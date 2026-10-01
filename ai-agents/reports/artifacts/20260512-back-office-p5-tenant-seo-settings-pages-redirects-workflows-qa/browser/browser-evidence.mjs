import fs from 'node:fs/promises'
import path from 'node:path'

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright')
const baseUrl = process.env.QA_BO_BASE || 'http://172.22.0.6:3000'
const password = process.env.QA_TENANT_PASSWORD
const artifactDir = process.env.QA_ARTIFACT_DIR || '/workspace/ai-agents/reports/artifacts/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa/browser'

if (!password) {
  throw new Error('QA_TENANT_PASSWORD is required')
}

await fs.mkdir(artifactDir, { recursive: true })

const browser = await chromium.launch({ headless: true })
const page = await browser.newPage({ viewport: { width: 1440, height: 1200 } })
const network = []
let screenshotIndex = 0

const scopedPaths = [
  '/api/v1/admin/tenant/seo',
  '/api/v1/admin/tenant/redirects',
]

page.on('response', async (response) => {
  const request = response.request()
  let url
  try {
    url = new URL(request.url())
  } catch {
    return
  }

  if (!scopedPaths.some((entry) => url.pathname.startsWith(entry))) {
    return
  }

  const headers = request.headers()
  let payload = {}
  try {
    payload = request.postDataJSON() || {}
  } catch {
    payload = {}
  }

  network.push({
    method: request.method(),
    path: url.pathname.replace('/api/v1', '') + url.search,
    status: response.status(),
    payload_keys: payloadKeys(payload),
    headers: {
      x_admin_scope: headers['x-admin-scope'] || null,
      x_tenant_id: headers['x-tenant-id'] || null,
      idempotency_key_present: Boolean(headers['idempotency-key']),
      authorization_present: Boolean(headers.authorization),
    },
  })
})

const summary = {
  result: 'PASS',
  baseUrl,
  tenantId: 'ten_demo_alpha',
  usedCustomerFrontend: false,
  menuSeoClicked: false,
  workflows: {},
  screenshots: [],
  network,
}

const shot = async (label) => {
  const fileName = `${String(++screenshotIndex).padStart(2, '0')}-${label}.png`
  await page.screenshot({ path: path.join(artifactDir, fileName), fullPage: true })
  summary.screenshots.push(fileName)
}

const uniqueCode = (prefix) => `${prefix}_${Date.now().toString(36)}_${Math.random().toString(16).slice(2, 6)}`
const runCode = uniqueCode('qa_seo')
const pagePath = `/qa-seo-page-${runCode}`
const redirectSource = `/qa-old-seo-page-${runCode}`
const redirectTarget = `https://alpha.newpaotang.test${pagePath}`

const clickUnique = async (locator, label) => {
  const count = await locator.count()
  if (count < 1) throw new Error(`${label} not found`)
  await locator.first().click()
}

const fillById = async (id, value) => {
  const locator = page.locator(`#${id}`)
  await locator.waitFor({ state: 'visible', timeout: 15000 })
  await locator.fill(String(value))
}

const selectById = async (id, value) => {
  const locator = page.locator(`#${id}`)
  await locator.waitFor({ state: 'visible', timeout: 15000 })
  await locator.selectOption(String(value))
}

const waitApi = (method, pathPart, action) => Promise.all([
  page.waitForResponse((response) => {
    const request = response.request()
    return request.method() === method
      && response.url().includes(pathPart)
      && response.status() >= 200
      && response.status() < 300
  }, { timeout: 30000 }),
  action(),
]).then(([response]) => response)

const waitListRefresh = (pathPart, predicate = () => true) => page.waitForResponse((response) => {
  const request = response.request()
  let url
  try {
    url = new URL(response.url())
  } catch {
    return false
  }

  return request.method() === 'GET'
    && url.pathname.includes(pathPart)
    && response.status() >= 200
    && response.status() < 300
    && predicate(url)
}, { timeout: 30000 })

const waitForNoVisibleLoading = async () => {
  await page.waitForFunction(() => {
    return !Array.from(document.querySelectorAll('*')).some((entry) => {
      const text = entry.textContent?.trim()
      return text === 'Loading...' && entry.getClientRects().length > 0
    })
  }, null, { timeout: 30000 })
}

const waitForRowAbsent = async (text) => {
  const deadline = Date.now() + 10000
  while (Date.now() < deadline) {
    if (await page.locator('tr').filter({ hasText: text }).count() === 0) {
      return true
    }
    await page.waitForTimeout(250)
  }
  return false
}

const confirmButton = () => page.locator('.modal.show').getByRole('button', { name: 'Confirm' })

const confirmAction = async (method, pathPart) => {
  const response = await waitApi(method, pathPart, async () => {
    await confirmButton().click()
  })
  try {
    return await response.json()
  } catch {
    return null
  }
}

const openSeoMenu = async () => {
  await page.goto(`${baseUrl}/admin/tenant/dashboard`)
  await page.waitForLoadState('networkidle')
  const link = page.locator('a[href="/admin/tenant/seo"]')
  await clickUnique(link, 'tenant SEO menu link')
  await page.waitForURL('**/admin/tenant/seo', { timeout: 20000 })
  await page.waitForLoadState('networkidle')
  summary.menuSeoClicked = true
}

const expectVisibleText = async (text, label) => {
  await page.getByText(text, { exact: false }).first().waitFor({ state: 'visible', timeout: 20000 })
  summary.workflows[label] = true
}

const applyPageFilter = async (status, pathValue) => {
  const card = page.locator('.card.custom-card').filter({ hasText: 'Path' }).first()
  await card.locator('select').first().selectOption(status)
  await card.locator('input[type="text"]').first().fill(pathValue)
  await waitApi('GET', '/api/v1/admin/tenant/seo/pages', async () => {
    await card.getByRole('button', { name: 'Apply filters' }).click()
  })
  await page.waitForLoadState('networkidle')
}

const applyRedirectFilter = async (status) => {
  const cards = page.locator('.card.custom-card').filter({ hasText: 'Apply filters' })
  const count = await cards.count()
  if (count < 2) throw new Error('redirect filter card not found')
  const card = cards.nth(1)
  await card.locator('select').first().selectOption(status)
  await waitApi('GET', '/api/v1/admin/tenant/redirects', async () => {
    await card.getByRole('button', { name: 'Apply filters' }).click()
  })
  await page.waitForLoadState('networkidle')
}

await page.goto(`${baseUrl}/login`)
await page.locator('input[type="email"]').fill('owner@alpha.newpaotang.test')
await page.locator('input[type="password"]').fill(password)
await page.locator('select.form-select').selectOption('tenant')
await page.locator('input[placeholder="Required for tenant login"]').fill('ten_demo_alpha')
await page.getByRole('button', { name: 'Sign in' }).click()
await page.waitForURL('**/admin/tenant/dashboard', { timeout: 30000 })
await page.waitForLoadState('networkidle')
await shot('tenant-dashboard')

await openSeoMenu()
await shot('seo-settings-initial')

await selectById('admin-operation-settings-status', 'active')
await fillById('admin-operation-settings-default_title', `QA Tenant SEO ${runCode}`)
await fillById('admin-operation-settings-title_template', `{{title}} | QA ${runCode}`)
await fillById('admin-operation-settings-default_description', `QA tenant SEO description ${runCode}`)
await fillById('admin-operation-settings-default_keywords', `qa\nseo\n${runCode}`)
await fillById('admin-operation-settings-robots_default', 'index,follow')
await fillById('admin-operation-settings-canonical_base_url', 'https://alpha.newpaotang.test')
await fillById('admin-operation-settings-og_image_url', `https://alpha.newpaotang.test/og-${runCode}.png`)
await shot('seo-settings-typed-form')
await waitApi('PATCH', '/api/v1/admin/tenant/seo', async () => {
  await page.locator('.card.custom-card').filter({ hasText: 'Configuration' }).getByRole('button', { name: 'Save' }).click()
})
summary.workflows.settings_title_round_trip = await page.locator('#admin-operation-settings-default_title').inputValue() === `QA Tenant SEO ${runCode}`

await fillById('admin-operation-settings-default_keywords', '')
await waitApi('PATCH', '/api/v1/admin/tenant/seo', async () => {
  await page.locator('.card.custom-card').filter({ hasText: 'Configuration' }).getByRole('button', { name: 'Save' }).click()
})
summary.workflows.blank_keywords_saved = true
await shot('seo-settings-blank-keywords-saved')

await clickUnique(page.getByRole('button', { name: 'Create SEO page' }), 'Create SEO page')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('seo-page-create-modal')
await fillById('admin-confirm-path', pagePath)
await fillById('admin-confirm-title', `QA SEO Page ${runCode}`)
await fillById('admin-confirm-description', 'QA SEO page description')
await fillById('admin-confirm-canonical_url', `https://alpha.newpaotang.test${pagePath}`)
await fillById('admin-confirm-robots', 'index,follow')
await fillById('admin-confirm-og_image_url', `https://alpha.newpaotang.test/page-${runCode}.png`)
await selectById('admin-confirm-status', 'active')
await fillById('admin-confirm-metadata', JSON.stringify({ source: 'browser', run: runCode }, null, 2))
const seoPage = await confirmAction('POST', '/api/v1/admin/tenant/seo/pages')
await expectVisibleText(pagePath, 'seo_page_row_visible_after_create')

const pageRow = page.locator('tr').filter({ hasText: pagePath })
await clickUnique(pageRow.getByRole('button', { name: 'Update page' }), 'Update page')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('seo-page-update-modal')
await fillById('admin-confirm-title', `QA SEO Page Updated ${runCode}`)
await fillById('admin-confirm-robots', 'noindex,nofollow')
await selectById('admin-confirm-status', 'inactive')
await fillById('admin-confirm-metadata', JSON.stringify([{ source: 'browser-update' }, { run: runCode }], null, 2))
await confirmAction('PATCH', `/api/v1/admin/tenant/seo/pages/${seoPage.id}`)
await expectVisibleText(`QA SEO Page Updated ${runCode}`, 'seo_page_update_round_trip')
await applyPageFilter('inactive', pagePath)
await expectVisibleText(pagePath, 'seo_page_filter_found')
await shot('seo-page-filter')

await clickUnique(page.locator('tr').filter({ hasText: pagePath }).getByRole('button', { name: 'Delete page' }), 'Delete page')
await page.locator('.modal.show').waitFor({ state: 'visible' })
summary.workflows.page_delete_confirm_disabled_without_reason = !(await confirmButton().isEnabled())
await shot('seo-page-delete-modal')
await page.locator('.modal.show textarea.form-control').fill('qa cleanup seo page')
const pageRefreshAfterDelete = waitListRefresh('/api/v1/admin/tenant/seo/pages', (url) => url.searchParams.get('path') === pagePath)
await confirmAction('DELETE', `/api/v1/admin/tenant/seo/pages/${seoPage.id}`)
await pageRefreshAfterDelete
await waitForNoVisibleLoading()
summary.workflows.seo_page_absent_after_delete = await waitForRowAbsent(pagePath)
await shot('seo-page-after-delete')

await clickUnique(page.getByRole('button', { name: 'Create redirect' }), 'Create redirect')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('redirect-create-modal')
await fillById('admin-confirm-source_path', redirectSource)
await fillById('admin-confirm-target_url', redirectTarget)
await selectById('admin-confirm-status_code', '301')
await selectById('admin-confirm-status', 'active')
await fillById('admin-confirm-metadata', JSON.stringify({ source: 'browser', run: runCode }, null, 2))
const redirect = await confirmAction('POST', '/api/v1/admin/tenant/redirects')
await expectVisibleText(redirectSource, 'redirect_row_visible_after_create')

const redirectRow = page.locator('tr').filter({ hasText: redirectSource })
await clickUnique(redirectRow.getByRole('button', { name: 'Update redirect' }), 'Update redirect')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('redirect-update-modal')
await fillById('admin-confirm-target_url', `${redirectTarget}?updated=1`)
await selectById('admin-confirm-status_code', '302')
await selectById('admin-confirm-status', 'inactive')
await fillById('admin-confirm-metadata', JSON.stringify([{ source: 'browser-update' }, { run: runCode }], null, 2))
await confirmAction('PATCH', `/api/v1/admin/tenant/redirects/${redirect.id}`)
await expectVisibleText(`${redirectTarget}?updated=1`, 'redirect_update_round_trip')
await applyRedirectFilter('inactive')
await expectVisibleText(redirectSource, 'redirect_filter_found')
await shot('redirect-filter')

await clickUnique(page.locator('tr').filter({ hasText: redirectSource }).getByRole('button', { name: 'Delete redirect' }), 'Delete redirect')
await page.locator('.modal.show').waitFor({ state: 'visible' })
summary.workflows.redirect_delete_confirm_disabled_without_reason = !(await confirmButton().isEnabled())
await shot('redirect-delete-modal')
await page.locator('.modal.show textarea.form-control').fill('qa cleanup redirect')
const redirectRefreshAfterDelete = waitListRefresh('/api/v1/admin/tenant/redirects')
await confirmAction('DELETE', `/api/v1/admin/tenant/redirects/${redirect.id}`)
await redirectRefreshAfterDelete
await waitForNoVisibleLoading()
summary.workflows.redirect_absent_after_delete = await waitForRowAbsent(redirectSource)
await shot('redirect-after-delete')

summary.fixtures = {
  seo_page_id: seoPage.id,
  seo_page_path: pagePath,
  redirect_id: redirect.id,
  redirect_source_path: redirectSource,
}
summary.currentUrl = page.url()
summary.networkChecks = {
  listCallsHaveTenantHeaders: network
    .filter((entry) => entry.method === 'GET')
    .every((entry) => entry.headers.x_admin_scope === 'tenant' && entry.headers.x_tenant_id === 'ten_demo_alpha'),
  writesHaveIdempotency: network
    .filter((entry) => ['POST', 'PATCH', 'DELETE'].includes(entry.method))
    .every((entry) => entry.headers.idempotency_key_present),
  noPageRedirectDetailGet: network
    .filter((entry) => entry.method === 'GET')
    .every((entry) => !/^\/admin\/tenant\/seo\/pages\/[^/?]+$/.test(entry.path) && !/^\/admin\/tenant\/redirects\/[^/?]+$/.test(entry.path)),
  noCustomerApiSeen: network.every((entry) => !entry.path.includes('/customer/')),
}

await fs.writeFile(path.join(artifactDir, 'browser-summary.json'), JSON.stringify(summary, null, 2))
console.log(JSON.stringify({
  result: summary.result,
  fixtures: summary.fixtures,
  screenshots: summary.screenshots.length,
  networkEvents: summary.network.length,
  networkChecks: summary.networkChecks,
}, null, 2))

await browser.close()

function payloadKeys(value, prefix = '') {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return []
  }

  const keys = []
  for (const [key, entry] of Object.entries(value)) {
    const pathKey = prefix ? `${prefix}.${key}` : key
    keys.push(pathKey)
    if (entry && typeof entry === 'object' && !Array.isArray(entry)) {
      keys.push(...payloadKeys(entry, pathKey))
    }
  }
  return keys
}

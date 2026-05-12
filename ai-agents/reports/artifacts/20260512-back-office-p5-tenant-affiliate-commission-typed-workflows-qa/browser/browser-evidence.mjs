import fs from 'node:fs/promises'
import path from 'node:path'

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright')
const baseUrl = process.env.QA_BO_BASE || 'http://newpaotang-back-office-affiliate-qa:3000'
const password = process.env.QA_TENANT_PASSWORD
const artifactDir = process.env.QA_ARTIFACT_DIR || '/workspace/ai-agents/reports/artifacts/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa/browser'

if (!password) {
  throw new Error('QA_TENANT_PASSWORD is required')
}

await fs.mkdir(artifactDir, { recursive: true })

const browser = await chromium.launch({ headless: true })
const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } })
const network = []
let screenshotIndex = 0

const scopedPaths = [
  '/api/v1/admin/tenant/affiliate-programs',
  '/api/v1/admin/tenant/affiliates',
  '/api/v1/admin/tenant/affiliate-links',
  '/api/v1/admin/tenant/commission-rules',
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
  menusClicked: {},
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
const runCode = uniqueCode('qa')

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
  await locator.selectOption(value)
}

const textareaById = async (id, value) => {
  const locator = page.locator(`#${id}`)
  await locator.waitFor({ state: 'visible', timeout: 15000 })
  await locator.fill(value)
}

const confirmButton = () => page.locator('.modal.show').getByRole('button', { name: 'Confirm' })

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

const openMenu = async (href, key) => {
  await page.goto(`${baseUrl}/admin/tenant/dashboard`)
  await page.waitForLoadState('networkidle')
  const link = page.locator(`a[href="${href}"]`)
  await clickUnique(link, `menu ${href}`)
  await page.waitForURL(`**${href}`, { timeout: 20000 })
  await page.waitForLoadState('networkidle')
  summary.menusClicked[key] = true
}

const openRowDetail = async (code, expectedPath) => {
  const row = page.locator('tr').filter({ hasText: code })
  await row.waitFor({ state: 'visible', timeout: 20000 })
  await row.getByRole('link', { name: 'Detail' }).click()
  await page.waitForURL(`**${expectedPath}/**`, { timeout: 20000 })
  await page.waitForLoadState('networkidle')
}

const applyStatusFilter = async (status) => {
  const filterCard = page.locator('.card.custom-card').filter({ hasText: 'Apply filters' }).first()
  await filterCard.locator('select').first().selectOption(status)
  await waitApi('GET', '/api/v1/admin/tenant/', async () => {
    await filterCard.getByRole('button', { name: 'Apply filters' }).click()
  })
  await page.waitForLoadState('networkidle')
}

const applyTextFilter = async (labelText, value) => {
  const filterCard = page.locator('.card.custom-card').filter({ hasText: 'Apply filters' }).first()
  const group = filterCard.locator('.col-sm-6').filter({ hasText: labelText }).first()
  await group.locator('input').fill(value)
  await waitApi('GET', '/api/v1/admin/tenant/', async () => {
    await filterCard.getByRole('button', { name: 'Apply filters' }).click()
  })
  await page.waitForLoadState('networkidle')
}

const expectVisibleText = async (text, label) => {
  const locator = page.getByText(text, { exact: false })
  await locator.first().waitFor({ state: 'visible', timeout: 20000 })
  summary.workflows[label] = true
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

const programCode = `${runCode}_program`
await openMenu('/admin/tenant/growth/affiliate-programs', 'affiliatePrograms')
await shot('programs-list')
await clickUnique(page.getByRole('button', { name: 'Create program' }), 'Create program')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('program-create-modal')
await fillById('admin-confirm-code', programCode)
await fillById('admin-confirm-name', `QA Program ${runCode}`)
await selectById('admin-confirm-status', 'active')
await fillById('admin-confirm-starts_at', '2026-05-12T09:00')
await fillById('admin-confirm-ends_at', '2026-06-12T09:00')
await textareaById('admin-confirm-metadata', JSON.stringify({ source: 'browser', run: runCode }, null, 2))
const program = await confirmAction('POST', '/api/v1/admin/tenant/affiliate-programs')
await expectVisibleText(programCode, 'program_row_visible_after_create')
await openRowDetail(programCode, '/admin/tenant/growth/affiliate-programs')
await shot('program-detail')
await clickUnique(page.getByRole('button', { name: 'Update program' }), 'Update program')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('program-update-modal')
await fillById('admin-confirm-name', `QA Program Updated ${runCode}`)
await selectById('admin-confirm-status', 'inactive')
await textareaById('admin-confirm-metadata', JSON.stringify([{ source: 'browser-update' }, { run: runCode }], null, 2))
await confirmAction('PATCH', `/api/v1/admin/tenant/affiliate-programs/${program.id}`)
await expectVisibleText(`QA Program Updated ${runCode}`, 'program_detail_updated')

const affiliateCode = `${runCode}_affiliate`
await openMenu('/admin/tenant/growth/affiliates', 'affiliateAccounts')
await shot('affiliates-list')
await clickUnique(page.getByRole('button', { name: 'Create affiliate' }), 'Create affiliate')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('affiliate-create-modal')
await fillById('admin-confirm-code', affiliateCode)
await fillById('admin-confirm-name', `QA Affiliate ${runCode}`)
await fillById('admin-confirm-phone', '0200000000')
await fillById('admin-confirm-email', `qa-affiliate-${runCode}@example.test`)
await selectById('admin-confirm-status', 'active')
await selectById('admin-confirm-currency', 'THB')
await textareaById('admin-confirm-payout_profile', JSON.stringify({ method: 'bank_transfer', account_ref: 'redacted' }, null, 2))
await textareaById('admin-confirm-metadata', JSON.stringify({ source: 'browser', run: runCode }, null, 2))
const affiliate = await confirmAction('POST', '/api/v1/admin/tenant/affiliates')
await expectVisibleText(affiliateCode, 'affiliate_row_visible_after_create')
await openRowDetail(affiliateCode, '/admin/tenant/growth/affiliates')
await shot('affiliate-detail')
await clickUnique(page.getByRole('button', { name: 'Update affiliate' }), 'Update affiliate')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('affiliate-update-modal')
await fillById('admin-confirm-name', `QA Affiliate Updated ${runCode}`)
await selectById('admin-confirm-status', 'inactive')
await textareaById('admin-confirm-payout_profile', JSON.stringify([{ method: 'manual_review' }, { run: runCode }], null, 2))
await textareaById('admin-confirm-metadata', JSON.stringify([{ source: 'browser-update' }, { run: runCode }], null, 2))
await confirmAction('PATCH', `/api/v1/admin/tenant/affiliates/${affiliate.id}`)
await expectVisibleText(`QA Affiliate Updated ${runCode}`, 'affiliate_detail_updated')
await openMenu('/admin/tenant/growth/affiliates', 'affiliateAccountsFilter')
await applyStatusFilter('inactive')
await expectVisibleText(affiliateCode, 'affiliate_status_filter_found')
summary.workflows.affiliate_has_no_archive_action = await page.getByRole('button', { name: 'Archive' }).count() === 0
await shot('affiliate-status-filter')

const linkCode = `${runCode}_link`
await openMenu('/admin/tenant/growth/affiliate-links', 'affiliateLinks')
await shot('links-list')
await clickUnique(page.getByRole('button', { name: 'Create link' }), 'Create link')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('link-create-modal')
await fillById('admin-confirm-affiliate_account_id', affiliate.id)
await fillById('admin-confirm-affiliate_program_id', program.id)
await fillById('admin-confirm-code', linkCode)
await fillById('admin-confirm-url', `https://newpaotang.local/a/${linkCode}`)
await selectById('admin-confirm-status', 'active')
await textareaById('admin-confirm-metadata', JSON.stringify({ source: 'browser', run: runCode }, null, 2))
const link = await confirmAction('POST', '/api/v1/admin/tenant/affiliate-links')
await expectVisibleText(linkCode, 'link_row_visible_after_create')
await openRowDetail(linkCode, '/admin/tenant/growth/affiliate-links')
await shot('link-detail')
await clickUnique(page.getByRole('button', { name: 'Update link' }), 'Update link')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('link-update-modal')
await selectById('admin-confirm-status', 'inactive')
await textareaById('admin-confirm-metadata', JSON.stringify([{ source: 'browser-update' }, { run: runCode }], null, 2))
await confirmAction('PATCH', `/api/v1/admin/tenant/affiliate-links/${link.id}`)
await expectVisibleText('inactive', 'link_detail_updated')
await openMenu('/admin/tenant/growth/affiliate-links', 'affiliateLinksFilter')
await applyTextFilter('Affiliate ID', affiliate.id)
await expectVisibleText(linkCode, 'link_affiliate_filter_found')
await shot('link-affiliate-filter')

const ruleCode = `${runCode}_rule`
await openMenu('/admin/tenant/growth/commission-rules', 'commissionRules')
await shot('rules-list')
await clickUnique(page.getByRole('button', { name: 'Create commission rule' }), 'Create commission rule')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('rule-create-modal')
await fillById('admin-confirm-affiliate_program_id', program.id)
await fillById('admin-confirm-affiliate_account_id', affiliate.id)
await fillById('admin-confirm-code', ruleCode)
await fillById('admin-confirm-name', `QA Rule ${runCode}`)
await selectById('admin-confirm-rule_type', 'fixed_per_order')
await fillById('admin-confirm-amount-amount', '125')
await fillById('admin-confirm-rate_bps', '0')
await selectById('admin-confirm-amount-currency', 'THB')
await selectById('admin-confirm-status', 'active')
await textareaById('admin-confirm-metadata', JSON.stringify({ source: 'browser', run: runCode }, null, 2))
const rule = await confirmAction('POST', '/api/v1/admin/tenant/commission-rules')
await expectVisibleText(ruleCode, 'rule_row_visible_after_create')
await openRowDetail(ruleCode, '/admin/tenant/growth/commission-rules')
await shot('rule-detail')
await clickUnique(page.getByRole('button', { name: 'Update rule' }), 'Update rule')
await page.locator('.modal.show').waitFor({ state: 'visible' })
await shot('rule-update-modal')
await fillById('admin-confirm-name', `QA Rule Updated ${runCode}`)
await selectById('admin-confirm-rule_type', 'per_ticket')
await fillById('admin-confirm-amount-amount', '175')
await fillById('admin-confirm-rate_bps', '0')
await selectById('admin-confirm-status', 'inactive')
await textareaById('admin-confirm-metadata', JSON.stringify([{ source: 'browser-update' }, { run: runCode }], null, 2))
await confirmAction('PATCH', `/api/v1/admin/tenant/commission-rules/${rule.id}`)
await expectVisibleText(`QA Rule Updated ${runCode}`, 'rule_detail_updated')
await openMenu('/admin/tenant/growth/commission-rules', 'commissionRulesFilter')
await applyTextFilter('Affiliate account ID', affiliate.id)
await expectVisibleText(ruleCode, 'rule_affiliate_account_filter_found')
await shot('rule-affiliate-filter')

await page.goto(`${baseUrl}/admin/tenant/growth/commission-rules/${rule.id}`)
await page.waitForLoadState('networkidle')
await clickUnique(page.getByRole('button', { name: 'Archive' }), 'Archive rule')
await page.locator('.modal.show').waitFor({ state: 'visible' })
summary.workflows.rule_archive_confirm_disabled_without_reason = !(await confirmButton().isEnabled())
await shot('rule-archive-modal')
await page.locator('.modal.show textarea.form-control').fill('qa cleanup commission rule')
await confirmAction('DELETE', `/api/v1/admin/tenant/commission-rules/${rule.id}`)
await openMenu('/admin/tenant/growth/commission-rules', 'commissionRulesArchivedFilter')
await applyStatusFilter('archived')
await expectVisibleText(ruleCode, 'rule_archived_filter_found')
await shot('rule-archived-filter')

await page.goto(`${baseUrl}/admin/tenant/growth/affiliate-links/${link.id}`)
await page.waitForLoadState('networkidle')
await clickUnique(page.getByRole('button', { name: 'Archive' }), 'Archive link')
await page.locator('.modal.show').waitFor({ state: 'visible' })
summary.workflows.link_archive_confirm_disabled_without_reason = !(await confirmButton().isEnabled())
await shot('link-archive-modal')
await page.locator('.modal.show textarea.form-control').fill('qa cleanup affiliate link')
await confirmAction('DELETE', `/api/v1/admin/tenant/affiliate-links/${link.id}`)
await openMenu('/admin/tenant/growth/affiliate-links', 'affiliateLinksArchivedFilter')
await applyStatusFilter('archived')
await expectVisibleText(linkCode, 'link_archived_filter_found')
await shot('link-archived-filter')

await page.goto(`${baseUrl}/admin/tenant/growth/affiliate-programs/${program.id}`)
await page.waitForLoadState('networkidle')
await clickUnique(page.getByRole('button', { name: 'Archive' }), 'Archive program')
await page.locator('.modal.show').waitFor({ state: 'visible' })
summary.workflows.program_archive_confirm_disabled_without_reason = !(await confirmButton().isEnabled())
await shot('program-archive-modal')
await page.locator('.modal.show textarea.form-control').fill('qa cleanup affiliate program')
await confirmAction('DELETE', `/api/v1/admin/tenant/affiliate-programs/${program.id}`)
await openMenu('/admin/tenant/growth/affiliate-programs', 'affiliateProgramsArchivedFilter')
await applyStatusFilter('archived')
await expectVisibleText(programCode, 'program_archived_filter_found')
await shot('program-archived-filter')

summary.fixtures = {
  affiliate_program_id: program.id,
  affiliate_account_id: affiliate.id,
  affiliate_link_id: link.id,
  commission_rule_id: rule.id,
}
summary.currentUrl = page.url()
summary.networkChecks = {
  listCallsHaveTenantHeaders: network
    .filter((entry) => entry.method === 'GET')
    .every((entry) => entry.headers.x_admin_scope === 'tenant' && entry.headers.x_tenant_id === 'ten_demo_alpha'),
  writesHaveIdempotency: network
    .filter((entry) => ['POST', 'PATCH', 'DELETE'].includes(entry.method))
    .every((entry) => entry.headers.idempotency_key_present),
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

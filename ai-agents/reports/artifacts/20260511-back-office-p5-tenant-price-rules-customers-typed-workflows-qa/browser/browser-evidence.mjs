import { createRequire } from 'node:module'
import { promises as fs } from 'node:fs'

const workspace = '/workspace'
const artifactDir = `${workspace}/ai-agents/reports/artifacts/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa/browser`
const appBase = process.env.QA_BO_BASE || 'http://newpaotang-back-office-qa:3000'
const require = createRequire(process.env.PLAYWRIGHT_REQUIRE_BASE || import.meta.url)
const { chromium } = require('playwright')

const platformConfig = await fs.readFile(`${workspace}/apps/platform-api/config/platform.php`, 'utf8')
const tenantPassword = platformConfig.match(/tenant_owner_password' => env\('PLATFORM_SEED_TENANT_OWNER_PASSWORD', '([^']+)'\)/)?.[1]

if (!tenantPassword) {
  throw new Error('Unable to load tenant seed password from platform config.')
}

const runId = Date.now().toString(36)
const priceCode = `p5_ui_price_${runId}`
const memberPhone = `08${String(Math.floor(10000000 + Math.random() * 89999999))}`
const memberEmail = `p5.ui.${runId}@example.test`
const memberPassword = crypto.randomUUID().replace(/-/g, '')

const requestEvents = []
const browserChecks = {
  usedCustomerFrontend: false,
  menuPriceRulesClicked: false,
  menuCustomersClicked: false,
  priceRule: {},
  customer: {},
}

const relevantApiPath = (url) => {
  const parsed = new URL(url)
  return parsed.pathname.replace('/api/v1', '')
}

const redactPayloadKeys = (request) => {
  const raw = request.postData()
  if (!raw) return []
  try {
    return Object.keys(JSON.parse(raw))
  } catch {
    return ['<non-json>']
  }
}

const browser = await chromium.launch({ headless: true })
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } })

page.on('framenavigated', (frame) => {
  if (frame === page.mainFrame() && frame.url().includes('/customer/')) {
    browserChecks.usedCustomerFrontend = true
  }
})

page.on('request', (request) => {
  const url = request.url()
  if (!url.includes('/api/v1/admin/tenant/price-rules') && !url.includes('/api/v1/admin/tenant/members')) {
    return
  }

  const headers = request.headers()
  requestEvents.push({
    label: 'request',
    method: request.method(),
    path: relevantApiPath(url),
    headers: {
      x_admin_scope: headers['x-admin-scope'] || null,
      x_tenant_id: headers['x-tenant-id'] || null,
      idempotency_key_present: Boolean(headers['idempotency-key']),
    },
    payload_keys: redactPayloadKeys(request),
  })
})

page.on('response', async (response) => {
  const url = response.url()
  if (!url.includes('/api/v1/admin/tenant/price-rules') && !url.includes('/api/v1/admin/tenant/members')) {
    return
  }

  requestEvents.push({
    label: 'response',
    method: response.request().method(),
    path: relevantApiPath(url),
    status: response.status(),
  })
})

const screenshot = async (name) => {
  await page.screenshot({ path: `${artifactDir}/${name}.png`, fullPage: true })
}

const clickMenu = async (href, label) => {
  const link = page.locator(`a[href="${href}"]`).first()
  await link.waitFor({ state: 'visible', timeout: 15000 })
  await link.click()
  await page.waitForURL(new RegExp(href.replace(/\//g, '\\/')), { timeout: 15000 })
  await page.waitForLoadState('networkidle').catch(() => {})
  if (label === 'price_rules') browserChecks.menuPriceRulesClicked = true
  if (label === 'customers') browserChecks.menuCustomersClicked = true
}

const waitForResponse = async (method, pathPart, action) => {
  const [response] = await Promise.all([
    page.waitForResponse((res) => res.request().method() === method && res.url().includes(pathPart), { timeout: 20000 }),
    action(),
  ])
  return response
}

const confirm = async () => {
  await page.getByRole('button', { name: 'Confirm' }).last().click()
}

const labelsVisible = async (labels) => {
  for (const label of labels) {
    const labelCount = await page.locator('.modal.show label', { hasText: label }).count()
    if (labelCount < 1) {
      return false
    }
  }

  return true
}

await page.goto(`${appBase}/login`)
await page.locator('input[type="email"]').fill('owner@alpha.newpaotang.test')
await page.locator('input[type="password"]').fill(tenantPassword)
await page.locator('select.form-select').selectOption('tenant')
await page.locator('input[placeholder="Required for tenant login"]').fill('ten_demo_alpha')
await page.getByRole('button', { name: 'Sign in' }).click()
await page.waitForURL(/\/admin\/tenant\/dashboard/, { timeout: 20000 })
await page.waitForLoadState('networkidle').catch(() => {})
await screenshot('01-tenant-dashboard-after-login')

await clickMenu('/admin/tenant/price-rules', 'price_rules')
await page.getByRole('heading', { name: 'Price Rules' }).waitFor({ timeout: 15000 })
await screenshot('02-price-rules-list')

await page.getByRole('button', { name: 'Create price rule' }).click()
await page.getByRole('heading', { name: 'Create price rule' }).waitFor({ timeout: 10000 })
browserChecks.priceRule.createFieldsVisible = await labelsVisible([
  'Code',
  'Name',
  'Game ID',
  'Rule type',
  'Price amount (minor units)',
  'Currency',
  'Conditions JSON',
  'Status',
])
await screenshot('03-price-rule-create-modal-fields')
await page.locator('#admin-confirm-code').fill(priceCode)
await page.locator('#admin-confirm-name').fill(`P5 UI Price Rule ${runId}`)
await page.locator('#admin-confirm-rule_type').fill('fixed_price')
await page.locator('#admin-confirm-price_amount').fill('45678')
await page.locator('#admin-confirm-currency').selectOption('THB')
await page.locator('#admin-confirm-conditions').fill(JSON.stringify({ qa_run: runId, channel: 'browser' }, null, 2))
await page.locator('#admin-confirm-status').selectOption('active')
const priceCreateResponse = await waitForResponse('POST', '/api/v1/admin/tenant/price-rules', confirm)
browserChecks.priceRule.createStatus = priceCreateResponse.status()
await page.getByText(priceCode).waitFor({ timeout: 15000 })
await screenshot('04-price-rule-list-after-create')

await page.locator('tr', { hasText: priceCode }).getByRole('link', { name: 'Detail' }).click()
await page.waitForURL(/\/admin\/tenant\/price-rules\/prr_/, { timeout: 15000 })
await page.getByText(priceCode).waitFor({ timeout: 15000 })
await screenshot('05-price-rule-detail-after-create')

await page.getByRole('button', { name: 'Update price rule' }).click()
await page.getByRole('heading', { name: 'Update price rule' }).waitFor({ timeout: 10000 })
await screenshot('06-price-rule-update-modal-prefill')
await page.locator('#admin-confirm-name').fill(`P5 UI Price Rule Updated ${runId}`)
await page.locator('#admin-confirm-price_amount').fill('56789')
await page.locator('#admin-confirm-conditions').fill(JSON.stringify([{ qa_run: runId, tier: 'updated' }], null, 2))
const priceUpdateResponse = await waitForResponse('PATCH', '/api/v1/admin/tenant/price-rules/', confirm)
browserChecks.priceRule.updateStatus = priceUpdateResponse.status()
await page.getByText(`P5 UI Price Rule Updated ${runId}`).waitFor({ timeout: 15000 })
await screenshot('07-price-rule-detail-after-update')

await page.getByRole('button', { name: 'Archive' }).click()
await page.getByRole('heading', { name: 'Archive' }).waitFor({ timeout: 10000 })
browserChecks.priceRule.archiveReasonInitiallyRequired = await page.getByRole('button', { name: 'Confirm' }).last().isDisabled()
await screenshot('08-price-rule-archive-modal-context')
await page.locator('.modal.show textarea.form-control').last().fill(`QA browser archive ${runId}`)
const priceArchiveResponse = await waitForResponse('DELETE', '/api/v1/admin/tenant/price-rules/', confirm)
browserChecks.priceRule.archiveStatus = priceArchiveResponse.status()
await page.getByText('archived', { exact: false }).waitFor({ timeout: 15000 })
await screenshot('09-price-rule-detail-after-archive')

await clickMenu('/admin/tenant/customers', 'customers')
await page.getByRole('heading', { name: 'Customers' }).waitFor({ timeout: 15000 })
await screenshot('10-customers-list')

await page.getByRole('button', { name: 'Create member' }).click()
await page.getByRole('heading', { name: 'Create member' }).waitFor({ timeout: 10000 })
browserChecks.customer.createFieldsVisible = await labelsVisible([
  'Name',
  'Phone',
  'Email',
  'Temporary password',
  'Status',
  'Send invitation',
])
await screenshot('11-member-create-modal-empty-password')
await page.locator('#admin-confirm-name').fill(`P5 UI Member ${runId}`)
await page.locator('#admin-confirm-phone').fill(memberPhone)
await page.locator('#admin-confirm-email').fill(memberEmail)
await page.locator('#admin-confirm-password').fill(memberPassword)
await page.locator('#admin-confirm-status').selectOption('active')
if (await page.locator('#admin-confirm-send_invitation').isChecked()) {
  await page.locator('#admin-confirm-send_invitation').uncheck()
}
const memberCreateResponse = await waitForResponse('POST', '/api/v1/admin/tenant/members', confirm)
browserChecks.customer.createStatus = memberCreateResponse.status()
await page.getByText(memberPhone).waitFor({ timeout: 15000 })
await screenshot('12-customers-list-after-create')

await page.locator('tr', { hasText: memberPhone }).getByRole('link', { name: 'Detail' }).click()
await page.waitForURL(/\/admin\/tenant\/customers\/cus_/, { timeout: 15000 })
await page.getByText(memberEmail).waitFor({ timeout: 15000 })
await screenshot('13-member-detail-after-create')

await page.getByRole('button', { name: 'Update member' }).click()
await page.getByRole('heading', { name: 'Update member' }).waitFor({ timeout: 10000 })
await screenshot('14-member-update-modal-prefill')
await page.locator('#admin-confirm-name').fill(`P5 UI Member Updated ${runId}`)
await page.locator('#admin-confirm-email').fill(`p5.ui.updated.${runId}@example.test`)
await page.locator('#admin-confirm-admin_note').fill(`QA browser audit note ${runId}`)
const memberUpdateResponse = await waitForResponse('PATCH', '/api/v1/admin/tenant/members/', confirm)
browserChecks.customer.updateStatus = memberUpdateResponse.status()
await page.getByText(`P5 UI Member Updated ${runId}`).waitFor({ timeout: 15000 })
await screenshot('15-member-detail-after-update')

await page.getByRole('button', { name: 'Change status' }).click()
await page.getByRole('heading', { name: 'Change status' }).waitFor({ timeout: 10000 })
browserChecks.customer.statusReasonInitiallyRequired = await page.getByRole('button', { name: 'Confirm' }).last().isDisabled()
await screenshot('16-member-status-modal-context')
await page.locator('#admin-confirm-status').selectOption('suspended')
if (await page.locator('#admin-confirm-notify_member').isChecked()) {
  await page.locator('#admin-confirm-notify_member').uncheck()
}
await page.locator('.modal.show textarea.form-control').last().fill(`QA browser status change ${runId}`)
const memberStatusResponse = await waitForResponse('POST', '/api/v1/admin/tenant/members/', confirm)
browserChecks.customer.statusChangeStatus = memberStatusResponse.status()
await page.getByText('suspended', { exact: false }).waitFor({ timeout: 15000 })
await screenshot('17-member-detail-after-status')

await clickMenu('/admin/tenant/customers', 'customers')
await page.locator('.card .form-select').first().selectOption('suspended')
await page.getByRole('button', { name: 'Apply filters' }).click()
await page.getByText(memberPhone).waitFor({ timeout: 15000 })
await screenshot('18-customers-suspended-filter')

await browser.close()

const unsafeNeedles = [tenantPassword, memberPassword].filter(Boolean)
const screenshotNames = await fs.readdir(artifactDir)
const pngNames = screenshotNames.filter((name) => name.endsWith('.png'))

await fs.writeFile(`${artifactDir}/browser-summary.json`, JSON.stringify({
  generated_at: new Date().toISOString(),
  app_base: appBase,
  run_id: runId,
  safe_fixture_refs: {
    price_code: priceCode,
    member_phone: memberPhone,
    member_email: memberEmail,
  },
  checks: browserChecks,
  request_events: requestEvents,
  screenshots: pngNames.sort(),
  unsafe_text_written_to_summary: false,
}, null, 2))

for (const needle of unsafeNeedles) {
  const summary = await fs.readFile(`${artifactDir}/browser-summary.json`, 'utf8')
  if (summary.includes(needle)) {
    throw new Error('Unsafe secret value found in browser summary.')
  }
}

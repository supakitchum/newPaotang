import fs from 'node:fs/promises'
import path from 'node:path'

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright')

const baseUrl = process.env.QA_BO_BASE
const centralPassword = process.env.QA_CENTRAL_PASSWORD
const tenantPassword = process.env.QA_TENANT_PASSWORD
const artifactDir = process.env.QA_ARTIFACT_DIR || '/workspace/ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser'
const fixturePath = process.env.QA_BROWSER_FIXTURE || path.join(artifactDir, 'browser-fixture.json')

if (!baseUrl) throw new Error('QA_BO_BASE is required')
if (!centralPassword) throw new Error('QA_CENTRAL_PASSWORD is required')
if (!tenantPassword) throw new Error('QA_TENANT_PASSWORD is required')

await fs.mkdir(artifactDir, { recursive: true })
const fixture = JSON.parse(await fs.readFile(fixturePath, 'utf8'))

const browser = await chromium.launch({ headless: true })
const context = await browser.newContext({ viewport: { width: 1440, height: 1200 } })
const page = await context.newPage()
const network = []
let screenshotIndex = 0

const scopedPaths = [
  '/api/v1/admin/central/stock',
  '/api/v1/admin/tenant/commission-transactions',
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
  tenantId: fixture.tenant_id,
  fixture: {
    run: fixture.run,
    game_id: fixture.game_id,
    stock_ids: fixture.stock_ids,
    commission_id: fixture.commission_id,
    affiliate_account_id: fixture.affiliate_account_id,
    order_id: fixture.order_id,
    commission_rule_id: fixture.commission_rule_id,
  },
  usedCustomerFrontend: false,
  menu: {
    centralStockClicked: false,
    tenantCommissionTransactionsClicked: false,
  },
  workflows: {},
  observations: {},
  screenshots: [],
  network,
}

const shot = async (label) => {
  const fileName = `${String(++screenshotIndex).padStart(2, '0')}-${label}.png`
  await page.screenshot({ path: path.join(artifactDir, fileName), fullPage: true })
  summary.screenshots.push(fileName)
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

const login = async (scope) => {
  await page.goto(`${baseUrl}/login`)
  await page.waitForLoadState('networkidle')
  await page.locator('input[type="email"]').fill(scope === 'central' ? 'admin@newpaotang.test' : 'owner@alpha.newpaotang.test')
  await page.locator('input[type="password"]').fill(scope === 'central' ? centralPassword : tenantPassword)
  await page.locator('select.form-select').selectOption(scope)
  if (scope === 'tenant') {
    await page.locator('input[placeholder="Required for tenant login"]').fill(fixture.tenant_id)
  }
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL(`**/admin/${scope}/dashboard`, { timeout: 30000 })
  await page.waitForLoadState('networkidle')
  await waitMenuReady()
}

const logoutToCleanSession = async () => {
  await page.evaluate(() => {
    localStorage.clear()
    sessionStorage.clear()
  })
}

const waitMenuReady = async () => {
  await page.locator('aside').getByText('Loading menu...', { exact: false }).waitFor({ state: 'hidden', timeout: 30000 }).catch(() => {})
}

const applyFilters = async (card, endpointPart) => {
  await waitApi('GET', endpointPart, async () => {
    await card.getByRole('button', { name: 'Apply filters' }).click()
  })
  await page.waitForLoadState('networkidle')
}

const rowCount = () => page.locator('tbody tr').count()
const confirmButton = () => page.locator('.modal.show').getByRole('button', { name: 'Confirm' })
const modalText = async () => (await page.locator('.modal.show').innerText()).replace(/\s+/g, ' ').trim()

await login('central')
await shot('central-dashboard')
const centralMenuLink = page.locator('aside a[href="/admin/central/stock"]')
await centralMenuLink.first().waitFor({ state: 'visible', timeout: 30000 })
if (await centralMenuLink.count() < 1) {
  throw new Error('central stock menu link not found')
}
await centralMenuLink.first().click()
await page.waitForURL('**/admin/central/stock', { timeout: 20000 })
await page.waitForLoadState('networkidle')
summary.menu.centralStockClicked = true
await shot('central-stock-initial')

const stockFilterCard = page.locator('.card.custom-card').filter({ hasText: 'Game ID' }).first()
await stockFilterCard.locator('input').nth(0).fill(fixture.game_id)
await stockFilterCard.locator('select').first().selectOption('available')
await stockFilterCard.locator('input').nth(3).fill('20')
await applyFilters(stockFilterCard, '/api/v1/admin/central/stock')
await page.getByText(fixture.stock_ids[0], { exact: false }).waitFor({ state: 'visible', timeout: 20000 })
summary.workflows.stock_supported_filter_found_fixture = true
summary.workflows.stock_rows_expose_inspection_context = await page.getByText('910001', { exact: false }).isVisible()
summary.workflows.stock_supported_filter_row_count = await rowCount()
await shot('central-stock-supported-filter')

await stockFilterCard.locator('input').nth(1).fill('910001')
await applyFilters(stockFilterCard, '/api/v1/admin/central/stock')
summary.observations.stockNumberFilter = {
  present: true,
  requestSentUnsupportedNumber: network.some((entry) => entry.method === 'GET' && entry.path.includes('/admin/central/stock?') && entry.path.includes('number=910001')),
  rowCountAfterExactNumber: await rowCount(),
  unrelatedNumberStillVisible: await page.getByText('910002', { exact: false }).isVisible(),
}
await shot('central-stock-unsupported-number-filter')

await page.getByRole('button', { name: 'Export stock' }).click()
await page.locator('.modal.show').waitFor({ state: 'visible' })
summary.workflows.stock_export_reason_required = !(await confirmButton().isEnabled())
summary.observations.stockExportModal = {
  text: await modalText(),
  contextItemCount: await page.locator('.modal.show dl dd').count(),
  ticketNumberFieldVisible: await page.locator('#admin-confirm-number').isVisible(),
}
await shot('central-stock-export-modal')
await page.locator('#admin-confirm-game_id').fill(fixture.game_id)
await page.locator('#admin-confirm-filters-status').selectOption('available')
await page.locator('.modal.show textarea.form-control').last().fill('qa browser export supported filter')
await waitApi('POST', '/api/v1/admin/central/stock/exports', async () => {
  await confirmButton().click()
})
await page.waitForLoadState('networkidle')
summary.workflows.stock_export_submitted = true
await shot('central-stock-after-export')

await logoutToCleanSession()
await login('tenant')
await shot('tenant-dashboard')
const commissionMenuLink = page.locator('aside a[href="/admin/tenant/growth/commission-transactions"]')
await commissionMenuLink.first().waitFor({ state: 'visible', timeout: 30000 })
if (await commissionMenuLink.count() < 1) {
  throw new Error('tenant commission transactions menu link not found')
}
await commissionMenuLink.first().click()
await page.waitForURL('**/admin/tenant/growth/commission-transactions', { timeout: 20000 })
await page.waitForLoadState('networkidle')
summary.menu.tenantCommissionTransactionsClicked = true
await shot('tenant-commission-initial')

const commissionFilterCard = page.locator('.card.custom-card').filter({ hasText: 'Status' }).first()
const commissionStatusOptions = await commissionFilterCard.locator('select option').allTextContents()
summary.observations.commissionStatusFilter = {
  options: commissionStatusOptions.map((entry) => entry.trim()).filter(Boolean),
  calculatedOptionPresent: commissionStatusOptions.some((entry) => entry.trim().toLowerCase() === 'calculated'),
}
if (summary.observations.commissionStatusFilter.calculatedOptionPresent) {
  await commissionFilterCard.locator('select').first().selectOption('calculated')
}
await commissionFilterCard.locator('input').nth(1).fill('20')
await applyFilters(commissionFilterCard, '/api/v1/admin/tenant/commission-transactions')
await page.getByText(fixture.commission_id, { exact: false }).waitFor({ state: 'visible', timeout: 20000 })
summary.workflows.commission_list_found_fixture = true
summary.workflows.commission_supported_status_filter_available_for_approvable_rows = summary.observations.commissionStatusFilter.calculatedOptionPresent
summary.workflows.commission_rows_expose_inspection_context = await page.getByText(fixture.affiliate_account_id, { exact: false }).isVisible()
await shot('tenant-commission-calculated-filter')

const commissionRow = page.locator('tr').filter({ hasText: fixture.commission_id })
await commissionRow.getByRole('button', { name: 'Approve' }).click()
await page.locator('.modal.show').waitFor({ state: 'visible' })
summary.workflows.commission_approve_reason_required = !(await confirmButton().isEnabled())
summary.observations.commissionApproveModal = {
  text: await modalText(),
  contextItemCount: await page.locator('.modal.show dl dd').count(),
  includesCommissionId: (await modalText()).includes(fixture.commission_id),
  includesAffiliateAccountId: (await modalText()).includes(fixture.affiliate_account_id),
  includesAmount: (await modalText()).includes('1500'),
}
await shot('tenant-commission-approve-modal')
await page.locator('.modal.show textarea.form-control').fill('qa browser approve safe fixture commission')
await waitApi('POST', `/api/v1/admin/tenant/commission-transactions/${fixture.commission_id}/approve`, async () => {
  await confirmButton().click()
})
await page.waitForLoadState('networkidle')
summary.workflows.commission_approve_submitted = true

await commissionFilterCard.locator('select').first().selectOption('approved')
await applyFilters(commissionFilterCard, '/api/v1/admin/tenant/commission-transactions')
await page.getByText(fixture.commission_id, { exact: false }).waitFor({ state: 'visible', timeout: 20000 })
summary.workflows.commission_post_approve_status_visible = await page.locator('tr').filter({ hasText: fixture.commission_id }).getByText('Approved', { exact: false }).count() > 0
await shot('tenant-commission-approved-filter')

summary.currentUrl = page.url()
summary.networkChecks = {
  centralListCallsHaveCentralScope: network
    .filter((entry) => entry.method === 'GET' && entry.path.startsWith('/admin/central/stock'))
    .every((entry) => entry.headers.x_admin_scope === 'central'),
  tenantListCallsHaveTenantHeaders: network
    .filter((entry) => entry.method === 'GET' && entry.path.startsWith('/admin/tenant/commission-transactions'))
    .every((entry) => entry.headers.x_admin_scope === 'tenant' && entry.headers.x_tenant_id === fixture.tenant_id),
  writesHaveIdempotency: network
    .filter((entry) => ['POST', 'PATCH', 'DELETE'].includes(entry.method))
    .every((entry) => entry.headers.idempotency_key_present),
  noStockDetailGet: network
    .filter((entry) => entry.method === 'GET')
    .every((entry) => !/^\/admin\/central\/stock\/[^/?]+$/.test(entry.path)),
  noCommissionDetailGet: network
    .filter((entry) => entry.method === 'GET')
    .every((entry) => !/^\/admin\/tenant\/commission-transactions\/[^/?]+$/.test(entry.path)),
  noCustomerApiSeen: network.every((entry) => !entry.path.includes('/customer/')),
}

const requiredChecks = [
  ...Object.values(summary.menu),
  ...Object.values(summary.workflows),
  ...Object.values(summary.networkChecks),
]
if (requiredChecks.some((value) => value !== true)) {
  summary.result = 'FAIL'
}

await fs.writeFile(path.join(artifactDir, 'browser-summary.json'), JSON.stringify(summary, null, 2))
console.log(JSON.stringify({
  result: summary.result,
  fixture: summary.fixture,
  screenshots: summary.screenshots.length,
  networkEvents: summary.network.length,
  networkChecks: summary.networkChecks,
  observations: summary.observations,
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

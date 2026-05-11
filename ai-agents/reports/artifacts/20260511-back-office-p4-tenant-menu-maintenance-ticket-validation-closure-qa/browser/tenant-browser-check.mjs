import fs from 'node:fs/promises'

let chromium
try {
  ;({ chromium } = await import(process.env.QA_PLAYWRIGHT_IMPORT || 'playwright'))
} catch {
  ;({ chromium } = await import('/tmp/bo-qa-pw/node_modules/playwright/index.mjs'))
}

const outDir = '/workspace/ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/browser'
const appBase = 'http://localhost:3100'
const apiBase = 'http://platform-api:8000/api/v1'
const tenantId = 'ten_demo_alpha'
const runId = `browser-closure-${Date.now().toString(36)}`

await fs.mkdir(outDir, { recursive: true })

const summary = {
  generated_at: new Date().toISOString(),
  run_id: runId,
  tenant_id: tenantId,
  requests: [],
  checks: {},
  console_messages: [],
}

async function writeText(name, text) {
  await fs.writeFile(`${outDir}/${name}`, text)
}

function safeHeaders(headers) {
  return {
    'x-admin-scope': headers['x-admin-scope'] || null,
    'x-tenant-id': headers['x-tenant-id'] || null,
    'idempotency-key': headers['idempotency-key'] || null,
  }
}

async function apiLogin() {
  const response = await fetch(`${apiBase}/auth/admin/login`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Admin-Scope': 'tenant',
      'X-Tenant-Id': tenantId,
      'X-Request-Id': `req_${runId}_cleanup_login`,
    },
    body: JSON.stringify({
      email: 'owner@alpha.newpaotang.test',
      password: process.env.QA_TENANT_PASSWORD,
      scope: 'tenant',
      tenant_id: tenantId,
    }),
  })
  if (!response.ok) throw new Error(`cleanup login failed ${response.status}`)
  return response.json()
}

async function cleanupBypass(id) {
  if (!id) return
  const login = await apiLogin()
  await fetch(`${apiBase}/admin/tenant/maintenance/bypasses/${id}`, {
    method: 'DELETE',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${login.access_token}`,
      'X-Admin-Scope': 'tenant',
      'X-Tenant-Id': tenantId,
      'X-Request-Id': `req_${runId}_cleanup_revoke`,
      'Idempotency-Key': `${runId}-ui-bypass-cleanup`,
    },
    body: JSON.stringify({ reason: `${runId} UI cleanup` }),
  })
}

const browser = await chromium.launch({
  headless: true,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--host-resolver-rules=MAP localhost 172.22.0.4'],
})
const context = await browser.newContext({ viewport: { width: 1365, height: 950 } })
await context.route('http://localhost:8000/**', (route) => {
  route.continue({ url: route.request().url().replace('http://localhost:8000', 'http://platform-api:8000') })
})
await context.route('http://127.0.0.1:8000/**', (route) => {
  route.continue({ url: route.request().url().replace('http://127.0.0.1:8000', 'http://platform-api:8000') })
})

const page = await context.newPage()
page.on('console', (msg) => summary.console_messages.push({ type: msg.type(), text: msg.text().slice(0, 500) }))
page.on('pageerror', (err) => summary.console_messages.push({ type: 'pageerror', text: err.message.slice(0, 500) }))
page.on('request', (request) => {
  const url = request.url()
  if (!url.includes('/api/v1/admin/tenant/menu-management') && !url.includes('/api/v1/admin/tenant/maintenance')) {
    return
  }
  summary.requests.push({
    method: request.method(),
    url: url.replace('http://localhost:8000/api/v1', '/api/v1').replace('http://platform-api:8000/api/v1', '/api/v1'),
    headers: safeHeaders(request.headers()),
    post_data: request.method() === 'GET' ? null : request.postDataJSON().catch ? null : request.postDataJSON(),
  })
})

await page.goto(`${appBase}/login`, { waitUntil: 'domcontentloaded' })
await page.locator('input[type="email"]').fill('owner@alpha.newpaotang.test')
await page.locator('input[type="password"]').fill(process.env.QA_TENANT_PASSWORD)
await page.locator('select').selectOption('tenant')
await page.locator('input[placeholder="Required for tenant login"]').fill(tenantId)
await page.screenshot({ path: `${outDir}/tenant-login-ready.png`, fullPage: true })
await Promise.all([
  page.waitForURL('**/admin/tenant/dashboard', { timeout: 20000 }),
  page.getByRole('button', { name: 'Sign in' }).click(),
])

await page.waitForSelector('a[href="/admin/tenant/menu-management"]', { timeout: 20000 })
const menuLinkCount = await page.locator('a[href="/admin/tenant/menu-management"]').count()
await page.locator('a[href="/admin/tenant/menu-management"]').first().click()
await page.waitForURL('**/admin/tenant/menu-management', { timeout: 20000 })
await page.waitForSelector('.np-menu-editor-label', { timeout: 20000 })

const beforeMenuPutCount = summary.requests.filter((request) => request.method === 'PUT' && request.url.includes('/admin/tenant/menu-management')).length
const editableCounts = {
  label: await page.locator('.np-menu-editor-label').count(),
  route: await page.locator('.np-menu-editor-route').count(),
  permission: await page.locator('.np-menu-editor-permission').count(),
  status: await page.locator('.np-menu-editor-status').count(),
  order: await page.locator('.np-menu-editor-order').count(),
  role_ids: await page.locator('.np-menu-editor-roles').count(),
}

const label = page.locator('.np-menu-editor-label').first()
const originalLabel = await label.inputValue()
const changedLabel = `${originalLabel} [TENANT-BROWSER-QA]`
await label.fill(changedLabel)
await page.locator('textarea').last().fill(`${runId} tenant menu confirmation`)
const afterReasonPutCount = summary.requests.filter((request) => request.method === 'PUT' && request.url.includes('/admin/tenant/menu-management')).length

await page.getByRole('button', { name: 'Save menu' }).click()
await page.getByRole('heading', { name: 'Confirm menu save' }).waitFor({ timeout: 10000 })
const modal = page.locator('.modal-content').filter({ hasText: 'Confirm menu save' }).last()
const modalText = await modal.innerText()
await writeText('tenant-menu-confirm-modal.txt', modalText)
await page.screenshot({ path: `${outDir}/tenant-menu-confirm-before-submit.png`, fullPage: true })
const afterOpenPutCount = summary.requests.filter((request) => request.method === 'PUT' && request.url.includes('/admin/tenant/menu-management')).length

await page.getByRole('button', { name: 'Cancel' }).click()
await page.getByRole('heading', { name: 'Confirm menu save' }).waitFor({ state: 'hidden', timeout: 10000 })
const afterCancelPutCount = summary.requests.filter((request) => request.method === 'PUT' && request.url.includes('/admin/tenant/menu-management')).length

await page.getByRole('button', { name: 'Save menu' }).click()
await page.getByRole('heading', { name: 'Confirm menu save' }).waitFor({ timeout: 10000 })
await page.screenshot({ path: `${outDir}/tenant-menu-confirm-ready-to-save.png`, fullPage: true })
const [menuSaveResponse] = await Promise.all([
  page.waitForResponse((response) => response.request().method() === 'PUT' && response.url().includes('/admin/tenant/menu-management'), { timeout: 20000 }),
  page.getByRole('button', { name: 'Confirm save' }).click(),
])
await page.reload({ waitUntil: 'domcontentloaded' })
await page.waitForSelector('.np-menu-editor-label', { timeout: 20000 })
const observedChanged = await page.locator('.np-menu-editor-label').first().inputValue()

await page.locator('.np-menu-editor-label').first().fill(originalLabel)
await page.locator('textarea').last().fill(`${runId} tenant menu restore`)
await page.getByRole('button', { name: 'Save menu' }).click()
await page.getByRole('heading', { name: 'Confirm menu save' }).waitFor({ timeout: 10000 })
const [menuRestoreResponse] = await Promise.all([
  page.waitForResponse((response) => response.request().method() === 'PUT' && response.url().includes('/admin/tenant/menu-management'), { timeout: 20000 }),
  page.getByRole('button', { name: 'Confirm save' }).click(),
])
await page.reload({ waitUntil: 'domcontentloaded' })
await page.waitForSelector('.np-menu-editor-label', { timeout: 20000 })
const observedRestored = await page.locator('.np-menu-editor-label').first().inputValue()
await page.screenshot({ path: `${outDir}/tenant-menu-restored.png`, fullPage: true })

const menuRequests = summary.requests.filter((request) => request.url.includes('/admin/tenant/menu-management'))
await writeText('tenant-menu-summary.json', JSON.stringify({
  menuLinkCount,
  editableCounts,
  beforeMenuPutCount,
  afterReasonPutCount,
  afterOpenPutCount,
  afterCancelPutCount,
  modal_has_tenant: modalText.includes('Tenant'),
  modal_has_reason: modalText.includes(`${runId} tenant menu confirmation`),
  modal_has_counts: modalText.includes('Menu items') && modalText.includes('Changed items'),
  modal_has_changed_context: modalText.includes(originalLabel) && modalText.includes(changedLabel) && modalText.includes('Label:'),
  save_status: menuSaveResponse.status(),
  restore_status: menuRestoreResponse.status(),
  observedChanged,
  observedRestored,
  requests: menuRequests,
}, null, 2))

summary.checks.tenant_menu_management = {
  menuLinkCount,
  editableCounts,
  noPutAfterReason: afterReasonPutCount === beforeMenuPutCount,
  noPutAfterOpen: afterOpenPutCount === beforeMenuPutCount,
  cancelNoSubmit: afterCancelPutCount === beforeMenuPutCount,
  saveStatus: menuSaveResponse.status(),
  restoreStatus: menuRestoreResponse.status(),
  observedChanged,
  observedRestored,
  allTenantHeaders: menuRequests.every((request) => request.headers['x-admin-scope'] === 'tenant' && request.headers['x-tenant-id'] === tenantId),
}

await page.waitForSelector('a[href="/admin/tenant/maintenance"]', { timeout: 20000 })
const maintenanceLinkCount = await page.locator('a[href="/admin/tenant/maintenance"]').count()
await page.locator('a[href="/admin/tenant/maintenance"]').first().click()
await page.waitForURL('**/admin/tenant/maintenance', { timeout: 20000 })
await page.waitForSelector('text=Create bypass', { timeout: 20000 })
await page.waitForResponse((response) => response.url().includes('/admin/tenant/maintenance/bypasses') && response.request().method() === 'GET', { timeout: 20000 }).catch(() => null)
await page.screenshot({ path: `${outDir}/tenant-maintenance-loaded.png`, fullPage: true })

const createCard = page.locator('.custom-card').filter({ hasText: 'Create bypass' })
const createButton = createCard.getByRole('button', { name: 'Create bypass' })
const disabledInitial = await createButton.isDisabled()
await createCard.locator('select').selectOption('tenant_admin')
await createCard.locator('input').nth(0).fill('adm_demo_alpha_owner')
await createCard.locator('input').nth(1).fill(`${runId} missing-ticket UI guard`)
const postCountBeforeEnter = summary.requests.filter((request) => request.method === 'POST' && request.url.includes('/admin/tenant/maintenance/bypasses')).length
const disabledMissingTicket = await createButton.isDisabled()
const helper = createCard.getByText('Ticket ID is required before creating a bypass.')
const helperVisible = await helper.isVisible()
const helperClass = await helper.getAttribute('class')
await createCard.locator('input').nth(1).press('Enter')
await page.waitForTimeout(500)
const postCountAfterEnter = summary.requests.filter((request) => request.method === 'POST' && request.url.includes('/admin/tenant/maintenance/bypasses')).length
await page.screenshot({ path: `${outDir}/tenant-maintenance-missing-ticket-guard.png`, fullPage: true })

await createCard.locator('input').nth(2).fill(`QA-${runId}`)
const enabledWithTicket = await createButton.isEnabled()
const [bypassCreateResponse] = await Promise.all([
  page.waitForResponse((response) => response.request().method() === 'POST' && response.url().includes('/admin/tenant/maintenance/bypasses'), { timeout: 20000 }),
  createButton.click(),
])
const createdBypass = await bypassCreateResponse.json()
await page.waitForSelector(`text=${createdBypass.id}`, { timeout: 20000 }).catch(() => null)
await page.screenshot({ path: `${outDir}/tenant-maintenance-ticketed-created.png`, fullPage: true })
await cleanupBypass(createdBypass.id)

const maintenanceRequests = summary.requests.filter((request) => request.url.includes('/admin/tenant/maintenance'))
await writeText('tenant-maintenance-summary.json', JSON.stringify({
  maintenanceLinkCount,
  disabledInitial,
  disabledMissingTicket,
  helperVisible,
  helperClass,
  noPostAfterEnterMissingTicket: postCountAfterEnter === postCountBeforeEnter,
  enabledWithTicket,
  createStatus: bypassCreateResponse.status(),
  createdBypass: { id: createdBypass.id, ticket_id_present: Boolean(createdBypass.ticket_id) },
  cleanup: 'revoked through API cleanup',
  requests: maintenanceRequests,
}, null, 2))

summary.checks.tenant_maintenance = {
  maintenanceLinkCount,
  disabledInitial,
  disabledMissingTicket,
  helperVisible,
  helperClass,
  noPostAfterEnterMissingTicket: postCountAfterEnter === postCountBeforeEnter,
  enabledWithTicket,
  createStatus: bypassCreateResponse.status(),
  createdTicketIdPresent: Boolean(createdBypass.ticket_id),
  allTenantHeaders: maintenanceRequests.every((request) => request.headers['x-admin-scope'] === 'tenant' && request.headers['x-tenant-id'] === tenantId),
}

await writeText('browser-summary.json', JSON.stringify(summary, null, 2))
await browser.close()
console.log(JSON.stringify({ ok: true, run_id: runId, checks: Object.keys(summary.checks) }, null, 2))

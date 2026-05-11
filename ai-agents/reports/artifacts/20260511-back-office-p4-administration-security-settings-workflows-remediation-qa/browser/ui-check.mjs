import fs from 'node:fs/promises'

let chromium
try {
  ;({ chromium } = await import(process.env.QA_PLAYWRIGHT_IMPORT || 'playwright'))
} catch {
  ;({ chromium } = await import('/tmp/bo-qa-pw/node_modules/playwright/index.mjs'))
}

const outDir = '/workspace/ai-agents/reports/artifacts/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa/browser'
const appBase = 'http://localhost:3100'
const apiProxyBase = process.env.QA_API_PROXY_BASE || 'http://host.docker.internal:8000'
const hostResolverRules = process.env.QA_HOST_RESOLVER_RULES || 'MAP localhost 192.168.65.254'
await fs.mkdir(outDir, { recursive: true })

const summary = { generated_at: new Date().toISOString(), checks: [] }
const consoleMessages = []

const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.QA_CHROMIUM_PATH || undefined,
  args: ['--no-sandbox', '--disable-dev-shm-usage', `--host-resolver-rules=${hostResolverRules}`],
})

async function writeText(name, text) {
  await fs.writeFile(`${outDir}/${name}`, text)
}

async function newPage() {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } })
  await context.route('http://localhost:8000/**', (route) => {
    route.continue({ url: route.request().url().replace('http://localhost:8000', apiProxyBase) })
  })
  await context.route('http://127.0.0.1:8000/**', (route) => {
    route.continue({ url: route.request().url().replace('http://127.0.0.1:8000', apiProxyBase) })
  })
  const page = await context.newPage()
  page.on('console', (msg) => consoleMessages.push({ type: msg.type(), text: msg.text().slice(0, 500) }))
  page.on('pageerror', (err) => consoleMessages.push({ type: 'pageerror', text: err.message.slice(0, 500) }))
  return { context, page }
}

async function login(page, scope) {
  await page.goto(`${appBase}/login`, { waitUntil: 'domcontentloaded' })
  await page.locator('input[type="email"]').fill(scope === 'central' ? 'admin@newpaotang.test' : 'owner@alpha.newpaotang.test')
  await page.locator('input[type="password"]').fill(scope === 'central' ? process.env.QA_CENTRAL_PASSWORD : process.env.QA_TENANT_PASSWORD)
  if (scope === 'tenant') {
    await page.locator('select').selectOption('tenant')
    await page.waitForTimeout(200)
    await page.locator('input[placeholder="Required for tenant login"]').fill('ten_demo_alpha')
  }
  await writeText(`${scope}-login-before-submit.json`, JSON.stringify({
    url: page.url(),
    scopeValue: await page.locator('select').inputValue(),
    tenantValue: await page.locator('input[placeholder="Required for tenant login"]').inputValue().catch(() => null),
    tenantDisabled: await page.locator('input[placeholder="Required for tenant login"]').isDisabled().catch(() => null),
  }, null, 2))
  await page.screenshot({ path: `${outDir}/${scope}-login-before-submit.png`, fullPage: true })
  await page.getByRole('button', { name: 'Sign in' }).click()
  try {
    await page.waitForURL(`**/admin/${scope}/dashboard`, { timeout: 15000 })
  } catch (error) {
    await writeText(`${scope}-login-after-submit.txt`, [
      `url=${page.url()}`,
      await page.locator('body').innerText().catch(() => ''),
    ].join('\n\n'))
    await page.screenshot({ path: `${outDir}/${scope}-login-after-submit-failed.png`, fullPage: true })
    throw error
  }
}

async function navigateByMenu(page, href) {
  await page.waitForSelector(`a[href="${href}"]`, { timeout: 15000 })
  const count = await page.locator(`a[href="${href}"]`).count()
  await page.locator(`a[href="${href}"]`).first().click()
  await page.waitForURL(`**${href}`, { timeout: 15000 })
  return count
}

async function exerciseMenu(scope, page, href, apiPath, suffix) {
  const menuLinkCount = await navigateByMenu(page, href)
  await page.waitForSelector('.np-menu-editor-label', { timeout: 15000 })

  const puts = []
  page.on('request', (req) => {
    if (req.method() === 'PUT' && req.url().includes(apiPath)) {
      puts.push(req.url())
    }
  })

  const label = page.locator('.np-menu-editor-label').first()
  const reason = page.locator('textarea').last()
  const original = await label.inputValue()
  const changed = `${original} ${suffix}`

  await label.fill(changed)
  await reason.fill(`QA ${scope} menu confirmation evidence`)
  await page.getByRole('button', { name: 'Save menu' }).click()
  await page.getByRole('heading', { name: 'Confirm menu save' }).waitFor({ timeout: 10000 })

  const modal = page.locator('.modal-content').filter({ hasText: 'Confirm menu save' }).last()
  const modalText = await modal.innerText()
  await writeText(`${scope}-menu-confirm-modal.txt`, modalText)
  await page.screenshot({ path: `${outDir}/${scope}-menu-confirm-before-submit.png`, fullPage: true })

  if (!modalText.includes(scope === 'central' ? 'Central' : 'Tenant')
    || !modalText.includes('Changed items')
    || !modalText.includes(original)
    || !modalText.includes(changed)
    || !modalText.includes('Label:')) {
    throw new Error(`${scope} confirmation modal missing required context`)
  }

  const putsBeforeCancel = puts.length
  await page.getByRole('button', { name: 'Cancel' }).click()
  await page.getByRole('heading', { name: 'Confirm menu save' }).waitFor({ state: 'hidden', timeout: 10000 })
  const putsAfterCancel = puts.length
  if (putsAfterCancel !== putsBeforeCancel) {
    throw new Error(`${scope} cancel submitted a PUT`)
  }

  await page.getByRole('button', { name: 'Save menu' }).click()
  await page.getByRole('heading', { name: 'Confirm menu save' }).waitFor({ timeout: 10000 })
  await page.screenshot({ path: `${outDir}/${scope}-menu-confirm-ready-to-save.png`, fullPage: true })
  const [saveResponse] = await Promise.all([
    page.waitForResponse((resp) => resp.request().method() === 'PUT' && resp.url().includes(apiPath), { timeout: 15000 }),
    page.getByRole('button', { name: 'Confirm save' }).click(),
  ])
  if (!saveResponse.ok()) {
    throw new Error(`${scope} menu confirm save failed ${saveResponse.status()}`)
  }
  await page.waitForTimeout(500)
  const observedChanged = await page.locator('.np-menu-editor-label').first().inputValue()

  await page.locator('.np-menu-editor-label').first().fill(original)
  await page.locator('textarea').last().fill(`QA ${scope} menu restore`)
  await page.getByRole('button', { name: 'Save menu' }).click()
  await page.getByRole('heading', { name: 'Confirm menu save' }).waitFor({ timeout: 10000 })
  const [restoreResponse] = await Promise.all([
    page.waitForResponse((resp) => resp.request().method() === 'PUT' && resp.url().includes(apiPath), { timeout: 15000 }),
    page.getByRole('button', { name: 'Confirm save' }).click(),
  ])
  if (!restoreResponse.ok()) {
    throw new Error(`${scope} menu restore failed ${restoreResponse.status()}`)
  }
  await page.waitForTimeout(500)
  const observedRestored = await page.locator('.np-menu-editor-label').first().inputValue()

  await writeText(`${scope}-menu-save-summary.json`, JSON.stringify({
    menuLinkCount,
    original,
    changed,
    putsBeforeCancel,
    putsAfterCancel,
    putCountTotal: puts.length,
    saveStatus: saveResponse.status(),
    restoreStatus: restoreResponse.status(),
    observedChanged,
    observedRestored,
  }, null, 2))

  summary.checks.push({
    scope,
    menuLinkCount,
    modalHasRequiredContext: true,
    cancelNoSubmit: putsAfterCancel === putsBeforeCancel,
    saveStatus: saveResponse.status(),
    restoreStatus: restoreResponse.status(),
    observedChanged,
    observedRestored,
  })
}

const central = await newPage()
await login(central.page, 'central')
await exerciseMenu('central', central.page, '/admin/central/menu-management', '/api/v1/admin/central/menu-management', '[UI-QA-CENTRAL]')
await central.context.close()

const tenant = await newPage()
await login(tenant.page, 'tenant')
await exerciseMenu('tenant', tenant.page, '/admin/tenant/menu-management', '/api/v1/admin/tenant/menu-management', '[UI-QA-TENANT]')

const maintenanceLinkCount = await navigateByMenu(tenant.page, '/admin/tenant/maintenance')
await tenant.page.waitForSelector('text=Create bypass', { timeout: 15000 })
const createCard = tenant.page.locator('.custom-card').filter({ hasText: 'Create bypass' })
await createCard.locator('select').selectOption('tenant_admin')
await createCard.locator('input').nth(0).fill('adm_demo_alpha_owner')
await createCard.locator('input').nth(1).fill('QA missing ticket UI guard')
const createButton = createCard.getByRole('button', { name: 'Create bypass' })
const disabledWithoutTicket = await createButton.isDisabled()
const helper = createCard.getByText('Ticket ID is required before creating a bypass.')
const helperVisible = await helper.isVisible()
const helperClass = await helper.getAttribute('class')
await tenant.page.screenshot({ path: `${outDir}/tenant-maintenance-bypass-ticket-required.png`, fullPage: true })

await createCard.locator('input').nth(2).fill('QA-UI-TICKET')
const enabledWithTicket = await createButton.isEnabled()
await tenant.page.screenshot({ path: `${outDir}/tenant-maintenance-bypass-ticket-ready.png`, fullPage: true })
await writeText('tenant-maintenance-bypass-summary.json', JSON.stringify({
  maintenanceLinkCount,
  disabledWithoutTicket,
  helperVisible,
  helperClass,
  enabledWithTicket,
}, null, 2))

summary.checks.push({
  scope: 'tenant-maintenance',
  maintenanceLinkCount,
  disabledWithoutTicket,
  helperVisible,
  helperClass,
  enabledWithTicket,
})
await tenant.context.close()

await writeText('browser-summary.json', JSON.stringify({ ...summary, consoleMessages: consoleMessages.slice(0, 20) }, null, 2))
await browser.close()
console.log(JSON.stringify({ ok: true, checks: summary.checks.length }, null, 2))

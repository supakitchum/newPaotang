import fs from 'node:fs/promises'
import path from 'node:path'

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright')

const baseUrl = process.env.QA_BO_BASE
const centralPassword = process.env.QA_CENTRAL_PASSWORD
const tenantPassword = process.env.QA_TENANT_PASSWORD
const apiEvidencePath = process.env.QA_API_EVIDENCE
const artifactDir = process.env.QA_ARTIFACT_DIR || '/workspace/ai-agents/reports/artifacts/20260514-lottery-image-partner-branding-assets-qa/browser'

if (!baseUrl) throw new Error('QA_BO_BASE is required')
if (!centralPassword) throw new Error('QA_CENTRAL_PASSWORD is required')
if (!tenantPassword) throw new Error('QA_TENANT_PASSWORD is required')
if (!apiEvidencePath) throw new Error('QA_API_EVIDENCE is required')

await fs.mkdir(artifactDir, { recursive: true })
const apiEvidence = JSON.parse(await fs.readFile(apiEvidencePath, 'utf8'))
const unlockedPartnerId = apiEvidence.fixtures.unlocked_partner_id
const lockedPartnerId = apiEvidence.fixtures.locked_partner_id

const browser = await chromium.launch({ headless: true })
const context = await browser.newContext({ viewport: { width: 1440, height: 1200 } })
const page = await context.newPage()
const network = []
let screenshotIndex = 0

const trackedPaths = [
  '/api/v1/admin/central/partners/',
  '/api/v1/admin/central/assets/uploads',
  '/api/v1/admin/central/assets/',
]

page.on('response', async (response) => {
  const request = response.request()
  let url
  try {
    url = new URL(request.url())
  } catch {
    return
  }

  if (!trackedPaths.some((entry) => url.pathname.startsWith(entry))) {
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
  fixtures: {
    unlocked_partner_id: unlockedPartnerId,
    locked_partner_id: lockedPartnerId,
  },
  usedCustomerFrontend: false,
  routeChecks: {},
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

const waitMenuReady = async () => {
  await page.locator('aside').getByText('Loading menu...', { exact: false }).waitFor({ state: 'hidden', timeout: 30000 }).catch(() => {})
}

const login = async (scope) => {
  await page.goto(`${baseUrl}/login`)
  await page.waitForLoadState('networkidle')
  await page.locator('input[type="email"]').fill(scope === 'central' ? 'admin@newpaotang.test' : 'owner@alpha.newpaotang.test')
  await page.locator('input[type="password"]').fill(scope === 'central' ? centralPassword : tenantPassword)
  await page.locator('select.form-select').selectOption(scope)
  if (scope === 'tenant') {
    await page.locator('input[placeholder="Required for tenant login"]').fill('ten_demo_alpha')
  }
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL(`**/admin/${scope}/dashboard`, { timeout: 30000 })
  await page.waitForLoadState('networkidle')
  await waitMenuReady()
}

const clearSession = async () => {
  await page.evaluate(() => {
    localStorage.clear()
    sessionStorage.clear()
  })
}

const png1x1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
  'base64',
)
const badText = Buffer.from('not an image', 'utf8')
const largePng = Buffer.alloc(5 * 1024 * 1024 + 1, 1)

await login('central')
await waitApi('GET', `/admin/central/partners/${unlockedPartnerId}/lottery-branding-assets`, async () => {
  await page.goto(`${baseUrl}/admin/central/partners/${unlockedPartnerId}/lottery-branding`)
})
await page.getByRole('heading', { name: 'Partner Lottery Branding' }).waitFor({ state: 'visible', timeout: 30000 })
summary.routeChecks.central_route_renders = page.url().endsWith(`/admin/central/partners/${unlockedPartnerId}/lottery-branding`)
summary.workflows.unlocked_read_uses_central_scope = true
await shot('central-unlocked-initial')

summary.observations.unlockedInitialText = (await page.locator('main').innerText()).replace(/\s+/g, ' ').trim()
summary.workflows.unlocked_state_metadata_visible = summary.observations.unlockedInitialText.includes('Status')
  && summary.observations.unlockedInitialText.includes('Generated images')
  && summary.observations.unlockedInitialText.includes('Version')
  && summary.observations.unlockedInitialText.includes('Asset ID')
  && summary.observations.unlockedInitialText.includes('logo_qr.webp')
  && summary.observations.unlockedInitialText.includes('right_sidebar.webp')
  && summary.observations.unlockedInitialText.includes('logo_bottom.webp')

const logoInput = page.locator('#branding-file-logo_qr')
await logoInput.setInputFiles({ name: 'bad.txt', mimeType: 'text/plain', buffer: badText })
await page.getByText('Only PNG or WebP images are accepted.', { exact: false }).waitFor({ state: 'visible', timeout: 10000 })
summary.workflows.client_rejects_unsupported_file_type = true
await shot('unsupported-file-validation')

await logoInput.setInputFiles({ name: 'too-large.png', mimeType: 'image/png', buffer: largePng })
await page.getByText('Image size must be between 1 byte and 5 MB.', { exact: false }).waitFor({ state: 'visible', timeout: 10000 })
summary.workflows.client_rejects_large_file = true
await shot('large-file-validation')

for (const slot of ['logo_qr', 'right_sidebar', 'logo_bottom']) {
  await page.locator(`#branding-file-${slot}`).setInputFiles({
    name: `${slot}-qa.png`,
    mimeType: 'image/png',
    buffer: png1x1,
  })
}
await page.getByText('logo_qr-qa.png', { exact: false }).waitFor({ state: 'visible', timeout: 10000 })
await page.getByText('right_sidebar-qa.png', { exact: false }).waitFor({ state: 'visible', timeout: 10000 })
await page.getByText('logo_bottom-qa.png', { exact: false }).waitFor({ state: 'visible', timeout: 10000 })
summary.workflows.selected_file_previews_visible = await page.locator('img[alt="Logo QR preview"]').count() > 0
  && await page.locator('img[alt="Right Sidebar preview"]').count() > 0
  && await page.locator('img[alt="Logo Bottom preview"]').count() > 0
await shot('selected-file-previews')

await waitApi('PUT', `/admin/central/partners/${unlockedPartnerId}/lottery-branding-assets`, async () => {
  await page.getByRole('button', { name: 'Save assets' }).first().click()
})
await page.getByText('Partner branding assets saved.', { exact: false }).waitFor({ state: 'visible', timeout: 30000 })
summary.workflows.unlocked_upload_commit_save_completed = true
await shot('unlocked-after-save')

await waitApi('GET', `/admin/central/partners/${lockedPartnerId}/lottery-branding-assets`, async () => {
  await page.goto(`${baseUrl}/admin/central/partners/${lockedPartnerId}/lottery-branding`)
})
await page.getByText('This partner is locked because partner-branded images already exist.', { exact: false }).waitFor({ state: 'visible', timeout: 30000 })
await shot('locked-state')
summary.observations.lockedText = (await page.locator('main').innerText()).replace(/\s+/g, ' ').trim()
summary.workflows.locked_state_visible = summary.observations.lockedText.includes('Locked')
  && summary.observations.lockedText.includes('partner_images_already_generated')
  && summary.observations.lockedText.includes('Generated images')
summary.workflows.locked_controls_disabled = await page.locator('#lottery-branding-version').isDisabled()
  && await page.locator('#branding-file-logo_qr').isDisabled()
  && await page.locator('#branding-file-right_sidebar').isDisabled()
  && await page.locator('#branding-file-logo_bottom').isDisabled()
  && await page.getByRole('button', { name: 'Save assets' }).first().isDisabled()

await clearSession()
await login('tenant')
await page.goto(`${baseUrl}/admin/tenant/partners/${unlockedPartnerId}/lottery-branding`)
await page.waitForLoadState('networkidle')
await shot('tenant-route-attempt')
summary.routeChecks.tenant_route_does_not_render_branding_form = await page.getByRole('heading', { name: 'Partner Lottery Branding' }).count() === 0

summary.networkChecks = {
  readCallsHaveCentralScope: network
    .filter((entry) => entry.method === 'GET' && entry.path.includes('/lottery-branding-assets'))
    .every((entry) => entry.headers.x_admin_scope === 'central'),
  uploadIntentCallsHaveCentralScopeAndIdempotency: network
    .filter((entry) => entry.method === 'POST' && entry.path === '/admin/central/assets/uploads')
    .length === 3
    && network
      .filter((entry) => entry.method === 'POST' && entry.path === '/admin/central/assets/uploads')
      .every((entry) => entry.headers.x_admin_scope === 'central' && entry.headers.idempotency_key_present),
  commitCallsHaveCentralScopeAndIdempotency: network
    .filter((entry) => entry.method === 'POST' && /^\/admin\/central\/assets\/[^/]+\/commit$/.test(entry.path))
    .length === 3
    && network
      .filter((entry) => entry.method === 'POST' && /^\/admin\/central\/assets\/[^/]+\/commit$/.test(entry.path))
      .every((entry) => entry.headers.x_admin_scope === 'central' && entry.headers.idempotency_key_present),
  saveCallUsesNestedAssetPayloadAndIdempotency: network
    .filter((entry) => entry.method === 'PUT' && entry.path === `/admin/central/partners/${unlockedPartnerId}/lottery-branding-assets`)
    .some((entry) => entry.headers.x_admin_scope === 'central'
      && entry.headers.idempotency_key_present
      && ['version', 'assets', 'assets.logo_qr.asset_id', 'assets.right_sidebar.asset_id', 'assets.logo_bottom.asset_id'].every((key) => entry.payload_keys.includes(key))),
  noCustomerApiSeen: network.every((entry) => !entry.path.includes('/customer/')),
}

const requiredChecks = [
  ...Object.values(summary.routeChecks),
  ...Object.values(summary.workflows),
  ...Object.values(summary.networkChecks),
]

if (requiredChecks.some((value) => value !== true)) {
  summary.result = 'FAIL'
}

await fs.writeFile(path.join(artifactDir, 'browser-summary.json'), JSON.stringify(summary, null, 2))
console.log(JSON.stringify({
  result: summary.result,
  fixtures: summary.fixtures,
  routeChecks: summary.routeChecks,
  workflows: summary.workflows,
  networkChecks: summary.networkChecks,
  screenshots: summary.screenshots.length,
  networkEvents: network.length,
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

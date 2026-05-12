import { createRequire } from 'node:module'
import { promises as fs } from 'node:fs'

const workspace = '/workspace'
const artifactDir = `${workspace}/ai-agents/reports/artifacts/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa/browser`
const appBase = process.env.QA_BO_BASE || 'http://newpaotang-back-office-agent-qa:3000'
const require = createRequire(process.env.PLAYWRIGHT_REQUIRE_BASE || import.meta.url)
const { chromium } = require('playwright')

const platformConfig = await fs.readFile(`${workspace}/apps/platform-api/config/platform.php`, 'utf8')
const tenantPassword = platformConfig.match(/tenant_owner_password' => env\('PLATFORM_SEED_TENANT_OWNER_PASSWORD', '([^']+)'\)/)?.[1]

if (!tenantPassword) {
  throw new Error('Unable to load tenant seed password from platform config.')
}

const runId = Date.now().toString(36)
const agentCode = `p5_ui_agent_${runId}`
const agentPhone = `08${String(Math.floor(10000000 + Math.random() * 89999999))}`
const agentEmail = `p5.agent.${runId}@example.test`

const requestEvents = []
const browserChecks = {
  usedCustomerFrontend: false,
  menuAgentsClicked: false,
  menuAgentQuotasClicked: false,
  agents: {},
  agentQuotas: {},
}

const relevantApiPath = (url) => new URL(url).pathname.replace('/api/v1', '')

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
  if (!url.includes('/api/v1/admin/tenant/agents')) {
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
  if (!url.includes('/api/v1/admin/tenant/agents')) {
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
  if (label === 'agents') browserChecks.menuAgentsClicked = true
  if (label === 'agent_quotas') browserChecks.menuAgentQuotasClicked = true
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
    if (await page.locator('.modal.show label', { hasText: label }).count() < 1) {
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

await clickMenu('/admin/tenant/growth/agents', 'agents')
await page.getByRole('heading', { name: 'Agents' }).waitFor({ timeout: 15000 })
await screenshot('02-agents-list')

await page.getByRole('button', { name: 'Create agent' }).click()
await page.getByRole('heading', { name: 'Create agent' }).waitFor({ timeout: 10000 })
browserChecks.agents.createFieldsVisible = await labelsVisible([
  'Code',
  'Name',
  'Phone',
  'Email',
  'Store ID',
  'Status',
  'Metadata JSON',
])
await screenshot('03-agent-create-modal-fields')
await page.locator('#admin-confirm-code').fill(agentCode)
await page.locator('#admin-confirm-name').fill(`P5 UI Agent ${runId}`)
await page.locator('#admin-confirm-phone').fill(agentPhone)
await page.locator('#admin-confirm-email').fill(agentEmail)
await page.locator('#admin-confirm-store_id').fill(`qa-store-${runId}`)
await page.locator('#admin-confirm-status').selectOption('active')
await page.locator('#admin-confirm-metadata').fill(JSON.stringify({ qa_run: runId, route: 'agents' }, null, 2))
const agentCreateResponse = await waitForResponse('POST', '/api/v1/admin/tenant/agents', confirm)
browserChecks.agents.createStatus = agentCreateResponse.status()
await page.getByText(agentCode).waitFor({ timeout: 15000 })
await screenshot('04-agents-list-after-create')

await page.locator('tr', { hasText: agentCode }).getByRole('link', { name: 'Detail' }).click()
await page.waitForURL(/\/admin\/tenant\/growth\/agents\/agt_/, { timeout: 15000 })
await page.getByText(agentCode).waitFor({ timeout: 15000 })
await screenshot('05-agent-detail-after-create')

await page.getByRole('button', { name: 'Update agent' }).click()
await page.getByRole('heading', { name: 'Update agent' }).waitFor({ timeout: 10000 })
await screenshot('06-agent-update-modal-prefill')
await page.locator('#admin-confirm-code').fill(`${agentCode}_updated`)
await page.locator('#admin-confirm-name').fill(`P5 UI Agent Updated ${runId}`)
await page.locator('#admin-confirm-status').selectOption('inactive')
await page.locator('#admin-confirm-metadata').fill(JSON.stringify([{ qa_run: runId, stage: 'updated' }], null, 2))
const agentUpdateResponse = await waitForResponse('PATCH', '/api/v1/admin/tenant/agents/', confirm)
browserChecks.agents.updateStatus = agentUpdateResponse.status()
await page.getByText(`P5 UI Agent Updated ${runId}`).waitFor({ timeout: 15000 })
await screenshot('07-agent-detail-after-update')

await page.getByRole('button', { name: 'Update quotas' }).click()
await page.getByRole('heading', { name: 'Update quotas' }).waitFor({ timeout: 10000 })
browserChecks.agents.quotaFieldsVisible = await labelsVisible([
  'Game ID',
  'Quota count',
  'Used count',
  'Status',
  'Payload JSON',
])
browserChecks.agents.quotaReasonInitiallyRequired = await page.getByRole('button', { name: 'Confirm' }).last().isDisabled()
await screenshot('08-agent-quota-modal-context')
await page.locator('#admin-confirm-game_id').fill('')
await page.locator('#admin-confirm-quota_count').fill('31')
await page.locator('#admin-confirm-used_count').fill('5')
await page.locator('#admin-confirm-status').selectOption('active')
await page.locator('#admin-confirm-payload').fill(JSON.stringify({ qa_run: runId, route: 'agents' }, null, 2))
await page.locator('.modal.show textarea.form-control').last().fill(`QA browser agent quota ${runId}`)
const agentQuotaResponse = await waitForResponse('PATCH', '/api/v1/admin/tenant/agents/', confirm)
browserChecks.agents.quotaStatus = agentQuotaResponse.status()
await page.locator('code.np-admin-code', { hasText: '"quota_count": 31' }).waitFor({ timeout: 15000 })
await screenshot('09-agent-detail-after-quota')

await clickMenu('/admin/tenant/growth/agent-quotas', 'agent_quotas')
await page.getByRole('heading', { name: 'Agent Quotas' }).waitFor({ timeout: 15000 })
await screenshot('10-agent-quotas-list')
await page.locator('tr', { hasText: `${agentCode}_updated` }).getByRole('link', { name: 'Detail' }).click()
await page.waitForURL(/\/admin\/tenant\/growth\/agent-quotas\/agt_/, { timeout: 15000 })
await page.getByText(`P5 UI Agent Updated ${runId}`).waitFor({ timeout: 15000 })
await screenshot('11-agent-quotas-detail')

await page.getByRole('button', { name: 'Update quotas' }).click()
await page.getByRole('heading', { name: 'Update quotas' }).waitFor({ timeout: 10000 })
browserChecks.agentQuotas.quotaFieldsVisible = await labelsVisible([
  'Game ID',
  'Quota count',
  'Used count',
  'Status',
  'Payload JSON',
])
browserChecks.agentQuotas.quotaReasonInitiallyRequired = await page.getByRole('button', { name: 'Confirm' }).last().isDisabled()
await screenshot('12-agent-quotas-update-modal-context')
await page.locator('#admin-confirm-quota_count').fill('44')
await page.locator('#admin-confirm-used_count').fill('6')
await page.locator('#admin-confirm-status').selectOption('suspended')
await page.locator('#admin-confirm-payload').fill(JSON.stringify([{ qa_run: runId, route: 'agent_quotas' }], null, 2))
await page.locator('.modal.show textarea.form-control').last().fill(`QA browser dedicated quota ${runId}`)
const dedicatedQuotaResponse = await waitForResponse('PATCH', '/api/v1/admin/tenant/agents/', confirm)
browserChecks.agentQuotas.quotaUpdateStatus = dedicatedQuotaResponse.status()
await page.locator('code.np-admin-code', { hasText: '"quota_count": 44' }).waitFor({ timeout: 15000 })
await page.locator('code.np-admin-code', { hasText: '"status": "suspended"' }).waitFor({ timeout: 15000 })
await screenshot('13-agent-quotas-detail-after-update')

await clickMenu('/admin/tenant/growth/agent-quotas', 'agent_quotas')
await page.locator('.card .form-select').first().selectOption('inactive')
await page.getByRole('button', { name: 'Apply filters' }).click()
await page.getByText(`${agentCode}_updated`).waitFor({ timeout: 15000 })
await screenshot('14-agent-quotas-filter-inactive')

await browser.close()

await fs.writeFile(`${artifactDir}/browser-summary.json`, JSON.stringify({
  generated_at: new Date().toISOString(),
  app_base: appBase,
  run_id: runId,
  safe_fixture_refs: {
    agent_code: agentCode,
    agent_email: agentEmail,
    agent_phone: agentPhone,
  },
  checks: browserChecks,
  request_events: requestEvents,
  screenshots: (await fs.readdir(artifactDir)).filter((name) => name.endsWith('.png')).sort(),
  unsafe_text_written_to_summary: false,
}, null, 2))

const summary = await fs.readFile(`${artifactDir}/browser-summary.json`, 'utf8')
if (summary.includes(tenantPassword)) {
  throw new Error('Unsafe tenant password found in browser summary.')
}

const { chromium } = require('playwright')
const fs = require('fs/promises')
const path = require('path')

const artifactDir = '/workspace/ai-agents/reports/artifacts/20260510-back-office-p4-administration-security-settings-workflows-qa/browser'
const apiEvidencePath = '/workspace/ai-agents/reports/artifacts/20260510-back-office-p4-administration-security-settings-workflows-qa/api/p4-api-evidence.json'
const apiEvidence = require(apiEvidencePath)
const supportId = apiEvidence.steps.find((step) => step.label === 'tenant support access create')?.body?.id

const out = {
  mode: 'docker-playwright-clean-context',
  routed_api: 'http://localhost:8000 -> http://platform-api:8000',
  support_id: supportId,
  central: {},
  tenant: {},
}

async function setupPage(context, viewport = { width: 1280, height: 900 }) {
  const page = await context.newPage()
  await page.setViewportSize(viewport)
  await page.route('http://localhost:8000/**', async (route) => {
    const url = route.request().url().replace('http://localhost:8000', 'http://platform-api:8000')
    const response = await route.fetch({ url })
    await route.fulfill({ response })
  })
  return page
}

async function login(page, scope) {
  await page.goto('http://back-office:3100/login', { waitUntil: 'domcontentloaded' })
  await page.locator('input[type=email]').fill(scope === 'central' ? process.env.CENTRAL_EMAIL : process.env.TENANT_EMAIL)
  await page.locator('input[type=password]').fill(scope === 'central' ? process.env.CENTRAL_PASSWORD : process.env.TENANT_PASSWORD)
  if (scope === 'tenant') {
    await page.locator('select').selectOption('tenant')
    await page.locator('input[placeholder="Required for tenant login"]').fill(process.env.TENANT_ID)
  }
  await Promise.all([
    page.waitForURL(`**/admin/${scope}/dashboard`, { timeout: 15000 }),
    page.getByRole('button', { name: 'Sign in' }).click(),
  ])
}

async function routeCheck(page, label, url, heading) {
  await page.goto(url, { waitUntil: 'networkidle' })
  const h = page.getByRole('heading', { name: heading })
  await h.waitFor({ state: 'visible', timeout: 10000 })
  const loginVisible = await page.getByRole('heading', { name: 'Admin sign in' }).isVisible().catch(() => false)
  const bodyText = await page.locator('main').innerText({ timeout: 5000 }).catch(() => '')
  return {
    label,
    url: page.url(),
    heading_visible: await h.isVisible(),
    login_visible: loginVisible,
    has_error: /Unable to load|not registered|permission/i.test(bodyText),
  }
}

async function main() {
  const launchOptions = { headless: true, args: ['--no-sandbox'] }
  if (process.env.CHROMIUM_PATH) {
    launchOptions.executablePath = process.env.CHROMIUM_PATH
  }
  const browser = await chromium.launch(launchOptions)
  try {
    const centralContext = await browser.newContext()
    const centralPage = await setupPage(centralContext)
    await login(centralPage, 'central')
    const centralRoutes = [
      ['central admin users', 'http://back-office:3100/admin/central/admin-users', 'Admin Users'],
      ['central roles', 'http://back-office:3100/admin/central/roles', 'Roles And Permissions'],
      ['central menu management', 'http://back-office:3100/admin/central/menu-management', 'Menu Management'],
      ['central system settings', 'http://back-office:3100/admin/central/system-settings', 'System Settings'],
    ]
    out.central.routes = []
    for (const [label, url, heading] of centralRoutes) {
      out.central.routes.push(await routeCheck(centralPage, label, url, heading))
    }

    await centralPage.goto('http://back-office:3100/admin/central/admin-users', { waitUntil: 'networkidle' })
    await centralPage.getByRole('button', { name: 'Create admin user' }).click()
    out.central.admin_user_modal = {
      has_name: await centralPage.locator('#admin-confirm-name').isVisible().catch(() => false),
      has_email: await centralPage.locator('#admin-confirm-email').isVisible().catch(() => false),
      has_password: await centralPage.locator('#admin-confirm-password').isVisible().catch(() => false),
      has_role_ids: await centralPage.locator('#admin-confirm-role_ids').isVisible().catch(() => false),
      confirm_disabled_without_reason: !(await centralPage.getByRole('button', { name: 'Confirm' }).isEnabled()),
    }
    await centralPage.keyboard.press('Escape')

    await centralPage.goto('http://back-office:3100/admin/central/menu-management', { waitUntil: 'networkidle' })
    await centralPage.screenshot({ path: path.join(artifactDir, 'central-menu-management.png'), fullPage: true })
    out.central.menu_management = {
      save_enabled_without_reason: await centralPage.getByRole('button', { name: 'Save menu' }).isEnabled(),
      reason_visible: await centralPage.locator('textarea').last().isVisible().catch(() => false),
      confirmation_modal_present_before_save: await centralPage.getByText('Confirm save', { exact: false }).isVisible().catch(() => false),
    }

    await centralPage.goto('http://back-office:3100/admin/central/system-settings', { waitUntil: 'networkidle' })
    await centralPage.setViewportSize({ width: 390, height: 844 })
    await centralPage.screenshot({ path: path.join(artifactDir, 'central-system-settings-mobile.png'), fullPage: true })
    out.central.system_settings_mobile = {
      viewport: '390x844',
      has_platform_name: await centralPage.getByText('Platform name', { exact: true }).isVisible().catch(() => false),
      save_visible: await centralPage.getByRole('button', { name: 'Save' }).isVisible().catch(() => false),
    }

    const tenantContext = await browser.newContext()
    const tenantPage = await setupPage(tenantContext)
    const tenantRequests = []
    tenantPage.on('request', (request) => {
      const url = request.url()
      if (url.includes('/api/v1/admin/tenant/')) {
        tenantRequests.push({
          url: url.replace('http://localhost:8000/api/v1', ''),
          tenant: request.headers()['x-tenant-id'] || null,
          scope: request.headers()['x-admin-scope'] || null,
        })
      }
    })

    await login(tenantPage, 'tenant')
    const tenantRoutes = [
      ['tenant admin users', 'http://back-office:3100/admin/tenant/admin-users', 'Admin Users'],
      ['tenant roles', 'http://back-office:3100/admin/tenant/roles', 'Roles And Permissions'],
      ['tenant menu management', 'http://back-office:3100/admin/tenant/menu-management', 'Menu Management'],
      ['tenant maintenance', 'http://back-office:3100/admin/tenant/maintenance', 'Maintenance'],
      ['tenant support access', 'http://back-office:3100/admin/tenant/support-access', 'Support Access Logs'],
      ['tenant settings', 'http://back-office:3100/admin/tenant/settings', 'Tenant Settings'],
    ]
    out.tenant.routes = []
    for (const [label, url, heading] of tenantRoutes) {
      out.tenant.routes.push(await routeCheck(tenantPage, label, url, heading))
    }

    await tenantPage.goto('http://back-office:3100/admin/tenant/maintenance', { waitUntil: 'networkidle' })
    await tenantPage.getByLabel('Actor ID').fill('adm_demo_alpha_owner').catch(async () => {
      await tenantPage.locator('input').nth(3).fill('adm_demo_alpha_owner')
    })
    await tenantPage.getByLabel('Reason').nth(1).fill('P4 QA UI missing ticket guard').catch(async () => {
      await tenantPage.locator('input').nth(4).fill('P4 QA UI missing ticket guard')
    })
    out.tenant.maintenance = {
      create_bypass_enabled_without_ticket: await tenantPage.getByRole('button', { name: 'Create bypass' }).isEnabled().catch(() => null),
    }
    await tenantPage.screenshot({ path: path.join(artifactDir, 'tenant-maintenance-missing-ticket.png'), fullPage: true })

    if (supportId) {
      await tenantPage.goto(`http://back-office:3100/admin/tenant/support-access/${supportId}`, { waitUntil: 'networkidle' })
      await tenantPage.screenshot({ path: path.join(artifactDir, 'tenant-support-access-detail.png'), fullPage: true })
      out.tenant.support_detail = {
        reason_required_disables_actions: !(await tenantPage.getByRole('button', { name: 'Approve' }).isEnabled().catch(() => true)),
        token_text_visible: await tenantPage.getByText('Initial token', { exact: true }).isVisible().catch(() => false),
      }
    }

    await tenantPage.goto('http://back-office:3100/admin/tenant/settings', { waitUntil: 'networkidle' })
    await tenantPage.setViewportSize({ width: 390, height: 844 })
    await tenantPage.screenshot({ path: path.join(artifactDir, 'tenant-settings-mobile.png'), fullPage: true })
    out.tenant.settings_mobile = {
      viewport: '390x844',
      has_theme_panel: await tenantPage.getByText('Theme And Branding', { exact: true }).isVisible().catch(() => false),
      has_domain_list: await tenantPage.getByText('Tenant Domains', { exact: true }).isVisible().catch(() => false),
    }
    out.tenant.request_headers_sample = tenantRequests.slice(0, 12)
    out.tenant.all_sampled_requests_tenant_scoped = tenantRequests.slice(0, 12).every((request) => (
      request.tenant === process.env.TENANT_ID && request.scope === 'tenant'
    ))

    await fs.writeFile(path.join(artifactDir, 'browser-ui-evidence.json'), JSON.stringify(out, null, 2))
    console.log(JSON.stringify(out, null, 2))
  } finally {
    await browser.close()
  }
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})

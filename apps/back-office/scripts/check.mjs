import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.cwd()
const mode = process.argv[2] || 'lint'

const requiredFiles = [
  'nuxt.config.ts',
  'app.vue',
  'layouts/admin.vue',
  'pages/login.vue',
  'pages/admin/central/dashboard/index.vue',
  'pages/admin/tenant/dashboard.vue',
  'pages/admin/tenant/maintenance.vue',
  'pages/admin/tenant/customer-notifications.vue',
  'pages/admin/tenant/support-access/index.vue',
  'pages/admin/tenant/support-access/[id].vue',
  'pages/admin/tenant/support.vue',
  'composables/useSupportApi.ts',
  'pages/admin/tenant/winners/index.vue',
  'pages/admin/tenant/[...slug].vue',
  'pages/admin/central/winners/index.vue',
  'pages/admin/central/[...slug].vue',
  'composables/useAdminApi.ts',
  'composables/useAdminHostMode.ts',
  'composables/useAdminSuccessAlert.ts',
  'composables/useAdminClientReady.ts',
  'composables/useAdminBranding.ts',
  'composables/useAdminSession.ts',
  'composables/useAdminSiteConfig.ts',
  'composables/useAdminRealtime.ts',
  'composables/useAdminNavigation.ts',
  'composables/useAdminOperationsCatalog.ts',
  'scripts/openapi-admin-paths.snapshot.json',
]

const requiredComponents = [
  'AdminHeader',
  'AdminSidebar',
  'AdminFooter',
  'AdminLoader',
  'AdminSearchModal',
  'AdminPageHeader',
  'AdminKpiCard',
  'AdminDataTable',
  'AdminStatusBadge',
  'AdminActionDropdown',
  'AdminFormSection',
  'AdminModal',
  'AdminToast',
  'AdminAlert',
  'AdminEmptyState',
  'AdminTimeline',
  'AdminTabs',
  'AdminPagination',
  'AdminPermissionGuard',
  'AdminApiState',
  'AdminFilterBar',
  'AdminDefinitionList',
  'AdminDetailSection',
  'AdminOperationHeader',
  'AdminConfirmAction',
  'AdminMenuTreeEditor',
  'AdminReportPanel',
  'AdminExportPanel',
  'AdminDateRangeFilter',
  'AdminOperationsPage',
  'AdminStockGenerationBatches',
  'AdminStockNumberDetail',
  'AdminStockCoverageSettings',
  'AdminStockPatternCoverage',
  'AdminProtectedContent',
  'AdminWinnersPage',
]

const failures = []

for (const file of requiredFiles) {
  if (!existsSync(join(root, file))) {
    failures.push(`Missing ${file}`)
  }
}

for (const component of requiredComponents) {
  const file = join(root, 'components', `${component}.vue`)
  if (!existsSync(file)) {
    failures.push(`Missing component ${component}`)
  }
}

const requiredStaticAssets = [
  'public/admin-template/assets/libs/bootstrap/css/bootstrap.min.css',
  'public/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js',
  'public/admin-template/assets/css/styles.css',
  'public/admin-template/assets/css/icons.css',
  'public/admin-template/assets/libs/node-waves/waves.min.css',
  'public/admin-template/assets/libs/node-waves/waves.min.js',
  'public/admin-template/assets/libs/simplebar/simplebar.min.css',
  'public/admin-template/assets/libs/simplebar/simplebar.min.js',
  'public/admin-template/assets/js/main.js',
  'public/admin-template/assets/js/defaultmenu.min.js',
  'public/admin-template/assets/js/custom.js',
  'public/admin-template/assets/js/sticky.js',
  'public/admin-template/NOTICE.md',
  'public/brand/siamblend-bo-logo.png',
  'public/brand/siamblend-bo-mark.png',
  'public/brand/siamblend-favicon.ico',
  'public/brand/favicon-32x32.png',
  'public/brand/apple-touch-icon.png',
]

for (const asset of requiredStaticAssets) {
  if (!existsSync(join(root, asset))) {
    failures.push(`Missing static asset ${asset}`)
  }
}

const apiClient = existsSync(join(root, 'composables/useAdminApi.ts'))
  ? readFileSync(join(root, 'composables/useAdminApi.ts'), 'utf8')
  : ''
const adminHostMode = existsSync(join(root, 'composables/useAdminHostMode.ts'))
  ? readFileSync(join(root, 'composables/useAdminHostMode.ts'), 'utf8')
  : ''
const adminSiteConfig = existsSync(join(root, 'composables/useAdminSiteConfig.ts'))
  ? readFileSync(join(root, 'composables/useAdminSiteConfig.ts'), 'utf8')
  : ''
const adminBranding = existsSync(join(root, 'composables/useAdminBranding.ts'))
  ? readFileSync(join(root, 'composables/useAdminBranding.ts'), 'utf8')
  : ''
const adminMiddleware = existsSync(join(root, 'middleware/admin.global.ts'))
  ? readFileSync(join(root, 'middleware/admin.global.ts'), 'utf8')
  : ''
const adminSession = existsSync(join(root, 'composables/useAdminSession.ts'))
  ? readFileSync(join(root, 'composables/useAdminSession.ts'), 'utf8')
  : ''
const loginPage = existsSync(join(root, 'pages/login.vue'))
  ? readFileSync(join(root, 'pages/login.vue'), 'utf8')
  : ''
const adminLayout = existsSync(join(root, 'layouts/admin.vue'))
  ? readFileSync(join(root, 'layouts/admin.vue'), 'utf8')
  : ''
const operationsPage = existsSync(join(root, 'components/AdminOperationsPage.vue'))
  ? readFileSync(join(root, 'components/AdminOperationsPage.vue'), 'utf8')
  : ''
const adminDataTable = existsSync(join(root, 'components/AdminDataTable.vue'))
  ? readFileSync(join(root, 'components/AdminDataTable.vue'), 'utf8')
  : ''
const adminPagination = existsSync(join(root, 'components/AdminPagination.vue'))
  ? readFileSync(join(root, 'components/AdminPagination.vue'), 'utf8')
  : ''
const adminConfirmAction = existsSync(join(root, 'components/AdminConfirmAction.vue'))
  ? readFileSync(join(root, 'components/AdminConfirmAction.vue'), 'utf8')
  : ''
const adminDefinitionList = existsSync(join(root, 'components/AdminDefinitionList.vue'))
  ? readFileSync(join(root, 'components/AdminDefinitionList.vue'), 'utf8')
  : ''
const adminDetailSection = existsSync(join(root, 'components/AdminDetailSection.vue'))
  ? readFileSync(join(root, 'components/AdminDetailSection.vue'), 'utf8')
  : ''
const adminReportPanel = existsSync(join(root, 'components/AdminReportPanel.vue'))
  ? readFileSync(join(root, 'components/AdminReportPanel.vue'), 'utf8')
  : ''
const formatUtils = existsSync(join(root, 'utils/format.ts'))
  ? readFileSync(join(root, 'utils/format.ts'), 'utf8')
  : ''
const adminClientReady = existsSync(join(root, 'composables/useAdminClientReady.ts'))
  ? readFileSync(join(root, 'composables/useAdminClientReady.ts'), 'utf8')
  : ''
const adminSuccessAlert = existsSync(join(root, 'composables/useAdminSuccessAlert.ts'))
  ? readFileSync(join(root, 'composables/useAdminSuccessAlert.ts'), 'utf8')
  : ''
const adminProtectedContent = existsSync(join(root, 'components/AdminProtectedContent.vue'))
  ? readFileSync(join(root, 'components/AdminProtectedContent.vue'), 'utf8')
  : ''
const packageJson = existsSync(join(root, 'package.json'))
  ? readFileSync(join(root, 'package.json'), 'utf8')
  : ''
const nuxtConfig = existsSync(join(root, 'nuxt.config.ts'))
  ? readFileSync(join(root, 'nuxt.config.ts'), 'utf8')
  : ''
const adminFoundationDocPath = join(root, '..', '..', 'docs', 'back-office-admin-foundation.md')
const adminFoundationDoc = existsSync(adminFoundationDocPath)
  ? readFileSync(adminFoundationDocPath, 'utf8')
  : ''
const templateNotice = existsSync(join(root, 'public/admin-template/NOTICE.md'))
  ? readFileSync(join(root, 'public/admin-template/NOTICE.md'), 'utf8')
  : ''
const adminNavigation = existsSync(join(root, 'composables/useAdminNavigation.ts'))
  ? readFileSync(join(root, 'composables/useAdminNavigation.ts'), 'utf8')
  : ''
const tenantSupportPage = existsSync(join(root, 'pages/admin/tenant/support.vue'))
  ? readFileSync(join(root, 'pages/admin/tenant/support.vue'), 'utf8')
  : ''
const adminApiState = existsSync(join(root, 'components/AdminApiState.vue'))
  ? readFileSync(join(root, 'components/AdminApiState.vue'), 'utf8')
  : ''
const tenantMaintenancePage = existsSync(join(root, 'pages/admin/tenant/maintenance.vue'))
  ? readFileSync(join(root, 'pages/admin/tenant/maintenance.vue'), 'utf8')
  : ''
const tenantAnnouncementsPage = existsSync(join(root, 'pages/admin/tenant/announcements.vue'))
  ? readFileSync(join(root, 'pages/admin/tenant/announcements.vue'), 'utf8')
  : ''
const tenantActivitiesPage = existsSync(join(root, 'pages/admin/tenant/activities.vue'))
  ? readFileSync(join(root, 'pages/admin/tenant/activities.vue'), 'utf8')
  : ''
const tenantCustomerNotificationsPage = existsSync(join(root, 'pages/admin/tenant/customer-notifications.vue'))
  ? readFileSync(join(root, 'pages/admin/tenant/customer-notifications.vue'), 'utf8')
  : ''
const adminOperationsCatalog = existsSync(join(root, 'composables/useAdminOperationsCatalog.ts'))
  ? readFileSync(join(root, 'composables/useAdminOperationsCatalog.ts'), 'utf8')
  : ''
const tenantLineNotificationsPage = existsSync(join(root, 'pages/admin/tenant/line-notifications.vue'))
  ? readFileSync(join(root, 'pages/admin/tenant/line-notifications.vue'), 'utf8')
  : ''
const centralDashboardPage = existsSync(join(root, 'pages/admin/central/dashboard/index.vue'))
  ? readFileSync(join(root, 'pages/admin/central/dashboard/index.vue'), 'utf8')
  : ''
const centralDashboardSection = existsSync(join(root, 'components/CentralDashboardSection.vue'))
  ? readFileSync(join(root, 'components/CentralDashboardSection.vue'), 'utf8')
  : ''
const centralDashboardSectionPages = [
  'sales',
  'partner',
  'wallet',
  'payout',
  'monitor',
].map((section) => existsSync(join(root, `pages/admin/central/dashboard/${section}.vue`))
  ? readFileSync(join(root, `pages/admin/central/dashboard/${section}.vue`), 'utf8')
  : '').join('\n')
const adminFoundationCss = existsSync(join(root, 'assets/css/admin-foundation.css'))
  ? readFileSync(join(root, 'assets/css/admin-foundation.css'), 'utf8')
  : ''
const rewardPrizes = existsSync(join(root, 'composables/useRewardPrizes.ts'))
  ? readFileSync(join(root, 'composables/useRewardPrizes.ts'), 'utf8')
  : ''
const adminWinnersPage = existsSync(join(root, 'components/AdminWinnersPage.vue'))
  ? readFileSync(join(root, 'components/AdminWinnersPage.vue'), 'utf8')
  : ''
const tenantWinnersPage = existsSync(join(root, 'pages/admin/tenant/winners/index.vue'))
  ? readFileSync(join(root, 'pages/admin/tenant/winners/index.vue'), 'utf8')
  : ''
const centralWinnersPage = existsSync(join(root, 'pages/admin/central/winners/index.vue'))
  ? readFileSync(join(root, 'pages/admin/central/winners/index.vue'), 'utf8')
  : ''
const adminPathsSnapshot = existsSync(join(root, 'scripts/openapi-admin-paths.snapshot.json'))
  ? readFileSync(join(root, 'scripts/openapi-admin-paths.snapshot.json'), 'utf8')
  : ''
const platformSeederPath = join(root, '..', 'platform-api', 'database', 'seeders', 'DefaultRbacMenuSeeder.php')
const platformSeeder = existsSync(platformSeederPath)
  ? readFileSync(platformSeederPath, 'utf8')
  : ''
const platformRoutesPath = join(root, '..', 'platform-api', 'routes', 'api.php')
const platformRoutes = existsSync(platformRoutesPath)
  ? readFileSync(platformRoutesPath, 'utf8')
  : ''
const platformPermissionServicePath = join(root, '..', 'platform-api', 'app', 'Modules', 'Rbac', 'Services', 'PermissionService.php')
const platformPermissionService = existsSync(platformPermissionServicePath)
  ? readFileSync(platformPermissionServicePath, 'utf8')
  : ''
const platformAdminOperationsServicePath = join(root, '..', 'platform-api', 'app', 'Modules', 'AdminOperations', 'Services', 'AdminOperationsService.php')
const platformAdminOperationsService = existsSync(platformAdminOperationsServicePath)
  ? readFileSync(platformAdminOperationsServicePath, 'utf8')
  : ''
const tenantWinnersBackfillMigrationPath = join(root, '..', 'platform-api', 'database', 'migrations', '2026_05_27_000001_backfill_tenant_winners_owner_menu.php')
const tenantWinnersBackfillMigration = existsSync(tenantWinnersBackfillMigrationPath)
  ? readFileSync(tenantWinnersBackfillMigrationPath, 'utf8')
  : ''
const hasPlatformGuardrailContext = [
  platformSeederPath,
  platformRoutesPath,
  platformPermissionServicePath,
  platformAdminOperationsServicePath,
  tenantWinnersBackfillMigrationPath,
].every((path) => existsSync(path))
const serverAdminGuardStart = adminMiddleware.indexOf('if (import.meta.server)')
const clientAdminRestoreStart = adminMiddleware.indexOf('session.restore()')
const serverAdminGuard =
  serverAdminGuardStart >= 0 && clientAdminRestoreStart > serverAdminGuardStart
    ? adminMiddleware.slice(serverAdminGuardStart, clientAdminRestoreStart)
    : ''

for (const header of ['X-Admin-Scope', 'X-Tenant-Id', 'Idempotency-Key', 'X-Request-Id']) {
  if (!apiClient.includes(header)) {
    failures.push(`API client does not include ${header}`)
  }
}

for (const evidence of [
  ['session cookie marker', adminSession.includes('newpaotang_bo_session') && adminSession.includes('writeSessionCookie') && adminSession.includes('clearSessionCookie')],
  ['stale marker cleanup', adminSession.includes('clearSessionCookie()') && adminSession.includes('sessionStorage.removeItem(storageKey)') && adminSession.includes('!parsed?.accessToken')],
  ['path scope alignment', adminSession.includes('alignScopeForPath') && adminSession.includes('/admin/central') && adminSession.includes('/admin/tenant')],
  ['SSR no-marker login redirect', serverAdminGuard.includes('adminSessionCookieName') && serverAdminGuard.includes("marker.value !== '1'") && serverAdminGuard.includes('loginRedirect(to.fullPath)')],
  ['SSR exact-marker shell bridge', serverAdminGuard.includes('useCookie<string | null>') && serverAdminGuard.includes('decode: (value) => value') && serverAdminGuard.includes('non-sensitive SSR restore shell') && !serverAdminGuard.includes('session.isAuthenticated')],
  ['login redirect preservation', adminMiddleware.includes('loginRedirect(to.fullPath)')],
  ['client auth restore', adminMiddleware.includes('session.restore()') && adminMiddleware.includes('session.alignScopeForPath(to.path)')],
  ['support-only accounts are routed to customer support', adminSession.includes('usesCustomerSupportLanding') && adminSession.includes('standardSupportPermissions') && adminSession.includes("'/admin/tenant/support'") && loginPage.includes('session.usesCustomerSupportLanding(scope)') && adminMiddleware.includes('session.usesCustomerSupportLanding()') && adminMiddleware.includes("to.path !== '/admin/tenant/support'")],
  ['support-only sidebar hides unrelated tenant menus', adminNavigation.includes('customerSupportOnlyMenus') && adminNavigation.includes("item.key === 'customer_support'") && adminNavigation.includes('session.usesCustomerSupportLanding()')],
  ['login safe redirect target', loginPage.includes('safeRedirectTarget') && loginPage.includes('route.query.redirect') && loginPage.includes('isAdminPath') && loginPage.includes('isScopePath')],
  ['partner BO host detection', adminHostMode.includes("const partnerBoPrefix = 'bo.'") && adminHostMode.includes('host.value.startsWith(partnerBoPrefix)') && adminHostMode.includes('storefrontHost')],
  ['partner BO same-origin API base', adminHostMode.includes("? '/api/v1'") && apiClient.includes('hostMode.adminApiBase.value')],
  ['partner BO local .test/.localhost hosts allowed', nuxtConfig.includes("allowedHosts: ['.test', '.localhost']")],
  ['partner BO dev same-origin API proxy preserves host', nuxtConfig.includes("'/api/v1'") && nuxtConfig.includes("target: 'http://platform-api:8000'") && nuxtConfig.includes('changeOrigin: false')],
  ['partner BO dev API proxy normalizes IDN host', nuxtConfig.includes("from 'node:url'") && nuxtConfig.includes('domainToASCII') && nuxtConfig.includes("proxyReq.setHeader('Host', host)")],
  ['partner BO public site config cache', adminSiteConfig.includes('/public/admin-site-config') && adminSiteConfig.includes("useState<AdminSiteConfig | null>('admin-site-config'") && adminSiteConfig.includes("response?.mode === 'partner'") && adminSiteConfig.includes('brand?.logo_url') && adminSiteConfig.includes('site?.display_name')],
  ['partner BO login hides central fields', loginPage.includes('v-if="!isPartnerBoMode"') && loginPage.includes('data-central-login-scope-controls') && loginPage.includes('data-partner-login-tenant-only')],
  ['partner BO login submits tenant scope without tenant id', loginPage.includes("const scope = isPartnerBoMode.value ? 'tenant'") && !loginPage.includes('tenant_id:') && apiClient.includes('const body = partnerMode') && apiClient.includes("scope: 'tenant'") && apiClient.includes('const tenantId = partnerMode ? null')],
  ['partner BO redirect blocks central', loginPage.includes('if (isPartnerBoMode.value)') && loginPage.includes("return isScopePath(target, 'tenant') ? target : ''") && adminSession.includes('hostMode.isPartnerBoHost.value') && adminSession.includes("path.startsWith('/admin/central')") && adminMiddleware.includes("to.path.startsWith('/admin/central')")],
  ['central BO login scope remains without tenant id field', (loginPage.includes('<label class="form-label">Scope</label>') || loginPage.includes("t('common.scope')")) && (loginPage.includes('<option value="central">Central</option>') || loginPage.includes("t('common.central')")) && !loginPage.includes('<label class="form-label">Tenant ID</label>')],
  ['partner BO brand render evidence', loginPage.includes('data-partner-login-brand-name') && loginPage.includes('data-partner-login-brand-logo') && loginPage.includes('adminSiteConfig.displayName') && loginPage.includes('adminSiteConfig.logoUrl')],
  ['central BO Siamblend branding', nuxtConfig.includes('Siamblend Back Office') && nuxtConfig.includes('/brand/siamblend-favicon.ico') && adminBranding.includes("const siamblendSystemName = 'Siamblend'") && adminBranding.includes('/brand/siamblend-bo-logo.png') && adminBranding.includes('/brand/siamblend-bo-mark.png') && loginPage.includes('adminBranding.centralLogoUrl')],
  ['operations client-only load', operationsPage.includes('if (!import.meta.client)') && operationsPage.includes('onMounted(() =>') && operationsPage.includes('!session.isAuthenticated.value')],
  ['successful write alert rule', (!adminFoundationDoc || (adminFoundationDoc.includes('Successful admin API write calls') && adminFoundationDoc.includes('top-level `message`') && adminFoundationDoc.includes('preview rendering must not show a success alert'))) && apiClient.includes('useAdminSuccessAlert') && apiClient.includes('isWriteMethod(method)') && apiClient.includes('options.successMessage !== false') && apiClient.includes('responseSuccessMessage(response)') && !apiClient.includes('successMessageFor(method)') && adminSuccessAlert.includes("import('sweetalert2')") && adminSuccessAlert.includes('Swal.fire') && packageJson.includes('"sweetalert2"') && nuxtConfig.includes('sweetalert2/dist/sweetalert2.min.css') && !adminLayout.includes('AdminAlert v-if="successAlert"')],
]) {
  if (!evidence[1]) {
    failures.push(`Authenticated navigation guardrail missing: ${evidence[0]}`)
  }
}

for (const evidence of [
  ['client readiness state', adminClientReady.includes('admin-client-ready') && adminClientReady.includes('markReady')],
  ['protected shell placeholder', adminLayout.includes('canRenderAdminContent') && adminLayout.includes('AdminProtectedContent') && adminLayout.includes('clientReady.value && session.isAuthenticated.value')],
  ['protected slot hydration wrapper', adminProtectedContent.includes('Restoring admin session') && adminProtectedContent.includes('slots.default?.()') && adminProtectedContent.includes('_isNuxtPageUsed') && adminProtectedContent.includes('import.meta.dev')],
  ['hidden pre-restore menus', adminLayout.includes('visibleMenus') && adminLayout.includes('AdminSearchModal :menus="visibleMenus"')],
  ['tenant maintenance client-only load', tenantMaintenancePage.includes('onMounted(loadAll)') && tenantMaintenancePage.includes('if (!tenantId.value)')],
  ['mobile sidebar shell default closed', adminFoundationCss.includes('@media (max-width: 991.98px)') && adminFoundationCss.includes('.app-sidebar') && adminFoundationCss.includes('transform: translateX(-100%)') && adminFoundationCss.includes("[data-toggled='open'] .app-sidebar")],
  ['mobile content viewport fit', adminFoundationCss.includes('.main-content.app-content') && adminFoundationCss.includes('max-width: 100vw') && adminFoundationCss.includes('.main-content.app-content > .container-fluid') && adminFoundationCss.includes('padding-inline: 0.75rem')],
  ['mobile compact header fit', adminFoundationCss.includes('.app-header .header-logo') && adminFoundationCss.includes('max-width: 9.5rem') && adminFoundationCss.includes('text-overflow: ellipsis')],
  ['template notice blocker', templateNotice.includes('Legal Agreement & Copyright Notice.txt') && templateNotice.includes('not a replacement') && templateNotice.includes('client delivery')],
  ['backend menu icon support', adminNavigation.includes('category?: string') && adminNavigation.includes('safeIcon') && adminNavigation.includes('item.icon')],
  ['support chat visually separates customer messages', tenantSupportPage.includes('data-sender') && tenantSupportPage.includes('np-support-customer-avatar') && tenantSupportPage.includes('.np-support-message-row.is-customer .np-support-bubble') && tenantSupportPage.includes('border: 2px solid rgba(var(--primary-rgb), .5)') && tenantSupportPage.includes('border-inline-start: 4px solid var(--primary-color)') && tenantSupportPage.includes('.np-support-customer-label')],
  ['support role sees only own work and personal report', tenantSupportPage.includes("key: 'mine'") && tenantSupportPage.includes("key: 'reports'") && tenantSupportPage.includes("hasPermission('support_ticket.view_all')") && tenantSupportPage.includes("hasPermission('support_agent.manage')") && tenantSupportPage.includes('canViewTeamReports')],
  ['maintenance bypass list support', tenantMaintenancePage.includes("api.apiFetch('/admin/tenant/maintenance/bypasses'") && tenantMaintenancePage.includes("status: 'active'") && tenantMaintenancePage.includes('bypassMeta') && tenantMaintenancePage.includes('support_session')],
  ['LINE notification edit modal is visible without Bootstrap JS', tenantLineNotificationsPage.includes('templateModalOpen') && tenantLineNotificationsPage.includes('modal fade show d-block np-line-modal')],
  ['LINE notification edit modal stays above its backdrop', tenantLineNotificationsPage.includes('.np-line-modal {\n  z-index: 12010;') && tenantLineNotificationsPage.includes('.np-line-modal-backdrop {\n  z-index: 12000;')],
  ['LINE notification connection save error stays retryable', tenantLineNotificationsPage.includes('lineConnectionSaveError') && tenantLineNotificationsPage.includes('กด Save ใหม่อีกครั้ง') && tenantLineNotificationsPage.includes('savingConnection.value = false')],
  ['LINE notification 422 errors render alerts instead of breaking save state', tenantLineNotificationsPage.includes('const alertType') && tenantLineNotificationsPage.includes('422') && tenantLineNotificationsPage.includes(':message="error.message"')],
  ['LINE notification connection lets tenant configure LIFF ID', tenantLineNotificationsPage.includes('LINE LIFF ID') && tenantLineNotificationsPage.includes('connectionForm.liff_id') && tenantLineNotificationsPage.includes('Used when customers open the storefront from LINE LIFF')],
  ['LINE notification connection can be disconnected from tenant BO', tenantLineNotificationsPage.includes('ยกเลิกการเชื่อมต่อ') && tenantLineNotificationsPage.includes('disconnectConnection') && tenantLineNotificationsPage.includes("method: 'DELETE'") && tenantLineNotificationsPage.includes("'/admin/tenant/line-notifications/connection'")],
  ['LINE notification callback URL uses backend storefront value instead of BO origin', tenantLineNotificationsPage.includes('Customer callback URL') && tenantLineNotificationsPage.includes('connection.value.callback_url') && !tenantLineNotificationsPage.includes('window.location.origin')],
  ['customer notification composer is tenant scoped and idempotent', tenantCustomerNotificationsPage.includes("'/admin/tenant/customer-notifications/customers'") && tenantCustomerNotificationsPage.includes("'/admin/tenant/customer-notifications'") && tenantCustomerNotificationsPage.includes('scope: \'tenant\'') && tenantCustomerNotificationsPage.includes('idempotencyKey: api.idempotencyKey()')],
  ['customer notification composer confirms direct sends and shows read/push history', tenantCustomerNotificationsPage.includes('confirmationOpen') && tenantCustomerNotificationsPage.includes('Confirm notification') && tenantCustomerNotificationsPage.includes('recipient?.is_read') && tenantCustomerNotificationsPage.includes('recipient?.push?.status')],
  ['customer notification history exposes partial multi-device delivery', tenantCustomerNotificationsPage.includes("partial: 'Partially delivered'") && tenantCustomerNotificationsPage.includes('pushCountSummary') && tenantCustomerNotificationsPage.includes('sent_count') && tenantCustomerNotificationsPage.includes('pending_count') && tenantCustomerNotificationsPage.includes('failed_count')],
  ['customer detail links to the composer with a tenant-scoped preselected customer', adminOperationsCatalog.includes("key: 'send-notification'") && adminOperationsCatalog.includes("customer-notifications?customer_id={id}") && tenantCustomerNotificationsPage.includes('route.query.customer_id') && tenantCustomerNotificationsPage.includes('{ customer_id: requestedCustomerId }')],
  ['news customer notification opt-in stays explicit and off by default', tenantAnnouncementsPage.includes('v-model="form.notify_customers"') && tenantAnnouncementsPage.includes('notify_customers: false') && tenantAnnouncementsPage.includes('notify_customers: canNotifyCustomers.value && Boolean(form.notify_customers)')],
  ['activity customer notification opt-in stays explicit and off by default', tenantActivitiesPage.includes('v-model="form.notify_customers"') && tenantActivitiesPage.includes('notify_customers: false') && tenantActivitiesPage.includes('notify_customers: canNotifyCustomers.value && Boolean(form.notify_customers)')],
]) {
  if (!evidence[1]) {
    failures.push(`Production readiness guardrail missing: ${evidence[0]}`)
  }
}

const detailPage = existsSync(join(root, 'pages/admin/tenant/support-access/[id].vue'))
  ? readFileSync(join(root, 'pages/admin/tenant/support-access/[id].vue'), 'utf8')
  : ''

if (!detailPage.includes('oneTimeToken') || detailPage.includes('localStorage.setItem')) {
  failures.push('Support token one-time handling check failed')
}

const operationsCatalog = existsSync(join(root, 'composables/useAdminOperationsCatalog.ts'))
  ? readFileSync(join(root, 'composables/useAdminOperationsCatalog.ts'), 'utf8')
  : ''
const sliceBetween = (source, start, end) => {
  const startIndex = source.indexOf(start)
  if (startIndex === -1) {
    return ''
  }

  const endIndex = source.indexOf(end, startIndex + start.length)
  return endIndex === -1
    ? source.slice(startIndex)
    : source.slice(startIndex, endIndex)
}
const rawStringifyValuePattern = /JSON\.stringify\(\s*value\b/
const displayFormatterSlices = [
  ['AdminOperationsPage formatValue', sliceBetween(operationsPage, 'const formatValue =', 'const formattedCellValue')],
  ['AdminOperationsPage formatCustomerValue', sliceBetween(operationsPage, 'const formatCustomerValue =', 'const formatCustomerNameValue')],
  ['AdminConfirmAction formatContextValue', sliceBetween(adminConfirmAction, 'const formatContextValue =', 'const contextLabel')],
  ['AdminReportPanel report formatter', adminReportPanel.includes('formatReportValue')
    ? sliceBetween(adminReportPanel, 'formatReportValue', '</script>')
    : adminReportPanel],
]
const menuCompletionDocPath = join(root, '..', '..', 'docs', 'back-office-menu-completion.md')
const menuCompletionDoc = existsSync(menuCompletionDocPath)
  ? readFileSync(menuCompletionDocPath, 'utf8')
  : ''

for (const evidence of [
  ['AdminReportPanel removed raw payload label', !adminReportPanel.includes('Raw report payload')],
  ['AdminReportPanel removed raw JSON fallback block', !adminReportPanel.includes('<pre v-else class="np-admin-json')],
  ['AdminReportPanel removed props.data JSON stringify display', !adminReportPanel.includes('JSON.stringify(props.data')],
  ['AdminReportPanel uses readable report formatter', adminReportPanel.includes('formatAdminValue(') || adminReportPanel.includes('formatMoney(') || adminReportPanel.includes('formatReportValue(')],
  ['AdminReportPanel formatter has no raw JSON.stringify(value) fallback', !rawStringifyValuePattern.test(adminReportPanel)],
  ['AdminDataTable default cell removed raw interpolation', !adminDataTable.includes("{{ row[column.key] ?? '-' }}")],
  ['AdminDataTable default cell uses readable formatter', adminDataTable.includes('formatAdminValue(') && adminDataTable.includes('formatCell(row, column)')],
  ['Operations catalog hides minor-unit wording from users', !/minor units|smallest currency unit/i.test(operationsCatalog)],
  ['AdminOperationsPage money payload conversion stores minor units', operationsPage.includes('Math.round(Number(value) * 100)')],
  ['AdminOperationsPage or shared formatter displays minor-unit money as baht', (operationsPage.includes('/ 100') && operationsPage.includes('บาท')) || (formatUtils.includes('/ 100') && formatUtils.includes('บาท'))],
  ['AdminConfirmAction money initial/display converts and labels baht', adminConfirmAction.includes('/ 100') && adminConfirmAction.includes('formatMoney') && (adminConfirmAction.includes('บาท') || formatUtils.includes('บาท'))],
]) {
  if (!evidence[1]) {
    failures.push(`BO readable display guardrail missing: ${evidence[0]}`)
  }
}

for (const [sliceName, source] of displayFormatterSlices) {
  if (rawStringifyValuePattern.test(source)) {
    failures.push(`BO readable display guardrail failed: ${sliceName} must not use JSON.stringify(value) for read-only display`)
  }
}

const priceRuleUpdateFields = sliceBetween(operationsCatalog, 'const priceRuleUpdateFields', 'const centralSalePriceRuleFields')
const billingPlanCreateFields = sliceBetween(operationsCatalog, 'const billingPlanFields', 'const billingPlanUpdateFields')
const billingPlanUpdateFields = sliceBetween(operationsCatalog, 'const billingPlanUpdateFields', 'const alertPolicyFields')
const refundAction = sliceBetween(operationsCatalog, "key: 'refund'", "key: 'customers'")
const adminUserColumnsSlice = sliceBetween(operationsCatalog, 'const adminUserColumns', 'const roleColumns')
const roleColumnsSlice = sliceBetween(operationsCatalog, 'const roleColumns', 'const genericColumns')
const roleIdsFieldSlice = sliceBetween(operationsCatalog, 'const roleIdsField', 'const permissionsField')
const permissionsFieldSlice = sliceBetween(operationsCatalog, 'const permissionsField', 'const adminUserCreateFields')
const adminUserResourceSlice = sliceBetween(operationsCatalog, 'function adminUserResource', 'function roleManagementResource')
const roleManagementResourceSlice = sliceBetween(operationsCatalog, 'function roleManagementResource', 'function growthColumns')

for (const evidence of [
  ['partner payout amount uses whole-baht reward money form source', priceRuleUpdateFields.includes("key: 'partner_payout_amount'") && priceRuleUpdateFields.includes("type: 'reward-money'") && priceRuleUpdateFields.includes("sourceKey: 'partner_payout_amount.amount'") && priceRuleUpdateFields.includes('step: 1')],
  ['billing plan create monthly fee uses baht money field', billingPlanCreateFields.includes("key: 'monthly_fee_amount'") && billingPlanCreateFields.includes("type: 'money'") && billingPlanCreateFields.includes('step: 0.01')],
  ['billing plan update monthly fee uses baht money field', billingPlanUpdateFields.includes("key: 'monthly_fee_amount'") && billingPlanUpdateFields.includes("type: 'money'") && billingPlanUpdateFields.includes('step: 0.01')],
  ['refund action uses baht money helper', refundAction.includes("bahtMoneyFields('amount', 'Refund amount'") && !refundAction.includes("moneyFields('amount', 'Refund amount'")],
]) {
  if (!evidence[1]) {
    failures.push(`BO money form guardrail missing: ${evidence[0]}`)
  }
}

for (const evidence of [
  ['admin user Role ID field is a role-name select that submits role_ids array', roleIdsFieldSlice.includes("label: 'Role'") && roleIdsFieldSlice.includes("type: 'select'") && roleIdsFieldSlice.includes('optionSource: roleOptionSource(scope)') && roleIdsFieldSlice.includes('submitAsArray: true') && !roleIdsFieldSlice.includes("type: 'lines'")],
  ['role permissions are checkbox group with readable labels', permissionsFieldSlice.includes("label: 'Permissions'") && permissionsFieldSlice.includes("type: 'checkbox-group'") && permissionsFieldSlice.includes('permissionOptionsForScope(scope)') && !permissionsFieldSlice.includes("type: 'lines'")],
  ['admin users table supports client sorting by created_at desc', adminUserColumnsSlice.includes("key: 'created_at'") && adminUserResourceSlice.includes('clientSort: true') && adminUserResourceSlice.includes("defaultSort: { key: 'created_at', direction: 'desc' }")],
  ['roles table supports client sorting by created_at desc', roleColumnsSlice.includes("key: 'created_at'") && roleManagementResourceSlice.includes('clientSort: true') && roleManagementResourceSlice.includes("defaultSort: { key: 'created_at', direction: 'desc' }")],
  ['roles table hides permissions column and relies on detail view', !roleColumnsSlice.includes("key: 'permissions'") && roleManagementResourceSlice.includes('detailFromList: true') && operationsPage.includes('loadDetailFromList')],
  ['roles detail renders permissions as readonly checklist from catalog options', operationsCatalog.includes("type?: 'text' | 'status' | 'datetime' | 'money' | 'reward-money' | 'json' | 'customer' | 'customer_name' | 'number' | 'image' | 'boolean' | 'percent' | 'array' | 'object-summary' | 'permission-list'") && operationsCatalog.includes('options?: OperationOption[]') && operationsCatalog.includes('const roleDetailFields = (scope: AdminScope)') && operationsCatalog.includes("options: permissionOptionsForScope(scope)") && operationsPage.includes(':fields=\"resource.detailFields || []\"') && adminDetailSection.includes('fields?: OperationColumn[]') && adminDefinitionList.includes('np-permission-checklist') && adminDefinitionList.includes('type=\"checkbox\"') && adminDefinitionList.includes('disabled')],
  ['admin user and role create/update reasons are optional', adminUserResourceSlice.includes('optionalReason: true') && roleManagementResourceSlice.includes('optionalReason: true')],
  ['admin role option sources load from roles endpoints', operationsCatalog.includes("'central-admin-roles'") && operationsCatalog.includes("'tenant-admin-roles'") && operationsPage.includes("api.apiFetch('/admin/central/roles'") && operationsPage.includes("api.apiFetch('/admin/tenant/roles'") && operationsPage.includes('normalizeRoleOptions')],
  ['checkbox group form serializes arrays for permissions', adminConfirmAction.includes("field.type === 'checkbox-group'") && operationsPage.includes("field.type === 'checkbox-group'") && operationsPage.includes('submitAsArray')],
]) {
  if (!evidence[1]) {
    failures.push(`Administration BO guardrail missing: ${evidence[0]}`)
  }
}

for (const route of [
  "slug: 'stock'",
  "'payment-settings'",
  "'partners'",
  "'settlements'",
  "slug: 'reports'",
  'detailApiGap',
]) {
  if (!operationsCatalog.includes(route)) {
    failures.push(`Operations catalog does not include ${route}`)
  }
}

if (operationsCatalog.includes('/admin/tenant/growth/')) {
  failures.push('Operations catalog uses undocumented /admin/tenant/growth/* API endpoints')
}

for (const helper of ['resource', 'editableResource', 'actionResource', 'growthColumns', 'settingsResource', 'summaryResource', 'reportIndex']) {
  if (!operationsCatalog.includes(`function ${helper}`)) {
    failures.push(`Operations catalog helper must be a hoisted function declaration: ${helper}`)
  }
}

for (const routeSlug of [
  "'growth/agents'",
  "'growth/agent-quotas'",
]) {
  if (!operationsCatalog.includes(routeSlug)) {
    failures.push(`Tenant growth frontend route grouping missing ${routeSlug}`)
  }
}

for (const [routeKey, route] of [
  ['central:rewards', '/admin/central/rewards'],
  ['central:reward_payout_rules', '/admin/central/reward-payout-rules'],
  ['central:stock_generation', '/admin/central/stock-generation'],
  ['central:stock_settings', '/admin/central/stock-settings'],
  ['central:stock_pattern_coverage', '/admin/central/stock-pattern-coverage'],
  ['central:reports', '/admin/central/reports'],
  ['central:settlement', '/admin/central/settlements'],
  ['central:partner_monitoring', '/admin/central/partner-monitoring'],
  ['central:partner_usage', '/admin/central/partner-usage'],
  ['central:billing_plans', '/admin/central/billing-plans'],
  ['central:alert_policies', '/admin/central/alert-policies'],
  ['central:alert_events', '/admin/central/alert-events'],
  ['central:webhook_logs', '/admin/central/webhook-logs'],
  ['central:audit_logs', '/admin/central/audit-logs'],
  ['central:admin_users', '/admin/central/admin-users'],
  ['central:roles_permissions', '/admin/central/roles'],
  ['central:menu_management', '/admin/central/menu-management'],
  ['central:system_settings', '/admin/central/system-settings'],
  ['tenant:price_rules', '/admin/tenant/price-rules'],
  ['tenant:customers', '/admin/tenant/customers'],
  ['tenant:agent_quotas', '/admin/tenant/growth/agent-quotas'],
  ['tenant:monitoring', '/admin/tenant/monitoring'],
  ['tenant:usage', '/admin/tenant/usage'],
  ['tenant:reports', '/admin/tenant/reports'],
  ['tenant:sync_logs', '/admin/tenant/sync-logs'],
  ['tenant:audit_logs', '/admin/tenant/audit-logs'],
  ['tenant:admin_users', '/admin/tenant/admin-users'],
  ['tenant:roles_permissions', '/admin/tenant/roles'],
  ['tenant:menu_management', '/admin/tenant/menu-management'],
]) {
  if (!adminNavigation.includes(`'${routeKey}': '${route}'`)) {
    failures.push(`Menu completion route override missing ${routeKey} -> ${route}`)
  }
}

for (const requiredResource of [
  "'admin-users'",
  "'roles'",
  "'menu-management'",
  "'partner-monitoring'",
  "'partner-usage'",
  "'billing-plans'",
  "'alert-policies'",
  "'alert-events'",
  "'webhook-logs'",
  "'system-settings'",
  "'stock-settings'",
  "'stock-pattern-coverage'",
  "'price-rules'",
  "'customers'",
  "'growth/affiliate-programs'",
  "'growth/affiliate-links'",
  "'growth/attributions'",
  "'growth/affiliates'",
  "'growth/commission-rules'",
  "'growth/commission-transactions'",
  "'growth/payouts'",
  "'monitoring'",
  "'usage'",
]) {
  if (!operationsCatalog.includes(requiredResource)) {
    failures.push(`Menu completion catalog route missing ${requiredResource}`)
  }
}

const affiliateAccountForm = sliceBetween(operationsCatalog, 'const affiliateAccountCreateFields', 'const affiliateAccountUpdateFields')
const affiliateLinkForm = sliceBetween(operationsCatalog, 'const affiliateLinkCreateFields', 'const affiliateLinkUpdateFields')
const commissionRuleForm = sliceBetween(operationsCatalog, 'const commissionRuleCreateFields', 'const commissionRuleUpdateFields')
const payoutResource = sliceBetween(operationsCatalog, "slug: 'growth/payouts'", "summaryResource('tenant', 'monitoring'")
const walletResource = sliceBetween(operationsCatalog, "slug: 'wallets'", "...actionResource('tenant', 'topups'")
for (const evidence of [
  ['affiliate account form uses customer selector', affiliateAccountForm.includes('customerSelectField()') && operationsCatalog.includes("optionSource: 'tenant-customers'")],
  ['affiliate account form omits generated code/json inputs', !affiliateAccountForm.includes("key: 'code'") && !affiliateAccountForm.includes("type: 'json'") && !affiliateAccountForm.includes('Payout profile JSON') && !affiliateAccountForm.includes('Metadata JSON')],
  ['affiliate account form uses payout method and bank fields', affiliateAccountForm.includes('affiliatePayoutProfileFields') && operationsCatalog.includes('payout_profile.bank_account.bank_name') && operationsCatalog.includes('payout_profile.bank_account.account_number')],
  ['affiliate link form follows the account tier and omits program/code/url/json inputs', affiliateLinkForm.includes('affiliateSelectField()') && !affiliateLinkForm.includes('affiliateProgramSelectField') && !affiliateLinkForm.includes("key: 'code'") && !affiliateLinkForm.includes("key: 'url'") && !affiliateLinkForm.includes("type: 'json'")],
  ['commission rule form uses selectors enums and baht amount', commissionRuleForm.includes('affiliateProgramSelectField') && commissionRuleForm.includes('affiliateSelectField') && commissionRuleForm.includes("key: 'rule_type'") && commissionRuleForm.includes('commissionRuleTypeOptions') && commissionRuleForm.includes("bahtMoneyFields('amount'") && !commissionRuleForm.includes("type: 'json'") && !commissionRuleForm.includes('Amount (minor units)')],
  ['affiliate detail views use curated fields', operationsCatalog.includes('detailFields: affiliateProgramDetailFields') && operationsCatalog.includes('detailFields: affiliateAccountDetailFields') && operationsCatalog.includes('detailFields: affiliateLinkDetailFields') && operationsCatalog.includes('detailFields: affiliateAttributionDetailFields') && operationsCatalog.includes('detailFields: commissionRuleDetailFields') && operationsCatalog.includes('detailFields: commissionTransactionDetailFields') && operationsCatalog.includes('detailFields: payoutDetailFields') && operationsPage.includes('detailSectionRecord')],
  ['affiliate generated referral URL rendered readonly', operationsCatalog.includes("canonical_url', label: 'Referral URL'") && operationsCatalog.includes("fallbackKeys: ['referral_url', 'url']") && operationsCatalog.includes("fallbackKeys: ['url']") && !operationsCatalog.includes('/a/{CODE}')],
  ['affiliate option source loaders present', operationsCatalog.includes("'tenant-customers'") && operationsCatalog.includes("'tenant-affiliates'") && operationsCatalog.includes("'tenant-affiliate-programs'") && operationsPage.includes("api.apiFetch('/admin/tenant/members'") && operationsPage.includes("api.apiFetch('/admin/tenant/affiliates'") && operationsPage.includes("api.apiFetch('/admin/tenant/affiliate-programs'")],
  ['affiliate payout form uses baht amount method select and bank fields', payoutResource.includes("bahtMoneyFields('amount', 'Payout amount'") && payoutResource.includes("key: 'payout_method'") && payoutResource.includes("type: 'select'") && payoutResource.includes('bank_account.bank_name') && payoutResource.includes('bank_account.account_number') && !payoutResource.includes("type: 'json'")],
  ['affiliate table is sortable with visitor and registered counts', operationsCatalog.includes("slug: 'growth/affiliates'") && operationsCatalog.includes("apiSort: true") && operationsCatalog.includes("key: 'visitor_count'") && operationsCatalog.includes("key: 'registered_count'") && operationsCatalog.includes("key: 'customer_name'")],
]) {
  if (!evidence[1]) {
    failures.push(`Affiliate BO usability guardrail missing: ${evidence[0]}`)
  }
}

for (const evidence of [
  ['API gap state render', operationsPage.includes('resource.apiGap') && operationsPage.includes(':message="resource.apiGap"')],
  ['API gap load guard', operationsPage.includes('resource.value.apiGap')],
  ['summary route render', operationsPage.includes("mode === 'summary'") && operationsCatalog.includes("mode: 'summary'")],
  ['central dashboard operational analytics workflow', centralDashboardPage.includes('/admin/central/dashboard/sales') && centralDashboardSectionPages.includes('section="sales"') && centralDashboardSectionPages.includes('section="partner"') && centralDashboardSectionPages.includes('section="wallet"') && centralDashboardSectionPages.includes('section="payout"') && centralDashboardSectionPages.includes('section="monitor"') && centralDashboardSection.includes('Payment methods') && centralDashboardSection.includes('Wallet money flow') && centralDashboardSection.includes('Payout trend') && centralDashboardSection.includes('Online admins and owner partners') && centralDashboardSection.includes('periodOptions') && (!hasPlatformGuardrailContext || (platformAdminOperationsService.includes('centralDashboardSection') && platformAdminOperationsService.includes('centralSalesDashboard') && platformAdminOperationsService.includes('centralPartnerDashboard') && platformAdminOperationsService.includes('centralWalletDashboard') && platformAdminOperationsService.includes('centralPayoutDashboard') && platformAdminOperationsService.includes('centralMonitorDashboard')))],
  ['detail JSON update editor', operationsPage.includes('resource.detailJsonEditor') && operationsPage.includes('saveDetailDraft')],
  ['JSON payload action support', operationsPage.includes('buildActionBody') && operationsCatalog.includes('payloadTemplate') && adminConfirmAction.includes('Payload JSON')],
  ['P1 typed action forms', operationsCatalog.includes('formFields') && operationsPage.includes('buildPayloadFromFields') && adminConfirmAction.includes('formFields')],
  ['P1 related list support', operationsCatalog.includes('relatedLists') && operationsPage.includes('loadRelatedLists') && operationsPage.includes('openRelatedDetail')],
  ['P1 payment channel workflow', operationsCatalog.includes('/admin/tenant/payment-channels') && operationsCatalog.includes("settingsFields") && operationsCatalog.includes("title: 'Payment Channels'")],
  ['P1 wallet ledger workflow', walletResource.includes('/admin/tenant/wallets/{wallet_id}/ledger') && walletResource.includes("title: 'Wallet Ledger'") && walletResource.includes("key: 'amount', label: 'Amount', type: 'money'") && walletResource.includes("key: 'balance_after', label: 'Balance after', type: 'money'") && !walletResource.includes("key: 'amount.amount', label: 'Amount', type: 'money'") && !walletResource.includes("key: 'balance_after.amount', label: 'Balance after', type: 'money'")],
  ['P1 tenant order nested customer context', operationsCatalog.includes("type?: 'text' | 'status' | 'datetime' | 'money' | 'reward-money' | 'json' | 'customer'") && operationsCatalog.includes('fallbackKeys?: string[]') && operationsCatalog.includes('const orderActionContext') && operationsCatalog.includes("'customer.id'") && operationsCatalog.includes("'customer.name'") && operationsCatalog.includes("'customer.phone'") && operationsCatalog.includes("type: 'customer'")],
  ['P1 tenant topup nested customer context', operationsCatalog.includes('const topupActionContext') && operationsCatalog.includes("'member_id'") && operationsCatalog.includes("'amount.currency'") && operationsCatalog.includes("'channel'") && operationsCatalog.includes("contextFields: topupActionContext")],
  ['P2 partner typed workflows', operationsCatalog.includes('const partnerCreateFields') && operationsCatalog.includes('const partnerProvisionFields') && operationsCatalog.includes("endpoint: '/admin/central/partners/{partner_id}/suspend'") && operationsCatalog.includes("formFields: partnerProvisionFields")],
  ['P2 billing alert typed workflows', operationsCatalog.includes('sourceKey?: string') && operationsCatalog.includes('const billingPlanFields') && operationsCatalog.includes('const billingPlanUpdateFields') && operationsCatalog.includes('const alertPolicyFields') && operationsCatalog.includes('const alertEventActionContext') && operationsCatalog.includes("formFields: billingPlanFields") && operationsCatalog.includes("formFields: alertPolicyFields")],
  ['P3 central stock game selector workflows', operationsCatalog.includes("export type OperationOptionSource = 'central-games'") && operationsCatalog.includes('const gameSelectField') && operationsCatalog.includes('const gameSelectFilter') && operationsPage.includes("api.apiFetch('/admin/central/games'") && operationsPage.includes('hydrateFields') && operationsPage.includes('hydratedCollectionActions')],
  ['P3 stock manager old draw read-only workflow', operationsCatalog.includes('optionalReason: true') && operationsCatalog.includes('Generate or top up virtual stock only for the current open draw.') && operationsPage.includes('stockManagerSelectedOldGame') && operationsPage.includes('stockManagerWriteBlocked') && operationsPage.includes('isStockImportAction') && operationsPage.includes('isCentralStockRecallAction') && operationsPage.includes('isOldStockRow') && operationsPage.includes('Old draw stock is read-only') && operationsPage.includes('This old draw is read-only')],
  ['P3 central stock grouped duplicate workflow', operationsCatalog.includes('stockGrouped?: boolean') && operationsCatalog.includes('defaultQuery: { grouped: true }') && operationsCatalog.includes("key: 'number'") && operationsPage.includes('openStockNumberDetail') && operationsPage.includes('AdminStockNumberDetail') && operationsPage.includes('/numbers/') && (adminPagination.includes('Page {{ currentPage }}') || (adminPagination.includes("phrase('Page')") && adminPagination.includes('{{ currentPage }}')))],
  ['central stock table realtime workflow', operationsPage.includes('private-admin.central.stock.table.game') && operationsPage.includes("eventName: 'stock.table.updated'") && operationsPage.includes('showStockTableRealtimePanel') && operationsPage.includes('Stock table realtime') && operationsPage.includes('stockTableRealtimeEnabled') && operationsPage.includes('stockTableRealtimeStatusLabel') && operationsPage.includes('Select a game to show stock summary widgets and enable live table updates.') && operationsPage.includes('<template #beforeTable>') && adminDataTable.includes('<slot name="beforeTable" />') && operationsPage.includes('handleStockTableRealtimeEvent') && operationsPage.includes('handleStockTableRealtimeReconnect') && operationsPage.includes('reloadStockTableFromRealtime') && operationsPage.includes('stockTableRealtimeRowRequiresReload') && operationsPage.includes('mergeStockTableRealtimeRow') && operationsPage.includes('refreshStockSummaryWidgets') && operationsPage.includes('useAdminRealtimeSubscription')],
  ['stock manager consolidated menu workflow', operationsCatalog.includes("'central:stock-generation': { target: 'stock', title: 'Stock Manager' }") && operationsCatalog.includes("'central:master-stock': { target: 'stock', title: 'Stock Manager' }") && adminNavigation.includes("new Set(['master_stock', 'partner_quotas', 'stock_recall', 'partner_provisioning'])") && adminNavigation.includes("item.key === 'stock_generation' ? 'Stock Manager' : item.key === 'local_stock' ? 'Tenant Stock' : item.key === 'partners' ? 'Partner/Tenant' : item.label") && !adminNavigation.includes("'central:master_stock': '/admin/central/master-stock'") && !adminNavigation.includes("'central:stock_recall': '/admin/central/stock-recall'")],
  ['P3 stock coverage settings workflow', operationsCatalog.includes("slug: 'stock-settings'") && operationsCatalog.includes("slug: 'stock-pattern-coverage'") && operationsPage.includes('isStockSettingsRoute') && operationsPage.includes('AdminStockCoverageSettings') && operationsPage.includes('AdminStockPatternCoverage') && readFileSync(join(root, 'components/AdminStockCoverageSettings.vue'), 'utf8').includes('stock_pattern_coverage_default') && readFileSync(join(root, 'components/AdminStockPatternCoverage.vue'), 'utf8').includes('/admin/central/stock/limit-settings') && readFileSync(join(root, 'components/AdminStockPatternCoverage.vue'), 'utf8').includes('/admin/central/stock/limit-overrides')],
  ['allocation partner percent BO workflow', operationsCatalog.includes("'allocation-partners'") && operationsCatalog.includes('/admin/central/allocations/partner-percent') && operationsCatalog.includes('/admin/central/allocations/open-all-partners') && operationsCatalog.includes("key: 'open-all-partners'") && operationsCatalog.includes('allocation-partner-percent-list') && operationsCatalog.includes('/admin/central/allocations/{allocation_id}/recall-all') && operationsCatalog.includes('/admin/central/allocations/{allocation_id}/redistribute') && operationsCatalog.includes("enabledStatuses: ['recalled']") && operationsCatalog.includes('allocationPercentField') && operationsPage.includes('/admin/central/allocation-options/partners') && operationsPage.includes('/admin/central/allocation-options/tenants') && operationsPage.includes('/admin/central/allocation-options/games') && operationsPage.includes('routeFilterValues') && adminConfirmAction.includes('Allocation preview') && adminConfirmAction.includes('bulkAllocationRemainingPercent') && readFileSync(join(root, 'components/AdminFilterBar.vue'), 'utf8').includes('visibleOptions(filter)') && readFileSync(join(root, 'components/AdminStockPatternCoverage.vue'), 'utf8').includes('applyRouteDefaults')],
  ['retired physical stock BO workflow', operationsCatalog.includes("apiGapResource('central', 'partner-quotas'") && operationsCatalog.includes('Partner Quotas is retired') && !operationsCatalog.includes("endpoint: '/admin/central/partner-quotas'") && !operationsCatalog.includes("endpoint: '/admin/central/partner-quotas/{quota_id}'") && !operationsCatalog.includes('partnerQuotaCreateFields') && !operationsCatalog.includes('partnerQuotaUpdateFields') && !operationsCatalog.includes('requested_count') && adminNavigation.includes('retiredCentralMenuKeys') && !adminNavigation.includes("'central:partner_quotas':") && apiClient.includes('retired_flow') && adminApiState.includes('retired_flow') && operationsPage.includes("generation_mode: 'virtual_profile'") && operationsPage.includes('delete next.total_count') && operationsPage.includes('delete next.number_digits') && operationsCatalog.includes("route: adminUiRoute('central', 'stock-generation?game_id={game_id}&partner_id={partner_id}&tenant_id={tenant_id}&allocation_id={id}&status=allocated')")],
  ['retired tenant stock sync workflow', adminNavigation.includes("retiredTenantMenuKeys = new Set(['stock_sync'])") && !operationsCatalog.includes("slug: 'stock-sync'") && !operationsCatalog.includes('/admin/tenant/stock-sync/batches')],
  ['tenant winners partner menu stays in Store Operations', !hasPlatformGuardrailContext || (platformSeeder.includes("'tenant:winners' => '/admin/tenant/winners'") && platformSeeder.includes("'tenant:winners',\n            'tenant:payment_settings' => 'Store Operations'") && platformSeeder.includes("'winners' => 'reward_claim.view'") && platformSeeder.includes('grantTenantWinnerMenuToPartnerOwners') && platformSeeder.includes("whereIn('code', ['owner_partner', 'owner'])") && platformPermissionService.includes('tenantOwnerRewardClaimPermission') && platformPermissionService.includes("whereIn('roles.code', ['owner', 'owner_partner'])") && tenantWinnersBackfillMigration.includes("where('scope_type', 'tenant')") && tenantWinnersBackfillMigration.includes("where('code', 'winners')") && tenantWinnersBackfillMigration.includes("'category' => 'Store Operations'") && tenantWinnersBackfillMigration.includes("whereIn('code', ['owner', 'owner_partner'])"))],
  ['tenant exchange reward approval menu exists', (!hasPlatformGuardrailContext || (platformSeeder.includes("'exchange_reward' => 'reward_claim.view'") && platformSeeder.includes("'tenant:exchange_reward' => '/admin/tenant/exchange-reward'"))) && adminNavigation.includes("'tenant:exchange_reward': '/admin/tenant/exchange-reward'") && operationsCatalog.includes("slug: 'exchange-reward'") && operationsCatalog.includes("title: 'Exchange Reward'") && operationsCatalog.includes("title: 'Pending Exchange Requests'") && operationsCatalog.includes("title: 'Exchange Reward History'") && operationsCatalog.includes("defaultQuery: { section: 'pending' }") && operationsCatalog.includes("defaultSort: { key: 'submitted_at', direction: 'asc' }") && operationsCatalog.includes("defaultQuery: { section: 'history' }") && operationsCatalog.includes("defaultSort: { key: 'updated_at', direction: 'desc' }") && operationsCatalog.includes("endpoint: '/admin/tenant/reward-claims/{claim_id}/approve'") && operationsCatalog.includes("optionalReason: true, enabledStatuses: ['submitted', 'under_review']") && !operationsCatalog.includes("endpoint: '/admin/tenant/reward-claims/{claim_id}/pay'") && operationsPage.includes('private-admin.tenant.${session.currentTenantId.value}.reward-claims') && operationsPage.includes("eventName: 'reward.claim.updated'") && operationsPage.includes('handleTenantRewardClaimRealtimeEvent') && operationsPage.includes('rewardClaimBelongsToSection') && operationsPage.includes('rewardClaimMatchesSectionFilters')],
  ['tenant winners partner route and shared page exist', adminNavigation.includes("'tenant:winners': '/admin/tenant/winners'") && tenantWinnersPage.includes('scope="tenant"') && centralWinnersPage.includes('scope="central"') && adminWinnersPage.includes('props.scope') && adminWinnersPage.includes('`/admin/${pageScope.value}/winners`')],
  ['tenant winners API endpoints are registered and snapshotted', (!hasPlatformGuardrailContext || (platformRoutes.includes("Route::get('/admin/tenant/winners/games'") && platformRoutes.includes("Route::get('/admin/tenant/winners'"))) && adminPathsSnapshot.includes('"/admin/tenant/winners"') && adminPathsSnapshot.includes('"/admin/tenant/winners/games"')],
  ['winners table includes customer number for central and tenant page', operationsCatalog.includes("{ key: 'customer_no', label: 'Customer no' }") && adminWinnersPage.includes("key: 'customer_no'")],
  ['central winners includes realtime reward results table', adminWinnersPage.includes('Realtime reward results') && adminWinnersPage.includes('livePrizeRows') && adminWinnersPage.includes('mergeLiveResults') && adminWinnersPage.includes('formatLivePrizeMoney') && adminWinnersPage.includes("pageScope === 'central'")],
  ['customer detail includes order history related table', operationsCatalog.includes("key: 'order-histories'") && operationsCatalog.includes("title: 'Order Histories'") && operationsCatalog.includes("listEndpoint: '/admin/tenant/orders'") && operationsCatalog.includes("defaultQuery: { customer_id: '{member_id}' }") && operationsCatalog.includes("detailRenderer: 'order'") && operationsPage.includes('interpolateQuery(related.defaultQuery') && operationsPage.includes("relatedDetail.renderer === 'order'")],
  ['P3 API sortable data table', readFileSync(join(root, 'components/AdminDataTable.vue'), 'utf8').includes('sortChange') && readFileSync(join(root, 'components/AdminDataTable.vue'), 'utf8').includes('aria-sort') && readFileSync(join(root, 'components/AdminDataTable.vue'), 'utf8').includes('sortable') && operationsCatalog.includes('apiSort?: boolean') && operationsPage.includes('sort_by') && operationsPage.includes('applySort')],
  ['P3 reward report log workflows', operationsCatalog.includes("'reward-prize-number-grid'") && operationsCatalog.includes("'reward-prize-amount-grid'") && operationsCatalog.includes('detailRenderer?:') && operationsCatalog.includes("detailRenderer: 'reward'") && operationsCatalog.includes('const rewardCreateFields') && operationsCatalog.includes('const rewardNumberUpdateFields') && operationsCatalog.includes('const rewardPayoutUpdateFields') && operationsCatalog.includes('Update winning numbers') && operationsCatalog.includes('Update payout amounts') && operationsPage.includes('AdminRewardPrizes') && operationsPage.includes('rewardPrizeGroupsToPayload') && adminConfirmAction.includes('np-reward-prize-editor') && existsSync(join(root, 'components/AdminRewardPrizes.vue')) && operationsCatalog.includes('const settlementActionContext') && operationsCatalog.includes('const reportExportContext') && operationsCatalog.includes('function reportExportFields') && operationsPage.includes('buildCollectionContext') && adminReportPanel.includes('Report rows')],
  ['reward number updates keep blank rows so API can mark pending results', rewardPrizes.includes('.filter((group) => group.prize_numbers.length > 0)') && rewardPrizes.includes('group.numbers.length > 0') && !rewardPrizes.includes("number !== '' && !number.startsWith('pending_')")],
  ['P3 tenant sync processed filter', operationsCatalog.includes("slug: 'sync-logs'") && operationsCatalog.includes("statusFilter(['pending', 'running', 'completed', 'processed', 'failed'])")],
  ['P4 administration security settings workflows', operationsCatalog.includes('function adminUserResource') && operationsCatalog.includes('function roleManagementResource') && operationsCatalog.includes('const adminUserCreateFields') && operationsCatalog.includes('const roleCreateFields') && operationsCatalog.includes('const tenantSettingsFields') && operationsCatalog.includes('const tenantThemeFields') && operationsCatalog.includes('const tenantDomainCreateFields') && operationsCatalog.includes("secondarySettings") && operationsPage.includes('isMenuManagement') && operationsPage.includes('saveMenuTree') && operationsPage.includes('loadSecondarySettings') && existsSync(join(root, 'components/AdminMenuTreeEditor.vue')) && readFileSync(join(root, 'components/AdminMenuTreeEditor.vue'), 'utf8').includes('Save menu')],
  ['tenant customer logo and PWA icon uploads', operationsCatalog.includes("'image-upload'") && operationsCatalog.includes("uploadPurpose: 'tenant_logo'") && operationsCatalog.includes("uploadPurpose: 'tenant_favicon'") && operationsPage.includes("'/admin/tenant/assets/uploads'") && operationsPage.includes('uploadSecondaryAsset') && operationsPage.includes('panel.updateEndpoint')],
  ['tenant legal terms settings workflow', operationsCatalog.includes('defaultTermsContentPlaceholder') && operationsCatalog.includes("key: 'legal.terms_content'") && operationsCatalog.includes("sourceKey: 'legal.terms_content'") && operationsCatalog.includes("label: 'Terms and conditions'")],
  ['tenant announcements use create/edit modal workflow', tenantAnnouncementsPage.includes('formModalOpen') && tenantAnnouncementsPage.includes('openCreateModal') && tenantAnnouncementsPage.includes('openEditModal(row)') && tenantAnnouncementsPage.includes('class="modal fade show np-ann-modal"') && !tenantAnnouncementsPage.includes('col-xl-5')],
  ['settings update method support', operationsPage.includes('resource.value.updateMethod') && operationsCatalog.includes("updateMethod?: 'PATCH' | 'PUT' | 'POST'")],
  ['menu management PUT resources', operationsCatalog.includes("settingsResource('tenant', 'menu-management', 'Menu Management', '/admin/tenant/menu-management', 'PUT')") && operationsCatalog.includes("settingsResource('central', 'menu-management', 'Menu Management', '/admin/central/menu-management', 'PUT')")],
]) {
  if (!evidence[1]) {
    failures.push(`Menu completion guardrail missing: ${evidence[0]}`)
  }
}

for (const staleGap of [
  /apiGapResource\('central', 'partner-monitoring'/,
  /apiGapResource\('central', 'partner-usage'/,
  /apiGapResource\('central', 'billing-plans'/,
  /apiGapResource\('central', 'alert-policies'/,
  /apiGapResource\('central', 'alert-events'/,
  /apiGapResource\('central', 'webhook-logs'/,
  /apiGapResource\('central', 'system-settings'/,
  /apiGapResource\('tenant', 'price-rules'/,
  /apiGapResource\('tenant', 'customers'/,
  /apiGapResource\('tenant', 'monitoring'/,
  /apiGapResource\('tenant', 'usage'/,
]) {
  if (staleGap.test(operationsCatalog)) {
    failures.push(`Backend-ready route still uses apiGapResource: ${staleGap.source}`)
  }
}

if (operationsCatalog.includes('not registered in routes/api.php')) {
  failures.push('Operations catalog still contains stale backend route-not-registered gap copy')
}

if (menuCompletionDoc) {
  for (const menuCode of [
    'central:dashboard',
    'central:dashboard_sales',
    'central:dashboard_partner',
    'central:dashboard_wallet',
    'central:dashboard_payout',
    'central:dashboard_monitor',
    'central:games',
    'central:rewards',
    'central:prize_checking',
    'central:stock_generation',
    'central:partners',
    'central:maintenance',
    'central:partner_monitoring',
    'central:partner_usage',
    'central:allocations',
    'central:billing_plans',
    'central:alert_policies',
    'central:alert_events',
    'central:reports',
    'central:settlement',
    'central:webhook_logs',
    'central:audit_logs',
    'central:admin_users',
    'central:roles_permissions',
    'central:menu_management',
    'central:system_settings',
    'tenant:dashboard',
    'tenant:local_stock',
    'tenant:price_rules',
    'tenant:reservations',
    'tenant:orders',
    'tenant:customers',
    'tenant:wallets',
    'tenant:topups',
    'tenant:tickets',
    'tenant:agents',
    'tenant:agent_quotas',
    'tenant:payment_settings',
    'tenant:announcements',
    'tenant:affiliate_programs',
    'tenant:affiliate_accounts',
    'tenant:affiliate_links',
    'tenant:affiliate_attributions',
    'tenant:commission_rules',
    'tenant:seo_settings',
    'tenant:maintenance',
    'tenant:support_access_logs',
    'tenant:commission_transactions',
    'tenant:payouts',
    'tenant:reports',
    'tenant:monitoring',
    'tenant:usage',
    'tenant:sync_logs',
    'tenant:audit_logs',
    'tenant:admin_users',
    'tenant:roles_permissions',
    'tenant:menu_management',
    'tenant:settings',
  ]) {
    if (!menuCompletionDoc.includes(`| ${menuCode} |`)) {
      failures.push(`Menu completion document missing inventory row for ${menuCode}`)
    }
  }
}

const bootstrapCssIndex = nuxtConfig.indexOf('/admin-template/assets/libs/bootstrap/css/bootstrap.min.css')
const stylesCssIndex = nuxtConfig.indexOf('/admin-template/assets/css/styles.css')
if (bootstrapCssIndex === -1 || stylesCssIndex === -1 || bootstrapCssIndex > stylesCssIndex) {
  failures.push('Nuxt head must load Bootstrap CSS before Meno styles.css')
}

for (const assetPath of requiredStaticAssets.map((asset) => `/${asset.replace(/^public\//, '')}`)) {
  if (!assetPath.startsWith('/admin-template/')) continue
  const localPath = join(root, 'public', assetPath.replace('/admin-template/', 'admin-template/'))
  if (!existsSync(localPath)) {
    failures.push(`Linked /admin-template asset would not return static 200: ${assetPath}`)
  }
}

const snapshot = existsSync(join(root, 'scripts/openapi-admin-paths.snapshot.json'))
  ? JSON.parse(readFileSync(join(root, 'scripts/openapi-admin-paths.snapshot.json'), 'utf8'))
  : { paths: {} }
const documentedPaths = snapshot.paths || {}
const endpointPattern = /['"`](\/admin\/(?:tenant|central)\/[^'"`$]+)['"`]/g
const catalogEndpoints = new Set()
let endpointMatch
while ((endpointMatch = endpointPattern.exec(operationsCatalog))) {
  catalogEndpoints.add(endpointMatch[1])
}

for (const endpoint of catalogEndpoints) {
  if (!documentedPaths[endpoint]) {
    failures.push(`Catalog endpoint is not in OpenAPI snapshot: ${endpoint}`)
  }
}

if (documentedPaths['/admin/central/partner-quotas']?.includes('post')) {
  failures.push('OpenAPI admin snapshot still exposes retired active BO path POST /admin/central/partner-quotas')
}

if (documentedPaths['/admin/central/partner-quotas/{quota_id}']?.includes('patch')) {
  failures.push('OpenAPI admin snapshot still exposes retired active BO path PATCH /admin/central/partner-quotas/{quota_id}')
}

for (const requiredAdminWorkflowPath of [
  '/admin/tenant/reports/{report_key}',
  '/admin/tenant/reports/{report_key}/exports',
  '/admin/central/reports/{report_key}',
  '/admin/central/reports/{report_key}/exports',
  '/admin/central/rewards/{reward_result_id}/check-batches',
  '/admin/central/rewards/{reward_result_id}/confirm-live',
]) {
  if (!documentedPaths[requiredAdminWorkflowPath]) {
    failures.push(`OpenAPI snapshot is missing admin workflow path ${requiredAdminWorkflowPath}`)
  }
}

for (const requiredMaintenancePath of [
  ['/admin/central/maintenance', 'get'],
  ['/admin/central/maintenance/{tenant_id}', 'get'],
  ['/admin/central/maintenance/{tenant_id}', 'put'],
  ['/admin/central/partner-maintenance/{partner_id}', 'get'],
  ['/admin/central/partner-maintenance/{partner_id}', 'put'],
  ['/admin/tenant/maintenance', 'get'],
  ['/admin/tenant/maintenance', 'put'],
  ['/admin/tenant/maintenance/events', 'get'],
  ['/admin/tenant/maintenance/bypasses', 'get'],
  ['/admin/tenant/maintenance/bypasses', 'post'],
  ['/admin/tenant/maintenance/bypasses/{bypass_id}', 'delete'],
]) {
  const [path, method] = requiredMaintenancePath
  if (!documentedPaths[path]?.includes(method)) {
    failures.push(`OpenAPI snapshot is missing maintenance path ${method.toUpperCase()} ${path}`)
  }
}

for (const requiredBackendReadyPath of [
  ['/admin/central/partner-monitoring', 'get'],
  ['/admin/central/partner-monitoring/{monitoring_profile_id}', 'get'],
  ['/admin/central/partner-usage', 'get'],
  ['/admin/central/partner-usage/{usage_meter_id}', 'get'],
  ['/admin/central/billing-plans', 'get'],
  ['/admin/central/billing-plans', 'post'],
  ['/admin/central/billing-plans/{billing_plan_id}', 'get'],
  ['/admin/central/billing-plans/{billing_plan_id}', 'patch'],
  ['/admin/central/alert-policies', 'get'],
  ['/admin/central/alert-policies', 'post'],
  ['/admin/central/alert-policies/{alert_policy_id}', 'get'],
  ['/admin/central/alert-policies/{alert_policy_id}', 'patch'],
  ['/admin/central/alert-events', 'get'],
  ['/admin/central/alert-events/{alert_event_id}', 'get'],
  ['/admin/central/alert-events/{alert_event_id}/acknowledge', 'post'],
  ['/admin/central/alert-events/{alert_event_id}/resolve', 'post'],
  ['/admin/central/system-settings', 'get'],
  ['/admin/central/system-settings', 'patch'],
  ['/admin/central/stock/summary', 'get'],
  ['/admin/central/stock/settings', 'get'],
  ['/admin/central/stock/settings', 'patch'],
  ['/admin/central/stock/patterns', 'get'],
  ['/admin/central/stock/limit-settings', 'put'],
  ['/admin/central/stock/limit-overrides', 'get'],
  ['/admin/central/stock/limit-overrides', 'put'],
  ['/admin/central/stock/{game_id}/numbers/{full_number}', 'get'],
  ['/admin/central/webhook-logs', 'get'],
  ['/admin/central/webhook-logs/{webhook_log_id}', 'get'],
  ['/admin/central/reward-payout-rule-games', 'get'],
  ['/admin/central/reward-payout-rules', 'get'],
  ['/admin/central/reward-payout-rules/{payout_rule_id}', 'get'],
  ['/admin/central/reward-payout-rules/{payout_rule_id}', 'patch'],
  ['/admin/tenant/price-rules', 'get'],
  ['/admin/tenant/price-rules', 'post'],
  ['/admin/tenant/price-rules/{price_rule_id}', 'get'],
  ['/admin/tenant/price-rules/{price_rule_id}', 'patch'],
  ['/admin/tenant/members', 'get'],
  ['/admin/tenant/members', 'post'],
  ['/admin/tenant/members/{member_id}', 'get'],
  ['/admin/tenant/members/{member_id}', 'patch'],
  ['/admin/tenant/members/{member_id}/status', 'post'],
  ['/admin/tenant/monitoring', 'get'],
  ['/admin/tenant/usage', 'get'],
]) {
  const [path, method] = requiredBackendReadyPath
  if (!documentedPaths[path]?.includes(method)) {
    failures.push(`OpenAPI snapshot is missing backend-ready path ${method.toUpperCase()} ${path}`)
  }
}

const actionPattern = /endpoint:\s*['"`](\/admin\/(?:tenant|central)\/[^'"`$]+)['"`]/g
let actionMatch
while ((actionMatch = actionPattern.exec(operationsCatalog))) {
  const endpoint = actionMatch[1]
  const actionContext = operationsCatalog.slice(Math.max(0, actionMatch.index - 180), actionMatch.index)
  const method = (actionContext.match(/method:\s*['"`]([A-Z]+)['"`]/)?.[1] || 'POST').toLowerCase()
  if (!documentedPaths[endpoint]?.includes(method)) {
    failures.push(`Catalog action ${method.toUpperCase()} ${endpoint} is not documented in OpenAPI snapshot`)
  }
}

const menoPlugin = existsSync(join(root, 'plugins/meno.client.ts'))
  ? readFileSync(join(root, 'plugins/meno.client.ts'), 'utf8')
  : ''
const adminHeader = existsSync(join(root, 'components/AdminHeader.vue'))
  ? readFileSync(join(root, 'components/AdminHeader.vue'), 'utf8')
  : ''
const adminSidebar = existsSync(join(root, 'components/AdminSidebar.vue'))
  ? readFileSync(join(root, 'components/AdminSidebar.vue'), 'utf8')
  : ''

for (const evidence of [
  ['Bootstrap plugin', menoPlugin.includes("bootstrap/dist/js/bootstrap.bundle.min.js")],
  ['SimpleBar plugin', menoPlugin.includes('new SimpleBar')],
  ['Waves plugin', menoPlugin.includes('Waves.attach')],
  ['deferred Meno hydration', menoPlugin.includes("nuxtApp.hook('app:mounted'") && menoPlugin.includes('requestAnimationFrame')],
  ['route re-init', menoPlugin.includes('router.afterEach')],
  ['Vue sidebar toggle', adminHeader.includes('data-toggled')],
  ['hydration-stable header labels', adminHeader.includes('displayScopeLabel') && adminHeader.includes('visibleScopes')],
  ['Vue submenu state', adminSidebar.includes('openKeys') && adminSidebar.includes('@click.prevent="toggle(item.key)"')],
  ['hydration-stable sidebar labels', adminSidebar.includes('displayScopeTitle') && adminSidebar.includes('Restoring menu')],
  ['sidebar horizontal brand variants', adminSidebar.includes('data-admin-sidebar-logo="horizontal"') && adminSidebar.includes('data-admin-sidebar-logo="horizontal-dark"') && adminSidebar.includes('desktop-dark np-admin-brand-logo') && adminSidebar.includes('toggle-dark np-admin-brand-mark')],
  ['SimpleBar hook', adminSidebar.includes('data-simplebar')],
  ['sticky sidebar class', adminSidebar.includes('app-sidebar sticky')],
]) {
  if (!evidence[1]) {
    failures.push(`Meno JS replacement evidence missing: ${evidence[0]}`)
  }
}

if (failures.length > 0) {
  console.error(`${mode} failed`)
  for (const failure of failures) {
    console.error(`- ${failure}`)
  }
  process.exit(1)
}

console.log(`${mode} passed: back-office foundation, operations catalog OpenAPI snapshot, Meno/Bootstrap static assets, Nuxt head order, JS replacement evidence, API headers, protected deep-link marker bridge, mobile no-overflow shell guardrails, menu completion fallback guardrails, retired physical stock guardrails, hydration guardrails, backend metadata/bypass readiness, license notice blocker, and one-time support token checks are present.`)

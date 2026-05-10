import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.cwd()
const mode = process.argv[2] || 'lint'

const requiredFiles = [
  'nuxt.config.ts',
  'app.vue',
  'layouts/admin.vue',
  'pages/login.vue',
  'pages/admin/central/dashboard.vue',
  'pages/admin/tenant/dashboard.vue',
  'pages/admin/tenant/maintenance.vue',
  'pages/admin/tenant/support-access/index.vue',
  'pages/admin/tenant/support-access/[id].vue',
  'pages/admin/tenant/[...slug].vue',
  'pages/admin/central/[...slug].vue',
  'composables/useAdminApi.ts',
  'composables/useAdminClientReady.ts',
  'composables/useAdminSession.ts',
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
  'AdminReportPanel',
  'AdminExportPanel',
  'AdminDateRangeFilter',
  'AdminOperationsPage',
  'AdminProtectedContent',
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
]

for (const asset of requiredStaticAssets) {
  if (!existsSync(join(root, asset))) {
    failures.push(`Missing static asset ${asset}`)
  }
}

const apiClient = existsSync(join(root, 'composables/useAdminApi.ts'))
  ? readFileSync(join(root, 'composables/useAdminApi.ts'), 'utf8')
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
const adminClientReady = existsSync(join(root, 'composables/useAdminClientReady.ts'))
  ? readFileSync(join(root, 'composables/useAdminClientReady.ts'), 'utf8')
  : ''
const adminProtectedContent = existsSync(join(root, 'components/AdminProtectedContent.vue'))
  ? readFileSync(join(root, 'components/AdminProtectedContent.vue'), 'utf8')
  : ''
const templateNotice = existsSync(join(root, 'public/admin-template/NOTICE.md'))
  ? readFileSync(join(root, 'public/admin-template/NOTICE.md'), 'utf8')
  : ''
const adminNavigation = existsSync(join(root, 'composables/useAdminNavigation.ts'))
  ? readFileSync(join(root, 'composables/useAdminNavigation.ts'), 'utf8')
  : ''
const tenantMaintenancePage = existsSync(join(root, 'pages/admin/tenant/maintenance.vue'))
  ? readFileSync(join(root, 'pages/admin/tenant/maintenance.vue'), 'utf8')
  : ''
const adminFoundationCss = existsSync(join(root, 'assets/css/admin-foundation.css'))
  ? readFileSync(join(root, 'assets/css/admin-foundation.css'), 'utf8')
  : ''
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
  ['login safe redirect target', loginPage.includes('safeRedirectTarget') && loginPage.includes('route.query.redirect') && loginPage.includes('isAdminPath') && loginPage.includes('isScopePath')],
  ['operations client-only load', operationsPage.includes('if (!import.meta.client)') && operationsPage.includes('onMounted(() =>') && operationsPage.includes('!session.isAuthenticated.value')],
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
  ['maintenance bypass list support', tenantMaintenancePage.includes("api.apiFetch('/admin/tenant/maintenance/bypasses'") && tenantMaintenancePage.includes("status: 'active'") && tenantMaintenancePage.includes('bypassMeta') && tenantMaintenancePage.includes('support_session')],
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
const menuCompletionDocPath = join(root, '..', '..', 'docs', 'back-office-menu-completion.md')
const menuCompletionDoc = existsSync(menuCompletionDocPath)
  ? readFileSync(menuCompletionDocPath, 'utf8')
  : ''

for (const route of [
  "slug: 'stock'",
  'Affiliate Programs',
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
  "'growth/affiliate-programs'",
  "'growth/affiliate-links'",
  "'growth/attributions'",
  "'growth/affiliates'",
  "'growth/commission-rules'",
  "slug: 'growth/commission-transactions'",
  "slug: 'growth/payouts'",
]) {
  if (!operationsCatalog.includes(routeSlug)) {
    failures.push(`Tenant growth frontend route grouping missing ${routeSlug}`)
  }
}

for (const [routeKey, route] of [
  ['central:rewards', '/admin/central/rewards'],
  ['central:prize_checking', '/admin/central/rewards'],
  ['central:reports', '/admin/central/reports'],
  ['central:settlement', '/admin/central/settlements'],
  ['central:partner_provisioning', '/admin/central/partner-provisioning'],
  ['central:partner_quotas', '/admin/central/partner-quotas'],
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
  "'partner-provisioning'",
  "'partner-quotas'",
  "'partner-monitoring'",
  "'partner-usage'",
  "'billing-plans'",
  "'alert-policies'",
  "'alert-events'",
  "'webhook-logs'",
  "'system-settings'",
  "'price-rules'",
  "'customers'",
  "'monitoring'",
  "'usage'",
]) {
  if (!operationsCatalog.includes(requiredResource)) {
    failures.push(`Menu completion catalog route missing ${requiredResource}`)
  }
}

for (const evidence of [
  ['API gap state render', operationsPage.includes('resource.apiGap') && operationsPage.includes(':message="resource.apiGap"')],
  ['API gap load guard', operationsPage.includes('resource.value.apiGap')],
  ['summary route render', operationsPage.includes("mode === 'summary'") && operationsCatalog.includes("mode: 'summary'")],
  ['detail JSON update editor', operationsPage.includes('resource.detailJsonEditor') && operationsPage.includes('saveDetailDraft')],
  ['JSON payload action support', operationsPage.includes('buildActionBody') && operationsCatalog.includes('payloadTemplate') && existsSync(join(root, 'components/AdminConfirmAction.vue')) && readFileSync(join(root, 'components/AdminConfirmAction.vue'), 'utf8').includes('Payload JSON')],
  ['P1 typed action forms', operationsCatalog.includes('formFields') && operationsPage.includes('buildPayloadFromFields') && readFileSync(join(root, 'components/AdminConfirmAction.vue'), 'utf8').includes('formFields')],
  ['P1 related list support', operationsCatalog.includes('relatedLists') && operationsPage.includes('loadRelatedLists') && operationsPage.includes('openRelatedDetail')],
  ['P1 payment channel workflow', operationsCatalog.includes('/admin/tenant/payment-channels') && operationsCatalog.includes("settingsFields") && operationsCatalog.includes("title: 'Payment Channels'")],
  ['P1 wallet ledger workflow', operationsCatalog.includes('/admin/tenant/wallets/{wallet_id}/ledger') && operationsCatalog.includes("title: 'Wallet Ledger'")],
  ['P1 tenant order nested customer context', operationsCatalog.includes("type?: 'text' | 'status' | 'datetime' | 'money' | 'json' | 'customer'") && operationsCatalog.includes('fallbackKeys?: string[]') && operationsCatalog.includes('const orderActionContext') && operationsCatalog.includes("'customer.id'") && operationsCatalog.includes("'customer.name'") && operationsCatalog.includes("'customer.phone'") && operationsCatalog.includes("type: 'customer'")],
  ['P1 tenant topup nested customer context', operationsCatalog.includes('const topupActionContext') && operationsCatalog.includes("'member_id'") && operationsCatalog.includes("'amount.currency'") && operationsCatalog.includes("'channel'") && operationsCatalog.includes("contextFields: topupActionContext")],
  ['P2 partner typed workflows', operationsCatalog.includes('const partnerCreateFields') && operationsCatalog.includes('const partnerProvisionFields') && operationsCatalog.includes('const partnerQuotaCreateFields') && operationsCatalog.includes("endpoint: '/admin/central/partners/{partner_id}/suspend'") && operationsCatalog.includes("formFields: partnerProvisionFields")],
  ['P2 billing alert typed workflows', operationsCatalog.includes('sourceKey?: string') && operationsCatalog.includes('const billingPlanFields') && operationsCatalog.includes('const billingPlanUpdateFields') && operationsCatalog.includes('const alertPolicyFields') && operationsCatalog.includes('const alertEventActionContext') && operationsCatalog.includes("formFields: billingPlanFields") && operationsCatalog.includes("formFields: alertPolicyFields")],
  ['P3 reward report log workflows', operationsCatalog.includes("'prize-lines'") && operationsCatalog.includes('const rewardCreateFields') && operationsCatalog.includes('const rewardUpdateFields') && operationsCatalog.includes('Prize Check Batches') && operationsCatalog.includes('const settlementActionContext') && operationsCatalog.includes('const reportExportContext') && operationsCatalog.includes('function reportExportFields') && operationsPage.includes('buildCollectionContext') && operationsPage.includes('normalizePrizeLines') && existsSync(join(root, 'components/AdminReportPanel.vue')) && readFileSync(join(root, 'components/AdminReportPanel.vue'), 'utf8').includes('Report rows')],
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
    'central:games',
    'central:rewards',
    'central:prize_checking',
    'central:master_stock',
    'central:stock_generation',
    'central:partners',
    'central:partner_provisioning',
    'central:partner_quotas',
    'central:partner_monitoring',
    'central:partner_usage',
    'central:allocations',
    'central:stock_recall',
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
    'tenant:stock_sync',
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

const nuxtConfig = existsSync(join(root, 'nuxt.config.ts'))
  ? readFileSync(join(root, 'nuxt.config.ts'), 'utf8')
  : ''

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

for (const requiredAdminWorkflowPath of [
  '/admin/tenant/reports/{report_key}',
  '/admin/tenant/reports/{report_key}/exports',
  '/admin/central/reports/{report_key}',
  '/admin/central/reports/{report_key}/exports',
  '/admin/central/rewards/{reward_result_id}/check-batches',
]) {
  if (!documentedPaths[requiredAdminWorkflowPath]) {
    failures.push(`OpenAPI snapshot is missing admin workflow path ${requiredAdminWorkflowPath}`)
  }
}

for (const requiredMaintenancePath of [
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
  ['/admin/central/webhook-logs', 'get'],
  ['/admin/central/webhook-logs/{webhook_log_id}', 'get'],
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

console.log(`${mode} passed: back-office foundation, operations catalog OpenAPI snapshot, Meno/Bootstrap static assets, Nuxt head order, JS replacement evidence, API headers, protected deep-link marker bridge, mobile no-overflow shell guardrails, menu completion fallback guardrails, hydration guardrails, backend metadata/bypass readiness, license notice blocker, and one-time support token checks are present.`)

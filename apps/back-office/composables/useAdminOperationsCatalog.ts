export type AdminScope = 'tenant' | 'central'
export type OperationMode = 'list' | 'detail' | 'report-index' | 'report-detail' | 'settings' | 'summary'
export type OperationOption = string | {
  value: string | number
  label: string
  disabled?: boolean
  status?: string
  code?: string
  name?: string
  partnerId?: string
  tenantId?: string
  activeTenantCount?: number
  singleTenantId?: string
  singleTenantLabel?: string
  allocationPercent?: number | null
  allocationPercentBasisPoints?: number | null
  stockPercent?: number | null
  stockPercentBasisPoints?: number | null
  defaultAllocationPercent?: number | null
  defaultAllocationPercentBasisPoints?: number | null
  remainingCount?: number | null
  existingAllocationPercent?: number | null
  existingAllocationPercentBasisPoints?: number | null
  existingAllocatedCount?: number | null
  existingRemainingCount?: number | null
  generatedSupplyCount?: number | null
  existingGameAllocationPercent?: number | null
  existingGameAllocationPercentBasisPoints?: number | null
  existingGameAllocatedCount?: number | null
  existingGameRemainingCount?: number | null
  allocatedCount?: number | null
  isCurrent?: boolean
  isDefault?: boolean
  stockModes?: string[]
  sale_start_at?: string
  draw_at?: string
  close_at?: string
  server_time?: string
}
export type OperationOptionSource = 'central-games' | 'central-partners' | 'allocation-partners' | 'allocation-tenants' | 'allocation-games' | 'tenant-stock-games'

export type OperationColumn = {
  key: string
  label: string
  type?: 'text' | 'status' | 'datetime' | 'money' | 'json' | 'customer' | 'number'
  fallbackKeys?: string[]
}

export type OperationFilter = {
  key: string
  label: string
  type?: 'text' | 'number' | 'date' | 'select'
  options?: OperationOption[]
  optionSource?: OperationOptionSource
  dependsOn?: string
  hideEmptyOption?: boolean
  emptyOptionLabel?: string
}

export type OperationFormField = {
  key: string
  label: string
  type?: 'text' | 'number' | 'textarea' | 'json' | 'select' | 'checkbox' | 'date' | 'datetime-local' | 'datetime-range' | 'lines' | 'password' | 'color' | 'prize-lines' | 'reward-prize-grid' | 'reward-prize-number-grid' | 'reward-prize-amount-grid' | 'stock-set-distribution' | 'stock-sale-limits' | 'stock-partner-distribution' | 'stock-partner-limits'
  sourceKey?: string
  rangeStartKey?: string
  rangeEndKey?: string
  rangeStartSourceKey?: string
  rangeEndSourceKey?: string
  rangeStartLabel?: string
  rangeEndLabel?: string
  valueKey?: string
  options?: OperationOption[]
  optionSource?: OperationOptionSource
  dependsOn?: string
  hideEmptyOption?: boolean
  emptyOptionLabel?: string
  defaultValueSource?: 'current-game' | 'stock-set-distribution-default'
  currentOnly?: boolean
  required?: boolean
  readonly?: boolean
  placeholder?: string
  defaultValue?: any
  help?: string
  min?: number
  max?: number
  step?: number
  itemKey?: string
  emptyValue?: 'array'
  partial?: boolean
  visibleForGenerationModes?: string[]
}

export type OperationAction = {
  key: string
  label: string
  method?: 'POST' | 'PATCH' | 'PUT' | 'DELETE'
  endpoint?: string
  route?: string
  variant?: 'primary' | 'success' | 'warning' | 'danger' | 'info' | 'light'
  disabled?: boolean
  disabledReason?: string
  enabledStatuses?: string[]
  reason?: boolean
  payloadTemplate?: Record<string, any>
  formFields?: OperationFormField[]
  contextFields?: string[]
}

export type OperationRelatedList = {
  key: string
  title: string
  listEndpoint: string
  detailEndpoint?: string
  idParam: string
  idKey?: string
  columns: OperationColumn[]
  filters?: OperationFilter[]
  actions?: OperationAction[]
  collectionActions?: OperationAction[]
  emptyTitle?: string
  emptyMessage?: string
}

export type OperationSettingsPanel = {
  key: string
  title: string
  listEndpoint: string
  updateEndpoint: string
  updateMethod?: 'PATCH' | 'PUT' | 'POST'
  settingsFields: OperationFormField[]
}

export type OperationResource = {
  scope: AdminScope
  slug: string
  title: string
  group: string
  mode?: OperationMode
  listEndpoint?: string
  detailEndpoint?: string
  updateEndpoint?: string
  updateMethod?: 'PATCH' | 'PUT' | 'POST'
  idParam?: string
  idKey?: string
  columns?: OperationColumn[]
  filters?: OperationFilter[]
  actions?: OperationAction[]
  collectionActions?: OperationAction[]
  relatedLists?: OperationRelatedList[]
  secondarySettings?: OperationSettingsPanel[]
  settingsFields?: OperationFormField[]
  confirmContextFields?: string[]
  reportKeys?: string[]
  detailJsonEditor?: boolean
  detailRenderer?: 'reward'
  defaultQuery?: Record<string, any>
  stockGrouped?: boolean
  stockSummaryEndpoint?: string
  apiSort?: boolean
  apiGap?: string
  detailApiGap?: string
}

const statusFilter = (options: string[] = ['pending', 'approved', 'rejected', 'cancelled', 'active', 'inactive', 'completed', 'failed']): OperationFilter => ({
  key: 'status',
  label: 'Status',
  type: 'select',
  options,
})
const adminUiRoute = (scope: AdminScope, path: string) => `/admin/${scope}/${path}`

const cursorFilters = (extra: OperationFilter[] = []): OperationFilter[] => [
  ...extra,
  { key: 'cursor', label: 'Cursor' },
  { key: 'limit', label: 'Limit', type: 'number' },
]

const gameSelectFilter = (label = 'Game'): OperationFilter => ({
  key: 'game_id',
  label,
  type: 'select',
  optionSource: 'central-games',
})

const gameSelectField = (required = false, label = 'Game', overrides: Partial<OperationFormField> = {}): OperationFormField => ({
  key: 'game_id',
  label,
  type: 'select',
  optionSource: 'central-games',
  required,
  ...overrides,
})

const allocationPartnerFilter = (label = 'Partner'): OperationFilter => ({
  key: 'partner_id',
  label,
  type: 'select',
  optionSource: 'allocation-partners',
})

const allocationTenantFilter = (label = 'Tenant'): OperationFilter => ({
  key: 'tenant_id',
  label,
  type: 'select',
  optionSource: 'allocation-tenants',
  dependsOn: 'partner_id',
  emptyOptionLabel: 'Select partner first',
})

const allocationGameFilter = (label = 'Game'): OperationFilter => ({
  key: 'game_id',
  label,
  type: 'select',
  optionSource: 'allocation-games',
})

const allocationPartnerField = (overrides: Partial<OperationFormField> = {}): OperationFormField => ({
  key: 'partner_id',
  label: 'Partner',
  type: 'select',
  optionSource: 'allocation-partners',
  required: true,
  hideEmptyOption: false,
  ...overrides,
})

const allocationTenantField = (overrides: Partial<OperationFormField> = {}): OperationFormField => ({
  key: 'tenant_id',
  label: 'Tenant',
  type: 'select',
  optionSource: 'allocation-tenants',
  dependsOn: 'partner_id',
  emptyOptionLabel: 'Select partner first',
  help: 'Auto-filled when the selected active partner has exactly one active tenant.',
  ...overrides,
})

const allocationGameField = (overrides: Partial<OperationFormField> = {}): OperationFormField => ({
  key: 'game_id',
  label: 'Game',
  type: 'select',
  optionSource: 'allocation-games',
  required: true,
  currentOnly: true,
  defaultValueSource: 'current-game',
  hideEmptyOption: true,
  emptyOptionLabel: 'No open game available',
  ...overrides,
})

const allocationPercentField = (overrides: Partial<OperationFormField> = {}): OperationFormField => ({
  key: 'allocation_percent',
  label: 'Allocation percent',
  type: 'number',
  min: 0.01,
  max: 100,
  step: 0.01,
  required: true,
  help: 'Backend enforces total active partner percent per game <= 100% and rejects values below already reserved or sold usage.',
  ...overrides,
})

const partnerStockPercentField = (overrides: Partial<OperationFormField> = {}): OperationFormField => ({
  key: 'stock_percent',
  label: 'Stock %',
  type: 'number',
  min: 0,
  max: 100,
  step: 0.01,
  required: true,
  help: 'Base partner stock percent. Allocation uses this value as the default for every game.',
  ...overrides,
})

const auditColumns: OperationColumn[] = [
  { key: 'id', label: 'Log' },
  { key: 'action', label: 'Action' },
  { key: 'actor_id', label: 'Actor' },
  { key: 'target_type', label: 'Target' },
  { key: 'target_id', label: 'Target ID' },
  { key: 'tenant_id', label: 'Tenant' },
  { key: 'request_id', label: 'Request' },
  { key: 'created_at', label: 'Created', type: 'datetime' },
]

const syncColumns: OperationColumn[] = [
  { key: 'id', label: 'Log' },
  { key: 'direction', label: 'Direction', type: 'status' },
  { key: 'event_type', label: 'Event' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'producer', label: 'Producer' },
  { key: 'consumer', label: 'Consumer' },
  { key: 'aggregate_id', label: 'Aggregate' },
  { key: 'attempt_count', label: 'Attempts' },
  { key: 'created_at', label: 'Created', type: 'datetime' },
]

const adminUserColumns: OperationColumn[] = [
  { key: 'id', label: 'Admin user' },
  { key: 'name', label: 'Name' },
  { key: 'email', label: 'Email' },
  { key: 'roles.0.name', label: 'Primary role' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]

const roleColumns: OperationColumn[] = [
  { key: 'id', label: 'Role' },
  { key: 'code', label: 'Code' },
  { key: 'name', label: 'Name' },
  { key: 'permissions', label: 'Permissions', type: 'json' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]

const genericColumns: OperationColumn[] = [
  { key: 'id', label: 'Record' },
  { key: 'name', label: 'Name' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]

const baseReportFilters: OperationFilter[] = [
  { key: 'date_from', label: 'From', type: 'date' },
  { key: 'date_to', label: 'To', type: 'date' },
  { key: 'group_by', label: 'Group by', type: 'select', options: ['day', 'week', 'month', 'game', 'status'] },
  { key: 'cursor', label: 'Cursor' },
  { key: 'limit', label: 'Limit', type: 'number' },
]
const centralReportFilters: OperationFilter[] = [
  { key: 'tenant_id', label: 'Tenant ID' },
  { key: 'date_from', label: 'From', type: 'date' },
  { key: 'date_to', label: 'To', type: 'date' },
  { key: 'group_by', label: 'Group by', type: 'select', options: ['day', 'week', 'month', 'tenant', 'game', 'status'] },
  { key: 'cursor', label: 'Cursor' },
  { key: 'limit', label: 'Limit', type: 'number' },
]
const tenantReportFilters = baseReportFilters

const currencyOptions = ['THB']
const priceRuleStatusOptions = ['active', 'archived']
const priceRuleTypeOptions = ['reward_adjustment_amount', 'reward_adjustment_percent']
const memberStatusOptions = ['active', 'pending_verification', 'suspended', 'disabled']
const notifyCustomerField: OperationFormField = {
  key: 'notify_customer',
  label: 'Notify customer',
  type: 'checkbox',
  defaultValue: true,
  help: 'Send customer-facing notification when the backend supports it.',
}

const moneyFields = (prefix = 'amount', label = 'Amount', required = true): OperationFormField[] => [
  {
    key: `${prefix}.amount`,
    label: `${label} (minor units)`,
    type: 'number',
    required,
    step: 1,
    help: 'Use the smallest currency unit, for example 10000 for THB 100.00.',
  },
  {
    key: `${prefix}.currency`,
    label: 'Currency',
    type: 'select',
    options: currencyOptions,
    defaultValue: 'THB',
  },
]

const stockActionContext = ['id', 'game_id', 'full_number', 'front3', 'back3', 'back2', 'status', 'partner_id', 'tenant_id', 'allocation_id']
const moneyActionContext = ['id', 'reference', 'customer_id', 'status', 'payment_status', 'total.amount', 'amount.amount', 'balance.amount']
const orderActionContext = [
  'id',
  'tenant_id',
  'reference',
  'customer_id',
  'customer.id',
  'customer.name',
  'customer.phone',
  'status',
  'payment_status',
  'total.amount',
  'customer.email',
]
const topupActionContext = [
  'id',
  'tenant_id',
  'reference',
  'customer_id',
  'member_id',
  'customer.id',
  'customer.name',
  'customer.phone',
  'status',
  'amount.amount',
  'amount.currency',
  'channel',
  'customer.email',
]
const partnerStatusOptions = ['draft', 'active', 'suspended', 'closed']
const partnerTypeOptions = ['partner_store', 'agent_network', 'white_label', 'api_partner', 'internal']
const tenantStatusOptions = ['provisioning', 'active', 'maintenance', 'suspended', 'closed']
const agentStatusOptions = ['active', 'inactive', 'suspended']
const affiliateStatusOptions = ['active', 'inactive', 'archived']
const commissionRuleTypeOptions = ['fixed_per_order', 'percent_sales', 'per_ticket']
const seoStatusOptions = ['draft', 'active', 'inactive', 'archived']
const redirectStatusCodeOptions = ['301', '302', '307', '308']
const domainTypeOptions = ['subdomain', 'custom_domain']
const deploymentModeOptions = ['shared', 'dedicated_runtime', 'dedicated_resource_pool']
const billingPlanStatusOptions = ['active', 'archived']
const alertPolicyStatusOptions = ['active', 'paused', 'archived']
const alertSeverityOptions = ['info', 'warning', 'critical']
const alertEventStatusOptions = ['open', 'acknowledged', 'resolved', 'suppressed']
const rewardStatusOptions = ['draft', 'recorded', 'checking', 'summary_ready', 'verified', 'published', 'corrected', 'archived']
const adminUserStatusOptions = ['active', 'invited', 'suspended', 'disabled']
const roleStatusOptions = ['active', 'archived']
const maintenanceStatusOptions = ['inactive', 'scheduled', 'active', 'ended', 'cancelled']
const maintenanceModeOptions = ['full_site', 'customer_web_only', 'admin_only', 'checkout_payment_only', 'read_only', 'scheduled']
const tenantDomainStatusOptions = ['pending_verification', 'dns_verified', 'ssl_pending', 'active', 'failed', 'suspended', 'archived']
const gameCreateStatusOptions = ['draft', 'open']
const gameLifecycleTransitionOptions = ['open', 'reward_recorded', 'reward_checking', 'reward_verified', 'reward_published']
const partnerActionContext = ['id', 'code', 'name', 'type', 'status', 'stock_percent', 'tenants.0.id', 'tenants.0.code', 'domains.0.host', 'runtime.billing_status', 'runtime.monitoring_status']
const gameActionContext = ['id', 'code', 'name', 'status', 'sale_start_at', 'draw_at', 'close_at', 'closed_at', 'archived_at']
const allocationActionContext = ['id', 'partner_name', 'partner_code', 'partner_id', 'tenant_name', 'tenant_code', 'tenant_id', 'game_name', 'game_code', 'game_id', 'allocation_percent', 'allocated_count', 'remaining_count', 'recalled_count', 'status']
const billingPlanActionContext = ['id', 'code', 'name', 'monthly_fee.amount', 'monthly_fee.currency', 'status']
const alertPolicyActionContext = ['id', 'partner_id', 'partner.name', 'policy_key', 'severity', 'status']
const alertEventActionContext = ['id', 'partner_id', 'partner.name', 'policy_key', 'severity', 'status', 'channel', 'title', 'triggered_at']
const rewardActionContext = ['id', 'game_id', 'status', 'version', 'checked_at', 'verified_at', 'published_at']
const settlementActionContext = ['id', 'partner_id', 'tenant_id', 'status', 'sales_amount.amount', 'commission_amount.amount', 'payout_amount.amount', 'net_amount.amount', 'period_from', 'period_to']
const priceRuleActionContext = ['id', 'tenant_id', 'code', 'name', 'game_id', 'base_source', 'rule_type', 'adjustment.amount', 'adjustment.bps', 'reward_preview.summary.base_total.amount', 'reward_preview.summary.effective_total.amount', 'status', 'conditions', 'updated_at']
const memberActionContext = ['id', 'tenant_id', 'member_no', 'name', 'phone', 'email', 'status', 'order_count', 'lifetime_spend.amount', 'updated_at']
const agentActionContext = ['id', 'tenant_id', 'partner_id', 'code', 'name', 'phone', 'email', 'store_id', 'status', 'metadata', 'updated_at']
const agentQuotaActionContext = ['id', 'tenant_id', 'code', 'name', 'store_id', 'status', 'quotas.0.game_id', 'quotas.0.quota_count', 'quotas.0.used_count', 'quotas.0.status', 'updated_at']
const affiliateProgramActionContext = ['id', 'tenant_id', 'code', 'name', 'status', 'starts_at', 'ends_at', 'metadata', 'updated_at']
const affiliateAccountActionContext = ['id', 'tenant_id', 'customer_id', 'code', 'name', 'phone', 'email', 'status', 'wallet_balance.amount', 'wallet_balance.currency', 'payout_profile', 'metadata', 'updated_at']
const affiliateLinkActionContext = ['id', 'tenant_id', 'affiliate_account_id', 'affiliate_program_id', 'code', 'url', 'status', 'metadata', 'updated_at']
const commissionRuleActionContext = ['id', 'tenant_id', 'affiliate_program_id', 'affiliate_account_id', 'code', 'name', 'rule_type', 'amount.amount', 'amount.currency', 'rate_bps', 'status', 'metadata', 'updated_at']
const commissionTransactionActionContext = ['id', 'tenant_id', 'affiliate_account_id', 'order_id', 'commission_rule_id', 'transaction_type', 'status', 'amount.amount', 'amount.currency', 'calculated_at', 'approved_at']
const seoPageActionContext = ['id', 'tenant_id', 'path', 'title', 'status', 'robots', 'canonical_url', 'og_image_url', 'metadata', 'updated_at']
const redirectActionContext = ['id', 'tenant_id', 'source_path', 'target_url', 'status_code', 'status', 'metadata', 'updated_at']
const reportExportContext = ['scope', 'report_key', 'tenant_id', 'date_from', 'date_to', 'group_by', 'filters']
const adminUserActionContext = ['id', 'tenant_id', 'name', 'email', 'phone', 'status', 'roles.0.id', 'roles.0.name', 'permissions.0']
const roleActionContext = ['id', 'tenant_id', 'code', 'name', 'status', 'permissions.0', 'permissions.1', 'system_role']
const domainActionContext = ['id', 'tenant_id', 'host', 'type', 'status', 'is_primary', 'readiness.local_only']
const rewardPrizeNumberHelp = 'Update winning numbers only. Payout amounts are kept from the current reward template.'
const rewardPrizeAmountHelp = 'Update payout amounts only. Each amount is edited once per prize group and applied to every row in that group.'
const roleIdsField = (required = false): OperationFormField => ({
  key: 'role_ids',
  label: 'Role IDs',
  type: 'lines',
  sourceKey: 'roles',
  valueKey: 'id',
  required,
  placeholder: 'rol_example_one\nrol_example_two',
  help: 'One role ID per line. Use IDs from the roles page for the same scope.',
})
const permissionsField = (required = false): OperationFormField => ({
  key: 'permissions',
  label: 'Permission codes',
  type: 'lines',
  required,
  placeholder: 'dashboard.view\norder.view',
  help: 'One permission code per line. Backend validates codes against the current scope.',
})
const adminUserCreateFields = (scope: AdminScope): OperationFormField[] => [
  { key: 'name', label: 'Name', required: true },
  { key: 'email', label: 'Email', required: true, placeholder: 'admin@example.test' },
  { key: 'phone', label: 'Phone' },
  ...(scope === 'central'
    ? [
        { key: 'password', label: 'Temporary password', type: 'password', placeholder: 'Leave blank for backend-generated secret' } as OperationFormField,
        { key: 'status', label: 'Status', type: 'select', options: adminUserStatusOptions, defaultValue: 'active' } as OperationFormField,
      ]
    : [
        { key: 'send_invitation', label: 'Send invitation', type: 'checkbox', defaultValue: true } as OperationFormField,
      ]),
  roleIdsField(true),
]
const adminUserUpdateFields: OperationFormField[] = [
  { key: 'name', label: 'Name' },
  { key: 'email', label: 'Email' },
  { key: 'phone', label: 'Phone' },
  { key: 'status', label: 'Status', type: 'select', options: adminUserStatusOptions },
  { key: 'password', label: 'Temporary password', type: 'password', placeholder: 'Leave blank to keep current credential' },
  roleIdsField(false),
]
const roleCreateFields: OperationFormField[] = [
  { key: 'name', label: 'Role name', required: true },
  { key: 'code', label: 'Role code', placeholder: 'Optional; backend derives one from the name' },
  { key: 'status', label: 'Status', type: 'select', options: roleStatusOptions, defaultValue: 'active' },
  permissionsField(true),
]
const roleUpdateFields: OperationFormField[] = [
  { key: 'name', label: 'Role name' },
  { key: 'code', label: 'Role code' },
  { key: 'status', label: 'Status', type: 'select', options: roleStatusOptions },
  permissionsField(false),
]
const systemSettingsFields: OperationFormField[] = [
  { key: 'settings.platform_name', label: 'Platform name', sourceKey: 'settings.platform_name' },
  { key: 'settings.admin_api_version', label: 'Admin API version', sourceKey: 'settings.admin_api_version' },
  { key: 'settings.release_gate_note', label: 'Release gate note', sourceKey: 'settings.release_gate_note' },
  { key: 'settings.bo_menu_completion_backend_gaps', label: 'BO backend gap status', sourceKey: 'settings.bo_menu_completion_backend_gaps' },
]
const tenantSettingsFields: OperationFormField[] = [
  { key: 'site.site_name', label: 'Site name', required: true },
  { key: 'site.display_name', label: 'Display name' },
  { key: 'site.locale', label: 'Locale', defaultValue: 'th-TH' },
  { key: 'site.timezone', label: 'Timezone', defaultValue: 'Asia/Bangkok' },
  { key: 'site.support_email', label: 'Support email' },
  { key: 'site.support_phone', label: 'Support phone' },
  { key: 'seo.default_title', label: 'SEO title' },
  { key: 'seo.default_description', label: 'SEO description', type: 'textarea' },
  { key: 'seo.default_keywords', label: 'SEO keywords', type: 'lines', sourceKey: 'seo.default_keywords', placeholder: 'lottery\nlucky' },
  { key: 'seo.robots_default', label: 'Robots default', defaultValue: 'index,follow' },
  { key: 'seo.sitemap_enabled', label: 'Sitemap enabled', type: 'checkbox', sourceKey: 'seo.sitemap_enabled', defaultValue: true },
  { key: 'seo.robots_enabled', label: 'Robots enabled', type: 'checkbox', sourceKey: 'seo.robots_enabled', defaultValue: true },
  { key: 'maintenance.active', label: 'Maintenance active', type: 'checkbox', sourceKey: 'maintenance.active', defaultValue: false },
  { key: 'maintenance.mode', label: 'Maintenance mode', type: 'select', options: maintenanceModeOptions, sourceKey: 'maintenance.mode' },
  { key: 'maintenance.message', label: 'Maintenance message', type: 'textarea', sourceKey: 'maintenance.message' },
  { key: 'maintenance.retry_after_seconds', label: 'Retry after seconds', type: 'number', sourceKey: 'maintenance.retry_after_seconds', min: 0, step: 1 },
  { key: 'maintenance.allowed_routes', label: 'Allowed routes', type: 'lines', sourceKey: 'maintenance.allowed_routes', placeholder: '/\n/login' },
  { key: 'maintenance.blocked_route_patterns', label: 'Blocked route patterns', type: 'lines', sourceKey: 'maintenance.blocked_route_patterns', placeholder: '/checkout/*' },
  { key: 'api.base_url', label: 'API base URL', sourceKey: 'api.base_url' },
  { key: 'api.realtime_url', label: 'Realtime URL', sourceKey: 'api.realtime_url' },
  { key: 'api.asset_cdn_base_url', label: 'Asset CDN base URL', sourceKey: 'api.asset_cdn_base_url' },
]
const tenantThemeFields: OperationFormField[] = [
  { key: 'brand.logo_url', label: 'Logo URL', sourceKey: 'brand.logo_url' },
  { key: 'brand.favicon_url', label: 'Favicon URL', sourceKey: 'brand.favicon_url' },
  { key: 'brand.og_image_url', label: 'Open graph image URL', sourceKey: 'brand.og_image_url' },
  { key: 'theme.primary_color', label: 'Primary color', type: 'color', sourceKey: 'theme.primary_color', defaultValue: '#0F766E' },
  { key: 'theme.secondary_color', label: 'Secondary color', type: 'color', sourceKey: 'theme.secondary_color', defaultValue: '#2563EB' },
  { key: 'theme.accent_color', label: 'Accent color', type: 'color', sourceKey: 'theme.accent_color', defaultValue: '#F59E0B' },
  { key: 'theme.background_color', label: 'Background color', type: 'color', sourceKey: 'theme.background_color', defaultValue: '#FFFFFF' },
  { key: 'theme.text_color', label: 'Text color', type: 'color', sourceKey: 'theme.text_color', defaultValue: '#111827' },
  { key: 'theme.font_family', label: 'Font family', sourceKey: 'theme.font_family', defaultValue: 'Inter, sans-serif' },
]
const tenantDomainCreateFields: OperationFormField[] = [
  { key: 'host', label: 'Host', required: true, placeholder: 'shop.example.test' },
  { key: 'type', label: 'Domain type', type: 'select', options: domainTypeOptions, defaultValue: 'custom_domain', required: true },
  { key: 'status', label: 'Status', type: 'select', options: tenantDomainStatusOptions, defaultValue: 'pending_verification', required: true },
  { key: 'is_primary', label: 'Primary domain', type: 'checkbox', defaultValue: false },
]
const tenantDomainUpdateFields: OperationFormField[] = tenantDomainCreateFields.map((field) => ({ ...field, required: false }))
const priceRuleCreateFields: OperationFormField[] = [
  { key: 'code', label: 'Code', required: true, placeholder: 'first_prize_plus_100', help: 'Unique within the active tenant.' },
  { key: 'name', label: 'Name', required: true, placeholder: 'First prize plus 100 THB' },
  { key: 'game_id', label: 'Game ID', placeholder: 'Game to adjust from Central Reward' },
  { key: 'base_source', label: 'Base source', type: 'select', options: ['central_reward'], defaultValue: 'central_reward', required: true },
  { key: 'rule_type', label: 'Rule type', type: 'select', options: priceRuleTypeOptions, defaultValue: 'reward_adjustment_amount', required: true },
  { key: 'adjustment_amount', label: 'Adjustment amount (minor units)', type: 'number', step: 1, defaultValue: 0, help: 'Signed delta from Central Reward, for example 10000 adds THB 100.00 and -10000 subtracts THB 100.00.' },
  { key: 'adjustment_bps', label: 'Adjustment BPS', type: 'number', step: 1, help: 'Used only for percent adjustments. 100 bps = 1%; negative values reduce the Central Reward.' },
  { key: 'currency', label: 'Currency', type: 'select', options: currencyOptions, defaultValue: 'THB' },
  { key: 'conditions', label: 'Prize conditions JSON', type: 'json', defaultValue: '{"prize_type":"first_prize"}', placeholder: '{"prize_type":"first_prize"}', help: 'Use prize_type, prize_types, prize_number, or prize_numbers to scope reward adjustment.' },
  { key: 'status', label: 'Status', type: 'select', options: priceRuleStatusOptions, defaultValue: 'active' },
]
const priceRuleUpdateFields: OperationFormField[] = priceRuleCreateFields.map((field) => {
  const updateField: OperationFormField = {
    ...field,
    required: false,
    sourceKey: field.key === 'adjustment_amount' ? 'adjustment.amount' : field.key === 'adjustment_bps' ? 'adjustment.bps' : field.key === 'currency' ? 'adjustment.currency' : field.key,
  }
  delete updateField.defaultValue
  return updateField
})
const memberCreateFields: OperationFormField[] = [
  { key: 'name', label: 'Name', required: true, placeholder: 'Tenant Member' },
  { key: 'phone', label: 'Phone', required: true, placeholder: '0811111111' },
  { key: 'email', label: 'Email', placeholder: 'member@example.test' },
  { key: 'password', label: 'Temporary password', type: 'password', placeholder: 'Optional password for safe local fixture members' },
  { key: 'status', label: 'Status', type: 'select', options: memberStatusOptions, defaultValue: 'active' },
  { key: 'send_invitation', label: 'Send invitation', type: 'checkbox', defaultValue: false },
]
const memberUpdateFields: OperationFormField[] = [
  { key: 'name', label: 'Name' },
  { key: 'phone', label: 'Phone' },
  { key: 'email', label: 'Email' },
  { key: 'admin_note', label: 'Admin note', type: 'textarea', placeholder: 'Optional internal note for audit context' },
]
const memberStatusFields: OperationFormField[] = [
  { key: 'status', label: 'Status', type: 'select', options: memberStatusOptions, defaultValue: 'suspended', required: true },
  { key: 'notify_member', label: 'Notify member', type: 'checkbox', defaultValue: true },
]
const agentCreateFields: OperationFormField[] = [
  { key: 'code', label: 'Code', placeholder: 'agent_alpha', help: 'Unique within the active tenant. Backend derives one from name if blank.' },
  { key: 'name', label: 'Name', required: true, placeholder: 'Agent Alpha' },
  { key: 'phone', label: 'Phone' },
  { key: 'email', label: 'Email', placeholder: 'agent@example.test' },
  { key: 'store_id', label: 'Store ID', placeholder: 'Optional store reference' },
  { key: 'status', label: 'Status', type: 'select', options: agentStatusOptions, defaultValue: 'active' },
  { key: 'metadata', label: 'Metadata JSON', type: 'json', defaultValue: '{}', placeholder: '{"source":"bo"}', help: 'Must be a JSON object or array.' },
]
const agentUpdateFields: OperationFormField[] = agentCreateFields.map((field) => {
  const updateField: OperationFormField = {
    ...field,
    required: false,
  }
  delete updateField.defaultValue
  return updateField
})
const agentQuotaFields: OperationFormField[] = [
  { key: 'game_id', label: 'Game ID', sourceKey: 'quotas.0.game_id', placeholder: 'Leave blank for tenant-wide quota' },
  { key: 'quota_count', label: 'Quota count', type: 'number', sourceKey: 'quotas.0.quota_count', min: 0, step: 1, defaultValue: 0 },
  { key: 'used_count', label: 'Used count', type: 'number', sourceKey: 'quotas.0.used_count', min: 0, step: 1, defaultValue: 0 },
  { key: 'status', label: 'Status', type: 'select', sourceKey: 'quotas.0.status', options: agentStatusOptions, defaultValue: 'active' },
  { key: 'payload', label: 'Payload JSON', type: 'json', sourceKey: 'quotas.0.payload', defaultValue: '{}', placeholder: '{"source":"bo"}', help: 'Stored as payload_json. Must be a JSON object or array.' },
]
const updateFields = (fields: OperationFormField[], sourceKeys: Record<string, string> = {}): OperationFormField[] => fields.map((field) => {
  const updateField: OperationFormField = {
    ...field,
    required: false,
    sourceKey: sourceKeys[field.key] || field.sourceKey || field.key,
  }
  delete updateField.defaultValue
  return updateField
})
const affiliateProgramCreateFields: OperationFormField[] = [
  { key: 'code', label: 'Code', placeholder: 'program_may_2026', help: 'Unique within the active tenant. Backend derives one from name if blank.' },
  { key: 'name', label: 'Name', required: true, placeholder: 'May 2026 Program' },
  { key: 'status', label: 'Status', type: 'select', options: affiliateStatusOptions, defaultValue: 'active' },
  { key: 'starts_at', label: 'Starts at', type: 'datetime-local' },
  { key: 'ends_at', label: 'Ends at', type: 'datetime-local' },
  { key: 'metadata', label: 'Metadata JSON', type: 'json', defaultValue: '{}', placeholder: '{"source":"bo"}', help: 'Must be a JSON object or array.' },
]
const affiliateProgramUpdateFields = updateFields(affiliateProgramCreateFields)
const affiliateAccountCreateFields: OperationFormField[] = [
  { key: 'customer_id', label: 'Customer ID', placeholder: 'Optional same-tenant customer ID' },
  { key: 'code', label: 'Code', placeholder: 'affiliate_alpha', help: 'Unique within the active tenant. Backend derives one from name if blank.' },
  { key: 'name', label: 'Name', required: true, placeholder: 'Affiliate Alpha' },
  { key: 'phone', label: 'Phone' },
  { key: 'email', label: 'Email', placeholder: 'affiliate@example.test' },
  { key: 'status', label: 'Status', type: 'select', options: affiliateStatusOptions, defaultValue: 'active' },
  { key: 'currency', label: 'Currency', type: 'select', options: currencyOptions, defaultValue: 'THB' },
  { key: 'payout_profile', label: 'Payout profile JSON', type: 'json', defaultValue: '{}', placeholder: '{"method":"bank_transfer"}', help: 'Stored as payout_profile_json. Must be a JSON object or array.' },
  { key: 'metadata', label: 'Metadata JSON', type: 'json', defaultValue: '{}', placeholder: '{"source":"bo"}', help: 'Must be a JSON object or array.' },
]
const affiliateAccountUpdateFields = updateFields(affiliateAccountCreateFields)
const affiliateLinkCreateFields: OperationFormField[] = [
  { key: 'affiliate_account_id', label: 'Affiliate account ID', required: true },
  { key: 'affiliate_program_id', label: 'Affiliate program ID', placeholder: 'Optional same-tenant program ID' },
  { key: 'code', label: 'Code', defaultValue: 'link', placeholder: 'Unique link code' },
  { key: 'url', label: 'URL', placeholder: 'Optional; backend defaults from code' },
  { key: 'status', label: 'Status', type: 'select', options: affiliateStatusOptions, defaultValue: 'active' },
  { key: 'metadata', label: 'Metadata JSON', type: 'json', defaultValue: '{}', placeholder: '{"source":"bo"}', help: 'Must be a JSON object or array.' },
]
const affiliateLinkUpdateFields = updateFields(affiliateLinkCreateFields)
const commissionRuleCreateFields: OperationFormField[] = [
  { key: 'affiliate_program_id', label: 'Affiliate program ID', placeholder: 'Optional same-tenant program ID' },
  { key: 'affiliate_account_id', label: 'Affiliate account ID', placeholder: 'Optional same-tenant affiliate account ID' },
  { key: 'code', label: 'Code', placeholder: 'commission_rule_alpha', help: 'Unique within the active tenant. Backend derives one from name if blank.' },
  { key: 'name', label: 'Name', required: true, placeholder: 'Commission Rule Alpha' },
  { key: 'rule_type', label: 'Rule type', type: 'select', options: commissionRuleTypeOptions, defaultValue: 'fixed_per_order', required: true },
  { key: 'amount.amount', label: 'Amount (minor units)', type: 'number', min: 0, step: 1, defaultValue: 100, help: 'Required for fixed_per_order and per_ticket. Use the smallest currency unit.' },
  { key: 'rate_bps', label: 'Rate (basis points)', type: 'number', min: 0, step: 1, defaultValue: 0, help: 'Required when rule_type is percent_sales. 100 bps = 1%.' },
  { key: 'amount.currency', label: 'Currency', type: 'select', options: currencyOptions, defaultValue: 'THB' },
  { key: 'status', label: 'Status', type: 'select', options: affiliateStatusOptions, defaultValue: 'active' },
  { key: 'metadata', label: 'Metadata JSON', type: 'json', defaultValue: '{}', placeholder: '{"source":"bo"}', help: 'Must be a JSON object or array.' },
]
const commissionRuleUpdateFields = updateFields(commissionRuleCreateFields, {
  'amount.amount': 'amount.amount',
  'amount.currency': 'amount.currency',
})
const tenantSeoSettingsFields: OperationFormField[] = [
  { key: 'status', label: 'Status', type: 'select', options: seoStatusOptions, defaultValue: 'active' },
  { key: 'default_title', label: 'Default title', required: true, placeholder: 'Tenant SEO title' },
  { key: 'title_template', label: 'Title template', placeholder: '{{title}} | NewPaotang' },
  { key: 'default_description', label: 'Default description', type: 'textarea' },
  { key: 'default_keywords', label: 'Default keywords', type: 'lines', emptyValue: 'array', placeholder: 'lottery\ntenant', help: 'One keyword per line. Submitted as an array.' },
  { key: 'robots_default', label: 'Robots default', defaultValue: 'index,follow' },
  { key: 'canonical_base_url', label: 'Canonical base URL', placeholder: 'https://tenant.example.test' },
  { key: 'og_image_url', label: 'Open graph image URL' },
]
const seoPageCreateFields: OperationFormField[] = [
  { key: 'path', label: 'Path', required: true, placeholder: '/promotions', help: 'Unique per tenant. Backend normalizes the path.' },
  { key: 'title', label: 'Title', required: true, placeholder: 'Promotions' },
  { key: 'description', label: 'Description', type: 'textarea' },
  { key: 'canonical_url', label: 'Canonical URL', placeholder: 'https://tenant.example.test/promotions' },
  { key: 'robots', label: 'Robots', defaultValue: 'index,follow' },
  { key: 'og_image_url', label: 'Open graph image URL' },
  { key: 'status', label: 'Status', type: 'select', options: seoStatusOptions, defaultValue: 'active' },
  { key: 'metadata', label: 'Metadata JSON', type: 'json', defaultValue: '{}', placeholder: '{"source":"bo"}', help: 'Stored as metadata_json. Must be a JSON object or array.' },
]
const seoPageUpdateFields = updateFields(seoPageCreateFields)
const redirectCreateFields: OperationFormField[] = [
  { key: 'source_path', label: 'Source path', required: true, placeholder: '/old-promotions', help: 'Unique per tenant. Backend normalizes the path.' },
  { key: 'target_url', label: 'Target URL', required: true, placeholder: 'https://tenant.example.test/promotions' },
  { key: 'status_code', label: 'Status code', type: 'select', options: redirectStatusCodeOptions, defaultValue: '301' },
  { key: 'status', label: 'Status', type: 'select', options: seoStatusOptions, defaultValue: 'active' },
  { key: 'metadata', label: 'Metadata JSON', type: 'json', defaultValue: '{}', placeholder: '{"source":"bo"}', help: 'Stored as metadata_json. Must be a JSON object or array.' },
]
const redirectUpdateFields = updateFields(redirectCreateFields)
const partnerCreateFields: OperationFormField[] = [
  { key: 'code', label: 'Partner code', required: true, placeholder: 'acme_partner', help: 'Use lowercase letters, numbers, underscores, or hyphens.' },
  { key: 'name', label: 'Partner name', required: true, placeholder: 'Acme Partner' },
  { key: 'type', label: 'Partner type', type: 'select', options: partnerTypeOptions, defaultValue: 'partner_store', required: true },
  { key: 'status', label: 'Status', type: 'select', options: partnerStatusOptions, defaultValue: 'draft', required: true },
]
const partnerUpdateFields: OperationFormField[] = [
  { key: 'code', label: 'Partner code', placeholder: 'acme_partner', help: 'Use lowercase letters, numbers, underscores, or hyphens.' },
  { key: 'name', label: 'Partner name' },
  { key: 'type', label: 'Partner type', type: 'select', options: partnerTypeOptions },
  { key: 'status', label: 'Status', type: 'select', options: partnerStatusOptions },
]
const partnerProvisionFields: OperationFormField[] = [
  { key: 'tenant_code', label: 'Tenant code', placeholder: 'acme_tenant', help: 'Defaults to the partner code when left blank.' },
  { key: 'tenant_name', label: 'Tenant name', placeholder: 'Acme Tenant' },
  { key: 'tenant_status', label: 'Tenant status', type: 'select', options: tenantStatusOptions, defaultValue: 'active' },
  { key: 'domain_host', label: 'Domain host', placeholder: 'acme.example.test' },
  { key: 'domain_type', label: 'Domain type', type: 'select', options: domainTypeOptions, defaultValue: 'subdomain' },
  { key: 'owner_email', label: 'Owner email', required: true, placeholder: 'owner@example.test' },
  { key: 'owner_name', label: 'Owner name', placeholder: 'Tenant owner' },
  { key: 'owner_password', label: 'Owner password', type: 'password', placeholder: 'Leave blank to keep generated/default handling' },
  { key: 'site_name', label: 'Site name', placeholder: 'Public shop name' },
  { key: 'billing_plan_code', label: 'Billing plan code', placeholder: 'starter' },
  { key: 'deployment_mode', label: 'Deployment mode', type: 'select', options: deploymentModeOptions, defaultValue: 'shared' },
  { key: 'features.affiliate', label: 'Affiliate feature', type: 'checkbox', defaultValue: false },
  { key: 'features.custom_domain', label: 'Custom domain feature', type: 'checkbox', defaultValue: false },
]
const gameCreateFields: OperationFormField[] = [
  { key: 'name', label: 'Game name', required: true, placeholder: 'May 2026 Draw' },
  {
    key: 'sale_window',
    label: 'Sale window',
    type: 'datetime-range',
    required: true,
    rangeStartKey: 'sale_start_at',
    rangeEndKey: 'close_at',
    rangeStartSourceKey: 'sale_start_at',
    rangeEndSourceKey: 'close_at',
    rangeStartLabel: 'Sale start',
    rangeEndLabel: 'Sale close',
    help: 'Central sale opening and closing date-time.',
  },
  { key: 'draw_at', label: 'Draw at', type: 'datetime-local', required: true, help: 'Game code is generated from the draw date as DDMMBBBB, for example 01042569.' },
  { key: 'status', label: 'Initial status', type: 'select', options: gameCreateStatusOptions, defaultValue: 'draft', required: true },
]
const gameUpdateFields: OperationFormField[] = [
  { key: 'name', label: 'Game name' },
  {
    key: 'sale_window',
    label: 'Sale window',
    type: 'datetime-range',
    rangeStartKey: 'sale_start_at',
    rangeEndKey: 'close_at',
    rangeStartSourceKey: 'sale_start_at',
    rangeEndSourceKey: 'close_at',
    rangeStartLabel: 'Sale start',
    rangeEndLabel: 'Sale close',
    help: 'Sale close must be after sale start and before draw.',
  },
  { key: 'draw_at', label: 'Draw at', type: 'datetime-local', help: 'Changing this date regenerates the game code as DDMMBBBB.' },
  {
    key: 'status',
    label: 'Lifecycle transition',
    type: 'select',
    sourceKey: '__next_status',
    options: gameLifecycleTransitionOptions,
    help: 'Optional. Backend allows only the next valid transition, such as draft to open or closed to reward_recorded.',
  },
]
const billingPlanFields: OperationFormField[] = [
  { key: 'code', label: 'Plan code', required: true, placeholder: 'enterprise' },
  { key: 'name', label: 'Plan name', required: true, placeholder: 'Enterprise' },
  { key: 'monthly_fee_amount', label: 'Monthly fee (minor units)', type: 'number', sourceKey: 'monthly_fee.amount', min: 0, step: 1, required: true },
  { key: 'currency', label: 'Currency', type: 'select', sourceKey: 'monthly_fee.currency', options: currencyOptions, defaultValue: 'THB', required: true },
  { key: 'status', label: 'Status', type: 'select', options: billingPlanStatusOptions, defaultValue: 'active', required: true },
  { key: 'features.affiliate', label: 'Affiliate included', type: 'checkbox', defaultValue: false },
  { key: 'features.custom_domain', label: 'Custom domain included', type: 'checkbox', defaultValue: false },
  { key: 'features.priority_support', label: 'Priority support included', type: 'checkbox', defaultValue: false },
  { key: 'limits.tenants', label: 'Tenant limit', type: 'number', min: 0, step: 1 },
  { key: 'limits.api_requests', label: 'API request limit', type: 'number', min: 0, step: 1 },
  { key: 'limits.alert_policies', label: 'Alert policy limit', type: 'number', min: 0, step: 1 },
]
const billingPlanUpdateFields: OperationFormField[] = [
  { key: 'code', label: 'Plan code', placeholder: 'enterprise' },
  { key: 'name', label: 'Plan name', placeholder: 'Enterprise' },
  { key: 'monthly_fee_amount', label: 'Monthly fee (minor units)', type: 'number', sourceKey: 'monthly_fee.amount', min: 0, step: 1 },
  { key: 'currency', label: 'Currency', type: 'select', sourceKey: 'monthly_fee.currency', options: currencyOptions },
  { key: 'status', label: 'Status', type: 'select', options: billingPlanStatusOptions },
  { key: 'limits.tenants', label: 'Tenant limit', type: 'number', sourceKey: 'limits.tenants', min: 0, step: 1 },
  { key: 'limits.api_requests', label: 'API request limit', type: 'number', sourceKey: 'limits.api_requests', min: 0, step: 1 },
  { key: 'limits.alert_policies', label: 'Alert policy limit', type: 'number', sourceKey: 'limits.alert_policies', min: 0, step: 1 },
]
const alertPolicyFields: OperationFormField[] = [
  { key: 'partner_id', label: 'Partner ID', required: true },
  { key: 'policy_key', label: 'Policy key', required: true, placeholder: 'sync_lag' },
  { key: 'severity', label: 'Severity', type: 'select', options: alertSeverityOptions, defaultValue: 'warning', required: true },
  { key: 'status', label: 'Status', type: 'select', options: alertPolicyStatusOptions, defaultValue: 'active', required: true },
  { key: 'config.metric', label: 'Metric', placeholder: 'sync_lag_seconds' },
  { key: 'config.threshold_seconds', label: 'Threshold seconds', type: 'number', min: 0, step: 1 },
  { key: 'config.window_seconds', label: 'Window seconds', type: 'number', min: 0, step: 1 },
  { key: 'config.description', label: 'Description', type: 'textarea' },
]
const alertPolicyUpdateFields: OperationFormField[] = alertPolicyFields.map((field) => ({ ...field, required: false }))
const rewardCreateFields: OperationFormField[] = [
  { key: 'game_id', label: 'Game ID', required: true },
  { key: 'prizes', label: 'Winning numbers', type: 'reward-prize-number-grid', required: true, help: rewardPrizeNumberHelp },
]
const rewardNumberUpdateFields: OperationFormField[] = [
  { key: 'prize_number_updates', label: 'Winning numbers', type: 'reward-prize-number-grid', sourceKey: 'prizes', required: true, partial: true, help: rewardPrizeNumberHelp },
]
const rewardPayoutUpdateFields: OperationFormField[] = [
  { key: 'payout_amount_updates', label: 'Payout amounts', type: 'reward-prize-amount-grid', sourceKey: 'prizes', required: true, partial: true, help: rewardPrizeAmountHelp },
]
const tenant: OperationResource[] = [
  {
    scope: 'tenant',
    slug: 'stock',
    title: 'Tenant Stock',
    group: 'Tenant Operations',
    listEndpoint: '/admin/tenant/stock',
    detailEndpoint: '/admin/tenant/stock/{stock_item_id}',
    idParam: 'stock_item_id',
    idKey: 'id',
    apiSort: true,
    columns: [
      { key: 'full_number', label: 'Number' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'owner_customer_id', label: 'Owner' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([
      { key: 'game_id', label: 'Game', type: 'select', optionSource: 'tenant-stock-games', hideEmptyOption: true, emptyOptionLabel: 'No stock game' },
      statusFilter(['available', 'reserved', 'sold', 'recalled', 'inactive']),
      { key: 'number', label: 'Number' },
    ]),
    confirmContextFields: stockActionContext,
    collectionActions: [{
      key: 'export',
      label: 'Export stock',
      endpoint: '/admin/tenant/stock/exports',
      reason: true,
      formFields: [
        { key: 'game_id', label: 'Game ID', placeholder: 'Optional game filter' },
        { key: 'filters.status', label: 'Status', type: 'select', options: ['available', 'reserved', 'sold', 'recalled', 'inactive'] },
        { key: 'number', label: 'Ticket number', placeholder: 'Optional exact number' },
      ],
    }],
  },
  {
    scope: 'tenant',
    slug: 'price-rules',
    title: 'Price Rules',
    group: 'Tenant Store Operations',
    listEndpoint: '/admin/tenant/price-rules',
    detailEndpoint: '/admin/tenant/price-rules/{price_rule_id}',
    updateEndpoint: '/admin/tenant/price-rules/{price_rule_id}',
    idParam: 'price_rule_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Price rule' },
      { key: 'game_id', label: 'Game' },
      { key: 'code', label: 'Code' },
      { key: 'rule_type', label: 'Type' },
      { key: 'reward_preview.summary.base_total', label: 'Central Reward', type: 'money' },
      { key: 'adjustment', label: 'Adjustment', type: 'money' },
      { key: 'reward_preview.summary.effective_total', label: 'Partner Reward', type: 'money' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([{ key: 'game_id', label: 'Game ID' }, statusFilter(priceRuleStatusOptions)]),
    confirmContextFields: priceRuleActionContext,
    actions: [
      {
        key: 'update',
        label: 'Update price rule',
        method: 'PATCH',
        endpoint: '/admin/tenant/price-rules/{price_rule_id}',
        variant: 'primary',
        contextFields: priceRuleActionContext,
        formFields: priceRuleUpdateFields,
      },
      {
        key: 'archive',
        label: 'Archive',
        method: 'DELETE',
        endpoint: '/admin/tenant/price-rules/{price_rule_id}',
        variant: 'danger',
        reason: true,
        contextFields: priceRuleActionContext,
      },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Create price rule',
      endpoint: '/admin/tenant/price-rules',
      formFields: priceRuleCreateFields,
    }],
  },
  {
    scope: 'tenant',
    slug: 'reservations',
    title: 'Reservations',
    group: 'Tenant Orders',
    listEndpoint: '/admin/tenant/reservations',
    idParam: 'reservation_id',
    columns: [
      { key: 'id', label: 'Reservation' },
      { key: 'customer_id', label: 'Customer' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'expires_at', label: 'Expires', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(['pending', 'confirmed', 'expired', 'cancelled']), { key: 'customer_id', label: 'Customer ID' }]),
    confirmContextFields: ['id', 'customer_id', 'status', 'expires_at'],
    actions: [{ key: 'cancel', label: 'Cancel', endpoint: '/admin/tenant/reservations/{reservation_id}/cancel', variant: 'warning', reason: true, contextFields: ['id', 'customer_id', 'status', 'expires_at'] }],
  },
  {
    scope: 'tenant',
    slug: 'orders',
    title: 'Orders',
    group: 'Tenant Orders',
    listEndpoint: '/admin/tenant/orders',
    detailEndpoint: '/admin/tenant/orders/{order_id}',
    updateEndpoint: '/admin/tenant/orders/{order_id}',
    idParam: 'order_id',
    columns: [
      { key: 'id', label: 'Order' },
      { key: 'customer', label: 'Customer', type: 'customer', fallbackKeys: ['customer_id', 'member_id'] },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'total.amount', label: 'Total', type: 'money' },
      { key: 'created_at', label: 'Created', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(['draft', 'pending_payment', 'paid', 'cancelled', 'expired', 'refunded', 'failed']), { key: 'payment_status', label: 'Payment status', type: 'select', options: ['unpaid', 'pending', 'paid', 'refunded', 'failed'] }, { key: 'game_id', label: 'Game ID' }, { key: 'customer_id', label: 'Customer ID' }]),
    confirmContextFields: orderActionContext,
    actions: [
      {
        key: 'update',
        label: 'Update',
        method: 'PATCH',
        endpoint: '/admin/tenant/orders/{order_id}',
        variant: 'primary',
        reason: true,
        contextFields: orderActionContext,
        formFields: [
          { key: 'status', label: 'Order status', type: 'select', options: ['pending_payment', 'paid', 'cancelled', 'expired', 'refunded', 'failed'] },
          { key: 'payment_status', label: 'Payment status', type: 'select', options: ['unpaid', 'pending', 'paid', 'refunded', 'failed'] },
          { key: 'admin_note', label: 'Admin note', type: 'textarea', placeholder: 'Optional internal note' },
        ],
      },
      {
        key: 'cancel',
        label: 'Cancel',
        endpoint: '/admin/tenant/orders/{order_id}/cancel',
        variant: 'warning',
        reason: true,
        contextFields: orderActionContext,
        formFields: [
          { key: 'refund_policy', label: 'Refund policy', type: 'select', options: ['none', 'wallet_refund', 'manual_refund'], defaultValue: 'none' },
          notifyCustomerField,
        ],
      },
      {
        key: 'refund',
        label: 'Refund',
        endpoint: '/admin/tenant/orders/{order_id}/refund',
        variant: 'danger',
        reason: true,
        contextFields: orderActionContext,
        formFields: [
          ...moneyFields('amount', 'Refund amount'),
          { key: 'method', label: 'Refund method', type: 'select', options: ['wallet_refund', 'manual_refund', 'original_payment'], defaultValue: 'wallet_refund' },
          notifyCustomerField,
        ],
      },
    ],
  },
  {
    scope: 'tenant',
    slug: 'customers',
    title: 'Customers',
    group: 'Tenant Store Operations',
    listEndpoint: '/admin/tenant/members',
    detailEndpoint: '/admin/tenant/members/{member_id}',
    updateEndpoint: '/admin/tenant/members/{member_id}',
    idParam: 'member_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Member' },
      { key: 'member_no', label: 'Member no' },
      { key: 'name', label: 'Name' },
      { key: 'phone', label: 'Phone' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'order_count', label: 'Orders' },
      { key: 'lifetime_spend.amount', label: 'Lifetime spend', type: 'money' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([
      { key: 'q', label: 'Search' },
      statusFilter(memberStatusOptions),
      { key: 'registered_from', label: 'Registered from', type: 'date' },
      { key: 'registered_to', label: 'Registered to', type: 'date' },
    ]),
    confirmContextFields: memberActionContext,
    actions: [
      {
        key: 'update',
        label: 'Update member',
        method: 'PATCH',
        endpoint: '/admin/tenant/members/{member_id}',
        variant: 'primary',
        contextFields: memberActionContext,
        formFields: memberUpdateFields,
      },
      {
        key: 'status',
        label: 'Change status',
        endpoint: '/admin/tenant/members/{member_id}/status',
        variant: 'warning',
        reason: true,
        contextFields: memberActionContext,
        formFields: memberStatusFields,
      },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Create member',
      endpoint: '/admin/tenant/members',
      formFields: memberCreateFields,
    }],
  },
  resource('tenant', 'tickets', 'Tickets', 'Tenant Support', '/admin/tenant/tickets', '/admin/tenant/tickets/{ticket_id}', 'ticket_id', [
    { key: 'id', label: 'Ticket' },
    { key: 'customer_id', label: 'Customer' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'created_at', label: 'Created', type: 'datetime' },
  ], cursorFilters([statusFilter(['active', 'open', 'pending', 'resolved', 'closed'])])),
  {
    scope: 'tenant',
    slug: 'wallets',
    title: 'Wallets',
    group: 'Tenant Finance',
    listEndpoint: '/admin/tenant/wallets',
    detailEndpoint: '/admin/tenant/wallets/{wallet_id}',
    updateEndpoint: '/admin/tenant/wallets/{wallet_id}/adjust',
    idParam: 'wallet_id',
    columns: [
      { key: 'id', label: 'Wallet' },
      { key: 'customer_id', label: 'Customer' },
      { key: 'balance', label: 'Balance', type: 'money' },
      { key: 'status', label: 'Status', type: 'status' },
    ],
    filters: cursorFilters([{ key: 'customer_id', label: 'Customer ID' }]),
    confirmContextFields: moneyActionContext,
    actions: [{
      key: 'adjust',
      label: 'Adjust',
      method: 'PATCH',
      endpoint: '/admin/tenant/wallets/{wallet_id}/adjust',
      variant: 'warning',
      reason: true,
      contextFields: moneyActionContext,
      formFields: moneyFields('amount', 'Adjustment amount'),
    }],
    relatedLists: [{
      key: 'ledger',
      title: 'Wallet Ledger',
      listEndpoint: '/admin/tenant/wallets/{wallet_id}/ledger',
      idParam: 'ledger_id',
      columns: [
        { key: 'id', label: 'Ledger' },
        { key: 'entry_type', label: 'Type', type: 'status' },
        { key: 'amount.amount', label: 'Amount', type: 'money' },
        { key: 'balance_after.amount', label: 'Balance after', type: 'money' },
        { key: 'reference_type', label: 'Reference' },
        { key: 'created_at', label: 'Created', type: 'datetime' },
      ],
      emptyTitle: 'No ledger entries',
      emptyMessage: 'No ledger entries were returned for this wallet.',
    }],
  },
  actionResource('tenant', 'topups', 'Topups', 'Tenant Finance', '/admin/tenant/topups', '/admin/tenant/topups/{topup_id}', 'topup_id', [
    {
      key: 'approve',
      label: 'Approve',
      endpoint: '/admin/tenant/topups/{topup_id}/approve',
      variant: 'success',
      reason: true,
      contextFields: topupActionContext,
      formFields: [
        ...moneyFields('approved_amount', 'Approved amount', false),
        ...moneyFields('bonus_amount', 'Bonus amount', false),
        notifyCustomerField,
      ],
    },
    { key: 'reject', label: 'Reject', endpoint: '/admin/tenant/topups/{topup_id}/reject', variant: 'danger', reason: true, contextFields: topupActionContext, formFields: [notifyCustomerField] },
    { key: 'cancel', label: 'Cancel', endpoint: '/admin/tenant/topups/{topup_id}/cancel', variant: 'warning', reason: true, contextFields: topupActionContext, formFields: [notifyCustomerField] },
  ]),
  actionResource('tenant', 'reward-claims', 'Reward Claims', 'Tenant Rewards', '/admin/tenant/reward-claims', '/admin/tenant/reward-claims/{claim_id}', 'claim_id', [
    { key: 'approve', label: 'Approve', endpoint: '/admin/tenant/reward-claims/{claim_id}/approve', variant: 'success', reason: true },
    { key: 'reject', label: 'Reject', endpoint: '/admin/tenant/reward-claims/{claim_id}/reject', variant: 'danger', reason: true },
    { key: 'pay', label: 'Pay', endpoint: '/admin/tenant/reward-claims/{claim_id}/pay', variant: 'primary', reason: true },
  ]),
  {
    scope: 'tenant',
    slug: 'growth/agents',
    title: 'Agents',
    group: 'Tenant Growth',
    listEndpoint: '/admin/tenant/agents',
    detailEndpoint: '/admin/tenant/agents/{agent_id}',
    updateEndpoint: '/admin/tenant/agents/{agent_id}',
    idParam: 'agent_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Agent' },
      { key: 'code', label: 'Code' },
      { key: 'name', label: 'Name' },
      { key: 'store_id', label: 'Store' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(agentStatusOptions)]),
    confirmContextFields: agentActionContext,
    actions: [
      {
        key: 'update',
        label: 'Update agent',
        method: 'PATCH',
        endpoint: '/admin/tenant/agents/{agent_id}',
        variant: 'primary',
        contextFields: agentActionContext,
        formFields: agentUpdateFields,
      },
      {
        key: 'quotas',
        label: 'Update quotas',
        method: 'PATCH',
        endpoint: '/admin/tenant/agents/{agent_id}/quotas',
        variant: 'warning',
        reason: true,
        contextFields: agentQuotaActionContext,
        formFields: agentQuotaFields,
      },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Create agent',
      endpoint: '/admin/tenant/agents',
      formFields: agentCreateFields,
    }],
  },
  {
    scope: 'tenant',
    slug: 'growth/agent-quotas',
    title: 'Agent Quotas',
    group: 'Tenant Growth',
    listEndpoint: '/admin/tenant/agents',
    detailEndpoint: '/admin/tenant/agents/{agent_id}',
    idParam: 'agent_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Agent' },
      { key: 'code', label: 'Code' },
      { key: 'name', label: 'Name' },
      { key: 'store_id', label: 'Store' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(agentStatusOptions)]),
    confirmContextFields: agentQuotaActionContext,
    actions: [{
      key: 'quotas',
      label: 'Update quotas',
      method: 'PATCH',
      endpoint: '/admin/tenant/agents/{agent_id}/quotas',
      variant: 'warning',
      reason: true,
      contextFields: agentQuotaActionContext,
      formFields: agentQuotaFields,
    }],
  },
  {
    scope: 'tenant',
    slug: 'growth/affiliate-programs',
    title: 'Affiliate Programs',
    group: 'Tenant Growth',
    listEndpoint: '/admin/tenant/affiliate-programs',
    detailEndpoint: '/admin/tenant/affiliate-programs/{affiliate_program_id}',
    updateEndpoint: '/admin/tenant/affiliate-programs/{affiliate_program_id}',
    idParam: 'affiliate_program_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Program' },
      { key: 'code', label: 'Code' },
      { key: 'name', label: 'Name' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'starts_at', label: 'Starts', type: 'datetime' },
      { key: 'ends_at', label: 'Ends', type: 'datetime' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(affiliateStatusOptions)]),
    confirmContextFields: affiliateProgramActionContext,
    actions: [
      {
        key: 'update',
        label: 'Update program',
        method: 'PATCH',
        endpoint: '/admin/tenant/affiliate-programs/{affiliate_program_id}',
        variant: 'primary',
        contextFields: affiliateProgramActionContext,
        formFields: affiliateProgramUpdateFields,
      },
      {
        key: 'delete',
        label: 'Archive',
        method: 'DELETE',
        endpoint: '/admin/tenant/affiliate-programs/{affiliate_program_id}',
        variant: 'danger',
        reason: true,
        contextFields: affiliateProgramActionContext,
      },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Create program',
      endpoint: '/admin/tenant/affiliate-programs',
      formFields: affiliateProgramCreateFields,
    }],
  },
  {
    scope: 'tenant',
    slug: 'growth/affiliate-links',
    title: 'Affiliate Links',
    group: 'Tenant Growth',
    listEndpoint: '/admin/tenant/affiliate-links',
    detailEndpoint: '/admin/tenant/affiliate-links/{affiliate_link_id}',
    updateEndpoint: '/admin/tenant/affiliate-links/{affiliate_link_id}',
    idParam: 'affiliate_link_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Link' },
      { key: 'affiliate_account_id', label: 'Affiliate' },
      { key: 'affiliate_program_id', label: 'Program' },
      { key: 'code', label: 'Code' },
      { key: 'url', label: 'URL' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(affiliateStatusOptions), { key: 'affiliate_id', label: 'Affiliate ID' }]),
    confirmContextFields: affiliateLinkActionContext,
    actions: [
      {
        key: 'update',
        label: 'Update link',
        method: 'PATCH',
        endpoint: '/admin/tenant/affiliate-links/{affiliate_link_id}',
        variant: 'primary',
        contextFields: affiliateLinkActionContext,
        formFields: affiliateLinkUpdateFields,
      },
      {
        key: 'delete',
        label: 'Archive',
        method: 'DELETE',
        endpoint: '/admin/tenant/affiliate-links/{affiliate_link_id}',
        variant: 'danger',
        reason: true,
        contextFields: affiliateLinkActionContext,
      },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Create link',
      endpoint: '/admin/tenant/affiliate-links',
      formFields: affiliateLinkCreateFields,
    }],
  },
  resource('tenant', 'growth/attributions', 'Affiliate Attributions', 'Tenant Growth', '/admin/tenant/affiliate-attributions', '/admin/tenant/affiliate-attributions/{attribution_id}', 'attribution_id', growthColumns(), cursorFilters([statusFilter()])),
  {
    scope: 'tenant',
    slug: 'growth/affiliates',
    title: 'Affiliates',
    group: 'Tenant Growth',
    listEndpoint: '/admin/tenant/affiliates',
    detailEndpoint: '/admin/tenant/affiliates/{affiliate_id}',
    updateEndpoint: '/admin/tenant/affiliates/{affiliate_id}',
    idParam: 'affiliate_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Affiliate' },
      { key: 'customer_id', label: 'Customer' },
      { key: 'code', label: 'Code' },
      { key: 'name', label: 'Name' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'wallet_balance.amount', label: 'Wallet', type: 'money' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(affiliateStatusOptions), { key: 'customer_id', label: 'Customer ID' }]),
    confirmContextFields: affiliateAccountActionContext,
    actions: [{
      key: 'update',
      label: 'Update affiliate',
      method: 'PATCH',
      endpoint: '/admin/tenant/affiliates/{affiliate_id}',
      variant: 'primary',
      contextFields: affiliateAccountActionContext,
      formFields: affiliateAccountUpdateFields,
    }],
    collectionActions: [{
      key: 'create',
      label: 'Create affiliate',
      endpoint: '/admin/tenant/affiliates',
      formFields: affiliateAccountCreateFields,
    }],
  },
  {
    scope: 'tenant',
    slug: 'growth/commission-rules',
    title: 'Commission Rules',
    group: 'Tenant Growth',
    listEndpoint: '/admin/tenant/commission-rules',
    detailEndpoint: '/admin/tenant/commission-rules/{commission_rule_id}',
    updateEndpoint: '/admin/tenant/commission-rules/{commission_rule_id}',
    idParam: 'commission_rule_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Rule' },
      { key: 'affiliate_account_id', label: 'Affiliate' },
      { key: 'affiliate_program_id', label: 'Program' },
      { key: 'code', label: 'Code' },
      { key: 'name', label: 'Name' },
      { key: 'rule_type', label: 'Type' },
      { key: 'amount.amount', label: 'Amount', type: 'money' },
      { key: 'rate_bps', label: 'BPS' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(affiliateStatusOptions), { key: 'affiliate_account_id', label: 'Affiliate account ID' }]),
    confirmContextFields: commissionRuleActionContext,
    actions: [
      {
        key: 'update',
        label: 'Update rule',
        method: 'PATCH',
        endpoint: '/admin/tenant/commission-rules/{commission_rule_id}',
        variant: 'primary',
        contextFields: commissionRuleActionContext,
        formFields: commissionRuleUpdateFields,
      },
      {
        key: 'delete',
        label: 'Archive',
        method: 'DELETE',
        endpoint: '/admin/tenant/commission-rules/{commission_rule_id}',
        variant: 'danger',
        reason: true,
        contextFields: commissionRuleActionContext,
      },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Create commission rule',
      endpoint: '/admin/tenant/commission-rules',
      formFields: commissionRuleCreateFields,
    }],
  },
  {
    scope: 'tenant',
    slug: 'growth/commission-transactions',
    title: 'Commission Transactions',
    group: 'Tenant Growth',
    listEndpoint: '/admin/tenant/commission-transactions',
    idParam: 'commission_id',
    columns: [
      { key: 'id', label: 'Commission' },
      { key: 'affiliate_account_id', label: 'Affiliate' },
      { key: 'order_id', label: 'Order' },
      { key: 'commission_rule_id', label: 'Rule' },
      { key: 'transaction_type', label: 'Type' },
      { key: 'amount', label: 'Amount', type: 'money' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'calculated_at', label: 'Calculated', type: 'datetime' },
      { key: 'approved_at', label: 'Approved', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(['calculated', 'approved', 'reversed'])]),
    confirmContextFields: commissionTransactionActionContext,
    actions: [{
      key: 'approve',
      label: 'Approve',
      endpoint: '/admin/tenant/commission-transactions/{commission_id}/approve',
      variant: 'success',
      reason: true,
      contextFields: commissionTransactionActionContext,
    }],
    detailApiGap: 'OpenAPI documents list and approve action, but no commission transaction detail route.',
  },
  {
    scope: 'tenant',
    slug: 'growth/payouts',
    title: 'Payouts',
    group: 'Tenant Growth',
    listEndpoint: '/admin/tenant/payouts',
    idParam: 'payout_id',
    columns: [
      { key: 'id', label: 'Payout' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'amount', label: 'Amount', type: 'money' },
      { key: 'created_at', label: 'Created', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(['pending', 'approved', 'rejected', 'paid'])]),
    confirmContextFields: ['id', 'affiliate_id', 'affiliate_account_id', 'status', 'amount.amount', 'payout_method'],
    actions: [{ key: 'approve', label: 'Approve', endpoint: '/admin/tenant/payouts/{payout_id}/approve', variant: 'success', reason: true, contextFields: ['id', 'affiliate_id', 'affiliate_account_id', 'status', 'amount.amount', 'payout_method'] }],
    collectionActions: [{
      key: 'create',
      label: 'Create payout',
      endpoint: '/admin/tenant/payouts',
      reason: true,
      formFields: [
        { key: 'affiliate_id', label: 'Affiliate ID', required: true },
        ...moneyFields('amount', 'Payout amount'),
        { key: 'payout_method', label: 'Payout method', type: 'select', options: ['bank_transfer', 'manual_cash', 'wallet_credit'], defaultValue: 'bank_transfer', required: true },
        { key: 'bank_account.bank_name', label: 'Bank name', placeholder: 'Required for bank transfer' },
        { key: 'bank_account.account_number', label: 'Account number', placeholder: 'Required for bank transfer' },
      ],
    }],
  },
  summaryResource('tenant', 'monitoring', 'Monitoring', 'Tenant Operations Control', '/admin/tenant/monitoring'),
  summaryResource('tenant', 'usage', 'Usage', 'Tenant Operations Control', '/admin/tenant/usage', [
    { key: 'date_from', label: 'From', type: 'date' },
    { key: 'date_to', label: 'To', type: 'date' },
  ]),
  adminUserResource('tenant', cursorFilters([
    { key: 'q', label: 'Search' },
    statusFilter(adminUserStatusOptions),
    { key: 'role_id', label: 'Role ID' },
  ])),
  roleManagementResource('tenant'),
  settingsResource('tenant', 'menu-management', 'Menu Management', '/admin/tenant/menu-management', 'PUT'),
  {
    ...settingsResource('tenant', 'settings', 'Tenant Settings', '/admin/tenant/settings'),
    settingsFields: tenantSettingsFields,
    secondarySettings: [{
      key: 'theme',
      title: 'Theme And Branding',
      listEndpoint: '/admin/tenant/theme',
      updateEndpoint: '/admin/tenant/theme',
      updateMethod: 'PATCH',
      settingsFields: tenantThemeFields,
    }],
    relatedLists: [{
      key: 'domains',
      title: 'Tenant Domains',
      listEndpoint: '/admin/tenant/domains',
      detailEndpoint: '/admin/tenant/domains/{domain_id}',
      idParam: 'domain_id',
      idKey: 'id',
      columns: [
        { key: 'id', label: 'Domain' },
        { key: 'host', label: 'Host' },
        { key: 'type', label: 'Type' },
        { key: 'status', label: 'Status', type: 'status' },
        { key: 'is_primary', label: 'Primary', type: 'status' },
        { key: 'updated_at', label: 'Updated', type: 'datetime' },
      ],
      collectionActions: [{
        key: 'create',
        label: 'Add domain',
        endpoint: '/admin/tenant/domains',
        reason: true,
        formFields: tenantDomainCreateFields,
      }],
      actions: [
        { key: 'update', label: 'Update', method: 'PATCH', endpoint: '/admin/tenant/domains/{domain_id}', variant: 'primary', reason: true, contextFields: domainActionContext, formFields: tenantDomainUpdateFields },
        { key: 'verify', label: 'Verify', endpoint: '/admin/tenant/domains/{domain_id}/verify', variant: 'success', reason: true, contextFields: domainActionContext, formFields: [
          { key: 'dns_ready', label: 'DNS ready', type: 'checkbox', defaultValue: true },
          { key: 'ssl_ready', label: 'SSL ready', type: 'checkbox', defaultValue: true },
          { key: 'cloudflare_proxy_verified', label: 'Cloudflare proxy verified', type: 'checkbox', defaultValue: true },
          { key: 'https_enforced', label: 'HTTPS enforced', type: 'checkbox', defaultValue: true },
          { key: 'status', label: 'Requested status', type: 'select', options: tenantDomainStatusOptions, defaultValue: 'active' },
        ] },
        { key: 'delete', label: 'Delete', method: 'DELETE', endpoint: '/admin/tenant/domains/{domain_id}', variant: 'danger', reason: true, contextFields: domainActionContext },
      ],
      emptyTitle: 'No tenant domains',
      emptyMessage: 'Add a domain when this tenant needs an operator-managed host.',
    }],
  },
  {
    scope: 'tenant',
    slug: 'payment-settings',
    title: 'Payment Settings',
    group: 'Tenant Settings',
    mode: 'settings',
    listEndpoint: '/admin/tenant/payment-settings',
    updateEndpoint: '/admin/tenant/payment-settings',
    updateMethod: 'PATCH',
    columns: [],
    filters: [],
    settingsFields: [
      { key: 'status', label: 'Status', type: 'select', options: ['active', 'inactive', 'disabled'] },
      { key: 'provider_mode', label: 'Provider mode', type: 'select', options: ['manual_only', 'external_configured'], defaultValue: 'manual_only' },
      { key: 'default_currency', label: 'Default currency', type: 'select', options: currencyOptions, defaultValue: 'THB' },
      { key: 'allow_manual_topup', label: 'Allow manual topup', type: 'checkbox', defaultValue: true },
      { key: 'allow_external_payment', label: 'Allow external payment', type: 'checkbox', defaultValue: false },
      { key: 'payment_provider_status', label: 'Provider status', type: 'select', options: ['blocked_external', 'local_dev_configured', 'manual_only', 'disabled'], defaultValue: 'manual_only' },
      { key: 'config.display_name', label: 'Display name', placeholder: 'Optional customer-facing payment label' },
    ],
    relatedLists: [{
      key: 'payment-channels',
      title: 'Payment Channels',
      listEndpoint: '/admin/tenant/payment-channels',
      detailEndpoint: '/admin/tenant/payment-channels/{payment_channel_id}',
      idParam: 'payment_channel_id',
      columns: [
        { key: 'id', label: 'Channel' },
        { key: 'code', label: 'Code' },
        { key: 'name', label: 'Name' },
        { key: 'provider', label: 'Provider' },
        { key: 'channel_type', label: 'Type' },
        { key: 'status', label: 'Status', type: 'status' },
        { key: 'provider_status', label: 'Provider status', type: 'status' },
      ],
      filters: cursorFilters([statusFilter(['draft', 'active', 'inactive', 'disabled', 'archived', 'blocked_external'])]),
      collectionActions: [{
        key: 'create',
        label: 'Create channel',
        endpoint: '/admin/tenant/payment-channels',
        formFields: [
          { key: 'code', label: 'Code', required: true, placeholder: 'credit_card' },
          { key: 'name', label: 'Name', required: true, placeholder: 'Credit card' },
          { key: 'provider', label: 'Provider', type: 'select', options: ['manual', 'external_payment'], defaultValue: 'manual', required: true },
          { key: 'channel_type', label: 'Channel type', type: 'select', options: ['manual', 'bank_transfer', 'qr', 'card'], defaultValue: 'manual', required: true },
          { key: 'status', label: 'Status', type: 'select', options: ['draft', 'active', 'inactive', 'disabled'], defaultValue: 'draft', required: true },
          { key: 'sort_order', label: 'Sort order', type: 'number', step: 1 },
          { key: 'config.public_label', label: 'Public label', placeholder: 'Shown to operators/customers where supported' },
          { key: 'config.api_key', label: 'Provider API key', type: 'password', placeholder: 'Stored redacted by backend' },
        ],
      }],
      actions: [
        {
          key: 'update',
          label: 'Update',
          method: 'PATCH',
          endpoint: '/admin/tenant/payment-channels/{payment_channel_id}',
          variant: 'primary',
          contextFields: ['id', 'code', 'name', 'provider', 'channel_type', 'status'],
          formFields: [
            { key: 'code', label: 'Code' },
            { key: 'name', label: 'Name' },
            { key: 'provider', label: 'Provider', type: 'select', options: ['manual', 'external_payment'] },
            { key: 'channel_type', label: 'Channel type', type: 'select', options: ['manual', 'bank_transfer', 'qr', 'card'] },
            { key: 'status', label: 'Status', type: 'select', options: ['draft', 'active', 'inactive', 'disabled', 'archived', 'blocked_external'] },
            { key: 'sort_order', label: 'Sort order', type: 'number', step: 1 },
            { key: 'config.public_label', label: 'Public label' },
            { key: 'config.api_key', label: 'Provider API key', type: 'password', placeholder: 'Leave blank to keep existing secret' },
          ],
        },
        { key: 'archive', label: 'Archive', method: 'DELETE', endpoint: '/admin/tenant/payment-channels/{payment_channel_id}', variant: 'danger', reason: true, contextFields: ['id', 'code', 'name', 'provider', 'status'] },
      ],
      emptyTitle: 'No payment channels',
      emptyMessage: 'Create a channel when this tenant needs manual or external payment routing.',
    }],
  },
  {
    ...settingsResource('tenant', 'seo', 'Tenant SEO', '/admin/tenant/seo'),
    settingsFields: tenantSeoSettingsFields,
    relatedLists: [
      {
        key: 'seo-pages',
        title: 'SEO Pages',
        listEndpoint: '/admin/tenant/seo/pages',
        idParam: 'page_id',
        idKey: 'id',
        columns: [
          { key: 'id', label: 'Page' },
          { key: 'path', label: 'Path' },
          { key: 'title', label: 'Title' },
          { key: 'status', label: 'Status', type: 'status' },
          { key: 'robots', label: 'Robots' },
          { key: 'updated_at', label: 'Updated', type: 'datetime' },
        ],
        filters: cursorFilters([statusFilter(seoStatusOptions), { key: 'path', label: 'Path' }]),
        collectionActions: [{
          key: 'create',
          label: 'Create SEO page',
          endpoint: '/admin/tenant/seo/pages',
          formFields: seoPageCreateFields,
        }],
        actions: [
          {
            key: 'update',
            label: 'Update page',
            method: 'PATCH',
            endpoint: '/admin/tenant/seo/pages/{page_id}',
            variant: 'primary',
            contextFields: seoPageActionContext,
            formFields: seoPageUpdateFields,
          },
          {
            key: 'delete',
            label: 'Delete page',
            method: 'DELETE',
            endpoint: '/admin/tenant/seo/pages/{page_id}',
            variant: 'danger',
            reason: true,
            contextFields: seoPageActionContext,
          },
        ],
        emptyTitle: 'No SEO pages',
        emptyMessage: 'Create a page override when this tenant needs route-specific SEO metadata.',
      },
      {
        key: 'redirects',
        title: 'Redirects',
        listEndpoint: '/admin/tenant/redirects',
        idParam: 'redirect_id',
        idKey: 'id',
        columns: [
          { key: 'id', label: 'Redirect' },
          { key: 'source_path', label: 'Source' },
          { key: 'target_url', label: 'Target' },
          { key: 'status_code', label: 'Code' },
          { key: 'status', label: 'Status', type: 'status' },
          { key: 'updated_at', label: 'Updated', type: 'datetime' },
        ],
        filters: cursorFilters([statusFilter(seoStatusOptions)]),
        collectionActions: [{
          key: 'create',
          label: 'Create redirect',
          endpoint: '/admin/tenant/redirects',
          formFields: redirectCreateFields,
        }],
        actions: [
          {
            key: 'update',
            label: 'Update redirect',
            method: 'PATCH',
            endpoint: '/admin/tenant/redirects/{redirect_id}',
            variant: 'primary',
            contextFields: redirectActionContext,
            formFields: redirectUpdateFields,
          },
          {
            key: 'delete',
            label: 'Delete redirect',
            method: 'DELETE',
            endpoint: '/admin/tenant/redirects/{redirect_id}',
            variant: 'danger',
            reason: true,
            contextFields: redirectActionContext,
          },
        ],
        emptyTitle: 'No redirects',
        emptyMessage: 'Create a redirect when this tenant needs a managed route move.',
      },
    ],
  },
  resource('tenant', 'domains', 'Domains', 'Tenant Settings', '/admin/tenant/domains', '/admin/tenant/domains/{domain_id}', 'domain_id', [
    { key: 'id', label: 'Domain' },
    { key: 'hostname', label: 'Hostname' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'updated_at', label: 'Updated', type: 'datetime' },
  ], cursorFilters([statusFilter(['pending', 'verified', 'failed', 'disabled'])]), [
    { key: 'verify', label: 'Verify', endpoint: '/admin/tenant/domains/{domain_id}/verify', variant: 'success', reason: true },
    { key: 'delete', label: 'Delete', method: 'DELETE', endpoint: '/admin/tenant/domains/{domain_id}', variant: 'danger', reason: true },
  ]),
  {
    scope: 'tenant',
    slug: 'audit-logs',
    title: 'Audit Logs',
    group: 'Tenant Operations',
    listEndpoint: '/admin/tenant/audit-logs',
    columns: auditColumns,
    filters: cursorFilters([{ key: 'action', label: 'Action' }]),
  },
  {
    scope: 'tenant',
    slug: 'sync-logs',
    title: 'Sync Logs',
    group: 'Tenant Operations',
    listEndpoint: '/admin/tenant/sync-logs',
    columns: syncColumns,
    filters: cursorFilters([statusFilter(['pending', 'running', 'completed', 'processed', 'failed'])]),
  },
  reportIndex('tenant', ['overview', 'sales', 'stock', 'wallet', 'commission', 'rewards', 'orders', 'customers', 'audit']),
]

const central: OperationResource[] = [
  {
    scope: 'central',
    slug: 'partners',
    title: 'Partners',
    group: 'Central Operations',
    listEndpoint: '/admin/central/partners',
    detailEndpoint: '/admin/central/partners/{partner_id}',
    updateEndpoint: '/admin/central/partners/{partner_id}',
    idParam: 'partner_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Partner' },
      { key: 'code', label: 'Code' },
      { key: 'name', label: 'Name' },
      { key: 'type', label: 'Type' },
      { key: 'stock_percent', label: 'Stock %', type: 'number' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([{ key: 'q', label: 'Search' }, statusFilter(partnerStatusOptions)]),
    confirmContextFields: partnerActionContext,
    actions: [
      { key: 'update', label: 'Update', method: 'PATCH', endpoint: '/admin/central/partners/{partner_id}', variant: 'primary', contextFields: partnerActionContext, formFields: partnerUpdateFields },
      {
        key: 'stock-percent',
        label: 'Edit stock percent',
        method: 'PATCH',
        endpoint: '/admin/central/partners/{partner_id}',
        variant: 'info',
        contextFields: partnerActionContext,
        formFields: [
          partnerStockPercentField(),
        ],
      },
      { key: 'lottery-branding', label: 'Lottery branding', route: adminUiRoute('central', 'partners/{id}/lottery-branding'), variant: 'success', contextFields: partnerActionContext },
      { key: 'suspend', label: 'Suspend', endpoint: '/admin/central/partners/{partner_id}/suspend', variant: 'warning', reason: true, contextFields: partnerActionContext },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Create partner',
      endpoint: '/admin/central/partners',
      formFields: partnerCreateFields,
    }],
  },
  {
    scope: 'central',
    slug: 'partner-provisioning',
    title: 'Partner Provisioning',
    group: 'Central Partner Operations',
    listEndpoint: '/admin/central/partners',
    detailEndpoint: '/admin/central/partners/{partner_id}',
    idParam: 'partner_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Partner' },
      { key: 'code', label: 'Code' },
      { key: 'name', label: 'Name' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'runtime.billing_status', label: 'Billing', type: 'status' },
      { key: 'runtime.monitoring_status', label: 'Monitoring', type: 'status' },
    ],
    filters: cursorFilters([{ key: 'q', label: 'Search' }, statusFilter(partnerStatusOptions)]),
    confirmContextFields: partnerActionContext,
    actions: [
      {
        key: 'provision',
        label: 'Provision',
        endpoint: '/admin/central/partners/{partner_id}/provision',
        variant: 'success',
        reason: true,
        contextFields: partnerActionContext,
        formFields: partnerProvisionFields,
      },
      { key: 'suspend', label: 'Suspend', endpoint: '/admin/central/partners/{partner_id}/suspend', variant: 'warning', reason: true, contextFields: partnerActionContext },
    ],
  },
  apiGapResource('central', 'partner-quotas', 'Partner Quotas', 'Central Partner Operations', 'Partner Quotas is retired for active stock allocation. Use Partners > Edit stock percent and Central Stock > Allocations for virtual distribution workflows.'),
  resource('central', 'partner-monitoring', 'Partner Monitoring', 'Central Partner Operations', '/admin/central/partner-monitoring', '/admin/central/partner-monitoring/{monitoring_profile_id}', 'monitoring_profile_id', [
    { key: 'id', label: 'Profile' },
    { key: 'partner_id', label: 'Partner' },
    { key: 'health_status', label: 'Health', type: 'status' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'updated_at', label: 'Updated', type: 'datetime' },
  ], cursorFilters([{ key: 'partner_id', label: 'Partner ID' }, statusFilter(['active', 'paused', 'archived'])])),
  resource('central', 'partner-usage', 'Partner Usage', 'Central Partner Operations', '/admin/central/partner-usage', '/admin/central/partner-usage/{usage_meter_id}', 'usage_meter_id', [
    { key: 'id', label: 'Usage meter' },
    { key: 'partner_id', label: 'Partner' },
    { key: 'meter_key', label: 'Meter' },
    { key: 'value', label: 'Value' },
    { key: 'limit_value', label: 'Limit' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'updated_at', label: 'Updated', type: 'datetime' },
  ], cursorFilters([
    { key: 'partner_id', label: 'Partner ID' },
    { key: 'date_from', label: 'From', type: 'date' },
    { key: 'date_to', label: 'To', type: 'date' },
  ])),
  {
    scope: 'central',
    slug: 'billing-plans',
    title: 'Billing Plans',
    group: 'Central Partner Operations',
    listEndpoint: '/admin/central/billing-plans',
    detailEndpoint: '/admin/central/billing-plans/{billing_plan_id}',
    updateEndpoint: '/admin/central/billing-plans/{billing_plan_id}',
    idParam: 'billing_plan_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Billing plan' },
      { key: 'code', label: 'Code' },
      { key: 'name', label: 'Name' },
      { key: 'monthly_fee.amount', label: 'Monthly fee', type: 'money' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(billingPlanStatusOptions)]),
    confirmContextFields: billingPlanActionContext,
    actions: [{
      key: 'update',
      label: 'Update',
      method: 'PATCH',
      endpoint: '/admin/central/billing-plans/{billing_plan_id}',
      variant: 'primary',
      contextFields: billingPlanActionContext,
      formFields: billingPlanUpdateFields,
    }],
    collectionActions: [{
      key: 'create',
      label: 'Create billing plan',
      endpoint: '/admin/central/billing-plans',
      formFields: billingPlanFields,
    }],
  },
  {
    scope: 'central',
    slug: 'alert-policies',
    title: 'Alert Policies',
    group: 'Central Partner Operations',
    listEndpoint: '/admin/central/alert-policies',
    detailEndpoint: '/admin/central/alert-policies/{alert_policy_id}',
    updateEndpoint: '/admin/central/alert-policies/{alert_policy_id}',
    idParam: 'alert_policy_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Alert policy' },
      { key: 'partner_id', label: 'Partner' },
      { key: 'policy_key', label: 'Policy' },
      { key: 'severity', label: 'Severity', type: 'status' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([{ key: 'partner_id', label: 'Partner ID' }]),
    confirmContextFields: alertPolicyActionContext,
    actions: [{
      key: 'update',
      label: 'Update',
      method: 'PATCH',
      endpoint: '/admin/central/alert-policies/{alert_policy_id}',
      variant: 'primary',
      contextFields: alertPolicyActionContext,
      formFields: alertPolicyUpdateFields,
    }],
    collectionActions: [{
      key: 'create',
      label: 'Create alert policy',
      endpoint: '/admin/central/alert-policies',
      formFields: alertPolicyFields,
    }],
  },
  resource('central', 'alert-events', 'Alert Events', 'Central Partner Operations', '/admin/central/alert-events', '/admin/central/alert-events/{alert_event_id}', 'alert_event_id', [
    { key: 'id', label: 'Alert event' },
    { key: 'partner_id', label: 'Partner' },
    { key: 'policy_key', label: 'Policy' },
    { key: 'severity', label: 'Severity', type: 'status' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'triggered_at', label: 'Triggered', type: 'datetime' },
    { key: 'delivered_at', label: 'Delivered', type: 'datetime' },
  ], cursorFilters([{ key: 'partner_id', label: 'Partner ID' }, statusFilter(alertEventStatusOptions)]), [
    { key: 'acknowledge', label: 'Acknowledge', endpoint: '/admin/central/alert-events/{alert_event_id}/acknowledge', variant: 'warning', reason: true, contextFields: alertEventActionContext },
    { key: 'resolve', label: 'Resolve', endpoint: '/admin/central/alert-events/{alert_event_id}/resolve', variant: 'success', reason: true, contextFields: alertEventActionContext },
  ]),
  {
    scope: 'central',
    slug: 'stock',
    title: 'Central Stock',
    group: 'Central Operations',
    listEndpoint: '/admin/central/stock',
    idParam: 'stock_item_id',
    stockGrouped: true,
    stockSummaryEndpoint: '/admin/central/stock/summary',
    defaultQuery: { grouped: true },
    apiSort: true,
    columns: [
      { key: 'full_number', label: 'Number' },
      { key: 'total_count', label: 'Tickets', type: 'number' },
      { key: 'available_count', label: 'Available', type: 'number' },
      { key: 'allocated_count', label: 'Allocated', type: 'number' },
      { key: 'sold_count', label: 'Sold', type: 'number' },
      { key: 'recalled_count', label: 'Recalled', type: 'number' },
      { key: 'game_id', label: 'Game' },
      { key: 'last_updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([
      gameSelectFilter(),
      allocationPartnerFilter(),
      allocationTenantFilter(),
      { key: 'allocation_id', label: 'Allocation ID' },
      { key: 'number', label: 'Number search' },
      { key: 'front3', label: 'Front 3' },
      { key: 'back3', label: 'Back 3' },
      { key: 'back2', label: 'Back 2' },
      statusFilter(['available', 'allocated', 'sold', 'recalled']),
    ]),
    confirmContextFields: stockActionContext,
    actions: [{ key: 'recall', label: 'Recall', endpoint: '/admin/central/stock/{stock_item_id}/recall', variant: 'warning', reason: true, contextFields: stockActionContext }],
    collectionActions: [
      {
        key: 'import',
        label: 'Import stock',
        endpoint: '/admin/central/stock/imports',
        reason: true,
        formFields: [
          gameSelectField(true),
          {
            key: 'items',
            label: 'Full numbers',
            type: 'lines',
            required: true,
            itemKey: 'full_number',
            placeholder: '000010\n000011\n000012',
            help: 'One stock full_number per line. Duplicate numbers create separate ticket rows.',
          },
        ],
      },
      {
        key: 'generate',
        label: 'Generate stock',
        endpoint: '/admin/central/stock/generate',
        reason: true,
        formFields: [
          gameSelectField(true, 'Current game', {
            defaultValueSource: 'current-game',
            currentOnly: true,
            hideEmptyOption: true,
            emptyOptionLabel: 'No current game',
            help: 'Generate or top up virtual stock only for the current open draw.',
          }),
          {
            key: 'set_distribution',
            label: 'Set distribution',
            type: 'stock-set-distribution',
            defaultValueSource: 'stock-set-distribution-default',
            defaultValue: [
              { set_size: 2, percent: 10 },
              { set_size: 3, percent: 15 },
            ],
            help: 'Percent controls added virtual capacity; the remaining percent defaults to single-ticket capacity. Deterministic internals are managed by the system.',
          },
        ],
      },
      {
        key: 'export',
        label: 'Export stock',
        endpoint: '/admin/central/stock/exports',
        reason: true,
        formFields: [
          gameSelectField(false),
          { key: 'filters.status', label: 'Status', type: 'select', options: ['available', 'allocated', 'sold', 'recalled'] },
        ],
      },
    ],
    detailApiGap: 'Central stock item detail remains list/action-only; grouped stock rows use the full-number detail modal.',
  },
  {
    scope: 'central',
    slug: 'stock-settings',
    title: 'Stock Settings',
    group: 'Central Operations',
    mode: 'settings',
    listEndpoint: '/admin/central/stock/settings',
    updateEndpoint: '/admin/central/stock/settings',
    updateMethod: 'PATCH',
    columns: [],
    filters: [],
  },
  {
    scope: 'central',
    slug: 'stock-pattern-coverage',
    title: 'Stock Pattern Coverage',
    group: 'Central Operations',
    listEndpoint: '/admin/central/stock/patterns',
    idParam: 'pattern_id',
    idKey: 'id',
    apiSort: true,
    columns: [
      { key: 'number', label: 'Pattern' },
      { key: 'scope_type', label: 'Scope', type: 'status' },
      { key: 'generated_count', label: 'Generated', type: 'number' },
      { key: 'reserved_count', label: 'Reserved', type: 'number' },
      { key: 'sold_count', label: 'Sold', type: 'number' },
      { key: 'default_limit', label: 'Default', type: 'number' },
      { key: 'override_limit', label: 'Override', type: 'number' },
      { key: 'limit', label: 'Effective', type: 'number' },
      { key: 'remaining_limit', label: 'Remaining', type: 'number' },
      { key: 'sellable_remaining_count', label: 'Sellable', type: 'number' },
    ],
    filters: cursorFilters([
      gameSelectFilter(),
      { key: 'dimension', label: 'Dimension', type: 'select', options: ['back2', 'back3', 'front3'] },
      { key: 'scope_type', label: 'Scope', type: 'select', options: ['central', 'partner'] },
      { key: 'scope_id', label: 'Scope ID' },
      { key: 'q', label: 'Pattern search' },
    ]),
  },
  {
    scope: 'central',
    slug: 'games',
    title: 'Games',
    group: 'Central Games',
    listEndpoint: '/admin/central/games',
    detailEndpoint: '/admin/central/games/{game_id}',
    idParam: 'game_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Game' },
      { key: 'code', label: 'Code' },
      { key: 'name', label: 'Name' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'sale_start_at', label: 'Sale start', type: 'datetime' },
      { key: 'close_at', label: 'Sale close', type: 'datetime' },
      { key: 'draw_at', label: 'Draw at', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(['draft', 'open', 'closed', 'reward_recorded', 'reward_checking', 'reward_verified', 'reward_published', 'archived'])]),
    confirmContextFields: gameActionContext,
    actions: [
      {
        key: 'update',
        label: 'Update',
        method: 'PATCH',
        endpoint: '/admin/central/games/{game_id}',
        variant: 'primary',
        contextFields: gameActionContext,
        formFields: gameUpdateFields,
      },
      { key: 'lottery-images', label: 'Lottery images', route: adminUiRoute('central', 'lottery-images?game_id={id}'), variant: 'success', contextFields: gameActionContext },
      { key: 'stock-coverage', label: 'Stock coverage', route: adminUiRoute('central', 'games/{id}/stock-coverage'), variant: 'info', contextFields: gameActionContext },
      { key: 'close', label: 'Close', endpoint: '/admin/central/games/{game_id}/close', variant: 'warning', reason: true, contextFields: gameActionContext },
      { key: 'archive', label: 'Archive', endpoint: '/admin/central/games/{game_id}/archive', variant: 'danger', reason: true, contextFields: gameActionContext },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Create game',
      endpoint: '/admin/central/games',
      formFields: gameCreateFields,
    }],
  },
  {
    scope: 'central',
    slug: 'allocations',
    title: 'Allocations',
    group: 'Central Stock',
    listEndpoint: '/admin/central/allocations',
    detailEndpoint: '/admin/central/allocations/{allocation_id}',
    idParam: 'allocation_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Allocation' },
      { key: 'partner_name', label: 'Partner', fallbackKeys: ['partner_code', 'partner_id'] },
      { key: 'tenant_name', label: 'Tenant', fallbackKeys: ['tenant_code', 'tenant_id'] },
      { key: 'game_name', label: 'Game', fallbackKeys: ['game_code', 'game_id'] },
      { key: 'allocation_percent', label: 'Percent', type: 'number' },
      { key: 'active_partner_percent', label: 'Active %', type: 'number' },
      { key: 'allocated_count', label: 'Allocated', type: 'number' },
      { key: 'remaining_count', label: 'Remaining', type: 'number' },
      { key: 'recalled_count', label: 'Recalled', type: 'number' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'created_at', label: 'Created', type: 'datetime' },
    ],
    filters: cursorFilters([
      allocationPartnerFilter(),
      allocationTenantFilter(),
      allocationGameFilter(),
      statusFilter(['draft', 'pending', 'processing', 'allocated', 'partially_allocated', 'failed', 'recalled', 'cancelled']),
    ]),
    confirmContextFields: allocationActionContext,
    actions: [
      {
        key: 'stock-coverage',
        label: 'Stock coverage',
        route: adminUiRoute('central', 'stock-pattern-coverage?game_id={game_id}&scope_type=partner&scope_id={partner_id}'),
        variant: 'info',
        contextFields: allocationActionContext,
      },
      {
        key: 'edit-percent',
        label: 'Edit percent',
        method: 'PUT',
        endpoint: '/admin/central/allocations/partner-percent',
        variant: 'info',
        contextFields: allocationActionContext,
        formFields: [
          allocationPartnerField({ sourceKey: 'partner_id', readonly: true }),
          allocationTenantField({ sourceKey: 'tenant_id', readonly: true }),
          allocationGameField({ sourceKey: 'game_id', readonly: true }),
          allocationPercentField(),
        ],
      },
      {
        key: 'remaining-stock',
        label: 'Remaining stock',
        route: adminUiRoute('central', 'stock-generation?game_id={game_id}&partner_id={partner_id}&tenant_id={tenant_id}&allocation_id={id}&status=allocated'),
        variant: 'success',
        contextFields: allocationActionContext,
      },
      {
        key: 'recall-all',
        label: 'Recall all',
        endpoint: '/admin/central/allocations/{allocation_id}/recall-all',
        variant: 'danger',
        reason: true,
        contextFields: allocationActionContext,
      },
      {
        key: 'redistribute',
        label: 'Redistribute',
        endpoint: '/admin/central/allocations/{allocation_id}/redistribute',
        variant: 'primary',
        reason: true,
        enabledStatuses: ['recalled'],
        disabledReason: 'Redistribute is available after recall-all reaches recalled status.',
        contextFields: allocationActionContext,
      },
      { key: 'cancel', label: 'Cancel', endpoint: '/admin/central/allocations/{allocation_id}/cancel', variant: 'warning', reason: true, contextFields: allocationActionContext },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Create allocation',
      endpoint: '/admin/central/allocations',
      reason: true,
      formFields: [
        allocationPartnerField(),
        allocationTenantField(),
        allocationGameField(),
        allocationPercentField(),
      ],
    }],
  },
  {
    scope: 'central',
    slug: 'rewards',
    title: 'Rewards',
    group: 'Central Rewards',
    listEndpoint: '/admin/central/rewards',
    detailEndpoint: '/admin/central/rewards/{reward_result_id}',
    detailRenderer: 'reward',
    idParam: 'reward_result_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Reward' },
      { key: 'game_id', label: 'Game' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'version', label: 'Version' },
      { key: 'prizes.0.prize_number', label: 'First prize' },
      { key: 'checked_at', label: 'Checked', type: 'datetime' },
    ],
    filters: cursorFilters([{ key: 'game_id', label: 'Game ID' }, statusFilter(rewardStatusOptions)]),
    confirmContextFields: rewardActionContext,
    actions: [
      { key: 'update_numbers', label: 'Update winning numbers', method: 'PATCH', endpoint: '/admin/central/rewards/{reward_result_id}', variant: 'primary', contextFields: rewardActionContext, formFields: rewardNumberUpdateFields },
      { key: 'update_payouts', label: 'Update payout amounts', method: 'PATCH', endpoint: '/admin/central/rewards/{reward_result_id}', variant: 'warning', contextFields: rewardActionContext, formFields: rewardPayoutUpdateFields },
      { key: 'verify', label: 'Verify', endpoint: '/admin/central/rewards/{reward_result_id}/verify', variant: 'success', reason: true, contextFields: rewardActionContext },
      { key: 'correct', label: 'Correct', endpoint: '/admin/central/rewards/{reward_result_id}/correct', variant: 'warning', reason: true, contextFields: rewardActionContext },
      { key: 'publish', label: 'Publish', endpoint: '/admin/central/rewards/{reward_result_id}/publish', variant: 'primary', reason: true, contextFields: rewardActionContext },
    ],
    collectionActions: [{
      key: 'create',
      label: 'Record reward result',
      endpoint: '/admin/central/rewards',
      formFields: rewardCreateFields,
    }],
  },
  {
    scope: 'central',
    slug: 'settlements',
    title: 'Settlements',
    group: 'Central Finance',
    listEndpoint: '/admin/central/settlements',
    detailEndpoint: '/admin/central/settlements/{settlement_id}',
    idParam: 'settlement_id',
    idKey: 'id',
    columns: [
      { key: 'id', label: 'Settlement' },
      { key: 'partner_id', label: 'Partner' },
      { key: 'tenant_id', label: 'Tenant' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'net_amount.amount', label: 'Net amount', type: 'money' },
      { key: 'period_from', label: 'From' },
      { key: 'period_to', label: 'To' },
    ],
    filters: cursorFilters([{ key: 'partner_id', label: 'Partner ID' }, { key: 'tenant_id', label: 'Tenant ID' }, statusFilter(['draft', 'pending', 'approved', 'paid', 'failed'])]),
    confirmContextFields: settlementActionContext,
    actions: [
      { key: 'approve', label: 'Approve', endpoint: '/admin/central/settlements/{settlement_id}/approve', variant: 'success', reason: true, contextFields: settlementActionContext },
    ],
  },
  resource('central', 'webhook-logs', 'Webhook Logs', 'Central Administration', '/admin/central/webhook-logs', '/admin/central/webhook-logs/{webhook_log_id}', 'webhook_log_id', [
    { key: 'id', label: 'Webhook log' },
    { key: 'provider', label: 'Provider' },
    { key: 'domain', label: 'Domain' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'callback_key', label: 'Callback' },
    { key: 'payload_hash', label: 'Payload hash' },
    { key: 'created_at', label: 'Created', type: 'datetime' },
    { key: 'updated_at', label: 'Updated', type: 'datetime' },
  ], cursorFilters([{ key: 'provider', label: 'Provider' }, statusFilter(['received', 'processed', 'failed', 'ignored'])])),
  {
    scope: 'central',
    slug: 'audit-logs',
    title: 'Audit Logs',
    group: 'Central Operations',
    listEndpoint: '/admin/central/audit-logs',
    columns: auditColumns,
    filters: cursorFilters([{ key: 'actor_id', label: 'Actor ID' }, { key: 'action', label: 'Action' }]),
  },
  {
    scope: 'central',
    slug: 'sync-logs',
    title: 'Sync Logs',
    group: 'Central Operations',
    listEndpoint: '/admin/central/sync-logs',
    columns: syncColumns,
    filters: cursorFilters([statusFilter(['pending', 'running', 'completed', 'failed'])]),
  },
  adminUserResource('central', cursorFilters([
    { key: 'q', label: 'Search' },
  ])),
  roleManagementResource('central'),
  settingsResource('central', 'menu-management', 'Menu Management', '/admin/central/menu-management', 'PUT'),
  {
    ...settingsResource('central', 'system-settings', 'System Settings', '/admin/central/system-settings'),
    settingsFields: systemSettingsFields,
  },
  reportIndex('central', ['overview', 'sales', 'stock', 'wallet', 'commission', 'rewards', 'settlement', 'partner_usage', 'audit']),
]

const resources = [...tenant, ...central]

const resourceAliases: Record<string, { target: string, title: string }> = {
  'central:master-stock': { target: 'stock', title: 'Stock Manager' },
  'central:stock-generation': { target: 'stock', title: 'Stock Manager' },
  'central:stock-coverage': { target: 'stock-pattern-coverage', title: 'Stock Pattern Coverage' },
}

export const useAdminOperationsCatalog = () => {
  const list = resources

  const resolve = (scope: AdminScope, slugParts: string[] = []) => {
    const slug = slugParts.filter(Boolean).join('/')
    const direct = list.find((item) => item.scope === scope && item.slug === slug)
    if (direct) {
      return { resource: direct, mode: direct.mode || 'list' as OperationMode, id: null as string | null }
    }

    const alias = resourceAliases[`${scope}:${slug}`]
    if (alias) {
      const target = list.find((item) => item.scope === scope && item.slug === alias.target)
      if (target) {
        return {
          resource: { ...target, slug, title: alias.title },
          mode: target.mode || 'list' as OperationMode,
          id: null as string | null,
        }
      }
    }

    if (slugParts[0] === 'reports' && slugParts[1]) {
      const index = list.find((item) => item.scope === scope && item.slug === 'reports')
      const reportKey = slugParts[1]
      return {
        resource: {
          ...index,
          slug,
          title: `${titleizeReport(reportKey)} Report`,
          mode: 'report-detail' as OperationMode,
          listEndpoint: `/admin/${scope}/reports/${reportKey}`,
          filters: index?.filters || [],
          collectionActions: [{
            key: 'export',
            label: 'Export report',
            endpoint: `/admin/${scope}/reports/${reportKey}/exports`,
            reason: true,
            contextFields: reportExportContext,
            formFields: reportExportFields(scope),
          }],
        } as OperationResource,
        mode: 'report-detail' as OperationMode,
        id: reportKey,
      }
    }

    if (slugParts.length > 1) {
      const parentSlug = slugParts.slice(0, -1).join('/')
      const parent = list.find((item) => item.scope === scope && item.slug === parentSlug)
      if (parent) {
        return { resource: parent, mode: 'detail' as OperationMode, id: slugParts.at(-1) || null }
      }
    }

    return { resource: null, mode: 'list' as OperationMode, id: null as string | null }
  }

  return { resources: list, resolve }
}

function resource(
  scope: AdminScope,
  slug: string,
  title: string,
  group: string,
  listEndpoint: string,
  detailEndpoint: string,
  idParam: string,
  columns: OperationColumn[],
  filters: OperationFilter[],
  actions: OperationAction[] = [],
): OperationResource {
  return {
    scope,
    slug,
    title,
    group,
    listEndpoint,
    detailEndpoint,
    updateEndpoint: detailEndpoint,
    idParam,
    idKey: 'id',
    columns,
    filters,
    actions,
  }
}

function listResource(
  scope: AdminScope,
  slug: string,
  title: string,
  group: string,
  listEndpoint: string,
  idParam: string,
  columns: OperationColumn[],
  filters: OperationFilter[],
): OperationResource {
  return {
    scope,
    slug,
    title,
    group,
    listEndpoint,
    idParam,
    idKey: 'id',
    columns,
    filters,
  }
}

function editableResource(
  scope: AdminScope,
  slug: string,
  title: string,
  group: string,
  listEndpoint: string,
  detailEndpoint: string,
  idParam: string,
  columns: OperationColumn[],
  filters: OperationFilter[],
  actions: OperationAction[] = [],
  collectionActions: OperationAction[] = [],
): OperationResource {
  return {
    ...resource(scope, slug, title, group, listEndpoint, detailEndpoint, idParam, columns, filters, actions),
    collectionActions,
    detailJsonEditor: true,
  }
}

function apiGapResource(scope: AdminScope, slug: string, title: string, group: string, apiGap: string): OperationResource {
  return {
    scope,
    slug,
    title,
    group,
    columns: genericColumns,
    filters: [],
    apiGap,
  }
}

function summaryResource(scope: AdminScope, slug: string, title: string, group: string, endpoint: string, filters: OperationFilter[] = []): OperationResource {
  return {
    scope,
    slug,
    title,
    group,
    mode: 'summary',
    listEndpoint: endpoint,
    columns: [],
    filters,
  }
}

function actionResource(
  scope: AdminScope,
  slug: string,
  title: string,
  group: string,
  listEndpoint: string,
  detailEndpoint: string,
  idParam: string,
  actions: OperationAction[],
): OperationResource {
  return resource(scope, slug, title, group, listEndpoint, detailEndpoint, idParam, [
    { key: 'id', label: 'Record' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'amount', label: 'Amount', type: 'money' },
    { key: 'created_at', label: 'Created', type: 'datetime' },
  ], cursorFilters([statusFilter()]), actions)
}

function adminUserResource(scope: AdminScope, filters: OperationFilter[]): OperationResource {
  const baseEndpoint = `/admin/${scope}/admin-users`
  const detailEndpoint = `${baseEndpoint}/{admin_user_id}`

  return {
    scope,
    slug: 'admin-users',
    title: 'Admin Users',
    group: scope === 'tenant' ? 'Tenant Administration' : 'Central Administration',
    listEndpoint: baseEndpoint,
    detailEndpoint,
    idParam: 'admin_user_id',
    idKey: 'id',
    columns: adminUserColumns,
    filters,
    confirmContextFields: adminUserActionContext,
    collectionActions: [{
      key: 'create',
      label: 'Create admin user',
      endpoint: baseEndpoint,
      reason: true,
      formFields: adminUserCreateFields(scope),
    }],
    actions: [
      {
        key: 'update',
        label: 'Update',
        method: 'PATCH',
        endpoint: detailEndpoint,
        variant: 'primary',
        reason: true,
        contextFields: adminUserActionContext,
        formFields: adminUserUpdateFields,
      },
      {
        key: 'delete',
        label: 'Disable',
        method: 'DELETE',
        endpoint: detailEndpoint,
        variant: 'danger',
        reason: true,
        contextFields: adminUserActionContext,
      },
    ],
  }
}

function roleManagementResource(scope: AdminScope): OperationResource {
  const baseEndpoint = `/admin/${scope}/roles`
  const detailEndpoint = `${baseEndpoint}/{role_id}`

  return {
    scope,
    slug: 'roles',
    title: 'Roles And Permissions',
    group: scope === 'tenant' ? 'Tenant Administration' : 'Central Administration',
    listEndpoint: baseEndpoint,
    idParam: 'role_id',
    idKey: 'id',
    columns: roleColumns,
    filters: cursorFilters(),
    confirmContextFields: roleActionContext,
    collectionActions: [{
      key: 'create',
      label: 'Create role',
      endpoint: baseEndpoint,
      reason: true,
      formFields: roleCreateFields,
    }],
    actions: [
      {
        key: 'update',
        label: 'Update',
        method: 'PATCH',
        endpoint: detailEndpoint,
        variant: 'primary',
        reason: true,
        contextFields: roleActionContext,
        formFields: roleUpdateFields,
      },
      {
        key: 'delete',
        label: 'Archive',
        method: 'DELETE',
        endpoint: detailEndpoint,
        variant: 'danger',
        reason: true,
        contextFields: roleActionContext,
      },
    ],
  }
}

function growthColumns(): OperationColumn[] {
  return [
    { key: 'id', label: 'Record' },
    { key: 'name', label: 'Name' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'created_at', label: 'Created', type: 'datetime' },
  ]
}

function settingsResource(scope: AdminScope, slug: string, title: string, endpoint: string, updateMethod: 'PATCH' | 'PUT' | 'POST' = 'PATCH'): OperationResource {
  return {
    scope,
    slug,
    title,
    group: scope === 'tenant' ? 'Tenant Settings' : 'Central Settings',
    mode: 'settings',
    listEndpoint: endpoint,
    updateEndpoint: endpoint,
    updateMethod,
    columns: [],
    filters: [],
  }
}

function reportIndex(scope: AdminScope, reportKeys: string[]): OperationResource {
  return {
    scope,
    slug: 'reports',
    title: `${scope === 'tenant' ? 'Tenant' : 'Central'} Reports`,
    group: `${scope === 'tenant' ? 'Tenant' : 'Central'} Reports`,
    mode: 'report-index',
    reportKeys,
    filters: scope === 'central' ? centralReportFilters : tenantReportFilters,
  }
}

function reportExportFields(scope: AdminScope): OperationFormField[] {
  return [
    { key: 'format', label: 'Format', type: 'select', options: ['csv', 'xlsx', 'pdf'], defaultValue: 'csv', required: true },
    ...(scope === 'central'
      ? [{ key: 'tenant_id', label: 'Tenant ID', sourceKey: 'tenant_id', placeholder: 'Optional tenant drill-down' } as OperationFormField]
      : []),
    { key: 'date_from', label: 'From', type: 'date', sourceKey: 'date_from' },
    { key: 'date_to', label: 'To', type: 'date', sourceKey: 'date_to' },
    { key: 'filters.group_by', label: 'Group by', type: 'select', sourceKey: 'group_by', options: scope === 'central' ? ['day', 'week', 'month', 'tenant', 'game', 'status'] : ['day', 'week', 'month', 'game', 'status'] },
  ]
}

function titleizeReport(value: string) {
  return value
    .replace(/[_-]/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())
}

export type AdminScope = 'tenant' | 'central'
export type OperationMode = 'list' | 'detail' | 'report-index' | 'report-detail' | 'settings' | 'summary'

export type OperationColumn = {
  key: string
  label: string
  type?: 'text' | 'status' | 'datetime' | 'money' | 'json'
}

export type OperationFilter = {
  key: string
  label: string
  type?: 'text' | 'number' | 'date' | 'select'
  options?: string[]
}

export type OperationAction = {
  key: string
  label: string
  method?: 'POST' | 'PATCH' | 'DELETE'
  endpoint: string
  variant?: 'primary' | 'success' | 'warning' | 'danger'
  reason?: boolean
  payloadTemplate?: Record<string, any>
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
  reportKeys?: string[]
  detailJsonEditor?: boolean
  apiGap?: string
  detailApiGap?: string
}

const statusFilter = (options: string[] = ['pending', 'approved', 'rejected', 'cancelled', 'active', 'inactive', 'completed', 'failed']): OperationFilter => ({
  key: 'status',
  label: 'Status',
  type: 'select',
  options,
})

const cursorFilters = (extra: OperationFilter[] = []): OperationFilter[] => [
  ...extra,
  { key: 'cursor', label: 'Cursor' },
  { key: 'limit', label: 'Limit', type: 'number' },
]

const auditColumns: OperationColumn[] = [
  { key: 'id', label: 'Log' },
  { key: 'actor_id', label: 'Actor' },
  { key: 'action', label: 'Action' },
  { key: 'created_at', label: 'Created', type: 'datetime' },
]

const syncColumns: OperationColumn[] = [
  { key: 'id', label: 'Log' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'source', label: 'Source' },
  { key: 'created_at', label: 'Created', type: 'datetime' },
]

const adminUserColumns: OperationColumn[] = [
  { key: 'id', label: 'Admin user' },
  { key: 'name', label: 'Name' },
  { key: 'email', label: 'Email' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]

const roleColumns: OperationColumn[] = [
  { key: 'id', label: 'Role' },
  { key: 'name', label: 'Name' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]

const genericColumns: OperationColumn[] = [
  { key: 'id', label: 'Record' },
  { key: 'name', label: 'Name' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]

const reportFilters: OperationFilter[] = [
  { key: 'date_from', label: 'From', type: 'date' },
  { key: 'date_to', label: 'To', type: 'date' },
  { key: 'group_by', label: 'Group by' },
  { key: 'cursor', label: 'Cursor' },
  { key: 'limit', label: 'Limit', type: 'number' },
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
    columns: [
      { key: 'id', label: 'Stock item' },
      { key: 'game_id', label: 'Game' },
      { key: 'number', label: 'Number' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'updated_at', label: 'Updated', type: 'datetime' },
    ],
    filters: cursorFilters([
      { key: 'game_id', label: 'Game ID' },
      statusFilter(['available', 'reserved', 'sold', 'recalled', 'inactive']),
      { key: 'number', label: 'Number' },
    ]),
    collectionActions: [{ key: 'export', label: 'Export stock', endpoint: '/admin/tenant/stock/exports', reason: true }],
  },
  {
    scope: 'tenant',
    slug: 'stock-sync',
    title: 'Tenant Stock Sync',
    group: 'Tenant Operations',
    listEndpoint: '/admin/tenant/stock-sync/batches',
    detailEndpoint: '/admin/tenant/stock-sync/batches/{batch_id}',
    idParam: 'batch_id',
    columns: [
      { key: 'id', label: 'Batch' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'source', label: 'Source' },
      { key: 'created_at', label: 'Created', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(['pending', 'running', 'completed', 'failed'])]),
    collectionActions: [{ key: 'create_batch', label: 'Create sync batch', endpoint: '/admin/tenant/stock-sync/batches', reason: true }],
  },
  editableResource('tenant', 'price-rules', 'Price Rules', 'Tenant Store Operations', '/admin/tenant/price-rules', '/admin/tenant/price-rules/{price_rule_id}', 'price_rule_id', [
    { key: 'id', label: 'Price rule' },
    { key: 'game_id', label: 'Game' },
    { key: 'code', label: 'Code' },
    { key: 'rule_type', label: 'Type' },
    { key: 'price.amount', label: 'Price', type: 'money' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'updated_at', label: 'Updated', type: 'datetime' },
  ], cursorFilters([{ key: 'game_id', label: 'Game ID' }, statusFilter(['active', 'archived'])]), [], [
    {
      key: 'create',
      label: 'Create price rule',
      endpoint: '/admin/tenant/price-rules',
      payloadTemplate: {
        code: '',
        name: '',
        game_id: null,
        rule_type: 'fixed_price',
        price_amount: 0,
        currency: 'THB',
        conditions: {},
        status: 'active',
      },
    },
  ]),
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
    actions: [{ key: 'cancel', label: 'Cancel', endpoint: '/admin/tenant/reservations/{reservation_id}/cancel', variant: 'warning', reason: true }],
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
      { key: 'customer_id', label: 'Customer' },
      { key: 'status', label: 'Status', type: 'status' },
      { key: 'total_amount', label: 'Total', type: 'money' },
      { key: 'created_at', label: 'Created', type: 'datetime' },
    ],
    filters: cursorFilters([statusFilter(['pending', 'paid', 'cancelled', 'refunded', 'completed']), { key: 'customer_id', label: 'Customer ID' }]),
    actions: [
      { key: 'cancel', label: 'Cancel', endpoint: '/admin/tenant/orders/{order_id}/cancel', variant: 'warning', reason: true },
      { key: 'refund', label: 'Refund', endpoint: '/admin/tenant/orders/{order_id}/refund', variant: 'danger', reason: true },
    ],
  },
  editableResource('tenant', 'customers', 'Customers', 'Tenant Store Operations', '/admin/tenant/members', '/admin/tenant/members/{member_id}', 'member_id', [
    { key: 'id', label: 'Member' },
    { key: 'member_no', label: 'Member no' },
    { key: 'name', label: 'Name' },
    { key: 'phone', label: 'Phone' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'order_count', label: 'Orders' },
    { key: 'lifetime_spend.amount', label: 'Lifetime spend', type: 'money' },
    { key: 'updated_at', label: 'Updated', type: 'datetime' },
  ], cursorFilters([
    { key: 'q', label: 'Search' },
    statusFilter(['active', 'pending_verification', 'suspended', 'disabled']),
    { key: 'registered_from', label: 'Registered from', type: 'date' },
    { key: 'registered_to', label: 'Registered to', type: 'date' },
  ]), [
    {
      key: 'status',
      label: 'Change status',
      endpoint: '/admin/tenant/members/{member_id}/status',
      variant: 'warning',
      reason: true,
      payloadTemplate: { status: 'suspended' },
    },
  ], [
    {
      key: 'create',
      label: 'Create member',
      endpoint: '/admin/tenant/members',
      payloadTemplate: {
        name: '',
        phone: '',
        email: null,
        status: 'active',
        password: '',
      },
    },
  ]),
  resource('tenant', 'tickets', 'Tickets', 'Tenant Support', '/admin/tenant/tickets', '/admin/tenant/tickets/{ticket_id}', 'ticket_id', [
    { key: 'id', label: 'Ticket' },
    { key: 'customer_id', label: 'Customer' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'created_at', label: 'Created', type: 'datetime' },
  ], cursorFilters([statusFilter(['open', 'pending', 'resolved', 'closed'])])),
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
    actions: [{ key: 'adjust', label: 'Adjust', method: 'PATCH', endpoint: '/admin/tenant/wallets/{wallet_id}/adjust', variant: 'warning', reason: true }],
  },
  actionResource('tenant', 'topups', 'Topups', 'Tenant Finance', '/admin/tenant/topups', '/admin/tenant/topups/{topup_id}', 'topup_id', [
    { key: 'approve', label: 'Approve', endpoint: '/admin/tenant/topups/{topup_id}/approve', variant: 'success', reason: true },
    { key: 'reject', label: 'Reject', endpoint: '/admin/tenant/topups/{topup_id}/reject', variant: 'danger', reason: true },
    { key: 'cancel', label: 'Cancel', endpoint: '/admin/tenant/topups/{topup_id}/cancel', variant: 'warning', reason: true },
  ]),
  actionResource('tenant', 'reward-claims', 'Reward Claims', 'Tenant Rewards', '/admin/tenant/reward-claims', '/admin/tenant/reward-claims/{claim_id}', 'claim_id', [
    { key: 'approve', label: 'Approve', endpoint: '/admin/tenant/reward-claims/{claim_id}/approve', variant: 'success', reason: true },
    { key: 'reject', label: 'Reject', endpoint: '/admin/tenant/reward-claims/{claim_id}/reject', variant: 'danger', reason: true },
    { key: 'pay', label: 'Pay', endpoint: '/admin/tenant/reward-claims/{claim_id}/pay', variant: 'primary', reason: true },
  ]),
  resource('tenant', 'growth/agents', 'Agents', 'Tenant Growth', '/admin/tenant/agents', '/admin/tenant/agents/{agent_id}', 'agent_id', growthColumns(), cursorFilters([statusFilter(['active', 'inactive', 'suspended'])]), [
    { key: 'quotas', label: 'Update quotas', method: 'PATCH', endpoint: '/admin/tenant/agents/{agent_id}/quotas', variant: 'warning', reason: true },
  ]),
  resource('tenant', 'growth/agent-quotas', 'Agent Quotas', 'Tenant Growth', '/admin/tenant/agents', '/admin/tenant/agents/{agent_id}', 'agent_id', growthColumns(), cursorFilters([statusFilter(['active', 'inactive', 'suspended'])]), [
    { key: 'quotas', label: 'Update quotas', method: 'PATCH', endpoint: '/admin/tenant/agents/{agent_id}/quotas', variant: 'warning', reason: true },
  ]),
  resource('tenant', 'growth/affiliate-programs', 'Affiliate Programs', 'Tenant Growth', '/admin/tenant/affiliate-programs', '/admin/tenant/affiliate-programs/{affiliate_program_id}', 'affiliate_program_id', growthColumns(), cursorFilters([statusFilter()]), [
    { key: 'delete', label: 'Delete', method: 'DELETE', endpoint: '/admin/tenant/affiliate-programs/{affiliate_program_id}', variant: 'danger', reason: true },
  ]),
  resource('tenant', 'growth/affiliate-links', 'Affiliate Links', 'Tenant Growth', '/admin/tenant/affiliate-links', '/admin/tenant/affiliate-links/{affiliate_link_id}', 'affiliate_link_id', growthColumns(), cursorFilters([statusFilter()]), [
    { key: 'delete', label: 'Delete', method: 'DELETE', endpoint: '/admin/tenant/affiliate-links/{affiliate_link_id}', variant: 'danger', reason: true },
  ]),
  resource('tenant', 'growth/attributions', 'Affiliate Attributions', 'Tenant Growth', '/admin/tenant/affiliate-attributions', '/admin/tenant/affiliate-attributions/{attribution_id}', 'attribution_id', growthColumns(), cursorFilters([statusFilter()])),
  resource('tenant', 'growth/affiliates', 'Affiliates', 'Tenant Growth', '/admin/tenant/affiliates', '/admin/tenant/affiliates/{affiliate_id}', 'affiliate_id', growthColumns(), cursorFilters([statusFilter()])),
  resource('tenant', 'growth/commission-rules', 'Commission Rules', 'Tenant Growth', '/admin/tenant/commission-rules', '/admin/tenant/commission-rules/{commission_rule_id}', 'commission_rule_id', growthColumns(), cursorFilters([statusFilter()]), [
    { key: 'delete', label: 'Delete', method: 'DELETE', endpoint: '/admin/tenant/commission-rules/{commission_rule_id}', variant: 'danger', reason: true },
  ]),
  {
    scope: 'tenant',
    slug: 'growth/commission-transactions',
    title: 'Commission Transactions',
    group: 'Tenant Growth',
    listEndpoint: '/admin/tenant/commission-transactions',
    idParam: 'commission_id',
    columns: growthColumns(),
    filters: cursorFilters([statusFilter(['pending', 'approved', 'rejected', 'paid'])]),
    actions: [{ key: 'approve', label: 'Approve', endpoint: '/admin/tenant/commission-transactions/{commission_id}/approve', variant: 'success', reason: true }],
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
    actions: [{ key: 'approve', label: 'Approve', endpoint: '/admin/tenant/payouts/{payout_id}/approve', variant: 'success', reason: true }],
  },
  summaryResource('tenant', 'monitoring', 'Monitoring', 'Tenant Operations Control', '/admin/tenant/monitoring'),
  summaryResource('tenant', 'usage', 'Usage', 'Tenant Operations Control', '/admin/tenant/usage', [
    { key: 'date_from', label: 'From', type: 'date' },
    { key: 'date_to', label: 'To', type: 'date' },
  ]),
  resource('tenant', 'admin-users', 'Admin Users', 'Tenant Administration', '/admin/tenant/admin-users', '/admin/tenant/admin-users/{admin_user_id}', 'admin_user_id', adminUserColumns, cursorFilters([
    { key: 'q', label: 'Search' },
    statusFilter(['active', 'invited', 'suspended', 'disabled']),
    { key: 'role_id', label: 'Role ID' },
  ])),
  listResource('tenant', 'roles', 'Roles And Permissions', 'Tenant Administration', '/admin/tenant/roles', 'role_id', roleColumns, cursorFilters()),
  settingsResource('tenant', 'menu-management', 'Menu Management', '/admin/tenant/menu-management', 'PUT'),
  settingsResource('tenant', 'settings', 'Tenant Settings', '/admin/tenant/settings'),
  settingsResource('tenant', 'payment-settings', 'Payment Settings', '/admin/tenant/payment-settings'),
  settingsResource('tenant', 'seo', 'Tenant SEO', '/admin/tenant/seo'),
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
    filters: cursorFilters([statusFilter(['pending', 'running', 'completed', 'failed'])]),
  },
  reportIndex('tenant', ['overview', 'sales', 'stock', 'wallet', 'commission', 'orders', 'customers', 'audit']),
]

const central: OperationResource[] = [
  resource('central', 'partners', 'Partners', 'Central Operations', '/admin/central/partners', '/admin/central/partners/{partner_id}', 'partner_id', [
    { key: 'id', label: 'Partner' },
    { key: 'name', label: 'Name' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'created_at', label: 'Created', type: 'datetime' },
  ], cursorFilters([statusFilter(['active', 'suspended', 'provisioning'])]), [
    { key: 'provision', label: 'Provision', endpoint: '/admin/central/partners/{partner_id}/provision', variant: 'success', reason: true },
    { key: 'suspend', label: 'Suspend', endpoint: '/admin/central/partners/{partner_id}/suspend', variant: 'warning', reason: true },
  ]),
  resource('central', 'partner-provisioning', 'Partner Provisioning', 'Central Partner Operations', '/admin/central/partners', '/admin/central/partners/{partner_id}', 'partner_id', [
    { key: 'id', label: 'Partner' },
    { key: 'name', label: 'Name' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'created_at', label: 'Created', type: 'datetime' },
  ], cursorFilters([statusFilter(['active', 'suspended', 'provisioning'])]), [
    { key: 'provision', label: 'Provision', endpoint: '/admin/central/partners/{partner_id}/provision', variant: 'success', reason: true },
    { key: 'suspend', label: 'Suspend', endpoint: '/admin/central/partners/{partner_id}/suspend', variant: 'warning', reason: true },
  ]),
  listResource('central', 'partner-quotas', 'Partner Quotas', 'Central Partner Operations', '/admin/central/partner-quotas', 'quota_id', [
    { key: 'id', label: 'Quota' },
    { key: 'partner_id', label: 'Partner' },
    { key: 'game_id', label: 'Game' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'updated_at', label: 'Updated', type: 'datetime' },
  ], cursorFilters([{ key: 'partner_id', label: 'Partner ID' }, { key: 'game_id', label: 'Game ID' }])),
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
  editableResource('central', 'billing-plans', 'Billing Plans', 'Central Partner Operations', '/admin/central/billing-plans', '/admin/central/billing-plans/{billing_plan_id}', 'billing_plan_id', [
    { key: 'id', label: 'Billing plan' },
    { key: 'code', label: 'Code' },
    { key: 'name', label: 'Name' },
    { key: 'monthly_fee.amount', label: 'Monthly fee', type: 'money' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'updated_at', label: 'Updated', type: 'datetime' },
  ], cursorFilters([statusFilter(['active', 'archived'])]), [], [
    {
      key: 'create',
      label: 'Create billing plan',
      endpoint: '/admin/central/billing-plans',
      payloadTemplate: {
        code: '',
        name: '',
        monthly_fee_amount: 0,
        currency: 'THB',
        features: {},
        limits: {},
        status: 'active',
      },
    },
  ]),
  editableResource('central', 'alert-policies', 'Alert Policies', 'Central Partner Operations', '/admin/central/alert-policies', '/admin/central/alert-policies/{alert_policy_id}', 'alert_policy_id', [
    { key: 'id', label: 'Alert policy' },
    { key: 'partner_id', label: 'Partner' },
    { key: 'policy_key', label: 'Policy' },
    { key: 'severity', label: 'Severity', type: 'status' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'updated_at', label: 'Updated', type: 'datetime' },
  ], cursorFilters([{ key: 'partner_id', label: 'Partner ID' }]), [], [
    {
      key: 'create',
      label: 'Create alert policy',
      endpoint: '/admin/central/alert-policies',
      payloadTemplate: {
        partner_id: '',
        policy_key: '',
        severity: 'warning',
        status: 'active',
        config: {},
      },
    },
  ]),
  resource('central', 'alert-events', 'Alert Events', 'Central Partner Operations', '/admin/central/alert-events', '/admin/central/alert-events/{alert_event_id}', 'alert_event_id', [
    { key: 'id', label: 'Alert event' },
    { key: 'partner_id', label: 'Partner' },
    { key: 'policy_key', label: 'Policy' },
    { key: 'severity', label: 'Severity', type: 'status' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'triggered_at', label: 'Triggered', type: 'datetime' },
    { key: 'delivered_at', label: 'Delivered', type: 'datetime' },
  ], cursorFilters([{ key: 'partner_id', label: 'Partner ID' }, statusFilter(['open', 'acknowledged', 'resolved', 'suppressed'])]), [
    { key: 'acknowledge', label: 'Acknowledge', endpoint: '/admin/central/alert-events/{alert_event_id}/acknowledge', variant: 'warning', reason: true },
    { key: 'resolve', label: 'Resolve', endpoint: '/admin/central/alert-events/{alert_event_id}/resolve', variant: 'success', reason: true },
  ]),
  {
    scope: 'central',
    slug: 'stock',
    title: 'Central Stock',
    group: 'Central Operations',
    listEndpoint: '/admin/central/stock',
    idParam: 'stock_item_id',
    columns: [
      { key: 'id', label: 'Stock item' },
      { key: 'partner_id', label: 'Partner' },
      { key: 'number', label: 'Number' },
      { key: 'status', label: 'Status', type: 'status' },
    ],
    filters: cursorFilters([{ key: 'game_id', label: 'Game ID' }, statusFilter(['available', 'allocated', 'sold', 'recalled']), { key: 'number', label: 'Number' }]),
    actions: [{ key: 'recall', label: 'Recall', endpoint: '/admin/central/stock/{stock_item_id}/recall', variant: 'warning', reason: true }],
    collectionActions: [
      { key: 'import', label: 'Import stock', endpoint: '/admin/central/stock/imports', reason: true },
      { key: 'generate', label: 'Generate stock', endpoint: '/admin/central/stock/generate', reason: true },
      { key: 'export', label: 'Export stock', endpoint: '/admin/central/stock/exports', reason: true },
    ],
    detailApiGap: 'OpenAPI documents central stock list and recall action, but no central stock detail GET endpoint.',
  },
  resource('central', 'games', 'Games', 'Central Games', '/admin/central/games', '/admin/central/games/{game_id}', 'game_id', [
    { key: 'id', label: 'Game' },
    { key: 'name', label: 'Name' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'close_at', label: 'Close at', type: 'datetime' },
  ], cursorFilters([statusFilter(['draft', 'open', 'closed', 'archived'])]), [
    { key: 'close', label: 'Close', endpoint: '/admin/central/games/{game_id}/close', variant: 'warning', reason: true },
    { key: 'archive', label: 'Archive', endpoint: '/admin/central/games/{game_id}/archive', variant: 'danger', reason: true },
  ]),
  resource('central', 'allocations', 'Allocations', 'Central Stock', '/admin/central/allocations', '/admin/central/allocations/{allocation_id}', 'allocation_id', [
    { key: 'id', label: 'Allocation' },
    { key: 'partner_id', label: 'Partner' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'created_at', label: 'Created', type: 'datetime' },
  ], cursorFilters([statusFilter(['pending', 'allocated', 'cancelled', 'completed'])]), [
    { key: 'cancel', label: 'Cancel', endpoint: '/admin/central/allocations/{allocation_id}/cancel', variant: 'warning', reason: true },
  ]),
  resource('central', 'rewards', 'Rewards', 'Central Rewards', '/admin/central/rewards', '/admin/central/rewards/{reward_result_id}', 'reward_result_id', [
    { key: 'id', label: 'Reward' },
    { key: 'game_id', label: 'Game' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'created_at', label: 'Created', type: 'datetime' },
  ], cursorFilters([statusFilter(['draft', 'verified', 'corrected', 'published'])]), [
    { key: 'verify', label: 'Verify', endpoint: '/admin/central/rewards/{reward_result_id}/verify', variant: 'success', reason: true },
    { key: 'correct', label: 'Correct', endpoint: '/admin/central/rewards/{reward_result_id}/correct', variant: 'warning', reason: true },
    { key: 'publish', label: 'Publish', endpoint: '/admin/central/rewards/{reward_result_id}/publish', variant: 'primary', reason: true },
  ]),
  resource('central', 'settlements', 'Settlements', 'Central Finance', '/admin/central/settlements', '/admin/central/settlements/{settlement_id}', 'settlement_id', [
    { key: 'id', label: 'Settlement' },
    { key: 'partner_id', label: 'Partner' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'amount', label: 'Amount', type: 'money' },
  ], cursorFilters([statusFilter(['pending', 'approved', 'paid', 'failed'])]), [
    { key: 'approve', label: 'Approve', endpoint: '/admin/central/settlements/{settlement_id}/approve', variant: 'success', reason: true },
  ]),
  resource('central', 'webhook-logs', 'Webhook Logs', 'Central Administration', '/admin/central/webhook-logs', '/admin/central/webhook-logs/{webhook_log_id}', 'webhook_log_id', [
    { key: 'id', label: 'Webhook log' },
    { key: 'provider', label: 'Provider' },
    { key: 'status', label: 'Status', type: 'status' },
    { key: 'callback_key', label: 'Callback' },
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
  resource('central', 'admin-users', 'Admin Users', 'Central Administration', '/admin/central/admin-users', '/admin/central/admin-users/{admin_user_id}', 'admin_user_id', adminUserColumns, cursorFilters([
    { key: 'q', label: 'Search' },
  ])),
  listResource('central', 'roles', 'Roles And Permissions', 'Central Administration', '/admin/central/roles', 'role_id', roleColumns, cursorFilters()),
  settingsResource('central', 'menu-management', 'Menu Management', '/admin/central/menu-management', 'PUT'),
  settingsResource('central', 'system-settings', 'System Settings', '/admin/central/system-settings'),
  reportIndex('central', ['overview', 'sales', 'stock', 'wallet', 'commission', 'settlement', 'partner_usage', 'audit']),
]

const resources = [...tenant, ...central]

export const useAdminOperationsCatalog = () => {
  const list = resources

  const resolve = (scope: AdminScope, slugParts: string[] = []) => {
    const slug = slugParts.filter(Boolean).join('/')
    const direct = list.find((item) => item.scope === scope && item.slug === slug)
    if (direct) {
      return { resource: direct, mode: direct.mode || 'list' as OperationMode, id: null as string | null }
    }

    if (slugParts[0] === 'reports' && slugParts[1]) {
      const index = list.find((item) => item.scope === scope && item.slug === 'reports')
      return {
        resource: {
          ...index,
          slug,
          title: `${titleizeReport(slugParts[1])} Report`,
          mode: 'report-detail' as OperationMode,
          listEndpoint: `/admin/${scope}/reports/${slugParts[1]}`,
          collectionActions: [{ key: 'export', label: 'Export report', endpoint: `/admin/${scope}/reports/${slugParts[1]}/exports`, reason: true }],
        } as OperationResource,
        mode: 'report-detail' as OperationMode,
        id: slugParts[1],
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
  }
}

function titleizeReport(value: string) {
  return value
    .replace(/[_-]/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())
}

type AdminMenuItem = {
  key: string
  label: string
  route?: string
  category?: string
  icon?: string
  children?: AdminMenuItem[]
  sort_order?: number
  badge_count?: number
}

type LoadMenusOptions = {
  silent?: boolean
}

const routeHints: Record<string, string> = {
  dashboard: '/admin/central/dashboard',
  dashboard_sales: '/admin/central/dashboard/sales',
  dashboard_partner: '/admin/central/dashboard/partner',
  dashboard_wallet: '/admin/central/dashboard/wallet',
  dashboard_payout: '/admin/central/dashboard/payout',
  dashboard_monitor: '/admin/central/dashboard/monitor',
  maintenance: '/admin/tenant/maintenance',
  support_access: '/admin/tenant/support-access',
}

const scopedRouteOverrides: Record<string, string> = {
  'central:dashboard_sales': '/admin/central/dashboard/sales',
  'central:dashboard_partner': '/admin/central/dashboard/partner',
  'central:dashboard_wallet': '/admin/central/dashboard/wallet',
  'central:dashboard_payout': '/admin/central/dashboard/payout',
  'central:dashboard_monitor': '/admin/central/dashboard/monitor',
  'central:reward_entry': '/admin/central/reward-entry',
  'central:rewards': '/admin/central/rewards',
  'central:winners': '/admin/central/winners',
  'central:reward_payout_rules': '/admin/central/reward-payout-rules',
  'central:stock_generation': '/admin/central/stock-generation',
  'central:stock_settings': '/admin/central/stock-settings',
  'central:stock_pattern_coverage': '/admin/central/stock-pattern-coverage',
  'central:maintenance': '/admin/central/maintenance',
  'central:lottery_images': '/admin/central/lottery-images',
  'central:lottery_image_operations': '/admin/central/lottery-images',
  'central:lottery-images': '/admin/central/lottery-images',
  'central:reports': '/admin/central/reports',
  'central:settlement': '/admin/central/settlements',
  'central:partner_monitoring': '/admin/central/partner-monitoring',
  'central:partner_usage': '/admin/central/partner-usage',
  'central:billing_plans': '/admin/central/billing-plans',
  'central:alert_policies': '/admin/central/alert-policies',
  'central:alert_events': '/admin/central/alert-events',
  'central:webhook_logs': '/admin/central/webhook-logs',
  'central:audit_logs': '/admin/central/audit-logs',
  'central:admin_users': '/admin/central/admin-users',
  'central:roles_permissions': '/admin/central/roles',
  'central:menu_management': '/admin/central/menu-management',
  'central:telegram_notifications': '/admin/central/telegram-notifications',
  'central:storage_connections': '/admin/central/storage-connections',
  'central:translations': '/admin/central/translations',
  'central:system_settings': '/admin/central/system-settings',
  'tenant:price_rules': '/admin/tenant/price-rules',
  'tenant:customers': '/admin/tenant/customers',
  'tenant:announcements': '/admin/tenant/announcements',
  'tenant:customer_notifications': '/admin/tenant/customer-notifications',
  'tenant:customer_support': '/admin/tenant/support',
  'tenant:line_notifications': '/admin/tenant/line-notifications',
  'tenant:social_login': '/admin/tenant/social-login',
  'tenant:sms_otp': '/admin/tenant/sms-otp',
  'tenant:password_reset_requests': '/admin/tenant/password-reset-requests',
  'tenant:activities': '/admin/tenant/activities',
  'tenant:activity_claims': '/admin/tenant/activity-claims',
  'tenant:winners': '/admin/tenant/winners',
  'tenant:exchange_reward': '/admin/tenant/exchange-reward',
  'tenant:agent_quotas': '/admin/tenant/growth/agent-quotas',
  'tenant:affiliate': '/admin/tenant/growth/affiliates',
  'tenant:affiliate_store_name_requests': '/admin/tenant/growth/affiliate-store-name-requests',
  'tenant:affiliate_tiers': '/admin/tenant/growth/affiliate-tiers',
  'tenant:affiliate_tier_campaigns': '/admin/tenant/growth/affiliate-tier-campaigns',
  'tenant:monitoring': '/admin/tenant/monitoring',
  'tenant:usage': '/admin/tenant/usage',
  'tenant:reports': '/admin/tenant/reports',
  'tenant:sync_logs': '/admin/tenant/sync-logs',
  'tenant:audit_logs': '/admin/tenant/audit-logs',
  'tenant:admin_users': '/admin/tenant/admin-users',
  'tenant:roles_permissions': '/admin/tenant/roles',
  'tenant:menu_management': '/admin/tenant/menu-management',
}

export const useAdminNavigation = () => {
  const api = useAdminApi()
  const session = useAdminSession()
  const { t } = useAdminLocale()
  const menus = useState<AdminMenuItem[]>('admin-menus', () => [])
  const loading = useState('admin-menus-loading', () => false)
  const error = useState<any>('admin-menus-error', () => null)
  const navigationMenus = computed(() => {
    const translated = translateMenuTree(buildMenuTree(menus.value), session.currentScope.value, t)

    return session.usesCustomerSupportLanding()
      ? customerSupportOnlyMenus(translated)
      : translated
  })

  const loadMenus = async (options: LoadMenusOptions = {}) => {
    session.restore()

    if (!session.isAuthenticated.value) {
      menus.value = []
      return
    }

    if (!options.silent) {
      loading.value = true
      error.value = null
    }

    try {
      const scope = session.currentScope.value
      const response: any = await api.apiFetch(`/admin/${scope}/menu`, {
        scope,
        tenantId: session.currentTenantId.value,
      })
      const nextMenus = Array.isArray(response?.data) ? response.data : []
      menus.value = hideRetiredMenus(scope, nextMenus)
    } catch (err) {
      if (!options.silent) {
        error.value = err
        menus.value = []
      } else if ((err as any)?.status === 401) {
        menus.value = []
      }
    } finally {
      if (!options.silent) {
        loading.value = false
      }
    }
  }

  const mapRoute = (item: AdminMenuItem) => {
    const overrideRoute = scopedRouteOverrides[`${session.currentScope.value}:${item.key}`]
    if (overrideRoute) {
      return overrideRoute
    }

    if (item.route && item.route.startsWith('/admin')) {
      return item.route
    }

    if (item.route && item.route.startsWith('/')) {
      return `/admin${item.route}`
    }

    return routeHints[item.key] || (session.currentScope.value === 'tenant' ? '/admin/tenant/dashboard' : '/admin/central/dashboard')
  }

  const iconFor = (item: AdminMenuItem) => {
    if (safeIcon(item.icon)) return item.icon

    const key = item.key || ''
    if (key.includes('announcement')) return 'ri-megaphone-line'
    if (key.includes('customer_notification')) return 'ri-notification-3-line'
    if (key.includes('line_notification')) return 'ri-line-line'
    if (key.includes('social_login')) return 'ri-login-circle-line'
    if (key.includes('sms_otp')) return 'ri-message-2-line'
    if (key.includes('password_reset')) return 'ri-lock-password-line'
    if (key.includes('storage')) return 'ri-database-2-line'
    if (key.includes('maintenance')) return 'ri-tools-line'
    if (key.includes('support')) return 'ri-customer-service-2-line'
    if (key.includes('audit')) return 'ri-history-line'
    if (key.includes('role') || key.includes('permission')) return 'ri-shield-user-line'
    if (key.includes('stock')) return 'ri-archive-stack-line'
    if (key.includes('reward') || key.includes('winner') || key.includes('prize')) return 'ri-trophy-line'
    if (key.includes('lottery') || key.includes('image')) return 'ri-image-2-line'
    if (key.includes('partner')) return 'ri-building-4-line'
    return item.children?.length ? 'ri-folder-2-line' : 'ri-dashboard-line'
  }

  return {
    menus,
    navigationMenus,
    loading,
    error,
    loadMenus,
    mapRoute,
    iconFor,
  }
}

const safeIcon = (icon?: string) => {
  return typeof icon === 'string' && /^[a-z0-9_-]+(?:\s+[a-z0-9_-]+)*$/i.test(icon)
}

const buildMenuTree = (items: AdminMenuItem[]) => {
  if (!Array.isArray(items)) return []

  const normalizedItems = items.map((item) => ({
    ...item,
    children: Array.isArray(item.children) ? item.children : [],
  }))

  const groups: AdminMenuItem[] = []
  const groupByCategory = new Map<string, AdminMenuItem>()

  normalizedItems.forEach((item) => {
    const category = typeof item.category === 'string' ? item.category.trim() : ''

    if (!category || category.toLowerCase() === 'dashboard') {
      groups.push(item)
      return
    }

    const groupKey = `category:${category.toLowerCase().replace(/[^a-z0-9]+/gi, '-')}`
    let group = groupByCategory.get(groupKey)

    if (!group) {
      group = {
        key: groupKey,
        label: category,
        icon: categoryIcon(category),
        children: [],
        sort_order: item.sort_order,
      }
      groupByCategory.set(groupKey, group)
      groups.push(group)
    }

    group.children?.push(item)
  })

  return groups
}

const translateMenuTree = (items: AdminMenuItem[], scope: string, translate: (key: string) => string): AdminMenuItem[] => (
  items.map((item) => {
    const children = Array.isArray(item.children) ? translateMenuTree(item.children, scope, translate) : []
    const isCategory = item.key.startsWith('category:')

    return {
      ...item,
      label: isCategory
        ? translatedCategoryLabel(item.label, translate)
        : translatedMenuLabel(scope, item.key, item.label, translate),
      children,
    }
  })
)

const translatedMenuLabel = (scope: string, key: string, fallback: string, translate: (key: string) => string) => {
  const scopedKey = `menus.items.${scope}.${key}`
  const scopedLabel = translate(scopedKey)

  if (scopedLabel !== scopedKey) {
    return scopedLabel
  }

  return fallback
}

const translatedCategoryLabel = (category: string, translate: (key: string) => string) => {
  const categoryKey = categoryTranslationKey(category)
  const translationKey = `menus.categories.${categoryKey}`
  const translated = translate(translationKey)

  return translated !== translationKey ? translated : category
}

const categoryTranslationKey = (category: string) => {
  const parts = category
    .trim()
    .replace(/&/g, ' and ')
    .split(/[^a-z0-9]+/i)
    .filter(Boolean)
    .map((part) => part.toLowerCase())

  return parts.map((part, index) => (
    index === 0 ? part : `${part.charAt(0).toUpperCase()}${part.slice(1)}`
  )).join('')
}

const retiredCentralMenuKeys = new Set(['master_stock', 'partner_quotas', 'stock_recall', 'partner_provisioning'])
const retiredTenantMenuKeys = new Set(['stock_sync'])

const hideRetiredMenus = (scope: string, items: AdminMenuItem[]): AdminMenuItem[] => {
  const retiredKeys = scope === 'central' ? retiredCentralMenuKeys : retiredTenantMenuKeys

  return items
    .filter((item) => item.key !== 'prize_checking' && !retiredKeys.has(item.key))
    .map((item) => ({
      ...item,
      label: item.key === 'stock_generation' ? 'Stock Manager' : item.key === 'local_stock' ? 'Tenant Stock' : item.key === 'partners' ? 'Partner/Tenant' : item.label,
      children: Array.isArray(item.children) ? hideRetiredMenus(scope, item.children) : [],
    }))
}

const customerSupportOnlyMenus = (items: AdminMenuItem[]): AdminMenuItem[] => (
  items.flatMap((item) => {
    if (item.key === 'customer_support') {
      return [{ ...item, children: [] }]
    }

    const children = Array.isArray(item.children)
      ? customerSupportOnlyMenus(item.children)
      : []

    return children.length > 0 ? [{ ...item, children }] : []
  })
)

const categoryIcon = (category: string) => {
  const value = category.toLowerCase()

  if (value.includes('lottery')) return 'ri-trophy-line'
  if (value.includes('partner')) return 'ri-building-4-line'
  if (value.includes('finance') || value.includes('report')) return 'ri-bar-chart-box-line'
  if (value.includes('store')) return 'ri-store-2-line'
  if (value.includes('plugin')) return 'ri-plug-2-line'
  if (value.includes('growth')) return 'ri-line-chart-line'
  if (value.includes('control')) return 'ri-pulse-line'
  if (value.includes('review') || value.includes('queue')) return 'ri-inbox-archive-line'
  if (value.includes('administration')) return 'ri-shield-user-line'
  return 'ri-folder-2-line'
}

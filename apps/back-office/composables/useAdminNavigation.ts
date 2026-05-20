type AdminMenuItem = {
  key: string
  label: string
  route?: string
  category?: string
  icon?: string
  children?: AdminMenuItem[]
  sort_order?: number
}

const routeHints: Record<string, string> = {
  dashboard: '/admin/central/dashboard',
  maintenance: '/admin/tenant/maintenance',
  support_access: '/admin/tenant/support-access',
}

const scopedRouteOverrides: Record<string, string> = {
  'central:rewards': '/admin/central/rewards',
  'central:master_stock': '/admin/central/master-stock',
  'central:stock_generation': '/admin/central/stock-generation',
  'central:stock_settings': '/admin/central/stock-settings',
  'central:stock_recall': '/admin/central/stock-recall',
  'central:stock_pattern_coverage': '/admin/central/stock-pattern-coverage',
  'central:lottery_images': '/admin/central/lottery-images',
  'central:lottery_image_operations': '/admin/central/lottery-images',
  'central:lottery-images': '/admin/central/lottery-images',
  'central:reports': '/admin/central/reports',
  'central:settlement': '/admin/central/settlements',
  'central:partner_provisioning': '/admin/central/partner-provisioning',
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
  'central:system_settings': '/admin/central/system-settings',
  'tenant:price_rules': '/admin/tenant/price-rules',
  'tenant:customers': '/admin/tenant/customers',
  'tenant:agent_quotas': '/admin/tenant/growth/agent-quotas',
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
  const menus = useState<AdminMenuItem[]>('admin-menus', () => [])
  const loading = useState('admin-menus-loading', () => false)
  const error = useState<any>('admin-menus-error', () => null)
  const navigationMenus = computed(() => buildMenuTree(menus.value))

  const loadMenus = async () => {
    session.restore()

    if (!session.isAuthenticated.value) {
      menus.value = []
      return
    }

    loading.value = true
    error.value = null

    try {
      const scope = session.currentScope.value
      const response: any = await api.apiFetch(`/admin/${scope}/menu`, {
        scope,
        tenantId: session.currentTenantId.value,
      })
      const nextMenus = Array.isArray(response?.data) ? response.data : []
      menus.value = scope === 'central' ? hideCentralOnlyMenus(nextMenus) : nextMenus
    } catch (err) {
      error.value = err
      menus.value = []
    } finally {
      loading.value = false
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
    if (key.includes('maintenance')) return 'ri-tools-line'
    if (key.includes('support')) return 'ri-customer-service-2-line'
    if (key.includes('audit')) return 'ri-history-line'
    if (key.includes('role') || key.includes('permission')) return 'ri-shield-user-line'
    if (key.includes('stock')) return 'ri-archive-stack-line'
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

  if (normalizedItems.some((item) => item.children.length)) {
    return normalizedItems
  }

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

const retiredCentralMenuKeys = new Set(['partner_quotas'])

const hideCentralOnlyMenus = (items: AdminMenuItem[]): AdminMenuItem[] => items
  .filter((item) => item.key !== 'prize_checking' && !retiredCentralMenuKeys.has(item.key))
  .map((item) => ({
    ...item,
    children: Array.isArray(item.children) ? hideCentralOnlyMenus(item.children) : [],
  }))

const categoryIcon = (category: string) => {
  const value = category.toLowerCase()

  if (value.includes('lottery')) return 'ri-trophy-line'
  if (value.includes('partner')) return 'ri-building-4-line'
  if (value.includes('finance') || value.includes('report')) return 'ri-bar-chart-box-line'
  if (value.includes('store')) return 'ri-store-2-line'
  if (value.includes('growth')) return 'ri-line-chart-line'
  if (value.includes('control')) return 'ri-pulse-line'
  if (value.includes('administration')) return 'ri-shield-user-line'
  return 'ri-folder-2-line'
}

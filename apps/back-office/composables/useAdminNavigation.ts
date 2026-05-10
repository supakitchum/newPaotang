type AdminMenuItem = {
  key: string
  label: string
  route?: string
  category?: string
  icon?: string
  children?: AdminMenuItem[]
}

const routeHints: Record<string, string> = {
  dashboard: '/admin/central/dashboard',
  maintenance: '/admin/tenant/maintenance',
  support_access: '/admin/tenant/support-access',
}

const scopedRouteOverrides: Record<string, string> = {
  'central:rewards': '/admin/central/rewards',
  'central:prize_checking': '/admin/central/rewards',
  'central:reports': '/admin/central/reports',
  'central:settlement': '/admin/central/settlements',
  'central:partner_provisioning': '/admin/central/partner-provisioning',
  'central:partner_quotas': '/admin/central/partner-quotas',
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
      menus.value = Array.isArray(response?.data) ? response.data : []
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
    if (key.includes('partner')) return 'ri-building-4-line'
    return item.children?.length ? 'ri-folder-2-line' : 'ri-dashboard-line'
  }

  return {
    menus,
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

type AdminScope = {
  scope: 'central' | 'tenant'
  scope_id?: string | null
  tenant_id?: string | null
  tenant_name?: string | null
  permissions?: string[]
}

type AdminUser = {
  id: string
  name: string
  email: string
  phone?: string | null
  status?: string
  preferred_locale?: string | null
  two_factor_enabled?: boolean
  must_change_password?: boolean
  password_changed_at?: string | null
}

type AdminSessionState = {
  accessToken: string | null
  refreshToken: string | null
  user: AdminUser | null
  scopes: AdminScope[]
  activeScope: 'central' | 'tenant'
  activeTenantId: string | null
  restored: boolean
}

const storageKey = 'newpaotang.back-office.session.v1'
const sessionCookieName = 'newpaotang_bo_session'
const authNoticeStorageKey = 'newpaotang.back-office.auth-notice.v1'
const forcedPasswordChangePath = '/admin/change-password'

const emptySession = (): AdminSessionState => ({
  accessToken: null,
  refreshToken: null,
  user: null,
  scopes: [],
  activeScope: 'central',
  activeTenantId: null,
  restored: false,
})

export const useAdminSession = () => {
  const session = useState<AdminSessionState>('admin-session', emptySession)
  const toast = useState<{ type: string, message: string } | null>('admin-toast', () => null)
  const hostMode = useAdminHostMode()

  const isAuthenticated = computed(() => Boolean(session.value.accessToken))
  const mustChangePassword = computed(() => Boolean(session.value.user?.must_change_password))
  const currentScope = computed(() => session.value.activeScope)
  const currentTenantId = computed(() => session.value.activeTenantId)
  const currentPermissions = computed(() => {
    const active = session.value.scopes.find((scope) => (
      scope.scope === session.value.activeScope
      && (scope.scope !== 'tenant' || scope.tenant_id === session.value.activeTenantId)
    ))

    return active?.permissions || []
  })

  const canApplyLocaleNow = () => !import.meta.client || useAdminClientReady().ready.value

  const applyPreferredLocale = () => {
    if (session.value.user?.preferred_locale && canApplyLocaleNow()) {
      useAdminLocale().applyProfileLocale(session.value.user.preferred_locale)
    }
  }

  const persist = () => {
    if (!import.meta.client) {
      return
    }

    if (!session.value.accessToken) {
      sessionStorage.removeItem(storageKey)
      clearSessionCookie()
      return
    }

    sessionStorage.setItem(storageKey, JSON.stringify({
      accessToken: session.value.accessToken,
      refreshToken: session.value.refreshToken,
      user: session.value.user,
      scopes: session.value.scopes,
      activeScope: session.value.activeScope,
      activeTenantId: session.value.activeTenantId,
    }))
    writeSessionCookie()
  }

  const restore = () => {
    if (!import.meta.client || session.value.restored) {
      return
    }

    try {
      const raw = sessionStorage.getItem(storageKey)
      if (raw) {
        const parsed = JSON.parse(raw)
        if (!parsed?.accessToken) {
          sessionStorage.removeItem(storageKey)
          clearSessionCookie()
          session.value = { ...emptySession(), restored: true }
          return
        }
        session.value = {
          ...emptySession(),
          ...parsed,
          restored: true,
        }
        applyPreferredLocale()
      } else {
        clearSessionCookie()
        session.value = { ...emptySession(), restored: true }
      }
    } catch {
      sessionStorage.removeItem(storageKey)
      clearSessionCookie()
      session.value = { ...emptySession(), restored: true }
    }
  }

  const applyAuthPayload = (payload: any, requestedScope?: 'central' | 'tenant', requestedTenantId?: string | null) => {
    const scopes = Array.isArray(payload?.scopes) ? payload.scopes : []
    const resolvedRequestedScope = hostMode.isPartnerBoHost.value ? 'tenant' : requestedScope
    const activeScope = (payload?.active_scope || resolvedRequestedScope || firstUsableScope(scopes)?.scope || 'central') as 'central' | 'tenant'
    const activeTenantId = payload?.active_tenant_id || requestedTenantId || firstTenantId(scopes, activeScope)

    session.value = {
      accessToken: payload?.access_token || session.value.accessToken,
      refreshToken: payload?.refresh_token || session.value.refreshToken,
      user: payload?.user || session.value.user,
      scopes,
      activeScope,
      activeTenantId: activeScope === 'tenant' ? activeTenantId : null,
      restored: true,
    }
    applyPreferredLocale()
    persist()
  }

  const updateUser = (user: AdminUser) => {
    session.value.user = {
      ...(session.value.user || user),
      ...user,
    }
    applyPreferredLocale()
    persist()
  }

  const setScope = (scope: 'central' | 'tenant', tenantId?: string | null) => {
    session.value.activeScope = scope
    session.value.activeTenantId = scope === 'tenant' ? tenantId || firstTenantId(session.value.scopes, 'tenant') : null
    persist()
  }

  const alignScopeForPath = (path: string) => {
    if (path.startsWith('/admin/central')) {
      if (hostMode.isPartnerBoHost.value) {
        return false
      }

      if (!hasScope('central')) {
        return false
      }
      setScope('central')
      return true
    }

    if (path.startsWith('/admin/tenant')) {
      const tenantId = session.value.activeTenantId || firstTenantId(session.value.scopes, 'tenant')
      if (!tenantId || !hasScope('tenant', tenantId)) {
        return false
      }
      setScope('tenant', tenantId)
      return true
    }

    return true
  }

  const ensurePartnerTenantSession = () => {
    if (!hostMode.isPartnerBoHost.value) {
      return true
    }

    const tenantId = session.value.activeTenantId || firstTenantId(session.value.scopes, 'tenant')
    if (!tenantId || !hasScope('tenant', tenantId)) {
      return false
    }

    setScope('tenant', tenantId)
    return true
  }

  const hasPermission = (permission: string) => currentPermissions.value.includes(permission)
  const hasScope = (scope: 'central' | 'tenant', tenantId?: string | null) => session.value.scopes.some((item) => (
    item.scope === scope
    && (scope !== 'tenant' || !tenantId || item.tenant_id === tenantId)
  ))
  const usesTranslationCenterLanding = (scope: 'central' | 'tenant' = session.value.activeScope) => (
    scope === 'central'
    && currentPermissions.value.includes('translation.view')
    && !currentPermissions.value.includes('dashboard.view')
  )
  const usesRewardEntryLanding = (scope: 'central' | 'tenant' = session.value.activeScope) => (
    scope === 'central'
    && currentPermissions.value.includes('reward_entry.view')
    && !currentPermissions.value.includes('dashboard.view')
  )
  const usesLotteryImagesLanding = (scope: 'central' | 'tenant' = session.value.activeScope) => (
    scope === 'central'
    && currentPermissions.value.includes('asset.manage')
    && currentPermissions.value.includes('stock.view')
    && !currentPermissions.value.includes('dashboard.view')
  )
  const usesCustomerSupportLanding = (scope: 'central' | 'tenant' = session.value.activeScope) => {
    if (scope !== 'tenant' || !currentPermissions.value.includes('support_ticket.view_assigned')) {
      return false
    }

    const standardSupportPermissions = (
      currentPermissions.value.includes('support_ticket.reply_assigned')
      && !currentPermissions.value.includes('support_ticket.view_all')
      && !currentPermissions.value.includes('support_ticket.assign')
      && !currentPermissions.value.includes('support_agent.manage')
      && !currentPermissions.value.includes('support_faq.manage')
      && !currentPermissions.value.includes('support_report.view')
    )

    return standardSupportPermissions || !currentPermissions.value.includes('dashboard.view')
  }
  const landingPath = (scope: 'central' | 'tenant' = session.value.activeScope) => {
    if (mustChangePassword.value) {
      return forcedPasswordChangePath
    }

    if (scope === 'tenant') {
      return usesCustomerSupportLanding(scope)
        ? '/admin/tenant/support'
        : '/admin/tenant/dashboard'
    }

    if (usesTranslationCenterLanding(scope)) {
      return '/admin/central/translations'
    }

    if (usesRewardEntryLanding(scope)) {
      return '/admin/central/reward-entry'
    }

    if (usesLotteryImagesLanding(scope)) {
      return '/admin/central/lottery-images'
    }

    return '/admin/central/dashboard'
  }

  const clear = () => {
    session.value = { ...emptySession(), restored: true }
    if (import.meta.client) {
      sessionStorage.removeItem(storageKey)
      clearSessionCookie()
    }
  }

  const rememberAuthNotice = (message: string) => {
    if (!import.meta.client || !message.trim()) {
      return
    }

    sessionStorage.setItem(authNoticeStorageKey, message.trim())
  }

  const consumeAuthNotice = () => {
    if (!import.meta.client) {
      return ''
    }

    const message = sessionStorage.getItem(authNoticeStorageKey) || ''
    sessionStorage.removeItem(authNoticeStorageKey)

    return message
  }

  const showToast = (message: string, type = 'primary') => {
    toast.value = { message, type }
  }

  return {
    session,
    toast,
    isAuthenticated,
    mustChangePassword,
    currentScope,
    currentTenantId,
    currentPermissions,
    restore,
    persist,
    applyAuthPayload,
    updateUser,
    setScope,
    alignScopeForPath,
    ensurePartnerTenantSession,
    applyPreferredLocale,
    hasPermission,
    hasScope,
    usesTranslationCenterLanding,
    usesRewardEntryLanding,
    usesLotteryImagesLanding,
    usesCustomerSupportLanding,
    landingPath,
    clear,
    rememberAuthNotice,
    consumeAuthNotice,
    showToast,
    forcedPasswordChangePath,
  }
}

const firstUsableScope = (scopes: AdminScope[]) => scopes.find((scope) => scope.scope === 'central') || scopes[0]

const firstTenantId = (scopes: AdminScope[], scope: string) => {
  if (scope !== 'tenant') {
    return null
  }

  return scopes.find((item) => item.scope === 'tenant')?.tenant_id || null
}

const writeSessionCookie = () => {
  document.cookie = `${sessionCookieName}=1; Path=/; SameSite=Lax`
}

const clearSessionCookie = () => {
  document.cookie = `${sessionCookieName}=; Path=/; SameSite=Lax; Max-Age=0`
}

export const adminSessionCookieName = sessionCookieName

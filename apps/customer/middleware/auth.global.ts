import { handlesCustomerPinInline, isPublicCustomerRoute } from '~/utils/customerAuthRoutes'

const getSafeRedirect = (value: unknown) => {
  if (typeof value !== 'string') {
    return '/'
  }

  if (!value.startsWith('/') || value.startsWith('//')) {
    return '/'
  }

  return value
}

export default defineNuxtRouteMiddleware(async (to) => {
  const requiresAuth = !isPublicCustomerRoute(to.path)
  const requiresPinBeforeUse = requiresAuth || to.path === '/'
  const guestOnly = to.meta.guestOnly === true
  const isPinPage = to.path === '/pin'
  const handlesPinInline = handlesCustomerPinInline(to.path)
  const {
    isAuthenticated,
    refreshToken,
    user,
    restoreAuthState,
    refreshAuthToken,
    clearAuthToken,
    pinSetupRequired,
    pinRequired,
    accountSuspension,
  } = useAuth()
  const suspensionRedirect = () => navigateTo('/account-suspended', { replace: true })
  const loginRedirect = () => navigateTo({
    path: '/login',
    query: {
      redirect: isPinPage ? getSafeRedirect(to.query.redirect) : to.fullPath
    }
  })
  const refreshSession = async () => {
    if (!refreshToken.value) {
      clearAuthToken()
      return false
    }

    const session = await refreshAuthToken()

    if (accountSuspension.value) {
      return false
    }

    return Boolean(session?.token)
  }
  const restoreOrRefreshSession = async (forceProfile = false) => {
    if (!isAuthenticated.value) {
      return refreshSession()
    }

    try {
      await restoreAuthState(forceProfile)
      return true
    } catch {
      if (accountSuspension.value) {
        return false
      }

      return refreshSession()
    }
  }

  if (to.path !== '/account-suspended' && accountSuspension.value && !isAuthenticated.value) {
    return suspensionRedirect()
  }

  if (requiresAuth && !isAuthenticated.value) {
    const refreshed = await refreshSession()

    if (!refreshed) {
      if (accountSuspension.value) {
        return suspensionRedirect()
      }

      return loginRedirect()
    }
  }

  if (requiresPinBeforeUse && !requiresAuth && !isAuthenticated.value && refreshToken.value) {
    const refreshed = await refreshSession()

    if (!refreshed && accountSuspension.value) {
      return suspensionRedirect()
    }
  }

  const userPinStateKnown = typeof (user.value as Record<string, unknown> | null)?.has_pin === 'boolean'

  if (isAuthenticated.value && (!user.value || !userPinStateKnown)) {
    const restored = await restoreOrRefreshSession(!userPinStateKnown)

    if (!restored && requiresAuth) {
      if (accountSuspension.value) {
        return suspensionRedirect()
      }

      return loginRedirect()
    }
  }

  if ((requiresAuth && isPinPage) || (guestOnly && isAuthenticated.value)) {
    const restored = await restoreOrRefreshSession(true)

    if (!restored) {
      if (requiresAuth) {
        if (accountSuspension.value) {
          return suspensionRedirect()
        }

        return loginRedirect()
      }

      return
    }
  }

  if (requiresPinBeforeUse && !isPinPage && (pinSetupRequired.value || (pinRequired.value && !handlesPinInline))) {
    const restored = await restoreOrRefreshSession(true)

    if (!restored) {
      if (accountSuspension.value) {
        return suspensionRedirect()
      }

      return loginRedirect()
    }

    return navigateTo({
      path: '/pin',
      query: {
        redirect: to.fullPath
      }
    })
  }

  if (guestOnly && isAuthenticated.value) {
    const redirect = getSafeRedirect(to.query.redirect)
    const redirectHandlesPinInline = handlesCustomerPinInline(redirect)

    if (pinSetupRequired.value || (pinRequired.value && !redirectHandlesPinInline)) {
      return navigateTo({
        path: '/pin',
        query: {
          redirect
        }
      })
    }

    return navigateTo(redirect)
  }
})

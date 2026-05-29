import { isPublicCustomerRoute } from '~/utils/customerAuthRoutes'

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
  const guestOnly = to.meta.guestOnly === true
  const isPinPage = to.path === '/pin'
  const {
    isAuthenticated,
    refreshToken,
    user,
    restoreAuthState,
    refreshAuthToken,
    clearAuthToken,
    pinSetupRequired,
    pinRequired,
  } = useAuth()
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
      return refreshSession()
    }
  }

  if (requiresAuth && !isAuthenticated.value) {
    const refreshed = await refreshSession()

    if (!refreshed) {
      return loginRedirect()
    }
  }

  const userPinStateKnown = typeof (user.value as Record<string, unknown> | null)?.has_pin === 'boolean'

  if (isAuthenticated.value && (!user.value || !userPinStateKnown)) {
    const restored = await restoreOrRefreshSession(!userPinStateKnown)

    if (!restored && requiresAuth) {
      return loginRedirect()
    }
  }

  if ((requiresAuth && isPinPage) || (guestOnly && isAuthenticated.value)) {
    const restored = await restoreOrRefreshSession(true)

    if (!restored) {
      if (requiresAuth) {
        return loginRedirect()
      }

      return
    }
  }

  if (requiresAuth && !isPinPage && (pinSetupRequired.value || pinRequired.value)) {
    const restored = await restoreOrRefreshSession(true)

    if (!restored) {
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

    if (pinSetupRequired.value || pinRequired.value) {
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

export default defineNuxtRouteMiddleware(async (to) => {
  const { fetchSiteConfig, isRouteBlockedByMaintenance } = useSiteConfig()
  const { ensureAppInit, getInitRedirectTarget } = useAppInit()
  const { token, user, restoreAuthState } = useAuth()

  await fetchSiteConfig()
  useTenantSeo({
    path: to.path,
    privatePage: to.meta.requiresAuth === true
  })

  if (to.path !== '/maintenance' && isRouteBlockedByMaintenance(to.path)) {
    return navigateTo('/maintenance')
  }

  await ensureAppInit()

  if (to.meta.requiresAuth === true && token.value && !user.value) {
    try {
      await restoreAuthState()
    } catch {
      // The axios interceptor owns expired-session clearing and redirect UX.
    }
  }

  const redirectTarget = getInitRedirectTarget(to.path)

  if (redirectTarget && redirectTarget !== to.path) {
    return navigateTo(redirectTarget)
  }
})

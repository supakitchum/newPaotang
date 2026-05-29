import { requiresCustomerAuth } from '~/utils/customerAuthRoutes'

export default defineNuxtRouteMiddleware(async (to) => {
  const { fetchSiteConfig, isRouteBlockedByMaintenance } = useSiteConfig()
  const { ensureAppInit, getInitRedirectTarget, isReady } = useAppInit()
  const { token, user, restoreAuthState } = useAuth()
  const isPrivatePage = requiresCustomerAuth(to.path)

  await fetchSiteConfig()
  useTenantSeo({
    path: to.path,
    privatePage: isPrivatePage
  })

  if (to.path !== '/maintenance' && isRouteBlockedByMaintenance(to.path)) {
    return navigateTo('/maintenance')
  }

  if (to.path === '/pin') {
    isReady.value = true
    return
  }

  await ensureAppInit()

  if ((isPrivatePage || to.path === '/') && token.value && !user.value) {
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

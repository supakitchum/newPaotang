export default defineNuxtRouteMiddleware(async (to) => {
  const { ensureAppInit, getInitRedirectTarget } = useAppInit()

  await ensureAppInit()

  const redirectTarget = getInitRedirectTarget(to.path)

  if (redirectTarget && redirectTarget !== to.path) {
    return navigateTo(redirectTarget)
  }
})

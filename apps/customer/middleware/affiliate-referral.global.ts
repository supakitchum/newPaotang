export default defineNuxtRouteMiddleware((to) => {
  useAffiliateReferral().captureRefFromRoute(to)
})

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

export default defineNuxtRouteMiddleware((to) => {
  const requiresAuth = !isPublicCustomerRoute(to.path)
  const guestOnly = to.meta.guestOnly === true
  const { isAuthenticated } = useAuth()

  if (requiresAuth && !isAuthenticated.value) {
    return navigateTo({
      path: '/login',
      query: {
        redirect: to.fullPath
      }
    })
  }

  if (guestOnly && isAuthenticated.value) {
    return navigateTo(getSafeRedirect(to.query.redirect))
  }
})

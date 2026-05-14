import { adminSessionCookieName } from '~/composables/useAdminSession'

const loginRedirect = (redirect: string) => ({ path: '/login', query: { redirect } })
const legacyLoginRedirect = () => ({ path: '/login' })

export default defineNuxtRouteMiddleware((to) => {
  const session = useAdminSession()

  if (!to.path.startsWith('/admin')) {
    return
  }

  if (to.path === '/admin/login') {
    return navigateTo(legacyLoginRedirect())
  }

  if (['/admin/403', '/admin/404', '/admin/500'].includes(to.path)) {
    return
  }

  if (import.meta.server) {
    const marker = useCookie<string | null>(adminSessionCookieName, {
      decode: (value) => value,
    })

    // The marker only permits a non-sensitive SSR restore shell; client sessionStorage remains the auth source.
    if (marker.value !== '1') {
      if (marker.value) {
        marker.value = null
      }

      return navigateTo(loginRedirect(to.fullPath))
    }

    return
  }

  session.restore()

  if (!session.isAuthenticated.value) {
    return navigateTo(loginRedirect(to.fullPath))
  }

  if (!session.alignScopeForPath(to.path)) {
    return navigateTo('/admin/403')
  }
})

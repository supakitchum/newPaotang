import { adminSessionCookieName } from '~/composables/useAdminSession'

const loginRedirect = (redirect: string) => ({ path: '/login', query: { redirect } })
const legacyLoginRedirect = () => ({ path: '/login' })

export default defineNuxtRouteMiddleware(async (to) => {
  const session = useAdminSession()
  const hostMode = useAdminHostMode()

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

  if (hostMode.isPartnerBoHost.value) {
    const adminSiteConfig = useAdminSiteConfig()
    await adminSiteConfig.load()

    if (adminSiteConfig.maintenanceActive.value) {
      session.clear()
      return navigateTo('/maintenance')
    }
  }

  session.restore()

  if (!session.isAuthenticated.value) {
    return navigateTo(loginRedirect(to.fullPath))
  }

  if (hostMode.isPartnerBoHost.value && !session.ensurePartnerTenantSession()) {
    session.rememberAuthNotice('This partner Back Office requires a tenant admin account for this domain.')
    session.clear()
    return navigateTo(loginRedirect('/admin/tenant/dashboard'))
  }

  if (hostMode.isPartnerBoHost.value && to.path.startsWith('/admin/central')) {
    session.rememberAuthNotice('Partner Back Office only supports tenant admin pages for this domain.')
    return navigateTo('/admin/tenant/dashboard')
  }

  if (!session.alignScopeForPath(to.path)) {
    return navigateTo('/admin/403')
  }
})

<template>
  <div class="page">
    <AdminHeader :client-ready="clientReady" />
    <AdminSidebar :menus="visibleMenus" :loading="visibleMenuLoading" :client-ready="clientReady" />
    <button class="np-sidebar-backdrop border-0" type="button" aria-label="Close sidebar" @click="closeSidebar" />
    <div class="np-admin-content-scroll">
      <main class="main-content app-content">
        <div class="container-fluid">
          <AdminProtectedContent :show="canRenderAdminContent">
            <AdminAlert v-if="error" type="warning" :message="error.message || t('menus.sidebar.loadError')" dismissible @dismiss="error = null" />
            <slot />
          </AdminProtectedContent>
        </div>
      </main>
      <AdminFooter />
    </div>
    <AdminSearchModal :menus="visibleMenus" />
    <AdminToast />
  </div>
</template>

<script setup lang="ts">
const navigation = useAdminNavigation()
const { navigationMenus, loading, error, loadMenus } = navigation
const session = useAdminSession()
const adminBranding = useAdminBranding()
const route = useRoute()
const { t } = useAdminLocale()
const { ready, markReady } = useAdminClientReady()
const adminSessionRedirectTimeoutMs = 3000
const adminMenuBadgeMinRefreshMs = 3000
const adminMobileSidebarQuery = '(max-width: 991.98px)'
const clientReady = computed(() => ready.value)
const isPublicAdminStatusPage = computed(() => ['/admin/403', '/admin/404', '/admin/500'].includes(route.path))
const canRenderAdminContent = computed(() => isPublicAdminStatusPage.value || (clientReady.value && session.isAuthenticated.value))
const visibleMenus = computed(() => canRenderAdminContent.value ? navigationMenus.value : [])
const visibleMenuLoading = computed(() => canRenderAdminContent.value && loading.value)
let sessionRedirectTimer: ReturnType<typeof setTimeout> | null = null
let menuBadgeRefreshInFlight = false
let menuBadgeRefreshListenersStarted = false
let lastMenuBadgeRefreshAt = 0
let sidebarMediaQuery: MediaQueryList | null = null

const clearSessionRedirectTimer = () => {
  if (!sessionRedirectTimer) {
    return
  }

  clearTimeout(sessionRedirectTimer)
  sessionRedirectTimer = null
}

const redirectExpiredAdminSession = async () => {
  if (isPublicAdminStatusPage.value || session.isAuthenticated.value) {
    return false
  }

  session.clear()
  await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
  return true
}

const redirectStalledAdminRestore = async () => {
  if (isPublicAdminStatusPage.value) {
    return false
  }

  session.clear()
  await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
  return true
}

const shouldRefreshMenuBadges = () => (
  clientReady.value
  && session.isAuthenticated.value
  && !isPublicAdminStatusPage.value
)

const refreshMenuBadges = async (options: { force?: boolean } = {}) => {
  if (!shouldRefreshMenuBadges() || menuBadgeRefreshInFlight) {
    return
  }

  if (!options.force && typeof document !== 'undefined' && document.hidden) {
    return
  }

  const now = Date.now()
  if (!options.force && now - lastMenuBadgeRefreshAt < adminMenuBadgeMinRefreshMs) {
    return
  }

  menuBadgeRefreshInFlight = true
  try {
    await loadMenus({ silent: true })
    lastMenuBadgeRefreshAt = Date.now()
  } finally {
    menuBadgeRefreshInFlight = false
  }
}

const handleMenuBadgeWake = () => {
  void refreshMenuBadges({ force: true })
}

const handleVisibilityChange = () => {
  if (typeof document !== 'undefined' && !document.hidden) {
    handleMenuBadgeWake()
  }
}

const startMenuBadgeRefresh = () => {
  if (!import.meta.client || menuBadgeRefreshListenersStarted) {
    return
  }

  menuBadgeRefreshListenersStarted = true
  window.addEventListener('focus', handleMenuBadgeWake)
  window.addEventListener('online', handleMenuBadgeWake)
  window.addEventListener('admin:menu-badges-refresh', handleMenuBadgeWake)
  document.addEventListener('visibilitychange', handleVisibilityChange)
}

const stopMenuBadgeRefresh = () => {
  if (!import.meta.client) {
    return
  }

  window.removeEventListener('focus', handleMenuBadgeWake)
  window.removeEventListener('online', handleMenuBadgeWake)
  window.removeEventListener('admin:menu-badges-refresh', handleMenuBadgeWake)
  document.removeEventListener('visibilitychange', handleVisibilityChange)
  menuBadgeRefreshListenersStarted = false
}

const removeLegacyResponsiveOverlay = () => {
  if (!import.meta.client) {
    return
  }

  document.querySelectorAll('#responsive-overlay').forEach((element) => {
    element.classList.remove('active')
    element.remove()
  })
}

const isMobileSidebarViewport = () => (
  import.meta.client
  && window.matchMedia(adminMobileSidebarQuery).matches
)

const closeSidebar = () => {
  if (!import.meta.client) {
    return
  }

  removeLegacyResponsiveOverlay()
  document.documentElement.setAttribute('data-toggled', 'close')
}

const sanitizeSidebarOverlayState = () => {
  if (!import.meta.client) {
    return
  }

  removeLegacyResponsiveOverlay()

  if (document.documentElement.getAttribute('data-toggled') !== 'open') {
    return
  }

  if (isMobileSidebarViewport()) {
    document.documentElement.setAttribute('data-toggled', 'close')
  } else {
    document.documentElement.removeAttribute('data-toggled')
  }
}

const handleSidebarViewportChange = () => {
  sanitizeSidebarOverlayState()
}

const adminMenuRealtimeChannelName = computed(() => {
  if (!shouldRefreshMenuBadges()) {
    return ''
  }

  if (session.currentScope.value === 'tenant') {
    const tenantId = String(session.currentTenantId.value || '').trim()
    return tenantId ? `private-admin.tenant.${tenantId}.menu` : ''
  }

  return session.currentScope.value === 'central' ? 'private-admin.central.menu' : ''
})
const adminMenuRealtimeEnabled = computed(() => Boolean(adminMenuRealtimeChannelName.value))

useAdminRealtimeSubscription({
  channelName: adminMenuRealtimeChannelName,
  eventName: 'admin.menu.badges.updated',
  enabled: adminMenuRealtimeEnabled,
  onEvent: () => {
    void refreshMenuBadges({ force: true })
  },
  onReconnect: () => {
    void refreshMenuBadges({ force: true })
  },
})

onMounted(async () => {
  sidebarMediaQuery = window.matchMedia(adminMobileSidebarQuery)
  sidebarMediaQuery.addEventListener('change', handleSidebarViewportChange)
  sanitizeSidebarOverlayState()

  sessionRedirectTimer = setTimeout(() => {
    void redirectStalledAdminRestore()
  }, adminSessionRedirectTimeoutMs)

  session.restore()
  await adminBranding.load()
  markReady()
  session.applyPreferredLocale()

  if (await redirectExpiredAdminSession()) {
    clearSessionRedirectTimer()
    return
  }

  if (session.isAuthenticated.value) {
    await loadMenus()
    lastMenuBadgeRefreshAt = Date.now()
    startMenuBadgeRefresh()
  }

  if (await redirectExpiredAdminSession()) {
    clearSessionRedirectTimer()
    return
  }

  clearSessionRedirectTimer()
})

onBeforeUnmount(() => {
  clearSessionRedirectTimer()
  stopMenuBadgeRefresh()
  sidebarMediaQuery?.removeEventListener('change', handleSidebarViewportChange)
  sidebarMediaQuery = null
})

watch(() => route.fullPath, () => {
  sanitizeSidebarOverlayState()
})

watch(() => [session.currentScope.value, session.currentTenantId.value], () => {
  if (!clientReady.value || !session.isAuthenticated.value) {
    return
  }
  lastMenuBadgeRefreshAt = Date.now()
  loadMenus()
})

watch(() => session.isAuthenticated.value, (authenticated) => {
  if (!clientReady.value || authenticated || isPublicAdminStatusPage.value) {
    if (authenticated) {
      startMenuBadgeRefresh()
    } else {
      stopMenuBadgeRefresh()
    }
    return
  }

  stopMenuBadgeRefresh()
  void redirectExpiredAdminSession()
})

</script>

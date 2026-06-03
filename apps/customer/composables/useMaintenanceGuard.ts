import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

const MAINTENANCE_PATH = '/maintenance'
const REFRESH_INTERVAL_MS = 5000

export const useMaintenanceGuard = () => {
  if (!process.client) {
    return
  }

  const route = useRoute()
  const {
    config,
    fetchSiteConfig,
    isMaintenanceActive,
    isRouteBlockedByMaintenance
  } = useSiteConfig()
  const checking = ref(false)
  let timer: ReturnType<typeof setInterval> | null = null

  const redirectIfBlocked = async (force = false) => {
    if (checking.value) {
      return
    }

    checking.value = true
    try {
      await fetchSiteConfig({ force })

      if (route.path === MAINTENANCE_PATH && config.value && !isMaintenanceActive.value) {
        await navigateTo('/', { replace: true })
        return
      }

      if (route.path !== MAINTENANCE_PATH && isRouteBlockedByMaintenance(route.path)) {
        await navigateTo(MAINTENANCE_PATH, { replace: true })
      }
    } finally {
      checking.value = false
    }
  }

  const refreshWhenVisible = () => {
    if (document.visibilityState === 'visible') {
      void redirectIfBlocked(true)
    }
  }

  watch(
    () => route.fullPath,
    () => {
      void redirectIfBlocked(true)
    }
  )

  watch(
    isMaintenanceActive,
    () => {
      void redirectIfBlocked(false)
    }
  )

  onMounted(() => {
    void redirectIfBlocked(true)

    timer = setInterval(() => {
      void redirectIfBlocked(true)
    }, REFRESH_INTERVAL_MS)

    document.addEventListener('visibilitychange', refreshWhenVisible)
    window.addEventListener('focus', refreshWhenVisible)
  })

  onBeforeUnmount(() => {
    if (timer) {
      clearInterval(timer)
      timer = null
    }

    document.removeEventListener('visibilitychange', refreshWhenVisible)
    window.removeEventListener('focus', refreshWhenVisible)
  })
}

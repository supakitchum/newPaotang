import { computed, onMounted, ref, watch } from 'vue'

const MAINTENANCE_PATH = '/maintenance'

export const useMaintenanceGuard = () => {
  if (!process.client) {
    return
  }

  const route = useRoute()
  const {
    config,
    fetchSiteConfig,
    setSiteConfig,
    isMaintenanceActive,
    isRouteBlockedByMaintenance
  } = useSiteConfig()
  const checking = ref(false)

  const redirectIfBlocked = async (force = false) => {
    if (checking.value) {
      return
    }

    checking.value = true
    try {
      if (!config.value || force) {
        await fetchSiteConfig({ force })
      }

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

  const applySiteConfigPatch = (payload: Record<string, any>) => {
    if (!payload || typeof payload !== 'object' || !config.value) {
      return
    }

    const tenantId = String(payload.tenant_id || '').trim()
    const currentTenantId = String(config.value.tenant_id || '').trim()
    if (tenantId && currentTenantId && tenantId !== currentTenantId) {
      return
    }

    const maintenance = payload.maintenance
    if (!maintenance || typeof maintenance !== 'object' || Array.isArray(maintenance)) {
      return
    }

    const currentTimestamps = config.value.timestamps
    const timestamps = currentTimestamps && typeof currentTimestamps === 'object' && !Array.isArray(currentTimestamps)
      ? currentTimestamps
      : {}

    setSiteConfig({
      ...config.value,
      maintenance: {
        ...(config.value.maintenance || {}),
        ...maintenance,
      },
      timestamps: {
        ...timestamps,
        site_config_realtime_at: payload.updated_at || new Date().toISOString(),
      },
    })

    void redirectIfBlocked(false)
  }

  useCustomerStockRealtime({
    enabled: computed(() => Boolean(config.value?.tenant_id)),
    onSiteConfig: applySiteConfigPatch,
    onReconnect: () => {
      void redirectIfBlocked(true)
    },
  })

  watch(
    () => route.fullPath,
    () => {
      void redirectIfBlocked(false)
    }
  )

  watch(
    isMaintenanceActive,
    () => {
      void redirectIfBlocked(false)
    }
  )

  onMounted(() => {
    void redirectIfBlocked(false)
  })
}

<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
  <AnnouncementModal />
  <AppSplashScreen />
  <AppAlert />
</template>

<script setup lang="ts">
import { requiresCustomerAuth } from '~/utils/customerAuthRoutes'

const { isAuthenticated } = useAuth()
const route = useRoute()
const hasRouteRealtime = computed(() => (
  route.path === '/buy'
  || route.path.startsWith('/buy/')
  || route.path === '/stores/lotteries'
  || route.path === '/topup'
  || route.path === '/my-wallet'
))
const shouldUseGlobalPresence = computed(() => isAuthenticated.value && requiresCustomerAuth(route.path) && !hasRouteRealtime.value)

useCustomerStockRealtime({
  enabled: shouldUseGlobalPresence,
  includePresence: true,
})

useSaleClosureGuard()
useMaintenanceGuard()
usePublicVisitMonitor()
</script>

<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
  <AppSplashScreen />
  <AppAlert />
</template>

<script setup lang="ts">
const { isAuthenticated } = useAuth()
const route = useRoute()
const hasRouteRealtime = computed(() => (
  route.path === '/buy'
  || route.path.startsWith('/buy/')
  || route.path === '/stores/lotteries'
  || route.path === '/topup'
))
const shouldUseGlobalPresence = computed(() => isAuthenticated.value && !hasRouteRealtime.value)

useCustomerStockRealtime({
  enabled: shouldUseGlobalPresence,
  includePresence: true,
})

useSaleClosureGuard()
</script>

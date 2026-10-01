<template>
  <section class="app-shell">
    <StatusBar :time="time" />
    <div class="app-scroll" :class="{ 'has-floating-payment': showCartPaymentDock }">
      <slot />
    </div>
    <PaymentDock
      v-if="showCartPaymentDock"
      class="cart-payment-dock"
      :class="{ 'home-cart-payment-dock': isHomeNavCartDock }"
      :amount="cartAmount"
      :button="cartButton"
      :count="cartCount"
      label="จำนวนที่เลือก"
      :timer="cartTimer"
      :to="cartTo"
      :variant="cartDockVariant"
    />
    <BottomNav v-if="showBottomNav" :active="activeNav" />
  </section>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

defineProps({
  activeNav: {
    type: String,
    default: 'home'
  },
  showBottomNav: {
    type: Boolean,
    default: false
  },
  time: {
    type: String,
    default: '12:29'
  }
})

const route = useRoute()
const { hasItems, exp, count: cartCount, amount: cartAmount, timer: cartTimer, isExpired, setCartItems } = useCart()
const platformApi = usePlatformApi()
const isSyncingExpiredCart = ref(false)
const expiredCartSyncedFor = ref<string | number | null>(null)
const isHomeNavCartDock = computed(() => route.path === '/')
const isLotteryBrowseRoute = computed(() => route.path === '/' || route.path === '/buy' || route.path.startsWith('/buy/') || route.path === '/stores' || route.path.startsWith('/stores/'))
const showCartPaymentDock = computed(() => hasItems.value && isLotteryBrowseRoute.value)
const cartDockVariant = computed(() => isHomeNavCartDock.value ? 'selection' : 'review')
const cartButton = computed(() => isHomeNavCartDock.value ? 'ชำระเงิน' : 'ตรวจสอบสลากฯ')
const cartTo = computed(() => isHomeNavCartDock.value ? '/checkout' : '/cart')

const applyCartPayload = (payload: Record<string, any> | null | undefined) => {
  if (Array.isArray(payload?.carts)) {
    setCartItems(
      payload.carts,
      payload.result?.cart_order?.exp || null,
      payload.server_time || payload.result?.cart_order?.created_at || null
    )
    return
  }

  setCartItems([])
}

const syncExpiredCartFromBackend = async () => {
  if (!hasItems.value || !isExpired.value || isSyncingExpiredCart.value || expiredCartSyncedFor.value === exp.value) {
    return
  }

  expiredCartSyncedFor.value = exp.value
  isSyncingExpiredCart.value = true

  try {
    const response = await platformApi.loadCartLegacy()

    applyCartPayload(response.data)
  } catch (e) {
    console.log(e)
  } finally {
    isSyncingExpiredCart.value = false
  }
}

const handleVisibilityChange = () => {
  if (document.visibilityState === 'visible') {
    void syncExpiredCartFromBackend()
  }
}

watch(exp, () => {
  expiredCartSyncedFor.value = null
})

watch(isExpired, (expired) => {
  if (expired) {
    void syncExpiredCartFromBackend()
  }
})

onMounted(() => {
  void syncExpiredCartFromBackend()
  document.addEventListener('visibilitychange', handleVisibilityChange)
})

onBeforeUnmount(() => {
  document.removeEventListener('visibilitychange', handleVisibilityChange)
})
</script>

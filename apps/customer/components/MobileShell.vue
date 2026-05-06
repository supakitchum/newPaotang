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
import { computed } from 'vue'

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
const { hasItems, count: cartCount, amount: cartAmount, timer: cartTimer } = useCart()
const isHomeNavCartDock = computed(() => route.path === '/')
const isLotteryBrowseRoute = computed(() => route.path === '/' || route.path === '/buy' || route.path.startsWith('/buy/') || route.path === '/stores' || route.path.startsWith('/stores/'))
const showCartPaymentDock = computed(() => hasItems.value && isLotteryBrowseRoute.value)
const cartDockVariant = computed(() => isHomeNavCartDock.value ? 'selection' : 'review')
const cartButton = computed(() => isHomeNavCartDock.value ? 'ชำระเงิน' : 'ตรวจสอบสลากฯ')
const cartTo = computed(() => isHomeNavCartDock.value ? '/checkout' : '/cart')
</script>

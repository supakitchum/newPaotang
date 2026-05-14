<template>
  <MobileShell time="12:58">
    <BlueHeader title="ยืนยันการชำระเงิน" back-to="/cart" min-height="454px">
      <div class="summary-card mt-4 text-dark">
        <div class="d-flex align-items-center gap-3 border-bottom pb-3 mb-3">
          <div class="rounded-circle border d-grid place-center" style="width:48px;height:48px">
            <BrandLogo />
          </div>
          <div class="fw-bold fs-5">สลากกินแบ่งรัฐบาล</div>
        </div>
        <div class="d-flex justify-content-between fs-5 mb-2">
          <span class="muted-text">จำนวนสลากฯ</span>
          <span><strong>{{ orderCount }}</strong> ใบ</span>
        </div>
        <div class="d-flex justify-content-between fs-5">
          <span class="muted-text">ยอดชำระทั้งหมด</span>
          <span><strong class="text-primary fs-2">{{ formatMoney(orderTotal) }}</strong> บาท</span>
        </div>
        <div v-if="orderTickets.length" class="checkout-ticket-preview mt-3">
          <LotteryImage
            v-for="(ticket, index) in orderTickets"
            :key="`${ticket.token || ticket.number}-${index}`"
            :src="ticket.image_url || ticket.image"
            :thumb-src="ticket.image_thumb_url"
            :status="ticket.image_status"
            :error-message="ticket.image_error"
            :number="getTicketNumber(ticket)"
            variant="stub"
          />
        </div>
        <div v-if="isPreparing" class="text-primary fw-semibold mt-3">กำลังเตรียมรายการชำระเงิน...</div>
        <div v-else-if="prepareError" class="text-danger fw-semibold mt-3">{{ prepareError }}</div>
      </div>
    </BlueHeader>

    <section class="content-sheet flush">
      <h2 class="fs-5 fw-bold mb-4">ช่องทางชำระเงิน</h2>
      <div class="wallet-card">
        <div class="d-flex align-items-center gap-3 p-3">
          <i
            class="bi fs-3"
            :class="primaryWallet ? 'bi-check-circle-fill text-primary' : 'bi-circle text-muted'"
          />
          <div class="flex-grow-1">
            <div class="fw-bold fs-5">{{ walletName }}</div>
            <div class="fw-bold fs-5">
              <span v-if="isWalletLoading">กำลังโหลด...</span>
              <span v-else>{{ formatMoney(walletBalance) }} บาท</span>
            </div>
            <div v-if="!isWalletLoading && !hasEnoughBalance" class="text-danger small fw-semibold mt-1">
              ยอดเงินไม่เพียงพอสำหรับชำระรายการนี้
            </div>
            <NuxtLink class="outline-pill d-inline-flex align-items-center gap-2 mt-2" to="/topup">
              <i class="bi bi-plus-lg" /> เติมเงิน
            </NuxtLink>
          </div>
          <div class="rounded-3 d-grid place-center text-white fs-2 fw-bold" style="width:55px;height:55px;background:#1e8bc2">G</div>
        </div>
        <div class="wallet-note">
          คุณสามารถ ‘ยืนยันชำระเงิน’ เพื่อใช้บัญชีกรุงไทยที่ผูกไว้ชำระเงินค่าสลากฯ ได้อัตโนมัติ
        </div>
      </div>
      <div style="height:265px" />
      <div class="payment-dock">
        <div class="text-center fw-semibold mb-3">
          กรุณาชำระเงินภายใน <span class="text-primary">{{ timer }}</span> นาที
        </div>
        <button
          class="primary-pill d-block text-center py-3 w-100"
          type="button"
          :disabled="!canConfirmPayment"
          @click="handleConfirmPayment"
        >
          {{ confirmButtonText }}
        </button>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { ticketPrice } from '~/data/lottery'
import type { CartLottery } from '~/composables/useCart'

definePageMeta({
  requiresAuth: true
})

interface CheckoutOrder {
  id?: number | string
  total?: number | string
  amount?: number | string
  price?: number | string
  lotteries?: CartLottery[]
  status?: number | string
  [key: string]: unknown
}

interface WalletItem {
  id?: number | string
  balance?: number | string
  type?: number | string
  name?: string
  [key: string]: unknown
}

const platformApi = usePlatformApi()
const { items, count, amount, timer, clearCart } = useCart()
const { data, waiting, ensureAppInit, refreshAppInit } = useAppInit()
const { showAlert } = useAppAlert()
const successOrder = useState<CheckoutOrder | null>('checkout_success_order', () => null)

const wallets = ref<WalletItem[]>([])
const order = ref<CheckoutOrder | null>(null)
const isPreparing = ref(false)
const isWalletLoading = ref(false)
const isPaying = ref(false)
const prepareError = ref('')

const toNumber = (value: unknown, fallback = 0) => {
  const number = Number(value)

  return Number.isFinite(number) ? number : fallback
}

const isFilledObject = (value: unknown) => (
  Boolean(value && typeof value === 'object' && !Array.isArray(value) && Object.keys(value as Record<string, unknown>).length > 0)
)

const isOrderObject = (value: unknown) => {
  if (!isFilledObject(value)) {
    return false
  }

  const orderValue = value as CheckoutOrder

  return Boolean(orderValue.id && (Array.isArray(orderValue.lotteries) || orderValue.total || orderValue.amount || orderValue.status))
}

const extractOrder = (value: unknown) => {
  if (Array.isArray(value)) {
    return (value.find((item) => isOrderObject(item)) as CheckoutOrder | undefined) || null
  }

  return isOrderObject(value) ? value as CheckoutOrder : null
}

const getWaitingOrder = () => extractOrder(waiting.value)

const getCartOrder = () => (
  extractOrder(data.value?.cart_order) ||
  extractOrder(data.value?.orders) ||
  extractOrder(data.value?.order) ||
  extractOrder(data.value?.carts)
)

const withCurrentCartItems = (value: CheckoutOrder) => ({
  ...value,
  lotteries: Array.isArray(value.lotteries) && value.lotteries.length > 0 ? value.lotteries : items.value
})

const setCheckoutOrder = (value: CheckoutOrder | null) => {
  order.value = value ? withCurrentCartItems(value) : null
}

const getOrderLotteries = (value: CheckoutOrder | null) => (
  Array.isArray(value?.lotteries) ? value.lotteries : []
)

const getTicketCount = (ticket: Partial<CartLottery>) => Math.max(1, toNumber(ticket.count, 1))

const getTicketNumber = (ticket: Partial<CartLottery>) => {
  const value = ticket.number || ticket.full_number || ticket.lottery_number || ''

  return String(value)
}

const getTicketPrice = (ticket: Partial<CartLottery>) => {
  const price = toNumber(ticket.price)

  return price > 0 ? price : getTicketCount(ticket) * ticketPrice
}

const formatMoney = (value: number) => new Intl.NumberFormat('th-TH', {
  minimumFractionDigits: value % 1 === 0 ? 0 : 2,
  maximumFractionDigits: 2
}).format(value)

const primaryWallet = computed(() => (
  wallets.value.find((wallet) => Number(wallet.type) === 1) || wallets.value[0] || null
))

const walletName = computed(() => primaryWallet.value?.name || 'G Wallet')
const walletBalance = computed(() => toNumber(primaryWallet.value?.balance))
const orderTickets = computed(() => getOrderLotteries(order.value))
const orderCount = computed(() => {
  if (orderTickets.value.length > 0) {
    return orderTickets.value.reduce((total, ticket) => total + getTicketCount(ticket), 0)
  }

  return count.value
})
const orderTotal = computed(() => {
  const orderValue = order.value
  const explicitTotal = toNumber(orderValue?.total ?? orderValue?.amount ?? orderValue?.price)

  if (explicitTotal > 0) {
    return explicitTotal
  }

  if (orderTickets.value.length > 0) {
    return orderTickets.value.reduce((total, ticket) => total + getTicketPrice(ticket), 0)
  }

  return amount.value
})
const hasEnoughBalance = computed(() => walletBalance.value >= orderTotal.value)
const canConfirmPayment = computed(() => (
  Boolean(order.value?.id) &&
  !isPreparing.value &&
  !isPaying.value &&
  !isWalletLoading.value &&
  hasEnoughBalance.value
))
const confirmButtonText = computed(() => {
  if (isPreparing.value) {
    return 'กำลังเตรียมรายการ...'
  }

  if (isPaying.value) {
    return 'กำลังชำระเงิน...'
  }

  if (isWalletLoading.value) {
    return 'กำลังโหลดกระเป๋าเงิน...'
  }

  if (!order.value?.id) {
    return 'ไม่พบรายการชำระเงิน'
  }

  if (!hasEnoughBalance.value) {
    return 'ยอดเงินไม่เพียงพอ'
  }

  return 'ยืนยันชำระเงิน'
})

const fetchWallet = async () => {
  isWalletLoading.value = true

  try {
    const response = await platformApi.walletLegacy()
    wallets.value = Array.isArray(response.data?.result) ? response.data.result : []
  } catch {
    wallets.value = []
    showAlert({
      title: 'โหลดกระเป๋าเงินไม่สำเร็จ',
      message: 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isWalletLoading.value = false
  }
}

const prepareOrder = async () => {
  isPreparing.value = true
  prepareError.value = ''

  await ensureAppInit()

  const waitingOrder = getWaitingOrder()

  if (waitingOrder) {
    setCheckoutOrder(waitingOrder)
    isPreparing.value = false
    return
  }

  const cartOrder = getCartOrder()

  if (cartOrder) {
    setCheckoutOrder(cartOrder)
    isPreparing.value = false
    return
  }

  if (items.value.length === 0) {
    prepareError.value = 'ไม่พบรายการสลากฯ สำหรับชำระเงิน'
  } else {
    prepareError.value = 'ไม่พบเลขที่คำสั่งซื้อสำหรับชำระเงิน'
  }

  isPreparing.value = false
}

const handleConfirmPayment = async () => {
  if (!order.value?.id) {
    showAlert({
      title: 'ไม่พบรายการชำระเงิน',
      message: 'กรุณากลับไปเลือกสลากฯ อีกครั้ง',
      variant: 'warning'
    })
    return
  }

  if (!hasEnoughBalance.value) {
    showAlert({
      title: 'ยอดเงินไม่เพียงพอ',
      message: 'กรุณาเติมเงินก่อนยืนยันชำระเงิน',
      variant: 'warning'
    })
    return
  }

  isPaying.value = true

  try {
    const response = await platformApi.checkoutLegacy(order.value.id)

    const paidOrder = response.data?.result?.order || order.value
    successOrder.value = paidOrder

    await refreshAppInit()
    clearCart()
    navigateTo({
      path: '/success',
      query: {
        order_id: String(paidOrder.id || order.value.id)
      }
    })
  } catch (error: any) {
    showAlert({
      title: 'ชำระเงินไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isPaying.value = false
  }
}

onMounted(() => {
  fetchWallet()
  prepareOrder()
})
</script>

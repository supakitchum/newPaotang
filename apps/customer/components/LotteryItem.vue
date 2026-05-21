<template>
  <article class="lottery-row" :class="{ 'is-lazy': loading, 'is-unavailable': isUnavailable }">
    <template v-if="!loading">
      <div class="d-flex justify-content-between align-items-start gap-3">
        <div class="ticket-brand">
          <span class="lottery-six">L6</span>
          <span>สลากกินแบ่งรัฐบาล</span>
        </div>
        <NuxtLink
          v-if="showMoreLink"
          class="blue-link"
          :to="{ path: '/buy/more', query: { number: ticketNumber } }"
        >
          ดูเลขนี้เพิ่ม
        </NuxtLink>
      </div>
      <div class="lottery-main-row">
        <div class="lottery-display-grid">
          <LotteryImage
            v-if="showImage"
            :src="ticket.image_url || ticket.image"
            :thumb-src="ticket.image_thumb_url"
            :status="ticket.image_status"
            :error-message="ticket.image_error"
            :number="ticketNumber"
            variant="card"
          />
          <div class="ticket-data-grid">
            <LotteryNumber :number="ticketNumber" :highlight="ticket.highlight" :highlight-digits="ticket.highlightDigits" />
          </div>
        </div>
        <button
          v-if="ticket.selected && confirmRemove"
          class="remove-pill px-4 py-2"
          type="button"
          @click="$emit('remove')"
        >
          เอาออก
        </button>
        <button
          v-else-if="isInCart"
          class="remove-pill px-4 py-2"
          type="button"
          :disabled="isCancelling"
          @click="handleCancelBooking"
        >
          {{ isCancelling ? 'กำลังลบ' : 'เอาออก' }}
        </button>
        <button
          v-else
          class="outline-pill px-4 py-2"
          type="button"
          :disabled="isBooking || bookingDisabled || isUnavailable"
          @click="handleBooking"
        >
          {{ selectButtonText }}
        </button>
      </div>
      <div class="d-flex justify-content-between align-items-center mt-2">
        <div class="muted-text fw-medium">{{ sellerName }}</div>
        <div class="price" :class="priceTrendClass">
          <i v-if="priceTrend === 'up'" class="bi bi-arrow-up-short price-trend-icon" aria-hidden="true" />
          <i v-else-if="priceTrend === 'down'" class="bi bi-arrow-down-short price-trend-icon" aria-hidden="true" />
          <span>{{ price }} บาท</span>
        </div>
      </div>
    </template>
    <template v-else>
      <div class="lottery-row-placeholder" aria-hidden="true">
        <div>
          <span class="placeholder-line placeholder-line-sm" />
          <span class="placeholder-number" />
          <span class="placeholder-line placeholder-line-md" />
        </div>
        <span class="placeholder-button" />
      </div>
    </template>
  </article>
  <div v-if="showUnavailableModal" class="modal-overlay booking-alert-overlay">
    <section class="booking-alert-modal" role="dialog" aria-modal="true" aria-labelledby="booking-alert-title">
      <div class="booking-alert-icon">
        <i class="bi bi-exclamation-lg" />
      </div>
      <h2 id="booking-alert-title">สลากใบนี้ถูกซื้อแล้ว</h2>
      <p>ขออภัย สลากที่ท่านเลือกมีคนซื้อแล้ว กรุณาเลือกสลากใบอื่น</p>
      <button class="primary-pill booking-alert-button" type="button" @click="closeUnavailableModal">
        รับทราบ
      </button>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { ticketPrice } from '~/data/lottery'

const props = defineProps<{
  ticket: {
    token?: string
    number: string
    full_number?: string
    lottery_number?: string
    seller?: string
    store_name?: string
    draw?: number | string
    draw_no?: number | string
    game_no?: number | string
    set?: number | string
    sort_order?: number | string
    selected?: boolean
    highlight?: string
    highlightDigits?: Array<string | null>
    image?: string | null
    image_url?: string | null
    image_thumb_url?: string | null
    image_status?: string | null
    image_error?: string | null
    price?: number | string
    priceTrend?: 'up' | 'down' | null
    priceFlashKey?: number | null
    remaining_count?: number | null
    availability_status?: string | null
    status?: string | null
  }
  confirmRemove?: boolean
  loading?: boolean
  bookingDisabled?: boolean
  showImage?: boolean
}>()

const emit = defineEmits<{
  remove: []
  bookingUnavailable: [ticket: typeof props.ticket]
  booked: [ticket: typeof props.ticket]
}>()

const platformApi = usePlatformApi()
const route = useRoute()
const { isAuthenticated } = useAuth()
const { items, addBookedLottery, removeLottery, setCartItems } = useCart()
const { showAlert } = useAppAlert()
const isBooking = ref(false)
const isCancelling = ref(false)
const showUnavailableModal = ref(false)
const shouldRemoveUnavailableTicket = ref(false)
const getTicketNumber = (ticket: typeof props.ticket) => {
  const value = ticket.number || ticket.full_number || ticket.lottery_number || ''

  return String(value)
}
const ticketNumber = computed(() => getTicketNumber(props.ticket))
const showMoreLink = computed(() => route.path !== '/buy/more')
const isUnavailable = computed(() => {
  const status = String(props.ticket.availability_status || props.ticket.status || '').toLowerCase()
  const hasRemainingCount = props.ticket.remaining_count !== null && props.ticket.remaining_count !== undefined

  return (hasRemainingCount && Number(props.ticket.remaining_count) <= 0) || ['sold_out', 'sold', 'reserved', 'unavailable'].includes(status)
})
const bookingDisabled = computed(() => Boolean(props.bookingDisabled))
const showImage = computed(() => props.showImage !== false)
const price = computed(() => {
  const value = Number(props.ticket.price)

  return Number.isFinite(value) && value > 0 ? value : ticketPrice
})
const priceTrend = computed(() => props.ticket.priceTrend || null)
const priceTrendClass = computed(() => ({
  'price-flash-up': priceTrend.value === 'up',
  'price-flash-down': priceTrend.value === 'down'
}))
const selectButtonText = computed(() => {
  if (isUnavailable.value) {
    return 'ขายหมดแล้ว'
  }

  if (bookingDisabled.value) {
    return 'ปิดรับซื้อ'
  }

  return isBooking.value ? 'กำลังจอง' : 'เลือก'
})
const cartItem = computed(() => {
  if (props.ticket.token) {
    return items.value.find((item) => item.token === props.ticket.token) || null
  }

  return items.value.find((item) => item.number === ticketNumber.value) || null
})
const isInCart = computed(() => props.ticket.selected || Boolean(cartItem.value))
const sellerName = computed(() => props.ticket.store_name ?? props.ticket.seller ?? '')

const openUnavailableModal = (shouldRemove = true) => {
  shouldRemoveUnavailableTicket.value = shouldRemove
  showUnavailableModal.value = true
}

const closeUnavailableModal = () => {
  showUnavailableModal.value = false

  if (shouldRemoveUnavailableTicket.value) {
    emit('bookingUnavailable', props.ticket)
  }

  shouldRemoveUnavailableTicket.value = false
}

const showCancelError = () => {
  showAlert({
    title: 'เกิดข้อผิดพลาด',
    message: 'กรุณาลองใหม่อีกครั้ง',
    variant: 'error'
  })
}

const getTicketToken = () => {
  const value = cartItem.value?.token || props.ticket.token || ''

  return String(value)
}

const handleCancelBooking = async () => {
  if (isCancelling.value) {
    return
  }

  isCancelling.value = true

  try {
    const response = await platformApi.releaseReservationLegacy(cartItem.value || props.ticket)

    if (response.data.code !== 0) {
      showCancelError()
      return
    }

    if (Array.isArray(response.data.carts)) {
      setCartItems(response.data.carts)
    } else {
      removeLottery(cartItem.value || props.ticket)
    }
  } catch (e) {
    console.log(e)
    showCancelError()
  } finally {
    isCancelling.value = false
  }
}

const handleBooking = async () => {
  if (isBooking.value || bookingDisabled.value || isUnavailable.value) {
    return
  }

  if (!isAuthenticated.value) {
    navigateTo({
      path: '/login',
      query: {
        redirect: route.fullPath
      }
    })
    return
  }

  isBooking.value = true

  try {
    const response = await platformApi.reserveLegacy(props.ticket)

    if (response.data.code !== 0) {
      openUnavailableModal()
      return
    }

    const responseTicket = response.data.result?.lottery || response.data.lottery || {}
    const bookedTicket = {
      ...props.ticket,
      ...responseTicket,
      number: getTicketNumber({
        ...props.ticket,
        ...responseTicket
      })
    }

    addBookedLottery(bookedTicket, response.data.exp)
    emit('booked', bookedTicket)
  } catch (e) {
    console.log(e)
    openUnavailableModal(false)
  } finally {
    isBooking.value = false
  }
}
</script>

<style scoped>
.price {
  align-items: center;
  display: inline-flex;
  gap: 2px;
  min-width: 72px;
  justify-content: flex-end;
}

.price-trend-icon {
  font-size: 1.15em;
  line-height: 1;
}

.price-flash-up {
  animation: pricePulse 2s ease-out;
  color: #15803d;
}

.price-flash-down {
  animation: pricePulse 2s ease-out;
  color: #dc2626;
}

@keyframes pricePulse {
  0%,
  55% {
    opacity: 1;
    transform: translateY(0);
  }

  20% {
    opacity: 0.35;
    transform: translateY(-1px);
  }

  100% {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>

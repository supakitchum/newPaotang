<template>
  <MobileShell time="12:57">
    <BlueHeader title="ตรวจสอบรายการสลากฯ" back-to="/buy" min-height="294px">
      <div class="mt-4">
        <h2 class="fs-5 fw-bold">สลากฯ {{ count }} ใบ</h2>
        <div>งวดวันที่ {{ drawDate }}</div>
      </div>
    </BlueHeader>

    <section class="content-sheet cart-sheet">
      <LotteryItem
        v-for="ticket in cartTickets"
        :key="`${ticket.game_id ?? ''}-${ticket.number}-${ticket.reservation_ids?.join('-') || ticket.token || ticket.sort_order || ''}`"
        :ticket="ticket"
        confirm-remove
        :show-image="false"
        :show-more-link="false"
        @remove="openRemoveConfirm(ticket)"
      />
      <p class="text-center muted-text fw-semibold fs-6 px-4 mt-4">
        คุณสามารถเลือกซื้อสลากฯ ได้สูงสุด 20 ใบ<br>ต่อการทำรายการซื้อ 1 ครั้ง
      </p>
      <div class="text-center">
        <NuxtLink class="green-pill" to="/buy"><i class="bi bi-plus-lg me-2" />เลือกสลากฯ เพิ่ม</NuxtLink>
      </div>
      <PaymentDock
        v-if="hasItems"
        class="cart-dock"
        :timer="timer"
        :amount="amount"
        button="ชำระเงิน"
        to="/checkout"
      />
    </section>

    <div v-if="showRemoveConfirm && selectedTicket" class="modal-overlay cart-remove-overlay">
      <section class="cart-remove-modal" role="dialog" aria-modal="true" aria-labelledby="remove-title">
        <h2 id="remove-title">
          คุณต้องการลบสลากฯ<br>
          {{ selectedTicket.number }}{{ selectedTicketCount > 1 ? ` จำนวน ${selectedTicketCount} ใบ` : '' }} หรือไม่
        </h2>
        <p>
          เมื่อยืนยัน สลากฯ {{ selectedTicketCount > 1 ? 'ชุดนี้' : 'ใบนี้' }}<br>
          จะถูกลบออกจากรายการซื้อ
        </p>
        <div class="cart-remove-actions">
          <button
            class="outline-pill cart-remove-cancel"
            type="button"
            :disabled="isRemoving"
            @click="showRemoveConfirm = false"
          >
            ยกเลิก
          </button>
          <button
            class="primary-pill cart-remove-confirm"
            type="button"
            :disabled="isRemoving"
            @click="confirmRemove"
          >
            {{ isRemoving ? 'กำลังลบ' : 'ลบ' }}
          </button>
        </div>
      </section>
    </div>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { getCartLotteryNumber } from '~/composables/useCart'
import { ticketPrice } from '~/data/lottery'
import type { CartLottery } from '~/composables/useCart'

definePageMeta({
  requiresAuth: true
})

const { items, count, amount, timer, hasItems, removeLottery, setCartItems } = useCart()
const { currentDrawDate: drawDate } = useAppInit()
const platformApi = usePlatformApi()
const { showAlert } = useAppAlert()
const showRemoveConfirm = ref(false)
const selectedTicket = ref<CartLottery | null>(null)
const isRemoving = ref(false)
const isRefreshingCart = ref(false)

const toNumber = (value: unknown, fallback = 0) => {
  const number = Number(value)

  return Number.isFinite(number) ? number : fallback
}

const ticketCount = (ticket: Partial<CartLottery>) => Math.max(1, toNumber(ticket.count, 1))
const ticketAmount = (ticket: Partial<CartLottery>) => {
  const price = toNumber(ticket.price)

  return price > 0 ? price : ticketCount(ticket) * ticketPrice
}

const groupCartTickets = (tickets: CartLottery[]) => {
  const groups = new Map<string, CartLottery[]>()

  tickets.forEach((ticket) => {
    const number = getCartLotteryNumber(ticket)
    const key = `${ticket.game_id || ''}:${number}`
    const group = groups.get(key) || []

    group.push(ticket)
    groups.set(key, group)
  })

  return Array.from(groups.values()).map((group) => {
    const first = group[0]
    const groupCount = group.reduce((total, ticket) => total + ticketCount(ticket), 0)
    const groupPrice = group.reduce((total, ticket) => total + ticketAmount(ticket), 0)
    const reservationIds = Array.from(new Set(group.map((ticket) => String(ticket.reservation_id || '').trim()).filter(Boolean)))

    return {
      ...first,
      number: getCartLotteryNumber(first),
      count: groupCount,
      group_count: groupCount,
      group_items: group,
      local_stock_item_ids: group.map((ticket) => ticket.local_stock_item_id).filter((value): value is string | number => value !== null && value !== undefined && value !== ''),
      reservation_ids: reservationIds,
      price: groupPrice,
      selected: true,
      highlight: '',
      highlightDigits: null,
      priceTrend: null,
      priceFlashKey: null
    }
  })
}

const cartTickets = computed<CartLottery[]>(() => groupCartTickets(items.value))
const selectedTicketCount = computed(() => selectedTicket.value ? ticketCount(selectedTicket.value) : 1)

const openRemoveConfirm = (ticket: CartLottery) => {
  selectedTicket.value = ticket
  showRemoveConfirm.value = true
}

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

const refreshCartFromBackend = async () => {
  if (isRefreshingCart.value) {
    return
  }

  isRefreshingCart.value = true

  try {
    const response = await platformApi.loadCartLegacy()

    applyCartPayload(response.data)
  } catch (e) {
    console.log(e)
  } finally {
    isRefreshingCart.value = false
  }
}

const showRemoveError = () => {
  showAlert({
    title: 'เกิดข้อผิดพลาด',
    message: 'กรุณาลองใหม่อีกครั้ง',
    variant: 'error'
  })
}

const confirmRemove = async () => {
  if (!selectedTicket.value || isRemoving.value) {
    return
  }

  isRemoving.value = true

  try {
    const groupItems = Array.isArray(selectedTicket.value.group_items) && selectedTicket.value.group_items.length > 0
      ? selectedTicket.value.group_items
      : [selectedTicket.value]
    const reservationIds = Array.from(new Set(groupItems.map((ticket) => String(ticket.reservation_id || '').trim()).filter(Boolean)))
    let response: any = null

    if (reservationIds.length > 0) {
      for (const reservationId of reservationIds) {
        response = await platformApi.releaseReservationLegacy({ reservation_id: reservationId })

        if (response.data.code !== 0) {
          showRemoveError()
          return
        }
      }
    } else {
      response = await platformApi.releaseReservationLegacy(selectedTicket.value)
    }

    if (response.data.code !== 0) {
      showRemoveError()
      return
    }

    if (Array.isArray(response.data.carts)) {
      applyCartPayload(response.data)
    } else {
      removeLottery(selectedTicket.value)
    }

    selectedTicket.value = null
    showRemoveConfirm.value = false
  } catch (e) {
    console.log(e)
    showRemoveError()
  } finally {
    isRemoving.value = false
  }
}

onMounted(() => {
  void refreshCartFromBackend()
})
</script>

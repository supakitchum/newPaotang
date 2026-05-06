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
        v-for="ticket in items"
        :key="`${ticket.token ?? ticket.number}-${ticket.sort_order ?? ticket.set ?? ''}`"
        :ticket="ticket"
        confirm-remove
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
          {{ selectedTicket.number }} หรือไม่
        </h2>
        <p>
          เมื่อยืนยัน สลากฯ ใบนี้<br>
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
import { ref } from 'vue'
import type { CartLottery } from '~/composables/useCart'

definePageMeta({
  requiresAuth: true
})

const { items, count, amount, timer, hasItems, removeLottery, setCartItems } = useCart()
const { currentDrawDate: drawDate } = useAppInit()
const axios = useAxios()
const { showAlert } = useAppAlert()
const showRemoveConfirm = ref(false)
const selectedTicket = ref<CartLottery | null>(null)
const isRemoving = ref(false)

const openRemoveConfirm = (ticket: CartLottery) => {
  selectedTicket.value = ticket
  showRemoveConfirm.value = true
}

const getTicketToken = (ticket: CartLottery) => {
  const value = ticket.token || ''

  return String(value)
}

const getTicketNumber = (ticket: CartLottery) => {
  const value = ticket.full_number || ticket.number || ticket.lottery_number || ''

  return String(value)
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
    const response = await axios.post('/lotteries/cancel_booking', {
      token: getTicketToken(selectedTicket.value),
      full_number: getTicketNumber(selectedTicket.value)
    })

    if (response.data.code !== 0) {
      showRemoveError()
      return
    }

    if (Array.isArray(response.data.carts)) {
      setCartItems(response.data.carts)
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
</script>

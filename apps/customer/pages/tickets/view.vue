<template>
  <MobileShell time="13:07" active-nav="tickets" show-bottom-nav>
    <BlueHeader title="สลากฯ ของฉัน" min-height="253px">
      <div class="mt-4">
        <SegmentTabs :tabs="tabs" />
      </div>
    </BlueHeader>
    <section class="content-sheet">
      <div class="mb-4">
        <div class="muted-text fw-semibold">สลากฯ งวดวันที่</div>
        <h2 class="fs-5 fw-bold mb-1">{{ drawDate }}</h2>
        <div class="muted-text fw-semibold">ทั้งหมด {{ ticketCount }} ใบ</div>
      </div>

      <div v-if="isLoading" class="empty-lottery-state">
        กำลังโหลดสลากฯ
      </div>

      <TicketStub
        v-else-if="selectedTicket"
        :number="ticketNumber"
        :status="getTicketStatusText(selectedTicket)"
        :image-url="selectedTicket.image_url || selectedTicket.image"
        :image-thumb-url="selectedTicket.image_thumb_url"
        :image-status="selectedTicket.image_status"
        :image-error="selectedTicket.image_error"
      />

      <div v-else class="empty-lottery-state">
        ไม่พบสลากฯ
      </div>
    </section>
    <div v-if="selectedTicket" class="modal-overlay">
      <section class="ticket-modal">
        <div class="d-flex justify-content-center align-items-start mb-3">
          <div class="d-flex align-items-center gap-3">
            <BrandLogo />
            <span class="lottery-six fs-2">L6</span>
          </div>
          <button class="icon-back-button ms-auto text-dark fs-2" type="button" aria-label="กลับ" @click="goBack">
            <i class="bi bi-x-lg" />
          </button>
        </div>
        <LotteryImage
          :src="ticketImageUrl"
          :thumb-src="selectedTicket.image_thumb_url"
          :status="selectedTicket.image_status"
          :error-message="selectedTicket.image_error"
          :number="ticketNumber"
          variant="preview"
        />
        <div class="d-flex align-items-center gap-3 p-3 mt-3" style="background:#edf8ff;margin:0 -18px;border-radius:0 0 12px 12px;">
          <div class="rounded-3 d-grid place-center text-white fw-bold" style="width:44px;height:44px;background:#1298d7">เป๋าตัง</div>
          <div class="fw-semibold">
            สลากฯ ใบนี้ขายที่บริการ ‘สลากหกหลัก’<br>บนแอปฯ เป๋าตังเท่านั้น
          </div>
        </div>
      </section>
    </div>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { UserTicket, UserTicketGame } from '~/composables/useUserTickets'

definePageMeta({
  requiresAuth: true
})

const router = useRouter()
const route = useRoute()
const { currentDrawDate } = useAppInit()
const {
  fetchTickets,
  getGameDate,
  getTicketNumber,
  getTicketCount,
  getTicketImageUrl,
  getTicketStatusText
} = useUserTickets()
const selectedTicket = ref<UserTicket | null>(null)
const selectedGame = ref<UserTicketGame | null>(null)
const isLoading = ref(true)
const isHistoryView = computed(() => route.query.from === 'history')
const tabs = computed(() => [
  { label: 'งวดปัจจุบัน', to: '/tickets', active: !isHistoryView.value },
  { label: 'งวดย้อนหลัง', to: '/tickets/history', active: isHistoryView.value }
])
const requestedNumber = computed(() => {
  const value = Array.isArray(route.query.number) ? route.query.number[0] : route.query.number

  return value ? String(value) : ''
})
const requestedOrderId = computed(() => {
  const value = Array.isArray(route.query.order_id) ? route.query.order_id[0] : route.query.order_id

  return value ? String(value) : ''
})
const requestedGameId = computed(() => {
  const value = Array.isArray(route.query.game_id) ? route.query.game_id[0] : route.query.game_id

  return value ? String(value) : ''
})
const ticketNumber = computed(() => getTicketNumber(selectedTicket.value))
const ticketCount = computed(() => selectedTicket.value ? getTicketCount(selectedTicket.value) : 0)
const drawDate = computed(() => getGameDate(selectedGame.value) || currentDrawDate.value)
const ticketImageUrl = computed(() => getTicketImageUrl(selectedTicket.value))

const goBack = () => {
  if (process.client && window.history.length > 1) {
    router.back()
    return
  }

  navigateTo(isHistoryView.value ? '/tickets/history' : '/tickets')
}

onMounted(async () => {
  try {
    const response = await fetchTickets({
      gameId: requestedGameId.value || null,
      search: requestedNumber.value || undefined,
      perPage: 20
    })

    selectedGame.value = response.game
    selectedTicket.value = response.tickets.find((ticket) => {
      const sameNumber = getTicketNumber(ticket) === requestedNumber.value
      const sameOrder = !requestedOrderId.value || String(ticket.order_id || '') === requestedOrderId.value

      return sameNumber && sameOrder
    }) || (!requestedNumber.value ? response.tickets[0] || null : null)
  } catch (error) {
    console.log(error)
  } finally {
    isLoading.value = false
  }
})
</script>

<style scoped>
.ticket-image-preview {
  width: 100%;
  max-height: 420px;
  display: block;
  object-fit: contain;
  border-radius: 8px;
  background: #f5f7fb;
}
</style>

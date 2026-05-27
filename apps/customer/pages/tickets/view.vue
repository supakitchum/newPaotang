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
        :is-winning="isWinningTicket(selectedTicket)"
        :prize-title="getTicketPrizeTitle(selectedTicket)"
        :prize-amount="formatPrizeAmount(getTicketPrizeAmount(selectedTicket))"
        :claim-label="isTicketClaimable(selectedTicket) ? 'ขึ้นรางวัล' : 'ดูรางวัล'"
      />

      <div v-else class="empty-lottery-state">
        ไม่พบสลากฯ
      </div>
    </section>
    <TicketImageModal
      v-if="selectedTicket"
      :number="ticketNumber"
      :image-url="selectedTicket.image_url || ''"
      :image-thumb-url="selectedTicket.image_thumb_url || ''"
      :image-status="selectedTicket.image_status || ''"
      :image-error="selectedTicket.image_error || ''"
      @close="goBack"
    />
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
  getTicketStatusText,
  isWinningTicket,
  getTicketPrizeAmount,
  getTicketPrizeTitle,
  isTicketClaimable
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

const formatPrizeAmount = (amount: number) => {
  if (!Number.isFinite(amount) || amount <= 0) {
    return ''
  }

  return amount.toLocaleString('th-TH', {
    maximumFractionDigits: 0
  })
}

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

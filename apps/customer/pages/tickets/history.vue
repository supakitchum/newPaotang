<template>
  <MobileShell time="13:08" active-nav="tickets" show-bottom-nav>
    <BlueHeader title="สลากฯ ของฉัน" min-height="253px">
      <div class="mt-4">
        <SegmentTabs :tabs="tabs" />
      </div>
    </BlueHeader>

    <section class="content-sheet">
      <div class="d-flex align-items-center justify-content-between mb-3">
        <h1 class="section-title fs-5">รายการสลากฯ</h1>
        <button class="btn btn-link fw-bold p-0" type="button" @click="showOnlyWinning = !showOnlyWinning">
          <i class="bi bi-list-check me-2" />{{ showOnlyWinning ? 'ดูสลากฯ ทั้งหมด' : 'ดูสลากฯ ที่ถูกรางวัล' }}
        </button>
      </div>
      <hr>
      <div v-if="historyGame" class="d-flex justify-content-between align-items-center mb-3">
        <div>
          <div class="muted-text fw-semibold">สลากฯ งวดวันที่</div>
          <h2 class="fs-5 fw-bold">{{ drawDate }}</h2>
        </div>
        <button class="outline-pill"><i class="bi bi-share me-2" />แชร์ผลให้เพื่อนรู้</button>
      </div>

      <div v-if="tickets.length" class="rounded-3 p-3 mb-4 d-flex align-items-center justify-content-between" style="background:linear-gradient(110deg,#dfffe9,#fff6cf);">
        <div class="fs-5 fw-semibold text-success">{{ summaryText }}</div>
        <i class="bi bi-stars fs-1 text-warning" />
      </div>

      <div v-if="isLoading" class="empty-lottery-state">
        กำลังโหลดสลากฯ
      </div>

      <div v-else-if="loadError" class="empty-lottery-state text-danger">
        {{ loadError }}
      </div>

      <div v-else-if="visibleTickets.length" class="d-grid gap-3">
        <div
          v-for="(ticket, index) in visibleTickets"
          :key="getTicketKey(ticket, index)"
          class="ticket-card-button"
          role="button"
          tabindex="0"
          @click="openTicketModal(ticket)"
          @keydown.enter.prevent="openTicketModal(ticket)"
          @keydown.space.prevent="openTicketModal(ticket)"
        >
          <TicketStub
            :number="getTicketNumber(ticket)"
            :status="getTicketStatusText(ticket)"
            :is-winning="isWinningTicket(ticket)"
            :prize-title="getTicketPrizeTitle(ticket)"
            :prize-amount="formatPrizeAmount(getTicketPrizeAmount(ticket))"
            :prizes="getTicketRewardPrizes(ticket)"
            :claim-label="isTicketClaimable(ticket) ? 'ขึ้นรางวัล' : 'ดูรางวัล'"
            :claim-to="getTicketClaimTo(ticket)"
          />
        </div>
      </div>

      <div v-else-if="showOnlyWinning" class="empty-lottery-state">
        ไม่พบสลากฯ ที่ถูกรางวัลในงวดนี้
      </div>

      <div v-else class="empty-lottery-state">
        ยังไม่มีสลากฯ ย้อนหลัง
      </div>

      <div v-if="isLoadingMore" class="empty-lottery-state">
        กำลังโหลดเพิ่มเติม...
      </div>

      <div v-if="tickets.length && !hasMore && !isLoadingMore" class="text-center muted-text fw-medium mt-3">
        แสดงครบทั้งหมดแล้ว
      </div>

      <div ref="loadMoreSentinel" class="ticket-load-sentinel" />
    </section>
    <TicketImageModal
      v-if="selectedTicket"
      :number="getTicketNumber(selectedTicket)"
      :image-url="selectedTicket.image_url || ''"
      :image-thumb-url="selectedTicket.image_thumb_url || ''"
      :image-status="selectedTicket.image_status || ''"
      :image-error="selectedTicket.image_error || ''"
      @close="selectedTicket = null"
    />
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import type { UserTicket, UserTicketGame } from '~/composables/useUserTickets'

definePageMeta({
  requiresAuth: true
})

const tabs = [
  { label: 'งวดปัจจุบัน', to: '/tickets' },
  { label: 'งวดย้อนหลัง', to: '/tickets/history', active: true }
]
const {
  fetchTickets,
  getGameDate,
  getTicketGameDate,
  getTicketNumber,
  getTicketCount,
  getTicketStatusText,
  isWinningTicket,
  getTicketPrizeAmount,
  getTicketRewardPrizes,
  getTicketPrizeTitle,
  isTicketClaimable,
  getTicketClaimTo
} = useUserTickets()
const tickets = ref<UserTicket[]>([])
const historyGame = ref<UserTicketGame | null>(null)
const isLoading = ref(true)
const isLoadingMore = ref(false)
const loadError = ref('')
const showOnlyWinning = ref(false)
const currentPage = ref(1)
const lastPage = ref(1)
const perPage = 20
const selectedTicket = ref<UserTicket | null>(null)
const loadMoreSentinel = ref<HTMLElement | null>(null)
let loadObserver: IntersectionObserver | null = null
const drawDate = computed(() => getGameDate(historyGame.value) || getTicketGameDate(tickets.value[0]))
const winningTickets = computed(() => tickets.value.filter((ticket) => [4, 5].includes(Number(ticket.status))))
const visibleTickets = computed(() => showOnlyWinning.value ? winningTickets.value : tickets.value)
const hasMore = computed(() => currentPage.value < lastPage.value)
const summaryText = computed(() => {
  if (winningTickets.value.length > 0) {
    return `ยินดีด้วย คุณมีสลากฯ ถูกรางวัล ${winningTickets.value.reduce((total, ticket) => total + getTicketCount(ticket), 0)} ใบ`
  }

  return 'วันนี้อาจไม่ใช่วันของเรา เจอกันใหม่โอกาสหน้า'
})

const getTicketKey = (ticket: UserTicket, index: number) => (
  `${ticket.id || ticket.order_id || getTicketNumber(ticket)}-${index}`
)

const formatPrizeAmount = (amount: number) => {
  if (!Number.isFinite(amount) || amount <= 0) {
    return ''
  }

  return amount.toLocaleString('th-TH', {
    maximumFractionDigits: 0
  })
}

const openTicketModal = (ticket: UserTicket) => {
  selectedTicket.value = ticket
}

const fetchHistoryPage = async (page = 1) => {
  if (page === 1) {
    isLoading.value = true
  } else {
    isLoadingMore.value = true
  }

  loadError.value = ''

  try {
    const historyResponse = await fetchTickets({
      history: true,
      page,
      perPage
    })

    tickets.value = page === 1 ? historyResponse.tickets : [...tickets.value, ...historyResponse.tickets]
    historyGame.value = historyResponse.game || historyGame.value
    currentPage.value = historyResponse.pagination.currentPage
    lastPage.value = historyResponse.pagination.lastPage
  } catch (error: any) {
    console.log(error)
    loadError.value = error?.response?.data?.message || 'โหลดสลากฯ ย้อนหลังไม่สำเร็จ'
  } finally {
    isLoading.value = false
    isLoadingMore.value = false
  }
}

const loadNextPage = () => {
  if (!hasMore.value || isLoading.value || isLoadingMore.value || showOnlyWinning.value) {
    return
  }

  fetchHistoryPage(currentPage.value + 1)
}

const setupLoadObserver = async () => {
  await nextTick()

  if (!process.client || !loadMoreSentinel.value) {
    return
  }

  loadObserver?.disconnect()
  loadObserver = new IntersectionObserver((entries) => {
    if (entries.some((entry) => entry.isIntersecting)) {
      loadNextPage()
    }
  }, {
    rootMargin: '180px 0px'
  })
  loadObserver.observe(loadMoreSentinel.value)
}

onMounted(async () => {
  try {
    await fetchHistoryPage()
  } catch (error: any) {
    console.log(error)
    loadError.value = error?.response?.data?.message || 'โหลดสลากฯ ย้อนหลังไม่สำเร็จ'
  } finally {
    isLoading.value = false
  }

  setupLoadObserver()
})

onBeforeUnmount(() => {
  if (loadObserver) {
    loadObserver.disconnect()
  }
})
</script>

<style scoped>
.ticket-card-button {
  background: transparent;
  border: 0;
  color: inherit;
  cursor: pointer;
  display: block;
  padding: 0;
  text-align: left;
  width: 100%;
}

.ticket-card-button:focus-visible {
  border-radius: 14px;
  outline: 3px solid rgba(13, 110, 253, .35);
  outline-offset: 3px;
}

.ticket-load-sentinel {
  height: 1px;
}
</style>

<template>
  <MobileShell time="13:06" active-nav="tickets" show-bottom-nav>
    <BlueHeader title="สลากฯ ของฉัน" search-button min-height="253px" @search="toggleSearch">
      <div class="mt-4">
        <SegmentTabs :tabs="tabs" />
      </div>
    </BlueHeader>

    <section class="content-sheet">
      <form v-if="showSearch" class="ticket-search-form mb-3" @submit.prevent="applySearch">
        <i class="bi bi-search" />
        <input
          ref="searchInput"
          v-model="searchInputValue"
          inputmode="numeric"
          maxlength="6"
          placeholder="ค้นหาเลขสลากฯ ในคลังของฉัน"
          type="search"
        >
        <button v-if="searchInputValue" class="ticket-search-clear" type="button" aria-label="ล้างคำค้นหา" @click="clearSearch">
          <i class="bi bi-x-lg" />
        </button>
        <button class="ticket-search-submit" type="submit">ค้นหา</button>
      </form>

      <div class="mb-4">
        <div class="muted-text fw-semibold">สลากฯ งวดวันที่</div>
        <h2 class="fs-5 fw-bold mb-1">{{ drawDate }}</h2>
        <div class="muted-text fw-semibold">ทั้งหมด {{ totalTicketCount }} ใบ</div>
        <div v-if="activeSearch" class="muted-text fw-semibold">ผลการค้นหา “{{ activeSearch }}”</div>
      </div>

      <div v-if="winningTicketCount > 0" class="ticket-win-banner mb-3">
        <div>
          <strong>ยินดีด้วย!</strong>
          <span>คุณถูกรางวัล {{ winningTicketCountText }} ใบ</span>
        </div>
        <i class="bi bi-coin" />
      </div>

      <div v-if="isLoadingInitial" class="empty-lottery-state">
        กำลังโหลดสลากฯ
      </div>

      <div v-else-if="loadError" class="empty-lottery-state text-danger">
        {{ loadError }}
      </div>

      <div v-else-if="tickets.length" class="d-grid gap-3">
        <div
          v-for="(ticket, index) in displayTickets"
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

      <div v-else class="empty-lottery-state">
        {{ activeSearch ? 'ไม่พบเลขสลากฯ ที่ค้นหาในคลังของฉัน' : 'ยังไม่มีสลากฯ ในงวดนี้' }}
      </div>

      <div v-if="isLoadingMore" class="empty-lottery-state">
        กำลังโหลดเพิ่มเติม...
      </div>

      <div v-if="tickets.length && !hasMore && !isLoadingMore" class="text-center muted-text fw-medium mt-3">
        แสดงครบทั้งหมดแล้ว
      </div>

      <div ref="loadMoreSentinel" class="ticket-load-sentinel" />

      <p class="text-center muted-text fw-medium mt-4 px-4">
        เมนู ‘สลากฯ ของฉัน’ เป็นการบันทึกเลขสลากฯ หากถูกรางวัล ระบบจะแจ้งผลรางวัลในหน้านี้
      </p>
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
  { label: 'งวดปัจจุบัน', to: '/tickets', active: true },
  { label: 'งวดย้อนหลัง', to: '/tickets/history' }
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
  sortTicketsForCurrentDraw,
  getTicketClaimTo
} = useUserTickets()
const { currentDrawDate } = useAppInit()
const perPage = 20
const tickets = ref<UserTicket[]>([])
const currentGame = ref<UserTicketGame | null>(null)
const isLoadingInitial = ref(true)
const isLoadingMore = ref(false)
const loadError = ref('')
const currentPage = ref(1)
const lastPage = ref(1)
const apiTotalTicketCount = ref(0)
const showSearch = ref(false)
const searchInput = ref<HTMLInputElement | null>(null)
const searchInputValue = ref('')
const activeSearch = ref('')
const selectedTicket = ref<UserTicket | null>(null)
const loadMoreSentinel = ref<HTMLElement | null>(null)
let loadObserver: IntersectionObserver | null = null
const displayTickets = computed(() => sortTicketsForCurrentDraw(tickets.value))
const drawDate = computed(() => getGameDate(currentGame.value) || getTicketGameDate(displayTickets.value[0]) || currentDrawDate.value)
const loadedTicketCount = computed(() => tickets.value.reduce((total, ticket) => total + getTicketCount(ticket), 0))
const totalTicketCount = computed(() => apiTotalTicketCount.value || loadedTicketCount.value)
const hasMore = computed(() => currentPage.value < lastPage.value)
const winningTicketCount = computed(() => tickets.value.reduce((total, ticket) => (
  total + (isWinningTicket(ticket) ? getTicketCount(ticket) : 0)
), 0))
const winningTicketCountText = computed(() => winningTicketCount.value.toLocaleString('th-TH'))

const getTicketKey = (ticket: UserTicket, index: number) => (
  `${ticket.id || ticket.order_id || getTicketNumber(ticket)}-${index}`
)

const openTicketModal = (ticket: UserTicket) => {
  selectedTicket.value = ticket
}

const fetchTicketPage = async (page = 1) => {
  if (page === 1) {
    isLoadingInitial.value = true
  } else {
    isLoadingMore.value = true
  }

  loadError.value = ''

  try {
    const response = await fetchTickets({
      page,
      perPage,
      search: activeSearch.value
    })

    tickets.value = page === 1 ? response.tickets : [...tickets.value, ...response.tickets]
    currentGame.value = response.game
    currentPage.value = response.pagination.currentPage
    lastPage.value = response.pagination.lastPage
    apiTotalTicketCount.value = response.totalTicketCount
  } catch (error: any) {
    console.log(error)
    loadError.value = error?.response?.data?.message || 'โหลดสลากฯ ไม่สำเร็จ'
  } finally {
    isLoadingInitial.value = false
    isLoadingMore.value = false
  }
}

const loadNextPage = () => {
  if (!hasMore.value || isLoadingInitial.value || isLoadingMore.value) {
    return
  }

  fetchTicketPage(currentPage.value + 1)
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

const toggleSearch = async () => {
  showSearch.value = !showSearch.value

  if (showSearch.value) {
    await nextTick()
    searchInput.value?.focus()
  }
}

const applySearch = () => {
  const searchValue = searchInputValue.value.replace(/\D/g, '').slice(0, 6)

  searchInputValue.value = searchValue
  activeSearch.value = searchValue
  fetchTicketPage(1)
}

const clearSearch = () => {
  searchInputValue.value = ''
  activeSearch.value = ''
  fetchTicketPage(1)
}

const formatPrizeAmount = (amount: number) => {
  if (!Number.isFinite(amount) || amount <= 0) {
    return ''
  }

  return amount.toLocaleString('th-TH', {
    maximumFractionDigits: 0
  })
}

onMounted(async () => {
  await fetchTicketPage()
  setupLoadObserver()
})

onBeforeUnmount(() => {
  if (loadObserver) {
    loadObserver.disconnect()
  }
})
</script>

<style scoped>
.ticket-search-form {
  min-height: 48px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 0 14px;
  border: 1px solid #dbe4ef;
  border-radius: 12px;
  background: #f8fafc;
  color: #667085;
}

.ticket-search-form input {
  width: 100%;
  border: 0;
  background: transparent;
  color: #111827;
  font-size: 16px;
  font-weight: 600;
  outline: none;
}

.ticket-search-clear {
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 50%;
  background: #e8eef6;
  color: #344054;
}

.ticket-search-submit {
  min-height: 34px;
  flex: 0 0 auto;
  border: 0;
  border-radius: 999px;
  padding: 0 12px;
  background: #0b69dc;
  color: #fff;
  font-size: 14px;
  font-weight: 700;
}

.ticket-win-banner {
  min-height: 82px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 15px 18px;
  border-radius: 10px;
  background:
    radial-gradient(circle at 88% 18%, rgba(255, 255, 255, .7) 0 18px, transparent 19px),
    repeating-linear-gradient(135deg, rgba(255, 255, 255, .24) 0 8px, transparent 8px 22px),
    linear-gradient(105deg, #fff4bf 0%, #ffe28a 100%);
  color: #8b5c03;
  box-shadow: 0 8px 18px rgba(176, 121, 13, .12);
}

.ticket-win-banner div {
  display: grid;
  gap: 4px;
}

.ticket-win-banner strong {
  color: #a56800;
  font-size: 19px;
  font-weight: 900;
  line-height: 1.05;
}

.ticket-win-banner span {
  color: #7a5509;
  font-size: 13px;
  font-weight: 700;
}

.ticket-win-banner i {
  width: 56px;
  height: 56px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: rgba(255, 255, 255, .48);
  color: #f4a900;
  font-size: 32px;
}

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

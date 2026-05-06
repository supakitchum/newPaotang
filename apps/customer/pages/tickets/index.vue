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

      <div v-if="isLoadingInitial" class="empty-lottery-state">
        กำลังโหลดสลากฯ
      </div>

      <div v-else-if="loadError" class="empty-lottery-state text-danger">
        {{ loadError }}
      </div>

      <div v-else-if="tickets.length" class="d-grid gap-3">
        <NuxtLink
          v-for="(ticket, index) in tickets"
          :key="getTicketKey(ticket, index)"
          :to="{ path: '/tickets/view', query: getTicketQuery(ticket) }"
        >
          <TicketStub
            :number="getTicketNumber(ticket)"
            :draw="getTicketDraw(ticket, currentGame)"
            :set="getTicketSet(ticket)"
            :status="getTicketStatusText(ticket)"
          />
        </NuxtLink>
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
  getTicketNumber,
  getTicketCount,
  getTicketDraw,
  getTicketSet,
  getTicketStatusText
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
const loadMoreSentinel = ref<HTMLElement | null>(null)
let loadObserver: IntersectionObserver | null = null
const drawDate = computed(() => getGameDate(currentGame.value) || currentDrawDate.value)
const loadedTicketCount = computed(() => tickets.value.reduce((total, ticket) => total + getTicketCount(ticket), 0))
const totalTicketCount = computed(() => apiTotalTicketCount.value || loadedTicketCount.value)
const hasMore = computed(() => currentPage.value < lastPage.value)

const getTicketKey = (ticket: UserTicket, index: number) => (
  `${ticket.id || ticket.order_id || getTicketNumber(ticket)}-${index}`
)

const getTicketQuery = (ticket: UserTicket) => ({
  number: getTicketNumber(ticket),
  game_id: String(ticket.game_id || currentGame.value?.id || ''),
  order_id: ticket.order_id ? String(ticket.order_id) : undefined
})

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

.ticket-load-sentinel {
  height: 1px;
}
</style>

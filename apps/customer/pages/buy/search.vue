<template>
  <MobileShell time="13:13">
    <BlueHeader title="ซื้อสลากดิจิทัล" back-to="/buy"/>
    <section class="content-sheet">
      <div class="d-flex justify-content-between align-items-start mb-1">
        <h2 class="section-title">{{ searchTitle }}</h2>
        <button class="btn btn-link p-0 fw-semibold" type="button" @click="clearSearch">ล้างค่า</button>
      </div>
      <div class="fs-5">งวดวันที่ {{ displayDrawDate }}</div>
      <DigitBoxes :digits="searchDigits" filled @update:digits="handleDigitsUpdate"/>
      <button class="primary-pill d-block text-center py-3 mb-4 w-100" type="button" :disabled="isSearching"
              @click="search">
        {{ isSearching ? 'กำลังค้นหา' : 'ค้นหาเลข' }}
      </button>

      <hr>
      <div class="d-flex align-items-center justify-content-between gap-3 mb-3">
        <h2 class="section-title">ผลการค้นหาเลข</h2>
        <button class="outline-pill" type="button" :disabled="isSearching" @click="search"><i
            class="bi bi-arrow-clockwise me-1"/>แสดงเลขใหม่
        </button>
      </div>
      <FilterPills/>
      <LotteryItem
          v-for="(ticket, index) in lotteries"
          :key="ticketKey(ticket, index)"
          :ticket="ticket"
          @booking-unavailable="removeLottery"
      />
      <template v-if="showSkeletonItems">
        <LotteryItem
            v-for="item in skeletonItems"
            :key="`search-loading-${item}`"
            :ticket="skeletonTicket"
            loading
        />
      </template>
      <template v-if="isLoadingMore">
        <LotteryItem
            v-for="item in skeletonItems"
            :key="`search-loading-more-${item}`"
            :ticket="skeletonTicket"
            loading
        />
      </template>
      <div v-if="showEmptyState" class="empty-lottery-state">
        ไม่พบเลขสลากที่ค้นหา
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import {computed, onBeforeUnmount, onMounted, ref} from 'vue'

interface LotteryTicket {
  token?: string
  local_stock_item_id?: string
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
  remaining_count?: number | null
  availability_status?: string | null
  status?: string | null
  price?: number | string
  priceTrend?: 'up' | 'down' | null
  priceFlashKey?: number | null
}

interface SearchPagination {
  seed?: string
  page?: number
  current_page?: number
  total_page?: number
}

definePageMeta({
  alias: ['/search'],
  requiresAuth: false
})

const platformApi = usePlatformApi()
const route = useRoute()
const { currentDrawDate: displayDrawDate } = useAppInit()
const { applyPriceUpdateToTickets } = usePriceRealtimePatch()
const searchDigits = ref<string[]>(['', '', '', '', '', ''])
const lotteries = ref<LotteryTicket[]>([])
const pagination = ref<SearchPagination | null>(null)
const currentGameId = ref('')
const isSearching = ref(false)
const isLoadingMore = ref(false)
const hasSearched = ref(false)
let scrollContainer: HTMLElement | null = null

const skeletonItems = [1, 2, 3, 4, 5]
const skeletonTicket: LotteryTicket = {
  number: '000000'
}
const searchNumber = computed(() => searchDigits.value.map((digit) => digit || null))
const storeId = computed(() => {
  const value = Array.isArray(route.query.store_id) ? route.query.store_id[0] : route.query.store_id

  return value ? String(value) : ''
})
const isStoreSearch = computed(() => Boolean(storeId.value))
const searchTitle = computed(() => isStoreSearch.value ? 'ค้นหาเลขสลากฯในร้านค้า' : 'ค้นหาเลขเด็ด')
const currentPage = computed(() => pagination.value?.current_page ?? pagination.value?.page ?? 1)
const totalPage = computed(() => pagination.value?.total_page ?? 1)
const hasNextPage = computed(() => Boolean(pagination.value?.seed) && currentPage.value < totalPage.value)
const showSkeletonItems = computed(() => isSearching.value && lotteries.value.length === 0)
const showEmptyState = computed(() => hasSearched.value && !isSearching.value && !isLoadingMore.value && lotteries.value.length === 0)
useCustomerStockRealtime({
  gameId: currentGameId,
  enabled: computed(() => Boolean(currentGameId.value)),
  onAvailability: (payload) => applyAvailabilityUpdate(payload),
  onPrice: (payload) => applyPriceUpdateToTickets(lotteries, payload),
})

const handleDigitsUpdate = (digits: string[]) => {
  searchDigits.value = digits.slice(0, 6)
}

const buildSearchDigits = () => searchNumber.value.slice(0, 6)

const getTicketNumber = (ticket: Partial<LotteryTicket>) => {
  const value = ticket.number || ticket.full_number || ticket.lottery_number || ''

  return String(value)
}

const withHighlight = (ticket: LotteryTicket): LotteryTicket => ({
  ...ticket,
  number: getTicketNumber(ticket),
  highlightDigits: searchNumber.value
})

const updateSearchResult = (responseData: any, append = false) => {
  const result = responseData.result || {}
  const nextLotteries = (result.lotteries || []).map(withHighlight)

  lotteries.value = append ? [...lotteries.value, ...nextLotteries] : nextLotteries
  pagination.value = result.pagination || null
  currentGameId.value = String(result.game_id || currentGameId.value || '')
}

const applyAvailabilityUpdate = (payload: any) => {
  const fullNumber = String(payload?.full_number || '').replace(/\D/g, '').slice(0, 6)

  if (!fullNumber) {
    return
  }

  lotteries.value = lotteries.value.map((ticket) => (
    getTicketNumber(ticket) === fullNumber
      ? {
          ...ticket,
          remaining_count: Number(payload.remaining_count || 0),
          availability_status: payload.status || (Number(payload.remaining_count || 0) > 0 ? 'available' : 'sold_out'),
          status: payload.status || ticket.status
        }
      : ticket
  ))
}

const search = async () => {
  isSearching.value = true
  hasSearched.value = true
  lotteries.value = []
  pagination.value = null

  try {
    const response = await platformApi.searchStockLegacy({
      digits: buildSearchDigits(),
      storeId: storeId.value || undefined
    })

    if (response.data.code === 0) {
      updateSearchResult(response.data)
    }
  } catch (e) {
    console.log(e)
  } finally {
    isSearching.value = false
  }
}

const loadNextPage = async () => {
  if (isSearching.value || isLoadingMore.value || !hasNextPage.value) {
    return
  }

  isLoadingMore.value = true

  try {
    const response = await platformApi.searchStockLegacy({
      digits: buildSearchDigits(),
      storeId: storeId.value || undefined,
      cursor: pagination.value?.seed || null,
      page: currentPage.value + 1
    })

    if (response.data.code === 0) {
      updateSearchResult(response.data, true)
    }
  } catch (e) {
    console.log(e)
  } finally {
    isLoadingMore.value = false
  }
}

const handleScroll = () => {
  if (!scrollContainer) {
    return
  }

  const distanceFromBottom = scrollContainer.scrollHeight - scrollContainer.scrollTop - scrollContainer.clientHeight

  if (distanceFromBottom <= 180) {
    loadNextPage()
  }
}

const clearSearch = () => {
  searchDigits.value = ['', '', '', '', '', '']
  lotteries.value = []
  pagination.value = null
  hasSearched.value = false
}

const removeLottery = (ticket: LotteryTicket) => {
  lotteries.value = lotteries.value.filter((item) => {
    if (ticket.token) {
      return item.token !== ticket.token
    }

    return `${item.number}-${item.sort_order ?? item.set ?? ''}` !== `${ticket.number}-${ticket.sort_order ?? ticket.set ?? ''}`
  })
}

const ticketKey = (ticket: LotteryTicket, index: number) => String(ticket.token || ticket.local_stock_item_id || `${ticket.number}-${ticket.sort_order ?? ticket.set ?? index}`)

onMounted(() => {
  scrollContainer = document.querySelector('.app-scroll')
  scrollContainer?.addEventListener('scroll', handleScroll, {passive: true})
})

onBeforeUnmount(() => {
  scrollContainer?.removeEventListener('scroll', handleScroll)
})
</script>

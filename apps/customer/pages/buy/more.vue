<template>
  <MobileShell time="12:50">
    <BlueHeader min-height="142px" />
    <section class="content-sheet" style="margin-top:-24px">
      <div class="d-flex justify-content-between align-items-start mb-3">
        <div>
          <h1 class="section-title">รายการสลากฯ</h1>
          <div class="fs-5 mt-2">
            สลากฯ เลข <span class="text-primary fw-bold ms-2">{{ displayNumber }}</span>
          </div>
        </div>
        <button class="icon-back-button fs-1 text-dark" type="button" aria-label="กลับ" @click="goBack">
          <i class="bi bi-x" />
        </button>
      </div>
      <LotteryItem
        v-for="(ticket, index) in tickets"
        :key="ticketKey(ticket, index)"
        :ticket="ticket"
        @booking-unavailable="removeLottery"
      />
      <div v-if="showEmptyState" class="empty-lottery-state">
        ไม่พบสลาก
      </div>
      <template v-if="showSkeletonItems">
        <LotteryItem
          v-for="item in skeletonItems"
          :key="`more-loading-${item}`"
          :ticket="skeletonTicket"
          loading
        />
      </template>
      <template v-if="isLoadingMore">
        <LotteryItem
          v-for="item in skeletonItems"
          :key="`more-loading-more-${item}`"
          :ticket="skeletonTicket"
          loading
        />
      </template>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

interface MoreNumberTicket {
  token?: string
  local_stock_item_id?: string
  number: string
  full_number?: string
  lottery_number?: string
  set?: number | string
  sort_order?: number | string
  seller?: string
  store_name?: string
  draw?: number | string
  draw_no?: number | string
  game_no?: number | string
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

interface MorePagination {
  seed?: string
  page?: number
  current_page?: number
  total_page?: number
}

definePageMeta({
  requiresAuth: false
})

const route = useRoute()
const router = useRouter()
const platformApi = usePlatformApi()
const { applyPriceUpdateToTickets } = usePriceRealtimePatch()
const tickets = ref<MoreNumberTicket[]>([])
const pagination = ref<MorePagination | null>(null)
const currentGameId = ref('')
const isLoadingInitial = ref(false)
const isLoadingMore = ref(false)
let scrollContainer: HTMLElement | null = null

const skeletonItems = [1, 2, 3, 4, 5]
const skeletonTicket: MoreNumberTicket = {
  number: '000000'
}
const selectedNumber = computed(() => {
  const value = Array.isArray(route.query.number) ? route.query.number[0] : route.query.number

  return String(value || '').replace(/\D/g, '').slice(0, 6)
})
const displayNumber = computed(() => selectedNumber.value.split('').join(' '))
const currentPage = computed(() => pagination.value?.current_page ?? pagination.value?.page ?? 1)
const totalPage = computed(() => pagination.value?.total_page ?? 1)
const hasNextPage = computed(() => Boolean(pagination.value?.seed) && currentPage.value < totalPage.value)
const showSkeletonItems = computed(() => isLoadingInitial.value && tickets.value.length === 0)
const showEmptyState = computed(() => !isLoadingInitial.value && !isLoadingMore.value && tickets.value.length === 0)
useCustomerStockRealtime({
  gameId: currentGameId,
  onAvailability: (payload) => applyAvailabilityUpdate(payload),
  onPrice: (payload) => applyPriceUpdateToTickets(tickets, payload, { gameId: currentGameId }),
})

const goBack = () => {
  if (process.client && window.history.length > 1) {
    router.back()
    return
  }

  navigateTo('/buy')
}

const buildSearchPayload = () => {
  const number = selectedNumber.value
  const digits = number.split('')

  return {
    number,
    full_number: number,
    n1: digits[0] ?? null,
    n2: digits[1] ?? null,
    n3: digits[2] ?? null,
    n4: digits[3] ?? null,
    n5: digits[4] ?? null,
    n6: digits[5] ?? null
  }
}

const getTicketNumber = (ticket: Partial<MoreNumberTicket>) => {
  const value = ticket.number || ticket.full_number || ticket.lottery_number || ''

  return String(value)
}

const withHighlight = (ticket: MoreNumberTicket): MoreNumberTicket => ({
  ...ticket,
  number: getTicketNumber(ticket),
  highlightDigits: selectedNumber.value.split('')
})

const updateSearchResult = (responseData: any, append = false) => {
  const result = responseData.result || {}
  const nextTickets = (result.lotteries || []).map(withHighlight)

  tickets.value = append ? [...tickets.value, ...nextTickets] : nextTickets
  pagination.value = result.pagination || null
  currentGameId.value = String(result.game_id || currentGameId.value || '')
}

const applyAvailabilityUpdate = (payload: any) => {
  const fullNumber = String(payload?.full_number || '').replace(/\D/g, '').slice(0, 6)

  if (!fullNumber) {
    return
  }

  tickets.value = tickets.value.map((ticket) => (
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

const search = async (append = false) => {
  if (!selectedNumber.value) {
    tickets.value = []
    pagination.value = null
    return
  }

  const response = await platformApi.searchStockLegacy({
    number: String(buildSearchPayload().full_number || ''),
    cursor: append ? pagination.value?.seed || null : null,
    page: append ? currentPage.value + 1 : 1
  })

  if (response.data.code === 0) {
    updateSearchResult(response.data, append)
  }
}

const loadNextPage = async () => {
  if (isLoadingInitial.value || isLoadingMore.value || !hasNextPage.value) {
    return
  }

  isLoadingMore.value = true

  try {
    await search(true)
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

const removeLottery = (ticket: MoreNumberTicket) => {
  tickets.value = tickets.value.filter((item) => {
    if (ticket.token) {
      return item.token !== ticket.token
    }

    return `${item.number}-${item.sort_order ?? item.set ?? ''}` !== `${ticket.number}-${ticket.sort_order ?? ticket.set ?? ''}`
  })
}

const ticketKey = (ticket: MoreNumberTicket, index: number) => String(ticket.token || ticket.local_stock_item_id || `${ticket.number}-${ticket.sort_order ?? ticket.set ?? index}`)

onMounted(async () => {
  isLoadingInitial.value = true

  try {
    await search()
  } catch (e) {
    console.log(e)
  } finally {
    isLoadingInitial.value = false
  }

  scrollContainer = document.querySelector('.app-scroll')
  scrollContainer?.addEventListener('scroll', handleScroll, { passive: true })
})

onBeforeUnmount(() => {
  scrollContainer?.removeEventListener('scroll', handleScroll)
})
</script>

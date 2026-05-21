<template>
  <MobileShell time="12:54">
    <BlueHeader title="ร้านสลากหกหลักแบบดิจิทัล" back-to="/stores" min-height="312px">
      <div class="store-hero-card d-flex align-items-center gap-3 p-3 mt-4">
        <span class="store-icon position-relative" style="width:54px;height:54px">
          <i class="bi bi-shop" />
          <span class="position-absolute rounded-circle bg-success border border-white" style="width:10px;height:10px;right:4px;bottom:2px" />
        </span>
        <div class="fw-bold fs-5 flex-grow-1 text-dark">{{ storeName }}</div>
        <i class="bi bi-heart fs-3 text-secondary" />
      </div>
    </BlueHeader>

    <section class="content-sheet">
      <h2 class="section-title mb-1">ค้นหาเลขสลากฯ ในร้านค้า</h2>
      <div class="fs-5">{{ drawDate }}</div>
      <DigitBoxes :digits="emptyDigits" />
      <hr>
      <div class="d-flex align-items-center justify-content-between gap-3 mb-3">
        <h2 class="section-title">เลขสลากดิจิทัล</h2>
        <button class="outline-pill" type="button" :disabled="isRefreshDisabled" @click="handleRefresh">
          <i class="bi bi-arrow-clockwise me-1" />
          {{ refreshButtonText }}
        </button>
      </div>
      <LotteryItem
        v-for="(ticket, index) in lotteries"
        :key="`${ticket.number}-${ticket.sort_order ?? ticket.set ?? index}`"
        :ticket="ticket"
        @booking-unavailable="removeLottery"
      />
      <template v-if="showSkeletonItems">
        <LotteryItem
          v-for="item in skeletonItems"
          :key="`store-lotteries-loading-${item}`"
          :ticket="skeletonTicket"
          loading
        />
      </template>
      <template v-if="isLoadingMore">
        <LotteryItem
          v-for="item in skeletonItems"
          :key="`store-lotteries-loading-more-${item}`"
          :ticket="skeletonTicket"
          loading
        />
      </template>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

interface StoreLotteryTicket {
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
  remaining_count?: number | null
  availability_status?: string | null
  status?: string | null
  price?: number | string
  priceTrend?: 'up' | 'down' | null
  priceFlashKey?: number | null
}

interface StoreLotteryPagination {
  seed?: string
  page?: number
  current_page?: number
  total_page?: number
}

definePageMeta({
  requiresAuth: false
})

const route = useRoute()
const platformApi = usePlatformApi()
const { currentDrawDate: drawDate } = useAppInit()
const { applyPriceUpdateToTickets } = usePriceRealtimePatch()
const lotteries = ref<StoreLotteryTicket[]>([])
const storeName = ref('ร้านสลากฯ')
const pagination = ref<StoreLotteryPagination | null>(null)
const currentGameId = ref('')
const isLoadingInitial = ref(false)
const isRefreshing = ref(false)
const isLoadingMore = ref(false)
const cooldownSeconds = ref(0)
let cooldownTimer: ReturnType<typeof setInterval> | null = null
let scrollContainer: HTMLElement | null = null

const emptyDigits = ['', '', '', '', '', '']
const skeletonItems = [1, 2, 3, 4, 5]
const skeletonTicket: StoreLotteryTicket = {
  number: '000000'
}
const storeId = computed(() => {
  const value = Array.isArray(route.query.store_id) ? route.query.store_id[0] : route.query.store_id

  return value ? String(value) : ''
})
const isRefreshDisabled = computed(() => isRefreshing.value || cooldownSeconds.value > 0)
const currentPage = computed(() => pagination.value?.current_page ?? pagination.value?.page ?? 1)
const totalPage = computed(() => pagination.value?.total_page ?? 1)
const hasNextPage = computed(() => Boolean(pagination.value?.seed) && currentPage.value < totalPage.value)
const showSkeletonItems = computed(() => (isLoadingInitial.value || isRefreshing.value) && lotteries.value.length === 0)
const refreshButtonText = computed(() => {
  if (isRefreshing.value) {
    return 'กำลังโหลด'
  }

  if (cooldownSeconds.value > 0) {
    return `รอ ${cooldownSeconds.value} วิ`
  }

  return 'แสดงเลขใหม่'
})
useCustomerStockRealtime({
  gameId: currentGameId,
  enabled: computed(() => Boolean(currentGameId.value)),
  onAvailability: (payload) => applyAvailabilityUpdate(payload),
  onPrice: (payload) => applyPriceUpdateToTickets(lotteries, payload),
})

const startCooldown = () => {
  cooldownSeconds.value = 10

  if (cooldownTimer) {
    clearInterval(cooldownTimer)
  }

  cooldownTimer = setInterval(() => {
    cooldownSeconds.value -= 1

    if (cooldownSeconds.value <= 0 && cooldownTimer) {
      clearInterval(cooldownTimer)
      cooldownTimer = null
    }
  }, 1000)
}

const buildPostData = () => ({
  n1: null,
  n2: null,
  n3: null,
  n4: null,
  n5: null,
  n6: null,
  store_id: storeId.value
})

const getTicketNumber = (ticket: Partial<StoreLotteryTicket>) => {
  const value = ticket.number || ticket.full_number || ticket.lottery_number || ''

  return String(value)
}

const withHighlight = (ticket: StoreLotteryTicket): StoreLotteryTicket => ({
  ...ticket,
  number: getTicketNumber(ticket),
  highlightDigits: [null, null, null, null, null, null]
})

async function getData(options: { append?: boolean } = {}) {
  try {
    const response = await platformApi.searchStockLegacy({
      storeId: String(buildPostData().store_id || ''),
      mode: 'browse',
      cursor: options.append ? pagination.value?.seed || null : null,
      page: options.append ? currentPage.value + 1 : 1
    })

    if (response.data.code === 0) {
      const nextPagination = response.data.result.pagination || {}
      const nextLotteries = (response.data.result.lotteries || []).map(withHighlight)
      lotteries.value = options.append ? [...lotteries.value, ...nextLotteries] : nextLotteries
      storeName.value = response.data.result.seller?.name || storeName.value
      currentGameId.value = String(response.data.result.game_id || currentGameId.value || '')
      pagination.value = nextPagination
    }
  } catch (e) {
    console.log(e)
  }
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

const loadNextPage = async () => {
  if (isRefreshing.value || isLoadingMore.value || !hasNextPage.value) {
    return
  }

  isLoadingMore.value = true
  await getData({ append: true })
  isLoadingMore.value = false
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

const handleRefresh = async () => {
  if (isRefreshDisabled.value) {
    return
  }

  isRefreshing.value = true
  pagination.value = null
  lotteries.value = []
  await getData()
  isRefreshing.value = false
  startCooldown()
}

const removeLottery = (ticket: StoreLotteryTicket) => {
  lotteries.value = lotteries.value.filter((item) => {
    if (ticket.token) {
      return item.token !== ticket.token
    }

    return `${item.number}-${item.sort_order ?? item.set ?? ''}` !== `${ticket.number}-${ticket.sort_order ?? ticket.set ?? ''}`
  })
}

onMounted(async () => {
  isLoadingInitial.value = true
  await getData()
  isLoadingInitial.value = false
  scrollContainer = document.querySelector('.app-scroll')
  scrollContainer?.addEventListener('scroll', handleScroll, { passive: true })
})

onBeforeUnmount(() => {
  if (cooldownTimer) {
    clearInterval(cooldownTimer)
  }

  scrollContainer?.removeEventListener('scroll', handleScroll)
})
</script>

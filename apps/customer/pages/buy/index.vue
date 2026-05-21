<template>
  <MobileShell time="12:43">
    <BlueHeader title="ซื้อสลากดิจิทัล" back-to="/" min-height="258px">
      <div class="mt-4">
        <SegmentTabs :tabs="tabs"/>
      </div>
    </BlueHeader>

    <section class="content-sheet">
      <h2 class="section-title mb-1">ค้นหาเลขเด็ด</h2>
      <div class="fs-5">งวดวันที่ {{ drawDate }}</div>
      <DigitBoxes :digits="emptyDigits"/>

      <hr>

      <div class="d-flex align-items-center justify-content-between gap-3 mb-3">
        <h2 class="section-title">เลขสลากดิจิทัล</h2>
        <button class="outline-pill" type="button" :disabled="isRefreshDisabled" @click="handleRefresh">
          <i class="bi bi-arrow-clockwise me-1"/>
          {{ refreshButtonText }}
        </button>
      </div>
      <FilterPills class="mb-2"/>

      <div v-if="!canBuyLottery" class="buy-status-alert mb-3">
        <i class="bi bi-exclamation-circle"/>
        <span>ขณะนี้ไม่สามารถซื้อสลากได้</span>
      </div>

      <LotteryItem
        v-for="(ticket, index) in lotteries"
        :key="ticketKey(ticket, index)"
        :ticket="ticket"
        :show-image="false"
        :booking-disabled="!canBuyLottery"
        @booking-unavailable="removeLottery"
      />
      <template v-if="showSkeletonItems">
        <LotteryItem
          v-for="item in skeletonItems"
          :key="`buy-loading-${item}`"
          :ticket="skeletonTicket"
          loading
        />
      </template>
      <template v-if="isLoadingMore">
        <LotteryItem
          v-for="item in skeletonItems"
          :key="`buy-loading-more-${item}`"
          :ticket="skeletonTicket"
          loading
        />
      </template>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

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
  remaining_count?: number | null
  availability_status?: string | null
  status?: string | null
  price?: number | string
  priceTrend?: 'up' | 'down' | null
  priceFlashKey?: number | null
}

const platformApi = usePlatformApi()
const { clearAuthToken } = useAuth()
const { currentDrawDate: drawDate, currentGame } = useAppInit()
const { applyPriceUpdateToTickets } = usePriceRealtimePatch()
const lotteries = useState<LotteryTicket[]>('buy_browse_lotteries', () => [])
const seed = useState<string | null>('buy_browse_seed', () => null)
const nextCursor = useState<string | null>('buy_browse_next_cursor', () => null)
const currentGameId = useState<string>('buy_browse_game_id', () => '')
const cachedScrollTop = useState<number>('buy_browse_scroll_top', () => 0)
const isLoadingInitial = ref(false)
const isRefreshing = ref(false)
const isLoadingMore = ref(false)
const cooldownSeconds = ref(0)
const canBuyLottery = useState<boolean>('buy_browse_can_buy', () => true)
let cooldownTimer: ReturnType<typeof setInterval> | null = null
let scrollContainer: HTMLElement | null = null

definePageMeta({
  requiresAuth: false
})

const tabs = [
  {label: 'สลากฯ ทั้งหมด', to: '/buy', active: true},
  {label: 'ร้านค้า', to: '/stores'}
]
const emptyDigits = ['', '', '', '', '', '']
const skeletonItems = [1, 2, 3, 4, 5]
const skeletonTicket: LotteryTicket = {
  number: '000000'
}
const isRefreshDisabled = computed(() => isRefreshing.value || cooldownSeconds.value > 0)
const hasNextPage = computed(() => Boolean(nextCursor.value))
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

const currentAppGameId = computed(() => String(currentGame.value?.id || ''))
const hasReusableBrowseState = computed(() => lotteries.value.length > 0 && (!currentAppGameId.value || !currentGameId.value || currentGameId.value === currentAppGameId.value))

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

async function getData(options: { append?: boolean, cursor?: string | null } = {}) {
  try {
    const response = await platformApi.searchStockLegacy({
      mode: 'random',
      cursor: options.cursor || seed.value
    })
    if (response.data.code === 0) {
      const result = response.data.result || {}
      const pagination = response.data.result.pagination || {}
      const nextLotteries = response.data.result.lotteries || []
      currentGameId.value = String(result.game_id || currentGameId.value || '')
      canBuyLottery.value = result.bet_status !== 0
      lotteries.value = options.append ? [...lotteries.value, ...nextLotteries] : nextLotteries
      seed.value = pagination.seed || seed.value
      nextCursor.value = pagination.next_cursor || null
    }
  } catch (e) {
    const status = (e as { response?: { status?: number } }).response?.status

    if (status === 401) {
      clearAuthToken()
      seed.value = null
      nextCursor.value = null
    }

    console.log(e)
  }
}

const ticketFullNumber = (ticket: Partial<LotteryTicket>) => String(ticket.full_number || ticket.number || '').replace(/\D/g, '').slice(0, 6)

const applyAvailabilityUpdate = (payload: any) => {
  const fullNumber = String(payload?.full_number || '').replace(/\D/g, '').slice(0, 6)

  if (!fullNumber) {
    return
  }

  lotteries.value = lotteries.value.map((ticket) => (
    ticketFullNumber(ticket) === fullNumber
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
  await getData({ append: true, cursor: nextCursor.value })
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
  seed.value = null
  nextCursor.value = null
  cachedScrollTop.value = 0
  lotteries.value = []
  await getData()
  isRefreshing.value = false
  startCooldown()
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

onMounted(async () => {
  if (!hasReusableBrowseState.value) {
    isLoadingInitial.value = true
    seed.value = null
    nextCursor.value = null
    lotteries.value = []
    await getData()
    isLoadingInitial.value = false
  }

  scrollContainer = document.querySelector('.app-scroll')
  scrollContainer?.addEventListener('scroll', handleScroll, { passive: true })
  requestAnimationFrame(() => {
    if (scrollContainer && cachedScrollTop.value > 0) {
      scrollContainer.scrollTop = cachedScrollTop.value
    }
  })
})

onBeforeUnmount(() => {
  if (scrollContainer) {
    cachedScrollTop.value = scrollContainer.scrollTop
  }

  if (cooldownTimer) {
    clearInterval(cooldownTimer)
  }

  scrollContainer?.removeEventListener('scroll', handleScroll)
})
</script>

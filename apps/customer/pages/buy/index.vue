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
        :key="`${ticket.number}-${ticket.sort_order ?? ticket.set ?? index}`"
        :ticket="ticket"
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
  number: string
  seller?: string
  store_name?: string
  draw?: number | string
  draw_no?: number | string
  game_no?: number | string
  set?: number | string
  sort_order?: number | string
  selected?: boolean
  highlight?: string
}

const axios = useAxios()
const { isAuthenticated, clearAuthToken } = useAuth()
const { currentDrawDate: drawDate } = useAppInit()
const lotteries = ref<LotteryTicket[]>([])
const seed = ref<string | null>(null)
const nextCursor = ref<string | null>(null)
const isLoadingInitial = ref(false)
const isRefreshing = ref(false)
const isLoadingMore = ref(false)
const cooldownSeconds = ref(0)
const canBuyLottery = ref(true)
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
    const params: Record<string, string> = {}
    const endpoint = isAuthenticated.value ? '/stores' : '/lotteries/guest'

    if (seed.value) {
      params.seed = seed.value
    }

    if (options.cursor) {
      params.cursor = options.cursor
    }

    const response = await axios.get(endpoint, { params })
    if (response.data.code === 0) {
      const result = response.data.result || {}
      const pagination = response.data.result.pagination || {}
      const nextLotteries = response.data.result.lotteries || []
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

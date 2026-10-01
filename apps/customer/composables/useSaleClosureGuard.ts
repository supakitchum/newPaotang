import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { CartLottery } from '~/composables/useCart'

const WAITING_RESULT_PATH = '/waiting-result'
const SALE_CLOSED_NOTICE_QUERY = 'sale_closed'

const parseTimestampMs = (value: unknown) => {
  if (!value) {
    return null
  }

  if (typeof value === 'number') {
    return value < 1000000000000 ? value * 1000 : value
  }

  const numericValue = Number(value)

  if (Number.isFinite(numericValue)) {
    return numericValue < 1000000000000 ? numericValue * 1000 : numericValue
  }

  const dateValue = Date.parse(String(value))

  return Number.isNaN(dateValue) ? null : dateValue
}

const reservationIdsFromCart = (items: CartLottery[]) => Array.from(new Set(items.flatMap((item) => [
  item.reservation_id,
  ...(Array.isArray(item.reservation_ids) ? item.reservation_ids : [])
])
  .map((value) => String(value ?? '').trim())
  .filter(Boolean)))

const isBuyOrSearchRoute = (path: string) => (
  path === '/search' ||
  path === '/buy' ||
  path.startsWith('/buy/')
)

export const useSaleClosureGuard = () => {
  if (!process.client) {
    return
  }

  const route = useRoute()
  const platformApi = usePlatformApi()
  const { showAlert } = useAppAlert()
  const {
    currentGame,
    currentStatus,
    hasActiveCart,
    saleCloseAt,
    refreshAppInit,
    getInitRedirectTarget
  } = useAppInit()
  const { items, hasItems, isExpired, clearCart } = useCart()
  const now = useState<number>('sale_closure_guard_now', () => Date.now())
  const lastCloseRefreshKey = useState<string | null>('sale_closure_last_refresh_key', () => null)
  const lastReleasedCartKey = useState<string | null>('sale_closure_last_released_cart_key', () => null)
  const isRefreshingClosedSale = ref(false)
  const isReleasingExpiredCart = ref(false)
  let tickTimer: ReturnType<typeof setInterval> | null = null

  const closeRefreshKey = computed(() => {
    const closeAt = saleCloseAt.value

    return closeAt ? `${currentGame.value?.id || 'game'}:${closeAt}` : ''
  })
  const shouldRefreshClosedSale = computed(() => {
    const closeAt = saleCloseAt.value

    return Boolean(closeAt && now.value >= closeAt && lastCloseRefreshKey.value !== closeRefreshKey.value)
  })
  const saleClosed = computed(() => (
    currentStatus.value !== 1 ||
    (saleCloseAt.value !== null && now.value >= saleCloseAt.value)
  ))
  const waitingForResult = computed(() => saleClosed.value && currentStatus.value !== 2)
  const cartReleaseKey = computed(() => {
    const reservationIds = reservationIdsFromCart(items.value)

    if (reservationIds.length > 0) {
      return reservationIds.join('|')
    }

    return items.value.map((item) => `${item.game_id || ''}:${item.number}`).join('|')
  })

  const redirectForSaleState = async () => {
    const sourcePath = route.path
    const redirectTarget = getInitRedirectTarget(sourcePath)

    if (redirectTarget && redirectTarget !== route.path) {
      if (redirectTarget === WAITING_RESULT_PATH && isBuyOrSearchRoute(sourcePath)) {
        await navigateTo({
          path: WAITING_RESULT_PATH,
          query: {
            [SALE_CLOSED_NOTICE_QUERY]: '1'
          }
        })
        return
      }

      await navigateTo(redirectTarget)
    }
  }

  const refreshClosedSaleOnce = async () => {
    if (!shouldRefreshClosedSale.value || isRefreshingClosedSale.value || !closeRefreshKey.value) {
      return
    }

    lastCloseRefreshKey.value = closeRefreshKey.value
    isRefreshingClosedSale.value = true

    try {
      await refreshAppInit()
    } finally {
      isRefreshingClosedSale.value = false
    }
  }

  const releaseExpiredCart = async () => {
    const releaseKey = cartReleaseKey.value

    if (!releaseKey || isReleasingExpiredCart.value || lastReleasedCartKey.value === releaseKey) {
      return
    }

    lastReleasedCartKey.value = releaseKey
    isReleasingExpiredCart.value = true

    const reservationIds = reservationIdsFromCart(items.value)

    try {
      await Promise.allSettled(reservationIds.map((reservationId) => (
        platformApi.releaseReservationLegacy({ reservation_id: reservationId })
      )))
      await refreshAppInit()
    } finally {
      clearCart()
      isReleasingExpiredCart.value = false
    }

    showAlert({
      title: 'หมดเวลาชำระเงิน',
      message: 'ระบบยกเลิกการจองสลากในตะกร้านี้แล้ว',
      variant: 'warning'
    })

    if (waitingForResult.value || route.path === '/cart' || route.path === '/checkout') {
      await navigateTo(waitingForResult.value ? WAITING_RESULT_PATH : '/buy')
    }
  }

  const handleSaleState = async () => {
    now.value = Date.now()

    await refreshClosedSaleOnce()

    await redirectForSaleState()

    if (hasItems.value && isExpired.value) {
      await releaseExpiredCart()
    }
  }

  watch(
    () => [waitingForResult.value, hasActiveCart.value, route.path],
    () => {
      void handleSaleState()
    }
  )

  watch(
    () => isExpired.value,
    (expired) => {
      if (expired) {
        void releaseExpiredCart()
      }
    },
    { immediate: true }
  )

  onMounted(() => {
    void handleSaleState()
    tickTimer = setInterval(() => {
      void handleSaleState()
    }, 1000)
  })

  onBeforeUnmount(() => {
    if (tickTimer) {
      clearInterval(tickTimer)
    }
  })
}

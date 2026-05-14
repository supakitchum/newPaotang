import { computed } from 'vue'
import type { CartLottery } from '~/composables/useCart'
import { toSerializableError, type SerializableError } from '~/utils/serializableError'
import { formatDrawDateText } from '~/utils/formatDrawDate'

export const APP_INIT_TTL_MS = 60 * 1000

export interface AppInitGame {
  id?: number | string
  name?: string
  status?: number | string
  start_at?: string
  end_at?: string
  [key: string]: unknown
}

export interface AppInitOrder {
  id?: number | string
  lotteries?: CartLottery[]
  exp?: string | number | null
  created_at?: string
  updated_at?: string
  status?: number | string
  [key: string]: unknown
}

export interface AppInitData {
  status: number
  game: AppInitGame | null
  carts?: CartLottery[] | AppInitOrder | null
  cart_order?: AppInitOrder | null
  orders?: AppInitOrder | AppInitOrder[] | null
  order?: AppInitOrder | AppInitOrder[] | null
  waiting?: AppInitOrder | AppInitOrder[] | null
  [key: string]: unknown
}

let initFetchPromise: Promise<AppInitData | null> | null = null
let initFetchVersion = 0

const addMinutes = (value: unknown, minutes: number) => {
  if (!value) {
    return null
  }

  const timestamp = Date.parse(String(value))

  if (Number.isNaN(timestamp)) {
    return null
  }

  return new Date(timestamp + minutes * 60 * 1000).toISOString()
}

const getTicketNumber = (ticket: Partial<CartLottery>) => {
  const value = ticket.number || ticket.full_number || ticket.lottery_number || ''

  return String(value)
}

const isFilledValue = (value: unknown) => {
  if (Array.isArray(value)) {
    return value.length > 0
  }

  return Boolean(value && typeof value === 'object' && Object.keys(value as Record<string, unknown>).length > 0)
}

const normalizeTicket = (ticket: any): CartLottery => ({
  ...ticket,
  number: getTicketNumber(ticket),
  selected: true
})

const extractOrder = (value: unknown): AppInitOrder | null => {
  if (Array.isArray(value)) {
    return (value.find((item) => isFilledValue(item)) as AppInitOrder | undefined) || null
  }

  if (isFilledValue(value)) {
    return value as AppInitOrder
  }

  return null
}

const extractCartItems = (data: AppInitData | null) => {
  if (!data) {
    return []
  }

  const carts = data.carts

  if (Array.isArray(carts) && carts.length > 0) {
    if (carts.some((item) => Array.isArray((item as AppInitOrder).lotteries))) {
      return carts
        .flatMap((item) => (item as AppInitOrder).lotteries || [])
        .map(normalizeTicket)
        .filter((ticket) => ticket.number)
    }

    return carts.map(normalizeTicket).filter((ticket) => ticket.number)
  }

  const cartOrder = extractOrder(carts) || extractOrder(data.cart_order) || extractOrder(data.orders) || extractOrder(data.order) || extractOrder(data.waiting)
  const lotteries = Array.isArray(cartOrder?.lotteries) ? cartOrder.lotteries : []

  return lotteries.map(normalizeTicket).filter((ticket) => ticket.number)
}

const extractCartExp = (data: AppInitData | null) => {
  const cartOrder = extractOrder(data?.cart_order) || extractOrder(data?.orders) || extractOrder(data?.order) || extractOrder(data?.carts) || extractOrder(data?.waiting)

  return cartOrder?.exp || addMinutes(cartOrder?.created_at, 15)
}

const normalizeInitData = (responseData: any): AppInitData => {
  const result = responseData?.result || responseData || {}

  return {
    ...result,
    status: Number(result.status ?? 0),
    game: result.game || null,
    carts: result.carts || [],
    waiting: result.waiting || []
  }
}

const isSaleRoute = (path: string) => (
  path === '/' ||
  path === '/search' ||
  path === '/buy' ||
  path.startsWith('/buy/') ||
  path === '/stores' ||
  path.startsWith('/stores/')
)

const isCartOrPaymentRoute = (path: string) => (
  path === '/cart' ||
  path === '/checkout' ||
  path === '/topup'
)

export const useAppInit = () => {
  const data = useState<AppInitData | null>('app_init_data', () => null)
  const expiresAt = useState<number>('app_init_expires_at', () => 0)
  const fetchedAt = useState<number>('app_init_fetched_at', () => 0)
  const isLoading = useState<boolean>('app_init_loading', () => false)
  const isReady = useState<boolean>('app_init_ready', () => false)
  const error = useState<SerializableError | null>('app_init_error', () => null)
  const platformApi = usePlatformApi()
  const { items, setCartItems } = useCart()

  const currentGame = computed(() => data.value?.game || null)
  const currentStatus = computed(() => Number(data.value?.status ?? 0))
  const currentDrawDate = computed(() => formatDrawDateText(currentGame.value?.name))
  const waiting = computed(() => data.value?.waiting || [])
  const hasWaiting = computed(() => isFilledValue(waiting.value))
  const isExpired = () => !data.value || Date.now() >= expiresAt.value

  const applyCartFromInit = (initData: AppInitData | null, options: { replaceCart?: boolean } = {}) => {
    if (!options.replaceCart && items.value.length > 0) {
      return
    }

    const cartItems = extractCartItems(initData)

    if (cartItems.length === 0) {
      if (options.replaceCart) {
        setCartItems([])
      }

      return
    }

    setCartItems(cartItems, extractCartExp(initData))
  }

  const fetchAppInit = async (options: { force?: boolean, token?: string | null } = {}) => {
    if (!options.force && initFetchPromise) {
      return initFetchPromise
    }

    const requestVersion = ++initFetchVersion
    const requestPromise = (async () => {
      isLoading.value = true
      error.value = null

      try {
        const nextData = normalizeInitData(await platformApi.loadAppInit())
        const now = Date.now()

        if (requestVersion === initFetchVersion) {
          data.value = nextData
          fetchedAt.value = now
          expiresAt.value = now + APP_INIT_TTL_MS
          applyCartFromInit(nextData, {
            replaceCart: options.force
          })
        }

        return nextData
      } catch (e) {
        if (requestVersion === initFetchVersion) {
          error.value = toSerializableError(e)
        }

        return data.value
      } finally {
        if (requestVersion === initFetchVersion) {
          isLoading.value = false
          isReady.value = true
        }

        if (initFetchPromise === requestPromise) {
          initFetchPromise = null
        }
      }
    })()

    if (!options.force) {
      initFetchPromise = requestPromise
    }

    return requestPromise
  }

  const ensureAppInit = async () => {
    if (!isExpired()) {
      applyCartFromInit(data.value)
      isReady.value = true
      return data.value
    }

    return fetchAppInit()
  }

  const refreshAppInit = (token?: string | null) => fetchAppInit({ force: true, token })

  const getInitRedirectTarget = (path: string) => {
    if (!data.value) {
      return null
    }

    const status = currentStatus.value

    if (path === '/countdown' && status !== 3) {
      return status === 1 ? '/buy' : '/result'
    }

    if (status === 2 && (isSaleRoute(path) || isCartOrPaymentRoute(path))) {
      return '/result'
    }

    if (status === 3 && (isSaleRoute(path) || isCartOrPaymentRoute(path))) {
      return '/countdown'
    }

    if (status === 0 && isSaleRoute(path)) {
      return '/result'
    }

    return null
  }

  return {
    data,
    currentGame,
    currentStatus,
    currentDrawDate,
    waiting,
    hasWaiting,
    expiresAt,
    fetchedAt,
    isLoading,
    isReady,
    error,
    ensureAppInit,
    refreshAppInit,
    getInitRedirectTarget
  }
}

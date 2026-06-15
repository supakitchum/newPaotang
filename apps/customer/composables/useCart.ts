import { computed } from 'vue'
import { ticketPrice } from '~/data/lottery'

export interface CartLottery {
  id?: string | number
  token?: string
  number: string
  full_number?: string
  lottery_number?: string
  local_stock_item_id?: string | number
  local_stock_item_ids?: Array<string | number>
  stock_ref?: string | number
  reservation_id?: string | number
  reservation_ids?: Array<string | number>
  reservation_expires_at?: string | number | null
  server_time?: string | number | null
  order_id?: string | number
  game_id?: string | number
  count?: number | string
  group_count?: number | string
  group_items?: CartLottery[]
  price?: number | string
  seller?: string
  store_name?: string
  draw?: number | string
  draw_no?: number | string
  game_no?: number | string
  set?: number | string
  sort_order?: number | string
  selected?: boolean
  highlight?: string | null
  highlightDigits?: Array<string | null> | null
  priceTrend?: 'up' | 'down' | null
  priceFlashKey?: number | null
  image?: string | null
  image_url?: string | null
  image_thumb_url?: string | null
  image_status?: string | null
  image_error?: string | null
  remaining_count?: number | null
  availability_status?: string | null
  status?: string | null
}

let timerInterval: ReturnType<typeof setInterval> | null = null

const parseExpTime = (exp: string | number | null) => {
  if (!exp) {
    return null
  }

  if (typeof exp === 'number') {
    return exp < 1000000000000 ? exp * 1000 : exp
  }

  const numericExp = Number(exp)

  if (!Number.isNaN(numericExp)) {
    return numericExp < 1000000000000 ? numericExp * 1000 : numericExp
  }

  const dateExp = Date.parse(exp)

  return Number.isNaN(dateExp) ? null : dateExp
}

const formatTimer = (milliseconds: number) => {
  const totalSeconds = Math.max(0, Math.ceil(milliseconds / 1000))
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60

  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}

export const getCartLotteryNumber = (ticket: Partial<CartLottery>) => {
  const value = ticket.number || ticket.full_number || ticket.lottery_number || ''

  return String(value)
}

const normalizeIdentityValue = (value: unknown) => {
  const text = String(value ?? '').trim()

  return text && text !== 'null' && text !== 'undefined' ? text : ''
}

const uniqueIdentityKeys = (values: unknown[]) => Array.from(new Set(values.map(normalizeIdentityValue).filter(Boolean)))
const isVirtualStockRef = (value: string) => value.startsWith('vstock:')

export const getCartLotteryIdentityKeys = (ticket: Partial<CartLottery>) => {
  const stockRef = normalizeIdentityValue(ticket.stock_ref)
  const strongKeys = uniqueIdentityKeys([
    ticket.token,
    ticket.local_stock_item_id,
    ...(Array.isArray(ticket.local_stock_item_ids) ? ticket.local_stock_item_ids : []),
    ticket.id
  ])

  if (strongKeys.length > 0) {
    return stockRef && isVirtualStockRef(stockRef)
      ? uniqueIdentityKeys([...strongKeys, stockRef])
      : strongKeys
  }

  return uniqueIdentityKeys([stockRef])
}

const hasCartIdentityMatch = (item: Partial<CartLottery>, targetKeys: string[]) => {
  if (targetKeys.length === 0) {
    return false
  }

  const itemKeys = getCartLotteryIdentityKeys(item)

  return itemKeys.some((key) => targetKeys.includes(key))
}

const toNumber = (value: unknown, fallback = 0) => {
  const number = Number(value)

  return Number.isFinite(number) ? number : fallback
}

const normalizeCartLottery = (ticket: CartLottery): CartLottery => {
  const {
    highlight,
    highlightDigits,
    priceTrend,
    priceFlashKey,
    ...cartTicket
  } = ticket

  return {
    ...cartTicket,
    number: getCartLotteryNumber(ticket),
    selected: true
  }
}

const resolveEarliestExpiration = (cartItems: CartLottery[], candidates: Array<string | number | null | undefined> = []) => {
  const times = [
    ...cartItems.map((item) => item.reservation_expires_at),
    ...candidates
  ]
    .map((value) => parseExpTime(value ?? null))
    .filter((value): value is number => value !== null)

  return times.length > 0 ? Math.min(...times) : null
}

const resolveServerTime = (cartItems: CartLottery[], serverTime?: string | number | null) => {
  if (serverTime) {
    return serverTime
  }

  return cartItems.find((item) => item.server_time)?.server_time ?? null
}

export const useCart = () => {
  const items = useState<CartLottery[]>('cart_items', () => [])
  const exp = useState<string | number | null>('cart_exp', () => null)
  const serverTimeOffsetMs = useState('cart_server_time_offset_ms', () => 0)
  const now = useState('cart_now', () => Date.now())
  const initData = useState<any>('app_init_data', () => null)

  const currentServerTime = () => Date.now() + serverTimeOffsetMs.value
  const syncServerTime = (serverTime?: string | number | null) => {
    const parsed = parseExpTime(serverTime ?? null)

    if (parsed === null) {
      return
    }

    serverTimeOffsetMs.value = parsed - Date.now()
    now.value = parsed
  }

  if (process.client && !timerInterval) {
    timerInterval = setInterval(() => {
      now.value = currentServerTime()
    }, 1000)
  }

  const expTime = computed(() => parseExpTime(exp.value))
  const remainingMilliseconds = computed(() => expTime.value ? expTime.value - now.value : 0)
  const timer = computed(() => formatTimer(remainingMilliseconds.value))
  const count = computed(() => items.value.reduce((total, item) => total + Math.max(1, toNumber(item.count, 1)), 0))
  const amount = computed(() => items.value.reduce((total, item) => {
    const price = toNumber(item.price)

    return total + (price > 0 ? price : Math.max(1, toNumber(item.count, 1)) * ticketPrice)
  }, 0))
  const hasItems = computed(() => count.value > 0)
  const isExpired = computed(() => hasItems.value && remainingMilliseconds.value <= 0)

  const syncInitCart = () => {
    if (!initData.value) {
      return
    }

    const nextItems = items.value
    const hasCartItems = nextItems.length > 0
    const nextCartOrder = initData.value.cart_order && typeof initData.value.cart_order === 'object' && !Array.isArray(initData.value.cart_order)
      ? {
          ...initData.value.cart_order,
          lotteries: nextItems
        }
      : initData.value.cart_order
    const hasCartOrder = hasCartItems && nextCartOrder && typeof nextCartOrder === 'object' && !Array.isArray(nextCartOrder) && Object.keys(nextCartOrder).length > 0

    initData.value = {
      ...initData.value,
      carts: nextItems,
      cart_order: hasCartOrder ? nextCartOrder : [],
      order: hasCartOrder ? nextCartOrder : [],
      orders: hasCartOrder ? [nextCartOrder] : [],
      waiting: hasCartOrder ? [nextCartOrder] : []
    }
  }

  const addBookedLottery = (ticket: CartLottery, bookingExp: string | number | null, serverTime?: string | number | null) => {
    const bookedTicket = {
      ...normalizeCartLottery(ticket)
    }
    const bookedKeys = getCartLotteryIdentityKeys(bookedTicket)

    if (bookedKeys.length > 0) {
      items.value = [
        ...items.value.filter((item) => !hasCartIdentityMatch(item, bookedKeys)),
        bookedTicket
      ]
    } else {
      items.value = [
        ...items.value.filter((item) => getCartLotteryNumber(item) !== bookedTicket.number),
        bookedTicket
      ]
    }

    syncServerTime(resolveServerTime(items.value, serverTime || bookedTicket.server_time))
    exp.value = items.value.length > 0 ? resolveEarliestExpiration(items.value, [exp.value, bookingExp]) : null
    syncInitCart()
  }

  const removeLottery = (ticket: CartLottery) => {
    const groupItems = Array.isArray(ticket.group_items) ? ticket.group_items : []
    const targetKeys = Array.from(new Set([
      ...getCartLotteryIdentityKeys(ticket),
      ...groupItems.flatMap((item) => getCartLotteryIdentityKeys(item))
    ]))
    const ticketNumber = getCartLotteryNumber(ticket)

    items.value = items.value.filter((item) => {
      if (targetKeys.length > 0) {
        return !hasCartIdentityMatch(item, targetKeys)
      }

      return getCartLotteryNumber(item) !== ticketNumber
    })

    exp.value = items.value.length > 0 ? resolveEarliestExpiration(items.value, [exp.value]) : null

    syncInitCart()
  }

  const clearCart = () => {
    items.value = []
    exp.value = null
    syncInitCart()
  }

  const setCartItems = (cartItems: CartLottery[], bookingExp: string | number | null = null, serverTime?: string | number | null) => {
    items.value = cartItems.map(normalizeCartLottery).filter((item) => item.number)
    syncServerTime(resolveServerTime(items.value, serverTime))
    exp.value = items.value.length > 0 ? resolveEarliestExpiration(items.value, [bookingExp]) : null
    syncInitCart()
  }

  return {
    items,
    exp,
    remainingMilliseconds,
    isExpired,
    timer,
    count,
    amount,
    hasItems,
    addBookedLottery,
    removeLottery,
    clearCart,
    setCartItems,
    syncServerTime
  }
}

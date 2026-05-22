import { computed } from 'vue'
import { ticketPrice } from '~/data/lottery'

export interface CartLottery {
  id?: string | number
  token?: string
  number: string
  full_number?: string
  lottery_number?: string
  local_stock_item_id?: string | number
  stock_ref?: string | number
  reservation_id?: string | number
  order_id?: string | number
  game_id?: string | number
  count?: number | string
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

export const getCartLotteryIdentityKeys = (ticket: Partial<CartLottery>) => [
  ticket.token,
  ticket.local_stock_item_id,
  ticket.stock_ref,
  ticket.id
].map(normalizeIdentityValue).filter(Boolean)

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

export const useCart = () => {
  const items = useState<CartLottery[]>('cart_items', () => [])
  const exp = useState<string | number | null>('cart_exp', () => null)
  const now = useState('cart_now', () => Date.now())
  const initData = useState<any>('app_init_data', () => null)

  if (process.client && !timerInterval) {
    timerInterval = setInterval(() => {
      now.value = Date.now()
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

  const syncInitCart = () => {
    if (!initData.value) {
      return
    }

    const nextItems = items.value
    const nextCartOrder = initData.value.cart_order && typeof initData.value.cart_order === 'object' && !Array.isArray(initData.value.cart_order)
      ? {
          ...initData.value.cart_order,
          lotteries: nextItems
        }
      : initData.value.cart_order

    initData.value = {
      ...initData.value,
      carts: nextItems,
      cart_order: nextItems.length > 0 ? nextCartOrder : [],
      orders: nextItems.length > 0 ? nextCartOrder : []
    }
  }

  const addBookedLottery = (ticket: CartLottery, bookingExp: string | number | null) => {
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

    exp.value = bookingExp
    syncInitCart()
  }

  const removeLottery = (ticket: CartLottery) => {
    const targetKeys = getCartLotteryIdentityKeys(ticket)
    const ticketNumber = getCartLotteryNumber(ticket)

    items.value = items.value.filter((item) => {
      if (targetKeys.length > 0) {
        return !hasCartIdentityMatch(item, targetKeys)
      }

      return getCartLotteryNumber(item) !== ticketNumber
    })

    if (items.value.length === 0) {
      exp.value = null
    }

    syncInitCart()
  }

  const clearCart = () => {
    items.value = []
    exp.value = null
    syncInitCart()
  }

  const setCartItems = (cartItems: CartLottery[], bookingExp: string | number | null = exp.value) => {
    items.value = cartItems.map(normalizeCartLottery).filter((item) => item.number)
    exp.value = items.value.length > 0 ? bookingExp : null
    syncInitCart()
  }

  return {
    items,
    exp,
    timer,
    count,
    amount,
    hasItems,
    addBookedLottery,
    removeLottery,
    clearCart,
    setCartItems
  }
}

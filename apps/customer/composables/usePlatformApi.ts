import { ticketPrice } from '~/data/lottery'
import type { CartLottery } from '~/composables/useCart'

type AnyRecord = Record<string, any>
const CURRENT_GAME_TTL_MS = 5 * 60 * 1000

const normalizeResponse = <T = AnyRecord>(response: any): T => response?.data ?? response

const withLegacyData = <T extends AnyRecord>(payload: T): T & { data: T } => ({
  ...payload,
  data: payload
})

const unwrapData = <T = AnyRecord>(response: any): T => {
  const payload = normalizeResponse(response)

  return (payload?.data ?? payload) as T
}

export const createIdempotencyKey = (scope = 'customer-write') => {
  const randomValue = typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`

  return `${scope}-${randomValue}`
}

export const moneyToDisplayNumber = (value: unknown, fallback = 0) => {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : fallback
  }

  if (typeof value === 'string') {
    const parsed = Number(value)

    return Number.isFinite(parsed) ? parsed : fallback
  }

  if (value && typeof value === 'object' && 'amount' in value) {
    const amount = Number((value as { amount?: unknown }).amount)

    return Number.isFinite(amount) ? amount / 100 : fallback
  }

  return fallback
}

const displayAmountToMinor = (value: unknown) => Math.round(moneyToDisplayNumber(value) * 100)

const statusToLegacyGameStatus = (status: unknown) => {
  const value = String(status || '').toLowerCase()

  if (['open', 'active', 'selling', '1'].includes(value)) {
    return 1
  }

  if (['closed', 'reward_recorded', 'reward_checking', 'reward_verified', '3'].includes(value)) {
    return 3
  }

  if (['reward_published', 'published', 'archived', '2'].includes(value)) {
    return 2
  }

  return 0
}

const normalizeGame = (game: AnyRecord | null | undefined) => {
  if (!game) {
    return null
  }

  return {
    ...game,
    status: statusToLegacyGameStatus(game.status),
    start_at: game.start_at || game.draw_at || game.created_at,
    end_at: game.end_at || game.close_at || game.draw_at
  }
}

const normalizeImageFields = (item: AnyRecord) => {
  const imageUrl = item.image_url || item.image || ''
  const imageThumbUrl = item.image_thumb_url || item.preview_image_url || item.image_thumb || item.thumb_url || imageUrl
  const imageStatus = item.image_status || (imageUrl || imageThumbUrl ? 'ready' : 'missing')

  return {
    image_url: imageUrl,
    image_thumb_url: imageThumbUrl,
    preview_image_url: item.preview_image_url || imageThumbUrl || '',
    image_status: imageStatus,
    image_error: item.image_error || null,
    image: imageUrl || imageThumbUrl || ''
  }
}

const parseTimestampMs = (value: unknown) => {
  if (!value) {
    return null
  }

  if (typeof value === 'number') {
    return value < 1000000000000 ? value * 1000 : value
  }

  const parsed = Date.parse(String(value))

  return Number.isNaN(parsed) ? null : parsed
}

const expirationFromServerDuration = (reservation: AnyRecord | null | undefined) => {
  const seconds = Number(reservation?.expires_in_seconds)
  const serverTime = parseTimestampMs(reservation?.server_time)

  if (Number.isFinite(seconds) && serverTime !== null) {
    return new Date(serverTime + Math.max(0, seconds) * 1000).toISOString()
  }

  return reservation?.expires_at || null
}

const normalizeStockItem = (item: AnyRecord, reservationContext?: string | AnyRecord): CartLottery & AnyRecord => {
  const reservation = typeof reservationContext === 'string'
    ? { id: reservationContext }
    : (reservationContext || {})
  const reservationId = reservation?.id ? String(reservation.id) : ''
  const number = String(item.full_number || item.number || item.lottery_number || '')
  const price = moneyToDisplayNumber(item.price)
  const imageFields = normalizeImageFields(item)
  const reservationExpiresAt = expirationFromServerDuration(reservation)

  return {
    ...item,
    token: String(item.id || item.token || ''),
    local_stock_item_id: String(item.id || item.local_stock_item_id || item.token || ''),
    stock_ref: item.stock_ref || item.id || item.local_stock_item_id || item.token || '',
    remaining_count: Number.isFinite(Number(item.remaining_count)) ? Number(item.remaining_count) : null,
    availability_status: item.availability_status || item.status || 'available',
    reservation_id: reservationId || item.reservation_id,
    reservation_expires_at: item.reservation_expires_at || item.expires_at || reservationExpiresAt,
    server_time: item.server_time || reservation?.server_time || null,
    number,
    full_number: number,
    lottery_number: number,
    seller: item.seller || item.store?.name || item.store_name || '',
    store_name: item.store_name || item.store?.name || item.seller || '',
    price: price > 0 ? price : ticketPrice,
    selected: item.selected === true,
    ...imageFields
  }
}

const normalizeReservationItems = (reservation: AnyRecord | null | undefined) => {
  return Array.isArray(reservation?.items)
    ? reservation.items.map((item: AnyRecord) => normalizeStockItem(item, reservation || {}))
    : []
}

const normalizeCartItems = (cart: AnyRecord | null | undefined) => {
  const reservations = Array.isArray(cart?.reservations) ? cart.reservations : []

  return reservations.flatMap(normalizeReservationItems)
}

const getFirstActiveReservation = (cart: AnyRecord | null | undefined) => {
  const reservations = Array.isArray(cart?.reservations) ? cart.reservations : []

  return reservations.find((reservation: AnyRecord) => String(reservation.status || 'active') === 'active') || reservations[0] || null
}

const getCartReservationIds = (cart: AnyRecord | null | undefined) => {
  const reservations = Array.isArray(cart?.reservations) ? cart.reservations : []

  return reservations
    .filter((reservation: AnyRecord) => String(reservation.status || 'active') === 'active')
    .map((reservation: AnyRecord) => String(reservation.id || '').trim())
    .filter(Boolean)
}

const normalizeCartOrder = (cart: AnyRecord | null | undefined) => {
  const reservation = getFirstActiveReservation(cart)
  const lotteries = normalizeCartItems(cart)
  const expiresAt = expirationFromServerDuration(reservation)
  const reservationIds = getCartReservationIds(cart)

  if (!reservation && lotteries.length === 0) {
    return null
  }

  return {
    id: reservation?.id || lotteries[0]?.reservation_id || '',
    reservation_id: reservation?.id || lotteries[0]?.reservation_id || '',
    reservation_ids: reservationIds.length > 0
      ? reservationIds
      : Array.from(new Set(lotteries.map((item: CartLottery) => String(item.reservation_id || '').trim()).filter(Boolean))),
    exp: expiresAt,
    server_time: reservation?.server_time || cart?.server_time,
    created_at: reservation?.server_time || cart?.server_time,
    updated_at: reservation?.server_time || cart?.server_time,
    lotteries,
    total: moneyToDisplayNumber(cart?.total) || lotteries.reduce((sum: number, item: CartLottery) => sum + Number(item.price || ticketPrice), 0),
    status: reservation?.status || 'active'
  }
}

const normalizePagination = (meta: AnyRecord | null | undefined, page = 1, perPage = 20) => ({
  seed: meta?.next_cursor || null,
  next_cursor: meta?.next_cursor || null,
  page,
  current_page: page,
  total_page: meta?.has_more ? page + 1 : page,
  last_page: meta?.has_more ? page + 1 : page,
  per_page: perPage,
  total: 0
})

const normalizeWallet = (wallet: AnyRecord) => ({
  ...wallet,
  type: wallet.type === 'primary' ? 1 : wallet.type,
  balance: moneyToDisplayNumber(wallet.balance)
})

const topupStatusToLegacy = (status: unknown) => {
  const value = String(status || '')

  if (['approved', 'paid', 'completed'].includes(value)) {
    return 1
  }

  if (['pending_payment', 'pending_review', 'pending', 'processing'].includes(value)) {
    return 2
  }

  if (['rejected', 'cancelled', 'expired'].includes(value)) {
    return 0
  }

  return value
}

const normalizeTopup = (topup: AnyRecord | null | undefined) => {
  if (!topup) {
    return null
  }

  const presentationStatus = String(topup.status || '')

  return {
    ...topup,
    amount: moneyToDisplayNumber(topup.amount),
    bonus_amount: moneyToDisplayNumber(topup.bonus_amount),
    status: topupStatusToLegacy(presentationStatus),
    status_raw: presentationStatus,
    presentation_status: presentationStatus,
    slip: topup.slip || null,
    slip_url: topup.slip_url || topup.slip?.url || topup.slip?.full_url || '',
    slip_thumb_url: topup.slip_thumb_url || topup.slip?.thumb_url || topup.slip?.url || '',
    qr_code: topup.payment?.qr_code || '',
    redirect_url: topup.payment?.redirect_url || '',
    message: topup.payment?.message || ''
  }
}

const normalizeAffiliatePayout = (payout: AnyRecord | null | undefined) => {
  if (!payout) {
    return null
  }

  return {
    ...payout,
    amount: moneyToDisplayNumber(payout.amount)
  }
}

const normalizeAffiliateCommission = (commission: AnyRecord | null | undefined) => {
  if (!commission) {
    return null
  }

  return {
    ...commission,
    amount: moneyToDisplayNumber(commission.amount)
  }
}

const normalizeAffiliateOverview = (payload: AnyRecord | null | undefined) => {
  const stats = payload?.stats || {}
  const payoutPolicy = payload?.payout_policy || {}

  return {
    is_affiliate: Boolean(payload?.is_affiliate),
    affiliate: payload?.affiliate || null,
    links: Array.isArray(payload?.links) ? payload.links : [],
    profile: payload?.profile || {},
    payout_policy: {
      ...payoutPolicy,
      minimum_payout: moneyToDisplayNumber(payoutPolicy.minimum_payout, 300),
      minimum_payout_amount: moneyToDisplayNumber(payoutPolicy.minimum_payout_amount || payoutPolicy.minimum_payout, 300)
    },
    stats: {
      total_commission: moneyToDisplayNumber(stats.total_commission),
      approved_commission: moneyToDisplayNumber(stats.approved_commission),
      pending_commission: moneyToDisplayNumber(stats.pending_commission),
      requested_payout: moneyToDisplayNumber(stats.requested_payout),
      available_balance: moneyToDisplayNumber(stats.available_balance),
      converted_count: Number(stats.converted_count || 0),
      visitor_count: Number(stats.visitor_count || 0),
      registered_count: Number(stats.registered_count || 0)
    },
    commissions: Array.isArray(payload?.commissions) ? payload.commissions.map(normalizeAffiliateCommission).filter(Boolean) : [],
    payouts: Array.isArray(payload?.payouts) ? payload.payouts.map(normalizeAffiliatePayout).filter(Boolean) : []
  }
}

const normalizeBank = (bank: AnyRecord | null | undefined) => {
  if (!bank) {
    return null
  }

  return {
    ...bank,
    bank_deposit_name: bank.bank_deposit_name || bank.account_name,
    bank_deposit_number: bank.bank_deposit_number || bank.account_number,
    bank_name: bank.bank_name || bank.bank?.name || 'ธนาคาร',
    bank_icon: bank.bank_icon || bank.bank?.icon || 'bi-bank',
    bank: {
      code: bank.bank?.code || bank.bank_code || '',
      name: bank.bank?.name || bank.bank_name || 'ธนาคาร',
      icon: bank.bank?.icon || bank.bank_icon || 'bi-bank'
    }
  }
}

const ticketStatusToLegacy = (status: unknown) => {
  const value = String(status || '')

  if (['winning'].includes(value)) {
    return 4
  }

  if (['paid_out'].includes(value)) {
    return 5
  }

  if (['non_winning', 'cancelled', 'voided'].includes(value)) {
    return 0
  }

  return 1
}

const normalizeTicket = (ticket: AnyRecord) => {
  const imageFields = normalizeImageFields(ticket)

  return {
    ...ticket,
    number: String(ticket.full_number || ticket.number || ticket.lottery_number || ''),
    lottery_number: String(ticket.full_number || ticket.number || ticket.lottery_number || ''),
    status: ticketStatusToLegacy(ticket.status),
    ...imageFields
  }
}

const normalizeOrder = (order: AnyRecord | null | undefined) => {
  if (!order) {
    return null
  }

  const lotteries = Array.isArray(order.tickets) ? order.tickets.map(normalizeTicket) : []

  return {
    ...order,
    total: moneyToDisplayNumber(order.total),
    amount: moneyToDisplayNumber(order.total),
    price: moneyToDisplayNumber(order.total),
    updated_at: order.paid_at || order.updated_at || order.created_at,
    lotteries,
    wallet: order.wallet ? normalizeWallet(order.wallet) : null
  }
}

const rewardTypeToSlug = (value: unknown) => {
  const type = String(value || '')

  const map: Record<string, string> = {
    first: 'reward_1',
    reward_1: 'reward_1',
    two_digit: 'reward_two_digit',
    last2: 'reward_two_digit',
    reward_two_digit: 'reward_two_digit',
    front3: 'reward_three_digit_1',
    reward_three_digit_1: 'reward_three_digit_1',
    back3: 'reward_three_digit_2',
    last3: 'reward_three_digit_2',
    reward_three_digit_2: 'reward_three_digit_2',
    beside_first: 'reward_beside_1',
    reward_beside_1: 'reward_beside_1'
  }

  return map[type] || type
}

const normalizeRewardSummary = (summary: AnyRecord | null | undefined) => {
  if (!summary) {
    return null
  }

  const grouped = new Map<string, AnyRecord>()
  const prizes = Array.isArray(summary.prizes) ? summary.prizes : []

  prizes.forEach((prize: AnyRecord) => {
    const slug = rewardTypeToSlug(prize.prize_type || prize.slug)
    const existing = grouped.get(slug) || {
      id: slug,
      game_id: summary.game_id,
      name: prize.name || slug,
      reward: moneyToDisplayNumber(prize.amount || prize.reward),
      slug,
      number: []
    }

    existing.number = [...existing.number, String(prize.prize_number || prize.number || '')].filter(Boolean)
    grouped.set(slug, existing)
  })

  return {
    id: summary.game_id,
    name: summary.game_name || summary.draw_label || '',
    status: summary.status === 'published' ? 2 : 1,
    rewards: Array.from(grouped.values())
  }
}

export const usePlatformApi = () => {
  const axios = useAxios()
  const { token } = useAuth()
  const { config: siteConfig, fetchSiteConfig, setSiteConfig, isWriteBlockedByMaintenance } = useSiteConfig()
  const currentGameState = useState<AnyRecord | null>('platform_current_game', () => null)
  const currentGameFetchedAt = useState<number>('platform_current_game_fetched_at', () => 0)
  const serverCartState = useState<AnyRecord | null>('platform_server_cart', () => null)

  const idempotencyHeaders = (scope: string) => ({
    'Idempotency-Key': createIdempotencyKey(scope)
  })

  const getCurrentGame = async (options: { force?: boolean } = {}) => {
    if (!options.force && currentGameState.value?.id && Date.now() - currentGameFetchedAt.value < CURRENT_GAME_TTL_MS) {
      return currentGameState.value
    }

    const response = await axios.get('/public/games/current')
    const game = unwrapData<AnyRecord>(response)

    currentGameState.value = game
    currentGameFetchedAt.value = Date.now()

    return game
  }

  const getCurrentGameId = async () => {
    if (currentGameState.value?.id) {
      return String(currentGameState.value.id)
    }

    try {
      const game = await getCurrentGame()

      return game?.id ? String(game.id) : ''
    } catch {
      return ''
    }
  }

  const loadCart = async () => {
    if (!token.value) {
      serverCartState.value = null
      return null
    }

    const response = await axios.get('/customer/cart')
    const cart = unwrapData<AnyRecord>(response)

    serverCartState.value = cart

    return cart
  }

  const loadCartLegacy = async () => {
    const cart = await loadCart()

    return withLegacyData({
      code: 0,
      carts: normalizeCartItems(cart),
      server_time: cart?.server_time || null,
      result: {
        cart_order: normalizeCartOrder(cart)
      }
    })
  }

  const loadAppInit = async () => {
    const [configResult, gameResult, cartResult] = await Promise.allSettled([
      fetchSiteConfig(),
      getCurrentGame(),
      token.value ? loadCart() : Promise.resolve(null)
    ])
    const configValue = configResult.status === 'fulfilled' ? configResult.value : null
    const gameValue = gameResult.status === 'fulfilled' ? gameResult.value : null
    const cartValue = cartResult.status === 'fulfilled' ? cartResult.value : null
    const cartOrder = normalizeCartOrder(cartValue)
    const cartItems = normalizeCartItems(cartValue)

    if (configValue) {
      setSiteConfig(configValue)
    }

    return {
      status: statusToLegacyGameStatus(gameValue?.status),
      game: normalizeGame(gameValue),
      site_config: configValue,
      carts: cartItems,
      cart_order: cartOrder,
      orders: cartOrder ? [cartOrder] : [],
      waiting: cartOrder ? [cartOrder] : []
    }
  }

  const searchStockLegacy = async (input: {
    number?: string
    digits?: Array<string | null>
    cursor?: string | null
    storeId?: string
    mode?: 'search' | 'browse' | 'random'
    randomSeed?: string | null
    limit?: number
    page?: number
  } = {}) => {
    const gameId = await getCurrentGameId()

    if (!gameId) {
      return withLegacyData({
        code: 0,
        result: {
          lotteries: [],
          pagination: normalizePagination(null, input.page || 1, input.limit || 20),
          bet_status: 0
        }
      })
    }

    const number = String(input.number || '').replace(/\D/g, '').slice(0, 6)
    const digitParams = (input.digits || []).slice(0, 6).reduce((params, digit, index) => {
      const value = String(digit || '').replace(/\D/g, '').slice(0, 1)

      if (value) {
        params[`d${index + 1}`] = value
      }

      return params
    }, {} as Record<string, string>)
    const hasPositionalDigits = Object.keys(digitParams).length > 0
    const mode = input.mode || (number || hasPositionalDigits ? 'search' : (input.storeId ? 'browse' : 'random'))
    const response = await axios.get('/public/stock/search', {
      params: {
        game_id: gameId,
        ...(number ? { number } : {}),
        ...digitParams,
        ...(input.storeId ? { store_id: input.storeId } : {}),
        mode,
        ...(input.cursor ? { cursor: input.cursor } : {}),
        ...(input.randomSeed ? { random_seed: input.randomSeed } : {}),
        limit: input.limit || 20
      }
    })
    const payload = normalizeResponse(response)
    const lotteries = Array.isArray(payload.data) ? payload.data.map((item: AnyRecord) => normalizeStockItem(item)) : []

    return withLegacyData({
      code: 0,
      result: {
        lotteries,
        pagination: normalizePagination(payload.meta, input.page || 1, input.limit || 20),
        game_id: payload.meta?.game_id || gameId,
        seller: lotteries[0]?.store_name ? { name: lotteries[0].store_name } : null,
        bet_status: 1
      }
    })
  }

  const storesLegacy = async (input: { q?: string, cursor?: string | number | null, page?: number, limit?: number } = {}) => {
    const response = await axios.get('/public/stores', {
      params: {
        ...(input.q ? { q: input.q } : {}),
        ...(input.cursor ? { cursor: input.cursor } : {}),
        limit: input.limit || 20
      }
    })
    const payload = normalizeResponse(response)

    return withLegacyData({
      code: 0,
      result: {
        data: Array.isArray(payload.data) ? payload.data : [],
        ...normalizePagination(payload.meta, input.page || 1, input.limit || 20)
      }
    })
  }

  const newsLegacy = async () => {
    const response = await axios.get('/public/news')
    const payload = normalizeResponse(response)

    return withLegacyData({
      code: 0,
      result: (Array.isArray(payload.data) ? payload.data : []).map((news: AnyRecord) => ({
        ...news,
        cover: news.cover || news.cover_url || ''
      }))
    })
  }

  const rewardLegacy = async (gameId?: string | number | null) => {
    try {
      const endpoint = gameId ? `/public/results/${gameId}` : '/public/results/latest'
      const response = await axios.get(endpoint)
      const summary = normalizeRewardSummary(unwrapData<AnyRecord>(response))

      return withLegacyData({
        code: 0,
        result: summary,
        history: summary ? [summary] : []
      })
    } catch {
      return withLegacyData({
        code: 0,
        result: null,
        history: []
      })
    }
  }

  const login = async (payload: AnyRecord) => {
    const response = await axios.post('/customer/auth/login', payload)

    return unwrapData<AnyRecord>(response)
  }

  const me = async () => unwrapData<AnyRecord>(await axios.get('/customer/auth/me'))

  const refresh = async (refreshToken: string | null | undefined) => {
    if (!refreshToken) {
      return null
    }

    const response = await axios.post('/customer/auth/refresh', {
      refresh_token: refreshToken
    })

    return unwrapData<AnyRecord>(response)
  }

  const logout = async () => {
    await axios.post('/customer/auth/logout', {}, {
      headers: idempotencyHeaders('customer-auth-logout')
    })

    return true
  }

  const register = async (payload: AnyRecord) => {
    const response = await axios.post('/customer/auth/register', payload, {
      headers: idempotencyHeaders('customer-register')
    })

    return unwrapData<AnyRecord>(response)
  }

  const lineLogin = async (payload: AnyRecord) => {
    const response = await axios.post('/customer/auth/line/login', payload)
    const data = unwrapData<AnyRecord>(response)

    return withLegacyData({
      code: 0,
      url: data.redirect_url || data.url
    })
  }

  const lineCallback = async (params: AnyRecord) => {
    const response = await axios.get('/customer/auth/line/callback', { params })
    const data = unwrapData<AnyRecord>(response)

    return withLegacyData({
      code: 0,
      ...data
    })
  }

  const loadProfile = async () => unwrapData<AnyRecord>(await axios.get('/customer/profile'))

  const updateProfile = async (payload: AnyRecord) => unwrapData<AnyRecord>(await axios.patch('/customer/profile', payload, {
    headers: idempotencyHeaders('customer-profile-update')
  }))

  const reserveLegacy = async (ticket: AnyRecord) => {
    if (isWriteBlockedByMaintenance()) {
      throw new Error(siteConfig.value?.maintenance?.message || 'ขณะนี้ไม่สามารถทำรายการได้')
    }

    const gameId = String(ticket.game_id || currentGameState.value?.id || await getCurrentGameId())
    const localStockId = String(ticket.local_stock_item_id || ticket.token || ticket.id || '')
    const response = await axios.post('/customer/reservations', {
      game_id: gameId,
      local_stock_item_ids: [localStockId]
    }, {
      headers: idempotencyHeaders('customer-reservation')
    })
    const reservation = unwrapData<AnyRecord>(response)
    const reservedItems = normalizeReservationItems(reservation)
    const reservedTicket = reservedItems[0] || normalizeStockItem(ticket, reservation)

    await loadCart()

    return withLegacyData({
      code: 0,
      result: {
        reservation,
        lottery: {
          ...ticket,
          ...reservedTicket,
          selected: true
        }
      },
      exp: reservation.expires_at || reservedTicket.reservation_expires_at || null,
      server_time: reservation.server_time || reservedTicket.server_time || null
    })
  }

  const releaseReservationLegacy = async (ticket: AnyRecord) => {
    if (isWriteBlockedByMaintenance()) {
      throw new Error(siteConfig.value?.maintenance?.message || 'ขณะนี้ไม่สามารถทำรายการได้')
    }

    const reservationId = String(ticket.reservation_id || ticket.order_id || ticket.id || '')

    if (!reservationId) {
      throw new Error('ไม่พบรหัสรายการจอง')
    }

    await axios.post(`/customer/reservations/${reservationId}/release`, {}, {
      headers: idempotencyHeaders('customer-reservation-release')
    })
    const cart = await loadCart()

    return withLegacyData({
      code: 0,
      carts: normalizeCartItems(cart),
      server_time: cart?.server_time || null,
      result: {
        cart_order: normalizeCartOrder(cart)
      }
    })
  }

  const walletLegacy = async () => {
    const response = await axios.get('/customer/wallet')
    const payload = normalizeResponse(response)

    return withLegacyData({
      code: 0,
      result: (Array.isArray(payload.data) ? payload.data : []).map(normalizeWallet)
    })
  }

  const normalizeCheckoutReservationIds = (input: string | number | Array<string | number> | AnyRecord | null | undefined) => {
    if (Array.isArray(input)) {
      return input.map((id) => String(id || '').trim()).filter(Boolean)
    }

    if (input && typeof input === 'object') {
      const explicitIds = Array.isArray(input.reservation_ids)
        ? input.reservation_ids.map((id: unknown) => String(id || '').trim()).filter(Boolean)
        : []

      if (explicitIds.length > 0) {
        return explicitIds
      }

      const lotteryIds = Array.isArray(input.lotteries)
        ? Array.from(new Set(input.lotteries.map((item: AnyRecord) => String(item.reservation_id || '').trim()).filter(Boolean)))
        : []

      if (lotteryIds.length > 0) {
        return lotteryIds
      }

      return [String(input.reservation_id || input.id || '').trim()].filter(Boolean)
    }

    return [String(input || '').trim()].filter(Boolean)
  }

  const checkoutLegacy = async (reservationInput: string | number | Array<string | number> | AnyRecord) => {
    const reservationIds = normalizeCheckoutReservationIds(reservationInput)
    const response = await axios.post('/customer/checkout', {
      reservation_id: reservationIds[0] || '',
      reservation_ids: reservationIds,
      payment_method: 'wallet'
    }, {
      headers: idempotencyHeaders('customer-checkout')
    })

    return withLegacyData({
      code: 0,
      result: {
        order: normalizeOrder(unwrapData<AnyRecord>(response))
      }
    })
  }

  const orderReceiptLegacy = async (orderId: string | number) => {
    const order = normalizeOrder(unwrapData<AnyRecord>(await axios.get(`/customer/orders/${orderId}`)))

    return {
      order,
      game: null,
      wallet: order?.wallet || null,
      count: Array.isArray(order?.lotteries) ? order.lotteries.length : 0,
      total: order?.total || 0,
      reference: order?.reference || (order?.id ? `ORDER-${order.id}` : ''),
      paid_at: order?.paid_at || order?.updated_at
    }
  }

  const ticketsLegacy = async (input: { cursor?: string | null, limit?: number, page?: number, history?: boolean, status?: string | number } = {}) => {
    const response = await axios.get(input.history ? '/customer/tickets/history' : '/customer/tickets', {
      params: {
        ...(input.cursor ? { cursor: input.cursor } : {}),
        ...(input.status !== undefined && input.status !== null && String(input.status) !== '' ? { status: input.status } : {}),
        limit: input.limit || 20
      }
    })
    const payload = normalizeResponse(response)
    const tickets = Array.isArray(payload.data) ? payload.data.map(normalizeTicket) : []
    const game = input.history ? null : normalizeGame(currentGameState.value)

    return {
      tickets,
      game,
      games: game ? [game] : [],
      pagination: normalizePagination(payload.meta, input.page || 1, input.limit || 20),
      totalTicketCount: tickets.length
    }
  }

  const ticketDetail = async (ticketId: string | number) => normalizeTicket(unwrapData<AnyRecord>(await axios.get(`/customer/tickets/${ticketId}`)))

  const topupOverviewLegacy = async (params: AnyRecord = {}) => {
    const response = await axios.get('/customer/topups', { params })
    const payload = normalizeResponse(response)

    return {
      bank: normalizeBank(payload.bank),
      waiting: normalizeTopup(payload.waiting),
      histories: Array.isArray(payload.histories) ? payload.histories.map(normalizeTopup).filter(Boolean) : [],
      pagination: payload.meta || null
    }
  }

  const topupDetailLegacy = async (id: string | number) => {
    const topup = normalizeTopup(unwrapData<AnyRecord>(await axios.get(`/customer/topups/${id}`)))

    return {
      deposit: topup,
      bank: null,
      payment: {
        qr_code: topup?.qr_code || '',
        redirect_url: topup?.redirect_url || '',
        message: topup?.message || ''
      }
    }
  }

  const createTopupLegacy = async (payload: AnyRecord | FormData) => {
    const isFormData = typeof FormData !== 'undefined' && payload instanceof FormData
    const body = isFormData ? payload : {
      channel: payload.channel || 'qr',
      amount: displayAmountToMinor(payload.amount),
      ...(payload.transfer_at ? { transfer_at: payload.transfer_at } : {})
    }

    if (isFormData) {
      const amount = payload.get('amount')
      payload.set('amount', String(displayAmountToMinor(amount)))
      payload.delete('topup')
    }

    const topup = normalizeTopup(unwrapData<AnyRecord>(await axios.post('/customer/topups', body, {
      headers: idempotencyHeaders('customer-topup')
    })))

    return withLegacyData({
      code: 0,
      result: topup,
      qr_code: topup?.qr_code || ''
    })
  }

  const createCreditTopupLegacy = async (amount: unknown) => {
    const isFormData = typeof FormData !== 'undefined' && amount instanceof FormData
    const body = isFormData ? amount : {
      amount: displayAmountToMinor(amount)
    }

    if (isFormData) {
      amount.set('amount', String(displayAmountToMinor(amount.get('amount'))))
    }

    const topup = normalizeTopup(unwrapData<AnyRecord>(await axios.post('/customer/topups/credit', body, {
      headers: idempotencyHeaders('customer-credit-topup')
    })))

    return withLegacyData({
      code: 0,
      result: topup,
      qr_code: topup?.qr_code || ''
    })
  }

  const uploadTopupSlipLegacy = async (id: string | number, payload: FormData) => {
    const topup = normalizeTopup(unwrapData<AnyRecord>(await axios.post(`/customer/topups/${id}/slip`, payload, {
      headers: idempotencyHeaders('customer-topup-slip')
    })))

    return withLegacyData({
      code: 0,
      result: topup,
      deposit: topup,
      message: 'อัพโหลดสลิปสำเร็จ'
    })
  }

  const cancelTopupLegacy = async (id: string | number) => {
    const topup = normalizeTopup(unwrapData<AnyRecord>(await axios.delete(`/customer/topups/${id}`, {
      headers: idempotencyHeaders('customer-topup-cancel')
    })))

    return withLegacyData({
      code: 0,
      result: topup,
      message: 'ยกเลิกรายการสำเร็จ'
    })
  }

  const normalizeTopupLegacy = (topup: AnyRecord | null | undefined) => normalizeTopup(topup)

  const affiliateOverview = async () => normalizeAffiliateOverview(unwrapData<AnyRecord>(await axios.get('/customer/affiliate')))

  const registerAffiliate = async (payload: AnyRecord = {}) => normalizeAffiliateOverview(unwrapData<AnyRecord>(await axios.post('/customer/affiliate', payload, {
    headers: idempotencyHeaders('customer-affiliate-register')
  })))

  const trackAffiliateReferralClick = async (payload: AnyRecord) => unwrapData<AnyRecord>(await axios.post('/public/affiliate/referrals/click', payload))

  const applyAffiliateReferral = async (ref: string, payload: AnyRecord = {}) => unwrapData<AnyRecord>(await axios.post('/customer/affiliate/referrals/apply', {
    ...payload,
    ref
  }))

  const affiliateCommissions = async (params: AnyRecord = {}) => {
    const response = await axios.get('/customer/affiliate/commissions', { params })
    const payload = normalizeResponse(response)

    return {
      data: Array.isArray(payload.data) ? payload.data.map(normalizeAffiliateCommission).filter(Boolean) : [],
      meta: payload.meta || null
    }
  }

  const affiliatePayouts = async (params: AnyRecord = {}) => {
    const response = await axios.get('/customer/affiliate/payouts', { params })
    const payload = normalizeResponse(response)

    return {
      data: Array.isArray(payload.data) ? payload.data.map(normalizeAffiliatePayout).filter(Boolean) : [],
      meta: payload.meta || null
    }
  }

  const createAffiliatePayout = async (payload: AnyRecord) => normalizeAffiliatePayout(unwrapData<AnyRecord>(await axios.post('/customer/affiliate/payouts', {
    ...payload,
    amount: {
      amount: displayAmountToMinor(payload.amount),
      currency: 'THB'
    }
  }, {
    headers: idempotencyHeaders('customer-affiliate-payout')
  })))

  return {
    loadAppInit,
    loadCart,
    loadCartLegacy,
    searchStockLegacy,
    storesLegacy,
    newsLegacy,
    rewardLegacy,
    login,
    me,
    refresh,
    logout,
    register,
    lineLogin,
    lineCallback,
    loadProfile,
    updateProfile,
    reserveLegacy,
    releaseReservationLegacy,
    walletLegacy,
    checkoutLegacy,
    orderReceiptLegacy,
    ticketsLegacy,
    ticketDetail,
    topupOverviewLegacy,
    topupDetailLegacy,
    createTopupLegacy,
    createCreditTopupLegacy,
    uploadTopupSlipLegacy,
    cancelTopupLegacy,
    normalizeTopupLegacy,
    affiliateOverview,
    registerAffiliate,
    trackAffiliateReferralClick,
    applyAffiliateReferral,
    affiliateCommissions,
    affiliatePayouts,
    createAffiliatePayout,
    moneyToDisplayNumber
  }
}

import { formatDrawDateText } from '~/utils/formatDrawDate'

export interface UserTicketGame {
  id?: number | string
  name?: string
  status?: number | string
  [key: string]: unknown
}

export interface UserTicket {
  id?: number | string
  order_id?: number | string
  full_number?: string
  number?: string
  lottery_number?: string
  status?: number | string
  paid?: number | string | boolean
  image?: string | null
  count?: number | string
  total?: number | string
  game_id?: number | string
  draw?: number | string
  draw_no?: number | string
  game_no?: number | string
  set?: number | string
  sort_order?: number | string
  [key: string]: unknown
}

export interface UserTicketResponse {
  tickets: UserTicket[]
  game: UserTicketGame | null
  games: UserTicketGame[]
  pagination: UserTicketPagination
  totalTicketCount: number
}

export interface UserTicketPagination {
  currentPage: number
  lastPage: number
  perPage: number
  total: number
  nextPageUrl?: string | null
}

export interface FetchTicketsOptions {
  gameId?: number | string | null
  search?: string
  page?: number
  perPage?: number
  status?: number | string
}

export const getTicketNumber = (ticket: Partial<UserTicket> | null | undefined) => {
  const value = ticket?.full_number || ticket?.number || ticket?.lottery_number || ''

  return String(value)
}

export const getTicketCount = (ticket: Partial<UserTicket> | null | undefined) => {
  const value = Number(ticket?.count ?? 1)

  return Number.isFinite(value) && value > 0 ? value : 1
}

export const getTicketTotal = (ticket: Partial<UserTicket> | null | undefined) => {
  const value = Number(ticket?.total ?? 0)

  return Number.isFinite(value) ? value : 0
}

export const getTicketStatusText = (ticket: Partial<UserTicket> | null | undefined) => {
  const status = Number(ticket?.status)

  if (status === 4) {
    return 'ถูกรางวัล'
  }

  if (status === 5) {
    return 'ขึ้นเงินแล้ว'
  }

  if (status === 0) {
    return 'ไม่ถูกรางวัล'
  }

  if (status === 2) {
    return 'รอออกผล'
  }

  if (status === 1 || ticket?.paid === true || ticket?.paid === 1 || ticket?.paid === '1') {
    return 'รอออกผล'
  }

  return 'รอออกผล'
}

export const getTicketDraw = (ticket: Partial<UserTicket> | null | undefined, game?: UserTicketGame | null) => {
  const value = ticket?.draw_no ?? ticket?.draw ?? ticket?.game_no ?? ticket?.game_id ?? game?.id ?? '-'

  return String(value || '-')
}

export const getTicketSet = (ticket: Partial<UserTicket> | null | undefined) => {
  const value = ticket?.set ?? ticket?.sort_order ?? getTicketCount(ticket)

  return String(value || '-')
}

export const useUserTickets = () => {
  const axios = useAxios()
  const config = useRuntimeConfig()

  const fetchTickets = async (gameIdOrOptions?: number | string | null | FetchTicketsOptions, fetchOptions: FetchTicketsOptions = {}): Promise<UserTicketResponse> => {
    const options = typeof gameIdOrOptions === 'object' && gameIdOrOptions !== null
      ? gameIdOrOptions
      : {
          ...fetchOptions,
          gameId: gameIdOrOptions
        }

    const response = await axios.get('/lotteries', {
      params: {
        ...(options.gameId ? { game_id: options.gameId } : {}),
        ...(options.search ? { search: options.search } : {}),
        ...(options.page ? { page: options.page } : {}),
        ...(options.perPage ? { per_page: options.perPage } : {}),
        ...(options.status !== undefined ? { status: options.status } : {})
      }
    })

    const payload = response.data || {}
    const result = payload.result || {}
    const tickets = Array.isArray(result.data)
      ? result.data
      : Array.isArray(result)
        ? result
        : Array.isArray(payload.data)
          ? payload.data
          : []
    const game = payload.game || result.game || null
    const games = Array.isArray(payload.games) ? payload.games : Array.isArray(result.games) ? result.games : []
    const pagination = {
      currentPage: Number(result.current_page || payload.current_page || 1),
      lastPage: Number(result.last_page || payload.last_page || 1),
      perPage: Number(result.per_page || payload.per_page || options.perPage || tickets.length || 20),
      total: Number(result.total || payload.total || tickets.length),
      nextPageUrl: result.next_page_url || payload.next_page_url || null
    }

    return {
      tickets,
      game,
      games,
      pagination,
      totalTicketCount: Number(payload.ticket_count || result.ticket_count || 0)
    }
  }

  const getGameDate = (game: UserTicketGame | null | undefined) => {
    const dateText = formatDrawDateText(game?.name)

    return dateText === '-' ? '' : dateText
  }

  const getTicketImageUrl = (ticket: Partial<UserTicket> | null | undefined) => {
    const image = ticket?.image

    if (!image) {
      return ''
    }

    const imageUrl = String(image)

    if (/^https?:\/\//i.test(imageUrl) || imageUrl.startsWith('data:')) {
      return imageUrl
    }

    const baseUrl = String(config.public.apiBaseUrl || '').replace(/\/$/, '')
    const normalizedPath = imageUrl.replace(/^\/+/, '')

    return baseUrl ? `${baseUrl}/${normalizedPath}` : `/${normalizedPath}`
  }

  return {
    fetchTickets,
    getGameDate,
    getTicketNumber,
    getTicketCount,
    getTicketTotal,
    getTicketStatusText,
    getTicketDraw,
    getTicketSet,
    getTicketImageUrl
  }
}

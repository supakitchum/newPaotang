import { formatDrawDateText } from '~/utils/formatDrawDate'
import { moneyToDisplayNumber } from '~/composables/usePlatformApi'

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
  image_url?: string | null
  image_thumb_url?: string | null
  image_status?: string | null
  image_error?: string | null
  count?: number | string
  total?: number | string
  prize_amount?: number | string | { amount?: number | string, currency?: string } | null
  prize_type?: string | null
  prize_number?: string | null
  claimable?: boolean
  reward_status?: Record<string, unknown> | null
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
  history?: boolean
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

export const getTicketImageUrl = (ticket: Partial<UserTicket> | null | undefined) => {
  const image = ticket?.image_url || ticket?.image_thumb_url || ticket?.image

  if (!image) {
    return ''
  }

  const imageUrl = String(image)

  if (/^https?:\/\//i.test(imageUrl) || imageUrl.startsWith('data:')) {
    return imageUrl
  }

  return imageUrl.startsWith('/') ? imageUrl : `/${imageUrl.replace(/^\/+/, '')}`
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

const prizeTypeLabels: Record<string, string> = {
  first_prize: 'รางวัลที่ 1',
  near_first_prize: 'รางวัลข้างเคียงรางวัลที่ 1',
  second_prize: 'รางวัลที่ 2',
  third_prize: 'รางวัลที่ 3',
  fourth_prize: 'รางวัลที่ 4',
  fifth_prize: 'รางวัลที่ 5',
  front3: 'รางวัลเลขหน้า 3 ตัว',
  back3: 'รางวัลเลขท้าย 3 ตัว',
  back2: 'รางวัลเลขท้าย 2 ตัว'
}

export const isWinningTicket = (ticket: Partial<UserTicket> | null | undefined) => {
  const status = Number(ticket?.status)
  const rewardStatus = String(ticket?.reward_status?.status || '').toLowerCase()

  return [4, 5].includes(status) || ['winning', 'approved', 'submitted', 'paid', 'paid_out'].includes(rewardStatus)
}

export const getTicketPrizeAmount = (ticket: Partial<UserTicket> | null | undefined) => {
  const rewardStatus = ticket?.reward_status || {}

  return moneyToDisplayNumber(rewardStatus.prize_amount ?? ticket?.prize_amount, 0)
}

export const getTicketPrizeTitle = (ticket: Partial<UserTicket> | null | undefined) => {
  const rewardStatus = ticket?.reward_status || {}
  const type = String(rewardStatus.prize_type || ticket?.prize_type || '').trim()

  return prizeTypeLabels[type] || (isWinningTicket(ticket) ? 'ถูกรางวัล' : '')
}

export const isTicketClaimable = (ticket: Partial<UserTicket> | null | undefined) => {
  const rewardStatus = ticket?.reward_status || {}

  return Boolean(rewardStatus.claimable ?? ticket?.claimable)
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
  const platformApi = usePlatformApi()
  const pageCursors = useState<Record<string, string | null>>('ticket_page_cursors', () => ({}))

  const fetchTickets = async (gameIdOrOptions?: number | string | null | FetchTicketsOptions, fetchOptions: FetchTicketsOptions = {}): Promise<UserTicketResponse> => {
    const options = typeof gameIdOrOptions === 'object' && gameIdOrOptions !== null
      ? gameIdOrOptions
      : {
          ...fetchOptions,
          gameId: gameIdOrOptions
        }

    const history = options.history === true || Boolean(options.gameId)
    const page = Number(options.page || 1)
    const key = `${history ? 'history' : 'active'}-${options.gameId || 'all'}-${options.search || ''}`
    const cursor = page > 1 ? pageCursors.value[`${key}-${page}`] || null : null
    const response = await platformApi.ticketsLegacy({
      cursor,
      limit: options.perPage,
      page,
      history,
      status: options.status
    })
    const nextCursor = response.pagination.nextPageUrl || response.pagination.seed || null

    if (nextCursor) {
      pageCursors.value[`${key}-${page + 1}`] = nextCursor
    }

    const filteredTickets = options.search
      ? response.tickets.filter((ticket) => getTicketNumber(ticket).includes(String(options.search)))
      : response.tickets

    return {
      ...response,
      tickets: filteredTickets,
      totalTicketCount: response.totalTicketCount || filteredTickets.length
    }
  }

  const getGameDate = (game: UserTicketGame | null | undefined) => {
    const dateText = formatDrawDateText(game?.name)

    return dateText === '-' ? '' : dateText
  }

  return {
    fetchTickets,
    getGameDate,
    getTicketNumber,
    getTicketCount,
    getTicketTotal,
    getTicketStatusText,
    isWinningTicket,
    getTicketPrizeAmount,
    getTicketPrizeTitle,
    isTicketClaimable,
    getTicketDraw,
    getTicketSet,
    getTicketImageUrl
  }
}

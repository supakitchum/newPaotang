import { formatDrawDateText } from '~/utils/formatDrawDate'
import { rewardAmountToDisplayNumber } from '~/composables/usePlatformApi'

export interface UserTicketGame {
  id?: number | string
  code?: string
  name?: string
  draw_at?: string
  status?: number | string
  [key: string]: unknown
}

export interface UserTicketRewardPrize {
  prize_type?: string
  prize_number?: string
  amount?: number | string | { amount?: number | string, currency?: string } | null
  prize_amount?: number | string | { amount?: number | string, currency?: string } | null
  reward?: number | string | { amount?: number | string, currency?: string } | null
  title?: string
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
  prizes?: UserTicketRewardPrize[]
  claimable?: boolean
  reward_status?: Record<string, unknown> | null
  game?: UserTicketGame | null
  game_id?: number | string
  game_name?: string
  draw_at?: string
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
  const rewardStatusRecord = ticket?.reward_status || {}
  const rewardStatus = String(rewardStatusRecord.status || '').toLowerCase()

  if (['paid', 'paid_out'].includes(rewardStatus) || (rewardStatus === 'approved' && Boolean(rewardStatusRecord.paid_at || rewardStatusRecord.payout_ledger_id || rewardStatusRecord.payout_method === 'bank_transfer'))) {
    return 'ขึ้นเงินแล้ว'
  }

  if (['submitted', 'claim_submitted', 'under_review'].includes(rewardStatus)) {
    return 'รอรับเงินรางวัล'
  }

  if (['approved', 'claim_approved'].includes(rewardStatus)) {
    return 'อนุมัติแล้ว'
  }

  if (rewardStatus === 'rejected') {
    return 'ขึ้นเงินไม่สำเร็จ'
  }

  if (rewardStatus === 'cancelled') {
    return 'ยกเลิกขึ้นเงิน'
  }

  if (rewardStatus === 'winning') {
    return 'ถูกรางวัล'
  }

  if (rewardStatus === 'non_winning') {
    return 'ไม่ถูกรางวัล'
  }

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

  return [4, 5].includes(status) || ['winning', 'approved', 'claim_approved', 'submitted', 'claim_submitted', 'under_review', 'paid', 'paid_out', 'rejected', 'cancelled'].includes(rewardStatus)
}

export const getTicketPrizeAmount = (ticket: Partial<UserTicket> | null | undefined) => {
  const prizes = getTicketRewardPrizes(ticket)

  if (prizes.length > 0) {
    return prizes.reduce((total, prize) => total + prize.amount, 0)
  }

  const rewardStatus = ticket?.reward_status || {}
  const prizeType = rewardStatus.prize_type || ticket?.prize_type || ''

  return rewardAmountToDisplayNumber(rewardStatus.prize_amount ?? ticket?.prize_amount, 0, prizeType)
}

export const getTicketRewardPrizes = (ticket: Partial<UserTicket> | null | undefined) => {
  const rewardStatus = ticket?.reward_status || {}
  const source = Array.isArray(rewardStatus.prizes)
    ? rewardStatus.prizes
    : (Array.isArray(ticket?.prizes) ? ticket.prizes : [])

  return source
    .map((item: unknown) => {
      const prize = item && typeof item === 'object' ? item as UserTicketRewardPrize : {}
      const prizeType = String(prize.prize_type || '').trim()
      const amount = rewardAmountToDisplayNumber(prize.amount ?? prize.prize_amount ?? prize.reward, 0, prizeType)

      return {
        ...prize,
        prize_type: prizeType,
        prize_number: String(prize.prize_number || ''),
        title: prizeTypeLabels[prizeType] || String(prize.title || 'ถูกรางวัล'),
        amount
      }
    })
    .filter((prize) => prize.amount > 0 || prize.prize_type || prize.prize_number)
}

export const getTicketPrizeTitle = (ticket: Partial<UserTicket> | null | undefined) => {
  const prizes = getTicketRewardPrizes(ticket)

  if (prizes.length > 1) {
    return `ถูกรางวัล ${prizes.length.toLocaleString('th-TH')} รางวัล`
  }

  if (prizes.length === 1) {
    return prizes[0].title
  }

  const rewardStatus = ticket?.reward_status || {}
  const type = String(rewardStatus.prize_type || ticket?.prize_type || '').trim()

  return prizeTypeLabels[type] || (isWinningTicket(ticket) ? 'ถูกรางวัล' : '')
}

export const isTicketClaimable = (ticket: Partial<UserTicket> | null | undefined) => {
  const rewardStatus = ticket?.reward_status || {}

  return Boolean(rewardStatus.claimable ?? ticket?.claimable)
}

export const getTicketDisplaySortRank = (ticket: Partial<UserTicket> | null | undefined) => {
  const rewardStatusRecord = ticket?.reward_status || {}
  const rewardStatus = String(rewardStatusRecord.status || '').toLowerCase()
  const ticketStatus = Number(ticket?.status)

  if (rewardStatus === 'winning') {
    return 0
  }

  if (['rejected', 'cancelled'].includes(rewardStatus)) {
    return 1
  }

  if (['submitted', 'claim_submitted', 'under_review'].includes(rewardStatus)) {
    return 2
  }

  if (
    ['paid', 'paid_out'].includes(rewardStatus)
    || ['approved', 'claim_approved'].includes(rewardStatus)
    || ticketStatus === 5
    || ticket?.paid === true
    || ticket?.paid === 1
    || ticket?.paid === '1'
  ) {
    return 3
  }

  if (rewardStatus === 'non_winning' || ticketStatus === 0) {
    return 5
  }

  if (ticketStatus === 4) {
    return 0
  }

  return 4
}

export const sortTicketsForCurrentDraw = (nextTickets: UserTicket[]) => (
  nextTickets
    .map((ticket, index) => ({ ticket, index }))
    .sort((left, right) => (
      (getTicketDisplaySortRank(left.ticket) - getTicketDisplaySortRank(right.ticket))
      || left.index - right.index
    ))
    .map((entry) => entry.ticket)
)

export const getTicketClaimId = (ticket: Partial<UserTicket> | null | undefined) => {
  const rewardStatus = ticket?.reward_status || {}
  const claimId = rewardStatus.reward_claim_id || ticket?.reward_claim_id || ''

  return String(claimId || '').trim()
}

export const getTicketClaimTo = (ticket: Partial<UserTicket> | null | undefined) => {
  const ticketId = String(ticket?.id || '').trim()

  if (isTicketClaimable(ticket) && ticketId) {
    return `/tickets/claim/${encodeURIComponent(ticketId)}`
  }

  const claimId = getTicketClaimId(ticket)

  return claimId ? `/reward-claims/${encodeURIComponent(claimId)}` : ''
}

export const getTicketDraw = (ticket: Partial<UserTicket> | null | undefined, game?: UserTicketGame | null) => {
  const value = ticket?.draw_no ?? ticket?.draw ?? ticket?.game_no ?? ticket?.game_id ?? game?.id ?? '-'

  return String(value || '-')
}

export const getTicketGame = (ticket: Partial<UserTicket> | null | undefined) => {
  if (ticket?.game && typeof ticket.game === 'object') {
    return ticket.game
  }

  if (ticket?.game_id || ticket?.game_name || ticket?.draw_at) {
    return {
      id: ticket.game_id,
      name: ticket.game_name || '',
      draw_at: ticket.draw_at || ''
    }
  }

  return null
}

export const getGameDateText = (game: UserTicketGame | null | undefined) => {
  const nameDate = formatDrawDateText(game?.name)

  if (nameDate !== '-') {
    return nameDate
  }

  const drawAtDate = formatDrawDateText(game?.draw_at)

  return drawAtDate === '-' ? '' : drawAtDate
}

export const getTicketGameDate = (ticket: Partial<UserTicket> | null | undefined) => getGameDateText(getTicketGame(ticket))

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
    const ticketGame = filteredTickets.map(getTicketGame).find(Boolean) || null

    return {
      ...response,
      tickets: filteredTickets,
      game: ticketGame || response.game,
      totalTicketCount: response.totalTicketCount || filteredTickets.length
    }
  }

  return {
    fetchTickets,
    getGameDate: getGameDateText,
    getTicketNumber,
    getTicketCount,
    getTicketTotal,
    getTicketStatusText,
    isWinningTicket,
    getTicketPrizeAmount,
    getTicketRewardPrizes,
    getTicketPrizeTitle,
    isTicketClaimable,
    getTicketDisplaySortRank,
    sortTicketsForCurrentDraw,
    getTicketClaimId,
    getTicketClaimTo,
    getTicketDraw,
    getTicketGame,
    getTicketGameDate,
    getTicketSet,
    getTicketImageUrl
  }
}

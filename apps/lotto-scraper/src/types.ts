export type PrizeType =
  | 'first_prize'
  | 'near_first_prize'
  | 'second_prize'
  | 'third_prize'
  | 'fourth_prize'
  | 'fifth_prize'
  | 'front3'
  | 'back3'
  | 'back2'

export type ScrapeSource = 'sanook' | 'thairath'

export type LivePrizeGroup = {
  prize_type: PrizeType
  prize_numbers: string[]
}

export type LiveResultPayload = {
  source: ScrapeSource
  draw_code: string
  draw_date: string
  scraped_at: string
  completion_percent: number
  payload_hash: string
  prizes: LivePrizeGroup[]
}

export type ScrapeResult = LiveResultPayload & {
  source_url: string
  is_complete: boolean
}

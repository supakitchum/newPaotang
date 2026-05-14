export type RewardPrizeDefinition = {
  type: string
  label: string
  count: number
  digits: number
  amount: number
}

export type RewardPrizeGroupState = RewardPrizeDefinition & {
  currency: string
  numbers: string[]
}

export type RewardPrizePayload = {
  prize_type: string
  prize_number: string
  amount: {
    amount: number
    currency: string
  }
}

export type RewardPrizeNumberUpdatePayload = {
  prize_type: string
  prize_numbers: string[]
}

export type RewardPayoutAmountUpdatePayload = {
  prize_type: string
  amount: {
    amount: number
    currency: string
  }
}

export const thaiLotteryPrizeDefinitions: RewardPrizeDefinition[] = [
  { type: 'first_prize', label: 'รางวัลที่ 1', count: 1, digits: 6, amount: 6000000 },
  { type: 'near_first_prize', label: 'รางวัลข้างเคียงรางวัลที่ 1', count: 2, digits: 6, amount: 100000 },
  { type: 'second_prize', label: 'รางวัลที่ 2', count: 5, digits: 6, amount: 200000 },
  { type: 'third_prize', label: 'รางวัลที่ 3', count: 10, digits: 6, amount: 80000 },
  { type: 'fourth_prize', label: 'รางวัลที่ 4', count: 50, digits: 6, amount: 40000 },
  { type: 'fifth_prize', label: 'รางวัลที่ 5', count: 100, digits: 6, amount: 20000 },
  { type: 'front3', label: 'เลขหน้า 3 ตัว', count: 2, digits: 3, amount: 4000 },
  { type: 'back3', label: 'เลขท้าย 3 ตัว', count: 2, digits: 3, amount: 4000 },
  { type: 'back2', label: 'เลขท้าย 2 ตัว', count: 1, digits: 2, amount: 2000 },
]

export const rewardPrizeLabel = (type: string) => (
  thaiLotteryPrizeDefinitions.find((definition) => definition.type === type)?.label || type
)

export const formatRewardPrizeAmount = (amount: unknown, currency = 'THB') => {
  const numericAmount = Number(amount || 0)
  const formatted = Number.isFinite(numericAmount)
    ? new Intl.NumberFormat('th-TH', { maximumFractionDigits: 0 }).format(numericAmount)
    : String(amount || 0)

  return `${formatted} ${currency || 'THB'}`
}

export const normalizeRewardPrizeGroups = (value: unknown): RewardPrizeGroupState[] => {
  const prizes = Array.isArray(value) ? value : []

  return thaiLotteryPrizeDefinitions.map((definition) => {
    const rows = prizes.filter((prize: any) => prize?.prize_type === definition.type)
    const firstRow = rows[0]
    const currency = firstRow?.amount?.currency || 'THB'
    const amount = Number(firstRow?.amount?.amount ?? definition.amount)
    const numbers = Array.from({ length: definition.count }, (_, index) => {
      const number = rows[index]?.prize_number
      if (number !== undefined && number !== null && String(number).trim() !== '') {
        const normalized = String(number).trim()
        return normalized.startsWith('pending_') ? '' : normalized
      }

      return ''
    })

    return {
      ...definition,
      amount: Number.isFinite(amount) ? amount : definition.amount,
      currency,
      numbers,
    }
  })
}

export const rewardPrizeGroupsToPayload = (groups: RewardPrizeGroupState[]): RewardPrizePayload[] => groups.flatMap((group) => {
  const amount = Number(group.amount || 0)

  return group.numbers.map((number) => ({
    prize_type: group.type,
    prize_number: String(number || '').trim(),
    amount: {
      amount: Number.isFinite(amount) ? amount : 0,
      currency: group.currency || 'THB',
    },
  }))
})

export const rewardPrizeGroupsToNumberUpdates = (groups: RewardPrizeGroupState[]): RewardPrizeNumberUpdatePayload[] => groups
  .map((group) => ({
    prize_type: group.type,
    prize_numbers: group.numbers.map((number) => String(number || '').trim()),
  }))
  .filter((group) => group.prize_numbers.some((number) => number !== '' && !number.startsWith('pending_')))

export const rewardPrizeGroupsToPayoutUpdates = (groups: RewardPrizeGroupState[]): RewardPayoutAmountUpdatePayload[] => groups
  .map((group) => {
    const amount = Number(group.amount || 0)

    return {
      prize_type: group.type,
      amount: {
        amount: Number.isFinite(amount) ? amount : 0,
        currency: group.currency || 'THB',
      },
    }
  })
  .filter((group) => group.amount.amount > 0)

export const hasCompleteRewardPrizeGroups = (groups: RewardPrizeGroupState[]) => groups.every((group) => (
  group.numbers.length === group.count
  && group.numbers.every((number) => String(number || '').trim() !== '')
  && Number.isFinite(Number(group.amount))
  && Number(group.amount) >= 0
))

export const hasCompleteRewardPrizeAmounts = (groups: RewardPrizeGroupState[]) => groups.every((group) => (
  Number.isFinite(Number(group.amount))
  && Number(group.amount) >= 0
))

export const hasAnyRewardPrizeNumberUpdate = (groups: RewardPrizeGroupState[]) => groups.some((group) => (
  group.numbers.some((number) => {
    const normalized = String(number || '').trim()
    return normalized !== '' && !normalized.startsWith('pending_')
  })
))

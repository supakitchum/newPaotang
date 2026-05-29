export interface LotteryReward {
  id?: number
  game_id?: number
  name: string
  reward: number | string
  slug: string
  number?: string[] | null
}

export interface LotteryRewardGame {
  id?: number | string
  name?: string
  status?: number
  rewards?: LotteryReward[]
}

export interface LotteryRewardGroup {
  key: string
  title: string
  amount: string
  numbers: string[]
}

export interface LotteryRewardSummary {
  first: string
  front3: string[]
  last2: string
  last3: string[]
}

const rewardTitles: Record<string, string> = {
  reward_1: 'รางวัลที่ 1',
  reward_2: 'รางวัลที่ 2',
  reward_3: 'รางวัลที่ 3',
  reward_4: 'รางวัลที่ 4',
  reward_5: 'รางวัลที่ 5',
  reward_beside_1: 'รางวัลข้างเคียงรางวัลที่ 1',
  reward_three_digit_1: 'เลขหน้า 3 ตัว',
  reward_three_digit_2: 'เลขท้าย 3 ตัว',
  reward_two_digit: 'เลขท้าย 2 ตัว'
}

const rewardDefinitions: Record<string, { count: number, digits: number, amount: number }> = {
  reward_1: { count: 1, digits: 6, amount: 6000000 },
  reward_2: { count: 5, digits: 6, amount: 200000 },
  reward_3: { count: 10, digits: 6, amount: 80000 },
  reward_4: { count: 50, digits: 6, amount: 40000 },
  reward_5: { count: 100, digits: 6, amount: 20000 },
  reward_beside_1: { count: 2, digits: 6, amount: 100000 },
  reward_three_digit_1: { count: 2, digits: 3, amount: 4000 },
  reward_three_digit_2: { count: 2, digits: 3, amount: 4000 },
  reward_two_digit: { count: 1, digits: 2, amount: 2000 }
}

const rewardOrder = [
  'reward_1',
  'reward_two_digit',
  'reward_three_digit_1',
  'reward_three_digit_2',
  'reward_beside_1',
  'reward_2',
  'reward_3',
  'reward_4',
  'reward_5'
]

export const isDisplayableRewardNumber = (number: unknown) => {
  const value = String(number || '').trim()

  return value !== '' && value !== '-' && !value.startsWith('pending_')
}

export const isResolvedRewardNumber = (number: unknown) => {
  const value = String(number || '').trim()

  return isDisplayableRewardNumber(value) && !/^x+$/i.test(value)
}

export const getRewardPlaceholder = (slug: string) => {
  const digits = rewardDefinitions[slug]?.digits || 6

  return 'x'.repeat(digits)
}

const toNumbers = (value: unknown): string[] => {
  if (!Array.isArray(value)) {
    return []
  }

  return value
    .filter((item) => item !== null && item !== undefined && `${item}` !== '')
    .map((item) => `${item}`)
}

const toDisplayNumber = (value: unknown, slug: string) => {
  const normalized = String(value || '').trim()

  if (!normalized || normalized === '-' || normalized.startsWith('pending_') || /^x+$/i.test(normalized)) {
    return getRewardPlaceholder(slug)
  }

  return normalized
}

const toDisplayNumbers = (value: unknown, slug: string, fillMissing = true): string[] => {
  const numbers = toNumbers(value).map((number) => toDisplayNumber(number, slug))
  const expectedCount = rewardDefinitions[slug]?.count || 0

  if (fillMissing && expectedCount > 0) {
    while (numbers.length < expectedCount) {
      numbers.push(getRewardPlaceholder(slug))
    }
  }

  return numbers
}

export const formatRewardAmount = (value: number | string | undefined) => {
  const amount = Number(value || 0)

  if (!Number.isFinite(amount) || amount <= 0) {
    return '-'
  }

  return amount.toLocaleString('th-TH')
}

export const useLotteryReward = () => {
  const getReward = (game: LotteryRewardGame | null | undefined, slug: string) => {
    return game?.rewards?.find((reward) => reward.slug === slug) || null
  }

  const getRewardNumbers = (game: LotteryRewardGame | null | undefined, slug: string) => {
    return toNumbers(getReward(game, slug)?.number)
  }

  const getDisplayRewardNumbers = (game: LotteryRewardGame | null | undefined, slug: string) => {
    if (!game) {
      return []
    }

    return toDisplayNumbers(getReward(game, slug)?.number, slug)
  }

  const getRewardAmount = (game: LotteryRewardGame | null | undefined, slug: string) => {
    return formatRewardAmount(getReward(game, slug)?.reward ?? rewardDefinitions[slug]?.amount)
  }

  const getRewardGroups = (game: LotteryRewardGame | null | undefined): LotteryRewardGroup[] => {
    return rewardOrder
      .map((slug) => {
        const reward = getReward(game, slug)

        return {
          key: slug,
          title: rewardTitles[slug] || reward?.name || slug,
          amount: formatRewardAmount(reward?.reward ?? rewardDefinitions[slug]?.amount),
          numbers: game ? toDisplayNumbers(reward?.number, slug) : []
        }
      })
      .filter((group) => group.numbers.length > 0)
  }

  const toSummary = (game: LotteryRewardGame | null | undefined): LotteryRewardSummary => {
    const front3 = getDisplayRewardNumbers(game, 'reward_three_digit_1')
    const last3 = getDisplayRewardNumbers(game, 'reward_three_digit_2')

    return {
      first: getDisplayRewardNumbers(game, 'reward_1')[0] || '-',
      front3: front3.length ? front3 : ['-'],
      last2: getDisplayRewardNumbers(game, 'reward_two_digit')[0] || '-',
      last3: last3.length ? last3 : ['-']
    }
  }

  return {
    getReward,
    getRewardNumbers,
    getDisplayRewardNumbers,
    getRewardPlaceholder,
    getRewardAmount,
    getRewardGroups,
    isDisplayableRewardNumber,
    isResolvedRewardNumber,
    toSummary
  }
}

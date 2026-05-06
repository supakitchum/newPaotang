export interface LotteryReward {
  id?: number
  game_id?: number
  name: string
  reward: number | string
  slug: string
  number?: string[] | null
}

export interface LotteryRewardGame {
  id?: number
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

const toNumbers = (value: unknown): string[] => {
  if (!Array.isArray(value)) {
    return []
  }

  return value
    .filter((item) => item !== null && item !== undefined && `${item}` !== '')
    .map((item) => `${item}`)
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

  const getRewardAmount = (game: LotteryRewardGame | null | undefined, slug: string) => {
    return formatRewardAmount(getReward(game, slug)?.reward)
  }

  const getRewardGroups = (game: LotteryRewardGame | null | undefined): LotteryRewardGroup[] => {
    return rewardOrder
      .map((slug) => {
        const reward = getReward(game, slug)

        return {
          key: slug,
          title: rewardTitles[slug] || reward?.name || slug,
          amount: formatRewardAmount(reward?.reward),
          numbers: toNumbers(reward?.number)
        }
      })
      .filter((group) => group.numbers.length > 0)
  }

  const toSummary = (game: LotteryRewardGame | null | undefined): LotteryRewardSummary => {
    const front3 = getRewardNumbers(game, 'reward_three_digit_1')
    const last3 = getRewardNumbers(game, 'reward_three_digit_2')

    return {
      first: getRewardNumbers(game, 'reward_1')[0] || '-',
      front3: front3.length ? front3 : ['-'],
      last2: getRewardNumbers(game, 'reward_two_digit')[0] || '-',
      last3: last3.length ? last3 : ['-']
    }
  }

  return {
    getReward,
    getRewardNumbers,
    getRewardAmount,
    getRewardGroups,
    toSummary
  }
}

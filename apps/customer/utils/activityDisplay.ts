type ActivityLike = Record<string, any>

const predictionLabels: Record<string, string> = {
  first_prize_last2: '2 ตัวรางวัลที่ 1',
  first_prize_last3: '3 ตัวรางวัลที่ 1',
  last2: '2 ตัวท้าย'
}

const moneyNumber = (value: unknown) => {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : 0
  }

  if (typeof value === 'string') {
    const parsed = Number(value)

    return Number.isFinite(parsed) ? parsed : 0
  }

  if (value && typeof value === 'object' && 'amount' in value) {
    const amount = Number((value as { amount?: unknown }).amount)

    return Number.isFinite(amount) ? amount / 100 : 0
  }

  return 0
}

export const activityPredictionLabel = (type: unknown) => predictionLabels[String(type || '')] || 'เลขนำโชค'

export const formatActivityBaht = (value: unknown) => {
  const amount = moneyNumber(value)
  const hasSatang = Math.abs(amount % 1) > 0

  return amount.toLocaleString('th-TH', {
    minimumFractionDigits: hasSatang ? 2 : 0,
    maximumFractionDigits: 2
  }) + ' บาท'
}

const selectedPredictionType = (config: ActivityLike) => {
  const direct = String(config.prediction_type || '').trim()

  if (direct) {
    return direct
  }

  const predictionTypes = config.prediction_types && typeof config.prediction_types === 'object'
    ? config.prediction_types
    : {}

  return ['first_prize_last2', 'first_prize_last3', 'last2'].find((type) => predictionTypes[type] !== false) || 'first_prize_last2'
}

const luckyConditionText = (activity: ActivityLike) => {
  const config = activity.config && typeof activity.config === 'object' ? activity.config : {}
  const threshold = Math.max(1, Number(config.threshold_tickets || 1))
  const prediction = activityPredictionLabel(selectedPredictionType(config))
  const rule = String(config.eligibility_rule || 'cumulative_tickets')

  if (rule === 'single_order_exact_tickets') {
    return `ทุก ๆ ${threshold.toLocaleString('th-TH')} ใบใน 1 คำสั่งซื้อ ได้ 1 สิทธิ์ทาย ${prediction}`
  }

  return `ทุก ๆ ${threshold.toLocaleString('th-TH')} ใบที่ซื้อสะสมในงวดนี้ ได้ 1 สิทธิ์ทาย ${prediction}`
}

const cashbackConditionText = (activity: ActivityLike) => {
  const config = activity.config && typeof activity.config === 'object' ? activity.config : {}
  const minimumType = String(config.minimum_type || 'tickets')
  const minimumAmount = moneyNumber(config.min_purchase_amount || 0)
  const minimumTickets = Number(config.min_ticket_count || 0)
  const minimumText = minimumType === 'amount'
    ? (minimumAmount > 0 ? `ยอดซื้อครบ ${formatActivityBaht(minimumAmount)}` : 'ไม่มีขั้นต่ำยอดซื้อ')
    : (minimumTickets > 0 ? `ซื้อสลากครบ ${minimumTickets.toLocaleString('th-TH')} ใบ` : 'ไม่มีขั้นต่ำจำนวนสลาก')
  const percent = Number(config.cashback_percent || 0)
  const reward = String(config.cashback_type || 'percent') === 'fixed'
    ? `รับเงินคืน ${formatActivityBaht(config.fixed_amount || 0)}`
    : (percent > 0 ? `รับเงินคืน ${percent.toLocaleString('th-TH')}% ของยอดซื้อ` : 'รับเงินคืนตามเงื่อนไขกิจกรรม')

  return `ไม่ถูกรางวัลและ${minimumText} ${reward}`
}

export const activityConditionText = (activity: ActivityLike | null | undefined) => {
  if (!activity) {
    return ''
  }

  return String(activity.type || '') === 'cashback'
    ? cashbackConditionText(activity)
    : luckyConditionText(activity)
}

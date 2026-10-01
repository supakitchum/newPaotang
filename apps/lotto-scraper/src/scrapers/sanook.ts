import { createHash } from 'node:crypto'
import { load } from 'cheerio'
import { z } from 'zod'
import type { LivePrizeGroup, PrizeType, ScrapeResult } from '../types.js'

const prizeRules: Record<PrizeType, { count: number, digits: number }> = {
  first_prize: { count: 1, digits: 6 },
  near_first_prize: { count: 2, digits: 6 },
  second_prize: { count: 5, digits: 6 },
  third_prize: { count: 10, digits: 6 },
  fourth_prize: { count: 50, digits: 6 },
  fifth_prize: { count: 100, digits: 6 },
  front3: { count: 2, digits: 3 },
  back3: { count: 2, digits: 3 },
  back2: { count: 1, digits: 2 }
}

const resultSchema = z.object({
  source: z.literal('sanook'),
  draw_code: z.string().regex(/^[0-9]{8}$/),
  draw_date: z.string().regex(/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/),
  scraped_at: z.string(),
  completion_percent: z.number().min(0).max(100),
  payload_hash: z.string().min(16),
  prizes: z.array(z.object({
    prize_type: z.enum([
      'first_prize',
      'near_first_prize',
      'second_prize',
      'third_prize',
      'fourth_prize',
      'fifth_prize',
      'front3',
      'back3',
      'back2'
    ]),
    prize_numbers: z.array(z.string())
  }))
})

export const buildSanookUrl = (sourceBaseUrl: string, drawCode: string) => `${sourceBaseUrl.replace(/\/$/, '')}/${drawCode}/`

export const fetchSanookHtml = async (sourceBaseUrl: string, drawCode: string) => {
  const { request } = await import('undici')
  const url = buildSanookUrl(sourceBaseUrl, drawCode)
  const response = await request(url, {
    method: 'GET',
    headers: {
      'user-agent': 'newpaotang-lotto-scraper/0.1 (+https://newpaotang.local)',
      accept: 'text/html,application/xhtml+xml'
    }
  })

  if (response.statusCode >= 400) {
    const error = new Error(`Sanook responded with ${response.statusCode}`)
    Object.assign(error, { statusCode: response.statusCode })
    throw error
  }

  return {
    url,
    html: await response.body.text()
  }
}

export const parseSanookLottoHtml = (html: string, drawCode: string, sourceUrl: string, scrapedAt = new Date().toISOString(), drawDate = drawDateFromCode(drawCode)): ScrapeResult => {
  const $ = load(html)
  const groups: LivePrizeGroup[] = withComputedNearFirstPrize([
    group('first_prize', firstPrizeNumbers($)),
    group('front3', columnNumbers($, 'เลขหน้า 3 ตัว')),
    group('back3', columnNumbers($, 'เลขท้าย 3 ตัว')),
    group('back2', columnNumbers($, 'เลขท้าย 2 ตัว')),
    group('near_first_prize', sectionNumbers($, 'รางวัลข้างเคียงรางวัลที่ 1')),
    group('second_prize', sectionNumbers($, 'รางวัลที่ 2')),
    group('third_prize', sectionNumbers($, 'รางวัลที่ 3')),
    group('fourth_prize', sectionNumbers($, 'รางวัลที่ 4')),
    group('fifth_prize', sectionNumbers($, 'รางวัลที่ 5'))
  ].map(padGroup))

  const completedPercent = completionPercent(groups)
  const canonical = JSON.stringify({
    source: 'sanook',
    draw_code: drawCode,
    draw_date: drawDate,
    prizes: groups
  })
  const payloadHash = createHash('sha256').update(canonical).digest('hex')
  const payload = {
    source: 'sanook' as const,
    draw_code: drawCode,
    draw_date: drawDate,
    scraped_at: scrapedAt,
    completion_percent: completedPercent,
    payload_hash: payloadHash,
    prizes: groups
  }

  resultSchema.parse(payload)

  return {
    ...payload,
    source_url: sourceUrl,
    is_complete: completedPercent === 100
  }
}

const group = (prizeType: PrizeType, prizeNumbers: string[]): LivePrizeGroup => ({
  prize_type: prizeType,
  prize_numbers: prizeNumbers.map(normalizeNumber).filter(Boolean)
})

const firstPrizeNumbers = ($: ReturnType<typeof load>) => numbersFrom($, $('.lotto__number--first').first())

const columnNumbers = ($: ReturnType<typeof load>, title: string) => {
  const column = $('.lottocheck__column').filter((_, element) => $(element).text().includes(title)).first()

  return numbersFrom($, column)
}

const sectionNumbers = ($: ReturnType<typeof load>, title: string) => {
  const section = $('.lottocheck__sec').filter((_, element) => $(element).text().includes(title)).first()

  return numbersFrom($, section)
}

const numbersFrom = ($: ReturnType<typeof load>, element: any) => {
  const targets = element.is?.('.lotto__number') ? element : element.find('.lotto__number')

  return targets
    .map((_: number, numberElement: any) => normalizeNumber($(numberElement).text()))
    .get()
    .filter(Boolean)
}

const padGroup = (prize: LivePrizeGroup): LivePrizeGroup => {
  const rule = prizeRules[prize.prize_type]
  const placeholder = 'x'.repeat(rule.digits)
  const seen = new Set<string>()
  const numbers = prize.prize_numbers.reduce<string[]>((items, number) => {
    const normalized = normalizePrizeNumber(number, rule.digits)

    if (isPlaceholder(normalized, rule.digits)) {
      return items
    }

    if (seen.has(normalized)) {
      return items
    }

    seen.add(normalized)
    items.push(normalized)

    return items
  }, []).slice(0, rule.count)

  while (numbers.length < rule.count) {
    numbers.push(placeholder)
  }

  return {
    prize_type: prize.prize_type,
    prize_numbers: numbers
  }
}

const normalizeNumber = (value: string) => value.replace(/\s+/g, '').trim().toLowerCase()

const normalizePrizeNumber = (value: string, digits: number) => {
  const normalized = normalizeNumber(value)
  const placeholder = 'x'.repeat(digits)

  if (new RegExp(`^[0-9]{${digits}}$`).test(normalized)) {
    return normalized
  }

  if (isPlaceholder(normalized, digits)) {
    return placeholder
  }

  return placeholder
}

const withComputedNearFirstPrize = (groups: LivePrizeGroup[]) => {
  const firstPrize = groups.find((prize) => prize.prize_type === 'first_prize')
  const firstPrizeNumber = firstPrize?.prize_numbers[0] || ''

  return groups.map((prize) => (
    prize.prize_type === 'near_first_prize'
      ? { ...prize, prize_numbers: computedNearFirstPrizeNumbers(firstPrizeNumber) }
      : prize
  ))
}

const computedNearFirstPrizeNumbers = (firstPrizeNumber: string) => {
  const normalized = normalizePrizeNumber(firstPrizeNumber, 6)
  if (!/^[0-9]{6}$/.test(normalized)) {
    return ['xxxxxx', 'xxxxxx']
  }

  const value = Number(normalized)
  const previous = (value + 999999) % 1000000
  const next = (value + 1) % 1000000

  return [previous, next].map((number) => String(number).padStart(6, '0'))
}

const completionPercent = (groups: LivePrizeGroup[]) => {
  let total = 0
  let completed = 0

  for (const prize of groups) {
    const rule = prizeRules[prize.prize_type]
    total += rule.count
    completed += prize.prize_numbers.filter((number) => !isPlaceholder(number, rule.digits)).length
  }

  return total === 0 ? 0 : Math.round((completed / total) * 10000) / 100
}

const isPlaceholder = (number: string, digits: number) => new RegExp(`^x{${digits}}$`, 'i').test(number)

export const drawDateFromCode = (drawCode: string) => {
  const day = drawCode.slice(0, 2)
  const month = drawCode.slice(2, 4)
  const buddhistYear = Number(drawCode.slice(4, 8))
  const year = buddhistYear - 543

  return `${year}-${month}-${day}`
}

export const isCompleteResult = (groups: LivePrizeGroup[]) => completionPercent(groups) === 100

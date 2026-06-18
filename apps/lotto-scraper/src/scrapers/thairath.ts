import { createHash } from 'node:crypto'
import { load } from 'cheerio'
import { request } from 'undici'
import { z } from 'zod'
import type { LivePrizeGroup, PrizeType, ScrapeResult } from '../types.js'
import { drawDateFromCode } from './sanook.js'

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

const thairathPrizeKeys: Record<PrizeType, string> = {
  first_prize: '1',
  second_prize: '2',
  third_prize: '3',
  fourth_prize: '4',
  fifth_prize: '5',
  front3: '10',
  back2: '7',
  back3: '6',
  near_first_prize: '11'
}

const resultSchema = z.object({
  source: z.literal('thairath'),
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

export const buildThairathUrl = (sourceBaseUrl: string, drawCode: string) => {
  const url = new URL(sourceBaseUrl)
  url.searchParams.set('date', drawDateFromCode(drawCode))

  return url.toString()
}

export const fetchThairathHtml = async (sourceBaseUrl: string, drawCode: string) => {
  const url = buildThairathUrl(sourceBaseUrl, drawCode)
  const response = await request(url, {
    method: 'GET',
    headers: {
      'user-agent': 'newpaotang-lotto-scraper/0.1 (+https://newpaotang.local)',
      accept: 'text/html,application/xhtml+xml'
    }
  })

  if (response.statusCode >= 400) {
    const error = new Error(`ThaiRath responded with ${response.statusCode}`)
    Object.assign(error, { statusCode: response.statusCode })
    throw error
  }

  return {
    url,
    html: await response.body.text()
  }
}

export const parseThairathLottoHtml = (html: string, drawCode: string, sourceUrl: string, scrapedAt = new Date().toISOString(), drawDate = drawDateFromCode(drawCode)): ScrapeResult => {
  const prizes = nextDataPrizes(html)
  const groups = withComputedNearFirstPrizeFallback([
    group('first_prize', prizeNumbers(prizes, 'first_prize')),
    group('front3', prizeNumbers(prizes, 'front3')),
    group('back3', prizeNumbers(prizes, 'back3')),
    group('back2', prizeNumbers(prizes, 'back2')),
    group('near_first_prize', prizeNumbers(prizes, 'near_first_prize')),
    group('second_prize', prizeNumbers(prizes, 'second_prize')),
    group('third_prize', prizeNumbers(prizes, 'third_prize')),
    group('fourth_prize', prizeNumbers(prizes, 'fourth_prize')),
    group('fifth_prize', prizeNumbers(prizes, 'fifth_prize'))
  ].map(padGroup))

  const completedPercent = completionPercent(groups)
  const canonical = JSON.stringify({
    source: 'thairath',
    draw_code: drawCode,
    draw_date: drawDate,
    prizes: groups
  })
  const payloadHash = createHash('sha256').update(canonical).digest('hex')
  const payload = {
    source: 'thairath' as const,
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

const nextDataPrizes = (html: string): Record<string, any> => {
  const $ = load(html)
  const raw = $('#__NEXT_DATA__').first().text()

  if (raw.trim() === '') {
    throw new Error('ThaiRath __NEXT_DATA__ payload was not found.')
  }

  const parsed = JSON.parse(raw)
  const prizes = parsed?.props?.initialState?.lottery?.data?.items?.prizes

  if (!prizes || typeof prizes !== 'object') {
    throw new Error('ThaiRath lottery prizes payload was not found.')
  }

  return prizes
}

const prizeNumbers = (prizes: Record<string, any>, prizeType: PrizeType) => {
  const key = thairathPrizeKeys[prizeType]
  const data = prizes?.[key]?.data

  return Array.isArray(data) ? data.map((number) => String(number)) : []
}

const group = (prizeType: PrizeType, prizeNumbers: string[]): LivePrizeGroup => ({
  prize_type: prizeType,
  prize_numbers: prizeNumbers.map(normalizeNumber).filter(Boolean)
})

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

const withComputedNearFirstPrizeFallback = (groups: LivePrizeGroup[]) => {
  const firstPrizeNumber = groups.find((prize) => prize.prize_type === 'first_prize')?.prize_numbers[0] || ''

  return groups.map((prize) => {
    if (prize.prize_type !== 'near_first_prize') {
      return prize
    }

    const rule = prizeRules.near_first_prize
    const hasRealNearby = prize.prize_numbers.some((number) => !isPlaceholder(number, rule.digits))

    return hasRealNearby ? prize : { ...prize, prize_numbers: computedNearFirstPrizeNumbers(firstPrizeNumber) }
  })
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

const isPlaceholder = (number: string, digits: number) => new RegExp(`^x{1,${digits}}$`, 'i').test(number)

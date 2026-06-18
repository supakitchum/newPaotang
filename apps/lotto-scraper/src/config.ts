import type { ScrapeSource } from './types.js'

export type ScraperConfig = {
  source: ScrapeSource
  sourceBaseUrl: string
  platformApiUrl: string
  hmacSecret: string
  redisUrl: string
  healthPort: number
  triggerSecret: string
  triggerSignatureTtlSeconds: number
  timezone: string
  drawCode: string
  minCrawlDelayMs: number
  warmupPollMs: number
  livePollMinMs: number
  livePollMaxMs: number
  tailPollMinMs: number
  tailPollMaxMs: number
  lockTtlMs: number
}

const integerEnv = (name: string, fallback: number) => {
  const value = Number(process.env[name])

  return Number.isFinite(value) && value > 0 ? Math.round(value) : fallback
}

const sourceEnv = (): ScrapeSource => {
  const value = (process.env.LOTTO_SCRAPER_SOURCE || 'sanook').trim().toLowerCase()

  return value === 'thairath' ? 'thairath' : 'sanook'
}

const source = sourceEnv()
const defaultSourceBaseUrl = source === 'thairath'
  ? 'https://www.thairath.co.th/lottery/check'
  : 'https://news.sanook.com/lotto/check'

export const config: ScraperConfig = {
  source,
  sourceBaseUrl: process.env.LOTTO_SCRAPER_SOURCE_BASE_URL || defaultSourceBaseUrl,
  platformApiUrl: (process.env.LOTTO_SCRAPER_PLATFORM_API_URL || 'http://platform-api:8000/api/v1').replace(/\/$/, ''),
  hmacSecret: process.env.LOTTO_SCRAPER_HMAC_SECRET || 'newpaotang-local-lotto-scraper-secret',
  redisUrl: process.env.LOTTO_SCRAPER_REDIS_URL || 'redis://valkey:6379',
  healthPort: integerEnv('LOTTO_SCRAPER_HEALTH_PORT', 3200),
  triggerSecret: process.env.LOTTO_SCRAPER_TRIGGER_SECRET || process.env.LOTTO_SCRAPER_HMAC_SECRET || 'newpaotang-local-lotto-scraper-secret',
  triggerSignatureTtlSeconds: integerEnv('LOTTO_SCRAPER_TRIGGER_SIGNATURE_TTL_SECONDS', 300),
  timezone: process.env.TZ || process.env.LOTTO_SCRAPER_TIMEZONE || 'Asia/Bangkok',
  drawCode: (process.env.LOTTO_SCRAPER_DRAW_CODE || '').trim(),
  minCrawlDelayMs: Math.max(10000, integerEnv('LOTTO_SCRAPER_MIN_CRAWL_DELAY_MS', 10000)),
  warmupPollMs: integerEnv('LOTTO_SCRAPER_POLL_WARMUP_MS', 60000),
  livePollMinMs: integerEnv('LOTTO_SCRAPER_POLL_LIVE_MIN_MS', 10000),
  livePollMaxMs: integerEnv('LOTTO_SCRAPER_POLL_LIVE_MAX_MS', 15000),
  tailPollMinMs: integerEnv('LOTTO_SCRAPER_POLL_TAIL_MIN_MS', 30000),
  tailPollMaxMs: integerEnv('LOTTO_SCRAPER_POLL_TAIL_MAX_MS', 60000),
  lockTtlMs: integerEnv('LOTTO_SCRAPER_LOCK_TTL_MS', 30000)
}

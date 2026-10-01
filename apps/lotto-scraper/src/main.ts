import { randomUUID } from 'node:crypto'
import { setTimeout as sleep } from 'node:timers/promises'
import { config } from './config.js'
import { PlatformApiClient } from './clients/platformApi.js'
import { startHealthServer } from './http/health.js'
import { logger } from './logger.js'
import { BackoffState, shouldBackoffForStatus } from './scheduler/backoff.js'
import { applyJitter, currentDrawWindow } from './scheduler/drawWindow.js'
import { fetchSanookHtml, parseSanookLottoHtml } from './scrapers/sanook.js'
import { fetchThairathHtml, parseThairathLottoHtml } from './scrapers/thairath.js'
import { StateStore } from './state/store.js'
import type { ScrapeResult } from './types.js'

const instanceId = randomUUID()
const state = {
  startedAt: new Date().toISOString(),
  lastPollAt: null as string | null,
  lastIngestAt: null as string | null,
  lastError: null as string | null,
  phase: 'starting',
  source: config.source,
  drawCode: config.drawCode,
  ready: async () => false
}

const store = new StateStore(config.redisUrl)
const platformApi = new PlatformApiClient(config.platformApiUrl, config.hmacSecret)
const backoff = new BackoffState()
let stableCompleteCount = 0
const completedDraws = new Set<string>()

type FailedIngestState = {
  payload_hash: string
  status_code: number | null
  message: string
  failed_at: string
}

startHealthServer(config.healthPort, state, {
  triggerSecret: config.triggerSecret,
  triggerSignatureTtlSeconds: config.triggerSignatureTtlSeconds,
  triggerPoll: async ({ drawCode, drawDate, forceIngest, reason }) => {
    const result = await pollDraw(drawCode, {
      drawDate,
      forceIngest,
      reason,
      throwOnError: true
    })

    return {
      ingested: Boolean(result),
      completion_percent: result?.completion_percent ?? null,
      payload_hash: result?.payload_hash ?? null,
      is_complete: result?.is_complete ?? false
    }
  }
})
logger.info({ config: redactedConfig() }, 'Lotto scraper starting.')

try {
  await store.connect()
} catch (error) {
  logger.warn({ error }, 'Redis unavailable at startup; using local lock/dedupe fallback until restart.')
}

state.ready = async () => {
  const [storeReady, apiReady] = await Promise.allSettled([
    store.ready(),
    platformApi.ready()
  ])

  return storeReady.status === 'fulfilled' && storeReady.value && apiReady.status === 'fulfilled' && apiReady.value
}

process.on('SIGTERM', () => void shutdown('SIGTERM'))
process.on('SIGINT', () => void shutdown('SIGINT'))

while (true) {
  const window = currentDrawWindow(new Date(), {
    ...config,
    configuredDrawCode: config.drawCode
  })
  state.phase = window.phase
  state.drawCode = window.drawCode

  if (!window.shouldPoll) {
    stableCompleteCount = 0
    await sleep(window.intervalMs)
    continue
  }

  if (completedDraws.has(window.drawCode)) {
    await sleep(60_000)
    continue
  }

  if (backoff.active()) {
    await sleep(Math.min(backoff.remainingMs(), window.intervalMs))
    continue
  }

  const result = await pollDraw(window.drawCode)
  if (result?.is_complete) {
    stableCompleteCount += 1
    if (stableCompleteCount >= 3) {
      logger.info({ draw_code: window.drawCode }, 'Complete result was stable for 3 polls; stopping until the next window.')
      completedDraws.add(window.drawCode)
      await sleep(60_000)
      continue
    }
  } else {
    stableCompleteCount = 0
  }

  await sleep(applyJitter(window.intervalMs))
}

type PollOptions = {
  drawDate?: string | null
  forceIngest?: boolean
  reason?: string
  throwOnError?: boolean
}

async function pollDraw(drawCode: string, options: PollOptions = {}) {
  const sourceKey = `${config.source}:${drawCode}`
  const lockAcquired = await store.acquireLock(sourceKey, instanceId, config.lockTtlMs)

  if (!lockAcquired) {
    logger.debug({ source: config.source, draw_code: drawCode }, 'Another scraper instance holds the draw lock.')
    return null
  }

  try {
    state.lastPollAt = new Date().toISOString()
    const parsed = await scrapeDraw(drawCode, options.drawDate || null)
    const previousHash = await store.getHash(sourceKey)
    const failedIngest = await store.getJson<FailedIngestState>(failedIngestKey(config.source, drawCode))

    backoff.recordSuccess()

    if (previousHash === parsed.payload_hash && options.forceIngest !== true) {
      logger.info({ source: config.source, draw_code: drawCode, draw_date: parsed.draw_date, completion_percent: parsed.completion_percent }, 'Scraped result unchanged; skipping ingest.')
      return parsed
    }

    if (failedIngest?.payload_hash === parsed.payload_hash && options.forceIngest !== true) {
      state.lastError = failedIngest.message
      logger.warn({
        source: config.source,
        draw_code: drawCode,
        draw_date: parsed.draw_date,
        completion_percent: parsed.completion_percent,
        payload_hash: parsed.payload_hash,
        status_code: failedIngest.status_code,
        failed_at: failedIngest.failed_at
      }, 'Scraped result matches the last failed ingest payload; skipping until source changes.')

      return parsed
    }

    try {
      await platformApi.ingestResult(parsed)
    } catch (error: any) {
      await cacheFailedIngest(drawCode, parsed, error)
      throw error
    }

    await store.setHash(sourceKey, parsed.payload_hash)
    await store.delete(failedIngestKey(config.source, drawCode))
    state.lastIngestAt = new Date().toISOString()
    state.lastError = null
    logger.info({
      source: config.source,
      draw_code: drawCode,
      draw_date: parsed.draw_date,
      completion_percent: parsed.completion_percent,
      payload_hash: parsed.payload_hash,
      force_ingest: options.forceIngest === true,
      reason: options.reason || 'scheduled_poll'
    }, options.forceIngest === true ? 'Force-ingested live draft result.' : 'Ingested live draft result.')

    return parsed
  } catch (error: any) {
    state.lastError = error?.message || String(error)
    const statusCode = Number(error?.statusCode)

    if (shouldBackoffForStatus(statusCode)) {
      const delay = backoff.recordFailure()
      logger.warn({ error, statusCode, delay }, 'Source/API error triggered scraper backoff.')
    } else {
      logger.error({ error }, 'Lotto scraper poll failed.')
    }

    if (options.throwOnError === true) {
      throw error
    }

    return null
  }
}

async function scrapeDraw(drawCode: string, drawDate: string | null = null) {
  const fetchDrawCode = drawDateToDrawCode(drawDate) || drawCode

  if (config.source === 'thairath') {
    const { url, html } = await fetchThairathHtml(config.sourceBaseUrl, fetchDrawCode)
    return parseThairathLottoHtml(html, drawCode, url, new Date().toISOString(), drawDate || undefined)
  }

  const { url, html } = await fetchSanookHtml(config.sourceBaseUrl, fetchDrawCode)
  return parseSanookLottoHtml(html, drawCode, url, new Date().toISOString(), drawDate || undefined)
}

async function cacheFailedIngest(drawCode: string, parsed: ScrapeResult, error: any) {
  const statusCode = Number(error?.statusCode)

  if (statusCode !== 422) {
    return
  }

  await store.setJson(failedIngestKey(parsed.source, drawCode), {
    payload_hash: parsed.payload_hash,
    status_code: Number.isFinite(statusCode) ? statusCode : null,
    message: error?.message || String(error),
    failed_at: new Date().toISOString()
  } satisfies FailedIngestState, 6 * 60 * 60 * 1000)
}

function failedIngestKey(source: string, drawCode: string) {
  return `lotto-scraper:failed-ingest:${source}:${drawCode}`
}

function drawDateToDrawCode(drawDate: string | null) {
  if (!drawDate || !/^\d{4}-\d{2}-\d{2}$/.test(drawDate)) {
    return null
  }

  const [year, month, day] = drawDate.split('-')
  const buddhistYear = Number(year) + 543

  if (!Number.isFinite(buddhistYear)) {
    return null
  }

  return `${day}${month}${buddhistYear}`
}

async function shutdown(signal: string) {
  logger.info({ signal }, 'Lotto scraper shutting down.')
  await store.close()
  process.exit(0)
}

function redactedConfig() {
  return {
    ...config,
    hmacSecret: config.hmacSecret ? '[redacted]' : ''
  }
}

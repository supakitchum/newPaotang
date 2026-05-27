import { randomUUID } from 'node:crypto'
import { setTimeout as sleep } from 'node:timers/promises'
import { config } from './config.js'
import { PlatformApiClient } from './clients/platformApi.js'
import { startHealthServer } from './http/health.js'
import { logger } from './logger.js'
import { BackoffState, shouldBackoffForStatus } from './scheduler/backoff.js'
import { applyJitter, currentDrawWindow } from './scheduler/drawWindow.js'
import { fetchSanookHtml, parseSanookLottoHtml } from './scrapers/sanook.js'
import { StateStore } from './state/store.js'

const instanceId = randomUUID()
const state = {
  startedAt: new Date().toISOString(),
  lastPollAt: null as string | null,
  lastIngestAt: null as string | null,
  lastError: null as string | null,
  phase: 'starting',
  drawCode: config.drawCode,
  ready: async () => false
}

const store = new StateStore(config.redisUrl)
const platformApi = new PlatformApiClient(config.platformApiUrl, config.hmacSecret)
const backoff = new BackoffState()
let stableCompleteCount = 0
const completedDraws = new Set<string>()

startHealthServer(config.healthPort, state)
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

async function pollDraw(drawCode: string) {
  const lockAcquired = await store.acquireLock(drawCode, instanceId, config.lockTtlMs)

  if (!lockAcquired) {
    logger.debug({ draw_code: drawCode }, 'Another scraper instance holds the draw lock.')
    return null
  }

  try {
    state.lastPollAt = new Date().toISOString()
    const { url, html } = await fetchSanookHtml(config.sourceBaseUrl, drawCode)
    const parsed = parseSanookLottoHtml(html, drawCode, url)
    const previousHash = await store.getHash(drawCode)

    backoff.recordSuccess()

    if (previousHash === parsed.payload_hash) {
      logger.info({ draw_code: drawCode, completion_percent: parsed.completion_percent }, 'Sanook result unchanged; skipping ingest.')
      return parsed
    }

    await platformApi.ingestSanookResult(parsed)
    await store.setHash(drawCode, parsed.payload_hash)
    state.lastIngestAt = new Date().toISOString()
    state.lastError = null
    logger.info({
      draw_code: drawCode,
      completion_percent: parsed.completion_percent,
      payload_hash: parsed.payload_hash
    }, 'Ingested live draft result.')

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

    return null
  }
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

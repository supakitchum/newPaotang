import { createHmac, timingSafeEqual } from 'node:crypto'
import { createServer } from 'node:http'

type HealthState = {
  startedAt: string
  lastPollAt: string | null
  lastIngestAt: string | null
  lastError: string | null
  phase: string
  source: string
  drawCode: string
  ready: () => Promise<boolean>
}

type TriggerPollPayload = {
  drawCode: string
  drawDate: string | null
  source: string | null
  forceIngest: boolean
  reason: string
}

type HealthServerOptions = {
  triggerSecret?: string
  triggerSignatureTtlSeconds?: number
  triggerPoll?: (payload: TriggerPollPayload) => Promise<unknown>
}

export const startHealthServer = (port: number, state: HealthState, options: HealthServerOptions = {}) => {
  const server = createServer(async (request, response) => {
    const url = new URL(request.url || '/', 'http://lotto-scraper.local')

    if (request.method === 'OPTIONS') {
      response.writeHead(204, corsHeaders())
      response.end()
      return
    }

    if (url.pathname === '/healthz') {
      json(response, 200, {
        ok: true,
        service: 'lotto-scraper',
        started_at: state.startedAt,
        phase: state.phase,
        source: state.source,
        draw_code: state.drawCode,
        last_poll_at: state.lastPollAt,
        last_ingest_at: state.lastIngestAt,
        last_error: state.lastError
      })
      return
    }

    if (url.pathname === '/readyz') {
      const ready = await state.ready()
      json(response, ready ? 200 : 503, { ready })
      return
    }

    if (url.pathname === '/metrics') {
      response.writeHead(200, { ...corsHeaders(), 'content-type': 'text/plain; charset=utf-8' })
      response.end([
        '# HELP lotto_scraper_up Scraper process is running',
        '# TYPE lotto_scraper_up gauge',
        'lotto_scraper_up 1'
      ].join('\n') + '\n')
      return
    }

    if (url.pathname === '/internal/poll' && request.method === 'POST') {
      if (!options.triggerPoll) {
        json(response, 503, { ok: false, error: 'trigger_unavailable' })
        return
      }

      let rawBody = ''

      try {
        rawBody = await readBody(request)
      } catch (error: any) {
        json(response, 413, { ok: false, error: error?.message || 'request_body_too_large' })
        return
      }

      const authError = verifySignedRequest(request, rawBody, options)

      if (authError !== null) {
        json(response, 401, { ok: false, error: authError })
        return
      }

      let payload: any = null

      try {
        payload = JSON.parse(rawBody || '{}')
      } catch {
        json(response, 400, { ok: false, error: 'invalid_json' })
        return
      }

      const drawCode = String(payload?.draw_code || payload?.drawCode || '').trim()
      const requestedSource = normalizeSource(payload?.source)
      const drawDate = normalizeDrawDate(payload?.draw_date || payload?.drawDate || null)

      if (!/^\d{8}$/.test(drawCode)) {
        json(response, 422, { ok: false, error: 'invalid_draw_code' })
        return
      }

      if (requestedSource !== null && requestedSource !== state.source) {
        json(response, 409, {
          ok: false,
          error: 'source_mismatch',
          message: `This scraper serves ${state.source}, but trigger requested ${requestedSource}.`
        })
        return
      }

      if (drawDate === false) {
        json(response, 422, { ok: false, error: 'invalid_draw_date' })
        return
      }

      try {
        const result = await options.triggerPoll({
          drawCode,
          drawDate,
          source: requestedSource,
          forceIngest: payload?.force !== false && payload?.force_ingest !== false,
          reason: String(payload?.reason || 'manual_trigger').trim() || 'manual_trigger'
        })

        json(response, 202, { ok: true, source: state.source, draw_code: drawCode, draw_date: drawDate, result })
      } catch (error: any) {
        json(response, 502, {
          ok: false,
          source: state.source,
          draw_code: drawCode,
          draw_date: drawDate,
          error: 'trigger_poll_failed',
          message: error?.message || String(error)
        })
      }

      return
    }

    json(response, 404, { error: 'not_found' })
  })

  server.listen(port, '0.0.0.0')

  return server
}

const readBody = async (request: any, maxBytes = 65536) => {
  const chunks: Buffer[] = []
  let bytes = 0

  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
    bytes += buffer.length

    if (bytes > maxBytes) {
      throw new Error('request_body_too_large')
    }

    chunks.push(buffer)
  }

  return Buffer.concat(chunks).toString('utf8')
}

const verifySignedRequest = (request: any, rawBody: string, options: HealthServerOptions) => {
  const secret = String(options.triggerSecret || '').trim()

  if (secret === '') {
    return null
  }

  const timestamp = String(request.headers['x-lotto-scraper-timestamp'] || '').trim()
  const signature = String(request.headers['x-lotto-scraper-signature'] || '').trim()

  if (!/^\d+$/.test(timestamp) || signature === '') {
    return 'missing_signature'
  }

  const ttlSeconds = Math.max(60, Number(options.triggerSignatureTtlSeconds || 300))
  const ageSeconds = Math.abs(Math.floor(Date.now() / 1000) - Number(timestamp))

  if (ageSeconds > ttlSeconds) {
    return 'expired_signature'
  }

  const expected = 'sha256=' + createHmac('sha256', secret)
    .update(`${timestamp}.${rawBody}`)
    .digest('hex')

  if (!safeEquals(signature, expected)) {
    return 'invalid_signature'
  }

  return null
}

const safeEquals = (left: string, right: string) => {
  const leftBuffer = Buffer.from(left)
  const rightBuffer = Buffer.from(right)

  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer)
}

const json = (response: any, statusCode: number, payload: unknown) => {
  response.writeHead(statusCode, { ...corsHeaders(), 'content-type': 'application/json; charset=utf-8' })
  response.end(JSON.stringify(payload))
}

const corsHeaders = () => ({
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET,OPTIONS',
  'access-control-allow-headers': 'content-type'
})

const normalizeSource = (value: unknown) => {
  const source = String(value || '').trim().toLowerCase()

  if (source === '') {
    return null
  }

  if (source === 'sanook' || source === 'thairath') {
    return source
  }

  return null
}

const normalizeDrawDate = (value: unknown): string | null | false => {
  if (value === null || value === undefined || String(value).trim() === '') {
    return null
  }

  const drawDate = String(value).trim()

  return /^\d{4}-\d{2}-\d{2}$/.test(drawDate) ? drawDate : false
}

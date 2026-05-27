import { createServer } from 'node:http'

type HealthState = {
  startedAt: string
  lastPollAt: string | null
  lastIngestAt: string | null
  lastError: string | null
  phase: string
  drawCode: string
  ready: () => Promise<boolean>
}

export const startHealthServer = (port: number, state: HealthState) => {
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

    json(response, 404, { error: 'not_found' })
  })

  server.listen(port, '0.0.0.0')

  return server
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

import { createHmac } from 'node:crypto'
import { request } from 'undici'
import type { LiveResultPayload } from '../types.js'

export class PlatformApiClient {
  constructor(
    private readonly baseUrl: string,
    private readonly hmacSecret: string
  ) {
  }

  async ingestSanookResult(payload: LiveResultPayload) {
    const body = JSON.stringify(payload)
    const timestamp = Math.floor(Date.now() / 1000).toString()
    const signature = 'sha256=' + createHmac('sha256', this.hmacSecret)
      .update(`${timestamp}.${body}`)
      .digest('hex')
    const response = await request(`${this.baseUrl}/internal/reward-ingest/sanook`, {
      method: 'POST',
      body,
      headers: {
        'content-type': 'application/json',
        'x-lotto-scraper-timestamp': timestamp,
        'x-lotto-scraper-signature': signature,
        'x-request-id': `req_lotto_scraper_${Date.now()}`
      }
    })
    const responseBody = await response.body.text()

    if (response.statusCode >= 400) {
      const error = new Error(`Platform API ingest failed with ${response.statusCode}: ${responseBody}`)
      Object.assign(error, { statusCode: response.statusCode, responseBody })
      throw error
    }

    return responseBody ? JSON.parse(responseBody) : {}
  }

  async ready() {
    const response = await request(`${this.baseUrl}/health/ready`, { method: 'GET' })
    await response.body.dump()

    return response.statusCode < 500
  }
}

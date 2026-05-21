import { request as httpRequest, type IncomingHttpHeaders } from 'node:http'
import { request as httpsRequest } from 'node:https'
import { normalizeTenantHost } from '~/utils/tenantHost'

const forwardHeaders = [
  'accept',
  'accept-language',
  'authorization',
  'content-type',
  'idempotency-key',
  'x-request-id'
]

const responseHeaders = [
  'content-type',
  'date',
  'retry-after',
  'x-request-id',
  'ratelimit-limit',
  'ratelimit-remaining',
  'ratelimit-reset'
]

const createRequestId = () => `req_customer_proxy_${Date.now()}_${Math.random().toString(36).slice(2)}`

const requestPlatformApi = (
  targetUrl: URL,
  method: string,
  headers: Record<string, string>,
  body?: Buffer | string
) => new Promise<{
  statusCode: number
  statusMessage: string
  headers: IncomingHttpHeaders
  body: Buffer
}>((resolve, reject) => {
  const request = targetUrl.protocol === 'https:' ? httpsRequest : httpRequest
  const proxyRequest = request(targetUrl, { method, headers }, (response) => {
    const chunks: Buffer[] = []

    response.on('data', (chunk) => {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk))
    })

    response.on('end', () => {
      resolve({
        statusCode: response.statusCode || 502,
        statusMessage: response.statusMessage || 'Bad Gateway',
        headers: response.headers,
        body: Buffer.concat(chunks)
      })
    })
  })

  proxyRequest.on('error', reject)

  if (body) {
    proxyRequest.write(body)
  }

  proxyRequest.end()
})

export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const requestUrl = getRequestURL(event)
  const targetBaseUrl = String(config.platformApiInternalBaseUrl || 'http://platform-api:8000/api/v1').replace(/\/$/, '')
  const path = requestUrl.pathname.replace(/^\/api\/v1\/?/, '')
  const targetUrl = new URL(path, `${targetBaseUrl}/`)

  targetUrl.search = requestUrl.search

  const incomingHeaders = getHeaders(event)
  const headers: Record<string, string> = {}
  const tenantHost = normalizeTenantHost(incomingHeaders.host)

  for (const headerName of forwardHeaders) {
    const value = incomingHeaders[headerName]

    if (typeof value === 'string' && value) {
      headers[headerName] = value
    }
  }

  if (tenantHost) {
    headers.host = tenantHost
  }

  if (!headers['x-request-id']) {
    headers['x-request-id'] = createRequestId()
  }

  const method = getMethod(event)
  const body = ['GET', 'HEAD'].includes(method) ? undefined : await readRawBody(event, false)
  const response = await requestPlatformApi(targetUrl, method, headers, body)

  setResponseStatus(event, response.statusCode, response.statusMessage)
  setHeader(event, 'vary', 'Host')

  for (const headerName of responseHeaders) {
    const value = response.headers[headerName]

    if (value) {
      setHeader(event, headerName, value)
    }
  }

  return response.body
})

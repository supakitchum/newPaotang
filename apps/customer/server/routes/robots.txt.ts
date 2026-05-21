import { normalizeTenantHost } from '~/utils/tenantHost'

export default defineEventHandler(async (event) => {
  setHeader(event, 'content-type', 'text/plain; charset=utf-8')
  setHeader(event, 'cache-control', 'no-store')
  setHeader(event, 'vary', 'Host')

  const config = useRuntimeConfig()
  const host = normalizeTenantHost(getHeader(event, 'host') || '')
  const baseUrl = String(config.platformApiInternalBaseUrl || config.public.apiBaseUrl || '/api/v1')
  const origin = `https://${host}`
  const apiBaseUrl = /^https?:\/\//i.test(baseUrl) ? baseUrl : `${origin}${baseUrl.startsWith('/') ? baseUrl : `/${baseUrl}`}`

  try {
    const response = await $fetch<any>(`${apiBaseUrl.replace(/\/$/, '')}/public/site-config`, {
      headers: {
        Host: host,
        'X-Request-Id': `req_robots_${Date.now()}`
      }
    })
    const siteConfig = response?.data || response || {}
    const canonicalBase = String(siteConfig.domain?.canonical_url || siteConfig.seo?.canonical_base_url || origin).replace(/^http:\/\//i, 'https://').replace(/\/$/, '')

    if (siteConfig.maintenance?.active || siteConfig.status !== 'active' || siteConfig.seo?.robots_enabled === false) {
      return 'User-agent: *\nDisallow: /\n'
    }

    return [
      'User-agent: *',
      'Allow: /',
      'Disallow: /cart',
      'Disallow: /checkout',
      'Disallow: /success',
      'Disallow: /topup',
      'Disallow: /tickets',
      'Disallow: /profile',
      'Disallow: /admin',
      `Sitemap: ${canonicalBase}/sitemap.xml`,
      ''
    ].join('\n')
  } catch {
    return 'User-agent: *\nDisallow: /\n'
  }
})

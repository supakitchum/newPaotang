import { normalizeTenantHost } from '~/utils/tenantHost'

const publicRoutes = ['/', '/buy', '/buy/search', '/countdown', '/result', '/result/full', '/news', '/terms', '/lottery-knowledge', '/activities']

const escapeXml = (value: string) => value
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&apos;')

export default defineEventHandler(async (event) => {
  setHeader(event, 'content-type', 'application/xml; charset=utf-8')
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
        'X-Request-Id': `req_sitemap_${Date.now()}`
      }
    })
    const siteConfig = response?.data || response || {}

    if (siteConfig.maintenance?.active || siteConfig.status !== 'active' || siteConfig.seo?.sitemap_enabled === false) {
      return '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></urlset>'
    }

    const canonicalBase = String(siteConfig.domain?.canonical_url || siteConfig.seo?.canonical_base_url || origin).replace(/^http:\/\//i, 'https://').replace(/\/$/, '')
    const urls = publicRoutes.map((path) => {
      const loc = `${canonicalBase}${path === '/' ? '' : path}`

      return `<url><loc>${escapeXml(loc)}</loc></url>`
    }).join('')

    return `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`
  } catch {
    return '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></urlset>'
  }
})

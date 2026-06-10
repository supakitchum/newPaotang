import { toSerializableError, type SerializableError } from '~/utils/serializableError'
import { normalizeTenantHost, tenantHostScope } from '~/utils/tenantHost'

export interface SiteConfig {
  partner_id?: string
  tenant_id?: string
  site?: {
    site_name?: string
    display_name?: string
    locale?: string
    timezone?: string
    support_email?: string
    support_phone?: string
  }
  domain?: {
    host?: string
    canonical_url?: string
    status?: string
  }
  brand?: {
    logo_url?: string
    favicon_url?: string
    og_image_url?: string
  }
  theme?: {
    primary_color?: string
    secondary_color?: string
    accent_color?: string
    background_color?: string
    text_color?: string
    font_family?: string
  }
  features?: Record<string, boolean>
  seo?: {
    default_title?: string
    title_template?: string
    default_description?: string
    default_keywords?: string[]
    robots_default?: string
    canonical_base_url?: string
    sitemap_enabled?: boolean
    robots_enabled?: boolean
  }
  maintenance?: {
    active?: boolean
    mode?: string | null
    message?: string | null
    expected_end_at?: string | null
    retry_after_seconds?: number | null
    allowed_routes?: string[]
    blocked_route_patterns?: string[]
  }
  api?: {
    base_url?: string
    realtime_url?: string
    asset_cdn_base_url?: string
  }
  live?: {
    waiting_result_youtube_url?: string
    waiting_result_youtube_embed_url?: string
    tenant_override_youtube_url?: string
    central_default_youtube_url?: string
    source?: string
  }
  legal?: {
    terms_content?: string
  }
  line?: {
    liff_id?: string | null
    liff_enabled?: boolean
    bot_basic_id?: string | null
    add_friend_url?: string | null
  }
  [key: string]: unknown
}

const siteConfigPromises = new Map<string, Promise<SiteConfig | null>>()

const isSafeColor = (value: unknown) => typeof value === 'string' && /^#(?:[0-9a-f]{3}|[0-9a-f]{6})$/i.test(value)

const routeMatchesPattern = (path: string, pattern: string) => {
  if (pattern.endsWith('*')) {
    return path.startsWith(pattern.slice(0, -1))
  }

  return path === pattern
}

const checkoutPaymentRoutes = ['/checkout', '/topup']
const alwaysAllowedMaintenanceRoutes = ['/maintenance', '/robots.txt']
const protectedMaintenanceRoutes = [
  '/',
  '/buy',
  '/buy/search',
  '/buy/more',
  '/stores',
  '/stores/lotteries',
  '/countdown',
  '/result',
  '/result/full',
  '/results',
  '/results/full',
  '/cart',
  '/checkout',
  '/success',
  '/topup',
  '/topup/history',
  '/my-wallet',
  '/purchase-history',
  '/tickets',
  '/tickets/history',
  '/tickets/view',
  '/profile/auto-reward',
  '/profile'
]

export const useSiteConfig = () => {
  const requestHeaders = process.server ? useRequestHeaders(['host']) : {}
  const hostScope = tenantHostScope(normalizeTenantHost(
    process.server ? requestHeaders.host : (process.client ? window.location.host : '')
  ))
  const config = useState<SiteConfig | null>(`site_config_${hostScope}`, () => null)
  const error = useState<SerializableError | null>(`site_config_error_${hostScope}`, () => null)
  const isLoading = useState<boolean>(`site_config_loading_${hostScope}`, () => false)
  const axios = useAxios()

  const applyTheme = (siteConfig: SiteConfig | null) => {
    if (!process.client || !siteConfig?.theme) {
      return
    }

    const root = document.documentElement
    const theme = siteConfig.theme

    if (isSafeColor(theme.primary_color)) {
      root.style.setProperty('--app-blue', theme.primary_color)
      root.style.setProperty('--app-blue-dark', theme.primary_color)
    }

    if (isSafeColor(theme.secondary_color)) {
      root.style.setProperty('--app-sky', theme.secondary_color)
    }

    if (isSafeColor(theme.accent_color)) {
      root.style.setProperty('--app-yellow', theme.accent_color)
    }

    if (isSafeColor(theme.text_color)) {
      root.style.setProperty('--app-ink', theme.text_color)
    }
  }

  const setSiteConfig = (siteConfig: SiteConfig | null) => {
    config.value = siteConfig

    applyTheme(siteConfig)
  }

  const fetchSiteConfig = async (options: { force?: boolean } = {}) => {
    if (!options.force && config.value) {
      return config.value
    }

    const currentPromise = siteConfigPromises.get(hostScope)

    if (!options.force && currentPromise) {
      return currentPromise
    }

    const nextPromise = (async () => {
      isLoading.value = true
      error.value = null

      try {
        const response = await axios.get('/public/site-config')
        const nextConfig = response.data?.data || response.data || null

        setSiteConfig(nextConfig)

        return nextConfig
      } catch (e) {
        error.value = toSerializableError(e)
        setSiteConfig(null)

        return null
      } finally {
        isLoading.value = false
        siteConfigPromises.delete(hostScope)
      }
    })()

    siteConfigPromises.set(hostScope, nextPromise)

    return nextPromise
  }

  const canonicalBase = computed(() => {
    const configured = config.value?.domain?.canonical_url || config.value?.seo?.canonical_base_url || ''

    if (configured) {
      return String(configured).replace(/^http:\/\//i, 'https://').replace(/\/$/, '')
    }

    if (process.client) {
      return `https://${window.location.host}`
    }

    return ''
  })

  const isMaintenanceActive = computed(() => Boolean(config.value?.maintenance?.active))

  const isRouteAllowedDuringMaintenance = (path: string) => {
    const allowedRoutes = [
      ...alwaysAllowedMaintenanceRoutes,
      ...(config.value?.maintenance?.allowed_routes || [])
    ]

    return allowedRoutes.some((allowedPath) => routeMatchesPattern(path, allowedPath))
  }

  const isRouteBlockedByMaintenance = (path: string) => {
    const maintenance = config.value?.maintenance

    if (!maintenance?.active || isRouteAllowedDuringMaintenance(path)) {
      return false
    }

    const mode = maintenance.mode || 'full_site'
    const explicitPatterns = maintenance.blocked_route_patterns || []

    if (explicitPatterns.some((pattern) => routeMatchesPattern(path, pattern))) {
      return true
    }

    if (mode === 'checkout_payment_only') {
      return checkoutPaymentRoutes.some((blockedPath) => path === blockedPath || path.startsWith(`${blockedPath}/`))
    }

    if (mode === 'scheduled' || mode === 'admin_only' || mode === 'read_only') {
      return false
    }

    if (mode === 'full_site' || mode === 'customer_web_only') {
      return true
    }

    return protectedMaintenanceRoutes.some((blockedPath) => path === blockedPath || path.startsWith(`${blockedPath}/`))
  }

  const isWriteBlockedByMaintenance = () => {
    const mode = config.value?.maintenance?.mode

    return Boolean(config.value?.maintenance?.active && (!mode || ['full_site', 'customer_web_only', 'checkout_payment_only', 'read_only'].includes(mode)))
  }

  return {
    config,
    error,
    isLoading,
    canonicalBase,
    isMaintenanceActive,
    fetchSiteConfig,
    setSiteConfig,
    isRouteBlockedByMaintenance,
    isWriteBlockedByMaintenance
  }
}

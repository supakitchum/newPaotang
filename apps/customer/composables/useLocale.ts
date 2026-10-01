import thTH from '~/locales/th-TH'
import enUS from '~/locales/en-US'
import { normalizeTenantHost, tenantHostScope } from '~/utils/tenantHost'

export type AppLocale = string

const messages = {
  'th-TH': thTH,
  'en-US': enUS,
} as const

const defaultSupportedLocales: AppLocale[] = ['th-TH', 'en-US']

const localeCookieName = (scope: string) => `np_locale_${scope}`

export const normalizeLocale = (value: unknown): AppLocale | null => {
  const locale = String(value || '').trim().toLowerCase().replace('_', '-')

  if (locale === 'th' || locale === 'th-th') return 'th-TH'
  if (locale === 'en' || locale === 'en-us' || locale === 'en-gb') return 'en-US'
  if (/^[a-z]{2}(?:-[a-z]{2})?$/.test(locale)) {
    const [language, region] = locale.split('-')
    return (region ? `${language}-${region.toUpperCase()}` : language) as AppLocale
  }

  return null
}

const getByPath = (source: Record<string, any>, key: string): unknown => (
  key.split('.').reduce((current, part) => current?.[part], source)
)

const interpolate = (text: string, params: Record<string, unknown>) => (
  Object.entries(params).reduce(
    (next, [key, value]) => next.replaceAll(`{${key}}`, String(value ?? '')),
    text,
  )
)

const staticLocaleKey = (locale: string): keyof typeof messages => (
  locale === 'en-US' ? 'en-US' : 'th-TH'
)

export const useLocale = () => {
  const requestHeaders = process.server ? useRequestHeaders(['host', 'accept-language']) : {}
  const hostScope = tenantHostScope(normalizeTenantHost(
    process.server ? requestHeaders.host : (process.client ? window.location.host : ''),
  ))
  const cookie = useCookie<AppLocale | null>(localeCookieName(hostScope), {
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 365,
  })
  const locale = useState<AppLocale>(`app_locale_${hostScope}`, () => (
    normalizeLocale(cookie.value)
    || normalizeLocale(process.server ? requestHeaders['accept-language'] : (process.client ? navigator.language : ''))
    || 'th-TH'
  ))
  const runtimeMessages = useState<Record<string, Record<string, string>>>(`app_runtime_locale_messages_${hostScope}`, () => ({}))
  const supportedLocalesState = useState<AppLocale[]>(`app_supported_locales_${hostScope}`, () => [...defaultSupportedLocales])
  const runtimeLoading = useState(`app_runtime_locale_loading_${hostScope}`, () => false)

  const applyHtmlLang = () => {
    if (process.client) {
      document.documentElement.lang = locale.value
    }
  }

  const setLocale = async (nextLocale: unknown, options: { persistProfile?: boolean } = {}) => {
    const normalized = normalizeLocale(nextLocale)
    if (!normalized) {
      return
    }

    locale.value = normalized
    cookie.value = normalized
    applyHtmlLang()

    await loadRuntimeBundle(normalized)

    if (options.persistProfile !== false) {
      const { token, setAuthUser, user } = useAuth()
      if (token.value) {
        try {
          const api = usePlatformApi()
          const profile = await api.updateProfile({ preferred_locale: normalized })
          if (profile && typeof profile === 'object') {
            setAuthUser({ ...(user.value || {}), ...profile })
          }
        } catch {
          // Language should still switch locally even if profile persistence fails.
        }
      }
    }
  }

  const applyDefaultLocale = (defaultLocale: unknown) => {
    if (cookie.value) {
      applyHtmlLang()
      return
    }

    const normalized = normalizeLocale(defaultLocale)
    if (normalized) {
      locale.value = normalized
      applyHtmlLang()
      void loadRuntimeBundle(normalized)
    }
  }

  const loadRuntimeBundle = async (targetLocale: unknown = locale.value, previewToken?: string | null) => {
    const normalized = normalizeLocale(targetLocale)
    if (!normalized || !process.client) {
      return
    }

    runtimeLoading.value = true
    try {
      const query = {
        locale: normalized,
        surface: 'customer',
        preview_token: previewToken || undefined,
      }
      const response: any = globalThis.$api
        ? (await globalThis.$api.get('/public/translations', { params: query })).data
        : await $fetch('/api/v1/public/translations', { query })
      const messages = response?.messages && typeof response.messages === 'object' ? response.messages : {}
      runtimeMessages.value = {
        ...runtimeMessages.value,
        [normalized]: messages,
      }
      if (Array.isArray(response?.available_locales)) {
        supportedLocalesState.value = response.available_locales
          .map((item: any) => normalizeLocale(item?.locale))
          .filter(Boolean) as AppLocale[]
      }
    } catch {
      runtimeMessages.value = {
        ...runtimeMessages.value,
        [normalized]: runtimeMessages.value[normalized] || {},
      }
    } finally {
      runtimeLoading.value = false
    }
  }

  const t = (key: string, params: Record<string, unknown> = {}) => {
    const runtime = runtimeMessages.value[locale.value]?.[key]
    if (typeof runtime === 'string') {
      return interpolate(runtime, params)
    }

    const current = getByPath(messages[staticLocaleKey(locale.value)], key)
    const fallback = getByPath(messages['th-TH'], key)
    const text = typeof current === 'string' ? current : (typeof fallback === 'string' ? fallback : key)

    return interpolate(text, params)
  }

  const localeHeader = computed(() => locale.value)

  return {
    locale,
    localeHeader,
    supportedLocales: supportedLocalesState,
    setLocale,
    applyDefaultLocale,
    loadRuntimeBundle,
    runtimeLoading,
    t,
  }
}

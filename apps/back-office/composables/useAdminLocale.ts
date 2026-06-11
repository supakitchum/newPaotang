import enUS from '~/locales/en-US'
import thTH from '~/locales/th-TH'

export type AdminLocale = string

const messages = {
  'en-US': enUS,
  'th-TH': thTH,
} as const

const storageKey = 'newpaotang.back-office.locale.v1'

export const normalizeAdminLocale = (value: unknown): AdminLocale | null => {
  const locale = String(value || '').trim().toLowerCase().replace('_', '-')

  if (locale === 'th' || locale === 'th-th') return 'th-TH'
  if (locale === 'en' || locale === 'en-us' || locale === 'en-gb') return 'en-US'
  if (/^[a-z]{2}(?:-[a-z]{2})?$/.test(locale)) {
    const [language, region] = locale.split('-')
    return region ? `${language}-${region.toUpperCase()}` : language
  }

  return null
}

const getByPath = (source: Record<string, any>, key: string): unknown => (
  key.split('.').reduce((current, part) => current?.[part], source)
)

const staticLocaleKey = (locale: string): keyof typeof messages => (
  locale === 'th-TH' ? 'th-TH' : 'en-US'
)

const staticPhraseMap = (locale: string): Record<string, string> => {
  const staticKey = staticLocaleKey(locale)
  const source = (messages[staticKey] as any)?.phrases

  return source && typeof source === 'object' ? source : {}
}

export const useAdminLocale = () => {
  const locale = useState<AdminLocale>('admin-locale', () => 'en-US')
  const runtimeMessages = useState<Record<string, Record<string, string>>>('admin-runtime-locale-messages', () => ({}))
  const runtimePhrases = useState<Record<string, Record<string, string>>>('admin-runtime-locale-phrases', () => ({}))
  const availableLocales = useState<Array<{ locale: string, name: string, native_name: string }>>('admin-available-locales', () => [
    { locale: 'en-US', name: 'English', native_name: 'English' },
    { locale: 'th-TH', name: 'Thai', native_name: 'ไทย' },
  ])
  const runtimeLoading = useState('admin-runtime-locale-loading', () => false)
  const phraseMap = computed(() => ({
    ...staticPhraseMap(locale.value),
    ...(runtimePhrases.value[locale.value] || {}),
  }))

  const restore = () => {
    if (!import.meta.client) {
      return
    }

    const saved = normalizeAdminLocale(localStorage.getItem(storageKey))
    if (saved) {
      locale.value = saved
    }
    document.documentElement.lang = locale.value
    void loadRuntimeBundle(locale.value)
  }

  const setLocale = async (nextLocale: unknown, options: { persistProfile?: boolean } = {}) => {
    const normalized = normalizeAdminLocale(nextLocale)
    if (!normalized) {
      return
    }

    locale.value = normalized

    if (import.meta.client) {
      localStorage.setItem(storageKey, normalized)
      document.documentElement.lang = normalized
    }

    await loadRuntimeBundle(normalized)

    if (options.persistProfile !== false) {
      const session = useAdminSession()
      if (session.session.value.accessToken) {
        try {
          const api = useAdminApi()
          const response = await api.apiFetch('/auth/admin/me', {
            method: 'PATCH',
            body: { preferred_locale: normalized },
            successMessage: false,
          })
          if ((response as any)?.user) {
            session.updateUser((response as any).user)
          }
        } catch {
          // Keep the local language even when profile persistence fails.
        }
      }
    }
  }

  const loadRuntimeBundle = async (targetLocale: unknown = locale.value, previewToken?: string | null) => {
    const normalized = normalizeAdminLocale(targetLocale)
    if (!normalized) {
      return
    }

    const session = useAdminSession()
    session.restore()
    if (!session.session.value.accessToken) {
      return
    }

    runtimeLoading.value = true
    try {
      const api = useAdminApi()
      const response: any = await api.apiFetch('/admin/translations/runtime', {
        query: {
          locale: normalized,
          surface: 'back-office',
          preview_token: previewToken || undefined,
        },
        successMessage: false,
      })
      const messages = response?.messages && typeof response.messages === 'object' ? response.messages : {}
      const phrases = response?.phrases && typeof response.phrases === 'object' ? response.phrases : {}
      runtimeMessages.value = {
        ...runtimeMessages.value,
        [normalized]: messages,
      }
      runtimePhrases.value = {
        ...runtimePhrases.value,
        [normalized]: phrases,
      }

      if (Array.isArray(response?.available_locales)) {
        availableLocales.value = response.available_locales
      }
    } catch {
      runtimeMessages.value = {
        ...runtimeMessages.value,
        [normalized]: runtimeMessages.value[normalized] || {},
      }
      runtimePhrases.value = {
        ...runtimePhrases.value,
        [normalized]: runtimePhrases.value[normalized] || {},
      }
    } finally {
      runtimeLoading.value = false
    }
  }

  const applyProfileLocale = (value: unknown) => {
    const normalized = normalizeAdminLocale(value)
    if (normalized) {
      void setLocale(normalized, { persistProfile: false })
    }
  }

  const t = (key: string) => {
    const runtime = runtimeMessages.value[locale.value]?.[key]
    if (typeof runtime === 'string') {
      return runtime
    }

    const staticKey = staticLocaleKey(locale.value)
    const current = getByPath(messages[staticKey], key)
    const fallback = getByPath(messages['en-US'], key)

    return typeof current === 'string' ? current : (typeof fallback === 'string' ? fallback : key)
  }

  const phrase = (source: unknown) => {
    const text = String(source || '').replace(/\s+/g, ' ').trim()
    if (!text) {
      return String(source || '')
    }

    return phraseMap.value[text] || String(source || '')
  }

  return {
    locale,
    restore,
    setLocale,
    applyProfileLocale,
    loadRuntimeBundle,
    availableLocales,
    runtimeLoading,
    runtimePhrases,
    phraseMap,
    t,
    phrase,
  }
}

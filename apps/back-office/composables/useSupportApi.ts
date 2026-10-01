type SupportApiOptions = {
  method?: string
  body?: any
  query?: Record<string, any>
  idempotencyKey?: string
}

type SupportSession = {
  token: string
  expires_at: string
  api_url: string
  realtime?: {
    url?: string
    key?: string
    auth_path?: string
  }
}

export const useSupportApi = () => {
  const adminApi = useAdminApi()
  const adminLocale = useAdminLocale()
  const supportSession = useState<SupportSession | null>('support-api-session', () => null)

  const idempotencyKey = () => `support_${Date.now().toString(36)}_${cryptoSafeSupportRandom()}`

  const sessionExpired = (session: SupportSession | null) => {
    if (!session?.token || !session.api_url) return true
    const expiresAt = new Date(session.expires_at).getTime()
    return !Number.isFinite(expiresAt) || expiresAt <= Date.now() + 30_000
  }

  const getSession = async (force = false) => {
    if (!force && !sessionExpired(supportSession.value)) {
      return supportSession.value as SupportSession
    }

    supportSession.value = await adminApi.apiFetch<SupportSession>('/admin/tenant/support-session', {
      method: 'POST',
      scope: 'tenant',
      successMessage: false,
    })
    return supportSession.value
  }

  const supportFetch = async <T = any>(path: string, options: SupportApiOptions = {}, retry = true): Promise<T> => {
    const session = await getSession()
    const headers: Record<string, string> = {
      Accept: 'application/json',
      'Accept-Language': adminLocale.locale.value,
      Authorization: `Bearer ${session.token}`,
    }
    const method = (options.method || 'GET').toUpperCase()
    const writeRequest = !['GET', 'HEAD', 'OPTIONS'].includes(method)
    const resolvedIdempotencyKey = options.idempotencyKey || (writeRequest ? idempotencyKey() : '')
    if (resolvedIdempotencyKey) {
      headers['Idempotency-Key'] = resolvedIdempotencyKey
    }
    if (options.body !== undefined && !(typeof FormData !== 'undefined' && options.body instanceof FormData)) {
      headers['Content-Type'] = 'application/json'
    }

    try {
      return await $fetch<T>(`${session.api_url}${path}`, {
        method: method as any,
        body: options.body,
        query: options.query,
        headers,
      })
    } catch (error: any) {
      const status = error?.response?.status || error?.status || 500
      if (status === 401 && retry) {
        await getSession(true)
        return supportFetch<T>(path, {
          ...options,
          idempotencyKey: resolvedIdempotencyKey || undefined,
        }, false)
      }
      const body = error?.data || error?.response?._data || {}
      throw {
        status,
        code: body?.error?.code || `http_${status}`,
        message: body?.error?.message || error?.message || 'Support request failed.',
        details: body?.errors || body?.error?.details || {},
      }
    }
  }

  const clearSupportSession = () => {
    supportSession.value = null
  }

  return {
    supportFetch,
    getSession,
    clearSupportSession,
    idempotencyKey,
  }
}

const cryptoSafeSupportRandom = () => {
  if (import.meta.client && window.crypto?.getRandomValues) {
    const values = new Uint32Array(2)
    window.crypto.getRandomValues(values)
    return Array.from(values).map(value => value.toString(36)).join('')
  }
  return Math.random().toString(36).slice(2, 14)
}

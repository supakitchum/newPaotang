type ApiOptions = {
  method?: string
  body?: any
  query?: Record<string, any>
  scope?: 'central' | 'tenant'
  tenantId?: string | null
  idempotencyKey?: string
  successMessage?: string | false
}

export const useAdminApi = () => {
  const config = useRuntimeConfig()
  const session = useAdminSession()
  const { showSuccessAlert } = useAdminSuccessAlert()
  const apiBase = computed(() => String(config.public.adminApiBase || '').replace(/\/$/, ''))

  const requestId = () => `req_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`
  const idempotencyKey = () => `idk_${Date.now().toString(36)}_${cryptoSafeRandom()}`

  const apiFetch = async <T = any>(path: string, options: ApiOptions = {}): Promise<T> => {
    session.restore()
    const headers: Record<string, string> = {
      Accept: 'application/json',
      'X-Request-Id': requestId(),
    }

    if (options.body !== undefined && !isFormDataBody(options.body)) {
      headers['Content-Type'] = 'application/json'
    }

    if (session.session.value.accessToken) {
      headers.Authorization = `Bearer ${session.session.value.accessToken}`
    }

    const scope = options.scope || session.currentScope.value
    headers['X-Admin-Scope'] = scope

    const tenantId = options.tenantId !== undefined ? options.tenantId : session.currentTenantId.value
    if (scope === 'tenant' && tenantId) {
      headers['X-Tenant-Id'] = tenantId
    }

    if (options.idempotencyKey) {
      headers['Idempotency-Key'] = options.idempotencyKey
    }

    const method = (options.method || 'GET').toUpperCase()

    try {
      const response = await $fetch<T>(`${apiBase.value}${path}`, {
        method,
        body: options.body,
        query: options.query,
        headers,
      })

      const successMessage = options.successMessage || responseSuccessMessage(response)
      if (import.meta.client && isWriteMethod(method) && options.successMessage !== false && successMessage) {
        void showSuccessAlert(successMessage)
      }

      return response
    } catch (error: any) {
      const status = error?.response?.status || error?.status || 500
      const body = error?.data || error?.response?._data || {}
      const code = body?.error?.code || `http_${status}`
      const message = body?.error?.message || readableError(status)
      const details = body?.error?.details || {}
      const retryAfter = error?.response?.headers?.get?.('Retry-After') || null

      if (status === 401) {
        if (code === 'admin_session_replaced' && message) {
          session.rememberAuthNotice(message)
        }
        session.clear()
      }

      throw {
        status,
        code,
        message,
        details,
        retryAfter,
      }
    }
  }

  const login = async (payload: { email: string, password: string, scope?: string, tenant_id?: string | null }) => {
    const response = await apiFetch('/auth/admin/login', {
      method: 'POST',
      body: payload,
      scope: payload.scope === 'tenant' ? 'tenant' : 'central',
      tenantId: payload.tenant_id,
      successMessage: false,
    })
    session.applyAuthPayload(response, payload.scope as 'central' | 'tenant', payload.tenant_id)
    return response
  }

  const refresh = async () => {
    if (!session.session.value.refreshToken) {
      return null
    }

    const response = await apiFetch('/auth/admin/refresh', {
      method: 'POST',
      body: { refresh_token: session.session.value.refreshToken },
      successMessage: false,
    })
    session.applyAuthPayload(response)
    return response
  }

  const logout = async () => {
    try {
      await apiFetch('/auth/admin/logout', {
        method: 'POST',
        idempotencyKey: idempotencyKey(),
        successMessage: false,
      })
    } finally {
      session.clear()
    }
  }

  return {
    apiBase,
    apiFetch,
    idempotencyKey,
    login,
    refresh,
    logout,
  }
}

const readableError = (status: number) => {
  const map: Record<number, string> = {
    401: 'Authentication is required.',
    403: 'You do not have permission to perform this action.',
    409: 'The requested operation conflicts with current data.',
    422: 'The request payload is invalid.',
    429: 'Too many requests. Please wait and retry.',
    503: 'The service is temporarily unavailable.',
  }

  return map[status] || 'The request failed.'
}

const isWriteMethod = (method: string) => ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)

const responseSuccessMessage = (response: any) => {
  const message = response?.message

  return typeof message === 'string' && message.trim() ? message.trim() : ''
}

const isFormDataBody = (body: any) => typeof FormData !== 'undefined' && body instanceof FormData

const cryptoSafeRandom = () => {
  if (import.meta.client && window.crypto?.getRandomValues) {
    const values = new Uint32Array(2)
    window.crypto.getRandomValues(values)
    return Array.from(values).map((value) => value.toString(36)).join('')
  }

  return Math.random().toString(36).slice(2, 14)
}

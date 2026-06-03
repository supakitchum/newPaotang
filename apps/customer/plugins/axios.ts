import axios from 'axios'
import { normalizeTenantHost, tenantHostScope } from '~/utils/tenantHost'

const createRequestId = () => {
  const randomValue = typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`

  return `req_${randomValue}`
}

export default defineNuxtPlugin({
  name: 'axios',
  setup(nuxtApp) {
    const config = useRuntimeConfig()
    const route = useRoute()
    const requestHeaders = process.server ? useRequestHeaders(['host']) : {}
    const { token: authToken, refreshToken, clearAuthToken, setPinVerified, refreshAuthToken } = useAuth()
    const { showAlert } = useAppAlert()
    const publicApiBaseUrl = String(config.public.apiBaseUrl || '/api/v1')
    const tenantHost = normalizeTenantHost(process.server ? requestHeaders.host : (process.client ? window.location.host : ''))
    const runtimeApiBaseUrl = useState<string>(`platform_api_base_url_${tenantHostScope(tenantHost)}`, () => publicApiBaseUrl)
    const serverApiBaseUrl = String(config.platformApiInternalBaseUrl || publicApiBaseUrl)
    const resolveApiBaseUrl = () => {
      const nextPublicBaseUrl = runtimeApiBaseUrl.value || publicApiBaseUrl

      return process.server && nextPublicBaseUrl.startsWith('/') ? serverApiBaseUrl : nextPublicBaseUrl
    }
    let isHandlingUnauthorized = false
    const api = axios.create({
      baseURL: resolveApiBaseUrl(),
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json'
      },
      responseType: 'json'
    })

    api.interceptors.request.use((request) => {
      const isFormData = typeof FormData !== 'undefined' && request.data instanceof FormData

      request.baseURL = resolveApiBaseUrl()

      request.headers.set('Accept', 'application/json')
      request.headers.set('X-Request-Id', createRequestId())

      if (process.server && tenantHost) {
        request.headers.set('Host', tenantHost)
      }

      if (isFormData) {
        request.headers.delete('Content-Type')
      } else {
        request.headers.set('Content-Type', 'application/json')
      }

      const explicitAuthorization = request.headers.get('Authorization')

      if (explicitAuthorization) {
        return request
      }

      if (authToken.value) {
        request.headers.set('Authorization', `Bearer ${authToken.value}`)
      } else {
        request.headers.delete('Authorization')
      }

      return request
    })

    let refreshPromise: Promise<any> | null = null
    let isHandlingMaintenance = false
    const refreshCustomerSession = async () => {
      if (!refreshPromise) {
        refreshPromise = refreshAuthToken().finally(() => {
          refreshPromise = null
        })
      }

      return refreshPromise
    }

    api.interceptors.response.use(
      (response) => response,
      async (error) => {
        const status = error.response?.status
        const requestUrl = error.config?.url || ''
        const apiError = error.response?.data?.error
        const isLoginRequest = requestUrl.startsWith('/customer/auth/login')
        const isRefreshRequest = requestUrl.startsWith('/customer/auth/refresh')

        if (apiError && !error.response.data.message) {
          error.response.data.message = apiError.message || 'กรุณาลองใหม่อีกครั้ง'
          error.response.data.code = apiError.code
        }

        if (status === 503 && String(apiError?.code || '') === 'maintenance_active') {
          if (process.client && route.path !== '/maintenance' && !isHandlingMaintenance) {
            isHandlingMaintenance = true
            showAlert({
              title: 'ปิดปรับปรุงระบบ',
              message: apiError?.message || 'ระบบอยู่ระหว่างปิดปรับปรุง กรุณากลับมาใหม่อีกครั้ง',
              variant: 'warning'
            })

            await nuxtApp.runWithContext(() => navigateTo('/maintenance', { replace: true }))

            setTimeout(() => {
              isHandlingMaintenance = false
            }, 500)
          }
        }

        if (['pin_required', 'pin_setup_required', 'pin_locked'].includes(String(apiError?.code || '')) && !requestUrl.startsWith('/customer/auth/pin/')) {
          setPinVerified(false)

          if (process.client && route.path !== '/pin') {
            await nuxtApp.runWithContext(() => navigateTo({
              path: '/pin',
              query: {
                redirect: route.fullPath
              }
            }))
          }
        }

        if (status === 401 && !isLoginRequest && !isRefreshRequest && refreshToken.value && !error.config?._authRetry) {
          const session = await refreshCustomerSession()

          if (session?.token && error.config) {
            error.config._authRetry = true

            if (typeof error.config.headers?.set === 'function') {
              error.config.headers.set('Authorization', `Bearer ${session.token}`)
            } else {
              error.config.headers = {
                ...(error.config.headers || {}),
                Authorization: `Bearer ${session.token}`
              }
            }

            return api.request(error.config)
          }
        }

        if (status === 401 && !isLoginRequest) {
          clearAuthToken()

          if (process.client && !isHandlingUnauthorized) {
            isHandlingUnauthorized = true
            showAlert({
              title: 'เซสชันหมดอายุ',
              message: 'กรุณาเข้าสู่ระบบใหม่อีกครั้ง',
              variant: 'warning'
            })

            await nuxtApp.runWithContext(() => navigateTo({
              path: '/login',
              query: {
                redirect: route.path === '/login' ? '/' : route.fullPath
              }
            }))

            setTimeout(() => {
              isHandlingUnauthorized = false
            }, 500)
          }
        }

        return Promise.reject(error)
      }
    )

    globalThis.$api = api
    globalThis.$axios = api

    nuxtApp.vueApp.config.globalProperties.$api = api
    nuxtApp.vueApp.config.globalProperties.$axios = api

    return {
      provide: {
        api,
        axios: api
      }
    }
  }
})

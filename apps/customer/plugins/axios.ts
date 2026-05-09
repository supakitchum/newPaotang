import axios from 'axios'

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
    const { token: authToken, clearAuthToken } = useAuth()
    const { showAlert } = useAppAlert()
    const runtimeApiBaseUrl = useState<string>('platform_api_base_url', () => String(config.public.apiBaseUrl || '/api/v1'))
    let isHandlingUnauthorized = false
    const api = axios.create({
      baseURL: runtimeApiBaseUrl.value,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json'
      },
      responseType: 'json'
    })

    api.interceptors.request.use((request) => {
      const isFormData = typeof FormData !== 'undefined' && request.data instanceof FormData
      const tenantHost = process.server ? requestHeaders.host : (process.client ? window.location.host : '')

      request.baseURL = runtimeApiBaseUrl.value || String(config.public.apiBaseUrl || '/api/v1')

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

    api.interceptors.response.use(
      (response) => response,
      async (error) => {
        const status = error.response?.status
        const requestUrl = error.config?.url || ''
        const apiError = error.response?.data?.error

        if (apiError && !error.response.data.message) {
          error.response.data.message = apiError.message || 'กรุณาลองใหม่อีกครั้ง'
          error.response.data.code = apiError.code
        }

        if (status === 401 && requestUrl !== '/customer/auth/login') {
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

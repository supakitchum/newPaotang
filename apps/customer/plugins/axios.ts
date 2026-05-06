import axios from 'axios'

export default defineNuxtPlugin({
  name: 'axios',
  setup(nuxtApp) {
    const config = useRuntimeConfig()
    const route = useRoute()
    const { token: authToken, clearAuthToken } = useAuth()
    const { showAlert } = useAppAlert()
    let isHandlingUnauthorized = false
    const api = axios.create({
      baseURL: config.public.apiBaseUrl,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json'
      },
      responseType: 'json'
    })

    api.interceptors.request.use((request) => {
      const isFormData = typeof FormData !== 'undefined' && request.data instanceof FormData

      request.headers.set('Accept', 'application/json')

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

        if (status === 401 && requestUrl !== '/login') {
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

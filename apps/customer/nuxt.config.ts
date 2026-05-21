export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  devtools: { enabled: false },
  telemetry: false,
  runtimeConfig: {
    platformApiInternalBaseUrl: process.env.NUXT_PLATFORM_API_INTERNAL_BASE_URL ||
      process.env.PLATFORM_API_INTERNAL_BASE_URL ||
      'http://platform-api:8000/api/v1',
    public: {
      apiBaseUrl: process.env.NUXT_PUBLIC_API_BASE_URL || '/api/v1',
      customerRealtimeUrl: process.env.NUXT_PUBLIC_CUSTOMER_REALTIME_URL || process.env.NUXT_PUBLIC_REALTIME_URL || '',
      customerRealtimeKey: process.env.NUXT_PUBLIC_CUSTOMER_REALTIME_KEY || process.env.NUXT_PUBLIC_REALTIME_KEY || 'newpaotang-customer'
    }
  },
  vite: {
    server: {
      allowedHosts: [
        'partner-a.test',
        'alpha.newpaotang.test',
        'beta.newpaotang.test',
        'gamma.newpaotang.test'
      ]
    }
  },
  css: [
    'bootstrap/dist/css/bootstrap.min.css',
    'bootstrap-icons/font/bootstrap-icons.css',
    '~/assets/scss/main.css'
  ],
  app: {
    head: {
      title: 'สลากหกหลัก',
      link: [
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Kanit:wght@300;400;500;600;700&display=swap' }
      ],
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover' },
        { name: 'theme-color', content: '#0a87f5' }
      ]
    }
  }
})

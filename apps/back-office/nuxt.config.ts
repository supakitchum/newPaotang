import { domainToASCII } from 'node:url'

const normalizeDevProxyHost = (host?: string) => {
  const value = String(host || '').trim().toLowerCase()

  if (!value) {
    return ''
  }

  const withoutPort = value.replace(/:\d+$/, '')
  const ascii = domainToASCII(withoutPort)

  return ascii || withoutPort
}

export default defineNuxtConfig({
  devtools: { enabled: false },
  buildDir: process.env.NUXT_BUILD_DIR || '.nuxt',
  ssr: false,
  css: [
    '~/assets/css/admin-foundation.css',
    'sweetalert2/dist/sweetalert2.min.css',
  ],
  app: {
    head: {
      title: 'Siamblend Back Office',
      htmlAttrs: {
        lang: 'en',
        dir: 'ltr',
        'data-nav-layout': 'vertical',
        'data-theme-mode': 'light',
        'data-menu-styles': 'light',
        'data-header-styles': 'light',
        'data-vertical-style': 'closed',
        'data-width': 'fullwidth',
        'data-menu-position': 'fixed',
        'data-header-position': 'fixed',
      },
      link: [
        { rel: 'icon', type: 'image/x-icon', href: '/brand/siamblend-favicon.ico' },
        { rel: 'icon', type: 'image/png', sizes: '32x32', href: '/brand/favicon-32x32.png' },
        { rel: 'apple-touch-icon', sizes: '180x180', href: '/brand/apple-touch-icon.png' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { id: 'style', rel: 'stylesheet', href: '/admin-template/assets/libs/bootstrap/css/bootstrap.min.css' },
        { rel: 'stylesheet', href: '/admin-template/assets/css/styles.css' },
        { rel: 'stylesheet', href: '/admin-template/assets/css/icons.css' },
        { rel: 'stylesheet', href: '/admin-template/assets/libs/node-waves/waves.min.css' },
        { rel: 'stylesheet', href: '/admin-template/assets/libs/simplebar/simplebar.min.css' },
      ],
      meta: [
        { name: 'application-name', content: 'Siamblend Back Office' },
        { name: 'apple-mobile-web-app-title', content: 'Siamblend' },
      ],
    },
  },
  runtimeConfig: {
    public: {
      adminApiBase: process.env.VITE_ADMIN_API_BASE || process.env.NUXT_PUBLIC_ADMIN_API_BASE || 'http://localhost:8000/api/v1',
      adminRealtimeUrl: process.env.VITE_ADMIN_REALTIME_URL || process.env.NUXT_PUBLIC_ADMIN_REALTIME_URL || '',
      adminRealtimeKey: process.env.VITE_ADMIN_REALTIME_KEY || process.env.NUXT_PUBLIC_ADMIN_REALTIME_KEY || 'newpaotang-admin',
    },
  },
  vite: {
    server: {
      allowedHosts: ['.test', '.localhost'],
      proxy: {
        '/api/v1': {
          target: 'http://platform-api:8000',
          changeOrigin: false,
          configure: (proxy) => {
            proxy.on('proxyReq', (proxyReq, req) => {
              const host = normalizeDevProxyHost(req.headers.host)

              if (host) {
                proxyReq.setHeader('Host', host)
              }
            })
          },
        },
        '/lotto-scraper': {
          target: 'http://lotto-scraper:3200',
          changeOrigin: false,
          rewrite: (path) => path.replace(/^\/lotto-scraper/, '') || '/',
        },
      },
    },
  },
  typescript: {
    strict: false,
  },
  nitro: {
    preset: 'node-server',
  },
})

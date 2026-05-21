export default defineNuxtConfig({
  devtools: { enabled: false },
  buildDir: process.env.NUXT_BUILD_DIR || '.nuxt',
  ssr: true,
  css: [
    '~/assets/css/admin-foundation.css',
    'sweetalert2/dist/sweetalert2.min.css',
  ],
  app: {
    head: {
      title: 'NewPaotang Back Office',
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
        { rel: 'icon', href: '/admin-template/assets/images/brand-logos/favicon.ico' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { id: 'style', rel: 'stylesheet', href: '/admin-template/assets/libs/bootstrap/css/bootstrap.min.css' },
        { rel: 'stylesheet', href: '/admin-template/assets/css/styles.css' },
        { rel: 'stylesheet', href: '/admin-template/assets/css/icons.css' },
        { rel: 'stylesheet', href: '/admin-template/assets/libs/node-waves/waves.min.css' },
        { rel: 'stylesheet', href: '/admin-template/assets/libs/simplebar/simplebar.min.css' },
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
      allowedHosts: ['.test'],
      proxy: {
        '/api/v1': {
          target: 'http://platform-api:8000',
          changeOrigin: false,
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

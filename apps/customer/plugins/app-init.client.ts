import { APP_INIT_TTL_MS } from '~/composables/useAppInit'
import { watch } from 'vue'

let refreshTimer: ReturnType<typeof setInterval> | null = null

export default defineNuxtPlugin({
  name: 'app-init',
  dependsOn: ['axios'],
  setup(nuxtApp) {
    const route = useRoute()
    const {token} = useAuth()
    const { ensureAppInit, refreshAppInit, getInitRedirectTarget } = useAppInit()

    const applyRedirect = async () => {
      const redirectTarget = getInitRedirectTarget(route.path)

      if (redirectTarget && redirectTarget !== route.path) {
        await nuxtApp.runWithContext(() => navigateTo(redirectTarget))
      }
    }

    ensureAppInit().then(applyRedirect)

    if (refreshTimer) {
      clearInterval(refreshTimer)
    }

    refreshTimer = setInterval(async () => {
      await ensureAppInit()
      await applyRedirect()
    }, APP_INIT_TTL_MS)

    watch(token, async (nextToken, previousToken) => {
      if (nextToken === previousToken) {
        return
      }

      await refreshAppInit()
      await applyRedirect()
    })
  }
})

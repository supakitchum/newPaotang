import { watch } from 'vue'

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

    watch(token, async (nextToken, previousToken) => {
      if (nextToken === previousToken) {
        return
      }

      await refreshAppInit()
      await applyRedirect()
    })
  }
})

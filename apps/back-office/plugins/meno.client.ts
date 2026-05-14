import 'bootstrap/dist/js/bootstrap.bundle.min.js'
import SimpleBar from 'simplebar'
import Waves from 'node-waves'

export default defineNuxtPlugin((nuxtApp) => {
  if (!import.meta.client) {
    return
  }

  const initTemplateBehavior = () => {
    document.documentElement.setAttribute('data-nav-layout', 'vertical')
    document.documentElement.setAttribute('data-theme-mode', 'light')
    document.documentElement.setAttribute('data-menu-styles', 'light')
    document.documentElement.setAttribute('data-header-styles', 'light')
    document.documentElement.setAttribute('data-vertical-style', 'closed')

    document.querySelectorAll('[data-simplebar]').forEach((element) => {
      if (!(element as any).SimpleBar) {
        new SimpleBar(element as HTMLElement)
      }
    })

    Waves.init()
    Waves.attach('.btn-wave', ['waves-light'])
  }

  const scheduleTemplateBehavior = () => {
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(initTemplateBehavior)
    })
  }

  let mounted = false
  nuxtApp.hook('app:mounted', () => {
    mounted = true
    scheduleTemplateBehavior()
  })

  const router = useRouter()
  router.afterEach(() => {
    if (!mounted) {
      return
    }
    nextTick(scheduleTemplateBehavior)
  })
})

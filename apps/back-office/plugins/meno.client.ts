import 'bootstrap/dist/js/bootstrap.bundle.min.js'

export default defineNuxtPlugin((nuxtApp) => {
  if (!import.meta.client) {
    return
  }

  let templateModules: Promise<{ SimpleBar: any, Waves: any }> | null = null
  const loadTemplateModules = async () => {
    if (!templateModules) {
      templateModules = Promise.all([
        import('simplebar'),
        import('node-waves'),
      ]).then(([simpleBarModule, wavesModule]) => ({
        SimpleBar: simpleBarModule.default,
        Waves: wavesModule.default,
      }))
    }

    return templateModules
  }

  const initTemplateBehavior = async () => {
    const { SimpleBar, Waves } = await loadTemplateModules()

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
    window.setTimeout(() => {
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
          void initTemplateBehavior()
        })
      })
    }, 0)
  }

  let mounted = false
  nuxtApp.hook('app:mounted', () => {
    onNuxtReady(() => {
      mounted = true
      scheduleTemplateBehavior()
    })
  })

  const router = useRouter()
  router.afterEach(() => {
    if (!mounted) {
      return
    }
    nextTick(scheduleTemplateBehavior)
  })
})

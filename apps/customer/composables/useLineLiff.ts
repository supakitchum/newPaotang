type LiffStatus = 'idle' | 'checking' | 'ready' | 'line_app' | 'not_configured' | 'error'

const LINE_LIFF_SDK_SRC = 'https://static.line-scdn.net/liff/edge/2/sdk.js'

export const useLineLiff = () => {
  const { config, fetchSiteConfig } = useSiteConfig()
  const status = useState<LiffStatus>('line_liff_status', () => 'idle')
  const profile = useState<Record<string, any> | null>('line_liff_profile', () => null)
  const initializedLiffId = useState<string>('line_liff_initialized_id', () => '')
  const isLineInApp = useState<boolean>('line_liff_is_line_in_app', () => false)
  const isLiffClient = useState<boolean>('line_liff_is_liff_client', () => false)

  const liffId = computed(() => String(config.value?.line?.liff_id || (config.value as any)?.line_liff_id || '').trim())

  const detectLineClient = () => {
    if (!import.meta.client) return

    isLineInApp.value = /Line\//i.test(window.navigator.userAgent)
    isLiffClient.value = Boolean((window as any).liff?.isInClient?.())

    if (status.value === 'idle') {
      status.value = isLineInApp.value ? 'line_app' : 'not_configured'
    }
  }

  const initialize = async () => {
    if (!import.meta.client) return

    detectLineClient()

    if (!liffId.value) {
      await fetchSiteConfig().catch(() => null)
    }

    if (!liffId.value) {
      status.value = isLineInApp.value ? 'line_app' : 'not_configured'
      return
    }

    if (initializedLiffId.value === liffId.value && status.value === 'ready') {
      return
    }

    status.value = 'checking'

    try {
      const liff = await loadLiffSdk()
      await liff.init({ liffId: liffId.value })
      initializedLiffId.value = liffId.value
      isLiffClient.value = Boolean(liff.isInClient?.())
      isLineInApp.value = isLiffClient.value || isLineInApp.value
      status.value = 'ready'

      if (liff.isLoggedIn?.()) {
        profile.value = await liff.getProfile?.().catch(() => null)
      }
    } catch {
      status.value = 'error'
    }
  }

  const openExternal = (url: string) => {
    if (!url || !import.meta.client) return

    const liff = (window as any).liff

    if (isLiffClient.value && liff?.openWindow) {
      liff.openWindow({ url, external: true })
      return
    }

    window.open(url, '_blank', 'noopener')
  }

  const redirectToLineLogin = async (url: string) => {
    if (!url) return

    if (!import.meta.client) {
      await navigateTo(url, { external: true })
      return
    }

    detectLineClient()
    await initialize().catch(() => null)
    detectLineClient()

    const liff = (window as any).liff

    if (isLiffClient.value && liff?.openWindow) {
      try {
        liff.openWindow({ url, external: false })
        return
      } catch {
        window.location.assign(url)
        return
      }
    }

    window.location.assign(url)
  }

  return {
    status,
    profile,
    liffId,
    isLineInApp,
    isLiffClient,
    detectLineClient,
    initialize,
    openExternal,
    redirectToLineLogin,
  }
}

async function loadLiffSdk(): Promise<any> {
  const existingLiff = (window as any).liff
  if (existingLiff) {
    return existingLiff
  }

  return await new Promise((resolve, reject) => {
    const existingScript = document.querySelector<HTMLScriptElement>('script[data-line-liff-sdk]')

    if (existingScript) {
      existingScript.addEventListener('load', () => resolve((window as any).liff), { once: true })
      existingScript.addEventListener('error', reject, { once: true })
      return
    }

    const script = document.createElement('script')
    script.dataset.lineLiffSdk = 'true'
    script.async = true
    script.src = LINE_LIFF_SDK_SRC
    script.addEventListener('load', () => resolve((window as any).liff), { once: true })
    script.addEventListener('error', reject, { once: true })
    document.head.appendChild(script)
  })
}

import { normalizeTenantHost, tenantHostScope } from '~/utils/tenantHost'

const HEARTBEAT_INTERVAL_MS = 60_000
const ROUTE_THROTTLE_MS = 10_000

const randomId = (prefix: string) => {
  const value = typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`

  return `${prefix}_${value}`
}

const safeStorageValue = (storage: Storage, key: string, prefix: string) => {
  const existing = storage.getItem(key)

  if (existing) {
    return existing
  }

  const next = randomId(prefix)
  storage.setItem(key, next)

  return next
}

const firstQueryValue = (value: unknown) => {
  if (Array.isArray(value)) {
    return String(value[0] || '').trim()
  }

  return String(value || '').trim()
}

const normalizeSource = (value: string) => value
  .toLowerCase()
  .replace(/[^a-z0-9:_\-.]/g, '')
  .slice(0, 64)

export const usePublicVisitMonitor = () => {
  if (!process.client) {
    return
  }

  const route = useRoute()
  const platformApi = usePlatformApi()
  const hostScope = tenantHostScope(normalizeTenantHost(window.location.host))
  const visitorKey = `public_visitor_${hostScope}`
  const sessionKey = `public_visit_session_${hostScope}`
  const visitorId = ref('')
  const sessionId = ref('')
  const lastTrackedAt = ref(0)
  const lastTrackedPath = ref('')
  let timer: ReturnType<typeof setInterval> | null = null

  const ensureIds = () => {
    if (!visitorId.value) {
      try {
        visitorId.value = safeStorageValue(window.localStorage, visitorKey, 'pv')
      } catch {
        visitorId.value = randomId('pv')
      }
    }

    if (!sessionId.value) {
      try {
        sessionId.value = safeStorageValue(window.sessionStorage, sessionKey, 'pvs')
      } catch {
        sessionId.value = randomId('pvs')
      }
    }
  }

  const trafficSource = () => {
    const explicitSource = firstQueryValue(route.query.utm_source || route.query.source)
    if (explicitSource) {
      return normalizeSource(explicitSource)
    }

    if (firstQueryValue(route.query.ref || route.query.ref_code || route.query.affiliate)) {
      return 'affiliate'
    }

    if (!document.referrer) {
      return 'direct'
    }

    try {
      const referrerHost = new URL(document.referrer).hostname.toLowerCase()
      const currentHost = window.location.hostname.toLowerCase()

      if (referrerHost === currentHost) return 'internal'
      if (referrerHost.includes('line.me') || referrerHost.includes('lin.ee')) return 'line'
      if (referrerHost.includes('facebook.com') || referrerHost.includes('fb.com')) return 'facebook'
      if (referrerHost.includes('google.')) return 'google'
      if (referrerHost.includes('tiktok.')) return 'tiktok'
      if (referrerHost.includes('instagram.')) return 'instagram'
    } catch {
      return 'referral'
    }

    return 'referral'
  }

  const trafficChannel = () => firstQueryValue(route.query.utm_medium || route.query.utm_campaign || route.query.ref) || null

  const track = async (force = false) => {
    ensureIds()

    const now = Date.now()
    const currentPath = route.fullPath
    if (!force && currentPath === lastTrackedPath.value && now - lastTrackedAt.value < ROUTE_THROTTLE_MS) {
      return
    }

    lastTrackedAt.value = now
    lastTrackedPath.value = currentPath

    try {
      await platformApi.trackPublicVisit({
        visitor_id: visitorId.value,
        session_id: sessionId.value,
        source: trafficSource(),
        channel: trafficChannel(),
        path: currentPath,
        referrer: document.referrer || null,
        screen: `${window.screen.width}x${window.screen.height}`,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || null,
        route_name: route.name ? String(route.name) : null,
      })
    } catch {
      // Visit tracking must never interrupt customer journeys.
    }
  }

  onMounted(() => {
    void track(true)
    timer = setInterval(() => {
      void track(true)
    }, HEARTBEAT_INTERVAL_MS)
  })

  watch(() => route.fullPath, () => {
    void track()
  })

  onBeforeUnmount(() => {
    if (timer !== null) {
      clearInterval(timer)
    }
  })
}

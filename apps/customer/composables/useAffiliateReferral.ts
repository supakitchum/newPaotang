import { normalizeTenantHost, tenantHostScope } from '~/utils/tenantHost'

const REF_TTL_SECONDS = 60 * 60 * 24 * 30
const REF_CODE_PATTERN = /^[A-Za-z0-9]{6}$/

const extractRefCode = (value: unknown) => {
  const ref = Array.isArray(value) ? value[0] : value

  if (typeof ref !== 'string') {
    return null
  }

  return REF_CODE_PATTERN.test(ref) ? ref : null
}

const currentTenantScope = () => {
  const requestHeaders = process.server ? useRequestHeaders(['host']) : {}
  const host = normalizeTenantHost(process.server ? requestHeaders.host : (process.client ? window.location.host : ''))

  return tenantHostScope(host)
}

export const useAffiliateReferral = () => {
  const scope = currentTenantScope()
  const storedRefCookie = useCookie<string | null>(`affiliate_ref_${scope}`, {
    maxAge: REF_TTL_SECONDS,
    sameSite: 'lax'
  })
  const visitorCookie = useCookie<string | null>(`affiliate_visitor_${scope}`, {
    maxAge: REF_TTL_SECONDS,
    sameSite: 'lax'
  })
  const storedRef = useState<string | null>(`affiliate_ref_state_${scope}`, () => extractRefCode(storedRefCookie.value))
  const visitorState = useState<string | null>(`affiliate_visitor_state_${scope}`, () => visitorCookie.value || null)

  const ensureVisitorId = () => {
    if (visitorState.value) {
      return visitorState.value
    }

    const generated = process.client && typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
      ? crypto.randomUUID()
      : `v_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 12)}`

    visitorState.value = generated
    visitorCookie.value = generated

    return generated
  }

  const setStoredRef = (ref: string | null) => {
    storedRef.value = ref
    storedRefCookie.value = ref
  }

  const clearStoredRef = () => {
    setStoredRef(null)
  }

  const captureRefFromRoute = (route = useRoute()) => {
    const nextRef = extractRefCode(route.query?.ref)

    if (!nextRef) {
      return null
    }

    setStoredRef(nextRef)

    if (process.client) {
      const landingUrl = window.location.href
      void usePlatformApi().trackAffiliateReferralClick({
        ref: nextRef,
        visitor_id: ensureVisitorId(),
        landing_url: landingUrl
      }).catch(() => null)
    }

    return nextRef
  }

  const applyStoredRef = async (options: { registered?: boolean } = {}) => {
    const ref = extractRefCode(storedRef.value || storedRefCookie.value)

    if (!ref) {
      clearStoredRef()
      return null
    }

    try {
      return await usePlatformApi().applyAffiliateReferral(ref, {
        visitor_id: ensureVisitorId(),
        registered: Boolean(options.registered)
      })
    } catch (error: any) {
      const status = Number(error?.response?.status || 0)

      if ([404, 422].includes(status)) {
        clearStoredRef()
      }

      return null
    }
  }

  return {
    storedRef,
    captureRefFromRoute,
    applyStoredRef,
    clearStoredRef
  }
}

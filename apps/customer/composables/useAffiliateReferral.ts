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
  const storedRef = useState<string | null>(`affiliate_ref_state_${scope}`, () => extractRefCode(storedRefCookie.value))

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

    return nextRef
  }

  const applyStoredRef = async () => {
    const ref = extractRefCode(storedRef.value || storedRefCookie.value)

    if (!ref) {
      clearStoredRef()
      return null
    }

    try {
      return await usePlatformApi().applyAffiliateReferral(ref)
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

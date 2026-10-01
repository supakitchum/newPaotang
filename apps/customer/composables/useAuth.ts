import { computed } from 'vue'
import { normalizeTenantHost, tenantHostScope } from '~/utils/tenantHost'

export const AUTH_TOKEN_COOKIE = 'auth_token'
export const AUTH_REFRESH_TOKEN_COOKIE = 'auth_refresh_token'
export const AUTH_USER_COOKIE = 'auth_user'
export const AUTH_PIN_UNLOCKED_SESSION = 'auth_pin_unlocked'
export const LINE_REDIRECT_COOKIE = 'line_redirect'
export const AUTH_ACCOUNT_SUSPENSION_COOKIE = 'auth_account_suspension'
export const AUTH_ACCESS_TOKEN_TTL_SECONDS = 3600
export const AUTH_REFRESH_TOKEN_TTL_SECONDS = 2592000

export type AuthUser = Record<string, unknown>
export type AccountSuspension = {
  reason?: string
  suspended_at?: string | null
  suspended_until?: string | null
  is_permanent?: boolean
}
export type AuthSessionResponse = {
  token?: string | null
  refresh_token?: string | null
  user?: AuthUser | null
  customer?: AuthUser | null
  pin_verified?: boolean | null
  pin_required?: boolean | null
  pin_setup_required?: boolean | null
}

export const useAuth = () => {
  const requestHeaders = process.server ? useRequestHeaders(['host']) : {}
  const authScope = tenantHostScope(normalizeTenantHost(
    process.server ? requestHeaders.host : (process.client ? window.location.host : '')
  ))
  const tokenCookie = useCookie<string | null>(`${AUTH_TOKEN_COOKIE}_${authScope}`, {
    sameSite: 'lax',
    maxAge: AUTH_ACCESS_TOKEN_TTL_SECONDS
  })
  const refreshTokenCookie = useCookie<string | null>(`${AUTH_REFRESH_TOKEN_COOKIE}_${authScope}`, {
    sameSite: 'lax',
    maxAge: AUTH_REFRESH_TOKEN_TTL_SECONDS
  })
  const userCookie = useCookie<AuthUser | null>(`${AUTH_USER_COOKIE}_${authScope}`, {
    sameSite: 'lax',
    maxAge: AUTH_REFRESH_TOKEN_TTL_SECONDS
  })
  const lineRedirect = useCookie<string | null>(`${LINE_REDIRECT_COOKIE}_${authScope}`, {
    sameSite: 'lax'
  })
  const accountSuspensionCookie = useCookie<AccountSuspension | null>(`${AUTH_ACCOUNT_SUSPENSION_COOKIE}_${authScope}`, {
    sameSite: 'lax',
    maxAge: AUTH_REFRESH_TOKEN_TTL_SECONDS
  })
  const token = useState<string | null>(`auth_token_state_${authScope}`, () => tokenCookie.value)
  const refreshToken = useState<string | null>(`auth_refresh_token_state_${authScope}`, () => refreshTokenCookie.value)
  const user = useState<AuthUser | null>(`auth_user_state_${authScope}`, () => userCookie.value)
  const accountSuspension = useState<AccountSuspension | null>(`auth_account_suspension_state_${authScope}`, () => accountSuspensionCookie.value)
  const hasRestoredUser = useState<boolean>(`auth_me_restored_state_${authScope}`, () => Boolean(userCookie.value))
  const pinUnlockedKey = `${AUTH_PIN_UNLOCKED_SESSION}_${authScope}`
  const pinVerified = useState<boolean>(`auth_pin_verified_state_${authScope}`, () => (
    process.client ? window.sessionStorage.getItem(pinUnlockedKey) === '1' : false
  ))

  const isAuthenticated = computed(() => Boolean(token.value))
  const hasPin = computed(() => Boolean((user.value as Record<string, unknown> | null)?.has_pin))
  const pinSetupRequired = computed(() => Boolean(token.value && user.value && (user.value as Record<string, unknown>).has_pin === false))
  const pinRequired = computed(() => Boolean(token.value && user.value && hasPin.value && !pinVerified.value))

  const setPinVerified = (value: boolean) => {
    pinVerified.value = value

    if (!process.client) {
      return
    }

    if (value) {
      window.sessionStorage.setItem(pinUnlockedKey, '1')
      return
    }

    window.sessionStorage.removeItem(pinUnlockedKey)
  }

  const setRefreshToken = (value: string | null | undefined) => {
    refreshToken.value = value || null
    refreshTokenCookie.value = value || null
  }

  const setAuthToken = (value: string, nextRefreshToken?: string | null) => {
    token.value = value
    tokenCookie.value = value

    if (nextRefreshToken !== undefined) {
      setRefreshToken(nextRefreshToken)
    }
  }

  const setAuthUser = (value: AuthUser) => {
    user.value = value
    userCookie.value = value
    hasRestoredUser.value = true

    const preferredLocale = (value as Record<string, unknown>).preferred_locale
    if (preferredLocale) {
      void useLocale().setLocale(preferredLocale, { persistProfile: false })
    }

    if ((value as Record<string, unknown>).pin_verified === false) {
      setPinVerified(false)
    }
  }

  const setAuthSession = (session: AuthSessionResponse | null | undefined) => {
    if (!session?.token) {
      return
    }

    clearAccountSuspension()
    setAuthToken(session.token, session.refresh_token)
    setAuthUser(session.user || session.customer || {})

    if (session.pin_verified === false || (session.user as Record<string, unknown> | null)?.pin_verified === false) {
      setPinVerified(false)
    }
  }

  const setLineRedirect = (value: string) => {
    lineRedirect.value = value
  }

  const clearLineRedirect = () => {
    lineRedirect.value = null
  }

  const setAccountSuspension = (value: AccountSuspension | null | undefined) => {
    accountSuspension.value = value || {}
    accountSuspensionCookie.value = accountSuspension.value
  }

  const clearAccountSuspension = () => {
    accountSuspension.value = null
    accountSuspensionCookie.value = null
  }

  const clearAuthToken = () => {
    token.value = null
    tokenCookie.value = null
    setRefreshToken(null)
    setPinVerified(false)
    user.value = null
    userCookie.value = null
    hasRestoredUser.value = false
  }

  const restoreAuthState = async (force = false) => {
    if (!token.value || (hasRestoredUser.value && user.value && !force)) {
      return user.value
    }

    const platformApi = usePlatformApi()
    const profile = await platformApi.me()

    setAuthUser(profile || {})

    return profile
  }

  const refreshAuthToken = async () => {
    if (!refreshToken.value) {
      return null
    }

    try {
      const platformApi = usePlatformApi()
      const session = await platformApi.refresh(refreshToken.value)

      if (!session?.token) {
        clearAuthToken()
        return null
      }

      setAuthSession({
        ...session,
        refresh_token: session.refresh_token ?? refreshToken.value
      })

      return session
    } catch (error: any) {
      if (error?.response?.data?.error?.code === 'customer_suspended') {
        setAccountSuspension(error.response.data.error.details?.suspension || {})
      }
      clearAuthToken()
      return null
    }
  }

  const logout = async () => {
    try {
      if (token.value) {
        await usePlatformApi().logout()
      }
    } finally {
      clearAuthToken()
    }
  }

  return {
    token,
    refreshToken,
    user,
    lineRedirect,
    accountSuspension,
    pinVerified,
    hasPin,
    pinSetupRequired,
    pinRequired,
    isAuthenticated,
    setAuthToken,
    setRefreshToken,
    setAuthUser,
    setAuthSession,
    setPinVerified,
    setLineRedirect,
    clearLineRedirect,
    setAccountSuspension,
    clearAccountSuspension,
    clearAuthToken,
    restoreAuthState,
    refreshAuthToken,
    logout
  }
}

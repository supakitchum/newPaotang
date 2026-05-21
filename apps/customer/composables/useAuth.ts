import { computed } from 'vue'
import { normalizeTenantHost, tenantHostScope } from '~/utils/tenantHost'

export const AUTH_TOKEN_COOKIE = 'auth_token'
export const AUTH_REFRESH_TOKEN_COOKIE = 'auth_refresh_token'
export const AUTH_USER_COOKIE = 'auth_user'
export const LINE_REDIRECT_COOKIE = 'line_redirect'

export type AuthUser = Record<string, unknown>
export type AuthSessionResponse = {
  token?: string | null
  refresh_token?: string | null
  user?: AuthUser | null
  customer?: AuthUser | null
}

export const useAuth = () => {
  const requestHeaders = process.server ? useRequestHeaders(['host']) : {}
  const authScope = tenantHostScope(normalizeTenantHost(
    process.server ? requestHeaders.host : (process.client ? window.location.host : '')
  ))
  const tokenCookie = useCookie<string | null>(`${AUTH_TOKEN_COOKIE}_${authScope}`, {
    sameSite: 'lax'
  })
  const refreshTokenCookie = useCookie<string | null>(`${AUTH_REFRESH_TOKEN_COOKIE}_${authScope}`, {
    sameSite: 'lax'
  })
  const userCookie = useCookie<AuthUser | null>(`${AUTH_USER_COOKIE}_${authScope}`, {
    sameSite: 'lax'
  })
  const lineRedirect = useCookie<string | null>(`${LINE_REDIRECT_COOKIE}_${authScope}`, {
    sameSite: 'lax'
  })
  const token = useState<string | null>(`auth_token_state_${authScope}`, () => tokenCookie.value)
  const refreshToken = useState<string | null>(`auth_refresh_token_state_${authScope}`, () => refreshTokenCookie.value)
  const user = useState<AuthUser | null>(`auth_user_state_${authScope}`, () => userCookie.value)
  const hasRestoredUser = useState<boolean>(`auth_me_restored_state_${authScope}`, () => Boolean(userCookie.value))

  const isAuthenticated = computed(() => Boolean(token.value))

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
  }

  const setAuthSession = (session: AuthSessionResponse | null | undefined) => {
    if (!session?.token) {
      return
    }

    setAuthToken(session.token, session.refresh_token)
    setAuthUser(session.user || session.customer || {})
  }

  const setLineRedirect = (value: string) => {
    lineRedirect.value = value
  }

  const clearLineRedirect = () => {
    lineRedirect.value = null
  }

  const clearAuthToken = () => {
    token.value = null
    tokenCookie.value = null
    setRefreshToken(null)
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

    const platformApi = usePlatformApi()
    const session = await platformApi.refresh(refreshToken.value)

    if (!session?.token) {
      return null
    }

    setAuthSession({
      ...session,
      refresh_token: session.refresh_token ?? refreshToken.value
    })

    return session
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
    isAuthenticated,
    setAuthToken,
    setRefreshToken,
    setAuthUser,
    setAuthSession,
    setLineRedirect,
    clearLineRedirect,
    clearAuthToken,
    restoreAuthState,
    refreshAuthToken,
    logout
  }
}

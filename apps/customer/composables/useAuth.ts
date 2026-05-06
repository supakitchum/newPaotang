import { computed } from 'vue'

export const AUTH_TOKEN_COOKIE = 'auth_token'
export const AUTH_USER_COOKIE = 'auth_user'
export const LINE_REDIRECT_COOKIE = 'line_redirect'

export type AuthUser = Record<string, unknown>

export const useAuth = () => {
  const tokenCookie = useCookie<string | null>(AUTH_TOKEN_COOKIE, {
    sameSite: 'lax'
  })
  const userCookie = useCookie<AuthUser | null>(AUTH_USER_COOKIE, {
    sameSite: 'lax'
  })
  const lineRedirect = useCookie<string | null>(LINE_REDIRECT_COOKIE, {
    sameSite: 'lax'
  })
  const token = useState<string | null>('auth_token_state', () => tokenCookie.value)
  const user = useState<AuthUser | null>('auth_user_state', () => userCookie.value)

  const isAuthenticated = computed(() => Boolean(token.value))

  const setAuthToken = (value: string) => {
    token.value = value
    tokenCookie.value = value
  }

  const setAuthUser = (value: AuthUser) => {
    user.value = value
    userCookie.value = value
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
    user.value = null
    userCookie.value = null
  }

  return {
    token,
    user,
    lineRedirect,
    isAuthenticated,
    setAuthToken,
    setAuthUser,
    setLineRedirect,
    clearLineRedirect,
    clearAuthToken
  }
}

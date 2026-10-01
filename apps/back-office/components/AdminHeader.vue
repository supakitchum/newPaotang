<template>
  <header class="app-header">
    <div class="main-header-container container-fluid">
      <div class="header-content-left">
        <div class="header-element">
          <div class="horizontal-logo">
            <NuxtLink to="/admin" class="header-logo np-header-brand-link" :aria-label="displayName">
              <img :src="logoUrl" :alt="displayName" class="desktop-logo np-admin-brand-logo" data-admin-header-logo="horizontal" />
              <img :src="logoUrl" :alt="displayName" class="desktop-dark np-admin-brand-logo" />
              <img :src="compactLogoUrl" :alt="displayName" class="toggle-logo np-admin-brand-mark" />
              <img :src="compactLogoUrl" :alt="displayName" class="toggle-dark np-admin-brand-mark" />
            </NuxtLink>
          </div>
        </div>
        <div class="header-element">
          <button
            class="sidemenu-toggle header-link animated-arrow hor-toggle horizontal-navtoggle border-0 bg-transparent"
            type="button"
            aria-label="Toggle sidebar"
            @click="toggleSidebar"
          >
            <span />
          </button>
        </div>
      </div>
      <div class="header-content-right">
        <div class="header-element np-server-clock" :title="serverClockTitle">
          <div
            class="header-link np-server-clock__content"
            data-admin-server-clock
            role="timer"
            aria-live="off"
            :aria-label="serverClockTitle"
          >
            <i class="ri-time-line header-link-icon np-server-clock__icon" aria-hidden="true" />
            <span class="np-server-clock__copy">
              <span class="np-server-clock__date">{{ serverClockDateLabel }}</span>
              <time class="np-server-clock__time" :datetime="serverClockDateTime">{{ serverClockTimeLabel }}</time>
              <time class="np-server-clock__time-compact" :datetime="serverClockDateTime">{{ serverClockCompactTimeLabel }}</time>
            </span>
          </div>
        </div>
        <div class="header-element dropdown">
          <button class="header-link dropdown-toggle btn-wave border-0 bg-transparent" type="button" data-bs-toggle="dropdown" aria-expanded="false">
            <i class="ri-stack-line header-link-icon me-1" />
            <span class="np-header-text">{{ displayScopeLabel }}</span>
          </button>
          <ul class="dropdown-menu main-header-dropdown dropdown-menu-end">
            <li v-for="scope in visibleScopes" :key="`${scope.scope}-${scope.tenant_id || 'central'}`">
              <button class="dropdown-item" type="button" @click="switchScope(scope)">
                <i :class="[scope.scope === 'central' ? 'ri-global-line' : 'ri-building-line', 'me-2']" />
                {{ scope.scope === 'central' ? t('common.central') : scope.tenant_name || scope.tenant_id || t('common.tenant') }}
              </button>
            </li>
          </ul>
        </div>
        <div class="header-element">
          <button class="header-link btn-wave border-0 bg-transparent" type="button" data-bs-toggle="modal" data-bs-target="#admin-search-modal" :aria-label="t('common.search')">
            <i class="ri-search-line header-link-icon" />
          </button>
        </div>
        <div class="header-element dropdown">
          <button class="header-link dropdown-toggle btn-wave border-0 bg-transparent" type="button" data-bs-toggle="dropdown" :aria-label="t('common.language')" aria-expanded="false">
            <i class="ri-translate-2 header-link-icon me-1" />
            <span class="np-header-text">{{ localeLabel }}</span>
          </button>
          <ul class="dropdown-menu main-header-dropdown dropdown-menu-end">
            <li>
              <button class="dropdown-item" type="button" @click="setLocale('en-US')">
                {{ t('common.english') }}
              </button>
            </li>
            <li>
              <button class="dropdown-item" type="button" @click="setLocale('th-TH')">
                {{ t('common.thai') }}
              </button>
            </li>
          </ul>
        </div>
        <div class="header-element dropdown main-profile-user">
          <button class="header-link dropdown-toggle btn-wave border-0 bg-transparent" type="button" data-bs-toggle="dropdown" aria-expanded="false">
            <span class="avatar avatar-sm bg-primary-transparent text-primary me-2">
              {{ displayInitials }}
            </span>
            <span class="user-name d-none d-sm-inline">{{ displayUserName }}</span>
          </button>
          <ul class="dropdown-menu main-header-dropdown dropdown-menu-end">
            <li><span class="dropdown-item-text text-muted small">{{ displayUserEmail }}</span></li>
            <li><hr class="dropdown-divider" /></li>
            <li>
              <button class="dropdown-item" type="button" @click="openPasswordModal">
                <i class="ri-lock-password-line me-2" />
                {{ t('account.changePassword') }}
              </button>
            </li>
            <li><hr class="dropdown-divider" /></li>
            <li>
              <button class="dropdown-item text-danger" type="button" @click="handleLogout">
                <i class="ri-logout-box-r-line me-2" />
                {{ t('common.logout') }}
              </button>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </header>

  <AdminModal v-model="passwordModalOpen" :title="t('account.changePassword')" size="md">
    <form class="vstack gap-3" @submit.prevent="handleChangePassword">
      <AdminAlert
        v-if="passwordError"
        type="danger"
        :message="passwordError.message"
        :details="passwordError.details"
        dismissible
        @dismiss="passwordError = null"
      />
      <div>
        <label class="form-label">{{ t('account.currentPassword') }}</label>
        <input
          v-model="passwordForm.current_password"
          class="form-control"
          type="password"
          autocomplete="current-password"
          required
        >
      </div>
      <div>
        <label class="form-label">{{ t('account.newPassword') }}</label>
        <input
          v-model="passwordForm.new_password"
          class="form-control"
          type="password"
          autocomplete="new-password"
          minlength="8"
          required
        >
        <div class="form-text">{{ t('account.passwordPolicy') }}</div>
      </div>
      <div>
        <label class="form-label">{{ t('account.confirmNewPassword') }}</label>
        <input
          v-model="passwordForm.new_password_confirmation"
          class="form-control"
          type="password"
          autocomplete="new-password"
          minlength="8"
          required
        >
      </div>
    </form>
    <template #footer>
      <button type="button" class="btn btn-light btn-wave" :disabled="passwordSubmitting" @click="closePasswordModal">
        {{ t('common.cancel') }}
      </button>
      <button type="button" class="btn btn-primary btn-wave" :disabled="passwordSubmitting" @click="handleChangePassword">
        <span v-if="passwordSubmitting" class="spinner-border spinner-border-sm me-2" aria-hidden="true" />
        {{ t('account.updatePassword') }}
      </button>
    </template>
  </AdminModal>
</template>

<script setup lang="ts">
type AdminServerTimeResponse = {
  server_time?: string
  timezone?: string
  utc_offset?: string
}

const props = withDefaults(defineProps<{
  clientReady?: boolean
}>(), {
  clientReady: false,
})

const adminSession = useAdminSession()
const { logoUrl, compactLogoUrl, displayName } = useAdminBranding()
const { session } = adminSession
const api = useAdminApi()
const { locale, setLocale, t } = useAdminLocale()

const scopeLabel = computed(() => {
  if (session.value.activeScope === 'central') {
    return t('common.central')
  }

  const scope = session.value.scopes.find((item) => item.scope === 'tenant' && item.tenant_id === session.value.activeTenantId)
  return scope?.tenant_name || scope?.tenant_id || t('common.tenant')
})

const initials = computed(() => (session.value.user?.name || 'A').slice(0, 2).toUpperCase())
const visibleScopes = computed(() => props.clientReady ? session.value.scopes : [])
const displayScopeLabel = computed(() => props.clientReady ? scopeLabel.value : t('common.scope'))
const displayInitials = computed(() => props.clientReady ? initials.value : 'A')
const displayUserName = computed(() => props.clientReady ? session.value.user?.name || t('common.admin') : t('common.admin'))
const displayUserEmail = computed(() => props.clientReady ? session.value.user?.email || '' : '')
const localeLabel = computed(() => locale.value === 'th-TH' ? 'TH' : 'EN')
const passwordModalOpen = ref(false)
const passwordSubmitting = ref(false)
const passwordError = ref<{ message: string, details?: any } | null>(null)
const serverClockOriginMs = ref<number | null>(null)
const serverClockClientOriginMs = ref<number | null>(null)
const serverClockTickMs = ref(Date.now())
const serverClockTimezone = ref('')
const serverClockUtcOffset = ref('')
let serverClockTickTimer: ReturnType<typeof setInterval> | null = null
let serverClockSyncTimer: ReturnType<typeof setInterval> | null = null
let serverClockSyncing = false
const passwordForm = reactive({
  current_password: '',
  new_password: '',
  new_password_confirmation: '',
})

const currentServerTime = computed(() => {
  if (serverClockOriginMs.value === null || serverClockClientOriginMs.value === null) {
    return null
  }

  return new Date(serverClockOriginMs.value + (serverClockTickMs.value - serverClockClientOriginMs.value))
})

const formatServerClock = (options: Intl.DateTimeFormatOptions, fallback: (date: Date) => string) => {
  const date = currentServerTime.value
  if (!date) {
    return ''
  }

  try {
    return new Intl.DateTimeFormat(locale.value, {
      ...options,
      timeZone: serverClockTimezone.value,
    }).format(date)
  } catch {
    return fallback(date)
  }
}

const serverClockDateLabel = computed(() => formatServerClock(
  { day: '2-digit', month: 'short', year: 'numeric' },
  (date) => date.toISOString().slice(0, 10),
))
const serverClockTimeLabel = computed(() => formatServerClock(
  { hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' },
  (date) => date.toISOString().slice(11, 19),
) || '--:--:--')
const serverClockCompactTimeLabel = computed(() => formatServerClock(
  { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' },
  (date) => date.toISOString().slice(11, 16),
) || '--:--')
const serverClockDateTime = computed(() => currentServerTime.value?.toISOString())
const serverClockTitle = computed(() => {
  if (!currentServerTime.value) {
    return `${t('common.serverTime')}: ${t('common.loading')}`
  }

  const zone = [serverClockTimezone.value, serverClockUtcOffset.value].filter(Boolean).join(' ')
  const label = [serverClockDateLabel.value, serverClockTimeLabel.value].filter(Boolean).join(' ')

  return `${t('common.serverTime')}: ${label}${zone ? ` (${zone})` : ''}`
})

const syncServerClock = async () => {
  if (!props.clientReady || !session.value.accessToken || serverClockSyncing) {
    return
  }

  serverClockSyncing = true
  const requestStartedAt = Date.now()

  try {
    const response = await api.apiFetch<AdminServerTimeResponse>('/auth/admin/server-time', {
      successMessage: false,
    })
    const receivedAt = Date.now()
    const parsedServerTime = Date.parse(String(response?.server_time || ''))

    if (!Number.isFinite(parsedServerTime) || !response?.timezone) {
      return
    }

    serverClockOriginMs.value = parsedServerTime + Math.max(0, receivedAt - requestStartedAt) / 2
    serverClockClientOriginMs.value = receivedAt
    serverClockTickMs.value = receivedAt
    serverClockTimezone.value = String(response.timezone)
    serverClockUtcOffset.value = String(response.utc_offset || '')
  } catch {
    // Keep the last synchronized value and retry on the next bounded refresh.
  } finally {
    serverClockSyncing = false
  }
}

const handleServerClockVisibility = () => {
  if (document.visibilityState !== 'visible') {
    return
  }

  serverClockTickMs.value = Date.now()
  void syncServerClock()
}

watch([() => props.clientReady, () => session.value.accessToken], ([clientReady, accessToken]) => {
  if (clientReady && accessToken) {
    void syncServerClock()
  }
})

onMounted(() => {
  serverClockTickMs.value = Date.now()
  serverClockTickTimer = setInterval(() => {
    serverClockTickMs.value = Date.now()
  }, 1000)
  serverClockSyncTimer = setInterval(() => {
    void syncServerClock()
  }, 5 * 60 * 1000)
  document.addEventListener('visibilitychange', handleServerClockVisibility)
  void syncServerClock()
})

onBeforeUnmount(() => {
  if (serverClockTickTimer) {
    clearInterval(serverClockTickTimer)
  }
  if (serverClockSyncTimer) {
    clearInterval(serverClockSyncTimer)
  }
  document.removeEventListener('visibilitychange', handleServerClockVisibility)
})

const toggleSidebar = () => {
  const isMobile = window.matchMedia('(max-width: 991.98px)').matches
  const current = document.documentElement.getAttribute('data-toggled')

  if (isMobile) {
    document.documentElement.setAttribute('data-toggled', current === 'open' ? 'close' : 'open')
    return
  }

  if (current === 'close-menu-close') {
    document.documentElement.removeAttribute('data-toggled')
    return
  }

  document.documentElement.setAttribute('data-toggled', 'close-menu-close')
}

const switchScope = async (scope: any) => {
  adminSession.setScope(scope.scope, scope.tenant_id)
  await navigateTo(adminSession.landingPath(scope.scope))
}

const handleLogout = async () => {
  await api.logout()
  await navigateTo('/login')
}

const resetPasswordForm = () => {
  passwordForm.current_password = ''
  passwordForm.new_password = ''
  passwordForm.new_password_confirmation = ''
  passwordError.value = null
}

const openPasswordModal = () => {
  resetPasswordForm()
  passwordModalOpen.value = true
}

const closePasswordModal = () => {
  if (passwordSubmitting.value) {
    return
  }

  passwordModalOpen.value = false
  resetPasswordForm()
}

const handleChangePassword = async () => {
  passwordError.value = null

  if (passwordForm.new_password !== passwordForm.new_password_confirmation) {
    passwordError.value = { message: t('account.passwordMismatch') }
    return
  }

  passwordSubmitting.value = true
  try {
    await api.apiFetch('/auth/admin/password/change', {
      method: 'POST',
      body: { ...passwordForm },
      idempotencyKey: api.idempotencyKey(),
      successMessage: false,
    })
    passwordModalOpen.value = false
    resetPasswordForm()
    adminSession.clear()
    adminSession.rememberAuthNotice(t('account.forcePasswordChangedNotice'))
    await navigateTo('/login')
  } catch (error: any) {
    passwordError.value = {
      message: error?.message || t('errors.failed'),
      details: error?.details || null,
    }
  } finally {
    passwordSubmitting.value = false
  }
}
</script>

<style scoped>
.np-server-clock {
  flex: 0 0 auto;
}

.np-server-clock__content {
  display: flex;
  min-width: 8rem;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  cursor: default;
}

.np-server-clock__copy {
  display: flex;
  min-width: 0;
  align-items: baseline;
  gap: 0.45rem;
  white-space: nowrap;
}

.np-server-clock__date {
  color: var(--text-muted);
  font-size: 0.72rem;
  font-weight: 400;
}

.np-server-clock__time,
.np-server-clock__time-compact {
  color: var(--header-prime-color);
  font-size: 0.85rem;
  font-variant-numeric: tabular-nums;
  font-weight: 500;
  letter-spacing: 0;
}

.np-server-clock__time-compact {
  display: none;
}

@media (max-width: 1199.98px) {
  .np-server-clock__date {
    display: none;
  }
}

@media (max-width: 575.98px) {
  .np-server-clock__content {
    min-width: 3.25rem;
    padding-inline: 0.375rem;
  }

  .np-server-clock__icon,
  .np-server-clock__time {
    display: none;
  }

  .np-server-clock__time-compact {
    display: inline;
    font-size: 0.78rem;
  }
}
</style>

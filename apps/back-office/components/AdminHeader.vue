<template>
  <header class="app-header">
    <div class="main-header-container container-fluid">
      <div class="header-content-left">
        <div class="header-element">
          <div class="horizontal-logo">
            <NuxtLink to="/admin" class="header-logo">
              <img src="/admin-template/assets/images/brand-logos/desktop-logo.png" alt="NewPaotang" class="desktop-logo" />
              <img src="/admin-template/assets/images/brand-logos/desktop-dark.png" alt="NewPaotang" class="desktop-dark" />
              <img src="/admin-template/assets/images/brand-logos/toggle-logo.png" alt="NewPaotang" class="toggle-logo" />
              <img src="/admin-template/assets/images/brand-logos/toggle-dark.png" alt="NewPaotang" class="toggle-dark" />
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
const props = withDefaults(defineProps<{
  clientReady?: boolean
}>(), {
  clientReady: false,
})

const adminSession = useAdminSession()
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
const passwordForm = reactive({
  current_password: '',
  new_password: '',
  new_password_confirmation: '',
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
  await navigateTo(scope.scope === 'tenant' ? '/admin/tenant/dashboard' : '/admin/central/dashboard')
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

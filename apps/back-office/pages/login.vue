<template>
  <div class="authentication">
    <div class="container">
      <div class="row align-items-center justify-content-center min-vh-100">
        <div class="col-xl-9 col-lg-10">
          <div class="card custom-card overflow-hidden">
            <div class="row g-0">
              <div class="col-lg-6 d-none d-lg-flex np-login-media text-white p-5 align-items-end">
                <div>
                  <h1 class="fw-semibold mb-3">{{ loginHeroTitle }}</h1>
                  <p class="mb-0 opacity-75">{{ loginHeroSubtitle }}</p>
                </div>
              </div>
              <div class="col-lg-6">
                <div class="card-body p-4 p-lg-5">
                  <div class="mb-4">
                    <img :src="loginLogoUrl" :alt="loginLogoAlt" height="34" class="mb-3" data-partner-login-brand-logo />
                    <h4 class="mb-1" data-partner-login-brand-name>{{ loginTitle }}</h4>
                    <p class="text-muted mb-0">{{ loginSubtitle }}</p>
                  </div>
                  <AdminAlert v-if="notice" type="warning" :message="notice" dismissible @dismiss="notice = ''" />
                  <AdminAlert v-if="error" type="danger" :message="error.message" :details="error.details" dismissible @dismiss="error = null" />
                  <AdminAlert v-if="isPartnerBoMode && siteConfigError" type="warning" :message="t('login.brandingWarning')" dismissible @dismiss="siteConfigError = null" />
                  <form @submit.prevent="submit">
                    <div class="mb-3">
                      <label class="form-label">{{ t('common.usernameEmail') }}</label>
                      <input v-model="form.email" type="text" class="form-control" autocomplete="username" required />
                    </div>
                    <div class="mb-3">
                      <label class="form-label">{{ t('common.password') }}</label>
                      <input v-model="form.password" type="password" class="form-control" autocomplete="current-password" required />
                    </div>
                    <div v-if="!isPartnerBoMode" class="mb-0" data-central-login-scope-controls>
                      <div>
                        <label class="form-label">{{ t('common.scope') }}</label>
                        <select v-model="form.scope" class="form-select">
                          <option value="central">{{ t('common.central') }}</option>
                          <option value="tenant">{{ t('common.tenant') }}</option>
                        </select>
                      </div>
                    </div>
                    <div v-else class="alert alert-primary d-flex align-items-center mb-0" data-partner-login-tenant-only>
                      <i class="ri-building-line me-2" />
                      <span>{{ t('login.tenantOnly') }} {{ partnerDisplayName }}</span>
                    </div>
                    <button class="btn btn-primary btn-wave w-100 mt-4" type="submit" :disabled="loading">
                      <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
                      {{ t('common.signIn') }}
                    </button>
                  </form>
                  <div class="alert alert-info mt-4 mb-0">
                    <i class="ri-shield-check-line me-2" />
                    {{ t('login.sourceOfTruth') }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false })

const api = useAdminApi()
const session = useAdminSession()
const { t } = useAdminLocale()
const hostMode = useAdminHostMode()
const adminSiteConfig = useAdminSiteConfig()
const route = useRoute()
const loading = ref(false)
const error = ref<any>(null)
const notice = ref('')
const isPartnerBoMode = computed(() => hostMode.isPartnerBoHost.value)
const partnerDisplayName = computed(() => adminSiteConfig.displayName.value || 'Partner Back Office')
const loginHeroTitle = computed(() => isPartnerBoMode.value ? partnerDisplayName.value : t('login.heroTitle'))
const loginHeroSubtitle = computed(() => (
  isPartnerBoMode.value
    ? t('login.partnerHeroSubtitle')
    : t('login.heroSubtitle')
))
const loginTitle = computed(() => isPartnerBoMode.value ? `${partnerDisplayName.value} ${t('login.partnerTitleSuffix')}` : t('login.title'))
const loginSubtitle = computed(() => (
  isPartnerBoMode.value
    ? t('login.partnerSubtitle')
    : t('login.subtitle')
))
const defaultLoginLogoUrl = '/admin-template/assets/images/brand-logos/desktop-logo.png'
const loginLogoUrl = computed(() => isPartnerBoMode.value ? adminSiteConfig.logoUrl.value || defaultLoginLogoUrl : defaultLoginLogoUrl)
const loginLogoAlt = computed(() => isPartnerBoMode.value ? partnerDisplayName.value : 'NewPaotang')
const siteConfigError = computed({
  get: () => adminSiteConfig.error.value,
  set: (value) => {
    adminSiteConfig.error.value = value
  },
})
const form = reactive({
  email: '',
  password: '',
  scope: 'central',
})

onMounted(async () => {
  if (isPartnerBoMode.value) {
    form.scope = 'tenant'
    await adminSiteConfig.load()

    if (adminSiteConfig.maintenanceActive.value) {
      session.clear()
      await navigateTo('/maintenance')
      return
    }
  }

  session.restore()
  notice.value = session.consumeAuthNotice()

  if (!session.isAuthenticated.value) {
    return
  }

  if (isPartnerBoMode.value && !session.ensurePartnerTenantSession()) {
    session.clear()
      notice.value = notice.value || t('login.partnerRequiresTenant')
    return
  }

  try {
    await api.apiFetch('/auth/admin/me', {
      scope: isPartnerBoMode.value ? 'tenant' : session.currentScope.value,
      tenantId: session.currentTenantId.value,
      successMessage: false,
    })
    navigateTo(afterLoginPath(isPartnerBoMode.value ? 'tenant' : session.currentScope.value))
  } catch {
    session.clear()
    notice.value = notice.value || t('login.sessionExpired')
  }
})

const submit = async () => {
  loading.value = true
  error.value = null

  try {
    const scope = isPartnerBoMode.value ? 'tenant' : form.scope as 'central' | 'tenant'
    await api.login({
      email: form.email,
      password: form.password,
      scope,
    })
    await navigateTo(afterLoginPath(scope))
  } catch (err) {
    if (isPartnerBoMode.value && (err as any)?.code === 'maintenance_active') {
      adminSiteConfig.clear()
      await adminSiteConfig.load()
      await navigateTo('/maintenance')
      return
    }

    error.value = err
  } finally {
    loading.value = false
  }
}

const afterLoginPath = (scope: 'central' | 'tenant') => {
  const target = safeRedirectTarget(route.query.redirect, scope)
  const landing = session.landingPath(scope)
  if (isPartnerBoMode.value) {
    return target || landing
  }

  if (session.usesTranslationCenterLanding(scope) || session.usesRewardEntryLanding(scope)) {
    return target === landing ? target : landing
  }

  return target || landing
}

const safeRedirectTarget = (value: unknown, scope: 'central' | 'tenant') => {
  const target = Array.isArray(value) ? value[0] : value
  if (typeof target !== 'string' || target.startsWith('//') || !isRoutableAdminPath(target)) {
    return ''
  }

  if (isPartnerBoMode.value) {
    return isScopePath(target, 'tenant') ? target : ''
  }

  if (isScopePath(target, 'central') && scope !== 'central') {
    return ''
  }

  if (isScopePath(target, 'tenant') && scope !== 'tenant') {
    return ''
  }

  return target
}

const isAdminPath = (target: string) => target === '/admin' || target.startsWith('/admin/')

const isRoutableAdminPath = (target: string) => (
  isAdminPath(target)
  && target !== '/admin/login'
)

const isScopePath = (target: string, scope: 'central' | 'tenant') => (
  target === `/admin/${scope}` || target.startsWith(`/admin/${scope}/`)
)
</script>

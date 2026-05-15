<template>
  <div class="authentication">
    <div class="container">
      <div class="row align-items-center justify-content-center min-vh-100">
        <div class="col-xl-9 col-lg-10">
          <div class="card custom-card overflow-hidden">
            <div class="row g-0">
              <div class="col-lg-6 d-none d-lg-flex np-login-media text-white p-5 align-items-end">
                <div>
                  <h1 class="fw-semibold mb-3">NewPaotang Back Office</h1>
                  <p class="mb-0 opacity-75">Central and tenant operations, rendered through backend RBAC menus and Meno dashboard patterns.</p>
                </div>
              </div>
              <div class="col-lg-6">
                <div class="card-body p-4 p-lg-5">
                  <div class="mb-4">
                    <img src="/admin-template/assets/images/brand-logos/desktop-logo.png" alt="NewPaotang" height="34" class="mb-3" />
                    <h4 class="mb-1">Admin sign in</h4>
                    <p class="text-muted mb-0">Use an approved central or tenant admin account.</p>
                  </div>
                  <AdminAlert v-if="notice" type="warning" :message="notice" dismissible @dismiss="notice = ''" />
                  <AdminAlert v-if="error" type="danger" :message="error.message" :details="error.details" dismissible @dismiss="error = null" />
                  <form @submit.prevent="submit">
                    <div class="mb-3">
                      <label class="form-label">Email</label>
                      <input v-model="form.email" type="email" class="form-control" autocomplete="username" required />
                    </div>
                    <div class="mb-3">
                      <label class="form-label">Password</label>
                      <input v-model="form.password" type="password" class="form-control" autocomplete="current-password" required />
                    </div>
                    <div class="row g-2">
                      <div class="col-sm-5">
                        <label class="form-label">Scope</label>
                        <select v-model="form.scope" class="form-select">
                          <option value="central">Central</option>
                          <option value="tenant">Tenant</option>
                        </select>
                      </div>
                      <div class="col-sm-7">
                        <label class="form-label">Tenant ID</label>
                        <input v-model="form.tenant_id" class="form-control" :disabled="form.scope === 'central'" placeholder="Required for tenant login" />
                      </div>
                    </div>
                    <button class="btn btn-primary btn-wave w-100 mt-4" type="submit" :disabled="loading">
                      <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
                      Sign in
                    </button>
                  </form>
                  <div class="alert alert-info mt-4 mb-0">
                    <i class="ri-shield-check-line me-2" />
                    Backend authorization remains the source of truth after login.
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
const route = useRoute()
const loading = ref(false)
const error = ref<any>(null)
const notice = ref('')
const form = reactive({
  email: '',
  password: '',
  scope: 'central',
  tenant_id: '',
})

onMounted(() => {
  session.restore()
  notice.value = session.consumeAuthNotice()
  if (session.isAuthenticated.value) {
    navigateTo(afterLoginPath(session.currentScope.value))
  }
})

const submit = async () => {
  loading.value = true
  error.value = null

  try {
    await api.login({
      email: form.email,
      password: form.password,
      scope: form.scope,
      tenant_id: form.scope === 'tenant' ? form.tenant_id : null,
    })
    await navigateTo(afterLoginPath(form.scope as 'central' | 'tenant'))
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const afterLoginPath = (scope: 'central' | 'tenant') => {
  const target = safeRedirectTarget(route.query.redirect, scope)
  return target || (scope === 'tenant' ? '/admin/tenant/dashboard' : '/admin/central/dashboard')
}

const safeRedirectTarget = (value: unknown, scope: 'central' | 'tenant') => {
  const target = Array.isArray(value) ? value[0] : value
  if (typeof target !== 'string' || target.startsWith('//') || !isRoutableAdminPath(target)) {
    return ''
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

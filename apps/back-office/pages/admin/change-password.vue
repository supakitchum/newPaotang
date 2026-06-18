<template>
  <div class="authentication np-forced-password-page">
    <div class="container">
      <div class="row align-items-center justify-content-center min-vh-100 py-4">
        <div class="col-xl-5 col-lg-6 col-md-8">
          <div class="card custom-card overflow-hidden">
            <div class="card-body p-4 p-lg-5">
              <div class="mb-4 text-center">
                <span class="avatar avatar-xl bg-primary-transparent text-primary mb-3">
                  <i class="ri-lock-password-line fs-2" />
                </span>
                <h4 class="mb-2">{{ t('account.forcePasswordTitle') }}</h4>
                <p class="text-muted mb-0">{{ t('account.forcePasswordSubtitle') }}</p>
              </div>

              <AdminAlert
                v-if="error"
                type="danger"
                :message="error.message"
                :details="error.details"
                dismissible
                @dismiss="error = null"
              />

              <form class="vstack gap-3" @submit.prevent="submit">
                <div>
                  <label class="form-label">{{ t('account.currentPassword') }}</label>
                  <input
                    v-model="form.current_password"
                    class="form-control form-control-lg"
                    type="password"
                    autocomplete="current-password"
                    required
                  >
                </div>
                <div>
                  <label class="form-label">{{ t('account.newPassword') }}</label>
                  <input
                    v-model="form.new_password"
                    class="form-control form-control-lg"
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
                    v-model="form.new_password_confirmation"
                    class="form-control form-control-lg"
                    type="password"
                    autocomplete="new-password"
                    minlength="8"
                    required
                  >
                </div>
                <button class="btn btn-primary btn-wave btn-lg w-100 mt-2" type="submit" :disabled="submitting">
                  <span v-if="submitting" class="spinner-border spinner-border-sm me-2" aria-hidden="true" />
                  {{ t('account.updatePassword') }}
                </button>
              </form>
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
const submitting = ref(false)
const error = ref<{ message: string, details?: any } | null>(null)
const form = reactive({
  current_password: '',
  new_password: '',
  new_password_confirmation: '',
})

onMounted(() => {
  session.restore()

  if (!session.isAuthenticated.value) {
    navigateTo('/login')
    return
  }

  if (!session.mustChangePassword.value) {
    navigateTo(session.landingPath())
  }
})

const submit = async () => {
  error.value = null

  if (form.new_password !== form.new_password_confirmation) {
    error.value = { message: t('account.passwordMismatch') }
    return
  }

  submitting.value = true
  try {
    await api.apiFetch('/auth/admin/password/change', {
      method: 'POST',
      body: { ...form },
      idempotencyKey: api.idempotencyKey(),
      successMessage: false,
    })
    session.clear()
    session.rememberAuthNotice(t('account.forcePasswordChangedNotice'))
    await navigateTo('/login')
  } catch (err: any) {
    error.value = {
      message: err?.message || t('errors.failed'),
      details: err?.details || null,
    }
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.np-forced-password-page {
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, rgba(37, 99, 235, 0.16), transparent 32rem),
    linear-gradient(180deg, #f8fbff 0%, #eef4fb 100%);
}
</style>

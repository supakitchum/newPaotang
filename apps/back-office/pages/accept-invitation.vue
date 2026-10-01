<template>
  <div class="authentication">
    <div class="container">
      <div class="row align-items-center justify-content-center min-vh-100 py-4">
        <div class="col-xl-5 col-lg-6 col-md-8">
          <div class="card custom-card">
            <div class="card-body p-4 p-lg-5">
              <div class="text-center mb-4">
                <span class="avatar avatar-xl bg-primary-transparent text-primary mb-3">
                  <i class="ri-shield-user-line fs-2" />
                </span>
                <h4 class="mb-1">Set up your admin account</h4>
                <p class="text-muted mb-0">Create a password before signing in to Back Office.</p>
              </div>

              <div v-if="loading" class="text-center py-5">
                <span class="spinner-border text-primary" />
              </div>

              <template v-else-if="accepted">
                <AdminAlert type="success" message="Your admin account is ready. You can now sign in with your username." />
                <div class="border rounded p-3 mb-4">
                  <span class="text-muted d-block small">Username</span>
                  <strong class="font-monospace">{{ invitation?.username }}</strong>
                </div>
                <NuxtLink class="btn btn-primary btn-wave w-100" to="/login">Go to sign in</NuxtLink>
              </template>

              <template v-else-if="invitation">
                <div class="border rounded p-3 mb-4">
                  <div class="d-flex justify-content-between gap-3 mb-2">
                    <span class="text-muted">Name</span>
                    <strong class="text-end">{{ invitation.name }}</strong>
                  </div>
                  <div class="d-flex justify-content-between gap-3 mb-2">
                    <span class="text-muted">Username</span>
                    <strong class="font-monospace text-end">{{ invitation.username }}</strong>
                  </div>
                  <div class="d-flex justify-content-between gap-3">
                    <span class="text-muted">Email</span>
                    <span class="text-end">{{ invitation.email_masked }}</span>
                  </div>
                </div>

                <AdminAlert v-if="error" type="danger" :message="error.message" :details="error.details" dismissible @dismiss="error = null" />

                <form @submit.prevent="acceptInvitation">
                  <div class="mb-3">
                    <label class="form-label">Password</label>
                    <input v-model="form.password" class="form-control" type="password" minlength="8" autocomplete="new-password" required>
                  </div>
                  <div class="mb-4">
                    <label class="form-label">Confirm password</label>
                    <input v-model="form.password_confirmation" class="form-control" type="password" minlength="8" autocomplete="new-password" required>
                  </div>
                  <button class="btn btn-primary btn-wave w-100" type="submit" :disabled="saving">
                    <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                    Activate account
                  </button>
                </form>
              </template>

              <template v-else>
                <AdminAlert type="danger" :message="error?.message || 'This invitation link is invalid or has expired.'" />
                <NuxtLink class="btn btn-light btn-wave w-100 mt-3" to="/login">Back to sign in</NuxtLink>
              </template>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false })

const route = useRoute()
const api = useAdminApi()
const loading = ref(true)
const saving = ref(false)
const accepted = ref(false)
const invitation = ref<Record<string, any> | null>(null)
const error = ref<any>(null)
const form = reactive({
  password: '',
  password_confirmation: '',
})
const token = computed(() => String(Array.isArray(route.query.token) ? route.query.token[0] : route.query.token || '').trim())

useHead({
  title: 'Accept admin invitation',
  meta: [{ name: 'referrer', content: 'no-referrer' }],
})

onMounted(loadInvitation)

async function loadInvitation() {
  loading.value = true
  error.value = null

  try {
    if (!token.value) {
      throw { message: 'The invitation token is missing.' }
    }

    const response: any = await api.apiFetch(`/auth/admin/invitations/${encodeURIComponent(token.value)}`, {
      auth: false,
      successMessage: false,
    })
    invitation.value = response?.invitation || null
  } catch (err) {
    error.value = err
    invitation.value = null
  } finally {
    loading.value = false
  }
}

async function acceptInvitation() {
  saving.value = true
  error.value = null

  try {
    await api.apiFetch(`/auth/admin/invitations/${encodeURIComponent(token.value)}/accept`, {
      method: 'POST',
      auth: false,
      successMessage: false,
      idempotencyKey: api.idempotencyKey(),
      body: form,
    })
    accepted.value = true
  } catch (err) {
    error.value = err
  } finally {
    saving.value = false
  }
}
</script>

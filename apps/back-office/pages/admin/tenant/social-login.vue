<template>
  <div>
    <AdminPageHeader title="Social Login" :breadcrumbs="['Admin', 'Tenant', 'Social Login']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading || !tenantId" @click="loadSettings">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before editing social login settings." />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message || 'Unable to update social login settings.'" :details="error.details" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="np-social-grid">
      <section v-for="provider in providers" :key="provider.provider" class="card custom-card np-social-card">
        <div class="card-header">
          <div class="np-social-title">
            <span class="np-social-icon" :class="providerIconClass(provider.provider)">
              <i :class="providerIcon(provider.provider)" />
            </span>
            <div>
              <div class="card-title mb-1">{{ provider.label }}</div>
              <div class="text-muted fs-12">{{ providerSubtitle(provider) }}</div>
            </div>
          </div>
          <div class="ms-auto d-flex flex-wrap gap-2">
            <AdminStatusBadge :status="provider.ready ? 'active' : provider.status || 'inactive'" :label="provider.ready ? 'Ready' : titleize(provider.status || 'inactive')" />
            <span v-if="provider.managed_elsewhere" class="badge bg-info-transparent text-info">Managed elsewhere</span>
          </div>
        </div>

        <div class="card-body">
          <div v-if="provider.provider === 'line'" class="np-managed-provider">
            <p class="mb-3 text-muted">
              LINE Login uses the same LINE OA connection already configured in LINE Notifications.
            </p>
            <div class="np-callback-box">
              <div class="text-muted fs-12 text-uppercase fw-semibold">Callback URL</div>
              <code>{{ callbackUrls.line || '-' }}</code>
            </div>
            <button class="btn btn-success-light btn-wave mt-3" type="button" @click="goLineSettings">
              <i class="ri-line-line me-1" />
              Open LINE Notifications
            </button>
          </div>

          <form v-else class="np-provider-form" @submit.prevent="saveProvider(provider.provider)">
            <div class="row g-3">
              <div class="col-md-4">
                <label class="form-label">Status</label>
                <select v-model="forms[provider.provider].status" class="form-select">
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </select>
              </div>
              <div class="col-md-8">
                <label class="form-label">Client ID</label>
                <input v-model.trim="forms[provider.provider].client_id" class="form-control" autocomplete="off" :placeholder="provider.client_id_masked || 'Client ID / Services ID'">
                <div v-if="provider.client_id_masked" class="form-text">Saved: {{ provider.client_id_masked }}</div>
              </div>

              <template v-if="provider.provider === 'google'">
                <div class="col-12">
                  <label class="form-label">Client Secret</label>
                  <input v-model="forms.google.client_secret" class="form-control" type="password" autocomplete="off" :placeholder="provider.client_secret_configured ? 'Leave blank to keep existing secret' : 'Google client secret'">
                  <div v-if="provider.client_secret_configured" class="form-text">Saved and encrypted.</div>
                </div>
              </template>

              <template v-else-if="provider.provider === 'apple'">
                <div class="col-md-6">
                  <label class="form-label">Team ID</label>
                  <input v-model.trim="forms.apple.team_id" class="form-control" autocomplete="off" :placeholder="provider.team_id_masked || 'Apple Developer Team ID'">
                </div>
                <div class="col-md-6">
                  <label class="form-label">Key ID</label>
                  <input v-model.trim="forms.apple.key_id" class="form-control" autocomplete="off" :placeholder="provider.key_id_masked || 'Sign in with Apple key ID'">
                </div>
                <div class="col-12">
                  <label class="form-label">Private Key</label>
                  <textarea v-model="forms.apple.private_key" class="form-control np-private-key" rows="6" spellcheck="false" :placeholder="provider.private_key_configured ? 'Leave blank to keep existing private key' : 'Paste .p8 private key'"></textarea>
                  <div v-if="provider.private_key_configured" class="form-text">Saved and encrypted.</div>
                </div>
              </template>

              <div class="col-12">
                <div class="np-callback-box">
                  <div class="text-muted fs-12 text-uppercase fw-semibold">Callback URL</div>
                  <code>{{ provider.redirect_uri || callbackUrls[provider.provider] || '-' }}</code>
                </div>
              </div>
            </div>

            <div class="np-card-actions">
              <button
                v-if="provider.configured"
                class="btn btn-outline-danger btn-wave"
                type="button"
                :disabled="saving[provider.provider] || disconnecting[provider.provider]"
                @click="disconnectProvider(provider.provider)"
              >
                <span v-if="disconnecting[provider.provider]" class="spinner-border spinner-border-sm me-2" />
                Disconnect
              </button>
              <div v-else />
              <button class="btn btn-primary btn-wave" type="submit" :disabled="saving[provider.provider] || disconnecting[provider.provider] || !tenantId">
                <span v-if="saving[provider.provider]" class="spinner-border spinner-border-sm me-2" />
                Save {{ provider.label }}
              </button>
            </div>
          </form>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

const api = useAdminApi()
const session = useAdminSession()

const loading = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const providers = ref<any[]>([])
const callbackUrls = ref<Record<string, string>>({})
const saving = ref<Record<string, boolean>>({})
const disconnecting = ref<Record<string, boolean>>({})
const forms = reactive<Record<string, any>>({
  google: {
    status: 'inactive',
    client_id: '',
    client_secret: '',
  },
  apple: {
    status: 'inactive',
    client_id: '',
    team_id: '',
    key_id: '',
    private_key: '',
  },
})

const tenantId = computed(() => session.currentTenantId.value)

const loadSettings = async () => {
  if (!tenantId.value) return
  loading.value = true
  error.value = null

  try {
    const response: any = await api.apiFetch('/admin/tenant/social-login', {
      scope: 'tenant',
      tenantId: tenantId.value,
    })
    providers.value = Array.isArray(response?.data?.providers) ? response.data.providers : []
    callbackUrls.value = response?.data?.callback_urls || {}
    providers.value.forEach((provider) => applyProviderToForm(provider))
  } catch (err: any) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const saveProvider = async (provider: string) => {
  if (!tenantId.value || !forms[provider]) return
  saving.value = { ...saving.value, [provider]: true }
  error.value = null
  successMessage.value = ''

  try {
    const payload = { ...forms[provider] }
    const response: any = await api.apiFetch(`/admin/tenant/social-login/${provider}`, {
      method: 'PUT',
      scope: 'tenant',
      tenantId: tenantId.value,
      body: payload,
      successMessage: false,
    })
    providers.value = Array.isArray(response?.data?.providers) ? response.data.providers : providers.value
    callbackUrls.value = response?.data?.callback_urls || callbackUrls.value
    providers.value.forEach((item) => applyProviderToForm(item))
    successMessage.value = `${providerLabel(provider)} settings saved.`
  } catch (err: any) {
    error.value = err
  } finally {
    saving.value = { ...saving.value, [provider]: false }
  }
}

const disconnectProvider = async (provider: string) => {
  if (!tenantId.value) return
  disconnecting.value = { ...disconnecting.value, [provider]: true }
  error.value = null
  successMessage.value = ''

  try {
    const response: any = await api.apiFetch(`/admin/tenant/social-login/${provider}`, {
      method: 'DELETE',
      scope: 'tenant',
      tenantId: tenantId.value,
      successMessage: false,
    })
    providers.value = Array.isArray(response?.data?.providers) ? response.data.providers : providers.value
    providers.value.forEach((item) => applyProviderToForm(item))
    successMessage.value = `${providerLabel(provider)} disconnected.`
  } catch (err: any) {
    error.value = err
  } finally {
    disconnecting.value = { ...disconnecting.value, [provider]: false }
  }
}

const applyProviderToForm = (provider: any) => {
  if (!provider || provider.provider === 'line' || !forms[provider.provider]) return
  forms[provider.provider].status = provider.status || 'inactive'
  forms[provider.provider].client_id = ''
  if (provider.provider === 'google') {
    forms.google.client_secret = ''
  }
  if (provider.provider === 'apple') {
    forms.apple.team_id = ''
    forms.apple.key_id = ''
    forms.apple.private_key = ''
  }
}

const goLineSettings = () => navigateTo('/admin/tenant/line-notifications')

const providerLabel = (provider: string) => {
  if (provider === 'google') return 'Google / Gmail'
  if (provider === 'apple') return 'Apple ID'
  return 'LINE'
}

const providerSubtitle = (provider: any) => {
  if (provider.provider === 'line') return 'Uses LINE Login settings from LINE Notifications.'
  if (provider.provider === 'google') return 'Required when LINE Login is enabled in a mobile app.'
  return 'Required by iOS App Review when other social logins are available.'
}

const providerIcon = (provider: string) => {
  if (provider === 'line') return 'ri-line-line'
  if (provider === 'apple') return 'ri-apple-fill'
  return 'ri-google-fill'
}

const providerIconClass = (provider: string) => ({
  'is-line': provider === 'line',
  'is-google': provider === 'google',
  'is-apple': provider === 'apple',
})

const titleize = (value: any) => String(value || '-').replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase())
const alertType = (err: any) => ([403, 409, 422].includes(Number(err?.status)) ? 'warning' : 'danger')

onMounted(loadSettings)
</script>

<style scoped>
.np-social-grid {
  display: grid;
  gap: 1rem;
}

.np-social-card {
  overflow: hidden;
}

.np-social-title {
  display: flex;
  align-items: center;
  gap: .85rem;
}

.np-social-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 42px;
  height: 42px;
  border-radius: 14px;
  color: #fff;
  font-size: 1.35rem;
  background: #64748b;
}

.np-social-icon.is-line {
  background: #06c755;
}

.np-social-icon.is-google {
  background: #2563eb;
}

.np-social-icon.is-apple {
  background: #111827;
}

.np-provider-form,
.np-managed-provider {
  max-width: 980px;
}

.np-callback-box {
  padding: .85rem 1rem;
  border: 1px solid var(--default-border);
  border-radius: .65rem;
  background: var(--default-background);
  overflow-x: auto;
}

.np-callback-box code {
  color: var(--default-text-color);
  white-space: nowrap;
}

.np-private-key {
  min-height: 140px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
}

.np-card-actions {
  display: flex;
  justify-content: space-between;
  gap: .75rem;
  margin-top: 1.25rem;
  padding-top: 1rem;
  border-top: 1px solid var(--default-border);
}

@media (max-width: 575.98px) {
  .np-card-actions {
    flex-direction: column-reverse;
  }

  .np-card-actions .btn,
  .np-managed-provider .btn {
    width: 100%;
  }
}
</style>

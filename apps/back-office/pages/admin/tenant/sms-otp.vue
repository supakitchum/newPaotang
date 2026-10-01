<template>
  <div>
    <AdminPageHeader title="SMS OTP" :breadcrumbs="['Admin', 'Tenant', 'SMS OTP']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading || !tenantId" @click="loadSettings">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before editing SMS OTP settings." />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message || 'Unable to update SMS OTP settings.'" :details="error.details" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="row g-3">
      <div class="col-xl-7">
        <div class="card custom-card h-100">
          <div class="card-header">
            <div>
              <div class="card-title">ThaiBulkSMS connection</div>
              <div class="text-muted fs-12">Credentials are encrypted and never shown again after saving.</div>
            </div>
            <div class="ms-auto">
              <AdminStatusBadge :status="connection.ready ? 'active' : connection.status || 'inactive'" :label="connection.ready ? 'Ready' : titleize(connection.status || 'inactive')" />
            </div>
          </div>
          <div class="card-body">
            <form class="row g-3" @submit.prevent="saveConnection">
              <div class="col-md-6">
                <label class="form-label">Provider</label>
                <input class="form-control" value="ThaiBulkSMS" disabled>
              </div>
              <div class="col-md-6">
                <label class="form-label">Status</label>
                <select v-model="connectionForm.status" class="form-select">
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">API Key</label>
                <input v-model="connectionForm.api_key" class="form-control" type="password" autocomplete="off" :placeholder="connection.api_key_masked || 'Paste API key'">
                <div v-if="connection.api_key_configured" class="form-text">Saved: {{ connection.api_key_masked }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">API Secret</label>
                <input v-model="connectionForm.api_secret" class="form-control" type="password" autocomplete="off" :placeholder="connection.api_secret_configured ? 'Leave blank to keep existing secret' : 'Paste API secret'">
                <div v-if="connection.api_secret_configured" class="form-text">Saved and encrypted.</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">ThaiBulkSMS Sender ID</label>
                <input
                  v-model.trim="connectionForm.sender_name"
                  class="form-control"
                  :class="{ 'is-invalid': senderNameInvalid }"
                  maxlength="11"
                  placeholder="Optional approved Sender ID"
                >
                <div v-if="senderNameInvalid" class="invalid-feedback d-block">
                  Use English letters, numbers, dot, dash, or underscore only, up to 11 characters.
                </div>
                <div class="form-text">
                  Use an approved Sender ID from ThaiBulkSMS. Leave blank to use the provider default sender.
                </div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Last test</label>
                <div class="np-sms-test-state">
                  <span class="badge" :class="connection.last_test_status === 'sent' ? 'bg-success-transparent text-success' : 'bg-light text-muted'">
                    {{ connection.last_test_status || 'Not tested' }}
                  </span>
                  <span class="text-muted fs-12">{{ formatDateTime(connection.last_tested_at) }}</span>
                </div>
              </div>
              <div class="col-12 d-flex justify-content-end gap-2">
                <button class="btn btn-primary btn-wave" type="submit" :disabled="saving || !tenantId">
                  <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                  Save connection
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>

      <div class="col-xl-5">
        <div class="card custom-card h-100">
          <div class="card-header">
            <div>
              <div class="card-title">Test send</div>
              <div class="text-muted fs-12">Send a test OTP message before enabling customer flows.</div>
            </div>
          </div>
          <div class="card-body">
            <form class="np-sms-test-form" @submit.prevent="testSend">
              <label class="form-label">Phone number</label>
              <div class="input-group">
                <input v-model.trim="testPhone" class="form-control" inputmode="tel" placeholder="08xxxxxxxx">
                <button class="btn btn-success btn-wave" type="submit" :disabled="testing || saving || !tenantId">
                  <span v-if="testing" class="spinner-border spinner-border-sm me-1" />
                  Send test
                </button>
              </div>
              <div class="form-text">Test send will save entered credentials first. Customer OTP flows only use this provider when status is active.</div>
            </form>
          </div>
        </div>
      </div>

      <div class="col-12">
        <AdminDataTable
          title="Saved provider API keys"
          :columns="providerColumns"
          :rows="providers"
          :loading="loading"
          empty-title="No SMS provider keys"
          empty-message="Save ThaiBulkSMS credentials to manage provider activation here."
          sortable
        >
          <template #cell-status="{ row }">
            <AdminStatusBadge :status="row.status" :label="titleize(row.status)" />
          </template>
          <template #cell-api_key_configured="{ row }">
            <span class="badge" :class="row.api_key_configured && row.api_secret_configured ? 'bg-success-transparent text-success' : 'bg-warning-transparent text-warning'">
              {{ row.api_key_configured && row.api_secret_configured ? 'Configured' : 'Missing secret' }}
            </span>
          </template>
          <template #cell-sender_name="{ row }">
            {{ row.sender_name || 'Provider default' }}
          </template>
          <template #cell-last_test_status="{ row }">
            <span class="badge" :class="row.last_test_status === 'sent' ? 'bg-success-transparent text-success' : row.last_test_status === 'failed' ? 'bg-danger-transparent text-danger' : 'bg-light text-muted'">
              {{ titleize(row.last_test_status || 'not_tested') }}
            </span>
          </template>
          <template #cell-last_tested_at="{ row }">
            {{ formatDateTime(row.last_tested_at) }}
          </template>
          <template #rowActions="{ row }">
            <button
              class="btn btn-sm btn-wave"
              :class="row.status === 'active' ? 'btn-outline-danger' : 'btn-outline-success'"
              type="button"
              :disabled="providerStatusLoading[row.id] || saving || testing"
              @click="toggleProvider(row)"
            >
              <span v-if="providerStatusLoading[row.id]" class="spinner-border spinner-border-sm me-1" />
              {{ row.status === 'active' ? 'Deactivate' : 'Activate' }}
            </button>
          </template>
        </AdminDataTable>
      </div>

      <div class="col-xl-6">
        <AdminDataTable
          title="SMS delivery logs"
          :columns="deliveryColumns"
          :rows="deliveries"
          :loading="loading"
          empty-title="No SMS deliveries"
          empty-message="OTP and test-send deliveries will appear here."
          sortable
        >
          <template #cell-status="{ row }">
            <span class="badge" :class="statusBadgeClass(row.status)">{{ titleize(row.status) }}</span>
          </template>
          <template #cell-created_at="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </AdminDataTable>
      </div>

      <div class="col-xl-6">
        <AdminDataTable
          title="OTP verification logs"
          :columns="otpColumns"
          :rows="otps"
          :loading="loading"
          empty-title="No OTP requests"
          empty-message="Customer OTP requests will appear here."
          sortable
        >
          <template #cell-purpose="{ row }">
            {{ purposeLabel(row.purpose) }}
          </template>
          <template #cell-status="{ row }">
            <span class="badge" :class="statusBadgeClass(row.status)">{{ titleize(row.status) }}</span>
          </template>
          <template #cell-created_at="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </AdminDataTable>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

const api = useAdminApi()
const session = useAdminSession()

const loading = ref(false)
const saving = ref(false)
const testing = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const connection = ref<any>({})
const providers = ref<any[]>([])
const deliveries = ref<any[]>([])
const otps = ref<any[]>([])
const testPhone = ref('')
const providerStatusLoading = ref<Record<string, boolean>>({})
const connectionForm = reactive({
  provider: 'thaibulk',
  status: 'inactive',
  api_key: '',
  api_secret: '',
  sender_name: '',
})

const tenantId = computed(() => session.currentTenantId.value)
const hasSavedCredentials = computed(() => Boolean(connection.value.api_key_configured && connection.value.api_secret_configured))
const hasTypedCredentials = computed(() => Boolean(connectionForm.api_key.trim() && connectionForm.api_secret.trim()))
const connectionStatusChanged = computed(() => String(connectionForm.status || 'inactive') !== String(connection.value.status || 'inactive'))
const senderChanged = computed(() => String(connectionForm.sender_name || '') !== String(connection.value.sender_name || ''))
const shouldSaveBeforeTest = computed(() => !hasSavedCredentials.value || hasTypedCredentials.value || connectionStatusChanged.value || senderChanged.value)
const senderNameInvalid = computed(() => {
  const sender = String(connectionForm.sender_name || '').trim()
  return sender !== '' && !/^[A-Za-z0-9._-]{1,11}$/.test(sender)
})
const providerColumns = [
  { key: 'provider_label', label: 'Provider' },
  { key: 'status', label: 'Status' },
  { key: 'api_key_configured', label: 'API key' },
  { key: 'sender_name', label: 'Sender ID' },
  { key: 'last_test_status', label: 'Last test' },
  { key: 'last_tested_at', label: 'Last tested' },
]
const deliveryColumns = [
  { key: 'purpose', label: 'Purpose' },
  { key: 'phone_masked', label: 'Phone' },
  { key: 'status', label: 'Status' },
  { key: 'http_status', label: 'HTTP' },
  { key: 'latency_ms', label: 'Latency ms', type: 'number' },
  { key: 'created_at', label: 'Sent at' },
]
const otpColumns = [
  { key: 'purpose', label: 'Purpose' },
  { key: 'phone_masked', label: 'Phone' },
  { key: 'status', label: 'Status' },
  { key: 'attempts', label: 'Attempts', type: 'number' },
  { key: 'created_at', label: 'Requested at' },
]

const loadSettings = async () => {
  if (!tenantId.value) return
  loading.value = true
  error.value = null

  try {
    const response: any = await api.apiFetch('/admin/tenant/sms-otp', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: { limit: 50 },
    })
    connection.value = response.connection || {}
    providers.value = Array.isArray(response.providers) ? response.providers : []
    deliveries.value = Array.isArray(response.deliveries) ? response.deliveries : []
    otps.value = Array.isArray(response.otps) ? response.otps : []
    hydrateForm()
  } catch (err: any) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const hydrateForm = () => {
  connectionForm.status = connection.value.status || (hasSavedCredentials.value ? 'inactive' : 'active')
  connectionForm.sender_name = connection.value.sender_name || ''
  connectionForm.api_key = ''
  connectionForm.api_secret = ''
}

const persistConnection = async () => {
  await api.apiFetch('/admin/tenant/sms-otp/connection', {
    method: 'PUT',
    scope: 'tenant',
    tenantId: tenantId.value,
    body: { ...connectionForm },
    successMessage: false,
  })
  await loadSettings()
}

const saveConnection = async () => {
  if (!tenantId.value) return
  if (!assertValidSenderName()) return
  saving.value = true
  error.value = null
  successMessage.value = ''

  try {
    await persistConnection()
    successMessage.value = 'SMS OTP connection saved.'
  } catch (err: any) {
    error.value = err
  } finally {
    saving.value = false
  }
}

const testSend = async () => {
  if (!tenantId.value) return
  if (!assertValidSenderName()) return
  if (!normalizePhone(testPhone.value)) {
    error.value = {
      status: 422,
      message: 'Enter a valid phone number before sending a test SMS.',
      details: { fields: { phone: ['Use a Thai mobile number such as 08xxxxxxxx.'] } },
    }
    return
  }
  if (!hasSavedCredentials.value && !hasTypedCredentials.value) {
    error.value = {
      status: 422,
      message: 'Enter ThaiBulkSMS API key and API secret before sending a test SMS.',
      details: { fields: { api_key: ['API key is required.'], api_secret: ['API secret is required.'] } },
    }
    return
  }

  testing.value = true
  error.value = null
  successMessage.value = ''

  try {
    if (shouldSaveBeforeTest.value) {
      await persistConnection()
    }
    await api.apiFetch('/admin/tenant/sms-otp/test-send', {
      method: 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      body: { phone: testPhone.value },
      successMessage: false,
    })
    successMessage.value = 'Test SMS sent.'
    await loadSettings()
  } catch (err: any) {
    error.value = err
  } finally {
    testing.value = false
  }
}

const toggleProvider = async (provider: any) => {
  const providerId = String(provider?.id || '')
  if (!tenantId.value || providerId === '') return

  const nextStatus = provider.status === 'active' ? 'inactive' : 'active'
  providerStatusLoading.value = { ...providerStatusLoading.value, [providerId]: true }
  error.value = null
  successMessage.value = ''

  try {
    const response: any = await api.apiFetch(`/admin/tenant/sms-otp/providers/${encodeURIComponent(providerId)}/status`, {
      method: 'PATCH',
      scope: 'tenant',
      tenantId: tenantId.value,
      body: { status: nextStatus },
      successMessage: false,
    })
    connection.value = response.connection || connection.value || {}
    providers.value = Array.isArray(response.providers) ? response.providers : providers.value
    deliveries.value = Array.isArray(response.deliveries) ? response.deliveries : deliveries.value
    otps.value = Array.isArray(response.otps) ? response.otps : otps.value
    hydrateForm()
    successMessage.value = nextStatus === 'active' ? 'SMS provider activated.' : 'SMS provider deactivated.'
  } catch (err: any) {
    error.value = err
  } finally {
    providerStatusLoading.value = { ...providerStatusLoading.value, [providerId]: false }
  }
}

const alertType = (err: any) => (Number(err?.status || 500) >= 500 ? 'danger' : 'warning')
const assertValidSenderName = () => {
  if (!senderNameInvalid.value) return true
  error.value = {
    status: 422,
    message: 'ThaiBulkSMS Sender ID is invalid.',
    details: {
      fields: {
        sender_name: [
          'Use an approved English Sender ID with letters, numbers, dot, dash, or underscore only, up to 11 characters, or leave it blank.',
        ],
      },
    },
  }
  successMessage.value = ''
  return false
}
const titleize = (value: any) => String(value || '-').replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase())
const normalizePhone = (value: any) => {
  let phone = String(value || '').replace(/\D/g, '')
  if (phone.startsWith('66') && phone.length === 11) {
    phone = `0${phone.slice(2)}`
  }
  return phone.length >= 9 && phone.length <= 10 ? phone : ''
}
const formatDateTime = (value: any) => {
  if (!value) return '-'
  return new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Bangkok',
  }).format(new Date(value))
}
const statusBadgeClass = (status: any) => {
  const value = String(status || '')
  if (['sent', 'verified', 'consumed', 'active'].includes(value)) return 'bg-success-transparent text-success'
  if (['failed', 'locked'].includes(value)) return 'bg-danger-transparent text-danger'
  return 'bg-warning-transparent text-warning'
}
const purposeLabel = (purpose: any) => {
  const value = String(purpose || '')
  if (value === 'password_reset') return 'Password reset'
  if (value === 'pin_reset') return 'PIN reset'
  return 'Register'
}

onMounted(loadSettings)
</script>

<style scoped>
.np-sms-test-form {
  max-width: 520px;
}

.np-sms-test-state {
  align-items: center;
  display: flex;
  gap: .75rem;
  min-height: 38px;
}
</style>

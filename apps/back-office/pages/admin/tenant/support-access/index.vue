<template>
  <div>
    <AdminPageHeader title="Support Access" :breadcrumbs="['Admin', 'Tenant', 'Support Access']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" @click="openCreate = true">
          <i class="ri-add-line me-1" />
          New request
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="error" :type="error.status === 403 ? 'warning' : 'danger'" :message="error.message" :details="error.details" />

    <div class="card custom-card">
      <div class="card-body">
        <div class="row g-2 align-items-end">
          <div class="col-md-4">
            <label class="form-label">Status</label>
            <select v-model="filters.status" class="form-select">
              <option value="">All</option>
              <option v-for="status in statuses" :key="status" :value="status">{{ titleize(status) }}</option>
            </select>
          </div>
          <div class="col-md-3">
            <label class="form-label">Limit</label>
            <input v-model.number="filters.limit" type="number" min="1" max="100" class="form-control" />
          </div>
          <div class="col-md-3">
            <button class="btn btn-outline-primary btn-wave w-100" type="button" @click="load()">
              <i class="ri-filter-3-line me-1" />
              Apply filters
            </button>
          </div>
        </div>
      </div>
    </div>

    <AdminDataTable
      title="Requests"
      :columns="columns"
      :rows="requests"
      :loading="loading"
      empty-title="No support access requests"
      empty-message="Create a request when support needs approved, audited access."
    >
      <template #cell-status="{ value }">
        <AdminStatusBadge :status="value" />
      </template>
      <template #cell-created_at="{ value }">
        {{ formatDateTime(value) }}
      </template>
      <template #rowActions="{ row }">
        <NuxtLink :to="`/admin/tenant/support-access/${row.id}`" class="btn btn-sm btn-primary btn-wave">
          Detail
        </NuxtLink>
      </template>
    </AdminDataTable>

    <AdminPagination :next-cursor="meta.next_cursor" :loading="loading" @next="load(meta.next_cursor)" />

    <AdminModal v-model="openCreate" title="Create support access request" size="lg">
      <AdminAlert v-if="modalError" type="danger" :message="modalError.message" :details="modalError.details" />
      <form class="row g-3">
        <div class="col-md-6">
          <label class="form-label">Target user type</label>
          <select v-model="form.target_user_type" class="form-select" :class="invalidClass('target_user_type')">
            <option value="customer">Customer</option>
            <option value="tenant_admin">Tenant admin</option>
          </select>
          <div class="invalid-feedback">{{ fieldError('target_user_type') }}</div>
        </div>
        <div class="col-md-6">
          <label class="form-label">Scope</label>
          <select v-model="form.scope" class="form-select" :class="invalidClass('scope')">
            <option value="read_only">Read only</option>
            <option value="support">Support</option>
            <option value="elevated">Elevated</option>
          </select>
          <div class="invalid-feedback">{{ fieldError('scope') }}</div>
        </div>
        <div class="col-md-6">
          <label class="form-label">Target user ID</label>
          <input v-model="form.target_user_id" class="form-control" :class="invalidClass('target_user_id')" />
          <div class="invalid-feedback">{{ fieldError('target_user_id') }}</div>
        </div>
        <div class="col-md-6">
          <label class="form-label">Ticket ID</label>
          <input v-model="form.ticket_id" class="form-control" :class="invalidClass('ticket_id')" />
          <div class="invalid-feedback">{{ fieldError('ticket_id') }}</div>
        </div>
        <div class="col-12">
          <label class="form-label">Reason</label>
          <textarea v-model="form.reason" class="form-control" rows="3" :class="invalidClass('reason')" />
          <div class="invalid-feedback">{{ fieldError('reason') }}</div>
        </div>
      </form>
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" @click="openCreate = false">Cancel</button>
        <button class="btn btn-primary btn-wave" type="button" :disabled="saving" @click="createRequest">
          <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
          Create request
        </button>
      </template>
    </AdminModal>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, titleize } from '~/utils/format'

definePageMeta({ layout: 'admin' })

const api = useAdminApi()
const session = useAdminSession()
const tenantId = computed(() => session.currentTenantId.value)
const loading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const modalError = ref<any>(null)
const validation = ref<Record<string, string[]>>({})
const requests = ref<any[]>([])
const openCreate = ref(false)
const filters = reactive({ status: '', limit: 20 })
const meta = reactive({ next_cursor: null as string | null, has_more: false })
const form = reactive({
  target_user_type: 'customer',
  target_user_id: '',
  scope: 'read_only',
  reason: '',
  ticket_id: '',
})

const statuses = ['pending_approval', 'approved', 'revoked', 'completed', 'expired']
const columns = [
  { key: 'id', label: 'Request' },
  { key: 'target_user_type', label: 'Target type' },
  { key: 'target_user_id', label: 'Target ID' },
  { key: 'status', label: 'Status' },
  { key: 'created_at', label: 'Created' },
]

const fieldError = (field: string) => validation.value[field]?.[0] || ''
const invalidClass = (field: string) => fieldError(field) ? 'is-invalid' : ''

const load = async (cursor?: string | null) => {
  if (!tenantId.value) return
  loading.value = true
  error.value = null
  try {
    const response: any = await api.apiFetch('/admin/tenant/support-access', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: {
        status: filters.status || undefined,
        cursor: cursor || undefined,
        limit: filters.limit,
      },
    })
    requests.value = cursor ? [...requests.value, ...(response.data || [])] : (response.data || [])
    meta.next_cursor = response.meta?.next_cursor || null
    meta.has_more = Boolean(response.meta?.has_more)
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const createRequest = async () => {
  if (!tenantId.value) return
  saving.value = true
  modalError.value = null
  validation.value = {}

  try {
    const created: any = await api.apiFetch('/admin/tenant/support-access', {
      method: 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      body: { ...form },
    })
    openCreate.value = false
    await navigateTo(`/admin/tenant/support-access/${created.id}`)
  } catch (err: any) {
    modalError.value = err
    validation.value = err?.details?.fields || {}
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div>
    <AdminPageHeader title="Central Maintenance" :breadcrumbs="['Admin', 'Central', 'Maintenance']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading" @click="loadRows">
          <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="error" :type="error.status === 403 ? 'warning' : 'danger'" :message="error.message" :details="error.details" />

    <div class="card custom-card">
      <div class="card-body">
        <form class="row g-3 align-items-end" @submit.prevent="loadRows">
          <div class="col-12 col-xl-5">
            <label class="form-label">Search</label>
            <input v-model="filters.q" class="form-control" placeholder="Partner, tenant, or domain" />
          </div>
          <div class="col-12 col-md-4 col-xl-3">
            <label class="form-label">Status</label>
            <select v-model="filters.status" class="form-select">
              <option value="">All statuses</option>
              <option v-for="status in statusOptions" :key="status" :value="status">{{ titleize(status) }}</option>
            </select>
          </div>
          <div class="col-12 col-md-4 col-xl-2">
            <label class="form-label">Limit</label>
            <input v-model.number="filters.limit" class="form-control" type="number" min="1" max="100" step="1" />
          </div>
          <div class="col-12 col-md-4 col-xl-2 d-flex gap-2">
            <button class="btn btn-primary btn-wave flex-fill" type="submit" :disabled="loading">Apply</button>
            <button class="btn btn-light btn-wave" type="button" :disabled="loading" @click="resetFilters">Reset</button>
          </div>
        </form>
      </div>
    </div>

    <AdminDataTable
      title="Partner / Tenant maintenance"
      :columns="columns"
      :rows="sortedRows"
      :loading="loading"
      sortable
      :sort-key="sort.key"
      :sort-direction="sort.direction"
      empty-title="No partners found"
      empty-message="Try changing filters or provision a partner tenant first."
      @sort-change="applySort"
    >
      <template #cell-partner="{ row }">
        <div class="fw-semibold">{{ row.partner_name }}</div>
        <div class="text-muted fs-12">{{ row.partner_code }}</div>
      </template>
      <template #cell-tenant="{ row }">
        <div class="fw-semibold">{{ row.tenant_name }}</div>
        <div class="text-muted fs-12">{{ row.tenant_code }}</div>
      </template>
      <template #cell-domain="{ row }">
        <code v-if="row.domain_host" class="np-admin-code">{{ row.domain_host }}</code>
        <span v-else>-</span>
      </template>
      <template #cell-partner_status="{ value }">
        <AdminStatusBadge :status="value" />
      </template>
      <template #cell-tenant_status="{ value }">
        <AdminStatusBadge :status="value" />
      </template>
      <template #cell-partner_maintenance_status="{ row }">
        <div class="d-flex flex-column gap-1">
          <AdminStatusBadge :status="row.partner_maintenance_status" />
          <span class="text-muted fs-12">
            {{ row.partner_maintenance_active ? 'Partner BO closed by Central' : 'Partner BO open' }}
          </span>
        </div>
      </template>
      <template #cell-maintenance_status="{ row }">
        <div class="d-flex flex-column gap-1">
          <AdminStatusBadge :status="row.maintenance_status" />
          <span class="text-muted fs-12">{{ titleize(row.maintenance_mode || '-') }}</span>
        </div>
      </template>
      <template #rowActions="{ row }">
        <button class="btn btn-sm btn-warning btn-wave me-2" type="button" @click="openPartnerMaintenanceModal(row)">
          <i class="ri-tools-line me-1" />
          Partner maintenance
        </button>
        <button class="btn btn-sm btn-primary btn-wave me-2" type="button" @click="openMaintenanceModal(row)">
          <i class="ri-building-2-line me-1" />
          Tenant maintenance
        </button>
        <button
          v-if="row.partner_status === 'suspended'"
          class="btn btn-sm btn-success btn-wave"
          type="button"
          :disabled="saving"
          @click="openUnsuspendModal(row)"
        >
          <i class="ri-play-circle-line me-1" />
          Unsuspend
        </button>
      </template>
    </AdminDataTable>

    <div v-if="partnerMaintenanceModal.open" class="modal fade show np-central-maintenance-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">Central partner maintenance</h5>
              <div class="text-muted fs-12">
                {{ partnerMaintenanceModal.row?.partner_name || '-' }}
              </div>
            </div>
            <button class="btn-close" type="button" aria-label="Close" @click="closePartnerMaintenanceModal" />
          </div>
          <form @submit.prevent="savePartnerMaintenance">
            <div class="modal-body">
              <AdminAlert v-if="partnerModalError" :type="partnerModalError.status === 403 ? 'warning' : 'danger'" :message="partnerModalError.message" :details="partnerModalError.details" />
              <div class="alert alert-warning">
                <i class="ri-alert-line me-2" />
                Active status closes this partner's Back Office. Central Back Office and tenant customer maintenance remain separate.
              </div>
              <div class="row g-3">
                <div class="col-12 col-md-6">
                  <label class="form-label">Status</label>
                  <select v-model="partnerForm.status" class="form-select" :class="partnerInvalidClass('status')">
                    <option v-for="status in maintenanceStatuses" :key="status" :value="status">{{ titleize(status) }}</option>
                  </select>
                  <div class="invalid-feedback">{{ partnerFieldError('status') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Scope</label>
                  <div class="form-control-plaintext fw-semibold">Partner BO only</div>
                </div>
                <div class="col-12">
                  <label class="form-label">Message</label>
                  <textarea v-model="partnerForm.message" class="form-control" rows="3" :class="partnerInvalidClass('message')" />
                  <div class="invalid-feedback">{{ partnerFieldError('message') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Change reason</label>
                  <input v-model="partnerForm.reason" class="form-control" :class="partnerInvalidClass('reason')" placeholder="Required for audit trail" />
                  <div class="invalid-feedback">{{ partnerFieldError('reason') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Ticket ID</label>
                  <input v-model="partnerForm.ticket_id" class="form-control" :class="partnerInvalidClass('ticket_id')" placeholder="Optional support ticket" />
                  <div class="invalid-feedback">{{ partnerFieldError('ticket_id') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Scheduled start</label>
                  <input v-model="partnerForm.scheduled_start_at" type="datetime-local" class="form-control" :class="partnerInvalidClass('scheduled_start_at')" />
                  <div class="invalid-feedback">{{ partnerFieldError('scheduled_start_at') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Expected end</label>
                  <input v-model="partnerForm.expected_end_at" type="datetime-local" class="form-control" :class="partnerInvalidClass('expected_end_at')" />
                  <div class="invalid-feedback">{{ partnerFieldError('expected_end_at') }}</div>
                </div>
                <div class="col-12 col-md-4">
                  <label class="form-label">Retry after seconds</label>
                  <input v-model.number="partnerForm.retry_after_seconds" type="number" min="0" max="86400" step="1" class="form-control" :class="partnerInvalidClass('retry_after_seconds')" />
                  <div class="invalid-feedback">{{ partnerFieldError('retry_after_seconds') }}</div>
                </div>
                <div class="col-12 col-md-4">
                  <label class="form-label">Partner status</label>
                  <div class="form-control-plaintext">
                    <AdminStatusBadge :status="partnerMaintenanceModal.row?.partner_status" />
                  </div>
                </div>
                <div class="col-12 col-md-4">
                  <label class="form-label">Tenant status</label>
                  <div class="form-control-plaintext">
                    <AdminStatusBadge :status="partnerMaintenanceModal.row?.tenant_status" />
                  </div>
                </div>
              </div>
            </div>
            <div class="modal-footer">
              <button class="btn btn-light btn-wave" type="button" :disabled="saving" @click="closePartnerMaintenanceModal">Cancel</button>
              <button class="btn btn-warning btn-wave" type="submit" :disabled="partnerSaveDisabled">
                <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                Save partner maintenance
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <div v-if="partnerMaintenanceModal.open" class="modal-backdrop fade show" />

    <div v-if="maintenanceModal.open" class="modal fade show np-central-maintenance-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-xl modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">Manage maintenance</h5>
              <div class="text-muted fs-12">
                {{ maintenanceModal.row?.partner_name || '-' }} / {{ maintenanceModal.row?.tenant_name || '-' }}
              </div>
            </div>
            <button class="btn-close" type="button" aria-label="Close" @click="closeMaintenanceModal" />
          </div>
          <form @submit.prevent="saveMaintenance">
            <div class="modal-body">
              <AdminAlert v-if="modalError" :type="modalError.status === 403 ? 'warning' : 'danger'" :message="modalError.message" :details="modalError.details" />
              <div class="row g-3">
                <div class="col-12 col-md-6">
                  <label class="form-label">Status</label>
                  <select v-model="form.status" class="form-select" :class="invalidClass('status')">
                    <option v-for="status in maintenanceStatuses" :key="status" :value="status">{{ titleize(status) }}</option>
                  </select>
                  <div class="invalid-feedback">{{ fieldError('status') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Mode</label>
                  <select v-model="form.mode" class="form-select" :class="invalidClass('mode')">
                    <option v-for="mode in availableModes" :key="mode" :value="mode">{{ titleize(mode) }}</option>
                  </select>
                  <div class="invalid-feedback">{{ fieldError('mode') || activeModeError }}</div>
                </div>
                <div class="col-12">
                  <label class="form-label">Message</label>
                  <textarea v-model="form.message" class="form-control" rows="3" :class="invalidClass('message')" />
                  <div class="invalid-feedback">{{ fieldError('message') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Change reason</label>
                  <input v-model="form.reason" class="form-control" :class="invalidClass('reason')" placeholder="Required for audit trail" />
                  <div class="invalid-feedback">{{ fieldError('reason') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Ticket ID</label>
                  <input v-model="form.ticket_id" class="form-control" :class="invalidClass('ticket_id')" placeholder="Optional support ticket" />
                  <div class="invalid-feedback">{{ fieldError('ticket_id') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Scheduled start</label>
                  <input v-model="form.scheduled_start_at" type="datetime-local" class="form-control" :class="invalidClass('scheduled_start_at')" />
                  <div class="invalid-feedback">{{ fieldError('scheduled_start_at') }}</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Expected end</label>
                  <input v-model="form.expected_end_at" type="datetime-local" class="form-control" :class="invalidClass('expected_end_at')" />
                  <div class="invalid-feedback">{{ fieldError('expected_end_at') }}</div>
                </div>
                <div class="col-12 col-md-4">
                  <label class="form-label">Retry after seconds</label>
                  <input v-model.number="form.retry_after_seconds" type="number" min="0" max="86400" step="1" class="form-control" :class="invalidClass('retry_after_seconds')" />
                  <div class="invalid-feedback">{{ fieldError('retry_after_seconds') }}</div>
                </div>
                <div class="col-12 col-md-4">
                  <label class="form-label">Partner status</label>
                  <div class="form-control-plaintext">
                    <AdminStatusBadge :status="maintenanceModal.row?.partner_status" />
                  </div>
                </div>
                <div class="col-12 col-md-4">
                  <label class="form-label">Tenant status</label>
                  <div class="form-control-plaintext">
                    <AdminStatusBadge :status="maintenanceModal.row?.tenant_status" />
                  </div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Allowed API routes</label>
                  <textarea v-model="form.allowed_routes" class="form-control" rows="4" :class="invalidClass('allowed_routes')" placeholder="/api/v1/public/site-config" />
                  <div class="invalid-feedback">{{ fieldError('allowed_routes') }}</div>
                  <div class="form-text">One route or wildcard pattern per line.</div>
                </div>
                <div class="col-12 col-md-6">
                  <label class="form-label">Blocked API route patterns</label>
                  <textarea v-model="form.blocked_route_patterns" class="form-control" rows="4" :class="invalidClass('blocked_route_patterns')" placeholder="/api/v1/customer/checkout" />
                  <div class="invalid-feedback">{{ fieldError('blocked_route_patterns') }}</div>
                  <div class="form-text">One route or wildcard pattern per line.</div>
                </div>
              </div>
            </div>
            <div class="modal-footer">
              <button class="btn btn-light btn-wave" type="button" :disabled="saving" @click="closeMaintenanceModal">Cancel</button>
              <button class="btn btn-primary btn-wave" type="submit" :disabled="saveDisabled">
                <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                Save maintenance
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <div v-if="maintenanceModal.open" class="modal-backdrop fade show" />

    <div v-if="unsuspendModal.open" class="modal fade show np-central-maintenance-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Unsuspend partner</h5>
            <button class="btn-close" type="button" aria-label="Close" @click="closeUnsuspendModal" />
          </div>
          <form @submit.prevent="confirmUnsuspend">
            <div class="modal-body">
              <AdminAlert v-if="unsuspendError" :type="unsuspendError.status === 403 ? 'warning' : 'danger'" :message="unsuspendError.message" :details="unsuspendError.details" />
              <p class="mb-3">
                Restore <strong>{{ unsuspendModal.row?.partner_name || '-' }}</strong> and suspended tenant runtime records back to active.
              </p>
              <label class="form-label">Reason</label>
              <textarea v-model="unsuspendReason" class="form-control" rows="3" placeholder="Required for audit trail" />
            </div>
            <div class="modal-footer">
              <button class="btn btn-light btn-wave" type="button" :disabled="saving" @click="closeUnsuspendModal">Cancel</button>
              <button class="btn btn-success btn-wave" type="submit" :disabled="saving || !unsuspendReason.trim()">
                <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                Unsuspend
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <div v-if="unsuspendModal.open" class="modal-backdrop fade show" />
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, titleize } from '~/utils/format'

definePageMeta({ layout: 'admin' })

type SortState = {
  key: string
  direction: 'asc' | 'desc'
}

const api = useAdminApi()
const route = useRoute()
const router = useRouter()
const loading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const modalError = ref<any>(null)
const partnerModalError = ref<any>(null)
const unsuspendError = ref<any>(null)
const validation = ref<Record<string, string[]>>({})
const partnerValidation = ref<Record<string, string[]>>({})
const rows = ref<any[]>([])
const openedFromQuery = ref(false)
const sort = reactive<SortState>({ key: 'partner', direction: 'asc' })
const filters = reactive({
  q: '',
  status: '',
  limit: 100,
})
const partnerMaintenanceModal = reactive<{ open: boolean, row: any }>({ open: false, row: null })
const maintenanceModal = reactive<{ open: boolean, row: any }>({ open: false, row: null })
const unsuspendModal = reactive<{ open: boolean, row: any }>({ open: false, row: null })
const unsuspendReason = ref('')

const maintenanceStatuses = ['inactive', 'scheduled', 'active', 'ended', 'cancelled']
const maintenanceModes = ['full_site', 'customer_web_only', 'admin_only', 'checkout_payment_only', 'read_only', 'scheduled']
const statusOptions = ['active', 'maintenance', 'suspended', 'closed']
const columns = [
  { key: 'partner', label: 'Partner' },
  { key: 'tenant', label: 'Tenant' },
  { key: 'domain', label: 'Domain' },
  { key: 'partner_status', label: 'Partner status', type: 'status' },
  { key: 'tenant_status', label: 'Tenant status', type: 'status' },
  { key: 'partner_maintenance_status', label: 'Partner maintenance', type: 'status' },
  { key: 'maintenance_status', label: 'Tenant maintenance', type: 'status' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]
const partnerForm = reactive<any>({
  status: 'inactive',
  message: '',
  reason: '',
  ticket_id: '',
  scheduled_start_at: '',
  expected_end_at: '',
  retry_after_seconds: null,
})
const form = reactive<any>({
  status: 'inactive',
  mode: 'scheduled',
  message: '',
  reason: '',
  ticket_id: '',
  scheduled_start_at: '',
  expected_end_at: '',
  retry_after_seconds: null,
  allowed_routes: '',
  blocked_route_patterns: '',
})

const activeModeError = computed(() => (
  form.status === 'active' && form.mode === 'scheduled'
    ? 'Active maintenance must use a blocking mode.'
    : ''
))
const availableModes = computed(() => form.status === 'active' ? maintenanceModes.filter((mode) => mode !== 'scheduled') : maintenanceModes)
const saveDisabled = computed(() => Boolean(
  saving.value
  || !maintenanceModal.row?.tenant_id
  || !String(form.reason || '').trim()
  || activeModeError.value,
))
const partnerSaveDisabled = computed(() => Boolean(
  saving.value
  || !partnerMaintenanceModal.row?.partner_id
  || !String(partnerForm.reason || '').trim(),
))
const sortedRows = computed(() => {
  const direction = sort.direction === 'desc' ? -1 : 1

  return [...rows.value].sort((left, right) => compareSortValues(sortValue(left, sort.key), sortValue(right, sort.key)) * direction)
})

const fieldError = (field: string) => validation.value[field]?.[0] || ''
const invalidClass = (field: string) => fieldError(field) || (field === 'mode' && activeModeError.value) ? 'is-invalid' : ''
const partnerFieldError = (field: string) => partnerValidation.value[field]?.[0] || ''
const partnerInvalidClass = (field: string) => partnerFieldError(field) ? 'is-invalid' : ''
const stringList = (value: any) => Array.isArray(value)
  ? value.map((item) => String(item || '').trim()).filter(Boolean)
  : []
const linesToList = (value: string) => String(value || '')
  .split(/\r?\n/g)
  .map((item) => item.trim())
  .filter(Boolean)
const toApiDate = (value: string) => value ? new Date(value).toISOString() : null
const dateTimeLocalValue = (value: any) => value ? String(value).slice(0, 16) : ''

const applySort = (next: SortState) => {
  sort.key = next.key
  sort.direction = next.direction
}

const sortValue = (row: any, key: string) => {
  if (key === 'partner') return `${row.partner_name} ${row.partner_code}`
  if (key === 'tenant') return `${row.tenant_name} ${row.tenant_code}`
  if (key === 'domain') return row.domain_host || ''
  return row[key]
}

const compareSortValues = (left: any, right: any) => {
  const leftDate = Date.parse(String(left || ''))
  const rightDate = Date.parse(String(right || ''))
  if (!Number.isNaN(leftDate) && !Number.isNaN(rightDate)) {
    return leftDate - rightDate
  }

  return String(left ?? '').localeCompare(String(right ?? ''), 'th')
}

const loadRows = async () => {
  loading.value = true
  error.value = null
  try {
    const response: any = await api.apiFetch('/admin/central/maintenance', {
      scope: 'central',
      query: {
        q: filters.q || undefined,
        status: filters.status || undefined,
        limit: filters.limit || 100,
      },
    })
    rows.value = Array.isArray(response?.data) ? response.data : []
    openQueryPartnerIfNeeded()
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const resetFilters = () => {
  filters.q = ''
  filters.status = ''
  filters.limit = 100
  void loadRows()
}

const openQueryPartnerIfNeeded = () => {
  if (openedFromQuery.value) return
  const partnerId = String(route.query.partner_id || '').trim()
  const tenantId = String(route.query.tenant_id || '').trim()
  if (!partnerId && !tenantId) return

  const row = rows.value.find((item) => (
    (partnerId && String(item.partner_id) === partnerId)
    || (tenantId && String(item.tenant_id) === tenantId)
  ))

  if (row) {
    openedFromQuery.value = true
    if (partnerId) {
      void openPartnerMaintenanceModal(row)
    } else {
      void openMaintenanceModal(row)
    }
  }
}

const applyPartnerMaintenanceToForm = (row: any) => {
  const maintenance = row?.partner_maintenance || {}
  partnerForm.status = maintenance.status || 'inactive'
  partnerForm.message = maintenance.message || ''
  partnerForm.reason = ''
  partnerForm.ticket_id = maintenance.ticket_id || ''
  partnerForm.scheduled_start_at = dateTimeLocalValue(maintenance.scheduled_start_at)
  partnerForm.expected_end_at = dateTimeLocalValue(maintenance.expected_end_at)
  partnerForm.retry_after_seconds = maintenance.retry_after_seconds
}

const applyMaintenanceToForm = (row: any) => {
  const maintenance = row?.maintenance || {}
  form.status = maintenance.status || 'inactive'
  form.mode = maintenance.mode || 'scheduled'
  form.message = maintenance.message || ''
  form.reason = ''
  form.ticket_id = maintenance.ticket_id || ''
  form.scheduled_start_at = dateTimeLocalValue(maintenance.scheduled_start_at)
  form.expected_end_at = dateTimeLocalValue(maintenance.expected_end_at)
  form.retry_after_seconds = maintenance.retry_after_seconds
  form.allowed_routes = stringList(maintenance.allowed_routes).join('\n')
  form.blocked_route_patterns = stringList(maintenance.blocked_route_patterns).join('\n')
}

const openPartnerMaintenanceModal = async (row: any) => {
  partnerMaintenanceModal.row = row
  partnerMaintenanceModal.open = true
  partnerModalError.value = null
  partnerValidation.value = {}
  applyPartnerMaintenanceToForm(row)

  try {
    const response = await api.apiFetch(`/admin/central/partner-maintenance/${encodeURIComponent(row.partner_id)}`, { scope: 'central' })
    partnerMaintenanceModal.row = {
      ...row,
      partner_maintenance: response,
      partner_maintenance_status: response?.status || row.partner_maintenance_status,
      partner_maintenance_active: Boolean(response?.active),
      partner_maintenance_mode: response?.mode || row.partner_maintenance_mode,
      partner_maintenance_message: response?.message || row.partner_maintenance_message,
    }
    applyPartnerMaintenanceToForm(partnerMaintenanceModal.row)
  } catch (err) {
    partnerModalError.value = err
  }
}

const openMaintenanceModal = async (row: any) => {
  maintenanceModal.row = row
  maintenanceModal.open = true
  modalError.value = null
  validation.value = {}
  applyMaintenanceToForm(row)

  try {
    const response = await api.apiFetch(`/admin/central/maintenance/${encodeURIComponent(row.tenant_id)}`, { scope: 'central' })
    maintenanceModal.row = {
      ...row,
      maintenance: response,
      maintenance_status: response?.status || row.maintenance_status,
      maintenance_active: Boolean(response?.active),
      maintenance_mode: response?.mode || row.maintenance_mode,
      maintenance_message: response?.message || row.maintenance_message,
    }
    applyMaintenanceToForm(maintenanceModal.row)
  } catch (err) {
    modalError.value = err
  }
}

const closePartnerMaintenanceModal = () => {
  partnerMaintenanceModal.open = false
  partnerMaintenanceModal.row = null
  partnerModalError.value = null
  partnerValidation.value = {}
  if (route.query.partner_id || route.query.tenant_id) {
    void router.replace({ path: route.path, query: {} })
  }
}

const closeMaintenanceModal = () => {
  maintenanceModal.open = false
  maintenanceModal.row = null
  modalError.value = null
  validation.value = {}
  if (route.query.partner_id || route.query.tenant_id) {
    void router.replace({ path: route.path, query: {} })
  }
}

const savePartnerMaintenance = async () => {
  const partnerId = partnerMaintenanceModal.row?.partner_id
  if (!partnerId) return

  saving.value = true
  partnerModalError.value = null
  partnerValidation.value = {}
  try {
    const response = await api.apiFetch(`/admin/central/partner-maintenance/${encodeURIComponent(partnerId)}`, {
      method: 'PUT',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        status: partnerForm.status,
        message: partnerForm.message,
        reason: partnerForm.reason,
        ticket_id: partnerForm.ticket_id,
        scheduled_start_at: toApiDate(partnerForm.scheduled_start_at),
        expected_end_at: toApiDate(partnerForm.expected_end_at),
        retry_after_seconds: partnerForm.retry_after_seconds,
      },
    })
    partnerMaintenanceModal.row = {
      ...partnerMaintenanceModal.row,
      partner_maintenance: response,
      partner_maintenance_status: response?.status || 'inactive',
      partner_maintenance_active: Boolean(response?.active),
      partner_maintenance_mode: response?.mode || null,
      partner_maintenance_message: response?.message || null,
      updated_at: formatDateTime(new Date().toISOString()),
    }
    await loadRows()
    closePartnerMaintenanceModal()
  } catch (err: any) {
    partnerModalError.value = err
    partnerValidation.value = err?.details?.fields || {}
  } finally {
    saving.value = false
  }
}

const saveMaintenance = async () => {
  const tenantId = maintenanceModal.row?.tenant_id
  if (!tenantId) return

  saving.value = true
  modalError.value = null
  validation.value = {}
  try {
    const response = await api.apiFetch(`/admin/central/maintenance/${encodeURIComponent(tenantId)}`, {
      method: 'PUT',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        status: form.status,
        mode: form.mode,
        message: form.message,
        reason: form.reason,
        ticket_id: form.ticket_id,
        scheduled_start_at: toApiDate(form.scheduled_start_at),
        expected_end_at: toApiDate(form.expected_end_at),
        retry_after_seconds: form.retry_after_seconds,
        allowed_routes: linesToList(form.allowed_routes),
        blocked_route_patterns: linesToList(form.blocked_route_patterns),
      },
    })
    maintenanceModal.row = {
      ...maintenanceModal.row,
      tenant_status: response?.active ? 'maintenance' : 'active',
      maintenance: response,
      maintenance_status: response?.status || 'inactive',
      maintenance_active: Boolean(response?.active),
      maintenance_mode: response?.mode || null,
      maintenance_message: response?.message || null,
      updated_at: formatDateTime(new Date().toISOString()),
    }
    await loadRows()
    closeMaintenanceModal()
  } catch (err: any) {
    modalError.value = err
    validation.value = err?.details?.fields || {}
  } finally {
    saving.value = false
  }
}

const openUnsuspendModal = (row: any) => {
  unsuspendModal.row = row
  unsuspendModal.open = true
  unsuspendReason.value = ''
  unsuspendError.value = null
}

const closeUnsuspendModal = () => {
  unsuspendModal.open = false
  unsuspendModal.row = null
  unsuspendReason.value = ''
  unsuspendError.value = null
}

const confirmUnsuspend = async () => {
  const partnerId = unsuspendModal.row?.partner_id
  if (!partnerId || !unsuspendReason.value.trim()) return

  saving.value = true
  unsuspendError.value = null
  try {
    await api.apiFetch(`/admin/central/partners/${encodeURIComponent(partnerId)}/unsuspend`, {
      method: 'POST',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: { reason: unsuspendReason.value },
    })
    closeUnsuspendModal()
    await loadRows()
  } catch (err) {
    unsuspendError.value = err
  } finally {
    saving.value = false
  }
}

watch(() => form.status, (status) => {
  if (status === 'active' && form.mode === 'scheduled') {
    form.mode = 'full_site'
  }
})

onMounted(loadRows)
</script>

<style scoped>
.np-central-maintenance-modal {
  display: block;
}

.np-admin-code {
  white-space: normal;
}
</style>

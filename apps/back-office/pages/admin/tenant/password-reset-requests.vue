<template>
  <div>
    <AdminPageHeader title="Password Reset Requests" :breadcrumbs="['Admin', 'Tenant', 'Password Reset Requests']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading || !tenantId" @click="loadRequests()">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before reviewing customer password reset requests." />
    <AdminAlert v-if="error" type="danger" :message="error.message || 'Unable to load password reset requests.'" :details="error.details" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="card custom-card">
      <div class="card-header np-password-card-header">
        <div class="np-password-card-title">
          <div class="card-title mb-1">Customer Password Reset Queue</div>
          <div class="text-muted fs-12">Customers submit requests here. Issue a one-time link and send it back to the customer.</div>
        </div>
        <div class="np-password-filter-bar">
          <input
            v-model.trim="filters.q"
            class="form-control form-control-sm np-password-filter"
            placeholder="Search phone, customer, or request"
            @keyup.enter="loadRequests()"
          >
          <select v-model="filters.status" class="form-select form-select-sm np-password-filter" @change="loadRequests()">
            <option value="">All statuses</option>
            <option value="submitted">Submitted</option>
            <option value="link_issued">Link issued</option>
            <option value="consumed">Consumed</option>
          </select>
        </div>
      </div>
      <div class="card-body">
        <AdminDataTable
          :columns="columns"
          :rows="sortedRows"
          :loading="loading"
          empty-title="No password reset requests"
          empty-message="Customer forgot-password requests will appear here."
          sortable
          embedded
          :sort-key="sort.key"
          :sort-direction="sort.direction"
          @sort-change="handleSort"
        >
          <template #cell-customer="{ row }">
            <div class="fw-semibold">{{ customerName(row) }}</div>
            <div class="text-muted fs-12">{{ customerSubtext(row) }}</div>
          </template>
          <template #cell-requested_identifier="{ row }">
            <div class="fw-semibold">{{ row.requested_identifier || row.phone || row.email || '-' }}</div>
            <div class="text-muted fs-12">{{ channelLabel(row.channel) }}</div>
          </template>
          <template #cell-status="{ row }">
            <span class="badge" :class="statusClass(row.status)">{{ statusLabel(row.status) }}</span>
          </template>
          <template #cell-created_at="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
          <template #cell-expires_at="{ row }">
            <div>{{ row.expires_at ? formatDateTime(row.expires_at) : '-' }}</div>
            <div v-if="row.link_issued_at" class="text-muted fs-12">Issued {{ formatDateTime(row.link_issued_at) }}</div>
          </template>
          <template #cell-issued_by="{ row }">
            {{ row.issued_by?.name || row.issued_by?.email || '-' }}
          </template>
          <template #rowActions="{ row }">
            <div class="d-flex justify-content-end gap-2">
              <button
                class="btn btn-sm btn-primary-light btn-wave"
                type="button"
                :disabled="issuingId === row.id || !canIssue(row)"
                @click="issueLink(row)"
              >
                <span v-if="issuingId === row.id" class="spinner-border spinner-border-sm me-1" />
                Issue link
              </button>
            </div>
          </template>
        </AdminDataTable>
        <div v-if="meta.has_more" class="text-muted fs-12 mt-3">
          Showing the latest {{ meta.limit }} requests. Use filters to narrow the queue.
        </div>
      </div>
    </div>

    <div v-if="linkModalOpen" class="modal fade show np-reset-link-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">Reset link issued</h5>
              <div class="text-muted fs-12">{{ issuedLink?.customer?.name || issuedLink?.customer?.phone || '-' }}</div>
            </div>
            <button class="btn-close" type="button" aria-label="Close" @click="closeLinkModal" />
          </div>
          <div class="modal-body">
            <div class="alert alert-info d-flex gap-2">
              <i class="ri-information-line fs-18" />
              <div>
                This link is valid until <strong>{{ formatDateTime(issuedLink?.expires_at) }}</strong>. Send it to the customer through your trusted support channel.
              </div>
            </div>

            <label class="form-label">Reset password link</label>
            <div class="input-group">
              <input class="form-control" :value="issuedLink?.reset_url || issuedLink?.reset_path || ''" readonly>
              <button class="btn btn-primary btn-wave" type="button" @click="copyIssuedLink">
                <i class="ri-file-copy-line me-1" />
                Copy
              </button>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-light btn-wave" type="button" @click="closeLinkModal">Close</button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="linkModalOpen" class="modal-backdrop fade show" />
  </div>
</template>

<script setup lang="ts">
definePageMeta({
  layout: 'admin',
})

type ResetRequestRow = Record<string, any>

const api = useAdminApi()
const session = useAdminSession()
const tenantId = computed(() => session.currentTenantId.value)
const loading = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const rows = ref<ResetRequestRow[]>([])
const meta = ref({ limit: 25, has_more: false })
const issuingId = ref('')
const linkModalOpen = ref(false)
const issuedLink = ref<Record<string, any> | null>(null)
const filters = reactive({
  q: '',
  status: '',
})
const sort = reactive({
  key: 'created_at',
  direction: 'desc' as 'asc' | 'desc',
})

const columns = [
  { key: 'customer', label: 'Customer' },
  { key: 'requested_identifier', label: 'Request' },
  { key: 'status', label: 'Status' },
  { key: 'created_at', label: 'Submitted' },
  { key: 'expires_at', label: 'Reset link' },
  { key: 'issued_by', label: 'Issued by' },
]

const sortedRows = computed(() => {
  const sorted = [...rows.value]
  const direction = sort.direction === 'asc' ? 1 : -1

  sorted.sort((a, b) => compareValue(sortValue(a, sort.key), sortValue(b, sort.key)) * direction)
  return sorted
})

onMounted(() => {
  session.restore()
  void loadRequests()
})

const loadRequests = async () => {
  if (!tenantId.value) return

  loading.value = true
  error.value = null

  try {
    const response: any = await api.apiFetch('/admin/tenant/password-reset-requests', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: {
        status: filters.status || undefined,
        q: filters.q || undefined,
        limit: 50,
      },
    })
    rows.value = Array.isArray(response?.data) ? response.data : []
    meta.value = {
      limit: Number(response?.meta?.limit || 50),
      has_more: Boolean(response?.meta?.has_more),
    }
  } catch (err: any) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const issueLink = async (row: ResetRequestRow) => {
  if (!tenantId.value || !canIssue(row)) return

  issuingId.value = row.id
  error.value = null
  successMessage.value = ''

  try {
    const response: any = await api.apiFetch(`/admin/tenant/password-reset-requests/${encodeURIComponent(row.id)}/issue-link`, {
      method: 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      successMessage: false,
    })
    issuedLink.value = response
    linkModalOpen.value = true
    successMessage.value = 'Reset link issued. Copy it and send it to the customer.'
    await loadRequests()
  } catch (err: any) {
    error.value = err
  } finally {
    issuingId.value = ''
  }
}

const canIssue = (row: ResetRequestRow) => {
  const status = String(row?.status || '')
  return Boolean(row?.customer?.id || row?.customer_id) && ['submitted', 'link_issued'].includes(status)
}

const closeLinkModal = () => {
  linkModalOpen.value = false
  issuedLink.value = null
}

const copyIssuedLink = async () => {
  const value = String(issuedLink.value?.reset_url || issuedLink.value?.reset_path || '')
  if (!value) return

  if (import.meta.client && navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(value)
    successMessage.value = 'Reset link copied.'
  }
}

const handleSort = (value: { key: string, direction: 'asc' | 'desc' }) => {
  sort.key = value.key
  sort.direction = value.direction
}

const sortValue = (row: ResetRequestRow, key: string) => {
  if (key === 'customer') return customerName(row)
  if (key === 'issued_by') return row.issued_by?.name || row.issued_by?.email || ''
  return row?.[key] ?? ''
}

const compareValue = (left: unknown, right: unknown) => {
  const leftValue = normalizeSortValue(left)
  const rightValue = normalizeSortValue(right)
  if (leftValue < rightValue) return -1
  if (leftValue > rightValue) return 1
  return 0
}

const normalizeSortValue = (value: unknown) => {
  if (typeof value === 'string') {
    const timestamp = Date.parse(value)
    return Number.isNaN(timestamp) ? value.toLowerCase() : timestamp
  }

  if (typeof value === 'number') return value
  return String(value || '').toLowerCase()
}

const customerName = (row: ResetRequestRow) => {
  const customer = row.customer || {}
  return customer.name || customer.customer_no || row.customer_id || 'Unmatched customer'
}

const customerSubtext = (row: ResetRequestRow) => {
  const customer = row.customer || {}
  return [customer.phone || row.phone, customer.email || row.email].filter(Boolean).join(' / ') || '-'
}

const channelLabel = (channel: unknown) => {
  const value = String(channel || '')
  if (value === 'line_login') return 'LINE verified reset'
  if (value === 'admin_request') return 'Customer request'
  return titleize(value)
}

const statusLabel = (status: unknown) => titleize(String(status || 'unknown'))

const statusClass = (status: unknown) => {
  const value = String(status || '')
  if (value === 'submitted') return 'bg-warning-transparent text-warning'
  if (value === 'link_issued') return 'bg-info-transparent text-info'
  if (value === 'consumed') return 'bg-success-transparent text-success'
  return 'bg-light text-muted'
}

const titleize = (value: string) => value.replace(/[_-]+/g, ' ').replace(/\b\w/g, (match) => match.toUpperCase())

const formatDateTime = (value: unknown) => {
  if (!value) return '-'
  const date = new Date(String(value))
  if (Number.isNaN(date.getTime())) return String(value)

  return new Intl.DateTimeFormat('en-GB', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Bangkok',
  }).format(date)
}
</script>

<style scoped>
.np-password-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.np-password-card-title {
  min-width: 0;
}

.np-password-filter-bar {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-left: auto;
}

.np-password-filter {
  width: min(220px, 100%);
}

.np-reset-link-modal {
  display: block;
  z-index: 1065;
}

.modal-backdrop {
  z-index: 1060;
}

@media (max-width: 575.98px) {
  .np-password-card-header {
    flex-direction: column;
    align-items: stretch;
  }

  .np-password-filter-bar {
    margin-left: 0;
    justify-content: stretch;
  }

  .np-password-filter {
    width: 100%;
  }
}
</style>

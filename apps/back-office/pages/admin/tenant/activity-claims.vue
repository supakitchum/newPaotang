<template>
  <div>
    <AdminPageHeader title="Activity Claims" :breadcrumbs="['Admin', 'Tenant', 'Activity Claims']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading || !tenantId" @click="loadClaims()">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before reviewing activity claims." />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="row g-3 mb-3">
      <div v-for="metric in metrics" :key="metric.label" class="col-12 col-md-6 col-xl-3">
        <div class="card custom-card np-claim-metric">
          <div class="card-body">
            <div class="d-flex align-items-center justify-content-between gap-3">
              <div>
                <div class="text-muted fs-12">{{ metric.label }}</div>
                <div class="fs-22 fw-bold">{{ metric.value }}</div>
              </div>
              <span class="np-claim-metric-icon">
                <i :class="metric.icon" />
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="card custom-card">
      <div class="card-header align-items-center gap-3">
        <div class="btn-group" role="group" aria-label="Activity claim sections">
          <button
            class="btn btn-sm"
            :class="activeSection === 'pending' ? 'btn-primary' : 'btn-light'"
            type="button"
            @click="setSection('pending')"
          >
            Pending approval
          </button>
          <button
            class="btn btn-sm"
            :class="activeSection === 'history' ? 'btn-primary' : 'btn-light'"
            type="button"
            @click="setSection('history')"
          >
            History
          </button>
        </div>
        <div class="ms-auto d-flex flex-wrap gap-2">
          <input v-model="filters.search" class="form-control form-control-sm np-claim-filter" placeholder="Search customer or reference">
          <input v-model="filters.game_id" class="form-control form-control-sm np-claim-filter" placeholder="Game ID" @keyup.enter="loadClaims()">
          <select v-model="filters.status" class="form-select form-select-sm np-claim-filter" @change="loadClaims()">
            <option value="">All statuses</option>
            <option v-for="status in statusOptions" :key="status" :value="status">{{ titleize(status) }}</option>
          </select>
        </div>
      </div>
      <div class="card-body">
        <AdminDataTable
          :columns="columns"
          :rows="displayRows"
          :loading="loading"
          :empty-title="activeSection === 'pending' ? 'No pending activity claims' : 'No activity claim history'"
          :empty-message="activeSection === 'pending' ? 'Customer activity payout requests waiting for review will appear here.' : 'Reviewed activity payout requests will appear here.'"
          sortable
          embedded
          :sort-key="sort.key"
          :sort-direction="sort.direction"
          @sort-change="handleSort"
        >
          <template #cell-customer="{ row }">
            <div class="fw-semibold">{{ customerName(row) }}</div>
            <div class="text-muted fs-12">{{ row.customer?.phone || row.customer_id || '-' }}</div>
          </template>
          <template #cell-activity="{ row }">
            <div class="fw-semibold">{{ row.activity_name || row.activity_id }}</div>
            <div class="text-muted fs-12">{{ awardLabel(row.award) }}</div>
          </template>
          <template #cell-claim_amount="{ row }">
            <div class="fw-semibold">{{ formatMoney(row.claim_amount) }}</div>
          </template>
          <template #cell-payout_method="{ row }">
            <div class="fw-semibold">{{ payoutMethodLabel(row.payout_method) }}</div>
            <div v-if="row.payout_method === 'bank_transfer'" class="text-muted fs-12">
              {{ bankAccountSummary(row.bank_account) }}
            </div>
          </template>
          <template #cell-status="{ row }">
            <span class="badge" :class="statusClass(row.status)">{{ titleize(row.status) }}</span>
          </template>
          <template #cell-submitted_at="{ row }">
            {{ formatDateTime(row.submitted_at || row.created_at) }}
          </template>
          <template #cell-updated_at="{ row }">
            {{ formatDateTime(row.updated_at || row.reviewed_at || row.paid_at || row.created_at) }}
          </template>
          <template #rowActions="{ row }">
            <div class="d-flex justify-content-end gap-2">
              <button class="btn btn-sm btn-light btn-wave" type="button" @click="openReviewModal(row)">
                View
              </button>
              <button v-if="canReview(row)" class="btn btn-sm btn-success-light btn-wave" type="button" :disabled="saving" @click="openReviewModal(row, 'approve')">
                Approve
              </button>
              <button v-if="canReview(row)" class="btn btn-sm btn-danger-light btn-wave" type="button" :disabled="saving" @click="openReviewModal(row, 'reject')">
                Reject
              </button>
            </div>
          </template>
        </AdminDataTable>
        <AdminPagination
          class="mt-3"
          :next-cursor="meta.next_cursor"
          :has-previous="pageState.index > 0"
          :loading="loading"
          :current-page="pageState.index + 1"
          page-size="100"
          @previous="loadPreviousPage"
          @next="loadNextPage"
        />
      </div>
    </div>

    <div v-if="reviewModalOpen" class="modal fade show np-claim-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">Review activity claim</h5>
              <div class="text-muted fs-12">{{ selectedClaim?.reference || '-' }}</div>
            </div>
            <button class="btn-close" type="button" aria-label="Close" :disabled="saving" @click="closeReviewModal" />
          </div>
          <div class="modal-body">
            <div v-if="selectedClaim" class="np-claim-detail">
              <div class="np-claim-detail-row">
                <span>Customer</span>
                <strong>{{ customerName(selectedClaim) }}</strong>
              </div>
              <div class="np-claim-detail-row">
                <span>Activity</span>
                <strong>{{ selectedClaim.activity_name || selectedClaim.activity_id }}</strong>
              </div>
              <div class="np-claim-detail-row">
                <span>Award source</span>
                <strong>{{ awardLabel(selectedClaim.award) }}</strong>
              </div>
              <div class="np-claim-detail-row">
                <span>Claim amount</span>
                <strong>{{ formatMoney(selectedClaim.claim_amount) }}</strong>
              </div>
              <div class="np-claim-detail-row">
                <span>Payout method</span>
                <strong>{{ payoutMethodLabel(selectedClaim.payout_method) }}</strong>
              </div>
              <div v-if="selectedClaim.payout_method === 'bank_transfer'" class="np-claim-detail-row align-items-start">
                <span>Bank account</span>
                <strong class="text-end">{{ bankAccountLines(selectedClaim.bank_account).join(' / ') }}</strong>
              </div>
              <div class="np-claim-detail-row">
                <span>Status</span>
                <strong>{{ titleize(selectedClaim.status) }}</strong>
              </div>
              <div class="np-claim-detail-row">
                <span>Submitted</span>
                <strong>{{ formatDateTime(selectedClaim.submitted_at || selectedClaim.created_at) }}</strong>
              </div>
            </div>
            <div v-if="canReview(selectedClaim)" class="mt-3">
              <label class="form-label">Reason / note</label>
              <textarea v-model="reviewReason" class="form-control" rows="3" placeholder="Optional for approve, recommended for reject." />
            </div>
          </div>
          <div class="modal-footer justify-content-between">
            <button class="btn btn-light btn-wave" type="button" :disabled="saving" @click="closeReviewModal">Close</button>
            <div v-if="canReview(selectedClaim)" class="d-flex gap-2">
              <button class="btn btn-danger-light btn-wave" type="button" :disabled="saving" @click="submitReview('reject')">
                <span v-if="saving && pendingAction === 'reject'" class="spinner-border spinner-border-sm me-2" />
                Reject
              </button>
              <button class="btn btn-success btn-wave" type="button" :disabled="saving" @click="submitReview('approve')">
                <span v-if="saving && pendingAction === 'approve'" class="spinner-border spinner-border-sm me-2" />
                Approve
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div v-if="reviewModalOpen" class="modal-backdrop fade show np-claim-modal-backdrop" />
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, formatMoney, titleize } from '~/utils/format'

definePageMeta({
  layout: 'admin',
})

type AnyRecord = Record<string, any>
type Section = 'pending' | 'history'
type ReviewAction = 'approve' | 'reject'

const api = useAdminApi()
const session = useAdminSession()
const tenantId = computed(() => session.currentTenantId.value)

const columns = computed(() => activeSection.value === 'pending'
  ? [
      { key: 'reference', label: 'Reference' },
      { key: 'customer', label: 'Customer' },
      { key: 'activity', label: 'Activity' },
      { key: 'claim_amount', label: 'Amount' },
      { key: 'payout_method', label: 'Payout method' },
      { key: 'status', label: 'Status' },
      { key: 'submitted_at', label: 'Submitted' },
    ]
  : [
      { key: 'reference', label: 'Reference' },
      { key: 'customer', label: 'Customer' },
      { key: 'activity', label: 'Activity' },
      { key: 'claim_amount', label: 'Amount' },
      { key: 'payout_method', label: 'Payout method' },
      { key: 'status', label: 'Status' },
      { key: 'updated_at', label: 'Last action' },
    ])

const statusOptions = computed(() => activeSection.value === 'pending'
  ? ['submitted', 'under_review']
  : ['paid', 'approved', 'rejected', 'cancelled'])

const loading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const claims = ref<AnyRecord[]>([])
const meta = ref<AnyRecord>({})
const pageState = ref({ index: 0, cursors: [''] })
const activeSection = ref<Section>('pending')
const sort = reactive({ key: 'submitted_at', direction: 'asc' as 'asc' | 'desc' })
const filters = reactive({ search: '', status: '', game_id: '' })
const reviewModalOpen = ref(false)
const selectedClaim = ref<AnyRecord | null>(null)
const reviewReason = ref('')
const pendingAction = ref<ReviewAction | ''>('')

const displayRows = computed(() => {
  const query = filters.search.trim().toLowerCase()
  const filtered = !query
    ? claims.value
    : claims.value.filter((row) => [
        row.reference,
        row.customer_id,
        row.customer?.name,
        row.customer?.phone,
        row.activity_name,
        row.activity_id,
      ].some((value) => String(value || '').toLowerCase().includes(query)))

  return [...filtered].sort((a, b) => compareRows(a, b, sort.key, sort.direction))
})

const metrics = computed(() => {
  const pendingRows = activeSection.value === 'pending' ? claims.value : []
  const totalAmount = claims.value.reduce((sum, row) => sum + moneyAmount(row.claim_amount), 0)
  const walletRows = claims.value.filter((row) => row.payout_method === 'wallet_credit').length
  const bankRows = claims.value.filter((row) => row.payout_method === 'bank_transfer').length

  return [
    { label: activeSection.value === 'pending' ? 'Pending claims' : 'History rows', value: claims.value.length.toLocaleString('th-TH'), icon: 'ri-inbox-archive-line' },
    { label: 'Total amount', value: formatMoney({ amount: totalAmount, currency: 'THB' }), icon: 'ri-money-dollar-circle-line' },
    { label: 'Wallet requests', value: walletRows.toLocaleString('th-TH'), icon: 'ri-wallet-3-line' },
    { label: 'Bank transfers', value: bankRows.toLocaleString('th-TH'), icon: 'ri-bank-card-line' },
  ].map((metric, index) => index === 0 && activeSection.value === 'pending'
    ? { ...metric, value: pendingRows.length.toLocaleString('th-TH') }
    : metric)
})

const loadClaims = async (cursor = '') => {
  if (!tenantId.value) return
  loading.value = true
  error.value = null

  try {
    const response: any = await api.apiFetch('/admin/tenant/activity-claims', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: {
        limit: 100,
        cursor: cursor || undefined,
        section: activeSection.value,
        status: filters.status || undefined,
        game_id: filters.game_id.trim() || undefined,
        sort: sort.key,
        direction: sort.direction,
      },
    })
    claims.value = Array.isArray(response.data) ? response.data : []
    meta.value = response.meta || {}
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const setSection = (section: Section) => {
  if (activeSection.value === section) return
  activeSection.value = section
  filters.status = ''
  sort.key = section === 'pending' ? 'submitted_at' : 'updated_at'
  sort.direction = section === 'pending' ? 'asc' : 'desc'
  pageState.value = { index: 0, cursors: [''] }
  void loadClaims()
}

const loadNextPage = () => {
  const cursor = String(meta.value.next_cursor || '')
  if (!cursor) return
  pageState.value.cursors[pageState.value.index + 1] = cursor
  pageState.value.index += 1
  void loadClaims(cursor)
}

const loadPreviousPage = () => {
  if (pageState.value.index <= 0) return
  pageState.value.index -= 1
  void loadClaims(pageState.value.cursors[pageState.value.index] || '')
}

const handleSort = (next: { key: string, direction: 'asc' | 'desc' }) => {
  sort.key = next.key
  sort.direction = next.direction
}

const openReviewModal = (row: AnyRecord, action: ReviewAction | '' = '') => {
  selectedClaim.value = row
  reviewReason.value = ''
  pendingAction.value = action
  reviewModalOpen.value = true
}

const closeReviewModal = () => {
  if (saving.value) return
  reviewModalOpen.value = false
  selectedClaim.value = null
  reviewReason.value = ''
  pendingAction.value = ''
}

const submitReview = async (action: ReviewAction) => {
  if (!tenantId.value || !selectedClaim.value || saving.value) return
  saving.value = true
  pendingAction.value = action
  error.value = null
  successMessage.value = ''

  try {
    await api.apiFetch(`/admin/tenant/activity-claims/${encodeURIComponent(selectedClaim.value.id)}/${action}`, {
      method: 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      body: {
        reason: reviewReason.value.trim() || undefined,
      },
    })
    successMessage.value = action === 'approve' ? 'Activity claim approved.' : 'Activity claim rejected.'
    reviewModalOpen.value = false
    selectedClaim.value = null
    reviewReason.value = ''
    await loadClaims(pageState.value.cursors[pageState.value.index] || '')
  } catch (err) {
    error.value = err
  } finally {
    saving.value = false
    pendingAction.value = ''
  }
}

const canReview = (row?: AnyRecord | null) => ['submitted', 'under_review'].includes(String(row?.status || ''))

const customerName = (row: AnyRecord) => row.customer?.name || row.customer?.phone || row.customer_id || '-'
const awardLabel = (award?: AnyRecord | null) => {
  if (!award) return '-'
  if (award.type === 'cashback') return 'Cashback'
  return titleize(award.prediction_type || 'Lucky board')
}
const payoutMethodLabel = (method: string) => method === 'bank_transfer' ? 'Bank transfer' : 'Wallet credit'
const bankAccountLines = (bank?: AnyRecord | null) => {
  if (!bank || typeof bank !== 'object') return ['-']
  return [
    bank.bank_name,
    bank.account_name,
    bank.account_number,
  ].map((value) => String(value || '').trim()).filter(Boolean)
}
const bankAccountSummary = (bank?: AnyRecord | null) => bankAccountLines(bank).join(' / ')
const moneyAmount = (value: any) => Number(value && typeof value === 'object' ? value.amount : value || 0) || 0
const rowDate = (row: AnyRecord, key: string) => {
  const fallback = key === 'updated_at'
    ? row.updated_at || row.reviewed_at || row.paid_at || row.created_at
    : row.submitted_at || row.created_at
  const time = new Date(fallback || '').getTime()
  return Number.isFinite(time) ? time : 0
}
const sortValue = (row: AnyRecord, key: string) => {
  if (key === 'customer') return customerName(row)
  if (key === 'activity') return row.activity_name || row.activity_id || ''
  if (key === 'claim_amount') return moneyAmount(row.claim_amount)
  if (key === 'submitted_at' || key === 'updated_at') return rowDate(row, key)
  return row[key] ?? ''
}
const compareRows = (a: AnyRecord, b: AnyRecord, key: string, direction: 'asc' | 'desc') => {
  const left = sortValue(a, key)
  const right = sortValue(b, key)
  const result = typeof left === 'number' && typeof right === 'number'
    ? left - right
    : String(left).localeCompare(String(right), 'th')
  return direction === 'asc' ? result : -result
}
const statusClass = (status: string) => {
  const key = String(status || '')
  if (key === 'paid' || key === 'approved') return 'bg-success-transparent text-success'
  if (key === 'rejected' || key === 'cancelled') return 'bg-danger-transparent text-danger'
  if (key === 'under_review') return 'bg-warning-transparent text-warning'
  return 'bg-primary-transparent text-primary'
}
const alertType = (err: any) => ([403, 409, 422].includes(Number(err?.status)) ? 'warning' : 'danger')

watch(tenantId, () => {
  reviewModalOpen.value = false
  pageState.value = { index: 0, cursors: [''] }
  void loadClaims()
}, { immediate: true })
</script>

<style scoped>
.np-claim-filter {
  min-width: 180px;
}

.np-claim-metric {
  height: 100%;
}

.np-claim-metric-icon {
  align-items: center;
  background: #eef5ff;
  border-radius: .65rem;
  color: #0d6efd;
  display: inline-flex;
  font-size: 1.35rem;
  height: 42px;
  justify-content: center;
  width: 42px;
}

.np-claim-detail {
  border: 1px solid #edf1f7;
  border-radius: .75rem;
  overflow: hidden;
}

.np-claim-detail-row {
  align-items: center;
  border-bottom: 1px solid #edf1f7;
  display: flex;
  gap: 1rem;
  justify-content: space-between;
  padding: .85rem 1rem;
}

.np-claim-detail-row:last-child {
  border-bottom: 0;
}

.np-claim-detail-row span {
  color: #6b7280;
}

.np-claim-detail-row strong {
  color: #111827;
}

.np-claim-modal {
  display: block;
  z-index: 2000;
}

.np-claim-modal-backdrop {
  z-index: 1990;
}
</style>

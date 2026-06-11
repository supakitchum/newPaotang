<template>
  <div>
    <AdminPageHeader title="Settlements" :breadcrumbs="['Admin', 'Central', 'Finance And Reports', 'Settlements']">
      <template #actions>
        <button class="btn btn-outline-primary btn-wave" type="button" :disabled="loading" @click="loadSettlements('current')">
          <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminApiState :error="error" />

    <div class="card custom-card">
      <div class="card-body">
        <form class="row g-3 align-items-end" @submit.prevent="applyFilters">
          <div class="col-12 col-md-6 col-xl-2">
            <label class="form-label">From</label>
            <input v-model="filters.date_from" class="form-control" type="date">
          </div>
          <div class="col-12 col-md-6 col-xl-2">
            <label class="form-label">To</label>
            <input v-model="filters.date_to" class="form-control" type="date">
          </div>
          <div class="col-12 col-md-6 col-xl-2">
            <label class="form-label">Status</label>
            <select v-model="filters.status" class="form-select">
              <option value="">All statuses</option>
              <option v-for="status in statusOptions" :key="status" :value="status">{{ titleize(status) }}</option>
            </select>
          </div>
          <div class="col-12 col-md-6 col-xl-2">
            <label class="form-label">Partner ID</label>
            <input v-model.trim="filters.partner_id" class="form-control" placeholder="Optional partner">
          </div>
          <div class="col-12 col-md-6 col-xl-2">
            <label class="form-label">Tenant ID</label>
            <input v-model.trim="filters.tenant_id" class="form-control" placeholder="Optional tenant">
          </div>
          <div class="col-12 col-md-6 col-xl-2">
            <label class="form-label">Search loaded rows</label>
            <input v-model.trim="search" class="form-control" placeholder="Name, code, or ID">
          </div>
          <div class="col-12 d-flex flex-wrap gap-2">
            <button class="btn btn-primary btn-wave" type="submit" :disabled="loading">
              <i class="ri-filter-3-line me-1" />
              Apply filters
            </button>
            <button class="btn btn-light btn-wave" type="button" :disabled="loading" @click="resetFilters">
              Reset
            </button>
            <span class="ms-auto text-muted fs-12 align-self-center">
              {{ periodLabel }}
            </span>
          </div>
        </form>
      </div>
    </div>

    <div class="row g-3">
      <div v-for="card in summaryCards" :key="card.key" class="col-12 col-md-6 col-xl-3">
        <div class="card custom-card np-settlement-kpi">
          <div class="card-body">
            <div class="d-flex align-items-start justify-content-between gap-3">
              <div>
                <p class="text-muted mb-1">{{ card.label }}</p>
                <h4 class="mb-1">{{ card.value }}</h4>
                <span class="text-muted fs-12">{{ card.hint }}</span>
              </div>
              <span :class="['avatar', card.className]">
                <i :class="[card.icon, 'fs-4']" />
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="row g-3">
      <div class="col-12 col-xl-8">
        <AdminDataTable
          title="Settlement queue"
          :columns="columns"
          :rows="visibleRows"
          :loading="loading"
          sortable
          :sort-key="sort.key"
          :sort-direction="sort.direction"
          empty-title="No settlements"
          empty-message="Try changing filters. Settlements are generated from paid sales, commissions, and approved affiliate payouts."
          @sort-change="applySort"
        >
          <template #actions>
            <span class="badge bg-light text-default">{{ visibleRows.length }} loaded</span>
          </template>
          <template #cell-partner="{ row }">
            <div class="fw-semibold">{{ row.partner_name || row.partner_code || row.partner_id }}</div>
            <div class="text-muted fs-12">{{ row.partner_code || row.partner_id }}</div>
          </template>
          <template #cell-tenant="{ row }">
            <div class="fw-semibold">{{ row.tenant_name || row.tenant_code || row.tenant_id }}</div>
            <div class="text-muted fs-12">{{ row.tenant_code || row.tenant_id }}</div>
          </template>
          <template #cell-status="{ row }">
            <AdminStatusBadge :status="row.status" />
          </template>
          <template #cell-net_amount="{ row }">
            <div class="fw-semibold">{{ formatMoney(row.net_amount) }}</div>
            <div class="text-muted fs-12">
              {{ formatMoney(row.sales_amount) }} - {{ formatMoney(row.commission_amount) }} - {{ formatMoney(row.payout_amount) }}
            </div>
          </template>
          <template #cell-period="{ row }">
            <div class="fw-semibold">{{ formatDate(row.period_from) }}</div>
            <div class="text-muted fs-12">to {{ formatDate(row.period_to) }}</div>
          </template>
          <template #cell-updated_at="{ row }">
            {{ formatDateTime(row.updated_at) }}
          </template>
          <template #rowActions="{ row }">
            <button class="btn btn-sm btn-primary-light btn-wave me-1" type="button" @click="openDetail(row)">
              Detail
            </button>
            <button
              class="btn btn-sm btn-success btn-wave"
              type="button"
              :disabled="!canApprove(row) || approving"
              :title="canApprove(row) ? 'Approve settlement' : 'Only draft or pending settlements can be approved'"
              @click="openApprove(row)"
            >
              Approve
            </button>
          </template>
        </AdminDataTable>

        <AdminPagination
          class="mt-3"
          :next-cursor="meta.next_cursor"
          :has-previous="page.index > 0"
          :loading="loading"
          :current-page="page.index + 1"
          :page-size="filters.limit"
          @previous="loadPrevious"
          @next="loadNext"
        />
      </div>

      <div class="col-12 col-xl-4">
        <div class="card custom-card">
          <div class="card-header">
            <div class="card-title">Status mix</div>
          </div>
          <div class="card-body">
            <div v-if="!statusRows.length && !loading" class="text-muted">No status data</div>
            <div v-for="row in statusRows" :key="row.status" class="np-settlement-status-row">
              <div class="d-flex align-items-center justify-content-between gap-2 mb-1">
                <AdminStatusBadge :status="row.status" />
                <span class="fw-semibold">{{ row.count }}</span>
              </div>
              <div class="progress np-settlement-progress" role="progressbar" :aria-valuenow="row.percent" aria-valuemin="0" aria-valuemax="100">
                <div class="progress-bar" :class="statusProgressClass(row.status)" :style="{ width: `${row.percent}%` }" />
              </div>
            </div>
          </div>
        </div>

        <div class="card custom-card">
          <div class="card-header">
            <div class="card-title">How net amount is calculated</div>
          </div>
          <div class="card-body">
            <div class="np-settlement-formula">
              <div>
                <span>Sales amount</span>
                <strong>{{ totals.sales }}</strong>
              </div>
              <i class="ri-subtract-line" />
              <div>
                <span>Commission amount</span>
                <strong>{{ totals.commission }}</strong>
              </div>
              <i class="ri-subtract-line" />
              <div>
                <span>Payout amount</span>
                <strong>{{ totals.payout }}</strong>
              </div>
              <i class="ri-equal-line" />
              <div>
                <span>Net amount</span>
                <strong>{{ totals.net }}</strong>
              </div>
            </div>
            <p class="text-muted mb-0 mt-3 fs-12">
              The list refreshes settlement rows from paid orders, commission transactions, and approved affiliate payouts for the selected period.
            </p>
          </div>
        </div>
      </div>
    </div>

    <AdminModal v-model="detailModal.open" title="Settlement detail" size="lg">
      <AdminApiState :error="detailModal.error" />
      <AdminLoader v-if="detailModal.loading" />
      <template v-else-if="detailModal.record">
        <div class="np-settlement-detail-hero">
          <div>
            <div class="text-muted fs-12">Settlement</div>
            <h5 class="mb-1">{{ detailModal.record.id }}</h5>
            <AdminStatusBadge :status="detailModal.record.status" />
          </div>
          <div class="text-end">
            <div class="text-muted fs-12">Net amount</div>
            <h4 class="mb-0">{{ formatMoney(detailModal.record.net_amount) }}</h4>
          </div>
        </div>

        <div class="row g-3 mt-1">
          <div class="col-12 col-md-6">
            <div class="np-settlement-info">
              <span>Partner</span>
              <strong>{{ detailModal.record.partner_name || detailModal.record.partner_code || detailModal.record.partner_id }}</strong>
              <small>{{ detailModal.record.partner_id }}</small>
            </div>
          </div>
          <div class="col-12 col-md-6">
            <div class="np-settlement-info">
              <span>Tenant</span>
              <strong>{{ detailModal.record.tenant_name || detailModal.record.tenant_code || detailModal.record.tenant_id }}</strong>
              <small>{{ detailModal.record.tenant_id }}</small>
            </div>
          </div>
          <div v-for="metric in detailMetrics" :key="metric.key" class="col-12 col-md-6">
            <div class="np-settlement-info">
              <span>{{ metric.label }}</span>
              <strong>{{ metric.value }}</strong>
            </div>
          </div>
        </div>

        <div class="mt-4">
          <h6>Summary counts</h6>
          <div class="row g-2">
            <div v-for="item in summaryCountRows(detailModal.record)" :key="item.key" class="col-12 col-md-4">
              <div class="np-settlement-count">
                <span>{{ item.label }}</span>
                <strong>{{ item.value }}</strong>
              </div>
            </div>
          </div>
        </div>
      </template>
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" @click="detailModal.open = false">Close</button>
        <button
          v-if="detailModal.record"
          class="btn btn-success btn-wave"
          type="button"
          :disabled="!canApprove(detailModal.record) || approving"
          @click="openApprove(detailModal.record)"
        >
          Approve
        </button>
      </template>
    </AdminModal>

    <AdminModal v-model="approveModal.open" title="Approve settlement">
      <AdminApiState :error="approveModal.error" />
      <div v-if="approveModal.row" class="d-grid gap-3">
        <div class="alert alert-info mb-0">
          Approving locks this settlement total for the selected period. It does not mark the settlement as paid.
        </div>
        <div class="np-settlement-approve-box">
          <div>
            <span>Partner / Tenant</span>
            <strong>{{ approveModal.row.partner_name || approveModal.row.partner_id }} / {{ approveModal.row.tenant_name || approveModal.row.tenant_id }}</strong>
          </div>
          <div>
            <span>Net amount</span>
            <strong>{{ formatMoney(approveModal.row.net_amount) }}</strong>
          </div>
          <div>
            <span>Period</span>
            <strong>{{ formatDate(approveModal.row.period_from) }} - {{ formatDate(approveModal.row.period_to) }}</strong>
          </div>
        </div>
        <div>
          <label class="form-label">Reason</label>
          <textarea v-model.trim="approveModal.reason" class="form-control" rows="3" placeholder="Audit reason for approving this settlement" />
        </div>
      </div>
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" :disabled="approving" @click="approveModal.open = false">Cancel</button>
        <button class="btn btn-success btn-wave" type="button" :disabled="approving || !approveModal.reason" @click="approveSettlement">
          <span v-if="approving" class="spinner-border spinner-border-sm me-2" />
          Approve settlement
        </button>
      </template>
    </AdminModal>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, formatMoney, titleize } from '~/utils/format'

type SettlementRow = {
  id: string
  partner_id: string
  partner_name?: string
  partner_code?: string
  tenant_id: string
  tenant_name?: string
  tenant_code?: string
  status: string
  sales_amount: { amount: number, currency?: string }
  commission_amount: { amount: number, currency?: string }
  payout_amount: { amount: number, currency?: string }
  net_amount: { amount: number, currency?: string }
  period_from?: string
  period_to?: string
  approved_by_admin_id?: string
  approved_by_admin_name?: string
  approved_at?: string
  summary?: Record<string, unknown>
  created_at?: string
  updated_at?: string
}

definePageMeta({
  layout: 'admin',
})

const api = useAdminApi()

const statusOptions = ['draft', 'pending', 'approved', 'paid', 'failed']
const columns = [
  { key: 'partner', label: 'Partner' },
  { key: 'tenant', label: 'Tenant' },
  { key: 'status', label: 'Status' },
  { key: 'net_amount', label: 'Net amount' },
  { key: 'period', label: 'Period' },
  { key: 'updated_at', label: 'Updated' },
]

const today = new Date()
const firstDay = new Date(today.getFullYear(), today.getMonth(), 1)

const filters = reactive({
  date_from: toDateInput(firstDay),
  date_to: toDateInput(today),
  status: '',
  partner_id: '',
  tenant_id: '',
  limit: 50,
})
const search = ref('')
const rows = ref<SettlementRow[]>([])
const loading = ref(false)
const approving = ref(false)
const error = ref<any>(null)
const sort = reactive({ key: 'updated_at', direction: 'desc' as 'asc' | 'desc' })
const meta = reactive({ next_cursor: null as string | null, has_more: false })
const page = reactive({ cursors: [null] as Array<string | null>, index: 0 })
const detailModal = reactive({
  open: false,
  loading: false,
  error: null as any,
  record: null as SettlementRow | null,
})
const approveModal = reactive({
  open: false,
  row: null as SettlementRow | null,
  reason: '',
  error: null as any,
})

const visibleRows = computed(() => {
  const q = search.value.toLowerCase()
  const filtered = q
    ? rows.value.filter((row) => [
        row.id,
        row.partner_id,
        row.partner_name,
        row.partner_code,
        row.tenant_id,
        row.tenant_name,
        row.tenant_code,
        row.status,
      ].some((value) => String(value || '').toLowerCase().includes(q)))
    : rows.value

  return [...filtered].sort((a, b) => compareRows(a, b, sort.key, sort.direction))
})

const summary = computed(() => visibleRows.value.reduce((acc, row) => {
  acc.sales += moneyAmount(row.sales_amount)
  acc.commission += moneyAmount(row.commission_amount)
  acc.payout += moneyAmount(row.payout_amount)
  acc.net += moneyAmount(row.net_amount)
  acc.count += 1
  if (['draft', 'pending'].includes(row.status)) acc.pending += 1
  if (row.status === 'approved') acc.approved += 1
  return acc
}, {
  sales: 0,
  commission: 0,
  payout: 0,
  net: 0,
  count: 0,
  pending: 0,
  approved: 0,
}))

const totals = computed(() => ({
  sales: formatMajorMoney(summary.value.sales),
  commission: formatMajorMoney(summary.value.commission),
  payout: formatMajorMoney(summary.value.payout),
  net: formatMajorMoney(summary.value.net),
}))

const summaryCards = computed(() => [
  {
    key: 'net',
    label: 'Net amount',
    value: totals.value.net,
    hint: `${summary.value.count} loaded settlements`,
    icon: 'ri-bank-card-line',
    className: 'bg-primary-transparent text-primary',
  },
  {
    key: 'sales',
    label: 'Sales amount',
    value: totals.value.sales,
    hint: 'Paid order sales',
    icon: 'ri-shopping-bag-3-line',
    className: 'bg-success-transparent text-success',
  },
  {
    key: 'commission',
    label: 'Commission amount',
    value: totals.value.commission,
    hint: 'Affiliate commission total',
    icon: 'ri-percent-line',
    className: 'bg-warning-transparent text-warning',
  },
  {
    key: 'pending',
    label: 'Waiting approval',
    value: String(summary.value.pending),
    hint: `${summary.value.approved} approved on this page`,
    icon: 'ri-time-line',
    className: 'bg-info-transparent text-info',
  },
])

const statusRows = computed(() => {
  const counts = new Map<string, number>()
  visibleRows.value.forEach((row) => counts.set(row.status || 'unknown', (counts.get(row.status || 'unknown') || 0) + 1))
  const total = Math.max(1, visibleRows.value.length)
  return Array.from(counts.entries())
    .map(([status, count]) => ({ status, count, percent: Math.round((count / total) * 100) }))
    .sort((a, b) => b.count - a.count)
})

const periodLabel = computed(() => `Period ${formatDate(filters.date_from) || '-'} - ${formatDate(filters.date_to) || '-'}`)

const detailMetrics = computed(() => {
  const row = detailModal.record
  if (!row) return []
  return [
    { key: 'sales', label: 'Sales amount', value: formatMoney(row.sales_amount) },
    { key: 'commission', label: 'Commission amount', value: formatMoney(row.commission_amount) },
    { key: 'payout', label: 'Payout amount', value: formatMoney(row.payout_amount) },
    { key: 'period', label: 'Period', value: `${formatDate(row.period_from)} - ${formatDate(row.period_to)}` },
    { key: 'approved_by', label: 'Approved by', value: row.approved_by_admin_name || row.approved_by_admin_id || '-' },
    { key: 'approved_at', label: 'Approved at', value: row.approved_at ? formatDateTime(row.approved_at) : '-' },
  ]
})

onMounted(() => {
  void loadSettlements('reset')
})

function toDateInput(date: Date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function cleanQuery(cursor?: string | null) {
  const query: Record<string, any> = {
    limit: filters.limit,
    date_from: filters.date_from,
    date_to: filters.date_to,
  }
  if (cursor) query.cursor = cursor
  if (filters.status) query.status = filters.status
  if (filters.partner_id) query.partner_id = filters.partner_id
  if (filters.tenant_id) query.tenant_id = filters.tenant_id
  return query
}

async function loadSettlements(mode: 'reset' | 'next' | 'previous' | 'current' = 'reset', cursor: string | null = null) {
  loading.value = true
  error.value = null
  try {
    const response: any = await api.apiFetch('/admin/central/settlements', {
      scope: 'central',
      query: cleanQuery(cursor),
      successMessage: false,
    })
    rows.value = Array.isArray(response?.data) ? response.data : []
    meta.next_cursor = response?.meta?.next_cursor || null
    meta.has_more = Boolean(response?.meta?.has_more || meta.next_cursor)
    updatePage(mode, cursor)
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

function updatePage(mode: 'reset' | 'next' | 'previous' | 'current', cursor: string | null) {
  if (mode === 'reset') {
    page.cursors = [null]
    page.index = 0
    return
  }
  if (mode === 'next') {
    page.cursors = [...page.cursors.slice(0, page.index + 1), cursor]
    page.index += 1
    return
  }
  if (mode === 'previous') {
    page.index = Math.max(0, page.index - 1)
  }
}

function applyFilters() {
  void loadSettlements('reset')
}

function resetFilters() {
  filters.date_from = toDateInput(firstDay)
  filters.date_to = toDateInput(today)
  filters.status = ''
  filters.partner_id = ''
  filters.tenant_id = ''
  search.value = ''
  void loadSettlements('reset')
}

function loadNext() {
  if (!meta.next_cursor || loading.value) return
  void loadSettlements('next', meta.next_cursor)
}

function loadPrevious() {
  if (page.index <= 0 || loading.value) return
  const previousCursor = page.cursors[Math.max(0, page.index - 1)] || null
  void loadSettlements('previous', previousCursor)
}

function applySort(next: { key: string, direction: 'asc' | 'desc' }) {
  sort.key = next.key
  sort.direction = next.direction
}

function compareRows(a: SettlementRow, b: SettlementRow, key: string, direction: 'asc' | 'desc') {
  const left = sortableValue(a, key)
  const right = sortableValue(b, key)
  const modifier = direction === 'asc' ? 1 : -1
  if (left < right) return -1 * modifier
  if (left > right) return 1 * modifier
  return 0
}

function sortableValue(row: SettlementRow, key: string): string | number {
  if (key === 'partner') return `${row.partner_name || ''} ${row.partner_code || ''} ${row.partner_id || ''}`.toLowerCase()
  if (key === 'tenant') return `${row.tenant_name || ''} ${row.tenant_code || ''} ${row.tenant_id || ''}`.toLowerCase()
  if (key === 'net_amount') return moneyAmount(row.net_amount)
  if (key === 'period') return `${row.period_from || ''}:${row.period_to || ''}`
  return String((row as any)[key] || '').toLowerCase()
}

async function openDetail(row: SettlementRow) {
  detailModal.open = true
  detailModal.loading = true
  detailModal.error = null
  detailModal.record = row
  try {
    const response = await api.apiFetch<SettlementRow>(`/admin/central/settlements/${row.id}`, {
      scope: 'central',
      successMessage: false,
    })
    detailModal.record = response
  } catch (err) {
    detailModal.error = err
  } finally {
    detailModal.loading = false
  }
}

function openApprove(row: SettlementRow) {
  approveModal.open = true
  approveModal.row = row
  approveModal.reason = ''
  approveModal.error = null
}

async function approveSettlement() {
  if (!approveModal.row || !approveModal.reason) return
  approving.value = true
  approveModal.error = null
  try {
    const response = await api.apiFetch<SettlementRow>(`/admin/central/settlements/${approveModal.row.id}/approve`, {
      method: 'POST',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: { reason: approveModal.reason },
      successMessage: 'Settlement approved',
    })
    replaceRow(response)
    if (detailModal.record?.id === response.id) {
      detailModal.record = response
    }
    approveModal.open = false
  } catch (err) {
    approveModal.error = err
  } finally {
    approving.value = false
  }
}

function replaceRow(row: SettlementRow) {
  rows.value = rows.value.map((item) => item.id === row.id ? row : item)
}

function canApprove(row: SettlementRow) {
  return ['draft', 'pending'].includes(String(row.status || '').toLowerCase())
}

function moneyAmount(value: any) {
  const amount = Number(value?.amount ?? value ?? 0)
  return Number.isFinite(amount) ? amount : 0
}

function formatMajorMoney(minorAmount: number) {
  return formatMoney({ amount: minorAmount, currency: 'THB' })
}

function formatDate(value?: string | null) {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'medium',
    timeZone: 'Asia/Bangkok',
  }).format(date)
}

function statusProgressClass(status: string) {
  const normalized = String(status || '').toLowerCase()
  if (normalized === 'approved') return 'bg-success'
  if (normalized === 'paid') return 'bg-info'
  if (normalized === 'failed') return 'bg-danger'
  if (normalized === 'pending') return 'bg-warning'
  return 'bg-primary'
}

function summaryCountRows(row: SettlementRow) {
  const summary = row.summary || {}
  return [
    { key: 'orders', label: 'Paid orders', value: numberValue(summary.orders_count) },
    { key: 'commissions', label: 'Commission rows', value: numberValue(summary.commission_count) },
    { key: 'payouts', label: 'Approved payouts', value: numberValue(summary.payout_count) },
  ]
}

function numberValue(value: unknown) {
  const number = Number(value)
  return Number.isFinite(number) ? new Intl.NumberFormat('th-TH').format(number) : '-'
}
</script>

<style scoped>
.np-settlement-kpi {
  height: 100%;
}

.np-settlement-status-row + .np-settlement-status-row {
  margin-top: 1rem;
}

.np-settlement-progress {
  height: .45rem;
}

.np-settlement-formula {
  display: grid;
  gap: .75rem;
}

.np-settlement-formula > div {
  align-items: center;
  background: var(--default-background);
  border: 1px solid var(--default-border);
  border-radius: .5rem;
  display: flex;
  justify-content: space-between;
  padding: .75rem;
}

.np-settlement-formula span,
.np-settlement-info span,
.np-settlement-count span,
.np-settlement-approve-box span {
  color: rgb(var(--muted-rgb));
  font-size: .78rem;
}

.np-settlement-detail-hero {
  align-items: flex-start;
  background: linear-gradient(135deg, rgba(var(--primary-rgb), .12), rgba(var(--success-rgb), .08));
  border: 1px solid rgba(var(--primary-rgb), .16);
  border-radius: .75rem;
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
}

.np-settlement-info,
.np-settlement-count,
.np-settlement-approve-box > div {
  background: var(--default-background);
  border: 1px solid var(--default-border);
  border-radius: .5rem;
  display: grid;
  gap: .2rem;
  padding: .85rem;
}

.np-settlement-info small {
  color: rgb(var(--muted-rgb));
  overflow-wrap: anywhere;
}

.np-settlement-approve-box {
  display: grid;
  gap: .75rem;
}
</style>

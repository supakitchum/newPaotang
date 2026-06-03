<template>
  <div class="np-tenant-dashboard">
    <AdminPageHeader title="Tenant Dashboard" :breadcrumbs="['Admin', 'Tenant', 'Dashboard']">
      <template #actions>
        <NuxtLink to="/admin/tenant/stock" class="btn btn-light btn-wave">
          <i class="ri-stack-line me-1" />
          Stock
        </NuxtLink>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading" @click="load">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before opening tenant pages." />
    <AdminAlert v-if="error" :type="error.status === 403 ? 'warning' : 'danger'" :message="error.message" :details="error.details" />
    <AdminLoader v-if="loading && !summary" />

    <template v-else-if="summary">
      <div class="np-tenant-dashboard-toolbar">
        <div class="np-periods">
          <button
            v-for="option in periodOptions"
            :key="option.key"
            type="button"
            :class="['np-period', { active: option.key === period }]"
            @click="setPeriod(option.key)"
          >
            {{ option.label }}
          </button>
        </div>
        <div class="text-muted fs-12">
          {{ filterCaption }} · Generated {{ formatDateTime(summary.generated_at) }}
        </div>
      </div>

      <div class="row g-3">
        <div v-for="metric in topMetrics" :key="metric.key" class="col-xxl-3 col-md-6">
          <AdminKpiCard
            :label="metric.label"
            :value="formatMetricValue(metric)"
            :hint="metricHint(metric)"
            :icon="metric.icon"
            :color-class="toneClass(metric.tone)"
          />
        </div>
      </div>

      <div v-if="alerts.length" class="row g-3">
        <div v-for="alert in alerts" :key="`${alert.severity}-${alert.title}`" class="col-xl-6">
          <div :class="['alert mb-0', alertClass(alert.severity)]" role="alert">
            <div class="fw-semibold">{{ alert.title }}</div>
            <div class="fs-12">{{ alert.message }}</div>
          </div>
        </div>
      </div>

      <div class="row g-3">
        <div class="col-xl-8">
          <div class="card custom-card h-100">
            <div class="card-header">
              <div class="card-title">Sales Trend</div>
            </div>
            <div class="card-body">
              <div v-if="!salesTrendSeries.length" class="np-dashboard-empty">No sales trend data yet.</div>
              <AdminApexChart
                v-else
                type="area"
                :height="340"
                :series="salesTrendSeries"
                :options="salesTrendOptions"
              />
            </div>
          </div>
        </div>
        <div class="col-xl-4">
          <div class="card custom-card h-100">
            <div class="card-header">
              <div class="card-title">Payment Method Mix</div>
            </div>
            <div class="card-body">
              <div v-if="!paymentRows.length" class="np-dashboard-empty">No payment data yet.</div>
              <AdminApexChart
                v-else
                type="donut"
                :height="310"
                :series="paymentChartSeries"
                :options="paymentChartOptions"
              />
            </div>
          </div>
        </div>

        <div class="col-xl-6">
          <div class="card custom-card h-100">
            <div class="card-header">
              <div class="card-title">Wallet Flow</div>
            </div>
            <div class="card-body">
              <div v-if="!walletFlowSeries.length" class="np-dashboard-empty">No wallet data yet.</div>
              <AdminApexChart
                v-else
                type="bar"
                :height="300"
                :series="walletFlowSeries"
                :options="walletFlowOptions"
              />
            </div>
          </div>
        </div>
        <div class="col-xl-6">
          <div class="card custom-card h-100">
            <div class="card-header">
              <div class="card-title">Stock & Reward Status</div>
            </div>
            <div class="card-body">
              <div v-if="!statusChartSeries.length" class="np-dashboard-empty">No status data yet.</div>
              <AdminApexChart
                v-else
                type="bar"
                :height="300"
                :series="statusChartSeries"
                :options="statusChartOptions"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="row g-3">
        <div class="col-xl-8">
          <div class="card custom-card h-100">
            <div class="card-header justify-content-between">
              <div class="card-title">Top Lottery Numbers</div>
              <span class="fs-12 text-muted">Top 10 by sold tickets</span>
            </div>
            <div class="card-body">
              <div class="row g-3">
                <div v-for="group in popularNumberGroups" :key="group.key" class="col-lg-4">
                  <div class="np-number-group">
                    <div class="d-flex align-items-center justify-content-between mb-2">
                      <strong>{{ group.label }}</strong>
                      <span class="text-muted fs-12">{{ group.rows.length }} items</span>
                    </div>
                    <div v-if="!group.rows.length" class="np-dashboard-empty py-4">No numbers yet.</div>
                    <div v-else class="np-number-list">
                      <div v-for="(row, index) in group.rows" :key="`${group.key}-${row.number}`" class="np-number-row">
                        <span class="np-rank">{{ index + 1 }}</span>
                        <strong>{{ row.number }}</strong>
                        <span>{{ formatNumber(row.ticket_count || row.value || 0) }} ใบ</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="col-xl-4">
          <AdminDataTable
            title="Stock Summary"
            :columns="stockColumns"
            :rows="stockRows"
            :embedded="false"
            empty-title="No stock data"
            empty-message="Stock will appear after allocation or sync."
          />
        </div>
      </div>

      <div class="row g-3">
        <div class="col-12">
          <AdminDataTable
            title="Recent Orders"
            :columns="orderColumns"
            :rows="sortedOrders"
            sortable
            :sort-key="orderSort.key"
            :sort-direction="orderSort.direction"
            empty-title="No paid orders"
            empty-message="Paid orders in this tenant and period will appear here."
            @sort-change="orderSort = $event"
          />
        </div>
        <div class="col-xl-6">
          <AdminDataTable
            title="Recent Wallet Ledger"
            :columns="walletColumns"
            :rows="sortedWalletRows"
            sortable
            :sort-key="walletSort.key"
            :sort-direction="walletSort.direction"
            empty-title="No wallet movement"
            empty-message="Wallet ledger rows for this period will appear here."
            @sort-change="walletSort = $event"
          />
        </div>
        <div class="col-xl-6">
          <AdminDataTable
            title="Recent Reward Claims"
            :columns="rewardColumns"
            :rows="sortedRewardRows"
            sortable
            :sort-key="rewardSort.key"
            :sort-direction="rewardSort.direction"
            empty-title="No reward claims"
            empty-message="Reward claims for this tenant and period will appear here."
            @sort-change="rewardSort = $event"
          />
        </div>
      </div>

      <div class="card custom-card">
        <div class="card-header">
          <div class="card-title">Tenant operations</div>
        </div>
        <div class="card-body">
          <div class="row g-3">
            <div class="col-md-6">
              <NuxtLink to="/admin/tenant/maintenance" class="btn btn-outline-primary btn-wave w-100 text-start">
                <i class="ri-tools-line me-2" />
                Maintenance controls
              </NuxtLink>
            </div>
            <div class="col-md-6">
              <NuxtLink to="/admin/tenant/support-access" class="btn btn-outline-primary btn-wave w-100 text-start">
                <i class="ri-customer-service-2-line me-2" />
                Support access
              </NuxtLink>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { formatAdminValue, formatDateTime } from '~/utils/format'

definePageMeta({ layout: 'admin' })

type SortState = {
  key: string
  direction: 'asc' | 'desc'
}

const api = useAdminApi()
const route = useRoute()
const router = useRouter()
const session = useAdminSession()
const loading = ref(false)
const error = ref<any>(null)
const summary = ref<any>(null)
const tenantId = computed(() => session.currentTenantId.value)
const period = ref(typeof route.query.period === 'string' ? route.query.period : 'today')
const orderSort = ref<SortState>({ key: 'created_at', direction: 'desc' })
const walletSort = ref<SortState>({ key: 'created_at', direction: 'desc' })
const rewardSort = ref<SortState>({ key: 'created_at', direction: 'desc' })

const fallbackPeriodOptions = [
  { key: 'today', label: 'Today' },
  { key: 'yesterday', label: 'Yesterday' },
  { key: 'last_7_days', label: 'Last 7 days' },
  { key: 'current_draw', label: 'Current draw' },
  { key: 'previous_draw', label: 'Previous draw' },
]

const periodOptions = computed(() => summary.value?.filter?.options?.length ? summary.value.filter.options : fallbackPeriodOptions)
const filterCaption = computed(() => {
  const filter = summary.value?.filter
  if (!filter) return 'No filter loaded'
  return `${filter.label || period.value}: ${filter.current?.label || '-'} vs ${filter.previous?.label || '-'}`
})

const topMetrics = computed(() => {
  const metrics = summary.value?.metrics || []
  return metrics.slice(0, 8)
})

const alerts = computed(() => summary.value?.alerts || [])
const paymentRows = computed(() => summary.value?.charts?.payment_methods || summary.value?.charts?.secondary_breakdown || [])
const walletChart = computed(() => summary.value?.charts?.wallet_flow || emptyTrend())
const salesChart = computed(() => summary.value?.charts?.primary_trend || summary.value?.charts?.sales_trend || emptyTrend())
const stockRows = computed(() => summary.value?.tables?.stock_summary || [])
const popularNumberGroups = computed(() => {
  const groups = summary.value?.tables?.popular_numbers || summary.value?.charts?.top_numbers || {}
  return [
    { key: 'back2', label: '2 ท้าย', rows: groups.back2 || [] },
    { key: 'back3', label: '3 ท้าย', rows: groups.back3 || [] },
    { key: 'front3', label: '3 หน้า', rows: groups.front3 || [] },
  ]
})

const orderColumns = [
  { key: 'reference', label: 'Order' },
  { key: 'customer', label: 'Customer' },
  { key: 'amount', label: 'Amount', type: 'money' },
  { key: 'payment_method', label: 'Payment' },
  { key: 'status', label: 'Status' },
  { key: 'created_at', label: 'Paid at', type: 'datetime' },
]
const walletColumns = [
  { key: 'entry_type', label: 'Type' },
  { key: 'customer', label: 'Customer' },
  { key: 'amount', label: 'Amount', type: 'money' },
  { key: 'balance_after', label: 'Balance after', type: 'money' },
  { key: 'status', label: 'Status' },
  { key: 'created_at', label: 'Posted at', type: 'datetime' },
]
const rewardColumns = [
  { key: 'customer', label: 'Customer' },
  { key: 'amount', label: 'Prize amount', type: 'money' },
  { key: 'payout_method', label: 'Payout method' },
  { key: 'status', label: 'Status' },
  { key: 'created_at', label: 'Submitted at', type: 'datetime' },
]
const stockColumns = [
  { key: 'status', label: 'Status' },
  { key: 'count', label: 'Count', type: 'number' },
  { key: 'percent', label: 'Share', type: 'percent' },
]

const sortedOrders = computed(() => sortRows(summary.value?.tables?.recent_orders || [], orderSort.value))
const sortedWalletRows = computed(() => sortRows(summary.value?.tables?.recent_wallet_ledger || [], walletSort.value))
const sortedRewardRows = computed(() => sortRows(summary.value?.tables?.recent_reward_claims || [], rewardSort.value))

const salesTrendSeries = computed(() => trendSeries(salesChart.value, ['sales_amount', 'tickets_sold']))
const walletFlowSeries = computed(() => trendSeries(walletChart.value))
const paymentChartSeries = computed(() => paymentRows.value.map((row: any) => chartValue(row.value, row.type)))
const statusChartSeries = computed(() => {
  const stock = summary.value?.charts?.stock_by_status || []
  const rewards = summary.value?.charts?.reward_claims_by_status || []
  return [
    { name: 'Stock', data: statusLabels.value.map((label) => Number(stock.find((row: any) => row.label === label)?.value || 0)) },
    { name: 'Reward claims', data: statusLabels.value.map((label) => Number(rewards.find((row: any) => row.label === label)?.value || 0)) },
  ].filter((series) => series.data.some((value: number) => value > 0))
})
const statusLabels = computed(() => {
  const labels = new Set<string>()
  ;(summary.value?.charts?.stock_by_status || []).forEach((row: any) => labels.add(String(row.label)))
  ;(summary.value?.charts?.reward_claims_by_status || []).forEach((row: any) => labels.add(String(row.label)))
  return Array.from(labels)
})

const salesTrendOptions = computed(() => trendOptions(salesChart.value, 'Sales / tickets'))
const walletFlowOptions = computed(() => barTrendOptions(walletChart.value, 'Baht', ['#3b82f6', '#ef4444', '#22c55e']))
const paymentChartOptions = computed(() => ({
  labels: paymentRows.value.map((row: any) => row.label || 'Unknown'),
  legend: { position: 'bottom' },
  dataLabels: { enabled: false },
  tooltip: {
    y: {
      formatter: (value: number) => formatMoneyChart(value),
    },
  },
}))
const statusChartOptions = computed(() => ({
  xaxis: { categories: statusLabels.value },
  plotOptions: { bar: { borderRadius: 4, columnWidth: '45%' } },
  dataLabels: { enabled: false },
  colors: ['#3b82f6', '#a855f7'],
  legend: { position: 'top' },
}))

const load = async () => {
  if (!tenantId.value) return
  session.setScope('tenant', tenantId.value)
  loading.value = true
  error.value = null

  try {
    summary.value = await api.apiFetch('/admin/tenant/dashboard/summary', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: { period: period.value },
    })
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const setPeriod = async (key: string) => {
  period.value = key
  await router.replace({ query: { ...route.query, period: key } })
}

watch(
  () => route.query.period,
  (value) => {
    period.value = typeof value === 'string' && value ? value : 'today'
  },
)

watch([tenantId, period], () => {
  void load()
}, { immediate: true })

function emptyTrend() {
  return { labels: [], keys: [], series: [] }
}

function formatMetricValue(metric: any) {
  if (metric.type === 'money') {
    return formatAdminValue({ amount: metric.current || 0, currency: 'THB' }, 'money')
  }
  return formatAdminValue(metric.current || 0, metric.type || 'number')
}

function metricHint(metric: any) {
  const delta = metric.delta || {}
  const percent = delta.percent
  if (percent === null || percent === undefined) {
    return 'No previous data'
  }
  const direction = delta.direction === 'down' ? 'down' : delta.direction === 'up' ? 'up' : 'flat'
  return `${direction} ${Math.abs(Number(percent)).toLocaleString('th-TH', { maximumFractionDigits: 2 })}% vs previous`
}

function toneClass(tone?: string) {
  const map: Record<string, string> = {
    primary: 'bg-primary-transparent text-primary',
    success: 'bg-success-transparent text-success',
    info: 'bg-info-transparent text-info',
    warning: 'bg-warning-transparent text-warning',
    danger: 'bg-danger-transparent text-danger',
    secondary: 'bg-secondary-transparent text-secondary',
    pink: 'bg-pink-transparent text-pink',
  }
  return map[tone || 'primary'] || map.primary
}

function alertClass(severity?: string) {
  if (severity === 'warning') return 'alert-warning'
  if (severity === 'danger' || severity === 'critical') return 'alert-danger'
  return 'alert-info'
}

function trendSeries(chart: any, preferredKeys: string[] = []) {
  const series = Array.isArray(chart?.series) ? chart.series : []
  const filtered = preferredKeys.length
    ? series.filter((row: any) => preferredKeys.includes(row.key))
    : series

  return filtered.map((row: any) => ({
    name: row.label || row.key,
    data: (row.values || []).map((value: any) => chartValue(value, row.type)),
  }))
}

function trendOptions(chart: any, title: string) {
  return {
    xaxis: { categories: chart?.labels || [] },
    stroke: { curve: 'smooth', width: 3 },
    fill: { type: 'gradient', gradient: { opacityFrom: 0.25, opacityTo: 0.02 } },
    dataLabels: { enabled: false },
    colors: ['#3b82f6', '#22c55e', '#a855f7'],
    tooltip: {
      y: {
        formatter: (value: number) => title === 'Baht' ? formatMoneyChart(value) : formatNumber(value),
      },
    },
    yaxis: {
      labels: {
        formatter: (value: number) => title === 'Baht' ? formatCompactMoney(value) : formatNumber(value),
      },
    },
    legend: { position: 'top' },
  }
}

function barTrendOptions(chart: any, title: string, colors: string[]) {
  return {
    xaxis: { categories: chart?.labels || [] },
    plotOptions: {
      bar: {
        borderRadius: 5,
        columnWidth: '48%',
      },
    },
    dataLabels: { enabled: false },
    fill: { opacity: 1 },
    colors,
    tooltip: {
      y: {
        formatter: (value: number) => title === 'Baht' ? formatMoneyChart(value) : formatNumber(value),
      },
    },
    yaxis: {
      labels: {
        formatter: (value: number) => title === 'Baht' ? formatCompactMoney(value) : formatNumber(value),
      },
    },
    grid: {
      borderColor: 'rgba(107, 114, 128, .18)',
      strokeDashArray: 4,
    },
    legend: { position: 'top' },
  }
}

function chartValue(value: any, type?: string) {
  const number = Number(value || 0)
  return type === 'money' ? number / 100 : number
}

function formatMoneyChart(value: number) {
  return `${value.toLocaleString('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} บาท`
}

function formatCompactMoney(value: number) {
  if (Math.abs(value) >= 1000000) return `${(value / 1000000).toLocaleString('th-TH', { maximumFractionDigits: 1 })}M`
  if (Math.abs(value) >= 1000) return `${(value / 1000).toLocaleString('th-TH', { maximumFractionDigits: 1 })}K`
  return value.toLocaleString('th-TH', { maximumFractionDigits: 0 })
}

function formatNumber(value: any) {
  return Number(value || 0).toLocaleString('th-TH')
}

function sortRows(rows: any[], sort: SortState) {
  return [...rows].sort((left, right) => {
    const leftValue = sortValue(left?.[sort.key])
    const rightValue = sortValue(right?.[sort.key])
    const result = leftValue > rightValue ? 1 : leftValue < rightValue ? -1 : 0
    return sort.direction === 'asc' ? result : -result
  })
}

function sortValue(value: any) {
  if (value && typeof value === 'object' && 'amount' in value) {
    return Number(value.amount || 0)
  }
  if (typeof value === 'string' && /\d{4}-\d{2}-\d{2}/.test(value)) {
    return new Date(value).getTime()
  }
  const number = Number(value)
  if (Number.isFinite(number) && value !== '') {
    return number
  }
  return String(value || '').toLowerCase()
}
</script>

<style scoped>
.np-tenant-dashboard-toolbar {
  align-items: center;
  display: flex;
  flex-wrap: wrap;
  gap: .75rem;
  justify-content: space-between;
  margin-block-end: 1rem;
}

.np-tenant-dashboard > .row {
  --bs-gutter-y: 1rem;
}

.np-tenant-dashboard > .row + .row,
.np-tenant-dashboard > .row + .card,
.np-tenant-dashboard > .card + .row {
  margin-top: 1rem;
}

.np-tenant-dashboard :deep(.custom-card) {
  margin-bottom: 0;
}

.np-tenant-dashboard :deep(.card-body) {
  min-width: 0;
}

.np-periods {
  background: var(--light);
  border: 1px solid var(--default-border);
  border-radius: .5rem;
  display: inline-flex;
  flex-wrap: wrap;
  gap: .25rem;
  padding: .25rem;
}

.np-period {
  background: transparent;
  border: 0;
  border-radius: .375rem;
  color: var(--text-muted);
  font-size: .8125rem;
  font-weight: 600;
  min-height: 2rem;
  padding: .35rem .75rem;
}

.np-period.active {
  background: var(--primary-color);
  color: #fff;
}

.np-dashboard-empty {
  align-items: center;
  color: var(--text-muted);
  display: flex;
  font-size: .8125rem;
  justify-content: center;
  min-height: 180px;
}

.np-number-group {
  border: 1px solid var(--default-border);
  border-radius: .5rem;
  height: 100%;
  padding: .85rem;
}

.np-number-list {
  display: grid;
  gap: .5rem;
}

.np-number-row {
  align-items: center;
  display: grid;
  gap: .5rem;
  grid-template-columns: 2rem 1fr auto;
}

.np-rank {
  align-items: center;
  background: rgba(var(--primary-rgb), .1);
  border-radius: 999px;
  color: var(--primary-color);
  display: inline-flex;
  font-size: .75rem;
  font-weight: 700;
  height: 1.5rem;
  justify-content: center;
  width: 1.5rem;
}
</style>

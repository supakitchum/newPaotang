<template>
  <div class="np-stock-summary mb-3">
    <AdminApiState v-if="!normalizedGameId" message="Select a game to load stock generation summary widgets." />
    <template v-else>
      <AdminApiState :error="error" />
      <div v-if="summary?.empty" class="alert alert-info d-flex align-items-start gap-2">
        <i class="ri-information-line fs-18" />
        <div>No generated stock matched this game.</div>
      </div>

      <div class="row g-3">
        <div class="col-12 col-md-6 col-xl">
          <div class="card custom-card np-stock-summary-card">
            <div class="card-body">
              <div class="d-flex align-items-start justify-content-between gap-3">
                <div>
                  <p class="text-muted mb-1">Generated supply</p>
                  <h4 class="mb-1">{{ totalTicketsValue }}</h4>
                  <span class="text-muted fs-12">{{ totalTicketsHint }}</span>
                </div>
                <span class="avatar bg-primary-transparent text-primary">
                  <i class="ri-ticket-2-line fs-4" />
                </span>
              </div>
            </div>
          </div>
        </div>

        <div v-for="card in coverageCards" :key="card.key" class="col-12 col-md-6 col-xl">
          <div class="card custom-card np-stock-summary-card">
            <div class="card-body">
              <div class="d-flex align-items-start justify-content-between gap-3">
                <div>
                  <p class="text-muted mb-1">{{ card.label }}</p>
                  <h4 class="mb-1">{{ card.value }}</h4>
                  <span class="text-muted fs-12">{{ card.hint }}</span>
                </div>
                <span :class="['avatar', card.colorClass]">
                  <i :class="[card.icon, 'fs-4']" />
                </span>
              </div>
              <div class="d-flex flex-wrap gap-2 mt-3 fs-12">
                <span class="badge bg-light text-default">{{ card.badgeOneLabel }} {{ card.missing }}</span>
                <span class="badge bg-light text-default">{{ card.badgeTwoLabel }} {{ card.min }}</span>
                <span class="badge bg-light text-default">{{ card.badgeThreeLabel }} {{ card.max }}</span>
                <span class="badge bg-light text-default">{{ card.badgeFourLabel }} {{ card.total }}</span>
              </div>
            </div>
          </div>
        </div>

        <div class="col-12 col-xl-4">
          <div class="card custom-card np-stock-summary-card">
            <div class="card-body">
              <div class="d-flex align-items-start justify-content-between gap-3">
                <div>
                  <p class="text-muted mb-1">Status totals</p>
                  <h4 class="mb-1">{{ statusTotalValue }}</h4>
                  <span class="text-muted fs-12">{{ statusHint }}</span>
                </div>
                <span class="avatar bg-warning-transparent text-warning">
                  <i class="ri-list-check-3 fs-4" />
                </span>
              </div>
              <div class="np-stock-summary-status-grid mt-3">
                <div v-for="status in statusRows" :key="status.key" class="d-flex align-items-center justify-content-between gap-2">
                  <span class="text-muted">{{ status.label }}</span>
                  <strong>{{ status.value }}</strong>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
type StockCoverage = {
  expected_distinct?: number
  distinct_count?: number
  missing_distinct_count?: number
  min_count_per_number?: number
  max_count_per_number?: number
  total_count?: number
}

type StockSummary = {
  game_id?: string | null
  batch_id?: string | null
  total_count?: number
  empty?: boolean
  status_counts?: Record<string, number | undefined>
  pattern_totals?: Record<string, {
    pattern_count?: number
    reserved_count?: number
    sold_count?: number
    used_count?: number
    generated_count?: number
    generated_remaining_count?: number
    limit_total?: number | null
    remaining_limit?: number | null
    sellable_remaining_count?: number
    limit_exceeds_supply_count?: number
  }>
  number_coverage?: {
    back2?: StockCoverage
    back3?: StockCoverage
    front3?: StockCoverage
  }
}

const props = withDefaults(defineProps<{
  endpoint: string
  gameId?: string | number | null
  batchId?: string | number | null
  refreshKey?: number
}>(), {
  gameId: '',
  batchId: '',
  refreshKey: 0,
})

const api = useAdminApi()
const session = useAdminSession()
const loading = ref(false)
const error = ref<any>(null)
const summary = ref<StockSummary | null>(null)
const requestSerial = ref(0)

const normalizedGameId = computed(() => normalizeId(props.gameId))
const normalizedBatchId = computed(() => normalizeId(props.batchId))

const totalTicketsValue = computed(() => {
  if (loading.value) return 'Loading'
  if (!summary.value) return '-'
  if (summary.value.empty) return 'No stock'
  return formatNumber(summary.value.total_count)
})
const totalTicketsHint = computed(() => {
  if (loading.value) return 'Fetching aggregate summary'
  if (!summary.value) return 'No summary loaded'
  if (summary.value.empty) return 'Generate or import stock for this game'
  return summary.value.batch_id ? `Batch ${summary.value.batch_id}` : `Game ${summary.value.game_id || normalizedGameId.value}`
})
const statusTotalValue = computed(() => {
  if (loading.value) return 'Loading'
  if (!summary.value) return '-'
  return formatNumber(summary.value.status_counts?.total ?? summary.value.total_count)
})
const statusHint = computed(() => loading.value ? 'Fetching status counts' : 'Available, allocated, sold, recalled, and voided')
const coverageCards = computed(() => [
  coverageCard('back2', '2-tail max limit', 'ri-stack-line', 'bg-success-transparent text-success'),
  coverageCard('back3', '3-tail max limit', 'ri-grid-line', 'bg-info-transparent text-info'),
  coverageCard('front3', '3-front max limit', 'ri-layout-grid-line', 'bg-secondary-transparent text-secondary'),
])
const statusRows = computed(() => {
  const counts = summary.value?.status_counts || {}
  return [
    { key: 'available', label: 'Available', value: formatSummaryNumber(counts.available) },
    { key: 'allocated', label: 'Allocated', value: formatSummaryNumber(counts.allocated) },
    { key: 'sold', label: 'Sold', value: formatSummaryNumber(counts.sold) },
    { key: 'recalled', label: 'Recalled', value: formatSummaryNumber(counts.recalled) },
    { key: 'voided', label: 'Voided', value: formatSummaryNumber(counts.voided) },
  ]
})

watch(
  () => [normalizedGameId.value, normalizedBatchId.value, props.endpoint, props.refreshKey, session.isAuthenticated.value],
  () => {
    void loadSummary()
  },
  { immediate: true },
)

async function loadSummary() {
  if (!import.meta.client) {
    return
  }

  error.value = null
  summary.value = null

  if (!normalizedGameId.value || !session.isAuthenticated.value) {
    loading.value = false
    return
  }

  const serial = requestSerial.value + 1
  requestSerial.value = serial
  loading.value = true
  try {
    const response = await api.apiFetch(props.endpoint, {
      scope: 'central',
      query: cleanQuery({
        game_id: normalizedGameId.value,
        batch_id: normalizedBatchId.value,
      }),
    })
    if (requestSerial.value === serial) {
      summary.value = extractData(response)
    }
  } catch (err) {
    if (requestSerial.value === serial) {
      error.value = err
    }
  } finally {
    if (requestSerial.value === serial) {
      loading.value = false
    }
  }
}

function coverageCard(key: 'back2' | 'back3' | 'front3', label: string, icon: string, colorClass: string) {
  const coverage = summary.value?.number_coverage?.[key]
  const patternTotal = summary.value?.pattern_totals?.[key]
  return {
    key,
    label,
    icon,
    colorClass,
    value: loading.value ? 'Loading' : patternTotal ? formatNullableNumber(patternTotal.limit_total) : coverage ? `${formatNumber(coverage.distinct_count)} / ${formatNumber(coverage.expected_distinct)}` : '-',
    hint: loading.value ? 'Fetching limits' : patternTotal ? `Configured across ${formatNumber(patternTotal.pattern_count)} patterns` : coverage ? 'Distinct values covered' : 'No coverage loaded',
    missing: patternTotal ? formatSummaryNumber(patternTotal.generated_count) : formatSummaryNumber(coverage?.missing_distinct_count),
    min: patternTotal ? formatNullableNumber(patternTotal.remaining_limit) : formatSummaryNumber(coverage?.min_count_per_number),
    max: patternTotal ? formatSummaryNumber(patternTotal.sellable_remaining_count) : formatSummaryNumber(coverage?.max_count_per_number),
    total: patternTotal ? formatSummaryNumber(patternTotal.used_count) : formatSummaryNumber(coverage?.total_count),
    badgeOneLabel: patternTotal ? 'Generated' : 'Missing',
    badgeTwoLabel: patternTotal ? 'Limit left' : 'Min',
    badgeThreeLabel: patternTotal ? 'Sellable' : 'Max',
    badgeFourLabel: patternTotal ? 'Used' : 'Tickets',
  }
}

function normalizeId(value: string | number | null | undefined) {
  return String(value ?? '').trim()
}

function extractData(response: any): StockSummary {
  return response?.data ?? response
}

function cleanQuery(value: Record<string, string>) {
  return Object.fromEntries(Object.entries(value).filter(([, entry]) => entry !== ''))
}

function formatSummaryNumber(value: number | undefined) {
  if (loading.value || value === undefined || value === null) return '-'
  return formatNumber(value)
}

function formatNullableNumber(value: number | null | undefined) {
  if (loading.value) return '-'
  if (value === null || value === undefined) return 'Unlimited'
  return formatNumber(value)
}

function formatNumber(value: number | undefined) {
  if (value === undefined || value === null || Number.isNaN(Number(value))) return '-'
  return new Intl.NumberFormat('th-TH', { maximumFractionDigits: 0 }).format(Number(value))
}
</script>

<style scoped>
.np-stock-summary-card {
  min-height: 100%;
}

.np-stock-summary-status-grid {
  display: grid;
  gap: 0.45rem 1rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

@media (min-width: 1200px) {
  .np-stock-summary-status-grid {
    grid-template-columns: repeat(1, minmax(0, 1fr));
  }
}
</style>

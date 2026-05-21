<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-start justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Stock coverage</div>
        <p class="text-muted fs-12 mb-0">Partner pattern availability for the selected tenant game.</p>
      </div>
      <div class="d-flex flex-wrap align-items-center gap-2">
        <span :class="['badge', realtimeBadge.className]" :title="realtimeBadge.title">
          <i :class="[realtimeBadge.icon, 'me-1']" />
          {{ realtimeBadge.label }}
        </span>
        <button class="btn btn-sm btn-light btn-wave" type="button" :disabled="loading || !gameId" @click="loadCoverage()">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </div>
    </div>
    <div class="card-body">
      <AdminApiState v-if="!gameId" message="Select a game to load stock coverage." />
      <AdminApiState :error="error" />
      <div class="row g-2 align-items-end mb-3">
        <div class="col-sm-6 col-lg-3">
          <label class="form-label" for="tenant-stock-coverage-dimension">Dimension</label>
          <select id="tenant-stock-coverage-dimension" v-model="filters.dimension" class="form-select" :disabled="!gameId" @change="applyFilters">
            <option value="back2">Back 2</option>
            <option value="back3">Back 3</option>
            <option value="front3">Front 3</option>
          </select>
        </div>
        <div class="col-sm-6 col-lg-3">
          <label class="form-label" for="tenant-stock-coverage-q">Pattern</label>
          <input id="tenant-stock-coverage-q" v-model="filters.q" class="form-control" :disabled="!gameId" inputmode="numeric" placeholder="00, 001, 999" @keyup.enter="applyFilters">
        </div>
        <div class="col-sm-6 col-lg-2">
          <label class="form-label" for="tenant-stock-coverage-limit">Rows</label>
          <input id="tenant-stock-coverage-limit" v-model.number="filters.limit" class="form-control" :disabled="!gameId" type="number" min="1" max="100" step="1" @keyup.enter="applyFilters">
        </div>
        <div class="col-sm-6 col-lg-2">
          <button class="btn btn-outline-primary btn-wave w-100" type="button" :disabled="!gameId" @click="applyFilters">
            <i class="ri-filter-3-line me-1" />
            Apply
          </button>
        </div>
      </div>

      <div class="row g-2 mb-3">
        <div v-for="metric in summaryMetrics" :key="metric.key" class="col-6 col-xl-2">
          <div class="border rounded p-2 h-100">
            <span class="text-muted fs-12 d-block">{{ metric.label }}</span>
            <strong>{{ metric.value }}</strong>
          </div>
        </div>
      </div>

      <AdminDataTable
        title="Coverage rows"
        :columns="columns"
        :rows="rows"
        :loading="loading"
        :sort-key="sortState.key"
        :sort-direction="sortState.direction"
        sortable
        embedded
        empty-title="No coverage"
        empty-message="No stock coverage rows matched this game."
        @sort-change="applySort"
      >
        <template #cell-status="{ row }">
          <AdminStatusBadge :status="row.status" />
        </template>
        <template #cell-limit_exceeds_supply="{ row }">
          <AdminStatusBadge :status="row.limit_exceeds_supply ? 'warning' : 'ok'" :label="row.limit_exceeds_supply ? 'Over limit' : 'OK'" />
        </template>
      </AdminDataTable>
      <AdminPagination
        :next-cursor="meta.next_cursor"
        :has-previous="pageState.index > 0"
        :loading="loading"
        :current-page="pageState.index + 1"
        :page-size="filters.limit || 20"
        @previous="loadPreviousPage"
        @next="loadNextPage"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime } from '~/utils/format'

const props = defineProps<{
  gameId: string
  refreshKey?: number
}>()

const api = useAdminApi()
const session = useAdminSession()
const loading = ref(false)
const error = ref<any>(null)
const rows = ref<any[]>([])
const summary = ref<any>(null)
const filters = reactive({
  dimension: 'back2',
  q: '',
  limit: 20,
})
const sortState = reactive<{ key: string, direction: 'asc' | 'desc' }>({ key: 'number', direction: 'asc' })
const meta = reactive({ next_cursor: null as string | null, has_more: false })
const pageState = reactive({ cursors: [null] as Array<string | null>, index: 0 })
let reloadTimer: ReturnType<typeof setTimeout> | null = null

const columns = [
  { key: 'number', label: 'Pattern' },
  { key: 'generated_count', label: 'Generated', type: 'number' as const },
  { key: 'reserved_count', label: 'Reserved', type: 'number' as const },
  { key: 'sold_count', label: 'Sold', type: 'number' as const },
  { key: 'remaining_limit', label: 'Limit left', type: 'number' as const },
  { key: 'sellable_remaining_count', label: 'Sellable', type: 'number' as const },
  { key: 'status', label: 'Status', type: 'status' as const },
  { key: 'updated_at', label: 'Updated', type: 'datetime' as const },
  { key: 'limit_exceeds_supply', label: 'Ceiling' },
]

const realtimeChannelName = computed(() => (
  props.gameId && session.currentTenantId.value
    ? `private-admin.tenant.${session.currentTenantId.value}.stock.coverage.game.${props.gameId}`
    : ''
))
const realtimeEnabled = computed(() => Boolean(props.gameId && session.isAuthenticated.value))
const realtime = useAdminRealtimeSubscription({
  channelName: realtimeChannelName,
  eventName: 'stock.coverage.updated',
  enabled: realtimeEnabled,
  onEvent: handleRealtimeEvent,
  onReconnect: scheduleReload,
})
const realtimeBadge = computed(() => coverageRealtimeBadge(realtime.status.value, realtime.isConfigured.value))
const summaryMetrics = computed(() => {
  const totals = summary.value?.totals?.[filters.dimension] || {}
  return [
    { key: 'patterns', label: 'Patterns', value: formatNumber(totals.pattern_count) },
    { key: 'generated', label: 'Generated', value: formatNumber(totals.generated_count) },
    { key: 'reserved', label: 'Reserved', value: formatNumber(totals.reserved_count) },
    { key: 'sold', label: 'Sold', value: formatNumber(totals.sold_count) },
    { key: 'limit', label: 'Limit total', value: formatLimit(totals.limit_total) },
    { key: 'sellable', label: 'Sellable', value: formatNumber(totals.sellable_remaining_count) },
  ]
})

watch(() => props.gameId, () => {
  resetPageState()
  void loadCoverage()
}, { immediate: true })

watch(() => props.refreshKey, () => {
  scheduleReload()
})

onBeforeUnmount(() => {
  if (reloadTimer !== null && import.meta.client) {
    window.clearTimeout(reloadTimer)
  }
})

function applyFilters() {
  resetPageState()
  void loadCoverage()
}

function applySort(next: { key: string, direction: 'asc' | 'desc' }) {
  sortState.key = next.key
  sortState.direction = next.direction
  resetPageState()
  void loadCoverage()
}

async function loadCoverage(cursor?: string | null, pageMode: 'reset' | 'next' | 'previous' | 'current' = 'reset') {
  if (!props.gameId || !session.isAuthenticated.value) {
    rows.value = []
    summary.value = null
    return
  }

  loading.value = true
  error.value = null
  try {
    const response = await api.apiFetch('/admin/tenant/stock/coverage', {
      scope: 'tenant',
      tenantId: session.currentTenantId.value,
      query: cleanQuery({
        game_id: props.gameId,
        dimension: filters.dimension,
        q: filters.q,
        cursor: cursor || undefined,
        limit: filters.limit || 20,
        sort_by: sortState.key,
        sort_dir: sortState.direction,
      }),
    })
    summary.value = extractData(response)
    rows.value = normalizeRows(extractItems(response))
    const nextMeta = extractMeta(response)
    meta.next_cursor = nextMeta.next_cursor || null
    meta.has_more = Boolean(nextMeta.has_more || nextMeta.next_cursor)
    updatePageState(cursor || null, pageMode)
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

function loadNextPage() {
  if (!meta.next_cursor) return
  void loadCoverage(meta.next_cursor, 'next')
}

function loadPreviousPage() {
  if (pageState.index <= 0) return
  void loadCoverage(pageState.cursors[pageState.index - 1] || null, 'previous')
}

function handleRealtimeEvent(payload: any) {
  const source = payload?.coverage || payload?.delta || payload?.data || payload || {}
  const gameId = String(source?.game_id || '').trim()
  if (gameId !== props.gameId) {
    return
  }

  scheduleReload()
}

function scheduleReload() {
  if (!import.meta.client || !props.gameId) {
    return
  }

  if (reloadTimer !== null) {
    window.clearTimeout(reloadTimer)
  }

  reloadTimer = window.setTimeout(() => {
    reloadTimer = null
    void loadCoverage(pageState.cursors[pageState.index] || null, 'current')
  }, 300)
}

function resetPageState() {
  pageState.cursors = [null]
  pageState.index = 0
  meta.next_cursor = null
  meta.has_more = false
}

function updatePageState(cursor: string | null, mode: 'reset' | 'next' | 'previous' | 'current') {
  if (mode === 'reset') {
    pageState.cursors = [cursor]
    pageState.index = 0
    return
  }
  if (mode === 'next') {
    pageState.cursors = [...pageState.cursors.slice(0, pageState.index + 1), cursor]
    pageState.index += 1
    return
  }
  if (mode === 'previous') {
    pageState.index = Math.max(0, pageState.index - 1)
  }
}

function normalizeRows(items: any[]) {
  return items.map((row) => ({
    ...row,
    generated_count: formatNumber(row.generated_count),
    reserved_count: formatNumber(row.reserved_count),
    sold_count: formatNumber(row.sold_count),
    remaining_limit: formatLimit(row.remaining_limit),
    sellable_remaining_count: formatNumber(row.sellable_remaining_count),
    updated_at: row.updated_at ? formatDateTime(String(row.updated_at)) : '-',
  }))
}

function coverageRealtimeBadge(status: string, configured: boolean) {
  if (!configured) {
    return { label: 'Fallback HTTP', className: 'bg-secondary-transparent text-secondary', icon: 'ri-wifi-off-line', title: 'Realtime is not configured.' }
  }
  if (status === 'connected') {
    return { label: 'Live', className: 'bg-success-transparent text-success', icon: 'ri-broadcast-line', title: 'Coverage websocket is connected.' }
  }
  if (status === 'connecting' || status === 'authenticating' || status === 'reconnecting') {
    return { label: 'Connecting', className: 'bg-warning-transparent text-warning', icon: 'ri-loader-4-line', title: 'Coverage websocket is connecting.' }
  }
  if (status === 'error') {
    return { label: 'Attention', className: 'bg-danger-transparent text-danger', icon: 'ri-alert-line', title: 'Coverage websocket needs attention.' }
  }
  return { label: 'Idle', className: 'bg-light text-default', icon: 'ri-time-line', title: 'Select a game to subscribe to coverage updates.' }
}

function cleanQuery(value: Record<string, any>) {
  return Object.fromEntries(Object.entries(value).filter(([, entry]) => entry !== '' && entry !== undefined && entry !== null))
}

function extractData(response: any) {
  return response?.data ?? response
}

function extractItems(response: any) {
  if (Array.isArray(response)) return response
  if (Array.isArray(response?.data)) return response.data
  if (Array.isArray(response?.data?.items)) return response.data.items
  if (Array.isArray(response?.items)) return response.items
  return []
}

function extractMeta(response: any) {
  return response?.meta || response?.data?.meta || {}
}

function formatNumber(value: any) {
  const parsed = Number(value)
  if (!Number.isFinite(parsed)) {
    return '-'
  }

  return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(parsed)
}

function formatLimit(value: any) {
  return value === null || value === undefined || value === '' ? 'Unlimited' : formatNumber(value)
}
</script>

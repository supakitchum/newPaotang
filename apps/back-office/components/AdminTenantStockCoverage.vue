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
            <option v-for="dimension in dimensionOptions" :key="dimension.value" :value="dimension.value">
              {{ dimension.label }}
            </option>
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

      <div v-if="gameId" class="row g-3 mb-3">
        <div class="col-12 col-xl-6">
          <div class="border rounded p-3 h-100">
            <div class="d-flex flex-wrap align-items-start justify-content-between gap-2 mb-3">
              <div>
                <h6 class="mb-1">Partner sale limits</h6>
                <p class="text-muted fs-12 mb-0">Set default coverage for this partner. Values cannot exceed Central limits or allocated stock.</p>
              </div>
              <button class="btn btn-sm btn-light btn-wave" type="button" @click="resetLimitFormFromSummary">
                Load current
              </button>
            </div>
            <AdminApiState :error="limitError" />
            <div class="row g-3">
              <div v-for="field in limitFields" :key="field.key" class="col-md-4">
                <label class="form-label" :for="fieldId(`tenant-limit-${field.key}`)">{{ field.label }}</label>
                <div class="input-group">
                  <input
                    :id="fieldId(`tenant-limit-${field.key}`)"
                    v-model="limitForm[field.key]"
                    class="form-control"
                    :class="{ 'is-invalid': limitFieldMessages(field.key).length }"
                    type="number"
                    min="0"
                    step="1"
                    :max="centralCeiling(field.key) ?? undefined"
                  >
                  <span class="input-group-text">Max {{ formatLimit(centralCeiling(field.key)) }}</span>
                </div>
                <div v-for="message in limitFieldMessages(field.key)" :key="message" class="invalid-feedback d-block">
                  {{ message }}
                </div>
              </div>
            </div>
            <div class="d-flex justify-content-end mt-3">
              <button class="btn btn-primary btn-wave" type="button" :disabled="limitSaveDisabled" @click="saveLimitSettings">
                <span v-if="limitSaving" class="spinner-border spinner-border-sm me-2" />
                Save partner limits
              </button>
            </div>
          </div>
        </div>

        <div class="col-12 col-xl-6">
          <div class="border rounded p-3 h-100">
            <div class="d-flex flex-wrap align-items-start justify-content-between gap-2 mb-3">
              <div>
                <h6 class="mb-1">Pattern override</h6>
                <p class="text-muted fs-12 mb-0">
                  Tune one 2ท้าย, 3ท้าย, or 3หน้า pattern. Leave limit blank and save to remove its override.
                </p>
              </div>
              <button class="btn btn-sm btn-light btn-wave" type="button" @click="resetOverrideForm">
                Clear
              </button>
            </div>
            <AdminApiState :error="overrideError" />
            <div class="row g-3">
              <div class="col-md-4">
                <label class="form-label" for="tenant-stock-override-dimension">Pattern type</label>
                <select
                  id="tenant-stock-override-dimension"
                  v-model="filters.dimension"
                  class="form-select"
                  :disabled="!gameId"
                  @change="applyFilters"
                >
                  <option v-for="dimension in dimensionOptions" :key="dimension.value" :value="dimension.value">
                    {{ dimension.label }}
                  </option>
                </select>
                <div class="form-text">{{ activeDimensionDescription }}</div>
              </div>
              <div class="col-md-4">
                <label class="form-label" for="tenant-stock-override-value">Pattern value</label>
                <input
                  id="tenant-stock-override-value"
                  v-model="overrideForm.value"
                  class="form-control"
                  :maxlength="overrideValueLength"
                  inputmode="numeric"
                  :placeholder="activeDimensionExample"
                >
              </div>
              <div class="col-md-4">
                <label class="form-label" for="tenant-stock-override-limit">Override limit</label>
                <div class="input-group">
                  <input
                    id="tenant-stock-override-limit"
                    v-model="overrideForm.limit"
                    class="form-control"
                    :class="{ 'is-invalid': overrideMessages.length }"
                    type="number"
                    min="0"
                    step="1"
                    :max="overrideCentralCeiling ?? undefined"
                    placeholder="Blank removes override"
                  >
                  <span class="input-group-text">Max {{ formatLimit(overrideCentralCeiling) }}</span>
                </div>
                <div v-for="message in overrideMessages" :key="message" class="invalid-feedback d-block">
                  {{ message }}
                </div>
              </div>
            </div>
            <div class="d-flex justify-content-end mt-3">
              <button class="btn btn-primary btn-wave" type="button" :disabled="overrideSaveDisabled" @click="saveLimitOverride">
                <span v-if="overrideSaving" class="spinner-border spinner-border-sm me-2" />
                Save override
              </button>
            </div>
            <div v-if="overrideRows.length" class="table-responsive mt-3">
              <table class="table table-sm table-bordered text-nowrap w-100 mb-0">
                <thead>
                  <tr>
                    <th>Pattern</th>
                    <th>Limit</th>
                    <th>Updated</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="row in overrideRows" :key="row.value">
                    <td class="font-monospace">{{ row.value }}</td>
                    <td>{{ formatLimit(row.limit) }}</td>
                    <td>{{ row.updated_at ? formatDateTime(String(row.updated_at)) : '-' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
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
        <template #rowActions="{ row }">
          <button class="btn btn-sm btn-light btn-wave" type="button" @click="useRowForOverride(row)">
            Use override
          </button>
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
const limitSaving = ref(false)
const overrideSaving = ref(false)
const error = ref<any>(null)
const limitError = ref<any>(null)
const overrideError = ref<any>(null)
const rows = ref<any[]>([])
const summary = ref<any>(null)
const overridesDetail = ref<any>(null)
const filters = reactive({
  dimension: 'back2',
  q: '',
  limit: 20,
})
const limitForm = reactive<Record<string, any>>({
  back2_limit: '',
  back3_limit: '',
  front3_limit: '',
})
const overrideForm = reactive({
  value: '',
  limit: '',
})
const sortState = reactive<{ key: string, direction: 'asc' | 'desc' }>({ key: 'number', direction: 'asc' })
const meta = reactive({ next_cursor: null as string | null, has_more: false })
const pageState = reactive({ cursors: [null] as Array<string | null>, index: 0 })
let reloadTimer: ReturnType<typeof setTimeout> | null = null

type LoadOptions = {
  silent?: boolean
}

const columns = [
  { key: 'number', label: 'Pattern' },
  { key: 'generated_count', label: 'Generated', type: 'number' as const },
  { key: 'reserved_count', label: 'Reserved', type: 'number' as const },
  { key: 'sold_count', label: 'Sold', type: 'number' as const },
  { key: 'default_limit', label: 'Default', type: 'number' as const },
  { key: 'override_limit', label: 'Override', type: 'number' as const },
  { key: 'limit', label: 'Effective', type: 'number' as const },
  { key: 'central_limit', label: 'Central max', type: 'number' as const },
  { key: 'remaining_limit', label: 'Limit left', type: 'number' as const },
  { key: 'sellable_remaining_count', label: 'Sellable', type: 'number' as const },
  { key: 'status', label: 'Status', type: 'status' as const },
  { key: 'updated_at', label: 'Updated', type: 'datetime' as const },
  { key: 'limit_exceeds_supply', label: 'Ceiling' },
]
const limitFields = [
  { key: 'back2_limit', label: 'Back 2' },
  { key: 'back3_limit', label: 'Back 3' },
  { key: 'front3_limit', label: 'Front 3' },
] as const
const dimensionOptions = [
  { value: 'back2', label: '2 ท้าย', description: 'เลขท้าย 2 ตัว เช่น 00-99', example: '00' },
  { value: 'back3', label: '3 ท้าย', description: 'เลขท้าย 3 ตัว เช่น 000-999', example: '001' },
  { value: 'front3', label: '3 หน้า', description: 'เลขหน้า 3 ตัว เช่น 000-999', example: '001' },
] as const
const fallbackPartnerLimits = {
  back2_limit: 200,
  back3_limit: 100,
  front3_limit: 80,
}
const fallbackCentralLimits = {
  back2_limit: 500,
  back3_limit: 300,
  front3_limit: 200,
}

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
const effectiveLimits = computed(() => summary.value?.limits || fallbackPartnerLimits)
const centralLimits = computed(() => summary.value?.central_limits || fallbackCentralLimits)
const overrideValueLength = computed(() => filters.dimension === 'back2' ? 2 : 3)
const activeDimensionOption = computed(() => dimensionOptions.find((dimension) => dimension.value === filters.dimension) || dimensionOptions[0])
const activeDimensionDescription = computed(() => activeDimensionOption.value.description)
const activeDimensionExample = computed(() => activeDimensionOption.value.example)
const overrideRows = computed(() => normalizeOverrideRows(overridesDetail.value?.data || []))
const overrideCentralCeiling = computed(() => {
  const value = cleanedPatternValue(overrideForm.value)
  const currentRow = rows.value.find((row) => String(row?.number || '') === value)
  const field = `${filters.dimension}_limit`

  return numberOrNull(currentRow?.central_limit) ?? centralCeiling(field)
})
const limitClientMessages = computed(() => {
  const messages: Record<string, string[]> = {}
  for (const field of limitFields) {
    const limit = numberOrNull(limitForm[field.key])
    const ceiling = centralCeiling(field.key)
    if (limit !== null && ceiling !== null && limit > ceiling) {
      messages[field.key] = [`Partner value may not exceed Central max ${formatLimit(ceiling)}.`]
    }
  }

  return messages
})
const overrideClientMessages = computed(() => {
  const messages: string[] = []
  const limit = numberOrNull(overrideForm.limit)
  if (limit !== null && overrideCentralCeiling.value !== null && limit > overrideCentralCeiling.value) {
    messages.push(`Partner override may not exceed Central max ${formatLimit(overrideCentralCeiling.value)}.`)
  }

  return messages
})
const overrideMessages = computed(() => [...new Set([
  ...overrideClientMessages.value,
  ...backendFieldMessages(overrideError.value, 'overrides.0.limit'),
  ...backendFieldMessages(overrideError.value, 'limit'),
])])
const limitSaveDisabled = computed(() => Boolean(
  limitSaving.value
  || !props.gameId
  || Object.values(limitClientMessages.value).flat().length,
))
const overrideSaveDisabled = computed(() => Boolean(
  overrideSaving.value
  || !props.gameId
  || cleanedPatternValue(overrideForm.value).length !== overrideValueLength.value
  || overrideClientMessages.value.length,
))

watch(() => props.gameId, () => {
  resetPageState()
  resetOverrideForm()
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
  resetOverrideForm()
  void loadCoverage()
}

function applySort(next: { key: string, direction: 'asc' | 'desc' }) {
  sortState.key = next.key
  sortState.direction = next.direction
  resetPageState()
  void loadCoverage()
}

async function loadCoverage(cursor?: string | null, pageMode: 'reset' | 'next' | 'previous' | 'current' = 'reset', options: LoadOptions = {}) {
  if (!props.gameId || !session.isAuthenticated.value) {
    rows.value = []
    summary.value = null
    overridesDetail.value = null
    resetLimitForm()
    return
  }

  const shouldShowLoading = !options.silent
  if (shouldShowLoading) {
    loading.value = true
  }
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
    resetLimitFormFromSummary()
    await loadOverrides()
  } catch (err) {
    error.value = err
  } finally {
    if (shouldShowLoading) {
      loading.value = false
    }
  }
}

async function loadOverrides() {
  if (!props.gameId || !session.isAuthenticated.value) {
    overridesDetail.value = null
    return
  }

  try {
    const response = await api.apiFetch('/admin/tenant/stock/limit-overrides', {
      scope: 'tenant',
      tenantId: session.currentTenantId.value,
      query: cleanQuery({
        game_id: props.gameId,
        dimension: filters.dimension,
      }),
    })
    overridesDetail.value = response
  } catch {
    overridesDetail.value = null
  }
}

function resetLimitForm() {
  for (const field of limitFields) {
    limitForm[field.key] = fallbackPartnerLimits[field.key]
  }
  limitError.value = null
}

function resetLimitFormFromSummary() {
  const source = effectiveLimits.value || fallbackPartnerLimits
  for (const field of limitFields) {
    const value = numberOrNull(source?.[field.key])
    limitForm[field.key] = value === null ? fallbackPartnerLimits[field.key] : value
  }
  limitError.value = null
}

async function saveLimitSettings() {
  if (limitSaveDisabled.value) {
    return
  }

  limitSaving.value = true
  limitError.value = null
  try {
    await api.apiFetch('/admin/tenant/stock/limit-settings', {
      scope: 'tenant',
      tenantId: session.currentTenantId.value,
      method: 'PUT',
      idempotencyKey: api.idempotencyKey(),
      body: {
        game_id: props.gameId,
        back2_limit: numberOrNull(limitForm.back2_limit),
        back3_limit: numberOrNull(limitForm.back3_limit),
        front3_limit: numberOrNull(limitForm.front3_limit),
      },
    })
    await loadCoverage(pageState.cursors[pageState.index] || null, 'current', { silent: true })
  } catch (err) {
    limitError.value = err
  } finally {
    limitSaving.value = false
  }
}

function resetOverrideForm() {
  overrideForm.value = ''
  overrideForm.limit = ''
  overrideError.value = null
}

function useRowForOverride(row: any) {
  overrideForm.value = String(row?.number || '')
  overrideForm.limit = row?.override_limit ?? row?.limit ?? ''
  overrideError.value = null
}

async function saveLimitOverride() {
  if (overrideSaveDisabled.value) {
    return
  }

  overrideSaving.value = true
  overrideError.value = null
  try {
    await api.apiFetch('/admin/tenant/stock/limit-overrides', {
      scope: 'tenant',
      tenantId: session.currentTenantId.value,
      method: 'PUT',
      idempotencyKey: api.idempotencyKey(),
      body: {
        game_id: props.gameId,
        dimension: filters.dimension,
        overrides: [{
          value: cleanedPatternValue(overrideForm.value),
          limit: overrideForm.limit === '' ? null : numberOrNull(overrideForm.limit),
        }],
      },
    })
    resetOverrideForm()
    await loadCoverage(pageState.cursors[pageState.index] || null, 'current', { silent: true })
  } catch (err) {
    overrideError.value = err
  } finally {
    overrideSaving.value = false
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
    void loadCoverage(pageState.cursors[pageState.index] || null, 'current', { silent: true })
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
    __id: coverageRowId(row),
    generated_count: formatNumber(row.generated_count),
    reserved_count: formatNumber(row.reserved_count),
    sold_count: formatNumber(row.sold_count),
    remaining_limit: formatLimit(row.remaining_limit),
    sellable_remaining_count: formatNumber(row.sellable_remaining_count),
    updated_at: row.updated_at ? formatDateTime(String(row.updated_at)) : '-',
  }))
}

function coverageRowId(row: any) {
  return [
    row.game_id || props.gameId,
    row.scope_type || 'tenant',
    row.scope_id || session.currentTenantId.value || '',
    row.dimension || filters.dimension,
    row.number || '',
  ].map((value) => String(value ?? '').trim()).join(':')
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

function fieldId(value: string) {
  return `tenant-stock-coverage-${value}`
}

function centralCeiling(key: string) {
  return numberOrNull(centralLimits.value?.[key]) ?? numberOrNull(fallbackCentralLimits[key as keyof typeof fallbackCentralLimits])
}

function limitFieldMessages(key: string) {
  return [...new Set([
    ...(limitClientMessages.value[key] || []),
    ...backendFieldMessages(limitError.value, key),
  ])]
}

function backendFieldMessages(source: any, key: string) {
  const fields = source?.details?.fields
  if (!fields || typeof fields !== 'object') {
    return []
  }

  const value = fields[key]
  if (Array.isArray(value)) return value.map(String)
  return value ? [String(value)] : []
}

function cleanedPatternValue(value: any) {
  return String(value || '').replace(/\D+/g, '').slice(0, overrideValueLength.value)
}

function normalizeOverrideRows(source: any) {
  if (Array.isArray(source)) {
    return source
  }
  if (!source || typeof source !== 'object') {
    return []
  }

  return Object.entries(source).map(([value, row]) => ({
    value,
    ...(row && typeof row === 'object' ? row : { limit: row }),
  }))
}

function numberOrNull(value: any) {
  if (value === undefined || value === null || value === '') {
    return null
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : null
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

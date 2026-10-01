<template>
  <div class="np-stock-pattern-coverage">
    <div class="card custom-card">
      <div class="card-header d-flex flex-wrap align-items-start justify-content-between gap-2">
        <div>
          <div class="card-title mb-1">Stock Pattern Coverage</div>
          <p class="text-muted fs-12 mb-0">Central and partner limits for back/front number patterns.</p>
        </div>
        <div class="d-flex flex-wrap align-items-center gap-2">
          <span :class="['badge', realtimeBadge.className]" :title="realtimeBadge.title">
            <i :class="[realtimeBadge.icon, 'me-1']" />
            {{ realtimeBadge.label }}
          </span>
          <button class="btn btn-sm btn-light btn-wave" type="button" :disabled="loading" @click="reloadAll">
            <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
            <i v-else class="ri-refresh-line me-1" />
            Refresh
          </button>
        </div>
      </div>
      <div class="card-body">
        <AdminApiState :error="error" />
        <div class="row g-3">
          <div class="col-md-4">
            <label class="form-label" for="stock-pattern-game">Game</label>
            <select id="stock-pattern-game" v-model="filters.game_id" class="form-select">
              <option value="">Select game</option>
              <option v-for="game in gameOptions" :key="game.value" :value="game.value">{{ game.label }}</option>
            </select>
          </div>
          <div class="col-md-2">
            <label class="form-label" for="stock-pattern-dimension">Dimension</label>
            <select id="stock-pattern-dimension" v-model="filters.dimension" class="form-select" @change="handleDimensionChange">
              <option v-for="dimension in dimensionOptions" :key="dimension.value" :value="dimension.value">
                {{ dimension.label }}
              </option>
            </select>
          </div>
          <div class="col-md-3">
            <label class="form-label" for="stock-pattern-scope-type">Scope</label>
            <select id="stock-pattern-scope-type" v-model="filters.scope_type" class="form-select" @change="handleScopeChange">
              <option value="central">Central</option>
              <option value="partner">Partner</option>
            </select>
          </div>
          <div class="col-md-3">
            <label class="form-label" for="stock-pattern-scope-id">Scope ID</label>
            <input
              id="stock-pattern-scope-id"
              v-model="filters.scope_id"
              class="form-control"
              :disabled="filters.scope_type === 'central'"
              placeholder="Partner ID"
            >
          </div>
          <div class="col-md-4">
            <label class="form-label" for="stock-pattern-q">Pattern search</label>
            <input id="stock-pattern-q" v-model="filters.q" class="form-control" inputmode="numeric" placeholder="00, 001, 999">
          </div>
          <div class="col-md-2">
            <label class="form-label" for="stock-pattern-limit">Rows</label>
            <input id="stock-pattern-limit" v-model.number="filters.limit" class="form-control" type="number" min="1" max="100" step="1">
          </div>
          <div class="col-md-6 d-flex align-items-end justify-content-end gap-2">
            <button class="btn btn-light btn-wave" type="button" @click="resetFilters">Reset</button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="!filters.game_id" @click="applyFilters">
              Apply
            </button>
          </div>
        </div>
      </div>
    </div>

    <AdminApiState v-if="!filters.game_id" message="Select a game to load pattern coverage." />

    <div class="row g-3">
      <div class="col-12 col-xl-6">
        <div class="card custom-card">
          <div class="card-header">
            <div class="card-title">Default limits for selected scope</div>
          </div>
          <div class="card-body">
            <AdminApiState :error="limitError" />
            <div class="row g-3">
              <div v-for="field in limitFields" :key="field.key" class="col-md-4">
                <label class="form-label" :for="fieldId(`limit-${field.key}`)">{{ field.label }}</label>
                <div class="input-group">
                  <input
                    :id="fieldId(`limit-${field.key}`)"
                    v-model="limitForm[field.key]"
                    class="form-control"
                    :class="{ 'is-invalid': limitFieldMessages(field.key).length }"
                    type="number"
                    min="0"
                    step="1"
                    :max="filters.scope_type === 'partner' ? centralCeiling(field.key) ?? undefined : undefined"
                  >
                  <span v-if="filters.scope_type === 'partner'" class="input-group-text">Max {{ formatLimit(centralCeiling(field.key)) }}</span>
                </div>
                <div v-for="message in limitFieldMessages(field.key)" :key="message" class="invalid-feedback d-block">
                  {{ message }}
                </div>
              </div>
            </div>
          </div>
          <div class="card-footer d-flex flex-wrap justify-content-between gap-2">
            <button class="btn btn-light btn-wave" type="button" @click="resetLimitForm">Load defaults</button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="limitSaveDisabled" @click="saveLimitSettings">
              <span v-if="limitSaving" class="spinner-border spinner-border-sm me-2" />
              Save scope limits
            </button>
          </div>
        </div>
      </div>

      <div class="col-12 col-xl-6">
        <div class="card custom-card">
          <div class="card-header">
            <div class="card-title">Per-pattern override</div>
          </div>
          <div class="card-body">
            <AdminApiState :error="overrideError" />
            <div class="row g-3">
              <div class="col-md-4">
                <label class="form-label" for="stock-pattern-override-dimension">Pattern type</label>
                <select
                  id="stock-pattern-override-dimension"
                  v-model="filters.dimension"
                  class="form-select"
                  :disabled="!filters.game_id"
                  @change="handleDimensionChange"
                >
                  <option v-for="dimension in dimensionOptions" :key="dimension.value" :value="dimension.value">
                    {{ dimension.label }}
                  </option>
                </select>
                <div class="form-text">{{ activeDimensionDescription }}</div>
              </div>
              <div class="col-md-4">
                <label class="form-label" for="stock-pattern-override-value">Pattern value</label>
                <input
                  id="stock-pattern-override-value"
                  v-model="overrideForm.value"
                  class="form-control"
                  :maxlength="overrideValueLength"
                  inputmode="numeric"
                  :placeholder="activeDimensionExample"
                >
              </div>
              <div class="col-md-4">
                <label class="form-label" for="stock-pattern-override-limit">Override limit</label>
                <div class="input-group">
                  <input
                    id="stock-pattern-override-limit"
                    v-model="overrideForm.limit"
                    class="form-control"
                    :class="{ 'is-invalid': overrideMessages.length }"
                    type="number"
                    min="0"
                    step="1"
                    :max="filters.scope_type === 'partner' ? overrideCentralCeiling ?? undefined : undefined"
                    placeholder="Blank removes override"
                  >
                  <span v-if="filters.scope_type === 'partner'" class="input-group-text">Max {{ formatLimit(overrideCentralCeiling) }}</span>
                </div>
                <div v-for="message in overrideMessages" :key="message" class="invalid-feedback d-block">
                  {{ message }}
                </div>
              </div>
            </div>
            <div v-if="overrideRows.length" class="table-responsive mt-3">
              <table class="table table-bordered text-nowrap w-100 mb-0">
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
                    <td>{{ formatDateTime(row.updated_at) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          <div class="card-footer d-flex flex-wrap justify-content-between gap-2">
            <button class="btn btn-light btn-wave" type="button" @click="resetOverrideForm">Clear</button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="overrideSaveDisabled" @click="saveLimitOverride">
              <span v-if="overrideSaving" class="spinner-border spinner-border-sm me-2" />
              Save override
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="np-stock-pattern-coverage__metric-grid mb-3">
      <div v-for="metric in summaryMetrics" :key="metric.key">
        <span class="text-muted fs-12">{{ metric.label }}</span>
        <strong>{{ metric.value }}</strong>
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
      empty-title="No pattern rows"
      empty-message="No coverage rows matched the selected game, scope, or pattern search."
      @sort-change="applySort"
    >
      <template #cell-scope_type="{ row }">
        <AdminStatusBadge :status="row.scope_type" />
      </template>
      <template #cell-limit_exceeds_supply="{ row }">
        <AdminStatusBadge :status="row.limit_exceeds_supply ? 'warning' : 'ok'" :label="row.limit_exceeds_supply ? 'Exceeds supply' : 'OK'" />
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
</template>

<script setup lang="ts">
import { formatDateTime } from '~/utils/format'

const route = useRoute()
const api = useAdminApi()
const session = useAdminSession()
const loading = ref(false)
const limitSaving = ref(false)
const overrideSaving = ref(false)
const error = ref<any>(null)
const limitError = ref<any>(null)
const overrideError = ref<any>(null)
const rows = ref<any[]>([])
const settingsDetail = ref<any>(null)
const patternSummary = ref<any>(null)
const centralSummary = ref<any>(null)
const overridesDetail = ref<any>(null)
const gameOptions = ref<Array<{ value: string, label: string, status?: string }>>([])
const filters = reactive({
  game_id: '',
  dimension: 'back2',
  scope_type: 'central',
  scope_id: 'central',
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
let realtimeFallbackTimer: ReturnType<typeof setTimeout> | null = null
const columns = [
  { key: 'number', label: 'Pattern' },
  { key: 'scope_type', label: 'Scope', type: 'status' as const },
  { key: 'generated_count', label: 'Generated', type: 'number' as const },
  { key: 'reserved_count', label: 'Reserved', type: 'number' as const },
  { key: 'sold_count', label: 'Sold', type: 'number' as const },
  { key: 'default_limit', label: 'Default', type: 'number' as const },
  { key: 'override_limit', label: 'Override', type: 'number' as const },
  { key: 'limit', label: 'Effective', type: 'number' as const },
  { key: 'remaining_limit', label: 'Remaining limit', type: 'number' as const },
  { key: 'sellable_remaining_count', label: 'Sellable', type: 'number' as const },
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
const coverageDeltaFields = [
  'generated_count',
  'reserved_count',
  'sold_count',
  'default_limit',
  'override_limit',
  'limit',
  'remaining_limit',
  'sellable_remaining_count',
  'status',
]
const defaultCoverage = () => ({
  central: { back2_limit: 500, back3_limit: 300, front3_limit: 200 },
  partner: { back2_limit: 200, back3_limit: 100, front3_limit: 80 },
})

const coverageDefaults = computed(() => {
  const coverage = settingsDetail.value?.settings?.stock_pattern_coverage_default
    || settingsDetail.value?.stock_pattern_coverage_default
    || defaultCoverage()
  const defaults = defaultCoverage()

  return {
    central: {
      back2_limit: numericOrDefault(coverage?.central?.back2_limit, defaults.central.back2_limit),
      back3_limit: numericOrDefault(coverage?.central?.back3_limit, defaults.central.back3_limit),
      front3_limit: numericOrDefault(coverage?.central?.front3_limit, defaults.central.front3_limit),
    },
    partner: {
      back2_limit: numericOrDefault(coverage?.partner?.back2_limit, defaults.partner.back2_limit),
      back3_limit: numericOrDefault(coverage?.partner?.back3_limit, defaults.partner.back3_limit),
      front3_limit: numericOrDefault(coverage?.partner?.front3_limit, defaults.partner.front3_limit),
    },
  }
})
const activeDefaults = computed(() => filters.scope_type === 'partner' ? coverageDefaults.value.partner : coverageDefaults.value.central)
const effectiveLimits = computed(() => patternSummary.value?.limits || null)
const centralLimits = computed(() => centralSummary.value?.limits || coverageDefaults.value.central)
const overrideValueLength = computed(() => filters.dimension === 'back2' ? 2 : 3)
const activeDimensionOption = computed(() => dimensionOptions.find((dimension) => dimension.value === filters.dimension) || dimensionOptions[0])
const activeDimensionDescription = computed(() => activeDimensionOption.value.description)
const activeDimensionExample = computed(() => activeDimensionOption.value.example)
const overrideRows = computed(() => normalizeOverrideRows(overridesDetail.value?.data || []))
const overrideCentralCeiling = computed(() => {
  if (filters.scope_type !== 'partner') {
    return null
  }

  const field = `${filters.dimension}_limit`
  return numberOrNull(centralLimits.value?.[field]) ?? numberOrNull(coverageDefaults.value.central[field])
})
const limitClientMessages = computed(() => {
  if (filters.scope_type !== 'partner') {
    return {} as Record<string, string[]>
  }

  const messages: Record<string, string[]> = {}
  for (const field of limitFields) {
    const limit = numberOrNull(limitForm[field.key])
    const ceiling = centralCeiling(field.key)
    if (limit !== null && ceiling !== null && limit > ceiling) {
      messages[field.key] = [`Partner value may not exceed central ${formatLimit(ceiling)}.`]
    }
  }
  return messages
})
const overrideClientMessages = computed(() => {
  const messages: string[] = []
  const limit = numberOrNull(overrideForm.limit)
  if (filters.scope_type === 'partner' && limit !== null && overrideCentralCeiling.value !== null && limit > overrideCentralCeiling.value) {
    messages.push(`Partner override may not exceed central ${formatLimit(overrideCentralCeiling.value)}.`)
  }
  return [...new Set(messages)]
})
const overrideMessages = computed(() => [...new Set([
  ...overrideClientMessages.value,
  ...backendFieldMessages(overrideError.value, 'overrides.0.limit'),
  ...backendFieldMessages(overrideError.value, 'limit'),
])])
const limitSaveDisabled = computed(() => Boolean(
  limitSaving.value
  || !filters.game_id
  || (filters.scope_type === 'partner' && !normalizedScopeId.value)
  || Object.values(limitClientMessages.value).flat().length,
))
const overrideSaveDisabled = computed(() => Boolean(
  overrideSaving.value
  || !filters.game_id
  || (filters.scope_type === 'partner' && !normalizedScopeId.value)
  || cleanedPatternValue(overrideForm.value).length !== overrideValueLength.value
  || overrideClientMessages.value.length,
))
const normalizedScopeId = computed(() => filters.scope_type === 'partner' ? String(filters.scope_id || '').trim() : 'central')
const realtimeChannelName = computed(() => filters.game_id ? `private-admin.central.stock.coverage.game.${filters.game_id}` : '')
const realtimeEnabled = computed(() => Boolean(filters.game_id && session.isAuthenticated.value))
const realtime = useAdminRealtimeSubscription({
  channelName: realtimeChannelName,
  eventName: 'stock.coverage.updated',
  enabled: realtimeEnabled,
  onEvent: handleRealtimeCoverageEvent,
  onReconnect: () => scheduleCoverageFallbackReload(),
})
const realtimeBadge = computed(() => coverageRealtimeBadge(realtime.status.value, realtime.isConfigured.value))
const summaryMetrics = computed(() => {
  const totals = patternSummary.value?.totals?.[filters.dimension] || {}
  return [
    { key: 'patterns', label: 'Patterns', value: formatNumber(totals.pattern_count) },
    { key: 'generated', label: 'Generated', value: formatNumber(totals.generated_count) },
    { key: 'reserved', label: 'Reserved', value: formatNumber(totals.reserved_count) },
    { key: 'sold', label: 'Sold', value: formatNumber(totals.sold_count) },
    { key: 'limit_total', label: 'Limit total', value: formatLimit(totals.limit_total) },
    { key: 'sellable', label: 'Sellable', value: formatNumber(totals.sellable_remaining_count) },
  ]
})

onMounted(() => {
  void initialize()
})

onBeforeUnmount(() => {
  stopCoverageFallbackReload()
})

async function initialize() {
  await Promise.all([loadGames(), loadSettings()])
  applyRouteDefaults()
  applyCurrentGameDefault()
  resetLimitForm()
  if (filters.game_id) {
    await loadPatterns()
  }
}

function applyRouteDefaults() {
  const gameId = queryString(route.query.game_id)
  const scopeType = queryString(route.query.scope_type)
  const scopeId = queryString(route.query.scope_id)
  const dimension = queryString(route.query.dimension)
  const q = queryString(route.query.q)

  if (gameId) filters.game_id = gameId
  if (['central', 'partner'].includes(scopeType)) filters.scope_type = scopeType as 'central' | 'partner'
  if (scopeId) filters.scope_id = scopeId
  if (['back2', 'back3', 'front3'].includes(dimension)) filters.dimension = dimension
  if (q) filters.q = q
}

async function loadGames() {
  if (!session.isAuthenticated.value) {
    return
  }

  try {
    const response = await api.apiFetch('/admin/central/games', {
      scope: 'central',
      query: { limit: 100 },
    })
    gameOptions.value = extractItems(response).map((game: any) => {
      const id = String(game?.id || game?.game_id || game?.uuid || '')
      const code = game?.code && game.code !== game?.name ? ` (${game.code})` : ''
      const status = String(game?.status || '').toLowerCase()
      return {
        value: id,
        label: `${game?.name || game?.code || id}${code}${status === 'open' ? ' (Current)' : ''}`,
        status,
      }
    }).filter((game) => game.value)
  } catch {
    gameOptions.value = []
  }
}

async function loadSettings() {
  if (!session.isAuthenticated.value) {
    return
  }

  try {
    const response = await api.apiFetch('/admin/central/stock/settings', { scope: 'central' })
    settingsDetail.value = extractData(response)
  } catch {
    settingsDetail.value = null
  }
}

function applyCurrentGameDefault() {
  if (filters.game_id) {
    return
  }
  const current = gameOptions.value.filter((game) => game.status === 'open')
  if (current.length === 1) {
    filters.game_id = current[0].value
  }
}

function handleScopeChange() {
  filters.scope_id = filters.scope_type === 'partner' ? '' : 'central'
  resetLimitForm()
}

function handleDimensionChange() {
  resetOverrideForm()
  resetPageState()
  if (filters.game_id) {
    void loadPatterns()
  }
}

function resetFilters() {
  filters.dimension = 'back2'
  filters.scope_type = 'central'
  filters.scope_id = 'central'
  filters.q = ''
  filters.limit = 20
  sortState.key = 'number'
  sortState.direction = 'asc'
  applyCurrentGameDefault()
  resetLimitForm()
  void loadPatterns()
}

function applyFilters() {
  resetPageState()
  void loadPatterns()
}

function reloadAll() {
  void loadSettings().then(() => loadPatterns())
}

async function loadPatterns(cursor?: string | null, pageMode: 'reset' | 'next' | 'previous' | 'current' = 'reset') {
  if (!session.isAuthenticated.value || !filters.game_id) {
    rows.value = []
    patternSummary.value = null
    resetLimitForm()
    return
  }

  loading.value = true
  error.value = null
  try {
    const query = cleanQuery({
      game_id: filters.game_id,
      dimension: filters.dimension,
      scope_type: filters.scope_type,
      scope_id: normalizedScopeId.value,
      q: filters.q,
      cursor: cursor || undefined,
      limit: filters.limit || 20,
      sort_by: sortState.key,
      sort_dir: sortState.direction,
    })
    const response = await api.apiFetch('/admin/central/stock/patterns', { scope: 'central', query })
    patternSummary.value = extractData(response)
    rows.value = extractItems(response)
    const nextMeta = extractMeta(response)
    meta.next_cursor = nextMeta.next_cursor || null
    meta.has_more = Boolean(nextMeta.has_more || nextMeta.next_cursor)
    updatePageState(cursor || null, pageMode)
    resetLimitFormFromSummary()
    await Promise.all([loadCentralSummary(), loadOverrides()])
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

async function loadCentralSummary() {
  if (!filters.game_id) {
    centralSummary.value = null
    return
  }

  try {
    const response = await api.apiFetch('/admin/central/stock/patterns', {
      scope: 'central',
      query: cleanQuery({
        game_id: filters.game_id,
        dimension: filters.dimension,
        scope_type: 'central',
        scope_id: 'central',
        q: filters.q || cleanedPatternValue(overrideForm.value),
        limit: 100,
        sort_by: 'number',
        sort_dir: 'asc',
      }),
    })
    centralSummary.value = extractData(response)
  } catch {
    centralSummary.value = null
  }
}

async function loadOverrides() {
  if (!filters.game_id) {
    overridesDetail.value = null
    return
  }

  try {
    const response = await api.apiFetch('/admin/central/stock/limit-overrides', {
      scope: 'central',
      query: cleanQuery({
        game_id: filters.game_id,
        dimension: filters.dimension,
        scope_type: filters.scope_type,
        scope_id: normalizedScopeId.value,
      }),
    })
    overridesDetail.value = response
  } catch {
    overridesDetail.value = null
  }
}

function resetLimitForm() {
  for (const field of limitFields) {
    limitForm[field.key] = activeDefaults.value[field.key]
  }
  limitError.value = null
}

function resetLimitFormFromSummary() {
  const source = effectiveLimits.value || activeDefaults.value
  for (const field of limitFields) {
    const value = numberOrNull(source?.[field.key])
    limitForm[field.key] = value === null ? activeDefaults.value[field.key] : value
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
    const response = await api.apiFetch('/admin/central/stock/limit-settings', {
      scope: 'central',
      method: 'PUT',
      idempotencyKey: api.idempotencyKey(),
      body: {
        game_id: filters.game_id,
        scope_type: filters.scope_type,
        scope_id: normalizedScopeId.value,
        back2_limit: numberOrNull(limitForm.back2_limit),
        back3_limit: numberOrNull(limitForm.back3_limit),
        front3_limit: numberOrNull(limitForm.front3_limit),
      },
    })
    patternSummary.value = extractData(response)
    rows.value = extractItems(response)
    resetLimitFormFromSummary()
    await Promise.all([loadCentralSummary(), loadOverrides()])
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
  void loadCentralSummary()
}

async function saveLimitOverride() {
  if (overrideSaveDisabled.value) {
    return
  }

  overrideSaving.value = true
  overrideError.value = null
  try {
    const response = await api.apiFetch('/admin/central/stock/limit-overrides', {
      scope: 'central',
      method: 'PUT',
      idempotencyKey: api.idempotencyKey(),
      body: {
        game_id: filters.game_id,
        scope_type: filters.scope_type,
        scope_id: normalizedScopeId.value,
        dimension: filters.dimension,
        overrides: [{
          value: cleanedPatternValue(overrideForm.value),
          limit: overrideForm.limit === '' ? null : numberOrNull(overrideForm.limit),
        }],
      },
    })
    patternSummary.value = extractData(response)
    rows.value = extractItems(response)
    resetOverrideForm()
    await Promise.all([loadCentralSummary(), loadOverrides()])
  } catch (err) {
    overrideError.value = err
  } finally {
    overrideSaving.value = false
  }
}

function handleRealtimeCoverageEvent(payload: any) {
  const delta = normalizeCoverageDelta(payload)
  if (!delta.game_id || String(delta.game_id) !== String(filters.game_id || '')) {
    return
  }

  if (coverageDeltaIncomplete(delta)) {
    scheduleCoverageFallbackReload()
    return
  }

  if (!deltaMatchesActiveFilters(delta)) {
    return
  }

  if (!applyCoverageDelta(delta)) {
    scheduleCoverageFallbackReload()
  }
}

function normalizeCoverageDelta(payload: any) {
  const source = parseRealtimeData(payload?.coverage || payload?.delta || payload?.data || payload || {})
  const scopeType = String(source?.scope_type || filters.scope_type || 'central').toLowerCase()
  return {
    ...source,
    game_id: String(source?.game_id || ''),
    scope_type: scopeType,
    scope_id: String(source?.scope_id || (scopeType === 'central' ? 'central' : '')),
    dimension: String(source?.dimension || ''),
    number: String(source?.number ?? source?.value ?? source?.pattern ?? ''),
  }
}

function coverageDeltaIncomplete(delta: Record<string, any>) {
  return !delta.game_id
    || !delta.dimension
    || !delta.number
    || !delta.scope_type
    || !delta.scope_id
    || coverageDeltaFields.some((field) => !hasOwn(delta, field))
}

function deltaMatchesActiveFilters(delta: Record<string, any>) {
  if (String(delta.dimension) !== String(filters.dimension)) {
    return false
  }
  if (String(delta.scope_type) !== String(filters.scope_type)) {
    return false
  }
  if (String(delta.scope_id || '') !== String(normalizedScopeId.value || '')) {
    return false
  }

  const query = String(filters.q || '').replace(/\D+/g, '')
  return !query || String(delta.number).includes(query)
}

function applyCoverageDelta(delta: Record<string, any>) {
  const index = rows.value.findIndex((row) => String(row?.number) === String(delta.number))
  if (index < 0) {
    return false
  }

  const previous = rows.value[index]
  const nextRow = {
    ...previous,
    ...Object.fromEntries(coverageDeltaFields.map((field) => [field, delta[field]])),
    game_id: delta.game_id,
    scope_type: delta.scope_type,
    scope_id: delta.scope_id,
    dimension: delta.dimension,
    number: delta.number,
  }
  rows.value = [
    ...rows.value.slice(0, index),
    nextRow,
    ...rows.value.slice(index + 1),
  ]
  applyCoverageTotalsDelta(previous, nextRow)
  updateLimitSummaryFromDelta(nextRow)
  updateOverrideRowsFromDelta(nextRow)
  return true
}

function applyCoverageTotalsDelta(previous: Record<string, any>, nextRow: Record<string, any>) {
  const summary = patternSummary.value
  const totals = summary?.totals?.[filters.dimension]
  if (!totals || typeof totals !== 'object') {
    return
  }

  const mappings = [
    ['generated_count', 'generated_count'],
    ['reserved_count', 'reserved_count'],
    ['sold_count', 'sold_count'],
    ['limit', 'limit_total'],
    ['sellable_remaining_count', 'sellable_remaining_count'],
  ] as const
  const nextTotals = { ...totals }
  let changed = false

  for (const [rowField, totalField] of mappings) {
    const before = numberOrNull(previous?.[rowField])
    const after = numberOrNull(nextRow?.[rowField])
    const total = numberOrNull(nextTotals?.[totalField])
    if (before === null || after === null || total === null) {
      continue
    }
    nextTotals[totalField] = Math.max(0, total + after - before)
    changed = true
  }

  if (changed) {
    patternSummary.value = {
      ...summary,
      totals: {
        ...(summary?.totals || {}),
        [filters.dimension]: nextTotals,
      },
    }
  }
}

function updateLimitSummaryFromDelta(row: Record<string, any>) {
  const field = `${row.dimension}_limit`
  if (!hasOwn(limitForm, field) || !hasOwn(row, 'default_limit')) {
    return
  }

  const defaultLimit = numberOrNull(row.default_limit)
  if (defaultLimit === null) {
    return
  }

  const summary = patternSummary.value || {}
  patternSummary.value = {
    ...summary,
    limits: {
      ...(summary.limits || {}),
      [field]: defaultLimit,
    },
  }
  if (!limitSaving.value) {
    limitForm[field] = defaultLimit
  }
}

function updateOverrideRowsFromDelta(row: Record<string, any>) {
  if (!hasOwn(row, 'override_limit') || !overridesDetail.value) {
    return
  }

  const value = String(row.number)
  const limit = row.override_limit
  if (Array.isArray(overridesDetail.value?.data)) {
    const nextRows = overridesDetail.value.data.filter((entry: any) => String(entry?.value) !== value)
    if (limit !== null && limit !== undefined && limit !== '') {
      nextRows.unshift({ value, limit, updated_at: new Date().toISOString() })
    }
    overridesDetail.value = { ...overridesDetail.value, data: nextRows }
    return
  }

  if (overridesDetail.value?.data && typeof overridesDetail.value.data === 'object') {
    const nextData = { ...overridesDetail.value.data }
    if (limit === null || limit === undefined || limit === '') {
      delete nextData[value]
    } else {
      nextData[value] = { ...(nextData[value] || {}), value, limit, updated_at: new Date().toISOString() }
    }
    overridesDetail.value = { ...overridesDetail.value, data: nextData }
  }
}

function scheduleCoverageFallbackReload() {
  if (!import.meta.client || realtimeFallbackTimer !== null || !filters.game_id) {
    return
  }

  realtimeFallbackTimer = window.setTimeout(() => {
    realtimeFallbackTimer = null
    void loadPatterns(pageState.cursors[pageState.index] || null, 'current')
  }, 1200)
}

function stopCoverageFallbackReload() {
  if (!import.meta.client || realtimeFallbackTimer === null) {
    return
  }

  window.clearTimeout(realtimeFallbackTimer)
  realtimeFallbackTimer = null
}

function applySort(next: { key: string, direction: 'asc' | 'desc' }) {
  sortState.key = next.key
  sortState.direction = next.direction
  resetPageState()
  void loadPatterns()
}

function loadNextPage() {
  if (!meta.next_cursor) return
  void loadPatterns(meta.next_cursor, 'next')
}

function loadPreviousPage() {
  if (pageState.index <= 0) return
  void loadPatterns(pageState.cursors[pageState.index - 1] || null, 'previous')
}

function resetPageState() {
  pageState.cursors = [null]
  pageState.index = 0
  meta.next_cursor = null
  meta.has_more = false
}

function updatePageState(cursor: string | null, mode: 'reset' | 'next' | 'previous' | 'current') {
  if (mode === 'current') {
    pageState.cursors[pageState.index] = cursor
    return
  }
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
  pageState.index = Math.max(0, pageState.index - 1)
}

function centralCeiling(key: string) {
  return numberOrNull(centralLimits.value?.[key]) ?? numberOrNull(coverageDefaults.value.central[key])
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

function parseRealtimeData(source: any) {
  if (typeof source !== 'string') {
    return source && typeof source === 'object' ? source : {}
  }

  try {
    const parsed = JSON.parse(source)
    return parsed && typeof parsed === 'object' ? parsed : {}
  } catch {
    return {}
  }
}

function hasOwn(source: Record<string, any>, key: string) {
  return Object.prototype.hasOwnProperty.call(source, key)
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

function numericOrDefault(value: any, fallback: number) {
  return numberOrNull(value) ?? fallback
}

function formatNumber(value: any) {
  const parsed = numberOrNull(value)
  return parsed === null ? '-' : new Intl.NumberFormat('th-TH', { maximumFractionDigits: 0 }).format(parsed)
}

function formatLimit(value: any) {
  const parsed = numberOrNull(value)
  return parsed === null ? 'Unlimited' : formatNumber(parsed)
}

function queryString(value: unknown) {
  if (Array.isArray(value)) {
    return String(value[0] || '').trim()
  }
  return String(value || '').trim()
}

function cleanQuery(value: Record<string, any>) {
  return Object.fromEntries(Object.entries(value).filter(([, entry]) => entry !== '' && entry !== undefined && entry !== null))
}

function extractData(response: any) {
  return response?.data && !Array.isArray(response.data) ? response.data : response
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

function coverageRealtimeBadge(status: string, configured: boolean) {
  if (status === 'connected') {
    return {
      label: 'Realtime',
      icon: 'ri-broadcast-line',
      className: 'bg-success-transparent text-success',
      title: 'Stock coverage websocket is connected.',
    }
  }

  if (['connecting', 'authenticating', 'reconnecting'].includes(status)) {
    return {
      label: 'Connecting realtime',
      icon: 'ri-loader-4-line',
      className: 'bg-warning-transparent text-warning',
      title: 'Stock coverage websocket is connecting.',
    }
  }

  if (!configured || status === 'unavailable' || status === 'error') {
    return {
      label: 'HTTP fallback',
      icon: 'ri-refresh-line',
      className: 'bg-secondary-transparent text-secondary',
      title: 'Coverage reloads from HTTP when realtime is unavailable.',
    }
  }

  return {
    label: 'Realtime idle',
    icon: 'ri-broadcast-line',
    className: 'bg-secondary-transparent text-secondary',
    title: 'Select a game to subscribe to stock coverage updates.',
  }
}

function fieldId(key: string) {
  return `stock-pattern-${key.replace(/[^a-z0-9_-]/gi, '-')}`
}
</script>

<style scoped>
.np-stock-pattern-coverage__metric-grid {
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(auto-fit, minmax(8rem, 1fr));
}

.np-stock-pattern-coverage__metric-grid > div {
  background: var(--custom-white);
  border: 1px solid var(--default-border);
  border-radius: 4px;
  display: grid;
  gap: .25rem;
  padding: .65rem .75rem;
}
</style>

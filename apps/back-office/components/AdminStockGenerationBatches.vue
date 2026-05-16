<template>
  <div class="card custom-card np-stock-generation-batches">
    <div class="card-header d-flex flex-wrap align-items-start justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Generation progress</div>
        <p class="text-muted fs-12 mb-0">Queued, processing, completed, and failed stock generation batches for the selected game.</p>
      </div>
      <div class="d-flex flex-wrap align-items-center gap-2">
        <span :class="['badge', realtimeBadge.className]">
          <i :class="[realtimeBadge.icon, 'me-1']" />
          {{ realtimeBadge.label }}
        </span>
        <button class="btn btn-sm btn-light btn-wave" type="button" :disabled="loading || !normalizedGameId" @click="manualRefresh">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </div>
    </div>

    <div class="card-body">
      <AdminApiState v-if="!normalizedGameId" message="Select a current game to load stock generation batch progress." />
      <template v-else>
        <AdminApiState :error="error" />
        <AdminLoader v-if="loading && !batches.length" />
        <AdminEmptyState
          v-else-if="!batches.length"
          title="No generation batches"
          message="Submitted stock generation batches for this game will appear here."
          icon="ri-stack-line"
        />
        <div v-else class="row g-3">
          <div class="col-12 col-xl-5">
            <div class="np-stock-generation-batches__list">
              <button
                v-for="batch in batches"
                :key="batch.id"
                type="button"
                :class="['np-stock-generation-batches__item', { active: batch.id === selectedBatchId }]"
                @click="selectBatch(batch.id)"
              >
                <span class="d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <span class="fw-semibold text-break">{{ batch.id }}</span>
                  <AdminStatusBadge :status="batch.status" />
                </span>
                <span class="d-flex flex-wrap align-items-center justify-content-between gap-2 text-muted fs-12 mt-2">
                  <span>{{ formatNumber(batch.generated_count) }} / {{ formatNumber(batch.requested_count) }} tickets</span>
                  <span>{{ progressPercent(batch) }}%</span>
                </span>
                <span class="progress np-stock-generation-batches__bar mt-2" aria-hidden="true">
                  <span class="progress-bar" :style="{ width: `${progressPercent(batch)}%` }" />
                </span>
              </button>
            </div>
          </div>

          <div class="col-12 col-xl-7">
            <AdminLoader v-if="detailLoading && !selectedBatch" />
            <AdminEmptyState
              v-else-if="!selectedBatch"
              title="No batch selected"
              message="Select a generation batch to inspect progress."
              icon="ri-search-line"
            />
            <section v-else class="np-stock-generation-batches__detail">
              <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-3">
                <div>
                  <h6 class="mb-1">Batch {{ selectedBatch.id }}</h6>
                  <div class="text-muted fs-12">Game {{ selectedBatch.game_id || normalizedGameId }}</div>
                </div>
                <div class="d-flex flex-wrap gap-2">
                  <AdminStatusBadge :status="selectedBatch.status" />
                  <span :class="['badge', imageState.className]">{{ imageState.label }}</span>
                </div>
              </div>

              <div class="np-stock-generation-batches__metric-grid">
                <div>
                  <span class="text-muted fs-12">Requested</span>
                  <strong>{{ formatNumber(selectedBatch.requested_count) }}</strong>
                </div>
                <div>
                  <span class="text-muted fs-12">Generated</span>
                  <strong>{{ formatNumber(selectedBatch.generated_count) }}</strong>
                </div>
                <div>
                  <span class="text-muted fs-12">Rounds</span>
                  <strong>{{ formatNumber(selectedBatch.processed_rounds) }} / {{ formatNumber(selectedBatch.total_rounds) }}</strong>
                </div>
                <div>
                  <span class="text-muted fs-12">Chunk rounds</span>
                  <strong>{{ formatNumber(selectedBatch.chunk_rounds) }}</strong>
                </div>
              </div>

              <div class="mt-3">
                <div class="d-flex align-items-center justify-content-between gap-2 fs-12 mb-1">
                  <span class="text-muted">Stock row progress</span>
                  <strong>{{ progressPercent(selectedBatch) }}%</strong>
                </div>
                <div class="progress np-stock-generation-batches__detail-bar">
                  <div class="progress-bar" :style="{ width: `${progressPercent(selectedBatch)}%` }" />
                </div>
              </div>

              <div v-if="selectedBatch.failure_reason" class="alert alert-danger d-flex align-items-start gap-2 mt-3 mb-0">
                <i class="ri-error-warning-line fs-18" />
                <div>
                  <div class="fw-semibold">Generation failed</div>
                  <div class="text-break">{{ selectedBatch.failure_reason }}</div>
                </div>
              </div>

              <div v-if="detailRows.length" class="table-responsive mt-3">
                <table class="table table-bordered text-nowrap w-100 mb-0">
                  <thead>
                    <tr>
                      <th>Chunk</th>
                      <th>Status</th>
                      <th>Rounds</th>
                      <th>Attempts</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="chunk in detailRows" :key="chunk.id">
                      <td>{{ chunk.chunk_index + 1 }}</td>
                      <td><AdminStatusBadge :status="chunk.status" /></td>
                      <td>{{ formatNumber(chunk.round_count) }}</td>
                      <td>{{ formatNumber(chunk.attempt_count) }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { titleize } from '~/utils/format'

type StockGenerationBatchChunk = {
  id: string
  chunk_index: number
  round_count: number
  status: string
  attempt_count: number
  failure_reason?: string | null
}

type StockGenerationBatch = {
  id: string
  status: string
  game_id?: string | null
  requested_count?: number
  generated_count?: number
  total_rounds?: number
  processed_rounds?: number
  chunk_rounds?: number
  failure_reason?: string | null
  chunks?: StockGenerationBatchChunk[]
  [key: string]: any
}

const props = withDefaults(defineProps<{
  gameId?: string | number | null
  submittedBatch?: StockGenerationBatch | null
  refreshKey?: number
  fallbackPollIntervalMs?: number
}>(), {
  gameId: '',
  submittedBatch: null,
  refreshKey: 0,
  fallbackPollIntervalMs: 30000,
})

const emit = defineEmits<{
  'active-change': [active: boolean]
  progress: [batch: StockGenerationBatch | null]
}>()

const api = useAdminApi()
const session = useAdminSession()
const loading = ref(false)
const detailLoading = ref(false)
const error = ref<any>(null)
const batches = ref<StockGenerationBatch[]>([])
const batchDetail = ref<StockGenerationBatch | null>(null)
const selectedBatchId = ref('')
const requestSerial = ref(0)
const lastProgressKey = ref('')
let fallbackPollTimer: ReturnType<typeof setTimeout> | null = null

const normalizedGameId = computed(() => String(props.gameId ?? '').trim())
const realtimeChannelName = computed(() => normalizedGameId.value ? `private-admin.central.stock-generation.game.${normalizedGameId.value}` : '')
const realtimeEnabled = computed(() => Boolean(normalizedGameId.value && session.isAuthenticated.value))
const selectedBatch = computed(() => batchDetail.value || batches.value.find((batch) => batch.id === selectedBatchId.value) || null)
const activeBatch = computed(() => selectedBatch.value && isActiveBatch(selectedBatch.value)
  ? selectedBatch.value
  : batches.value.find(isActiveBatch) || null)
const detailRows = computed(() => selectedBatch.value?.chunks || [])
const imageState = computed(() => imageDispatchState(selectedBatch.value))
const fallbackPollIntervalMs = computed(() => Math.max(30000, Number(props.fallbackPollIntervalMs || 60000)))
const realtime = useAdminRealtimeSubscription({
  channelName: realtimeChannelName,
  eventName: 'stock.generation.progress.updated',
  enabled: realtimeEnabled,
  onEvent: handleRealtimeProgressEvent,
  onReconnect: handleRealtimeReconnect,
})
const realtimeStatus = computed(() => realtime.status.value)
const realtimeSupportsPush = computed(() => realtimeStatus.value === 'connected')
const shouldUseFallbackPolling = computed(() => Boolean(activeBatch.value && !realtimeSupportsPush.value))
const realtimeBadge = computed(() => realtimeConnectionBadge(realtimeStatus.value, realtime.isConfigured.value, fallbackPollIntervalMs.value))

watch(
  () => [normalizedGameId.value, props.refreshKey, session.isAuthenticated.value],
  () => {
    void loadBatches()
  },
  { immediate: true },
)

watch(
  () => props.submittedBatch,
  (batch) => {
    if (!batch?.id) {
      return
    }
    registerBatch(batch)
    void loadBatchDetail(batch.id)
  },
  { deep: true },
)

watch(
  () => [shouldUseFallbackPolling.value, fallbackPollIntervalMs.value, realtimeStatus.value],
  () => {
    updateFallbackPolling()
  },
)

onBeforeUnmount(() => {
  stopFallbackPolling()
})

function manualRefresh() {
  void loadBatches()
}

async function loadBatches() {
  if (!import.meta.client) {
    return
  }

  if (loading.value) {
    return
  }

  error.value = null

  if (!normalizedGameId.value || !session.isAuthenticated.value) {
    batches.value = []
    batchDetail.value = null
    selectedBatchId.value = ''
    updateActiveState()
    stopFallbackPolling()
    return
  }

  const serial = requestSerial.value + 1
  requestSerial.value = serial
  loading.value = true
  try {
    const response = await api.apiFetch('/admin/central/stock/generation-batches', {
      scope: 'central',
      query: {
        game_id: normalizedGameId.value,
        limit: 10,
      },
    })
    if (requestSerial.value !== serial) {
      return
    }

    batches.value = extractItems(response).map(normalizeBatch).filter((batch) => batch.id)
    const nextSelected = activeBatch.value?.id
      || (selectedBatchId.value && batches.value.some((batch) => batch.id === selectedBatchId.value) ? selectedBatchId.value : '')
      || batches.value[0]?.id
      || ''
    selectedBatchId.value = nextSelected

    if (nextSelected) {
      await loadBatchDetail(nextSelected, serial)
    } else {
      batchDetail.value = null
    }

    updateActiveState()
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

async function loadBatchDetail(batchId: string, serial = requestSerial.value) {
  if (!batchId || !session.isAuthenticated.value) {
    return
  }

  detailLoading.value = true
  try {
    const response = await api.apiFetch(`/admin/central/stock/generation-batches/${encodeURIComponent(batchId)}`, {
      scope: 'central',
    })
    if (serial !== requestSerial.value && serial !== 0) {
      return
    }

    registerBatch(normalizeBatch(extractData(response)), false)
  } catch (err) {
    error.value = err
  } finally {
    detailLoading.value = false
  }
}

function selectBatch(batchId: string) {
  selectedBatchId.value = batchId
  batchDetail.value = null
  void loadBatchDetail(batchId)
}

function registerBatch(batch: StockGenerationBatch, select = true) {
  const normalized = normalizeBatch(batch)
  if (!normalized.id) {
    return
  }

  const existingIndex = batches.value.findIndex((entry) => entry.id === normalized.id)
  if (existingIndex >= 0) {
    const existing = batches.value[existingIndex]
    batches.value[existingIndex] = {
      ...existing,
      ...normalized,
      chunks: normalized.chunks ?? existing.chunks,
    }
  } else {
    batches.value = [normalized, ...batches.value]
  }

  if (select) {
    selectedBatchId.value = normalized.id
  }
  if (selectedBatchId.value === normalized.id) {
    batchDetail.value = {
      ...(batchDetail.value || {}),
      ...normalized,
      chunks: normalized.chunks ?? batchDetail.value?.chunks,
    }
  }

  updateActiveState()
}

function updateActiveState() {
  const current = activeBatch.value
  emit('active-change', Boolean(current))

  const progressBatch = selectedBatch.value || current
  const progressKey = progressBatch
    ? [
        progressBatch.id,
        progressBatch.status,
        progressBatch.generated_count,
        progressBatch.requested_count,
        progressBatch.processed_rounds,
        progressBatch.failure_reason,
        progressBatch.image_dispatch_status,
      ].join(':')
    : ''

  if (progressKey !== lastProgressKey.value) {
    lastProgressKey.value = progressKey
    emit('progress', progressBatch || null)
  }

  updateFallbackPolling()
}

function updateFallbackPolling() {
  if (shouldUseFallbackPolling.value) {
    startFallbackPolling()
  } else {
    stopFallbackPolling()
  }
}

function startFallbackPolling() {
  if (!import.meta.client || fallbackPollTimer !== null) {
    return
  }

  fallbackPollTimer = window.setTimeout(() => {
    fallbackPollTimer = null
    if (!shouldUseFallbackPolling.value) {
      return
    }

    void loadBatches().finally(() => {
      updateFallbackPolling()
    })
  }, fallbackPollIntervalMs.value)
}

function stopFallbackPolling() {
  if (fallbackPollTimer === null || !import.meta.client) {
    return
  }

  window.clearTimeout(fallbackPollTimer)
  fallbackPollTimer = null
}

function isActiveBatch(batch: StockGenerationBatch | null | undefined) {
  return ['queued', 'pending', 'processing'].includes(String(batch?.status || '').toLowerCase())
}

function handleRealtimeProgressEvent(payload: any) {
  const batch = realtimePayloadToBatch(payload)
  if (!batch.id || String(batch.game_id || '') !== normalizedGameId.value) {
    return
  }

  registerBatch(batch, !selectedBatchId.value || selectedBatchId.value === batch.id || isActiveBatch(batch))
}

function handleRealtimeReconnect() {
  void loadBatches()
}

function realtimePayloadToBatch(payload: any): StockGenerationBatch {
  const source = payload?.batch || payload?.data || payload || {}
  return normalizeBatch({
    ...source,
    id: source.id || source.batch_id,
    image_dispatch_status: source.image_dispatch_status,
  })
}

function normalizeBatch(batch: any): StockGenerationBatch {
  return {
    ...batch,
    id: String(batch?.id || ''),
    status: String(batch?.status || 'unknown'),
    game_id: batch?.game_id ?? null,
    requested_count: numberValue(batch?.requested_count),
    generated_count: numberValue(batch?.generated_count),
    total_rounds: numberValue(batch?.total_rounds),
    processed_rounds: numberValue(batch?.processed_rounds),
    chunk_rounds: numberValue(batch?.chunk_rounds),
    failure_reason: batch?.failure_reason ?? null,
    chunks: Array.isArray(batch?.chunks) ? batch.chunks.map(normalizeChunk) : undefined,
  }
}

function normalizeChunk(chunk: any): StockGenerationBatchChunk {
  return {
    ...chunk,
    id: String(chunk?.id || ''),
    chunk_index: numberValue(chunk?.chunk_index),
    round_count: numberValue(chunk?.round_count),
    status: String(chunk?.status || 'unknown'),
    attempt_count: numberValue(chunk?.attempt_count),
    failure_reason: chunk?.failure_reason ?? null,
  }
}

function imageDispatchState(batch: StockGenerationBatch | null) {
  const reported = firstText([
    batch?.image_generation_status,
    batch?.image_status,
    batch?.image_dispatch_status,
    batch?.lottery_image_status,
  ])

  if (reported) {
    return {
      label: `Images ${titleize(reported)}`,
      className: statusClass(reported),
    }
  }

  if (!batch || !['completed', 'failed', 'cancelled'].includes(String(batch.status).toLowerCase())) {
    return {
      label: 'Images waiting for stock',
      className: 'bg-warning-transparent text-warning',
    }
  }

  if (String(batch.status).toLowerCase() === 'completed') {
    return {
      label: 'Images not reported by batch API',
      className: 'bg-secondary-transparent text-secondary',
    }
  }

  return {
    label: 'Images not started',
    className: 'bg-secondary-transparent text-secondary',
  }
}

function statusClass(status: string) {
  const value = String(status).toLowerCase()
  if (['completed', 'complete', 'generated', 'success'].includes(value)) return 'bg-success-transparent text-success'
  if (['queued', 'pending', 'processing', 'dispatching'].includes(value)) return 'bg-warning-transparent text-warning'
  if (['failed', 'error'].includes(value)) return 'bg-danger-transparent text-danger'
  return 'bg-secondary-transparent text-secondary'
}

function realtimeConnectionBadge(status: string, configured: boolean, fallbackMs: number) {
  if (status === 'connected') {
    return {
      label: 'Realtime',
      icon: 'ri-broadcast-line',
      className: 'bg-success-transparent text-success',
    }
  }

  if (['connecting', 'authenticating', 'reconnecting'].includes(status)) {
    return {
      label: 'Connecting realtime',
      icon: 'ri-loader-4-line',
      className: 'bg-warning-transparent text-warning',
    }
  }

  if (!configured || status === 'unavailable' || status === 'error') {
    return {
      label: `Fallback ${Math.round(fallbackMs / 1000)}s`,
      icon: 'ri-timer-line',
      className: 'bg-secondary-transparent text-secondary',
    }
  }

  return {
    label: 'Realtime idle',
    icon: 'ri-broadcast-line',
    className: 'bg-secondary-transparent text-secondary',
  }
}

function progressPercent(batch: StockGenerationBatch | null | undefined) {
  const requested = Number(batch?.requested_count || 0)
  const generated = Number(batch?.generated_count || 0)
  if (requested <= 0) {
    return 0
  }

  return Math.max(0, Math.min(100, Math.round((generated / requested) * 100)))
}

function numberValue(value: any) {
  const parsed = Number(value || 0)
  return Number.isFinite(parsed) ? parsed : 0
}

function formatNumber(value: any) {
  return new Intl.NumberFormat('th-TH', { maximumFractionDigits: 0 }).format(numberValue(value))
}

function firstText(values: any[]) {
  const value = values.find((entry) => String(entry || '').trim() !== '')
  return value === undefined ? '' : String(value).trim()
}

function extractItems(response: any) {
  if (Array.isArray(response)) return response
  if (Array.isArray(response?.data)) return response.data
  if (Array.isArray(response?.data?.items)) return response.data.items
  if (Array.isArray(response?.items)) return response.items
  return []
}

function extractData(response: any) {
  return response?.data ?? response
}
</script>

<style scoped>
.np-stock-generation-batches__list {
  display: grid;
  gap: .75rem;
}

.np-stock-generation-batches__item,
.np-stock-generation-batches__detail {
  background: var(--custom-white);
  border: 1px solid var(--default-border);
  border-radius: 6px;
  padding: 1rem;
}

.np-stock-generation-batches__item {
  text-align: start;
}

.np-stock-generation-batches__item.active {
  border-color: rgb(var(--primary-rgb));
  box-shadow: 0 0 0 .125rem rgba(var(--primary-rgb), .12);
}

.np-stock-generation-batches__bar {
  height: .35rem;
}

.np-stock-generation-batches__detail-bar {
  height: .5rem;
}

.np-stock-generation-batches__metric-grid {
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(auto-fit, minmax(8rem, 1fr));
}

.np-stock-generation-batches__metric-grid > div {
  background: rgb(var(--light-rgb));
  border: 1px solid var(--default-border);
  border-radius: 4px;
  display: grid;
  gap: .25rem;
  padding: .65rem .75rem;
}
</style>

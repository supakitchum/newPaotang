import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.cwd()
const failures = []
const read = (path) => readFileSync(join(root, path), 'utf8')

const componentPath = 'components/AdminStockSummaryWidgets.vue'
if (!existsSync(join(root, componentPath))) {
  failures.push('AdminStockSummaryWidgets.vue is missing')
}

const component = existsSync(join(root, componentPath)) ? read(componentPath) : ''
const progressComponentPath = 'components/AdminStockGenerationBatches.vue'
if (!existsSync(join(root, progressComponentPath))) {
  failures.push('AdminStockGenerationBatches.vue is missing')
}

const progressComponent = existsSync(join(root, progressComponentPath)) ? read(progressComponentPath) : ''
const operationsPage = read('components/AdminOperationsPage.vue')
const catalog = read('composables/useAdminOperationsCatalog.ts')
const snapshot = JSON.parse(read('scripts/openapi-admin-paths.snapshot.json'))

for (const token of [
  '/admin/central/stock/summary',
  'stockSummaryEndpoint',
  'AdminStockSummaryWidgets',
  'showStockSummaryWidgets',
  'stockSummaryRefreshKey',
]) {
  if (!`${component}\n${operationsPage}\n${catalog}`.includes(token)) {
    failures.push(`Stock summary widget wiring is missing token: ${token}`)
  }
}

for (const token of [
  'game_id: normalizedGameId.value',
  'batch_id: normalizedBatchId.value',
  'summary?.empty',
  'Total tickets',
  '2-tail coverage',
  '3-tail coverage',
  '3-front coverage',
  'Status totals',
  'available',
  'allocated',
  'sold',
  'recalled',
  'voided',
  'min_count_per_number',
  'max_count_per_number',
  'distinct_count',
  'expected_distinct',
]) {
  if (!component.includes(token)) {
    failures.push(`AdminStockSummaryWidgets is missing required summary token: ${token}`)
  }
}

for (const removedGenerateField of [
  "key: 'start'",
  "key: 'count'",
  "key: 'range'",
  "key: 'number_digits'",
]) {
  if (catalog.includes(removedGenerateField)) {
    failures.push(`Removed stock generation field returned to catalog: ${removedGenerateField}`)
  }
}

for (const requiredGenerateField of [
  "key: 'total_count'",
  "key: 'back2_count_per_number'",
  "key: 'back3_count_per_number'",
  "key: 'front3_count_per_number'",
]) {
  if (!catalog.includes(requiredGenerateField)) {
    failures.push(`Quota stock generation field is missing: ${requiredGenerateField}`)
  }
}

for (const token of [
  'defaultValueSource: \'current-game\'',
  'currentOnly: true',
  'hideEmptyOption: true',
  'No current game',
]) {
  if (!catalog.includes(token)) {
    failures.push(`Stock generation current-game selector is missing token: ${token}`)
  }
}

for (const token of [
  'isStockGenerationRoute',
  'currentCentralGameOption',
  'applyCurrentGameFilterDefault',
  'stockGenerationFiltersWithCurrentGame',
  'status: \'open\'',
  'AdminApiState v-if="stockGenerateCurrentGameMessage"',
]) {
  if (!operationsPage.includes(token)) {
    failures.push(`Stock generation current-game workflow is missing token: ${token}`)
  }
}

for (const token of [
  'Stock quota check',
  'syncStockQuotaFields',
  'back3FromQuotaSource',
  '2-tail quota must be divisible by 10.',
  'Total tickets must equal 1,000 x 3-tail quota.',
  'confirmDisabled.value',
]) {
  if (!read('components/AdminConfirmAction.vue').includes(token)) {
    failures.push(`Linked quota modal validation is missing token: ${token}`)
  }
}

for (const removedCapToken of [
  'Total tickets must not exceed 10,000',
  'not create more than 10,000',
  'ไม่เกิน 10,000',
  'สูงสุด 10',
]) {
  if (`${read('components/AdminConfirmAction.vue')}\n${catalog}`.includes(removedCapToken)) {
    failures.push(`Stock generation still exposes old 10,000 UI cap: ${removedCapToken}`)
  }
}

for (const token of [
  'AdminStockGenerationBatches',
  'stockGenerationHasActiveBatch',
  'stockGenerationProgressRefreshKey',
  'stockGenerationSubmittedBatch',
  'isStockGenerateAction',
  'stockGenerationBatchFromResponse',
]) {
  if (!operationsPage.includes(token)) {
    failures.push(`Async stock generation page wiring is missing token: ${token}`)
  }
}

for (const token of [
  '/admin/central/stock/generation-batches',
  'generated_count',
  'requested_count',
  'total_rounds',
  'processed_rounds',
  'chunk_rounds',
  'failure_reason',
  'active-change',
  'Images waiting for stock',
  'Images not reported by batch API',
  'useAdminRealtimeSubscription',
  'private-admin.central.stock-generation.game.',
  'stock.generation.progress.updated',
  'fallbackPollIntervalMs: 60000',
  'window.setTimeout',
]) {
  if (!progressComponent.includes(token)) {
    failures.push(`Async stock generation progress widget is missing token: ${token}`)
  }
}

for (const removedRealtimeToken of [
  'pollIntervalMs: 5000',
  'window.setInterval',
]) {
  if (progressComponent.includes(removedRealtimeToken)) {
    failures.push(`Async stock generation progress widget still exposes chatty polling token: ${removedRealtimeToken}`)
  }
}

const realtimeComposable = existsSync(join(root, 'composables/useAdminRealtime.ts'))
  ? read('composables/useAdminRealtime.ts')
  : ''

for (const token of [
  '/admin/central/realtime/auth',
  'pusher:connection_established',
  'pusher:subscribe',
  'pusher:unsubscribe',
  'onReconnect',
  'adminRealtimeUrl',
  'adminRealtimeKey',
]) {
  if (!realtimeComposable.includes(token)) {
    failures.push(`Admin realtime composable is missing token: ${token}`)
  }
}

if (!snapshot.paths?.['/admin/central/stock/summary']?.includes('get')) {
  failures.push('OpenAPI admin snapshot is missing GET /admin/central/stock/summary')
}

for (const [path, method] of [
  ['/admin/central/stock/generation-batches', 'get'],
  ['/admin/central/stock/generation-batches/{batch_id}', 'get'],
]) {
  if (!snapshot.paths?.[path]?.includes(method)) {
    failures.push(`OpenAPI admin snapshot is missing ${method.toUpperCase()} ${path}`)
  }
}

if (failures.length) {
  console.error('Stock summary widget check failed:')
  for (const failure of failures) {
    console.error(`- ${failure}`)
  }
  process.exit(1)
}

console.log('stock summary widget check passed')

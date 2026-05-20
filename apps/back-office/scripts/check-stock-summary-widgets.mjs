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
const stockSettingsComponentPath = 'components/AdminStockCoverageSettings.vue'
if (!existsSync(join(root, stockSettingsComponentPath))) {
  failures.push('AdminStockCoverageSettings.vue is missing')
}
const stockSettingsComponent = existsSync(join(root, stockSettingsComponentPath)) ? read(stockSettingsComponentPath) : ''
const operationsPage = read('components/AdminOperationsPage.vue')
const catalog = read('composables/useAdminOperationsCatalog.ts')
const generateStart = catalog.indexOf("key: 'generate'")
const generateEnd = catalog.indexOf("key: 'export'", generateStart)
const generateActionBlock = generateStart >= 0 && generateEnd > generateStart
  ? catalog.slice(generateStart, generateEnd)
  : catalog
const snapshot = JSON.parse(read('scripts/openapi-admin-paths.snapshot.json'))

for (const token of [
  '/admin/central/stock/summary',
  'stockSummaryEndpoint',
  'AdminStockSummaryWidgets',
  'showStockSummaryWidgets',
  'stockSummaryRefreshKey',
  'refreshStockSummaryWidgets',
]) {
  if (!`${component}\n${operationsPage}\n${catalog}`.includes(token)) {
    failures.push(`Stock summary widget wiring is missing token: ${token}`)
  }
}

for (const token of [
  'private-admin.central.stock.table.game',
  'stock.table.updated',
  'showStockTableRealtimePanel',
  'Stock table realtime',
  'stockTableRealtimeStatusLabel',
  'stockTableRealtimeStatusBadgeClass',
  'Select a game to show stock summary widgets and enable live table updates.',
  'stockTableRealtimeEnabled',
  'handleStockTableRealtimeEvent',
  'handleStockTableRealtimeReconnect',
  'reloadStockTableFromRealtime',
  'stockTableRealtimeRowRequiresReload',
  'mergeStockTableRealtimeRow',
  'stockTableRealtimeHasUncertainFilters',
  'stockTableRealtimeHasUncertainSort',
  'stockTableRealtimeHasUncertainPage',
]) {
  if (!operationsPage.includes(token)) {
    failures.push(`Central stock table realtime workflow is missing token: ${token}`)
  }
}

if (!operationsPage.includes('<template #beforeTable>') || !read('components/AdminDataTable.vue').includes('<slot name="beforeTable" />')) {
  failures.push('Stock table realtime panel must render inside the Stock Manager data table card')
}

for (const token of [
  'game_id: normalizedGameId.value',
  'batch_id: normalizedBatchId.value',
  'summary?.empty',
  'Generated supply',
  '2-tail max limit',
  '3-tail max limit',
  '3-front max limit',
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
  'generated_count',
  'sellable_remaining_count',
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
  "key: 'generation_mode'",
  "value: 'quota_random'",
  "key: 'total_count'",
  "key: 'back2_count_per_number'",
  "key: 'back3_count_per_number'",
  "key: 'front3_count_per_number'",
  "key: 'seed'",
  "visibleForGenerationModes: ['quota_random']",
]) {
  if (generateActionBlock.includes(removedGenerateField)) {
    failures.push(`Removed stock generation field returned to catalog: ${removedGenerateField}`)
  }
}

for (const requiredGenerateField of [
  "key: 'set_distribution'",
  "defaultValueSource: 'stock-set-distribution-default'",
]) {
  if (!generateActionBlock.includes(requiredGenerateField)) {
    failures.push(`Virtual-only stock generation field is missing: ${requiredGenerateField}`)
  }
}

for (const requiredVirtualPayloadToken of [
  "generation_mode: 'virtual_profile'",
  'delete next.seed',
  'delete next.total_count',
  'delete next.back2_count_per_number',
  'delete next.back3_count_per_number',
  'delete next.front3_count_per_number',
  'delete next.start_number',
  'delete next.count',
  'delete next.number_digits',
  'delete next.central_limits',
  'delete next.partner_limits',
]) {
  if (!operationsPage.includes(requiredVirtualPayloadToken)) {
    failures.push(`Virtual-only stock generation payload guard is missing: ${requiredVirtualPayloadToken}`)
  }
}

for (const movedGenerateField of [
  "key: 'partner_distribution'",
  "key: 'central_limits'",
  "key: 'partner_limits'",
]) {
  if (generateActionBlock.includes(movedGenerateField)) {
    failures.push(`Stock generation field should live in settings/coverage, not generate modal: ${movedGenerateField}`)
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
  'Default set distribution',
  'stock_set_distribution_default',
  'stock_pattern_coverage_default',
  'addSetDistributionRow',
  'removeSetDistributionRow',
  'Central coverage default',
  'Partner coverage default',
]) {
  if (!stockSettingsComponent.includes(token)) {
    failures.push(`Stock settings form is missing token: ${token}`)
  }
}

for (const token of [
  'useAdminRealtimeSubscription',
  'private-admin.central.stock.coverage.game',
  'stock.coverage.updated',
  'applyCoverageDelta',
  'scheduleCoverageFallbackReload',
  'coverageDeltaIncomplete',
]) {
  if (!read('components/AdminStockPatternCoverage.vue').includes(token)) {
    failures.push(`Stock pattern coverage realtime workflow is missing token: ${token}`)
  }
}

for (const token of [
  'virtual_copies',
  'Virtual copy ownership',
  'owner_label',
  'no_agent',
  'image_url',
  'image_thumb_url',
]) {
  if (!read('components/AdminStockNumberDetail.vue').includes(token)) {
    failures.push(`Stock number owner/image detail is missing token: ${token}`)
  }
}

for (const token of [
  'layer_capacity',
  'total_capacity',
  'top_up',
  'Virtual top-up',
  'Initial virtual generate',
]) {
  if (!progressComponent.includes(token)) {
    failures.push(`Stock generation batch top-up metadata is missing token: ${token}`)
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
  'Payload JSON',
  'formFields',
  'confirmDisabled.value',
  'fieldValidationMessages',
]) {
  if (!read('components/AdminConfirmAction.vue').includes(token)) {
    failures.push(`Stock generation modal support is missing token: ${token}`)
  }
}

for (const token of [
  'Stock quota check',
  'syncStockQuotaFields',
  'back3FromQuotaSource',
  '2-tail quota must be divisible by 10.',
  'Total tickets must equal 1,000 x 3-tail quota.',
]) {
  if (read('components/AdminConfirmAction.vue').includes(token)) {
    failures.push(`Retired linked quota modal validation returned: ${token}`)
  }
}

if (!read('components/AdminConfirmAction.vue').includes('confirmDisabled.value')) {
  failures.push('Confirm disabled guard is missing from modal.')
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
  'range_start',
  'formatDateTime(selectedBatch.started_at)',
  'active-change',
  'Images waiting for stock',
  'Images not reported by batch API',
  'useAdminRealtimeSubscription',
  'private-admin.central.stock-generation.game.',
  'stock.generation.progress.updated',
  'fallbackPollIntervalMs: 30000',
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
  'pusher_internal:subscription_succeeded',
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
  ['/admin/central/stock/settings', 'get'],
  ['/admin/central/stock/settings', 'patch'],
  ['/admin/central/stock/patterns', 'get'],
  ['/admin/central/stock/limit-settings', 'put'],
  ['/admin/central/stock/limit-overrides', 'get'],
  ['/admin/central/stock/limit-overrides', 'put'],
  ['/admin/central/stock/{game_id}/numbers/{full_number}', 'get'],
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

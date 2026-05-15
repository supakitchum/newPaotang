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

if (!snapshot.paths?.['/admin/central/stock/summary']?.includes('get')) {
  failures.push('OpenAPI admin snapshot is missing GET /admin/central/stock/summary')
}

if (failures.length) {
  console.error('Stock summary widget check failed:')
  for (const failure of failures) {
    console.error(`- ${failure}`)
  }
  process.exit(1)
}

console.log('stock summary widget check passed')

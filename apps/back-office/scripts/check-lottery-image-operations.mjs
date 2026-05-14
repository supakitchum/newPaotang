import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const componentPath = join(root, 'components/AdminLotteryImageOperations.vue')
const pagePath = join(root, 'pages/admin/central/lottery-images/index.vue')
const dashboardPath = join(root, 'pages/admin/central/dashboard.vue')
const apiPath = join(root, 'composables/useAdminApi.ts')
const catalogPath = join(root, 'composables/useAdminOperationsCatalog.ts')
const operationsPagePath = join(root, 'components/AdminOperationsPage.vue')
const navigationPath = join(root, 'composables/useAdminNavigation.ts')
const sidebarPath = join(root, 'components/AdminSidebar.vue')

const failures = []

if (!existsSync(componentPath)) {
  failures.push('Missing AdminLotteryImageOperations component')
}

if (!existsSync(pagePath)) {
  failures.push('Missing central lottery image operations route page')
}

const component = existsSync(componentPath) ? readFileSync(componentPath, 'utf8') : ''
const page = existsSync(pagePath) ? readFileSync(pagePath, 'utf8') : ''
const dashboard = existsSync(dashboardPath) ? readFileSync(dashboardPath, 'utf8') : ''
const api = existsSync(apiPath) ? readFileSync(apiPath, 'utf8') : ''
const catalog = existsSync(catalogPath) ? readFileSync(catalogPath, 'utf8') : ''
const operationsPage = existsSync(operationsPagePath) ? readFileSync(operationsPagePath, 'utf8') : ''
const navigation = existsSync(navigationPath) ? readFileSync(navigationPath, 'utf8') : ''
const sidebar = existsSync(sidebarPath) ? readFileSync(sidebarPath, 'utf8') : ''

for (const token of [
  '/admin/central/games',
  '/admin/central/partners',
  '/admin/central/lottery-images/readiness',
  '/admin/central/lottery-images/background-asset-sets',
  '/admin/central/lottery-images/background-asset-sets/import-zip',
  '/admin/central/lottery-images/preview',
  '/admin/central/lottery-images/mix',
  '/admin/central/lottery-images/retry-pending',
  '/admin/central/lottery-images/production-readiness',
  "scope: 'central'",
  'idempotencyKey: api.idempotencyKey()',
  'new FormData()',
  "body.append('zip'",
  'Detected Images',
  'Names are sorted automatically',
  'zipForm.progress',
  'previewForm.lottery_number',
  'mode: previewForm.mode',
  'partner_id: previewForm.partner_id',
  'central_unbranded',
  'partner_branded',
  'route.query.game_id',
  'unknownGameLabel',
  'session.setScope(\'central\')',
  'supersede_existing',
  'missing_set_types',
  'pending_assets',
  'failed_generation',
  'secrets_redacted',
  'mixTotal !== 100',
  'retryConfirmOpen',
  'zipUploadMaxBytes = 500 * 1024 * 1024',
  "zipUploadMaxLabel = '500 MB'",
]) {
  if (!component.includes(token)) {
    failures.push(`Lottery image operations component missing ${token}`)
  }
}

for (const removedToken of [
  '/admin/central/assets/uploads',
  '/admin/central/assets/${encodeURIComponent(intent.asset_id)}/commit',
  'source: { asset_id: assetForm.assets.source.asset_id }',
  'full: { asset_id: assetForm.assets.full.asset_id }',
  'thumb: { asset_id: assetForm.assets.thumb.asset_id }',
  'onAssetFileChange',
  'uploadAssetSlot',
  'Zip size must be between 1 byte and 50 MB.',
  '52_428_800',
  'Expected PNG Count',
  'PNG Zip Import',
  'Background PNG Zip',
  'PNG files only',
  'Import PNG zip',
  'Source PNG',
  'Names must be sequential',
  "body.append('expected_count'",
  'expectedCountValid',
]) {
  if (component.includes(removedToken)) {
    failures.push(`Lottery image operations component still contains old manual asset upload token ${removedToken}`)
  }
}

for (const token of [
  'AdminLotteryImageOperations',
  "definePageMeta({ layout: 'admin' })",
]) {
  if (!page.includes(token)) {
    failures.push(`Lottery image operations page missing ${token}`)
  }
}

if (!dashboard.includes('/admin/central/lottery-images')) {
  failures.push('Central dashboard does not link to lottery image operations')
}

if (!api.includes('isFormDataBody') || !api.includes('body instanceof FormData')) {
  failures.push('Admin API helper does not preserve multipart FormData boundaries')
}

if (!catalog.includes("adminUiRoute('central', 'lottery-images?game_id={id}')")) {
  failures.push('Central games catalog is missing lottery image deep-link action')
}

if (!operationsPage.includes('action.route') || !operationsPage.includes('actionRoute(action, row)')) {
  failures.push('Admin operations page does not render route actions')
}

if (!navigation.includes('central:lottery_images')) {
  failures.push('Central navigation does not map lottery image menu route override')
}

if (!sidebar.includes('/admin/central/lottery-images') || !sidebar.includes('/admin/central/games')) {
  failures.push('Sidebar active state does not map lottery image operations back to the games menu')
}

if (component.includes("scope: 'tenant'") || page.includes('/admin/tenant/')) {
  failures.push('Lottery image operations UI must not add tenant edit scope or route')
}

if (failures.length) {
  console.error(failures.map((failure) => `- ${failure}`).join('\n'))
  process.exit(1)
}

console.log('lottery image operations check passed')

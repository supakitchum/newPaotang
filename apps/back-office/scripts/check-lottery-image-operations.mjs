import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const componentPath = join(root, 'components/AdminLotteryImageOperations.vue')
const pagePath = join(root, 'pages/admin/central/lottery-images/index.vue')
const dashboardPath = join(root, 'pages/admin/central/dashboard.vue')

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

for (const token of [
  '/admin/central/lottery-images/readiness',
  '/admin/central/lottery-images/background-asset-sets',
  '/admin/central/lottery-images/mix',
  '/admin/central/lottery-images/retry-pending',
  '/admin/central/lottery-images/production-readiness',
  '/admin/central/assets/uploads',
  '/admin/central/assets/${encodeURIComponent(intent.asset_id)}/commit',
  "scope: 'central'",
  'idempotencyKey: api.idempotencyKey()',
  'supersede_existing',
  'missing_set_types',
  'pending_assets',
  'failed_generation',
  'secrets_redacted',
  'mixTotal !== 100',
  'retryConfirmOpen',
  'source: { asset_id: assetForm.assets.source.asset_id }',
  'full: { asset_id: assetForm.assets.full.asset_id }',
  'thumb: { asset_id: assetForm.assets.thumb.asset_id }',
]) {
  if (!component.includes(token)) {
    failures.push(`Lottery image operations component missing ${token}`)
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

if (component.includes("scope: 'tenant'") || page.includes('/admin/tenant/')) {
  failures.push('Lottery image operations UI must not add tenant edit scope or route')
}

if (failures.length) {
  console.error(failures.map((failure) => `- ${failure}`).join('\n'))
  process.exit(1)
}

console.log('lottery image operations check passed')

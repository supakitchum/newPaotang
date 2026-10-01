import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const componentPath = join(root, 'components/AdminPartnerLotteryBranding.vue')
const pagePath = join(root, 'pages/admin/central/partners/[partner_id]/lottery-branding.vue')
const catalogPath = join(root, 'composables/useAdminOperationsCatalog.ts')
const sidebarPath = join(root, 'components/AdminSidebar.vue')

const failures = []

if (!existsSync(componentPath)) {
  failures.push('Missing AdminPartnerLotteryBranding component')
}

if (!existsSync(pagePath)) {
  failures.push('Missing central partner lottery branding route page')
}

const component = existsSync(componentPath) ? readFileSync(componentPath, 'utf8') : ''
const page = existsSync(pagePath) ? readFileSync(pagePath, 'utf8') : ''
const catalog = existsSync(catalogPath) ? readFileSync(catalogPath, 'utf8') : ''
const sidebar = existsSync(sidebarPath) ? readFileSync(sidebarPath, 'utf8') : ''

for (const token of [
  '/admin/central/partners/${encodeURIComponent(props.partnerId)}/lottery-branding-assets',
  '/admin/central/partners/${encodeURIComponent(props.partnerId)}/lottery-branding/preview',
  '/admin/central/games',
  '/admin/central/assets/uploads',
  '/admin/central/assets/${encodeURIComponent(intent.asset_id)}/commit',
  "scope: 'central'",
  'session.setScope(\'central\')',
  'idempotencyKey: api.idempotencyKey()',
  'logo_qr: { asset_id: assetIds.logo_qr }',
  'right_sidebar: { asset_id: assetIds.right_sidebar }',
  'logo_bottom: { asset_id: assetIds.logo_bottom }',
  'Route-Locked Preview',
  'previewForm.lottery_number',
  'data_url',
  'warnings',
  'side_effects',
  'generated_image_count',
  'branding?.locked',
  'accept="image/*"',
  "new Set(['png', 'jpg', 'jpeg', 'webp', 'gif'])",
  '5 * 1024 * 1024',
]) {
  if (!component.includes(token)) {
    failures.push(`Lottery branding component missing ${token}`)
  }
}

if (!catalog.includes("adminUiRoute('central', 'partners/{id}/lottery-branding')")) {
  failures.push('Central partners catalog is missing lottery branding action link')
}

if (!sidebar.includes('lottery-branding') || !sidebar.includes('/admin/central/partners')) {
  failures.push('Sidebar active state does not map lottery branding back to the partners menu')
}

if (component.includes('previewForm.partner_id') || component.includes('partner_id: previewForm')) {
  failures.push('Lottery branding preview must not expose a partner selector or body partner override')
}

for (const token of [
  'AdminPartnerLotteryBranding',
  'definePageMeta({ layout: ',
  'route.params.partner_id',
]) {
  if (!page.includes(token)) {
    failures.push(`Lottery branding page missing ${token}`)
  }
}

if (component.includes("scope: 'tenant'") || page.includes('/admin/tenant/')) {
  failures.push('Lottery branding UI must not add tenant edit scope or route')
}

if (failures.length) {
  console.error(failures.map((failure) => `- ${failure}`).join('\n'))
  process.exit(1)
}

console.log('lottery branding check passed')

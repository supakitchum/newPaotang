import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const componentPath = join(root, 'components/AdminPartnerLotteryBranding.vue')
const pagePath = join(root, 'pages/admin/central/partners/[partner_id]/lottery-branding.vue')

const failures = []

if (!existsSync(componentPath)) {
  failures.push('Missing AdminPartnerLotteryBranding component')
}

if (!existsSync(pagePath)) {
  failures.push('Missing central partner lottery branding route page')
}

const component = existsSync(componentPath) ? readFileSync(componentPath, 'utf8') : ''
const page = existsSync(pagePath) ? readFileSync(pagePath, 'utf8') : ''

for (const token of [
  '/admin/central/partners/${encodeURIComponent(props.partnerId)}/lottery-branding-assets',
  '/admin/central/assets/uploads',
  '/admin/central/assets/${encodeURIComponent(intent.asset_id)}/commit',
  "scope: 'central'",
  'idempotencyKey: api.idempotencyKey()',
  'logo_qr: { asset_id: assetIds.logo_qr }',
  'right_sidebar: { asset_id: assetIds.right_sidebar }',
  'logo_bottom: { asset_id: assetIds.logo_bottom }',
  'generated_image_count',
  'branding?.locked',
  'image/png,image/webp',
  '5 * 1024 * 1024',
]) {
  if (!component.includes(token)) {
    failures.push(`Lottery branding component missing ${token}`)
  }
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

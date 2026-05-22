import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'

const root = process.cwd()
const read = (path) => readFileSync(resolve(root, path), 'utf8')
const checks = []

const expect = (label, condition) => {
  checks.push({ label, condition: Boolean(condition) })
}

const nuxtConfig = read('nuxt.config.ts')
const axiosPlugin = read('plugins/axios.ts')
const authComposable = read('composables/useAuth.ts')
const siteConfigComposable = read('composables/useSiteConfig.ts')
const stockRealtimeComposable = read('composables/useCustomerStockRealtime.ts')
const affiliateReferralComposable = read('composables/useAffiliateReferral.ts')
const affiliateReferralMiddleware = read('middleware/affiliate-referral.global.ts')
const platformApiComposable = read('composables/usePlatformApi.ts')
const loginPage = read('pages/login.vue')
const registerPage = read('pages/register.vue')
const lineCallbackPage = read('pages/line/callback.vue')
const checkoutPage = read('pages/checkout.vue')
const affiliatePage = read('pages/affiliate.vue')
const proxyRoutePath = 'server/routes/api/v1/[...path].ts'
const proxyRoute = read(proxyRoutePath)

expect('public API base defaults to /api/v1', nuxtConfig.includes("apiBaseUrl: process.env.NUXT_PUBLIC_API_BASE_URL || '/api/v1'"))
expect('customer build dir can be isolated from dev .nuxt volume', nuxtConfig.includes("buildDir: process.env.NUXT_BUILD_DIR || '.nuxt'"))
expect('internal platform API base is configured for SSR/proxy', nuxtConfig.includes('platformApiInternalBaseUrl'))
expect('local tenant storefront hosts are allowlisted', ['.localhost', 'partner-a.test', 'alpha.newpaotang.test', 'beta.newpaotang.test', 'gamma.newpaotang.test'].every((host) => nuxtConfig.includes(host)))
expect('same-origin /api/v1 proxy route exists', existsSync(resolve(root, proxyRoutePath)))
expect('proxy targets platform API internal base', proxyRoute.includes('platformApiInternalBaseUrl'))
expect('proxy preserves tenant Host header', proxyRoute.includes('headers.host = tenantHost'))
expect('proxy normalizes IDN tenant Host header', proxyRoute.includes("from 'node:url'") && proxyRoute.includes('domainToASCII'))
expect('proxy uses Node HTTP client so Host is not stripped by fetch', proxyRoute.includes("from 'node:http'") && !proxyRoute.includes('$fetch.raw'))
expect('axios uses internal platform API base on SSR', axiosPlugin.includes('serverApiBaseUrl') && axiosPlugin.includes('process.server'))
expect('axios forwards storefront Host on SSR', axiosPlugin.includes("request.headers.set('Host', tenantHost)"))
expect('auth cookies are host-scoped', authComposable.includes('tenantHostScope') && authComposable.includes('AUTH_TOKEN_COOKIE}_${authScope}'))
expect('auth useState keys are host-scoped', authComposable.includes('auth_token_state_${authScope}'))
expect('site-config state is host-scoped', siteConfigComposable.includes('site_config_${hostScope}'))
expect('site-config promise cache is host-scoped', siteConfigComposable.includes('siteConfigPromises'))
expect('site-config no longer replaces API base with site-config api.base_url', !siteConfigComposable.includes('runtimeApiBaseUrl.value = siteConfig.api.base_url'))
expect('customer stock realtime can resolve tenant from site-config', stockRealtimeComposable.includes('tenantIdFromSiteConfig(siteConfig.value)'))
expect('customer stock realtime prefers tenant host over auth user tenant', stockRealtimeComposable.includes('tenantIdFromSiteConfig(siteConfig.value) || tenantIdFromUser(user.value)'))
expect('customer stock realtime uses public stock channel subscription', stockRealtimeComposable.includes('syncPublicChannels') && stockRealtimeComposable.includes('customer.tenant.${tenantId.value}.stock.game.${gameId.value}') && !stockRealtimeComposable.includes('private-customer.tenant.${tenantId.value}.stock.game.${gameId.value}'))
expect('customer sale price realtime uses tenant-wide public channel fallback', stockRealtimeComposable.includes('customer.tenant.${tenantId.value}.sale-price'))
expect('customer sale price realtime can subscribe before game stock channel is ready', !stockRealtimeComposable.includes('&& gameId.value && tenantId.value && channelNames.value.length'))
expect('customer realtime channel changes do not reconnect the websocket', !stockRealtimeComposable.includes("channelNames.value.join('|'), realtimeKey.value") && stockRealtimeComposable.includes("watch(\n    () => channelNames.value.join('|')"))
expect('affiliate ref capture validates case-sensitive 6-character Base62 codes', affiliateReferralComposable.includes('REF_CODE_PATTERN = /^[A-Za-z0-9]{6}$/'))
expect('affiliate ref capture uses a 30-day TTL', affiliateReferralComposable.includes('REF_TTL_SECONDS = 60 * 60 * 24 * 30'))
expect('affiliate ref storage is tenant-host scoped', affiliateReferralComposable.includes('affiliate_ref_${scope}') && affiliateReferralComposable.includes('tenantHostScope'))
expect('affiliate ref capture runs before route handling', affiliateReferralMiddleware.includes('captureRefFromRoute(to)'))
expect('affiliate referral apply posts customer endpoint', platformApiComposable.includes("'/customer/affiliate/referrals/apply'"))
expect('affiliate referral apply is wired after login/register/line auth', [loginPage, registerPage, lineCallbackPage].every((page) => page.includes('applyStoredRef()')))
expect('affiliate referral apply is wired before checkout', checkoutPage.includes('await applyStoredRef()') && checkoutPage.indexOf('await applyStoredRef()') < checkoutPage.indexOf('checkoutLegacy'))
expect('customer affiliate page displays canonical ?ref link', affiliatePage.includes('/?ref=${encodeURIComponent(referralCode.value)}') && affiliatePage.includes("!value.includes('/a/')"))

const failed = checks.filter((check) => !check.condition)

for (const check of checks) {
  console.log(`${check.condition ? 'PASS' : 'FAIL'} ${check.label}`)
}

if (failed.length > 0) {
  console.error(`\n${failed.length} tenant-domain integration checks failed.`)
  process.exit(1)
}

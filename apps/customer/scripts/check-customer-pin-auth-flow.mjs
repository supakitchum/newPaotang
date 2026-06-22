import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = process.cwd()
const repoRoot = resolve(root, '../..')
const read = (path) => readFileSync(resolve(root, path), 'utf8')
const readRepo = (path) => readFileSync(resolve(repoRoot, path), 'utf8')
const exists = (path) => existsSync(resolve(root, path))
const checks = []

const expect = (label, condition) => {
  checks.push({ label, condition: Boolean(condition) })
}

const packageJson = read('package.json')
const nuxtConfig = read('nuxt.config.ts')
const mainCss = read('assets/scss/main.css')
const useAuth = read('composables/useAuth.ts')
const platformApi = read('composables/usePlatformApi.ts')
const customerAuthRoutes = read('utils/customerAuthRoutes.ts')
const authMiddleware = read('middleware/auth.global.ts')
const initMiddleware = read('middleware/init.global.ts')
const axiosPlugin = read('plugins/axios.ts')
const affiliatePage = read('pages/affiliate.vue')
const loginPage = read('pages/login.vue')
const lineCallbackPage = read('pages/line/callback.vue')
const registerPage = read('pages/register.vue')
const pinPage = exists('pages/pin.vue') ? read('pages/pin.vue') : ''
const rewardBankPage = exists('pages/profile/reward-bank.vue') ? read('pages/profile/reward-bank.vue') : ''
const pinKeypadScreen = exists('components/PinKeypadScreen.vue') ? read('components/PinKeypadScreen.vue') : ''
const apiRoutes = readRepo('apps/platform-api/routes/api.php')
const customerAuthController = readRepo('apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerAuthController.php')
const customerAuthService = readRepo('apps/platform-api/app/Modules/Auth/Services/CustomerAuthService.php')
const customerAuthMiddleware = readRepo('apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php')
const customerMigration = readRepo('apps/platform-api/database/migrations/2026_05_28_000001_add_customer_pin_unlock_flow.php')

expect('customer PIN page exists', exists('pages/pin.vue'))
expect('customer auth state tracks session-only PIN unlock', useAuth.includes('AUTH_PIN_UNLOCKED_SESSION') && useAuth.includes('window.sessionStorage') && useAuth.includes('pinVerified') && useAuth.includes('pinSetupRequired') && useAuth.includes('pinRequired') && useAuth.includes('setPinVerified(false)'))
expect('customer auth persists refresh session and clears stale refresh failures', useAuth.includes('AUTH_REFRESH_TOKEN_TTL_SECONDS') && useAuth.includes('2592000') && useAuth.includes('maxAge: AUTH_REFRESH_TOKEN_TTL_SECONDS') && useAuth.includes('refreshAuthToken') && useAuth.includes('clearAuthToken()'))
expect('customer platform API exposes PIN endpoints', platformApi.includes('/customer/auth/pin/status') && platformApi.includes('/customer/auth/pin/setup') && platformApi.includes('/customer/auth/pin/verify') && platformApi.includes('/customer/auth/pin/change') && platformApi.includes('/customer/auth/pin/reset/verify-password') && platformApi.includes('/customer/auth/pin/reset'))
expect('customer route middleware refreshes expired sessions before PIN redirects', authMiddleware.includes("to.path === '/pin'") && authMiddleware.includes('pinSetupRequired.value || (pinRequired.value && !handlesPinInline)') && authMiddleware.includes("path: '/pin'") && authMiddleware.includes('refreshAuthToken') && authMiddleware.includes('restoreOrRefreshSession(!userPinStateKnown)') && authMiddleware.includes('restoreOrRefreshSession(true)') && authMiddleware.indexOf('restoreOrRefreshSession(true)') < authMiddleware.indexOf("path: '/pin'"))
expect('customer init middleware skips protected cart init on PIN page without leaving splash stuck', initMiddleware.includes("if (to.path === '/pin')") && initMiddleware.includes('isReady.value = true') && initMiddleware.includes('return'))
expect('axios refreshes expired access tokens before login redirect and keeps PIN redirects scoped', axiosPlugin.includes("'pin_required'") && axiosPlugin.includes("'pin_setup_required'") && axiosPlugin.includes("'pin_locked'") && axiosPlugin.includes("path: '/pin'") && axiosPlugin.includes('setPinVerified(false)') && axiosPlugin.includes('refreshAuthToken') && axiosPlugin.includes('_authRetry') && axiosPlugin.includes('/customer/auth/refresh') && axiosPlugin.includes('return api.request(error.config)'))
expect('affiliate owns its PIN gate without duplicate global PIN redirect', customerAuthRoutes.includes('handlesCustomerPinInline') && customerAuthRoutes.includes("'/affiliate'") && affiliatePage.includes("affiliateStep === 'pin'") && authMiddleware.includes('handlesCustomerPinInline') && authMiddleware.includes('pinRequired.value && !handlesPinInline') && authMiddleware.includes('redirectHandlesPinInline') && loginPage.includes('shouldUseInlinePinRedirect') && loginPage.includes('handlesCustomerPinInline(redirect)') && lineCallbackPage.includes('shouldUseInlinePinRedirect') && lineCallbackPage.includes('handlesCustomerPinInline(redirectTo)') && initMiddleware.includes('handlesCustomerPinInline') && initMiddleware.includes('handlesPinInline && token.value && pinRequired.value') && axiosPlugin.includes('handlesCustomerPinInline(route.path)'))
expect('line callback processes provider code before authenticated shortcut', lineCallbackPage.includes('hasLineCallbackParams') && lineCallbackPage.includes('isAuthenticated.value && !hasLineCallbackParams.value') && lineCallbackPage.indexOf('platformApi.lineCallback(route.query)') > lineCallbackPage.indexOf('!hasLineCallbackParams.value'))
expect('line phone-link onboarding route stays public for first-time LINE users', customerAuthRoutes.includes("'/line/link-phone'"))
expect('password reset routes stay public for forgot-password flow', customerAuthRoutes.includes("'/forgot-password'") && customerAuthRoutes.includes("'/reset-password'") && loginPage.includes('to="/forgot-password"'))
expect('login and register send authenticated users to PIN before app init when needed', loginPage.includes('needsPinUnlock') && loginPage.includes("path: '/pin'") && loginPage.indexOf('needsPinUnlock(response)') < loginPage.indexOf('refreshAppInit(response.token)') && registerPage.includes('needsPinUnlock') && registerPage.includes("path: '/pin'") && registerPage.includes('setAuthSession(response)'))
expect('PIN page supports setup, verify, and reset keypad flows', pinPage.includes('platformApi.setupPin') && pinPage.includes('platformApi.verifyPin') && pinPage.includes('platformApi.verifyPinResetPassword') && pinPage.includes('platformApi.resetPin') && pinPage.includes('setPinVerified(Boolean(response.pin_verified))') && pinPage.includes('pin_confirmation') && pinPage.includes('resetStep') && pinPage.includes('ลืม PIN?') && pinPage.includes('appendDigit') && pinPage.includes('handleBack') && pinPage.includes('<PinKeypadScreen') && pinPage.includes('clearAuthToken()') && pinPage.includes("path: '/login'"))
expect('reward bank save requires PIN keypad and sends PIN to profile API', rewardBankPage.includes('<PinKeypadScreen') && rewardBankPage.includes("bankStep === 'pin'") && rewardBankPage.includes('submitBankAccount') && rewardBankPage.includes('pin: pinDigits.value') && customerAuthController.includes('profileUpdateRequiresPin') && customerAuthService.includes('verifyPinForContext($context') && customerAuthService.includes("'reward_payout_bank_account'"))
expect('PIN keypad screen matches prototype structure', pinKeypadScreen.includes('pin-keypad-dots') && pinKeypadScreen.includes('pin-keypad-grid') && pinKeypadScreen.includes('bi bi-backspace') && pinKeypadScreen.includes('เป๋าตัง'))
expect('customer PIN keypad prevents double-tap zoom', nuxtConfig.includes('maximum-scale=1') && nuxtConfig.includes('user-scalable=no') && mainCss.includes('touch-action: manipulation') && pinKeypadScreen.includes('touch-action: manipulation') && pinKeypadScreen.includes('@dblclick.prevent'))
expect('backend migration adds customer PIN and session unlock columns', customerMigration.includes("'pin_hash'") && customerMigration.includes("'pin_failed_attempts'") && customerMigration.includes("'pin_locked_until'") && customerMigration.includes("'pin_verified_at'"))
expect('backend exposes customer PIN auth routes', apiRoutes.includes('/customer/auth/pin/status') && apiRoutes.includes('/customer/auth/pin/setup') && apiRoutes.includes('/customer/auth/pin/verify') && apiRoutes.includes('/customer/auth/pin/change') && apiRoutes.includes('/customer/auth/pin/reset/verify-password') && apiRoutes.includes('/customer/auth/pin/reset'))
expect('backend controller validates PIN payloads and maps PIN errors', customerAuthController.includes('pinErrors') && customerAuthController.includes('passwordErrors') && customerAuthController.includes('customerPinSetupRequired') && customerAuthController.includes('customerPinRequired') && customerAuthController.includes('customerPinLocked') && customerAuthController.includes("'pin_invalid'") && customerAuthController.includes("'password_invalid'") && customerAuthController.includes("'pin_reset_not_verified'"))
expect('backend service hashes PINs, rate-limits failed attempts, and gates reset by password', customerAuthService.includes('Hash::make($pin)') && customerAuthService.includes('Hash::check($pin') && customerAuthService.includes('Hash::check($password') && customerAuthService.includes('Cache::put($this->pinResetCacheKey') && customerAuthService.includes('Cache::forget($this->pinResetCacheKey') && customerAuthService.includes('PIN_MAX_FAILED_ATTEMPTS') && customerAuthService.includes('PIN_LOCK_SECONDS'))
expect('backend customer refresh session lasts long enough for PIN-first return visits', customerAuthService.includes('REFRESH_TOKEN_TTL_SECONDS = 2592000') && customerAuthService.includes('access_expires_at') && customerAuthService.includes('refresh_expires_at'))
expect('customer PIN setup does not reject easy PIN values', !customerAuthService.includes('isWeakPin') && !customerAuthService.includes("'weak_pin'") && !customerAuthController.includes("'weak_pin'") && !pinPage.includes('PIN นี้เดาง่ายเกินไป'))
expect('backend customer middleware blocks protected APIs until PIN is unlocked while allowing PIN reset', customerAuthMiddleware.includes('requiresPinUnlock') && customerAuthMiddleware.includes('customerPinSetupRequired') && customerAuthMiddleware.includes('customerPinRequired') && customerAuthMiddleware.includes('customer/auth/pin/setup') && customerAuthMiddleware.includes('customer/auth/pin/verify') && customerAuthMiddleware.includes('customer/auth/pin/reset/verify-password'))
expect('customer PIN auth validation is wired into npm test', packageJson.includes('check-customer-pin-auth-flow.mjs'))

const failed = checks.filter((check) => !check.condition)

for (const check of checks) {
  console.log(`${check.condition ? 'PASS' : 'FAIL'} ${check.label}`)
}

if (failed.length > 0) {
  console.error(`\n${failed.length} customer PIN auth flow checks failed.`)
  process.exit(1)
}

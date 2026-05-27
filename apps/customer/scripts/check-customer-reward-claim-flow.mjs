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
const platformApi = read('composables/usePlatformApi.ts')
const ticketHelper = read('composables/useUserTickets.ts')
const ticketStub = read('components/TicketStub.vue')
const ticketPages = [
  read('pages/tickets/index.vue'),
  read('pages/tickets/history.vue'),
  read('pages/tickets/view.vue'),
]
const menuData = read('data/lottery.ts')
const profilePage = read('pages/profile/index.vue')
const claimCreatePage = read('pages/tickets/claim/[ticket_id].vue')
const claimListPage = read('pages/reward-claims/index.vue')
const claimDetailPage = read('pages/reward-claims/[claim_id].vue')
const apiRoutes = readRepo('apps/platform-api/routes/api.php')
const customerRewardController = readRepo('apps/platform-api/app/Modules/Reward/Http/Controllers/CustomerRewardController.php')
const rewardClaimValidator = readRepo('apps/platform-api/app/Modules/Reward/Http/Requests/RewardClaimRequestValidator.php')
const rewardService = readRepo('apps/platform-api/app/Modules/Reward/Services/RewardService.php')
const commerceService = readRepo('apps/platform-api/app/Modules/Commerce/Services/CommerceService.php')

expect('customer claim create page exists', exists('pages/tickets/claim/[ticket_id].vue'))
expect('customer claim list page exists', exists('pages/reward-claims/index.vue'))
expect('customer claim detail page exists', exists('pages/reward-claims/[claim_id].vue'))
expect('claim pages require customer auth', [claimCreatePage, claimListPage, claimDetailPage].every((page) => page.includes('requiresAuth: true')))
expect('customer API exposes ticket reward status and reward claim endpoints', [
  "Route::get('/customer/tickets/{ticket_id}/reward-status'",
  "Route::get('/customer/reward-claims'",
  "Route::post('/customer/reward-claims'",
  "Route::get('/customer/reward-claims/{claim_id}'",
].every((snippet) => apiRoutes.includes(snippet)))
expect('customer claim create requires idempotency header validation', customerRewardController.includes('idempotencyKeyErrors') && customerRewardController.includes('createCustomerClaim'))
expect('customer claim validator accepts wallet and bank transfer methods', rewardClaimValidator.includes("['wallet_credit', 'bank_transfer']"))
expect('reward service creates claims from ticket_id and payout_method', rewardService.includes("'ticket_id' => trim") && rewardService.includes("'payout_method' => trim") && rewardService.includes('RewardClaim::query()->insert'))
expect('reward service falls back to stored reward bank account', rewardService.includes('customerRewardPayoutBankAccount') && rewardService.includes('storeCustomerRewardPayoutBankAccount'))
expect('platform API wraps reward claim list/detail/create', platformApi.includes("axios.get('/customer/reward-claims'") && platformApi.includes('const rewardClaim = async') && platformApi.includes("axios.post('/customer/reward-claims'"))
expect('platform API sends idempotency key on reward claim create', platformApi.includes("headers: idempotencyHeaders('customer-reward-claim')"))
expect('platform API wraps ticket reward status', platformApi.includes('const ticketRewardStatus = async') && platformApi.includes('/customer/tickets/${ticketId}/reward-status'))
expect('ticket helper derives claim destination from reward_claim_id or claimable ticket', ticketHelper.includes('getTicketClaimTo') && ticketHelper.includes('/reward-claims/${encodeURIComponent(claimId)}') && ticketHelper.includes('/tickets/claim/${encodeURIComponent(ticketId)}'))
expect('ticket stub renders claim button as a route link without opening image modal', ticketStub.includes('NuxtLink v-if="claimTo"') && ticketStub.includes('@click.stop'))
expect('all customer ticket pages pass claim route into TicketStub', ticketPages.every((page) => page.includes(':claim-to="getTicketClaimTo(') && page.includes('getTicketClaimTo')))
expect('profile menu links reward cashout history', menuData.includes("{ label: 'ประวัติขึ้นเงินรางวัลสลากดิจิทัล', to: '/reward-claims' }"))
expect('profile menu shows recommended auto claim badge', menuData.includes("{ label: 'ขึ้นเงินรางวัลอัตโนมัติ', badge: 'แนะนำ' }") && profilePage.includes('menuItemBadge') && profilePage.includes('menu-row-badge'))
expect('claim create page implements select confirm pin processing flow', claimCreatePage.includes("type ClaimStep = 'select' | 'confirm' | 'pin' | 'processing'") && claimCreatePage.includes("claimStep === 'select'") && claimCreatePage.includes("claimStep === 'confirm'") && claimCreatePage.includes("claimStep === 'pin'") && claimCreatePage.includes("claimStep === 'processing'"))
expect('claim create page supports wallet and bank transfer payout methods', claimCreatePage.includes("'wallet_credit' | 'bank_transfer'") && claimCreatePage.includes("payoutMethod === 'wallet_credit'") && claimCreatePage.includes("payoutMethod === 'bank_transfer'"))
expect('bank transfer flow links to reward bank settings with redirect back', claimCreatePage.includes('/profile/reward-bank?redirect=') && claimCreatePage.includes('hasBankAccount'))
expect('claim create page submits ticket_id and payout_method', claimCreatePage.includes('platformApi.createRewardClaim') && claimCreatePage.includes('ticket_id: ticketId.value') && claimCreatePage.includes('payout_method: payoutMethod.value'))
expect('claim create page asks for six digit PIN before submit', claimCreatePage.includes('ใส่รหัส PIN 6 หลัก') && claimCreatePage.includes('pinDigits.value.length === 6') && claimCreatePage.includes('await submitClaim()'))
expect('claim create page shows payout confirmation math from attached flow', claimCreatePage.includes('prizeAmount.value * 0.005') && claimCreatePage.includes('prizeAmount.value * 0.01') && claimCreatePage.includes('netAmount') && claimCreatePage.includes('ยอดเงินที่ได้รับ'))
expect('claim create lottery card uses API draw and prize details', claimCreatePage.includes("getTicketGameDate(ticket.value) || '-'") && !claimCreatePage.includes('1 เม.ย. 2580') && claimCreatePage.includes('reward-lottery-card-divider') && claimCreatePage.includes('dd class="blue prize"'))
expect('claim create payout section uses card header layout', claimCreatePage.includes('reward-payout-card-header') && claimCreatePage.includes('reward-payout-card-body') && claimCreatePage.includes('min-height: 306px'))
expect('claim create page normalizes minor-unit reward amounts by prize type', claimCreatePage.includes('rewardAmountToDisplayNumber') && claimCreatePage.includes('mergedRewardStatus.value.prize_amount') && platformApi.includes('knownRewardDisplayAmounts'))
expect('claim create page displays every winning prize row and totals them', claimCreatePage.includes('rewardPrizes') && claimCreatePage.includes('rewardPrizes.value.reduce') && claimCreatePage.includes('v-for="(prize, index) in rewardPrizes"'))
expect('customer ticket detail loads game for claim draw date', commerceService.includes("->with(['localStockItem', 'game'])"))
expect('ticket reward status returns every prize row for claim card', rewardService.includes("'prizes' => $this->winningPrizeRowsResource($visibleWinnings)") && rewardService.includes('sumWinningAmount($visibleWinnings)') && commerceService.includes("'prizes' => $this->winningPrizeRowsResource($visibleWinnings)"))
expect('customer ticket cards can render multiple winning prizes', ticketStub.includes('ticket-stub-prize-list') && ticketHelper.includes('getTicketRewardPrizes') && ticketPages.every((page) => page.includes(':prizes="getTicketRewardPrizes(')))
expect('reward claim pages summarize multiple prize rows', claimListPage.includes('claimPrizeSummary') && claimDetailPage.includes('claimPrizes') && claimDetailPage.includes('reward-claim-prize-list'))
expect('claim create page shows processing receipt after submit', claimCreatePage.includes("claimStep.value = 'processing'") && claimCreatePage.includes('กำลังดำเนินการโอนเงินรางวัล') && claimCreatePage.includes('ดูสลากฯ ของฉัน'))
expect('claim list page loads and links claim detail rows', claimListPage.includes('platformApi.rewardClaims') && claimListPage.includes('/reward-claims/${encodeURIComponent(String(claim.id))}'))
expect('claim detail page loads claim detail and shows status timeline', claimDetailPage.includes('platformApi.rewardClaim') && claimDetailPage.includes('timelineSteps') && claimDetailPage.includes("status === 'rejected'") && claimDetailPage.includes('return 1'))
expect('customer reward claim validation is wired into npm test', packageJson.includes('check-customer-reward-claim-flow.mjs'))

const failed = checks.filter((check) => !check.condition)

for (const check of checks) {
  console.log(`${check.condition ? 'PASS' : 'FAIL'} ${check.label}`)
}

if (failed.length > 0) {
  console.error(`\n${failed.length} customer reward claim flow checks failed.`)
  process.exit(1)
}

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
const blueHeader = read('components/BlueHeader.vue')
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
const confirmTemplateStart = claimCreatePage.indexOf('v-else-if="claimStep === \'confirm\'"')
const processingTemplateStart = claimCreatePage.indexOf('v-else-if="claimStep === \'processing\'"')
const claimConfirmTemplate = confirmTemplateStart >= 0 && processingTemplateStart > confirmTemplateStart
  ? claimCreatePage.slice(confirmTemplateStart, processingTemplateStart)
  : ''
const claimProcessingTemplate = processingTemplateStart >= 0
  ? claimCreatePage.slice(processingTemplateStart)
  : ''
const processingDetailOrder = ['<dt>ผู้รับเงิน</dt>', '<dt>ช่องทางขึ้นเงินรางวัล</dt>', '<dt>วิธีขึ้นเงินรางวัล</dt>', '<dt>สลากฯ งวดวันที่</dt>', '<dt>เลขสลากดิจิทัล</dt>', '<dt>งวดที่</dt>', '<dt>ชุดที่</dt>', '<dt>รางวัล</dt>']
const apiRoutes = readRepo('apps/platform-api/routes/api.php')
const customerRewardController = readRepo('apps/platform-api/app/Modules/Reward/Http/Controllers/CustomerRewardController.php')
const rewardClaimValidator = readRepo('apps/platform-api/app/Modules/Reward/Http/Requests/RewardClaimRequestValidator.php')
const rewardService = readRepo('apps/platform-api/app/Modules/Reward/Services/RewardService.php')
const commerceService = readRepo('apps/platform-api/app/Modules/Commerce/Services/CommerceService.php')
const createCustomerClaimStart = rewardService.indexOf('public function createCustomerClaim')
const createCustomerClaimEnd = rewardService.indexOf('public function approveTenantClaim')
const createCustomerClaimSection = createCustomerClaimStart >= 0 && createCustomerClaimEnd > createCustomerClaimStart
  ? rewardService.slice(createCustomerClaimStart, createCustomerClaimEnd)
  : ''
const ticketSortStart = ticketHelper.indexOf('export const getTicketDisplaySortRank')
const ticketSortEnd = ticketHelper.indexOf('export const sortTicketsForCurrentDraw')
const ticketSortHelper = ticketSortStart >= 0 && ticketSortEnd > ticketSortStart
  ? ticketHelper.slice(ticketSortStart, ticketSortEnd)
  : ''

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
expect('customer claim validator requires wallet/bank transfer and six digit PIN', rewardClaimValidator.includes("['wallet_credit', 'bank_transfer']") && rewardClaimValidator.includes("payload['pin']") && rewardClaimValidator.includes('exactly 6 digits'))
expect('reward service verifies customer PIN before creating claims', createCustomerClaimSection.includes("'ticket_id' => trim") && createCustomerClaimSection.includes("'payout_method' => trim") && createCustomerClaimSection.includes('$this->customerAuth->verifyPin') && createCustomerClaimSection.indexOf('$this->customerAuth->verifyPin') < createCustomerClaimSection.indexOf('replayOrConflict') && createCustomerClaimSection.includes('RewardClaim::query()->insert'))
expect('reward service falls back to stored reward bank account', rewardService.includes('customerRewardPayoutBankAccount') && rewardService.includes('storeCustomerRewardPayoutBankAccount'))
expect('platform API wraps reward claim list/detail/create', platformApi.includes("axios.get('/customer/reward-claims'") && platformApi.includes('const rewardClaim = async') && platformApi.includes("axios.post('/customer/reward-claims'"))
expect('platform API sends idempotency key on reward claim create', platformApi.includes("headers: idempotencyHeaders('customer-reward-claim')"))
expect('platform API wraps ticket reward status', platformApi.includes('const ticketRewardStatus = async') && platformApi.includes('/customer/tickets/${ticketId}/reward-status'))
expect('ticket helper derives claim destination from claimable ticket before reward_claim_id', ticketHelper.includes('getTicketClaimTo') && ticketHelper.includes('/reward-claims/${encodeURIComponent(claimId)}') && ticketHelper.includes('/tickets/claim/${encodeURIComponent(ticketId)}') && ticketHelper.indexOf('isTicketClaimable(ticket) && ticketId') < ticketHelper.indexOf('const claimId = getTicketClaimId(ticket)'))
expect('ticket stub renders claim button as a route link without opening image modal', ticketStub.includes('NuxtLink v-if="claimTo"') && ticketStub.includes('@click.stop'))
expect('all customer ticket pages pass claim route into TicketStub', ticketPages.every((page) => page.includes(':claim-to="getTicketClaimTo(') && page.includes('getTicketClaimTo')))
expect('profile menu links reward cashout history', menuData.includes("{ label: 'ประวัติขึ้นเงินรางวัลสลากดิจิทัล', to: '/reward-claims' }"))
expect('profile menu shows recommended auto claim badge', menuData.includes("{ label: 'ขึ้นเงินรางวัลอัตโนมัติ', to: '/profile/auto-reward', badge: 'แนะนำ' }") && profilePage.includes('menuItemBadge') && profilePage.includes('menu-row-badge'))
expect('claim create page implements select confirm pin processing flow', claimCreatePage.includes("type ClaimStep = 'select' | 'confirm' | 'pin' | 'processing'") && claimCreatePage.includes("claimStep === 'select'") && claimCreatePage.includes("claimStep === 'confirm'") && claimCreatePage.includes("claimStep === 'pin'") && claimCreatePage.includes("claimStep === 'processing'"))
expect('claim create page supports wallet and bank transfer payout methods', claimCreatePage.includes("'wallet_credit' | 'bank_transfer'") && claimCreatePage.includes("payoutMethod === 'wallet_credit'") && claimCreatePage.includes("payoutMethod === 'bank_transfer'"))
expect('bank transfer flow links to reward bank settings with redirect back', claimCreatePage.includes('/profile/reward-bank?redirect=') && claimCreatePage.includes('hasBankAccount'))
expect('claim create page submits ticket_id, payout_method, and typed PIN', claimCreatePage.includes('platformApi.createRewardClaim') && claimCreatePage.includes('ticket_id: ticketId.value') && claimCreatePage.includes('payout_method: payoutMethod.value') && claimCreatePage.includes('pin: pinDigits.value'))
expect('claim create page does not block claimable rejected or cancelled tickets behind an old claim id', claimCreatePage.includes('rawExistingClaimId') && claimCreatePage.includes('claimStatusValue') && claimCreatePage.includes("['rejected', 'cancelled'].includes(claimStatusValue.value)") && claimCreatePage.includes('isClaimable.value') && claimCreatePage.indexOf('rawExistingClaimId') < claimCreatePage.indexOf('const existingClaimId = computed'))
expect('claim create page asks for six digit PIN and shows PIN errors before submit', claimCreatePage.includes('ใส่รหัส PIN 6 หลัก') && claimCreatePage.includes('pinDigits.value.length === 6') && claimCreatePage.includes('await submitClaim()') && claimCreatePage.includes('claimPinError') && claimCreatePage.includes("code === 'pin_invalid'"))
expect('claim create page shows payout confirmation math from attached flow', claimCreatePage.includes('prizeAmount.value * 0.005') && claimCreatePage.includes('prizeAmount.value * 0.01') && claimCreatePage.includes('netAmount') && claimCreatePage.includes('ยอดเงินที่ได้รับ'))
expect('claim confirm page shows waived tax and fee as zero baht', claimCreatePage.includes('ลดให้') && claimCreatePage.includes('<strong>0 บาท</strong>') && claimCreatePage.includes('const netAmount = computed(() => prizeAmount.value)'))
expect('claim confirm payout channel splits bank name and account number', claimCreatePage.includes('payoutChannelLines') && claimCreatePage.includes('หมายเลขบัญชี') && claimCreatePage.includes('reward-payout-lines'))
expect('claim confirm page hides set and draw rows and renders full ticket image', !claimConfirmTemplate.includes('<dt>ชุดที่</dt>') && !claimConfirmTemplate.includes('<dt>งวดที่</dt>') && claimConfirmTemplate.includes('<LotteryImage') && claimCreatePage.includes('ticketImageUrl') && !claimCreatePage.includes('ticketImageThumbUrl') && !claimCreatePage.includes(':thumb-src='))
expect('claim confirm submit is pinned in a bottom footer bar', claimCreatePage.includes('reward-confirm-footer') && claimCreatePage.includes('.reward-claim-page > .reward-claim-footer') && claimCreatePage.includes('position: fixed'))
expect('claim processing receipt uses floating card layout and bottom footer', claimProcessingTemplate.includes('reward-processing-card') && claimProcessingTemplate.includes('reward-processing-footer') && claimCreatePage.includes('.reward-flow-header.processing') && claimCreatePage.includes('.reward-claim-page.processing') && claimCreatePage.includes('background: transparent'))
expect('claim processing receipt follows prototype order', processingDetailOrder.every((label) => claimProcessingTemplate.includes(label)) && processingDetailOrder.every((label, index, labels) => index === 0 || claimProcessingTemplate.indexOf(label) > claimProcessingTemplate.indexOf(labels[index - 1])))
expect('claim processing receipt records submitted date', claimCreatePage.includes('submittedClaim') && claimCreatePage.includes('processingSubmittedAtText') && claimProcessingTemplate.includes('วันที่ทำรายการ'))
expect('claim create lottery card uses API draw and prize details', claimCreatePage.includes("getTicketGameDate(ticket.value) || '-'") && !claimCreatePage.includes('1 เม.ย. 2580') && claimCreatePage.includes('reward-lottery-card-divider') && claimCreatePage.includes('dd class="blue prize"'))
expect('claim create payout section uses card header layout', claimCreatePage.includes('reward-payout-card-header') && claimCreatePage.includes('reward-payout-card-body') && claimCreatePage.includes('min-height: 306px'))
expect('claim create page normalizes minor-unit reward amounts by prize type', claimCreatePage.includes('rewardAmountToDisplayNumber') && claimCreatePage.includes('mergedRewardStatus.value.prize_amount') && platformApi.includes('knownRewardDisplayAmounts'))
expect('claim create page displays every winning prize row and totals them', claimCreatePage.includes('rewardPrizes') && claimCreatePage.includes('rewardPrizes.value.reduce') && claimCreatePage.includes('v-for="(prize, index) in rewardPrizes"'))
expect('customer ticket detail loads game for claim draw date', commerceService.includes("->with(['localStockItem', 'game'])"))
expect('ticket reward status returns every prize row for claim card', rewardService.includes("'prizes' => $this->winningPrizeRowsResource($visibleWinnings)") && rewardService.includes('sumWinningAmount($visibleWinnings)') && commerceService.includes("'prizes' => $this->winningPrizeRowsResource($visibleWinnings)"))
expect('customer ticket cards can render multiple winning prizes', ticketStub.includes('ticket-stub-prize-list') && ticketHelper.includes('getTicketRewardPrizes') && ticketPages.every((page) => page.includes(':prizes="getTicketRewardPrizes(')))
expect('reward claim pages summarize multiple prize rows', claimListPage.includes('claimPrizeSummary') && claimDetailPage.includes('claimPrizes') && claimDetailPage.includes('claimPrizeRows') && claimDetailPage.includes('reward-prize-line'))
expect('claim list page uses compact transaction history layout', claimListPage.includes('ประวัติขึ้นเงินรางวัลสลากดิจิทัล') && claimListPage.includes('reward-claim-row-head') && claimListPage.includes('reward-claim-row-reward') && claimListPage.includes('reward-claim-row-payout') && claimListPage.includes('reward-claim-row-foot') && claimListPage.includes('claimPrizeNames') && claimListPage.includes('bi-chevron-right') && !claimListPage.includes('reward-claims-hero'))
expect('claim list status badges match transfer states', claimListPage.includes('claimIsPaid') && claimListPage.includes("claim.payout_method === 'bank_transfer'") && claimListPage.includes('รอดำเนินการโอนเงิน') && claimListPage.includes('อนุมัติแล้ว รอโอนเงิน') && claimListPage.includes('โอนเงินสำเร็จ') && claimListPage.includes('ขึ้นเงินไม่สำเร็จ') && claimListPage.includes('ยกเลิกรายการ'))
expect('claim create page shows processing receipt after submit', claimCreatePage.includes("claimStep.value = 'processing'") && claimCreatePage.includes('กำลังดำเนินการโอนเงินรางวัล') && claimCreatePage.includes('ดูสลากฯ ของฉัน'))
expect('claim list page loads and links claim detail rows', claimListPage.includes('platformApi.rewardClaims') && claimListPage.includes('/reward-claims/${encodeURIComponent(String(claim.id))}'))
expect('reward claim resource includes ticket game for draw date', rewardService.includes('Game::whereKey($ticket->game_id)') && rewardService.includes("'game' => $game === null ? null") && claimDetailPage.includes('getTicketGameDate'))
expect('reward claim hero back buttons use fixed list and detail destinations', blueHeader.includes('forceBackTo') && blueHeader.includes('navigateTo(props.backTo)') && claimListPage.includes('back-to="/profile"') && claimListPage.includes('force-back-to') && claimDetailPage.includes('back-to="/reward-claims"') && claimDetailPage.includes('force-back-to'))
expect('claim detail page uses flat receipt layout without set or draw rows', claimDetailPage.includes('รายละเอียดการขึ้นเงินรางวัล') && claimDetailPage.includes('reward-claim-receipt') && !claimDetailPage.includes('reward-claim-receipt-card') && claimDetailPage.includes('reward-receipt-money') && claimDetailPage.includes('ยอดเงินที่ได้รับ') && !claimDetailPage.includes('<dt>งวดที่</dt>') && !claimDetailPage.includes('<dt>ชุดที่</dt>'))
expect('claim detail page shows payout, status, game date, tax fee totals', claimDetailPage.includes('payoutChannelLines') && claimDetailPage.includes('<dt>สถานะ</dt>') && claimDetailPage.includes('claimGameDateText') && claimDetailPage.includes('taxAmount') && claimDetailPage.includes('feeAmount') && claimDetailPage.includes('netAmount') && claimDetailPage.includes('claimIsPaid') && claimDetailPage.includes("claimData.payout_method === 'bank_transfer'") && claimDetailPage.includes('อนุมัติแล้ว รอโอนเงิน') && claimDetailPage.includes('ขึ้นเงินไม่สำเร็จ') && claimDetailPage.includes('รอดำเนินการโอนเงิน') && !claimDetailPage.includes('หมายเลขบัญชี ${maskAccountNumber'))
expect('ticket status helpers render approved paid rejected and cancelled reward states', platformApi.includes("rewardStatusValue === 'approved'") && platformApi.includes('rewardStatus.payout_method') && platformApi.includes("'rejected'") && platformApi.includes("'cancelled'") && ticketHelper.includes('rewardStatusRecord.payout_method') && ticketHelper.includes('ขึ้นเงินไม่สำเร็จ') && ticketHelper.includes('ยกเลิกขึ้นเงิน'))
expect('current tickets sort reward states before non-winning tickets', ticketSortHelper.includes('getTicketDisplaySortRank') && ticketHelper.includes('sortTicketsForCurrentDraw') && ticketSortHelper.indexOf("rewardStatus === 'winning'") < ticketSortHelper.indexOf("['rejected', 'cancelled'].includes(rewardStatus)") && ticketSortHelper.indexOf("['rejected', 'cancelled'].includes(rewardStatus)") < ticketSortHelper.indexOf("['submitted', 'claim_submitted', 'under_review'].includes(rewardStatus)") && ticketSortHelper.indexOf("['submitted', 'claim_submitted', 'under_review'].includes(rewardStatus)") < ticketSortHelper.indexOf("rewardStatus === 'non_winning'") && ticketPages[0].includes('displayTickets') && ticketPages[0].includes('sortTicketsForCurrentDraw(tickets.value)') && ticketPages[0].includes('v-for="(ticket, index) in displayTickets"'))
expect('ticket stub uses green paid and red failed cashout status text', ticketStub.includes("statusText === 'ขึ้นเงินแล้ว'") && ticketStub.includes("return 'status-success'") && ticketStub.includes("statusText === 'ขึ้นเงินไม่สำเร็จ'") && ticketStub.includes("return 'status-danger'") && ticketStub.includes('.ticket-status-text.status-success') && ticketStub.includes('.ticket-status-text.status-danger'))
expect('ticket history includes published reward result tickets even before terminal ticket status', commerceService.includes('orWhereExists') && commerceService.includes("->from('reward_results')") && commerceService.includes("->whereColumn('reward_results.game_id', 'tickets.game_id')") && commerceService.includes("->where('reward_results.status', 'published')"))
expect('ticket reward API exposes customer-safe claim status details', rewardService.includes("'claim_status' => (string) $claim->status") && rewardService.includes("'paid_at' => $claim->paid_at") && rewardService.includes("'rejected' => 'rejected'") && commerceService.includes("'claim_status' => (string) $claim->status") && commerceService.includes("'cancelled' => 'cancelled'"))
expect('rejected reward claims become claimable again', rewardService.includes("whereNotIn('status', ['rejected', 'cancelled'])") && rewardService.includes('claimableAfterRejected') && commerceService.includes('claimableAfterRejected') && ticketHelper.includes('isTicketClaimable(ticket) && ticketId'))
expect('claim detail page shows waived tax and fee as zero baht', claimDetailPage.includes('<div class="discount">') && claimDetailPage.includes('ลดให้') && claimDetailPage.includes('<strong>0 บาท</strong>') && claimDetailPage.includes('const netAmount = computed(() => prizeAmount.value)') && claimDetailPage.includes('.reward-receipt-money .discount dd'))
expect('claim detail receipt lists have section dividers and readable type', claimDetailPage.includes('.reward-receipt-list {\n  border-top: 1px solid #eef2f7;') && claimDetailPage.includes('.reward-receipt-list dt,\n.reward-receipt-money dt {\n  color: #64748b;\n  font-size: 15px;') && claimDetailPage.includes('.reward-receipt-list dd,\n.reward-receipt-money dd {\n  color: #111827;\n  font-size: 17px;'))
expect('customer reward claim validation is wired into npm test', packageJson.includes('check-customer-reward-claim-flow.mjs'))

const failed = checks.filter((check) => !check.condition)

for (const check of checks) {
  console.log(`${check.condition ? 'PASS' : 'FAIL'} ${check.label}`)
}

if (failed.length > 0) {
  console.error(`\n${failed.length} customer reward claim flow checks failed.`)
  process.exit(1)
}

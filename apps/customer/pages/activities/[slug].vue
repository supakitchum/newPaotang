<template>
  <PinKeypadScreen
    v-if="claimStep === 'pin'"
    title="ใส่รหัส PIN 6 หลัก"
    subtitle="เพื่อรับเงินรางวัลกิจกรรม"
    :digits="pinDigits"
    :error="claimError"
    :disabled="isSubmitting"
    @append="appendClaimPinDigit"
    @remove="removeClaimPinDigit"
    @back="backToClaimSelect"
  />

  <MobileShell v-else active-nav="home" show-bottom-nav>
    <BlueHeader title="รายละเอียดกิจกรรม" :back-to="backToActivities" min-height="214px" />

    <section class="content-sheet flush activity-detail-sheet">
      <article v-if="activity" class="activity-detail-card">
        <img v-if="activity.image" class="activity-detail-image" :src="activity.image" :alt="activity.name">
        <div class="activity-detail-content">
          <span class="activity-type">{{ activity.type === 'cashback' ? 'กิจกรรมรับเงินคืน' : 'กิจกรรมแผงเลขนำโชค' }}</span>
          <h1>{{ activity.name }}</h1>
          <p>{{ activityConditionText(activity) }}</p>
          <div class="activity-game">
            <i class="bi bi-calendar2-check" />
            <span>{{ activity.game?.name || 'งวดกิจกรรม' }}</span>
          </div>
          <div class="activity-game">
            <i class="bi bi-clock-history" />
            <span>ออกผลกิจกรรม {{ activityResultTimeText }}</span>
          </div>
        </div>
      </article>

      <section v-if="showActivityAwardStatusPanel" class="activity-panel award-status-panel" :class="`is-${activityRewardStatusVariant}`">
        <div class="panel-heading">
          <h2>รางวัลกิจกรรม</h2>
          <span>{{ activityAwardCountText }}</span>
        </div>
        <div v-if="activityAwards.length" class="award-list">
          <div v-for="award in activityAwards" :key="award.id" class="award-row">
            <div>
              <strong>{{ award.type === 'cashback' ? 'เงินคืนกิจกรรม' : predictionLabel(award.prediction_type) }}</strong>
              <small>{{ statusText(award.status) }}</small>
            </div>
            <div class="award-amount">{{ formatBaht(award.amount) }}</div>
            <button v-if="award.status === 'claimable'" class="outline-pill" type="button" @click="startClaim(award)">
              รับเงิน
            </button>
          </div>
        </div>
        <div v-else class="award-status-empty">
          <i :class="activityRewardStatusIcon" />
          <div>
            <strong>{{ activityRewardStatusTitle }}</strong>
            <p>{{ activityRewardStatusDescription }}</p>
          </div>
        </div>
      </section>

      <section v-if="activity?.type === 'lucky_board'" class="activity-panel">
        <div class="panel-heading">
          <h2>เลือกเลขนำโชค</h2>
          <span>{{ rights.remaining_count || 0 }} สิทธิ์คงเหลือ · {{ boardRemainingText }}</span>
        </div>

        <div class="rights-box">
          <div>
            <strong>{{ rights.earned_count || 0 }}</strong>
            <span>สิทธิ์ทั้งหมด</span>
          </div>
          <div>
            <strong>{{ rights.used_count || 0 }}</strong>
            <span>ใช้ไปแล้ว</span>
          </div>
          <div>
            <strong>{{ rights.ticket_count || 0 }}</strong>
            <span>สลากที่ซื้อ</span>
          </div>
        </div>

        <div
          v-if="showLuckyResultPanel"
          class="lucky-result-panel"
          :class="{ won: customerLuckyWon, lost: customerLuckyLost }"
        >
          <div class="lucky-result-header">
            <span>ผลกิจกรรม</span>
            <strong>{{ luckyResultTitle }}</strong>
          </div>
          <div class="lucky-winning-numbers">
            <span v-for="number in luckyWinningNumbers" :key="number">{{ number }}</span>
          </div>
          <p>{{ luckyResultDescription }}</p>
          <div v-if="customerWinningNumbers.length" class="customer-winning-strip">
            <small>เลขของคุณที่ถูกรางวัล</small>
            <strong>{{ customerWinningNumbers.join(', ') }}</strong>
          </div>
        </div>

        <div v-if="entries.length" class="selected-number-panel" aria-label="เลขที่เลือกแล้ว">
          <div class="selected-number-head">
            <strong>เลขที่เลือกแล้ว</strong>
            <span>{{ formatInteger(entries.length) }} เลข</span>
          </div>
          <div class="selected-number-strip">
            <span v-for="entry in entries" :key="entry.id" class="selected-number-pill">
              {{ entry.selected_number }}
            </span>
          </div>
        </div>

        <div class="number-board">
          <div class="number-board-head">
            <div>
              <strong>{{ predictionLabel(predictionType) }}</strong>
              <span>{{ predictionDigits === 3 ? '000-999' : '00-99' }} · เหลือ {{ formatInteger(boardRemainingCount) }} จาก {{ formatInteger(boardTotalCount) }} เลข</span>
            </div>
            <em>เลขสีแดงถูกเลือกแล้ว</em>
          </div>

          <div class="number-board-scroll" :class="{ three: predictionDigits === 3 }">
            <button
              v-for="number in numberOptions"
              :key="`${predictionType}-${number}`"
              type="button"
              class="number-cell"
              :class="{ reserved: isReservedNumber(number), mine: hasSubmittedNumber(number) }"
              :disabled="numberCellDisabled(number)"
              @click="openNumberConfirm(number)"
            >
              {{ number }}
            </button>
          </div>
        </div>

        <NuxtLink v-if="!token" class="activity-login-link" :to="{ path: '/login', query: { redirect: route.fullPath } }">
          เข้าสู่ระบบเพื่อใช้สิทธิ์เลือกเลข
        </NuxtLink>

        <div v-else-if="Number(rights.remaining_count || 0) < 1" class="activity-note">
          สิทธิ์เลือกเลขของคุณหมดแล้ว หรือยังไม่เข้าเงื่อนไขยอดซื้อของกิจกรรมนี้
        </div>

      </section>

      <section v-else-if="activity" class="activity-panel">
        <div class="panel-heading">
          <h2>สิทธิ์รับเงินคืน</h2>
          <span>{{ cashbackProgressText }}</span>
        </div>

        <div class="cashback-hero">
          <span>{{ cashbackRewardText }}</span>
          <strong>{{ cashbackStatusTitle }}</strong>
          <p>{{ cashbackStatusDescription }}</p>
        </div>

        <div class="cashback-expected-card">
          <span>ยอดที่คุณควรได้รับ</span>
          <strong>{{ cashbackExpectedAmountText }}</strong>
          <small>ระบบจะสรุปสิทธิ์อีกครั้งเวลา {{ activityResultTimeText }}</small>
        </div>

        <div class="cashback-grid">
          <div>
            <span>ยอดซื้อในงวด</span>
            <strong>{{ formatBaht(activity.cashback_progress?.purchase_amount || 0) }}</strong>
          </div>
          <div>
            <span>จำนวนสลาก</span>
            <strong>{{ activity.cashback_progress?.ticket_count || 0 }} ใบ</strong>
          </div>
          <div>
            <span>เงื่อนไขขั้นต่ำ</span>
            <strong>{{ minConditionText }}</strong>
          </div>
        </div>

        <div class="cashback-detail-list">
          <div>
            <span>รูปแบบเงินคืน</span>
            <strong>{{ cashbackRewardText }}</strong>
          </div>
          <div>
            <span>เงื่อนไขหลัก</span>
            <strong>ไม่ถูกรางวัลสลาก และไม่ถูกรางวัลแผงเลขนำโชค</strong>
          </div>
          <div>
            <span>เวลาคำนวณ</span>
            <strong>{{ activityResultTimeText }}</strong>
          </div>
          <div>
            <span>การรับเงิน</span>
            <strong>เลือกรับเองจากรางวัลกิจกรรม หรือเปิดรับอัตโนมัติ</strong>
          </div>
        </div>

        <div class="cashback-payout-options">
          <button type="button" @click="startCashbackManualClaim">
            <i class="bi bi-hand-index-thumb" />
            <span>
              <strong>รับเงินเอง</strong>
              <small>{{ cashbackClaimableAward ? 'มีเงินคืนพร้อมรับแล้ว' : 'เมื่อระบบคำนวณแล้วจะมีปุ่มรับเงิน' }}</small>
            </span>
          </button>
          <button type="button" @click="goAutoReward">
            <i class="bi bi-lightning-charge" />
            <span>
              <strong>รับอัตโนมัติ</strong>
              <small>ตั้งค่าช่องทางรับเงินอัตโนมัติ</small>
            </span>
          </button>
        </div>
      </section>

      <section v-if="!activity && !isLoading" class="activity-detail-empty">
        <h1>ไม่พบกิจกรรม</h1>
        <p>กิจกรรมนี้อาจถูกปิดใช้งานหรือหมดช่วงแสดงผลแล้ว</p>
        <NuxtLink class="primary-pill" to="/activities">กลับหน้ากิจกรรม</NuxtLink>
      </section>

      <div v-if="pendingNumber" class="number-confirm-backdrop" @click.self="closeNumberConfirm">
        <div class="number-confirm-modal" role="dialog" aria-modal="true" aria-labelledby="number-confirm-title">
          <button class="number-confirm-close" type="button" aria-label="ปิด" @click="closeNumberConfirm">
            <i class="bi bi-x-lg" />
          </button>
          <span class="activity-type">ยืนยันเลขนำโชค</span>
          <h3 id="number-confirm-title">ต้องการเลือกเลขนี้ใช่ไหม?</h3>
          <div class="confirm-number">{{ pendingNumber }}</div>
          <p>ระบบจะใช้ 1 สิทธิ์ของคุณสำหรับ {{ predictionLabel(predictionType) }} และไม่สามารถเลือกเลขนี้ซ้ำได้</p>
          <div class="number-confirm-actions">
            <button type="button" class="outline-pill" @click="closeNumberConfirm">ยกเลิก</button>
            <button type="button" class="primary-pill" :disabled="!canSubmitEntry || isSubmitting" @click="submitEntry">
              {{ isSubmitting ? 'กำลังบันทึก' : 'ยืนยันเลือกเลข' }}
            </button>
          </div>
        </div>
      </div>

      <div v-if="claimAward && claimStep === 'select'" class="number-confirm-backdrop claim-backdrop" @click.self="closeClaimModal">
        <div class="number-confirm-modal claim-modal" role="dialog" aria-modal="true" aria-labelledby="activity-claim-title">
          <button class="number-confirm-close" type="button" aria-label="ปิด" @click="closeClaimModal">
            <i class="bi bi-x-lg" />
          </button>
          <span class="activity-type">รับเงินกิจกรรม</span>
          <h3 id="activity-claim-title">รับเงินรางวัลกิจกรรม</h3>
          <div class="claim-amount-card">
            <span>ยอดที่รับได้</span>
            <strong>{{ formatBaht(claimAward.amount) }}</strong>
          </div>

          <div class="claim-payout-options">
            <button type="button" :class="{ active: payoutMethod === 'wallet_credit' }" :disabled="isSubmitting" @click="payoutMethod = 'wallet_credit'">
              <span class="claim-radio" />
              <div>
                <strong>{{ walletOptionTitle }}</strong>
                <small>รับเงินเข้า G-Wallet</small>
              </div>
              <span class="claim-option-icon wallet">G</span>
            </button>

            <button
              type="button"
              :class="{ active: payoutMethod === 'bank_transfer', missing: !hasBankAccount }"
              :disabled="isSubmitting || !hasBankAccount"
              @click="payoutMethod = 'bank_transfer'"
            >
              <span class="claim-radio" />
              <div>
                <strong>{{ bankOptionTitle }}</strong>
                <small>{{ bankOptionSubtitle }}</small>
              </div>
              <span class="claim-option-icon bank"><i class="bi bi-bank2" /></span>
            </button>
          </div>

          <div v-if="payoutMethod === 'bank_transfer'" class="claim-bank-preview" :class="{ missing: !hasBankAccount }">
            <i class="bi bi-credit-card-2-front" />
            <div>
              <strong>{{ hasBankAccount ? bankAccount.bank_name : 'ยังไม่ได้บันทึกบัญชีรับเงิน' }}</strong>
              <span>{{ hasBankAccount ? `${bankAccount.account_name || 'ผู้รับเงิน'} · ${maskedAccountNumber}` : 'ใช้บัญชีเดียวกับช่องทางรับเงินรางวัลสลาก' }}</span>
            </div>
          </div>

          <NuxtLink v-if="!hasBankAccount" class="claim-bank-link" :to="rewardBankTo">
            เพิ่มบัญชีรับเงินรางวัล
          </NuxtLink>
          <p v-if="claimError" class="claim-error">{{ claimError }}</p>
          <div class="number-confirm-actions claim-actions">
            <button type="button" class="outline-pill" @click="closeClaimModal">ยกเลิก</button>
            <button class="primary-pill" type="button" :disabled="!canContinueClaim" @click="goToClaimPin">
              ถัดไป
            </button>
          </div>
        </div>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { activityConditionText } from '~/utils/activityDisplay'

definePageMeta({
  requiresAuth: false
})

const route = useRoute()
const platformApi = usePlatformApi()
const { token, restoreAuthState } = useAuth()
const { showAlert } = useAppAlert()
const activity = ref<Record<string, any> | null>(null)
const rights = ref<Record<string, any>>({})
const entries = ref<Record<string, any>[]>([])
const awards = ref<Record<string, any>[]>([])
const profile = ref<Record<string, any> | null>(null)
const isLoading = ref(true)
const isSubmitting = ref(false)
const predictionType = ref('first_prize_last2')
const pendingNumber = ref('')
const claimAward = ref<Record<string, any> | null>(null)
const payoutMethod = ref<'wallet_credit' | 'bank_transfer'>('wallet_credit')
const claimStep = ref<'idle' | 'select' | 'pin'>('idle')
const pinDigits = ref('')
const claimError = ref('')
const backToActivities = computed(() => (
  String(route.query.from || '') === 'history'
    ? `/activities/history${typeof route.query.game_id === 'string' && route.query.game_id ? `?game_id=${encodeURIComponent(route.query.game_id)}` : ''}`
    : '/activities'
))

const enabledPredictionTypes = computed(() => {
  const predictions = activity.value?.config?.prediction_types || {}
  const types = ['first_prize_last2', 'first_prize_last3', 'last2'].filter((type) => predictions[type] !== false)
  return types.length > 0 ? types : ['first_prize_last2']
})
const predictionDigits = computed(() => predictionType.value === 'first_prize_last3' ? 3 : 2)
const numberOptions = computed(() => {
  const length = predictionDigits.value === 3 ? 1000 : 100
  const padLength = predictionDigits.value

  return Array.from({ length }, (_, index) => String(index).padStart(padLength, '0'))
})
const numberBoardForPrediction = computed(() => {
  const board = activity.value?.number_board && typeof activity.value.number_board === 'object'
    ? activity.value.number_board
    : {}
  const types = board.types && typeof board.types === 'object' ? board.types : {}
  const typedBoard = types[predictionType.value] && typeof types[predictionType.value] === 'object'
    ? types[predictionType.value]
    : null

  if (typedBoard) {
    return typedBoard
  }

  return String(board.prediction_type || '') === predictionType.value ? board : {}
})
const boardReservedNumbers = computed(() => {
  const numbers = Array.isArray(numberBoardForPrediction.value.reserved_numbers)
    ? numberBoardForPrediction.value.reserved_numbers
    : []

  return new Set(numbers
    .map((number: unknown) => String(number || '').replace(/\D/g, ''))
    .filter(Boolean)
    .map((number: string) => number.padStart(predictionDigits.value, '0'))
  )
})
const boardTotalCount = computed(() => {
  const total = Number(numberBoardForPrediction.value.total_count)

  return Number.isFinite(total) && total > 0 ? total : numberOptions.value.length
})
const boardReservedCount = computed(() => {
  const reserved = Number(numberBoardForPrediction.value.reserved_count)

  return Number.isFinite(reserved) && reserved >= 0 ? reserved : boardReservedNumbers.value.size
})
const boardRemainingCount = computed(() => {
  const remaining = Number(numberBoardForPrediction.value.remaining_count)

  return Number.isFinite(remaining) && remaining >= 0
    ? remaining
    : Math.max(0, boardTotalCount.value - boardReservedCount.value)
})
const boardRemainingText = computed(() => `เหลือ ${formatInteger(boardRemainingCount.value)} เลขให้เลือก`)
const selectedEntryNumbers = computed(() => new Set(entries.value
  .filter((entry) => String(entry.prediction_type || '') === predictionType.value && String(entry.status || '') !== 'cancelled')
  .map((entry) => String(entry.selected_number || '').replace(/\D/g, ''))
  .filter(Boolean)
  .map((number) => number.padStart(predictionDigits.value, '0'))
))
const canSubmitEntry = computed(() => Boolean(
  token.value &&
  activity.value?.id &&
  pendingNumber.value.length === predictionDigits.value &&
  Number(rights.value.remaining_count || 0) > 0 &&
  !isReservedNumber(pendingNumber.value)
))
const luckyResultSummary = computed(() => {
  const summary = activity.value?.result_summary
  return summary && typeof summary === 'object' ? summary : null
})
const luckyResultDigits = computed(() => String(luckyResultSummary.value?.prediction_type || predictionType.value) === 'first_prize_last3' ? 3 : 2)
const luckyWinningNumbers = computed(() => {
  const summary = luckyResultSummary.value
  const numbers = Array.isArray(summary?.winning_numbers)
    ? summary.winning_numbers
    : (summary?.winning_number ? [summary.winning_number] : [])

  return numbers
    .map((number: unknown) => String(number || '').replace(/\D/g, ''))
    .filter(Boolean)
    .map((number: string) => number.padStart(luckyResultDigits.value, '0'))
})
const customerLuckyResult = computed(() => {
  const customer = luckyResultSummary.value?.customer
  return customer && typeof customer === 'object' ? customer : null
})
const customerLuckyStatus = computed(() => String(customerLuckyResult.value?.status || ''))
const customerLuckyWon = computed(() => customerLuckyStatus.value === 'won')
const customerLuckyLost = computed(() => customerLuckyStatus.value === 'lost')
const customerWinningNumbers = computed(() => {
  const numbers = Array.isArray(customerLuckyResult.value?.winning_numbers)
    ? customerLuckyResult.value.winning_numbers
    : []

  return numbers
    .map((number: unknown) => String(number || '').replace(/\D/g, ''))
    .filter(Boolean)
    .map((number: string) => number.padStart(luckyResultDigits.value, '0'))
})
const showLuckyResultPanel = computed(() => Boolean(
  activity.value?.type === 'lucky_board' &&
  luckyResultSummary.value?.status === 'announced' &&
  luckyWinningNumbers.value.length
))
const luckyResultTitle = computed(() => {
  if (customerLuckyWon.value) return 'คุณถูกรางวัลกิจกรรมนี้'
  if (customerLuckyLost.value) return 'คุณไม่ถูกรางวัลกิจกรรมนี้'
  if (customerLuckyStatus.value === 'pending') return 'รอประมวลผลเลขของคุณ'
  if (customerLuckyStatus.value === 'not_joined') return 'คุณไม่ได้เข้าร่วมกิจกรรมนี้'
  return 'ประกาศหมายเลขที่ชนะแล้ว'
})
const luckyResultDescription = computed(() => {
  const label = predictionLabel(String(luckyResultSummary.value?.prediction_type || predictionType.value))
  const winningText = luckyWinningNumbers.value.join(', ')

  if (customerLuckyWon.value) {
    return `เลขของคุณตรงกับ ${label} หมายเลข ${winningText} รับรางวัลกิจกรรม ${formatBaht(customerLuckyResult.value?.award_amount || 0)}`
  }

  if (customerLuckyLost.value) {
    return `หมายเลขที่ชนะคือ ${winningText} เลขที่คุณเลือกไม่ตรงกับผลกิจกรรมนี้`
  }

  if (customerLuckyStatus.value === 'pending') {
    return `หมายเลขที่ชนะคือ ${winningText} ระบบกำลังสรุปสถานะเลขที่คุณเลือก`
  }

  if (customerLuckyStatus.value === 'not_joined') {
    return `หมายเลขที่ชนะคือ ${winningText} คุณไม่ได้ใช้สิทธิ์ในกิจกรรมนี้`
  }

  return `หมายเลขที่ชนะของ ${label} คือ ${winningText}`
})
const activityAwards = computed(() => awards.value.filter((award) => String(award.activity_id || '') === String(activity.value?.id || '')))
const cashbackClaimableAward = computed(() => activityAwards.value.find((award) => award.type === 'cashback' && award.status === 'claimable') || null)
const activityHasClaimableAward = computed(() => activityAwards.value.some((award) => String(award.status || '') === 'claimable'))
const activityHasPaidAward = computed(() => activityAwards.value.some((award) => ['claimed', 'submitted', 'under_review', 'approved', 'paid'].includes(String(award.status || ''))))
const activityResultHasArrived = computed(() => {
  const raw = String(activity.value?.result_at || '')

  if (!raw) {
    return false
  }

  const date = new Date(raw)

  return !Number.isNaN(date.getTime()) && Date.now() >= date.getTime()
})
const showActivityAwardStatusPanel = computed(() => Boolean(
  activity.value &&
  (
    activityAwards.value.length > 0 ||
    activityResultHasArrived.value ||
    showLuckyResultPanel.value
  )
))
const activityAwardCountText = computed(() => {
  if (activityAwards.value.length > 0) {
    return `${activityAwards.value.length} รายการ`
  }

  if (!token.value) {
    return 'เข้าสู่ระบบเพื่อดูสถานะ'
  }

  if (activity.value?.type === 'lucky_board' && customerLuckyLost.value) {
    return 'ไม่ได้รับรางวัล'
  }

  if (activity.value?.type === 'lucky_board' && customerLuckyStatus.value === 'not_joined') {
    return 'ไม่ได้เข้าร่วม'
  }

  return activityResultHasArrived.value || showLuckyResultPanel.value ? 'ยังไม่มีรางวัล' : 'รอออกผล'
})
const activityRewardStatusVariant = computed(() => {
  if (activityAwards.value.length > 0) {
    return activityHasClaimableAward.value ? 'claimable' : (activityHasPaidAward.value ? 'paid' : 'awarded')
  }

  if (!token.value || customerLuckyStatus.value === 'pending' || (!activityResultHasArrived.value && !showLuckyResultPanel.value)) {
    return 'pending'
  }

  if (activity.value?.type === 'lucky_board' && (customerLuckyLost.value || customerLuckyStatus.value === 'not_joined')) {
    return 'missed'
  }

  return activityResultHasArrived.value ? 'missed' : 'pending'
})
const activityRewardStatusIcon = computed(() => {
  const icons: Record<string, string> = {
    claimable: 'bi bi-cash-coin',
    paid: 'bi bi-check2-circle',
    awarded: 'bi bi-trophy',
    missed: 'bi bi-x-circle',
    pending: 'bi bi-hourglass-split'
  }

  return icons[activityRewardStatusVariant.value] || 'bi bi-hourglass-split'
})
const activityRewardStatusTitle = computed(() => {
  if (!token.value) return 'เข้าสู่ระบบเพื่อดูรางวัลของคุณ'

  if (activity.value?.type === 'lucky_board') {
    if (customerLuckyLost.value) return 'คุณไม่ได้รับรางวัลกิจกรรมนี้'
    if (customerLuckyStatus.value === 'not_joined') return 'คุณยังไม่ได้เข้าร่วมกิจกรรมนี้'
    if (customerLuckyStatus.value === 'pending') return 'รอประมวลผลเลขของคุณ'
    return showLuckyResultPanel.value ? 'ยังไม่มีรางวัลกิจกรรมของคุณ' : 'รอออกผลกิจกรรม'
  }

  if (activityResultHasArrived.value) return 'ยังไม่มีเงินคืนกิจกรรม'

  return 'รอคำนวณสิทธิ์เงินคืน'
})
const activityRewardStatusDescription = computed(() => {
  if (!token.value) return 'เข้าสู่ระบบเพื่อดูว่าคุณได้รับรางวัลหรือเงินคืนจากกิจกรรมนี้หรือไม่'

  if (activity.value?.type === 'lucky_board') {
    if (customerLuckyLost.value) return 'เลขที่คุณเลือกไม่ตรงกับหมายเลขที่ชนะของกิจกรรมนี้'
    if (customerLuckyStatus.value === 'not_joined') return 'ใช้สิทธิ์เลือกเลขก่อนออกผล เพื่อร่วมลุ้นรางวัลกิจกรรม'
    if (customerLuckyStatus.value === 'pending') return 'ระบบกำลังสรุปสถานะหลังประกาศหมายเลขที่ชนะ'
    return showLuckyResultPanel.value
      ? 'ระบบประกาศหมายเลขที่ชนะแล้ว แต่คุณไม่มีรางวัลที่รับได้ในกิจกรรมนี้'
      : `ระบบจะประกาศรางวัลกิจกรรมเวลา ${activityResultTimeText}`
  }

  if (activityResultHasArrived.value) {
    return 'ระบบยังไม่พบรายการเงินคืนที่รับได้สำหรับกิจกรรมนี้'
  }

  return `ระบบจะสรุปสิทธิ์เงินคืนเวลา ${activityResultTimeText}`
})
const bankAccount = computed(() => {
  const bank = profile.value?.reward_payout_bank_account || profile.value?.bank_account || {}

  return {
    bank_name: String(bank.bank_name || bank.bank || ''),
    account_name: String(bank.account_name || bank.bank_deposit_name || ''),
    account_number: String(bank.account_number || bank.account_no || bank.bank_account_no || bank.bank_deposit_number || '')
  }
})
const hasBankAccount = computed(() => Boolean(bankAccount.value.bank_name && bankAccount.value.account_number))
const accountLast4 = computed(() => {
  const number = bankAccount.value.account_number.replace(/\D/g, '')

  return number.slice(-4) || '----'
})
const maskedAccountNumber = computed(() => maskAccountNumber(bankAccount.value.account_number))
const walletSuffix = computed(() => {
  const value = String(profile.value?.wallet?.id || profile.value?.primary_wallet?.id || profile.value?.wallet_id || '123').replace(/\D/g, '')

  return value.slice(-3).padStart(3, '0')
})
const bankDisplayName = computed(() => bankAccount.value.bank_name.replace(/^ธนาคาร/, 'บัญชี') || 'บัญชีธนาคาร')
const bankOptionTitle = computed(() => hasBankAccount.value ? `${bankDisplayName.value} x ${accountLast4.value}` : 'บัญชีธนาคาร')
const bankOptionSubtitle = computed(() => hasBankAccount.value
  ? 'รับเงินเข้าบัญชีรับเงินรางวัลที่บันทึกไว้'
  : 'เพิ่มบัญชีรับเงินรางวัลก่อนเลือกช่องทางนี้'
)
const walletOptionTitle = computed(() => `G Wallet x ${walletSuffix.value}`)
const rewardBankTo = computed(() => `/profile/reward-bank?redirect=${encodeURIComponent(route.fullPath)}`)
const canContinueClaim = computed(() => Boolean(
  claimAward.value &&
  !isSubmitting.value &&
  (payoutMethod.value !== 'bank_transfer' || hasBankAccount.value)
))
const canSubmitClaim = computed(() => {
  if (!canContinueClaim.value || pinDigits.value.length !== 6) return false
  return true
})
const cashbackProgressText = computed(() => activity.value?.cashback_progress?.eligible_by_purchase ? 'เข้าเงื่อนไขยอดซื้อ' : 'รอเข้าเงื่อนไข')
const cashbackRewardText = computed(() => {
  const config = activity.value?.config || {}
  const type = String(config.cashback_type || 'percent')

  if (type === 'fixed') {
    return `รับเงินคืน ${formatBaht(config.fixed_amount || 0)}`
  }

  const percent = Number(config.cashback_percent || 0)
  return percent > 0 ? `รับเงินคืน ${percent.toLocaleString('th-TH')}% ของยอดซื้อ` : 'รับเงินคืนตามเงื่อนไขกิจกรรม'
})
const cashbackStatusTitle = computed(() => activity.value?.cashback_progress?.eligible_by_purchase ? 'ยอดซื้อเข้าเงื่อนไขแล้ว' : 'ยังไม่เข้าเงื่อนไขยอดซื้อ')
const cashbackStatusDescription = computed(() => {
  if (activity.value?.cashback_progress?.eligible_by_purchase) {
    return 'ระบบจะตรวจสิทธิ์เวลา 17:00 ของวันที่ออกผล โดยลูกค้าต้องไม่ถูกรางวัลสลากและไม่ถูกรางวัลแผงเลขนำโชค'
  }

  return `ซื้อให้ครบ ${minConditionText.value} ในงวดนี้ เพื่อรอคำนวณเงินคืนเวลา 17:00 ของวันที่ออกผล`
})
const cashbackExpectedAmount = computed(() => Number(activity.value?.cashback_progress?.estimated_amount || 0))
const cashbackExpectedAmountText = computed(() => formatBaht(cashbackExpectedAmount.value))
const activityResultTimeText = computed(() => {
  const raw = String(activity.value?.result_at || '')

  if (!raw) {
    return '17:00 น. ของวันที่ออกผล'
  }

  const date = new Date(raw)

  if (Number.isNaN(date.getTime())) {
    return '17:00 น. ของวันที่ออกผล'
  }

  return new Intl.DateTimeFormat('th-TH', {
    timeZone: 'Asia/Bangkok',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  }).format(date) + ' น.'
})
const minConditionText = computed(() => {
  const progress = activity.value?.cashback_progress || {}
  const minimumType = String(progress.minimum_type || 'tickets')
  const tickets = Number(progress.min_ticket_count || 0)
  const purchase = Number(progress.min_purchase_amount || 0)

  if (minimumType === 'amount') {
    return purchase > 0 ? formatBaht(purchase) : 'ไม่มีขั้นต่ำ'
  }

  return tickets > 0 ? `${tickets} ใบ` : 'ไม่มีขั้นต่ำ'
})

watch(enabledPredictionTypes, (types) => {
  if (!types.includes(predictionType.value)) {
    predictionType.value = types[0]
  }
  pendingNumber.value = ''
}, { immediate: true })

const hasSubmittedNumber = (number: string) => selectedEntryNumbers.value.has(number)
const isReservedNumber = (number: string) => boardReservedNumbers.value.has(number)

const numberCellDisabled = (number: string) => (
  isReservedNumber(number) ||
  !token.value ||
  Number(rights.value.remaining_count || 0) < 1 ||
  isSubmitting.value
)

const openNumberConfirm = async (number: string) => {
  if (!token.value) {
    await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
    return
  }

  if (numberCellDisabled(number)) {
    return
  }

  pendingNumber.value = number
}

const closeNumberConfirm = () => {
  if (isSubmitting.value) {
    return
  }

  pendingNumber.value = ''
}

const maskAccountNumber = (value: unknown) => {
  const number = String(value || '').replace(/\D/g, '')

  if (number.length <= 4) {
    return number || '-'
  }

  return `${'*'.repeat(Math.max(0, number.length - 4))}${number.slice(-4)}`
}

const loadClaimProfile = async () => {
  if (!token.value) {
    profile.value = null
    return
  }

  try {
    profile.value = await restoreAuthState(true) || {}
  } catch (error) {
    console.log(error)
    profile.value = null
  }
}

const loadActivity = async () => {
  isLoading.value = true
  try {
    const publicActivity = await platformApi.activityPublic(String(route.params.slug || ''))
    activity.value = publicActivity

    if (token.value && publicActivity?.id) {
      try {
        const [customerActivity, profileResult] = await Promise.allSettled([
          platformApi.customerActivity(publicActivity.id),
          restoreAuthState(true)
        ])

        if (customerActivity.status === 'fulfilled') {
          activity.value = customerActivity.value
        }

        if (profileResult.status === 'fulfilled') {
          profile.value = profileResult.value || {}
        }

        rights.value = activity.value?.rights || {}
        entries.value = Array.isArray(activity.value?.entries) ? activity.value.entries : []
        const awardResponse = await platformApi.activityAwards({ limit: 100 })
        awards.value = Array.isArray(awardResponse.data) ? awardResponse.data : []
      } catch (error) {
        console.log(error)
        rights.value = {}
        entries.value = []
        awards.value = []
      }
    }
  } catch (error) {
    console.log(error)
    activity.value = null
  } finally {
    isLoading.value = false
  }
}

const submitEntry = async () => {
  if (!token.value) {
    await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
    return
  }

  if (!activity.value?.id || !canSubmitEntry.value) return
  isSubmitting.value = true
  try {
    await platformApi.createActivityEntry(activity.value.id, {
      prediction_type: predictionType.value,
      selected_number: pendingNumber.value
    })
    pendingNumber.value = ''
    await loadActivity()
    showAlert({ title: 'ส่งเลขสำเร็จ', message: 'ระบบบันทึกเลขนำโชคของคุณแล้ว', variant: 'success' })
  } catch (error: any) {
    showAlert({ title: 'ส่งเลขไม่สำเร็จ', message: error?.response?.data?.error?.message || 'กรุณาตรวจสอบสิทธิ์และลองใหม่อีกครั้ง', variant: 'error' })
  } finally {
    isSubmitting.value = false
  }
}

const startClaim = async (award: Record<string, any>) => {
  if (!token.value) {
    await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
    return
  }

  await loadClaimProfile()
  claimAward.value = award
  payoutMethod.value = 'wallet_credit'
  claimStep.value = 'select'
  pinDigits.value = ''
  claimError.value = ''
}

const closeClaimModal = () => {
  if (isSubmitting.value) {
    return
  }

  claimAward.value = null
  claimStep.value = 'idle'
  pinDigits.value = ''
  claimError.value = ''
}

const goToClaimPin = () => {
  if (!canContinueClaim.value) {
    return
  }

  pinDigits.value = ''
  claimError.value = ''
  claimStep.value = 'pin'
}

const backToClaimSelect = () => {
  if (isSubmitting.value) {
    return
  }

  pinDigits.value = ''
  claimError.value = ''
  claimStep.value = claimAward.value ? 'select' : 'idle'
}

const appendClaimPinDigit = async (digit: string) => {
  if (!/^\d$/.test(digit) || pinDigits.value.length >= 6 || isSubmitting.value) {
    return
  }

  claimError.value = ''
  pinDigits.value += digit

  if (pinDigits.value.length === 6) {
    await submitClaim()
  }
}

const removeClaimPinDigit = () => {
  if (isSubmitting.value || pinDigits.value.length === 0) {
    return
  }

  claimError.value = ''
  pinDigits.value = pinDigits.value.slice(0, -1)
}

const startCashbackManualClaim = async () => {
  if (!token.value) {
    await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
    return
  }

  if (!cashbackClaimableAward.value) {
    showAlert({
      title: 'ยังไม่มีเงินคืนพร้อมรับ',
      message: 'ระบบจะแสดงรายการเงินคืนหลังคำนวณสิทธิ์เรียบร้อยแล้ว',
      variant: 'warning'
    })
    return
  }

  await startClaim(cashbackClaimableAward.value)
}

const goAutoReward = async () => {
  if (!token.value) {
    await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
    return
  }

  await navigateTo({ path: '/profile/auto-reward', query: { redirect: route.fullPath } })
}

const submitClaim = async () => {
  if (!claimAward.value || !canSubmitClaim.value) return
  isSubmitting.value = true
  claimError.value = ''
  try {
    await platformApi.createActivityClaim({
      award_id: claimAward.value.id,
      payout_method: payoutMethod.value,
      pin: pinDigits.value,
      ...(payoutMethod.value === 'bank_transfer' ? { bank_account: bankAccount.value } : {})
    })
    claimAward.value = null
    claimStep.value = 'idle'
    pinDigits.value = ''
    await loadActivity()
    showAlert({ title: 'ส่งคำขอสำเร็จ', message: 'Partner จะตรวจสอบและอนุมัติรายการของคุณ', variant: 'success' })
  } catch (error: any) {
    const code = error?.response?.data?.error?.code || error?.data?.error?.code || ''
    pinDigits.value = ''
    claimError.value = code === 'pin_invalid'
      ? 'PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง'
      : code === 'pin_locked'
        ? 'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่แล้วลองใหม่'
        : code === 'pin_setup_required'
          ? 'กรุณาตั้งค่า PIN ก่อนทำรายการ'
          : 'ไม่สามารถส่งคำขอได้ กรุณาตรวจสอบข้อมูล'
  } finally {
    isSubmitting.value = false
  }
}

const predictionLabel = (type: string) => ({
  first_prize_last2: '2 ตัวรางวัลที่ 1',
  first_prize_last3: '3 ตัวรางวัลที่ 1',
  last2: '2 ตัวท้าย'
}[type] || type)
const statusText = (status: string) => ({
  submitted: 'ส่งเลขแล้ว',
  won: 'ถูกรางวัล',
  lost: 'ไม่ถูกรางวัล',
  claimable: 'รับเงินได้',
  claimed: 'ส่งคำขอแล้ว',
  paid: 'จ่ายแล้ว',
  rejected: 'ไม่อนุมัติ'
}[status] || status)
const formatInteger = (value: unknown) => Number(value || 0).toLocaleString('th-TH', { maximumFractionDigits: 0 })
const formatBaht = (value: unknown) => Number(value || 0).toLocaleString('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' บาท'

watch(() => route.params.slug, () => {
  void loadActivity()
}, { immediate: true })

useTenantSeo({
  title: 'รายละเอียดกิจกรรม',
  description: 'กิจกรรมและสิทธิพิเศษจากร้านค้า',
  canonicalPath: `/activities/${String(route.params.slug || '')}`
})
</script>

<style scoped>
.activity-detail-sheet {
  display: grid;
  gap: 14px;
  margin-top: -24px;
  padding: 6px 16px calc(112px + env(safe-area-inset-bottom));
}

.activity-detail-card,
.activity-panel,
.activity-detail-empty {
  background: #fff;
  border-radius: 18px;
  box-shadow: 0 14px 30px rgba(8, 48, 104, .1);
  overflow: hidden;
}

.activity-detail-image {
  display: block;
  max-height: 420px;
  object-fit: cover;
  width: 100%;
}

.activity-detail-content {
  display: grid;
  gap: 10px;
  padding: 18px;
}

.activity-type {
  align-items: center;
  background: #e8f4ff;
  border-radius: 999px;
  color: #0875df;
  display: inline-flex;
  font-size: 12px;
  font-weight: 900;
  justify-content: center;
  justify-self: start;
  line-height: 1;
  min-height: 24px;
  padding: 5px 10px;
}

.activity-detail-content h1,
.panel-heading h2 {
  color: #1f2937;
  font-size: 23px;
  font-weight: 900;
  line-height: 1.25;
  margin: 0;
}

.activity-detail-content p {
  color: #667085;
  font-size: 15px;
  line-height: 1.55;
  margin: 0;
}

.activity-game {
  align-items: center;
  color: #0b74d9;
  display: flex;
  font-size: 14px;
  font-weight: 800;
  gap: 8px;
}

.activity-panel {
  display: grid;
  gap: 16px;
  margin-top: 0;
  padding: 18px;
}

.panel-heading {
  align-items: flex-start;
  display: flex;
  gap: 12px;
  justify-content: space-between;
  flex-wrap: wrap;
}

.panel-heading span {
  color: #0b74d9;
  font-size: 13px;
  font-weight: 900;
  line-height: 1.35;
}

.rights-box,
.cashback-grid {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.rights-box div,
.cashback-grid div {
  background: #f6f9ff;
  border-radius: 14px;
  display: grid;
  gap: 3px;
  padding: 12px;
}

.rights-box strong,
.cashback-grid strong {
  color: #111827;
  font-size: 19px;
  font-weight: 900;
}

.rights-box span,
.cashback-grid span {
  color: #667085;
  font-size: 12px;
  font-weight: 700;
}

.lucky-result-panel {
  background: linear-gradient(135deg, #eff6ff, #f8fbff);
  border: 1px solid #b9dcff;
  border-radius: 18px;
  display: grid;
  gap: 12px;
  padding: 14px;
}

.lucky-result-panel.won {
  background: linear-gradient(135deg, #ecfdf3, #f8fffb);
  border-color: #86efac;
}

.lucky-result-panel.lost {
  background: linear-gradient(135deg, #fff7ed, #fffaf5);
  border-color: #fed7aa;
}

.lucky-result-header {
  align-items: center;
  display: flex;
  gap: 10px;
  justify-content: space-between;
}

.lucky-result-header span {
  color: #0b74d9;
  font-size: 12px;
  font-weight: 900;
}

.lucky-result-header strong {
  color: #0f3763;
  font-size: 17px;
  font-weight: 900;
  line-height: 1.25;
  text-align: right;
}

.lucky-winning-numbers {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.lucky-winning-numbers span {
  align-items: center;
  background: #0b7fe8;
  border-radius: 14px;
  box-shadow: 0 10px 18px rgba(11, 127, 232, .2);
  color: #fff;
  display: inline-flex;
  font-size: 26px;
  font-weight: 900;
  justify-content: center;
  letter-spacing: .08em;
  line-height: 1;
  min-height: 52px;
  min-width: 92px;
  padding: 12px 16px;
}

.lucky-result-panel.won .lucky-winning-numbers span {
  background: #10b981;
  box-shadow: 0 10px 18px rgba(16, 185, 129, .2);
}

.lucky-result-panel.lost .lucky-winning-numbers span {
  background: #f97316;
  box-shadow: 0 10px 18px rgba(249, 115, 22, .2);
}

.lucky-result-panel p {
  color: #475467;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.45;
  margin: 0;
}

.customer-winning-strip {
  align-items: center;
  background: rgba(255, 255, 255, .78);
  border: 1px solid rgba(16, 185, 129, .25);
  border-radius: 14px;
  display: flex;
  gap: 10px;
  justify-content: space-between;
  padding: 10px 12px;
}

.customer-winning-strip small {
  color: #667085;
  font-size: 12px;
  font-weight: 800;
}

.customer-winning-strip strong {
  color: #047857;
  font-size: 16px;
  font-weight: 900;
  letter-spacing: .04em;
}

.selected-number-panel {
  background: linear-gradient(135deg, #f7fbff, #eef7ff);
  border: 1px solid #b9dcff;
  border-radius: 18px;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, .65);
  display: grid;
  gap: 12px;
  padding: 14px;
}

.selected-number-head {
  align-items: center;
  display: flex;
  gap: 10px;
  justify-content: space-between;
}

.selected-number-head strong {
  color: #0f3763;
  font-size: 15px;
  font-weight: 900;
}

.selected-number-head span {
  background: #fff;
  border: 1px solid #cfe7ff;
  border-radius: 999px;
  color: #0875df;
  font-size: 12px;
  font-weight: 900;
  line-height: 1;
  padding: 6px 9px;
}

.selected-number-strip {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.selected-number-pill {
  align-items: center;
  background: #fff;
  border: 1px solid #9ccfff;
  border-radius: 12px;
  color: #075fb3;
  display: inline-flex;
  font-size: 17px;
  font-weight: 900;
  justify-content: center;
  letter-spacing: .06em;
  line-height: 1;
  min-height: 34px;
  min-width: 58px;
  padding: 8px 12px;
}

.number-board {
  border: 1px solid #e5ebf3;
  border-radius: 18px;
  display: grid;
  gap: 12px;
  overflow: hidden;
  padding: 12px;
}

.number-board-head {
  align-items: center;
  display: flex;
  gap: 10px;
  justify-content: space-between;
}

.number-board-head div {
  display: grid;
  gap: 2px;
}

.number-board-head strong {
  color: #111827;
  font-size: 15px;
  font-weight: 900;
}

.number-board-head span {
  color: #7a8797;
  font-size: 12px;
  font-weight: 800;
}

.number-board-head em {
  background: #e8f4ff;
  border-radius: 999px;
  color: #0875df;
  font-size: 12px;
  font-style: normal;
  font-weight: 900;
  padding: 6px 10px;
}

.number-board-scroll {
  display: grid;
  gap: 8px;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  overflow: visible;
  padding: 2px 2px 4px;
}

.number-board-scroll.three {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.number-cell {
  aspect-ratio: 1 / .72;
  background: #f8fafc;
  border: 1px solid #dce6f2;
  border-radius: 12px;
  color: #1f2937;
  font-size: 16px;
  font-weight: 900;
  min-height: 42px;
}

.number-cell.reserved {
  background: #fee2e2;
  border-color: #ef4444;
  color: #b42318;
  opacity: 1;
  position: relative;
}

.number-cell.reserved::after {
  background: #ef4444;
  border-radius: 999px;
  color: #fff;
  content: "จอง";
  font-size: 9px;
  font-weight: 900;
  line-height: 1;
  padding: 3px 5px;
  position: absolute;
  right: 4px;
  top: 4px;
}

.number-cell.mine {
  box-shadow: inset 0 0 0 2px rgba(180, 35, 24, .18);
}

.number-cell:disabled:not(.reserved) {
  color: #b5c0ce;
  opacity: .72;
}

.activity-login-link,
.activity-note {
  border-radius: 14px;
  font-size: 13px;
  font-weight: 900;
  line-height: 1.45;
  padding: 12px 14px;
  text-align: center;
}

.activity-login-link {
  background: #e8f4ff;
  color: #0875df;
  text-decoration: none;
}

.activity-note {
  background: #fff7e6;
  color: #b76b00;
}

.award-list {
  display: grid;
  gap: 10px;
}

.award-status-panel {
  border: 1px solid #d8ebff;
  box-shadow: 0 16px 34px rgba(8, 48, 104, .14);
  position: relative;
}

.award-status-panel::before {
  background: linear-gradient(90deg, #0b7fe8, #42b5ff);
  content: "";
  height: 5px;
  inset: 0 0 auto;
  position: absolute;
}

.award-status-panel.is-claimable::before,
.award-status-panel.is-paid::before,
.award-status-panel.is-awarded::before {
  background: linear-gradient(90deg, #10b981, #8be7bd);
}

.award-status-panel.is-missed::before {
  background: linear-gradient(90deg, #ef4444, #fca5a5);
}

.award-status-panel.is-pending::before {
  background: linear-gradient(90deg, #f59e0b, #fde68a);
}

.award-status-empty {
  align-items: center;
  background: #f8fbff;
  border: 1px solid #e5eef9;
  border-radius: 16px;
  display: grid;
  gap: 12px;
  grid-template-columns: 46px minmax(0, 1fr);
  padding: 13px;
}

.award-status-empty i {
  align-items: center;
  background: #e8f4ff;
  border-radius: 16px;
  color: #0875df;
  display: flex;
  font-size: 22px;
  height: 46px;
  justify-content: center;
  width: 46px;
}

.award-status-panel.is-claimable .award-status-empty,
.award-status-panel.is-paid .award-status-empty,
.award-status-panel.is-awarded .award-status-empty {
  background: #f0fdf4;
  border-color: #bbf7d0;
}

.award-status-panel.is-claimable .award-status-empty i,
.award-status-panel.is-paid .award-status-empty i,
.award-status-panel.is-awarded .award-status-empty i {
  background: #dcfce7;
  color: #059669;
}

.award-status-panel.is-missed .award-status-empty {
  background: #fff5f5;
  border-color: #fecaca;
}

.award-status-panel.is-missed .award-status-empty i {
  background: #fee2e2;
  color: #dc2626;
}

.award-status-panel.is-pending .award-status-empty {
  background: #fffbeb;
  border-color: #fde68a;
}

.award-status-panel.is-pending .award-status-empty i {
  background: #fef3c7;
  color: #d97706;
}

.award-status-empty strong {
  color: #111827;
  display: block;
  font-size: 16px;
  font-weight: 900;
  line-height: 1.25;
}

.award-status-empty p {
  color: #667085;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.45;
  margin: 4px 0 0;
}

.award-row {
  align-items: center;
  background: linear-gradient(135deg, #f8fbff, #ffffff);
  border: 1px solid #e1ecf8;
  border-radius: 16px;
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) auto;
  padding: 13px;
}

.award-row strong {
  color: #1f2937;
  display: block;
  font-size: 14px;
  font-weight: 900;
}

.award-row small {
  color: #7a8797;
  font-size: 12px;
  font-weight: 700;
}

.award-amount {
  background: #ecfdf3;
  border: 1px solid #bbf7d0;
  border-radius: 14px;
  color: #047857;
  font-size: 22px;
  font-weight: 900;
  line-height: 1.05;
  min-width: 128px;
  padding: 10px 12px;
  text-align: right;
  white-space: nowrap;
}

.award-row .outline-pill {
  grid-column: 1 / -1;
  justify-self: stretch;
  min-height: 42px;
}

.cashback-hero {
  background: linear-gradient(135deg, #e8f4ff, #f7fbff);
  border: 1px solid #d8ebff;
  border-radius: 18px;
  display: grid;
  gap: 6px;
  padding: 16px;
}

.cashback-hero span {
  color: #0875df;
  font-size: 13px;
  font-weight: 900;
}

.cashback-hero strong {
  color: #111827;
  font-size: 21px;
  font-weight: 900;
  line-height: 1.25;
}

.cashback-hero p {
  color: #667085;
  font-size: 13px;
  font-weight: 700;
  line-height: 1.45;
  margin: 0;
}

.cashback-expected-card {
  background: linear-gradient(135deg, #0b7fe8, #0d6bd9);
  border-radius: 18px;
  box-shadow: 0 12px 24px rgba(11, 127, 232, .18);
  color: #fff;
  display: grid;
  gap: 5px;
  padding: 16px;
}

.cashback-expected-card span,
.cashback-expected-card small {
  color: rgba(255, 255, 255, .82);
  font-size: 12px;
  font-weight: 800;
  line-height: 1.35;
}

.cashback-expected-card strong {
  color: #fff;
  font-size: 28px;
  font-weight: 900;
  line-height: 1.05;
}

.cashback-detail-list {
  border: 1px solid #e5ebf3;
  border-radius: 16px;
  display: grid;
  overflow: hidden;
}

.cashback-detail-list div {
  align-items: start;
  display: grid;
  gap: 10px;
  grid-template-columns: 108px minmax(0, 1fr);
  padding: 13px 14px;
}

.cashback-detail-list div + div {
  border-top: 1px solid #edf2f7;
}

.cashback-detail-list span {
  color: #7a8797;
  font-size: 12px;
  font-weight: 800;
}

.cashback-detail-list strong {
  color: #1f2937;
  font-size: 13px;
  font-weight: 900;
  line-height: 1.45;
}

.cashback-payout-options {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.cashback-payout-options button {
  align-items: center;
  background: #f8fafc;
  border: 1px solid #dce6f2;
  border-radius: 16px;
  color: #1f2937;
  display: grid;
  gap: 10px;
  grid-template-columns: 40px minmax(0, 1fr);
  min-height: 78px;
  padding: 12px;
  text-align: left;
}

.cashback-payout-options i {
  align-items: center;
  background: #e8f4ff;
  border-radius: 14px;
  color: #0875df;
  display: flex;
  font-size: 20px;
  height: 40px;
  justify-content: center;
  width: 40px;
}

.cashback-payout-options span {
  display: grid;
  gap: 2px;
}

.cashback-payout-options strong {
  color: #111827;
  font-size: 14px;
  font-weight: 900;
}

.cashback-payout-options small {
  color: #7a8797;
  font-size: 12px;
  font-weight: 800;
  line-height: 1.35;
}

.claim-error {
  background: #fee2e2;
  border-radius: 12px;
  color: #b42318;
  font-size: 13px;
  font-weight: 800;
  margin: 0;
  padding: 10px 12px;
}

.activity-detail-empty {
  display: grid;
  gap: 12px;
  justify-items: center;
  padding: 34px 24px;
  text-align: center;
}

.activity-detail-empty h1 {
  color: #1f2937;
  font-size: 24px;
  font-weight: 900;
  margin: 0;
}

.number-confirm-backdrop {
  align-items: center;
  background: rgba(15, 23, 42, .58);
  display: flex;
  inset: 0;
  justify-content: center;
  overflow: hidden auto;
  padding: 20px;
  position: fixed;
  z-index: 1060;
}

.number-confirm-modal {
  background: #fff;
  border-radius: 22px;
  box-sizing: border-box;
  box-shadow: 0 24px 48px rgba(15, 23, 42, .24);
  display: grid;
  gap: 14px;
  max-width: 340px;
  min-width: 0;
  padding: 22px;
  position: relative;
  text-align: center;
  width: min(100%, 340px);
}

.number-confirm-close {
  align-items: center;
  background: #f1f5f9;
  border: 0;
  border-radius: 999px;
  color: #475569;
  display: flex;
  height: 34px;
  justify-content: center;
  position: absolute;
  right: 12px;
  top: 12px;
  width: 34px;
}

.number-confirm-modal .activity-type {
  justify-self: center;
}

.number-confirm-modal h3 {
  color: #111827;
  font-size: 21px;
  font-weight: 900;
  line-height: 1.25;
  margin: 0;
}

.confirm-number {
  background: linear-gradient(135deg, #1488f5, #0568d9);
  border-radius: 18px;
  box-shadow: 0 12px 24px rgba(5, 104, 217, .22);
  color: #fff;
  font-size: 44px;
  font-weight: 900;
  letter-spacing: .08em;
  line-height: 1;
  padding: 22px 16px;
}

.number-confirm-modal p {
  color: #667085;
  font-size: 14px;
  font-weight: 800;
  line-height: 1.5;
  margin: 0;
}

.number-confirm-actions {
  display: grid;
  gap: 10px;
  grid-template-columns: 1fr 1fr;
}

.claim-backdrop {
  padding: max(12px, env(safe-area-inset-top)) 12px max(12px, env(safe-area-inset-bottom));
  z-index: 1080;
}

.claim-modal {
  gap: 13px;
  max-height: calc(100vh - 44px);
  max-width: min(390px, calc(100vw - 24px));
  overflow: hidden auto;
  text-align: left;
  width: min(390px, calc(100vw - 24px));
}

.claim-modal > * {
  min-width: 0;
}

.claim-modal .activity-type {
  justify-self: start;
}

.claim-modal h3 {
  font-size: clamp(18px, 5.2vw, 21px);
  padding-right: 32px;
}

.claim-amount-card {
  background: linear-gradient(135deg, #0b7fe8, #0d6bd9);
  border-radius: 18px;
  color: #fff;
  display: grid;
  gap: 4px;
  padding: 16px;
}

.claim-amount-card span {
  color: rgba(255, 255, 255, .82);
  font-size: 12px;
  font-weight: 900;
}

.claim-amount-card strong {
  color: #fff;
  font-size: clamp(22px, 7vw, 28px);
  font-weight: 900;
  line-height: 1.05;
  overflow-wrap: anywhere;
}

.claim-payout-options {
  display: grid;
  gap: 10px;
}

.claim-payout-options button {
  align-items: center;
  background: #f8fafc;
  border: 1px solid #dce6f2;
  border-radius: 16px;
  color: #1f2937;
  display: grid;
  gap: 12px;
  grid-template-columns: 22px minmax(0, 1fr) 42px;
  min-height: 72px;
  padding: 12px;
  text-align: left;
}

.claim-payout-options button:disabled {
  opacity: .64;
}

.claim-payout-options button.active {
  background: #eff7ff;
  border-color: #0b7fe8;
  box-shadow: inset 0 0 0 1px rgba(11, 127, 232, .18);
}

.claim-radio {
  border: 2px solid #d0d7e2;
  border-radius: 999px;
  height: 18px;
  position: relative;
  width: 18px;
}

.claim-payout-options button.active .claim-radio {
  background: #0b7fe8;
  border-color: #0b7fe8;
}

.claim-payout-options button.active .claim-radio::after {
  background: #fff;
  border-radius: 999px;
  content: "";
  height: 6px;
  inset: 4px;
  position: absolute;
  width: 6px;
}

.claim-payout-options strong,
.claim-bank-preview strong {
  color: #111827;
  display: block;
  font-size: 15px;
  font-weight: 900;
  line-height: 1.25;
}

.claim-payout-options small,
.claim-bank-preview span {
  color: #667085;
  display: block;
  font-size: 12px;
  font-weight: 800;
  line-height: 1.35;
  margin-top: 3px;
}

.claim-option-icon {
  align-items: center;
  border-radius: 14px;
  display: flex;
  font-size: 20px;
  font-weight: 900;
  height: 42px;
  justify-content: center;
  width: 42px;
}

.claim-option-icon.wallet {
  background: #dbeafe;
  color: #0b7fe8;
}

.claim-option-icon.bank {
  background: #f3e8ff;
  color: #7c3aed;
}

.claim-bank-preview {
  align-items: center;
  background: #f8fbff;
  border: 1px solid #dce8f5;
  border-radius: 16px;
  display: grid;
  gap: 12px;
  grid-template-columns: 42px minmax(0, 1fr);
  padding: 12px;
}

.claim-bank-preview.missing {
  background: #fff7ed;
  border-color: #fed7aa;
}

.claim-bank-preview i {
  align-items: center;
  background: #e8f4ff;
  border-radius: 14px;
  color: #0875df;
  display: flex;
  font-size: 20px;
  height: 42px;
  justify-content: center;
  width: 42px;
}

.claim-bank-preview.missing i {
  background: #ffedd5;
  color: #ea580c;
}

.claim-bank-link {
  background: #e8f4ff;
  border-radius: 14px;
  color: #0875df;
  font-size: 13px;
  font-weight: 900;
  padding: 12px 14px;
  text-align: center;
  text-decoration: none;
}

.claim-actions {
  margin-top: 2px;
}

@media (max-width: 380px) {
  .rights-box,
  .cashback-grid,
  .cashback-payout-options {
    grid-template-columns: 1fr;
  }

  .number-board-scroll {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .number-board-scroll.three {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .cashback-detail-list div {
    grid-template-columns: 1fr;
  }

  .number-confirm-actions {
    grid-template-columns: 1fr;
  }

  .award-row {
    grid-template-columns: 1fr;
  }

  .award-amount {
    justify-self: stretch;
    min-width: 0;
    text-align: left;
  }

  .lucky-result-header,
  .customer-winning-strip {
    align-items: flex-start;
    flex-direction: column;
  }

  .lucky-result-header strong {
    text-align: left;
  }
}

@media (max-width: 420px) {
  .claim-modal {
    border-radius: 20px;
    gap: 12px;
    padding: 18px;
  }

  .claim-actions {
    grid-template-columns: 1fr;
  }

  .claim-payout-options button {
    grid-template-columns: 20px minmax(0, 1fr) 38px;
    min-height: 66px;
  }

  .claim-amount-card {
    border-radius: 16px;
    padding: 14px;
  }
}
</style>

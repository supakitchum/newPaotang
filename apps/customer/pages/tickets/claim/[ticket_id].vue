<template>
  <PinKeypadScreen
    v-if="claimStep === 'pin'"
    title="ใส่รหัส PIN 6 หลัก"
    subtitle="เพื่อทำรายการต่อ"
    :digits="pinDigits"
    :error="claimPinError"
    :disabled="isSubmitting"
    @append="appendPinDigit"
    @remove="removePinDigit"
    @back="claimStep = 'confirm'"
  />

  <MobileShell v-else active-nav="tickets">
      <header class="reward-flow-header" :class="{ compact: claimStep === 'processing', processing: claimStep === 'processing', select: claimStep === 'select' }">
        <button v-if="claimStep !== 'processing'" class="reward-flow-back" type="button" aria-label="กลับ" @click="handleBack">
          <i class="bi bi-chevron-left" />
        </button>
        <h1 v-if="claimStep !== 'processing'">{{ stepTitle }}</h1>
        <article v-if="showSelectLotteryCard" class="reward-lottery-card reward-lottery-card-hero">
          <div class="reward-lottery-card-head">
            <span class="reward-lottery-logo">GLO</span>
            <div>
              <strong>สลากกินแบ่งรัฐบาล</strong>
              <span>{{ gameDateText }}</span>
            </div>
          </div>
          <dl>
            <div>
              <dt>เลขสลากดิจิทัล</dt>
              <dd>{{ ticketNumber || '-' }}</dd>
            </div>
            <div>
              <dt>รางวัล</dt>
              <dd class="blue prize">
                <template v-if="rewardPrizes.length > 1">
                  <span v-for="(prize, index) in rewardPrizes" :key="`${prize.prize_type || index}-${prize.prize_number || index}`">
                    {{ prize.title }} {{ formatMoney(prize.amount) }} บาท
                  </span>
                </template>
                <template v-else>
                  <span>{{ prizeTitle }}</span>
                  <span>{{ formattedPrizeAmountText }}</span>
                </template>
              </dd>
            </div>
            <hr class="reward-lottery-card-divider" aria-hidden="true">
            <div class="reward-lottery-money-row">
              <dt>เงินรางวัล</dt>
              <dd class="amount">{{ formattedPrizeAmountText }}</dd>
            </div>
          </dl>
        </article>
      </header>

      <section class="content-sheet reward-claim-page" :class="{ confirm: claimStep === 'confirm', processing: claimStep === 'processing', select: claimStep === 'select' }">
        <div v-if="isLoading" class="empty-lottery-state">
          กำลังโหลดข้อมูลรางวัล...
        </div>

        <div v-else-if="loadError" class="empty-lottery-state text-danger">
          {{ loadError }}
        </div>

        <template v-else>
          <article v-if="existingClaimId" class="reward-claim-card">
            <div class="reward-claim-card-head">
              <i class="bi bi-check2-circle" />
              <div>
                <h2>มีรายการขึ้นเงินแล้ว</h2>
                <p>ติดตามสถานะรายการนี้ได้จากหน้ารายละเอียด</p>
              </div>
            </div>
            <NuxtLink class="primary-pill reward-claim-submit" :to="existingClaimTo">
              ดูรายการขึ้นเงิน
            </NuxtLink>
          </article>

          <template v-else-if="claimStep === 'select'">
            <section class="reward-claim-card reward-payout-card">
              <header class="reward-payout-card-header">
                <h2>ช่องทางขึ้นเงินรางวัล</h2>
              </header>

              <div class="reward-payout-card-body">
                <div v-if="!isClaimable" class="reward-claim-alert">
                  <i class="bi bi-info-circle" />
                  <span>{{ unavailableMessage }}</span>
                </div>

                <div class="reward-payout-options">
                  <button
                    class="reward-payout-option"
                    :class="{ active: payoutMethod === 'wallet_credit' }"
                    type="button"
                    :disabled="!isClaimable || isSubmitting"
                    @click="payoutMethod = 'wallet_credit'"
                  >
                    <span class="reward-radio" />
                    <div>
                      <strong>{{ walletOptionTitle }}</strong>
                      <small>รับเงินเข้า G-Wallet ภายใน 2 ชม.</small>
                    </div>
                    <span class="reward-option-icon wallet">G</span>
                  </button>

                  <button
                    class="reward-payout-option"
                    :class="{ active: payoutMethod === 'bank_transfer' }"
                    type="button"
                    :disabled="!isClaimable || isSubmitting || !hasBankAccount"
                    @click="payoutMethod = 'bank_transfer'"
                  >
                    <span class="reward-radio" />
                    <div>
                      <strong class="reward-option-title">
                        {{ bankOptionTitle }}
                        <span class="reward-option-badge">แนะนำ</span>
                      </strong>
                      <small>{{ bankOptionSubtitle }}</small>
                    </div>
                    <span class="reward-option-icon bank"><i class="bi bi-bank2" /></span>
                  </button>
                </div>

                <NuxtLink v-if="!hasBankAccount" class="reward-bank-link" :to="rewardBankTo">
                  เพิ่มบัญชีรับเงินรางวัล
                </NuxtLink>
              </div>
            </section>

            <footer class="reward-claim-footer">
              <button class="primary-pill reward-claim-submit" type="button" :disabled="!canContinue" @click="claimStep = 'confirm'">
                ถัดไป
              </button>
            </footer>
          </template>

          <template v-else-if="claimStep === 'confirm'">
            <article class="reward-confirm-card">
              <div class="reward-confirm-ticket">
                <span class="reward-lottery-logo">GLO</span>
                <div>
                  <strong>สลากกินแบ่งรัฐบาล</strong>
                  <span>{{ gameDateText }}</span>
                </div>
              </div>

              <div class="reward-confirm-image-panel">
                <LotteryImage
                  :src="ticketImageUrl"
                  :status="ticketImageStatus"
                  :error-message="ticketImageError"
                  :number="ticketNumber"
                  variant="preview"
                />
              </div>

              <dl class="reward-confirm-list">
                <div>
                  <dt>ผู้รับเงิน</dt>
                  <dd class="blue">{{ receiverName }}</dd>
                </div>
                <div>
                  <dt>ช่องทางขึ้นเงินรางวัล</dt>
                  <dd class="blue reward-payout-lines">
                    <span v-for="line in payoutChannelLines" :key="line">{{ line }}</span>
                  </dd>
                </div>
                <div>
                  <dt>วิธีขึ้นเงินรางวัล</dt>
                  <dd class="blue">ขึ้นเงินรางวัลด้วยตนเอง</dd>
                </div>
                <div>
                  <dt>เลขสลากดิจิทัล</dt>
                  <dd>{{ ticketNumber || '-' }}</dd>
                </div>
                <div>
                  <dt>รางวัล</dt>
                  <dd>
                    <span v-for="(prize, index) in rewardPrizes" :key="`${prize.prize_type || index}-${prize.prize_number || index}`" class="reward-prize-line">
                      {{ prize.title }} {{ formatMoney(prize.amount) }} บาท
                    </span>
                  </dd>
                </div>
              </dl>

              <dl class="reward-confirm-money">
                <div>
                  <dt>เงินรางวัล</dt>
                  <dd>{{ formatMoney(prizeAmount) }} บาท</dd>
                </div>
                <div class="discount">
                  <dt>ค่าภาษีถอนเงิน (0.5%)</dt>
                  <dd>
                    <span><s>{{ formatMoney(taxAmount) }} บาท</s> ลดให้ {{ formatMoney(taxAmount) }} บาท</span>
                    <strong>0 บาท</strong>
                  </dd>
                </div>
                <div class="discount">
                  <dt>ค่าธรรมเนียม (1%)</dt>
                  <dd>
                    <span><s>{{ formatMoney(feeAmount) }} บาท</s> ลดให้ {{ formatMoney(feeAmount) }} บาท</span>
                    <strong>0 บาท</strong>
                  </dd>
                </div>
                <div class="total">
                  <dt>ยอดเงินที่ได้รับ</dt>
                  <dd>{{ formatMoney(netAmount) }} บาท</dd>
                </div>
              </dl>
            </article>
            <footer class="reward-claim-footer reward-confirm-footer">
              <button class="primary-pill reward-claim-submit" type="button" :disabled="!canContinue" @click="goToPin">
                ยืนยัน
              </button>
            </footer>
          </template>

          <template v-else-if="claimStep === 'processing'">
            <article class="reward-processing-card">
              <div class="reward-processing-logo-row">
                <BrandLogo />
                <span class="lottery-six">L6</span>
              </div>
              <div class="reward-processing-status-icon">
                <i class="bi bi-clock-history" />
              </div>
              <h2>กำลังดำเนินการโอนเงินรางวัล</h2>
              <p class="reward-processing-note">
                เงินรางวัลจะถึงบัญชีผู้รับเงิน ภายใน 2 ชั่วโมง หลังจากทำรายการสำเร็จ
              </p>

              <dl class="reward-confirm-list reward-processing-list">
                <div>
                  <dt>ผู้รับเงิน</dt>
                  <dd class="blue">{{ receiverName }}</dd>
                </div>
                <div>
                  <dt>ช่องทางขึ้นเงินรางวัล</dt>
                  <dd class="blue reward-payout-lines">
                    <span v-for="line in payoutChannelLines" :key="line">{{ line }}</span>
                  </dd>
                </div>
                <div>
                  <dt>วิธีขึ้นเงินรางวัล</dt>
                  <dd class="blue">ขึ้นเงินรางวัลด้วยตนเอง</dd>
                </div>
                <div>
                  <dt>สลากฯ งวดวันที่</dt>
                  <dd>{{ gameDatePlainText }}</dd>
                </div>
                <div>
                  <dt>เลขสลากดิจิทัล</dt>
                  <dd>{{ ticketNumber || '-' }}</dd>
                </div>
                <div>
                  <dt>งวดที่</dt>
                  <dd>{{ ticketDrawText }}</dd>
                </div>
                <div>
                  <dt>ชุดที่</dt>
                  <dd>{{ ticketSetText }}</dd>
                </div>
                <div>
                  <dt>รางวัล</dt>
                  <dd>
                    <span v-for="(prize, index) in rewardPrizes" :key="`${prize.prize_type || index}-${prize.prize_number || index}`" class="reward-prize-line">
                      {{ prize.title }} {{ formatMoney(prize.amount) }} บาท
                    </span>
                  </dd>
                </div>
              </dl>

              <dl class="reward-confirm-money reward-processing-money">
                <div>
                  <dt>เงินรางวัล</dt>
                  <dd>{{ formatMoney(prizeAmount) }} บาท</dd>
                </div>
                <div class="discount">
                  <dt>ค่าภาษีถอนเงิน (0.5%)</dt>
                  <dd>
                    <span><s>{{ formatMoney(taxAmount) }} บาท</s> ลดให้ {{ formatMoney(taxAmount) }} บาท</span>
                    <strong>0 บาท</strong>
                  </dd>
                </div>
                <div class="discount">
                  <dt>ค่าธรรมเนียม (1%)</dt>
                  <dd>
                    <span><s>{{ formatMoney(feeAmount) }} บาท</s> ลดให้ {{ formatMoney(feeAmount) }} บาท</span>
                    <strong>0 บาท</strong>
                  </dd>
                </div>
              </dl>
              <p class="reward-processing-date">
                วันที่ทำรายการ {{ processingSubmittedAtText }}
              </p>
            </article>
            <footer class="reward-claim-footer reward-processing-footer">
              <NuxtLink class="primary-pill reward-claim-submit" to="/tickets">
                ดูสลากฯ ของฉัน
              </NuxtLink>
            </footer>
          </template>
        </template>
      </section>
  </MobileShell>
</template>

<script setup lang="ts">
import type { UserTicket } from '~/composables/useUserTickets'
import { rewardAmountToDisplayNumber } from '~/composables/usePlatformApi'

definePageMeta({
  requiresAuth: true
})

type ClaimStep = 'select' | 'confirm' | 'pin' | 'processing'
type PayoutMethod = 'wallet_credit' | 'bank_transfer'

const route = useRoute()
const platformApi = usePlatformApi()
const { restoreAuthState } = useAuth()
const { showAlert } = useAppAlert()
const {
  getTicketNumber,
  getTicketPrizeAmount,
  getTicketRewardPrizes,
  getTicketPrizeTitle,
  getTicketDraw,
  getTicketSet,
  getTicketGameDate
} = useUserTickets()

const ticket = ref<UserTicket | null>(null)
const rewardStatus = ref<Record<string, any> | null>(null)
const profile = ref<Record<string, any> | null>(null)
const submittedClaim = ref<Record<string, any> | null>(null)
const isLoading = ref(true)
const isSubmitting = ref(false)
const loadError = ref('')
const payoutMethod = ref<PayoutMethod>('wallet_credit')
const claimStep = ref<ClaimStep>('select')
const pinDigits = ref('')
const claimPinError = ref('')

const ticketId = computed(() => {
  const value = Array.isArray(route.params.ticket_id) ? route.params.ticket_id[0] : route.params.ticket_id

  return String(value || '')
})
const backTo = computed(() => typeof route.query.from === 'string' && route.query.from === 'history' ? '/tickets/history' : '/tickets')
const stepTitle = computed(() => claimStep.value === 'confirm' ? 'ยืนยันการขึ้นเงินรางวัล' : 'ขึ้นเงินรางวัล')
const ticketNumber = computed(() => getTicketNumber(ticket.value))
const mergedRewardStatus = computed(() => ({
  ...(ticket.value?.reward_status || {}),
  ...(rewardStatus.value || {})
}))
const rewardPrizes = computed(() => getTicketRewardPrizes({
  ...(ticket.value || {}),
  reward_status: mergedRewardStatus.value
}))
const prizeAmount = computed(() => {
  if (rewardPrizes.value.length > 0) {
    return rewardPrizes.value.reduce((total, prize) => total + Number(prize.amount || 0), 0)
  }

  const prizeType = mergedRewardStatus.value.prize_type || ticket.value?.prize_type || ''

  return rewardAmountToDisplayNumber(
    mergedRewardStatus.value.prize_amount ?? ticket.value?.prize_amount,
    getTicketPrizeAmount(ticket.value),
    prizeType
  )
})
const formattedPrizeAmount = computed(() => prizeAmount.value > 0 ? prizeAmount.value.toLocaleString('th-TH') : '')
const formattedPrizeAmountText = computed(() => formattedPrizeAmount.value ? `${formattedPrizeAmount.value} บาท` : '-')
const prizeTitle = computed(() => {
  if (rewardPrizes.value.length > 1) {
    return `ถูกรางวัล ${rewardPrizes.value.length.toLocaleString('th-TH')} รางวัล`
  }

  if (rewardPrizes.value.length === 1) {
    return rewardPrizes.value[0].title
  }

  return getPrizeTitle(mergedRewardStatus.value.prize_type || ticket.value?.prize_type) || getTicketPrizeTitle(ticket.value) || 'ถูกรางวัล'
})
const isClaimable = computed(() => Boolean(rewardStatus.value?.claimable ?? ticket.value?.reward_status?.claimable ?? ticket.value?.claimable))
const rewardStatusValue = computed(() => String(rewardStatus.value?.status || ticket.value?.reward_status?.status || '').toLowerCase())
const claimStatusValue = computed(() => String(
  rewardStatus.value?.claim_status ||
  ticket.value?.reward_status?.claim_status ||
  rewardStatus.value?.status ||
  ticket.value?.reward_status?.status ||
  ''
).toLowerCase())
const rawExistingClaimId = computed(() => String(rewardStatus.value?.reward_claim_id || ticket.value?.reward_status?.reward_claim_id || '').trim())
const existingClaimId = computed(() => {
  const claimId = rawExistingClaimId.value

  if (!claimId) {
    return ''
  }

  if (isClaimable.value && ['rejected', 'cancelled'].includes(claimStatusValue.value)) {
    return ''
  }

  return claimId
})
const existingClaimTo = computed(() => existingClaimId.value ? `/reward-claims/${encodeURIComponent(existingClaimId.value)}` : '')
const showSelectLotteryCard = computed(() => claimStep.value === 'select' && !isLoading.value && !loadError.value && !existingClaimId.value)
const unavailableMessage = computed(() => {
  if (rewardStatusValue.value === 'pending_result') {
    return 'สลากใบนี้ยังรอออกผล'
  }

  if (rewardStatusValue.value === 'non_winning') {
    return 'สลากใบนี้ไม่ถูกรางวัลในงวดนี้'
  }

  if (rewardStatusValue.value === 'winning') {
    return 'พบรายการถูกรางวัลแล้ว แต่ยังรอเปิดให้ขึ้นเงินอย่างเป็นทางการ'
  }

  return 'รายการนี้ยังไม่สามารถขึ้นเงินได้'
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
const maskedAccountNumber = computed(() => maskAccountNumber(bankAccount.value.account_number))
const bankDisplayName = computed(() => bankAccount.value.bank_name.replace(/^ธนาคาร/, 'บัญชี') || 'บัญชีธนาคาร')
const bankOptionTitle = computed(() => hasBankAccount.value ? `${bankDisplayName.value} x ${accountLast4.value}` : 'บัญชีธนาคาร')
const bankOptionSubtitle = computed(() => hasBankAccount.value
  ? 'รับเงินเข้าบัญชีธนาคาร ภายใน 2 ชม.'
  : 'เพิ่มบัญชีรับเงินรางวัลก่อนเลือกช่องทางนี้'
)
const walletOptionTitle = computed(() => `G Wallet x ${walletSuffix.value}`)
const walletSuffix = computed(() => {
  const value = String(profile.value?.wallet?.id || profile.value?.primary_wallet?.id || profile.value?.wallet_id || '123').replace(/\D/g, '')

  return value.slice(-3).padStart(3, '0')
})
const accountLast4 = computed(() => {
  const number = bankAccount.value.account_number.replace(/\D/g, '')

  return number.slice(-4) || '----'
})
const receiverName = computed(() => String(profile.value?.name || profile.value?.full_name || profile.value?.display_name || 'ผู้ใช้งาน'))
const payoutChannelLines = computed(() => {
  if (payoutMethod.value === 'bank_transfer') {
    return [
      bankAccount.value.bank_name || bankDisplayName.value || 'บัญชีธนาคาร',
      `หมายเลขบัญชี ${maskedAccountNumber.value}`
    ]
  }

  return [walletOptionTitle.value]
})
const rewardBankTo = computed(() => `/profile/reward-bank?redirect=${encodeURIComponent(route.fullPath)}`)
const canContinue = computed(() => (
  isClaimable.value &&
  !isSubmitting.value &&
  Boolean(ticketId.value) &&
  (payoutMethod.value !== 'bank_transfer' || hasBankAccount.value)
))
const taxAmount = computed(() => Math.round(prizeAmount.value * 0.005))
const feeAmount = computed(() => Math.round(prizeAmount.value * 0.01))
const netAmount = computed(() => prizeAmount.value)
const ticketSetText = computed(() => getTicketSet(ticket.value))
const ticketDrawText = computed(() => getTicketDraw(ticket.value))
const ticketImageUrl = computed(() => ticket.value?.image_url || ticket.value?.image || '')
const ticketImageStatus = computed(() => ticket.value?.image_status || '')
const ticketImageError = computed(() => ticket.value?.image_error || '')
const gameDatePlainText = computed(() => getTicketGameDate(ticket.value) || '-')
const gameDateText = computed(() => `งวดวันที่ ${gameDatePlainText.value}`)
const processingSubmittedAtText = computed(() => formatDateTime(
  submittedClaim.value?.submitted_at ||
  submittedClaim.value?.created_at ||
  submittedClaim.value?.updated_at
))

const getPrizeTitle = (value: unknown) => {
  const prizeTypeLabels: Record<string, string> = {
    first_prize: 'รางวัลที่ 1',
    near_first_prize: 'รางวัลข้างเคียงรางวัลที่ 1',
    second_prize: 'รางวัลที่ 2',
    third_prize: 'รางวัลที่ 3',
    fourth_prize: 'รางวัลที่ 4',
    fifth_prize: 'รางวัลที่ 5',
    front3: 'รางวัลเลขหน้า 3 ตัว',
    back3: 'รางวัลเลขท้าย 3 ตัว',
    back2: 'รางวัลเลขท้าย 2 ตัว'
  }
  const key = String(value || '').trim()

  return prizeTypeLabels[key] || ''
}

const formatMoney = (amount: unknown) => {
  const value = Number(amount || 0)

  return Number.isFinite(value) ? value.toLocaleString('th-TH') : '0'
}

const formatDateTime = (value: unknown) => {
  const rawValue = value || new Date().toISOString()
  const date = new Date(String(rawValue))

  if (Number.isNaN(date.getTime())) {
    return '-'
  }

  return new Intl.DateTimeFormat('th-TH', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).format(date).replace(',', '')
}

const maskAccountNumber = (value: unknown) => {
  const number = String(value || '').replace(/\D/g, '')

  if (number.length <= 4) {
    return number || 'x xxx9'
  }

  return `x xxx${number.slice(-4)}`
}

const bankAccountFromProfile = (value: Record<string, any> | null | undefined) => {
  const bank = value?.reward_payout_bank_account || value?.bank_account || {}

  return {
    bank_name: String(bank.bank_name || bank.bank || ''),
    account_number: String(bank.account_number || bank.account_no || bank.bank_account_no || bank.bank_deposit_number || '')
  }
}

const handleBack = () => {
  if (claimStep.value === 'confirm') {
    claimStep.value = 'select'
    return
  }

  navigateTo(backTo.value)
}

const goToPin = () => {
  if (!canContinue.value) {
    return
  }

  pinDigits.value = ''
  claimPinError.value = ''
  claimStep.value = 'pin'
}

const appendPinDigit = async (digit: string) => {
  if (!digit || pinDigits.value.length >= 6 || isSubmitting.value) {
    return
  }

  claimPinError.value = ''
  pinDigits.value += digit

  if (pinDigits.value.length === 6) {
    await submitClaim()
  }
}

const removePinDigit = () => {
  claimPinError.value = ''
  pinDigits.value = pinDigits.value.slice(0, -1)
}

const loadClaimContext = async () => {
  isLoading.value = true
  loadError.value = ''

  try {
    const [ticketResult, rewardStatusResult, profileResult] = await Promise.allSettled([
      platformApi.ticketDetail(ticketId.value),
      platformApi.ticketRewardStatus(ticketId.value),
      restoreAuthState(true)
    ])

    if (ticketResult.status === 'fulfilled') {
      ticket.value = ticketResult.value
    }

    if (rewardStatusResult.status === 'fulfilled') {
      rewardStatus.value = rewardStatusResult.value
      if (ticket.value) {
        ticket.value = {
          ...ticket.value,
          reward_status: {
            ...(ticket.value.reward_status || {}),
            ...rewardStatusResult.value
          }
        }
      }
    }

    if (profileResult.status === 'fulfilled') {
      profile.value = profileResult.value || {}
      const bank = bankAccountFromProfile(profile.value)
      if (bank.bank_name && bank.account_number) {
        payoutMethod.value = 'bank_transfer'
      }
    }

    if (!ticket.value && ticketResult.status === 'rejected') {
      throw ticketResult.reason
    }
  } catch (error: any) {
    loadError.value = error?.response?.data?.message || 'โหลดข้อมูลขึ้นเงินไม่สำเร็จ'
  } finally {
    isLoading.value = false
  }
}

const submitClaim = async () => {
  if (!canContinue.value || isSubmitting.value) {
    return
  }

  isSubmitting.value = true
  try {
    const claimResult = await platformApi.createRewardClaim({
      ticket_id: ticketId.value,
      payout_method: payoutMethod.value,
      pin: pinDigits.value,
      ...(payoutMethod.value === 'bank_transfer' ? { bank_account: bankAccount.value } : {})
    })
    submittedClaim.value = {
      ...(claimResult || {}),
      submitted_at: claimResult?.submitted_at || claimResult?.created_at || new Date().toISOString()
    }

    claimStep.value = 'processing'
  } catch (error: any) {
    pinDigits.value = ''
    const code = error?.response?.data?.error?.code || error?.response?.data?.code

    if (error?.response?.status === 409) {
      await loadClaimContext()
      claimStep.value = 'select'
    }

    if (code === 'pin_invalid') {
      claimPinError.value = 'PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง'
      return
    }

    if (code === 'pin_locked') {
      claimPinError.value = 'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่แล้วลองใหม่'
      return
    }

    if (code === 'pin_setup_required') {
      claimPinError.value = 'กรุณาตั้งค่า PIN ก่อนทำรายการ'
      return
    }

    showAlert({
      title: 'ส่งรายการไม่สำเร็จ',
      message: error?.response?.status === 409 ? 'รายการนี้อาจถูกส่งขึ้นเงินไว้แล้ว' : error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}

onMounted(loadClaimContext)
</script>

<style scoped>
.reward-flow-header {
  align-items: flex-start;
  background: linear-gradient(145deg, #0788f2 0%, #0064d5 100%);
  color: #fff;
  display: flex;
  justify-content: center;
  min-height: 150px;
  padding: 50px 18px 26px;
  position: relative;
}

.reward-flow-header.compact {
  min-height: 126px;
}

.reward-flow-header.processing {
  min-height: 176px;
  padding-bottom: 74px;
}

.reward-flow-header.select {
  min-height: 306px;
  padding-bottom: 104px;
}

.reward-flow-header.select h1 {
  left: 56px;
  position: absolute;
  right: 56px;
  text-align: center;
  top: 50px;
  z-index: 4;
}

.reward-flow-header h1 {
  font-size: 20px;
  font-weight: 900;
  line-height: 1.25;
  margin: 0;
}

.reward-flow-back {
  align-items: center;
  background: transparent;
  border: 0;
  color: #fff;
  display: inline-flex;
  font-size: 26px;
  height: 40px;
  justify-content: center;
  left: 12px;
  padding: 0;
  position: absolute;
  top: 43px;
  width: 40px;
}

.reward-claim-page {
  display: grid;
  gap: 14px;
  margin-left: auto;
  margin-right: auto;
  margin-top: -34px;
  max-width: 640px;
  padding-bottom: 32px;
}

.reward-claim-page.select {
  align-content: start;
  background: #f2f3f5;
  border-radius: 0;
  gap: 10px;
  margin-top: 0;
  min-height: calc(100dvh - 306px);
  padding: 12px 12px calc(92px + env(safe-area-inset-bottom));
}

.reward-claim-page.processing {
  background: transparent;
  border-radius: 0;
  margin-top: -122px;
  min-height: calc(100dvh - 176px);
  padding: 0 12px calc(92px + env(safe-area-inset-bottom));
}

.reward-claim-page.confirm {
  padding-bottom: calc(94px + env(safe-area-inset-bottom));
}

.reward-claim-card,
.reward-lottery-card,
.reward-confirm-card,
.reward-processing-card {
  background: #fff;
  border: 1px solid #e5edf8;
  border-radius: 8px;
  box-shadow: 0 10px 24px rgba(22, 46, 82, .08);
  display: grid;
  gap: 14px;
  padding: 16px;
}

.reward-lottery-card-hero {
  bottom: 10px;
  gap: 12px;
  left: 14px;
  margin: 0 auto;
  max-width: 612px;
  padding: 14px;
  position: absolute;
  right: 14px;
  width: auto;
  z-index: 3;
}

.reward-lottery-card-hero dl {
  gap: 8px;
}

.reward-lottery-card-hero dl div {
  gap: 8px;
}

.reward-lottery-card-hero dd.amount {
  font-size: 20px;
}

.reward-payout-card {
  background: transparent;
  border: 0;
  border-radius: 0;
  box-shadow: none;
  gap: 0;
  padding: 0;
}

.reward-payout-card-header {
  background: #fff;
  border-bottom: 1px solid #e3e8ef;
  margin: -12px -12px 12px;
  padding: 13px 14px 12px;
}

.reward-payout-card-body {
  display: grid;
  gap: 10px;
}

.reward-claim-card-head {
  align-items: flex-start;
  display: flex;
  gap: 12px;
}

.reward-claim-card-head i {
  color: #16a34a;
  font-size: 26px;
}

.reward-claim-card h2,
.reward-processing-card h2 {
  color: #111827;
  font-size: 17px;
  font-weight: 900;
  margin: 0;
}

.reward-payout-card-header h2 {
  color: #111827;
  font-size: 13px;
  line-height: 1.25;
  margin: 0;
}

.reward-claim-card p {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
  margin: 4px 0 0;
}

.reward-lottery-card-head,
.reward-confirm-ticket,
.reward-processing-brand {
  align-items: center;
  display: flex;
  gap: 10px;
}

.reward-lottery-logo {
  align-items: center;
  border: 1px solid #dbeafe;
  border-radius: 50%;
  color: #0b69dc;
  display: inline-flex;
  flex: 0 0 42px;
  font-size: 13px;
  font-weight: 900;
  height: 42px;
  justify-content: center;
  width: 42px;
}

.reward-lottery-card-head div,
.reward-confirm-ticket div {
  display: grid;
  gap: 2px;
}

.reward-lottery-card-head strong,
.reward-confirm-ticket strong {
  color: #111827;
  font-size: 14px;
  font-weight: 900;
}

.reward-lottery-card-head span,
.reward-confirm-ticket span {
  color: #64748b;
  font-size: 12px;
  font-weight: 700;
}

.reward-confirm-image-panel {
  background: #f8fafc;
  border: 1px solid #e5edf8;
  border-radius: 8px;
  padding: 8px;
}

.reward-confirm-image-panel :deep(.lottery-image-preview) {
  border-radius: 6px;
}

.reward-lottery-card dl,
.reward-confirm-list,
.reward-confirm-money {
  display: grid;
  gap: 10px;
  margin: 0;
}

.reward-lottery-card dl div,
.reward-confirm-list div,
.reward-confirm-money div {
  align-items: start;
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
}

.reward-lottery-card dt,
.reward-confirm-list dt,
.reward-confirm-money dt {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

.reward-lottery-card dd,
.reward-confirm-list dd,
.reward-confirm-money dd {
  color: #111827;
  font-size: 13px;
  font-weight: 900;
  margin: 0;
  overflow-wrap: anywhere;
  text-align: right;
}

.reward-lottery-card dd.blue,
.reward-confirm-list dd.blue {
  color: #086bdd;
}

.reward-payout-lines {
  display: grid;
  gap: 3px;
}

.reward-payout-lines span {
  line-height: 1.3;
}

.reward-lottery-card dd.prize {
  display: grid;
  gap: 2px;
}

.reward-lottery-card dd.prize span {
  color: inherit;
  font-size: 13px;
  font-weight: 900;
  line-height: 1.25;
}

.reward-prize-line {
  display: block;
  line-height: 1.35;
}

.reward-lottery-card-divider {
  background: #eef2f7;
  border: 0;
  height: 1px;
  margin: 1px 0;
  width: 100%;
}

.reward-lottery-card dd.amount {
  color: #086bdd;
  font-size: 22px;
}

.reward-lottery-money-row {
  align-items: center !important;
}

.reward-claim-alert {
  align-items: flex-start;
  background: #fff8e6;
  border: 1px solid #ffe0a3;
  border-radius: 8px;
  color: #8b5c03;
  display: flex;
  font-size: 13px;
  font-weight: 800;
  gap: 8px;
  line-height: 1.4;
  padding: 11px 12px;
}

.reward-payout-options {
  display: grid;
  gap: 10px;
}

.reward-payout-option {
  align-items: center;
  background: #fff;
  border: 1px solid #dbe4ef;
  border-radius: 8px;
  color: #17335f;
  display: grid;
  gap: 10px;
  grid-template-columns: 24px minmax(0, 1fr) 42px;
  min-height: 74px;
  padding: 12px;
  text-align: left;
}

.reward-payout-option.active {
  border-color: #0b7fea;
  box-shadow: 0 0 0 1px rgba(11, 127, 234, .12);
}

.reward-radio {
  border: 1px solid #d7dee8;
  border-radius: 50%;
  display: block;
  height: 17px;
  width: 17px;
}

.reward-payout-option.active .reward-radio {
  background: #0b7fea;
  border-color: #0b7fea;
  box-shadow: inset 0 0 0 4px #fff;
}

.reward-payout-option div {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.reward-payout-option strong {
  color: #17335f;
  font-size: 14px;
  font-weight: 900;
}

.reward-option-title {
  align-items: center;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.reward-option-badge {
  background: #dff1ff;
  border-radius: 999px;
  color: #0b69dc;
  display: inline-flex;
  font-size: 10px;
  font-weight: 900;
  line-height: 1;
  padding: 3px 7px;
}

.reward-payout-option small {
  color: #64748b;
  font-size: 11px;
  font-weight: 700;
  line-height: 1.35;
}

.reward-option-icon {
  align-items: center;
  border-radius: 10px;
  display: inline-flex;
  font-size: 18px;
  font-weight: 900;
  height: 40px;
  justify-content: center;
  width: 40px;
}

.reward-option-icon.wallet {
  background: #0b69dc;
  color: #fff;
}

.reward-option-icon.bank {
  background: #eaf4ff;
  color: #0b69dc;
}

.reward-bank-link {
  color: #075ec9;
  font-size: 13px;
  font-weight: 900;
  justify-self: start;
}

.reward-confirm-card,
.reward-processing-card {
  gap: 18px;
}

.reward-confirm-money {
  border-top: 1px solid #eef2f7;
  padding-top: 12px;
}

.reward-confirm-money .total {
  border-top: 1px solid #eef2f7;
  padding-top: 10px;
}

.reward-confirm-money .discount dd {
  display: grid;
  gap: 4px;
}

.reward-confirm-money .discount dd span {
  color: #64748b;
  font-size: 11px;
  font-weight: 800;
  line-height: 1.25;
}

.reward-confirm-money .discount dd s {
  color: #94a3b8;
  margin-right: 4px;
}

.reward-confirm-money .discount dd strong {
  color: #16a34a;
  font-size: 13px;
  font-weight: 900;
  line-height: 1.25;
}

.reward-confirm-money .total dt,
.reward-confirm-money .total dd {
  color: #111827;
  font-size: 18px;
  font-weight: 900;
}

.reward-claim-submit {
  align-items: center;
  display: inline-flex;
  justify-content: center;
  text-decoration: none;
  width: 100%;
}

.reward-claim-page > .reward-claim-footer {
  background: #fff;
  bottom: 0;
  box-shadow: 0 -8px 24px rgba(24, 42, 72, .12);
  left: 0;
  margin: 0;
  max-width: none;
  padding: 10px 14px calc(14px + env(safe-area-inset-bottom));
  position: fixed;
  right: 0;
  width: 100%;
  z-index: 26;
}

.reward-claim-footer .reward-claim-submit {
  display: flex;
  margin: 0 auto;
  max-width: 612px;
  min-height: 48px;
}

.reward-processing-card {
  background:
    repeating-linear-gradient(150deg, rgba(5, 130, 226, .035) 0 28px, transparent 28px 66px),
    #fff;
  gap: 10px;
  overflow: hidden;
  padding: 12px 12px 14px;
  position: relative;
  text-align: center;
}

.reward-processing-logo-row {
  align-items: center;
  display: flex;
  gap: 10px;
  justify-content: center;
}

.reward-processing-logo-row :deep(.brand-logo-image),
.reward-processing-logo-row :deep(.brand-logo-fallback) {
  height: 22px;
  width: auto;
}

.reward-processing-logo-row .lottery-six {
  font-size: 16px;
  line-height: 1;
}

.reward-processing-status-icon {
  align-items: center;
  background: #ffb12f;
  border-radius: 50%;
  color: #fff;
  font-size: 24px;
  height: 52px;
  display: inline-flex;
  justify-content: center;
  justify-self: center;
  width: 52px;
}

.reward-processing-card h2 {
  font-size: 15px;
  line-height: 1.25;
}

.reward-processing-note {
  background: #fff7dc;
  border-radius: 8px;
  color: #b36a00;
  font-size: 12px;
  font-weight: 800;
  line-height: 1.45;
  margin: 0;
  padding: 10px;
}

.reward-processing-list,
.reward-processing-money {
  gap: 7px;
  text-align: left;
}

.reward-processing-list div,
.reward-processing-money div {
  gap: 10px;
  grid-template-columns: minmax(112px, .82fr) minmax(0, 1fr);
}

.reward-processing-card .reward-confirm-list dt,
.reward-processing-card .reward-confirm-money dt {
  font-size: 12px;
}

.reward-processing-card .reward-confirm-list dd,
.reward-processing-card .reward-confirm-money dd {
  font-size: 12px;
}

.reward-processing-date {
  border-top: 1px solid #eef2f7;
  color: #94a3b8;
  font-size: 11px;
  font-weight: 700;
  line-height: 1.35;
  margin: 0;
  padding-top: 8px;
}

@media (max-width: 420px) {
  .reward-claim-page {
    padding-left: 14px;
    padding-right: 14px;
  }
}
</style>

<template>
  <MobileShell active-nav="menu">
    <BlueHeader
      class="reward-claim-detail-header"
      title="รายละเอียดการขึ้นเงินรางวัล"
      back-to="/reward-claims"
      force-back-to
      min-height="96px"
    />

    <section class="content-sheet flush reward-claim-detail-page">
      <div v-if="isLoading" class="empty-lottery-state">
        กำลังโหลดรายการขึ้นเงิน...
      </div>

      <div v-else-if="loadError" class="empty-lottery-state text-danger">
        {{ loadError }}
      </div>

      <article v-else-if="claim" class="reward-claim-receipt">
        <div class="reward-receipt-brand">
          <span class="reward-lottery-logo">GLO</span>
          <strong>สลากกินแบ่งรัฐบาล</strong>
        </div>

        <dl class="reward-receipt-list">
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
            <dt>สถานะ</dt>
            <dd>
              <span :class="['reward-detail-status-text', statusClass(claim)]">{{ statusText(claim) }}</span>
            </dd>
          </div>
        </dl>

        <p class="reward-detail-transfer-note" :class="statusClass(claim)">
          {{ transferNoteText }}
        </p>

        <dl class="reward-receipt-list">
          <div>
            <dt>สลากฯ งวดวันที่</dt>
            <dd>{{ claimGameDateText }}</dd>
          </div>
          <div>
            <dt>เลขสลากดิจิทัล</dt>
            <dd>{{ ticketNumber || '-' }}</dd>
          </div>
          <div>
            <dt>รางวัล</dt>
            <dd>
              <span v-for="prize in claimPrizeRows" :key="prize.key" class="reward-prize-line">
                {{ prize.title }}<br>{{ formatMoney(prize.amount) }} บาท
              </span>
            </dd>
          </div>
        </dl>

        <dl class="reward-receipt-money">
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

        <p v-if="claim.admin_note" class="reward-detail-admin-note" :class="{ rejected: isRejected }">
          {{ claim.admin_note }}
        </p>
      </article>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: true
})

const route = useRoute()
const platformApi = usePlatformApi()
const { showAlert } = useAppAlert()
const { getTicketGameDate, getTicketNumber } = useUserTickets()

const claim = ref<Record<string, any> | null>(null)
const isLoading = ref(true)
const loadError = ref('')
const claimId = computed(() => {
  const value = Array.isArray(route.params.claim_id) ? route.params.claim_id[0] : route.params.claim_id

  return String(value || '')
})
const claimPrizes = computed(() => Array.isArray(claim.value?.prizes) ? claim.value.prizes : [])
const ticketNumber = computed(() => getTicketNumber(claim.value?.ticket))
const claimGameDateText = computed(() => getTicketGameDate(claim.value?.ticket) || '-')
const isRejected = computed(() => claimStatusValue(claim.value) === 'rejected')
const receiverName = computed(() => String(
  claim.value?.customer?.name ||
  claim.value?.customer?.full_name ||
  claim.value?.customer?.display_name ||
  'ผู้ใช้งาน'
))
const bankAccount = computed(() => {
  const bank = claim.value?.bank_account || claim.value?.payout_bank_account || {}

  return {
    bank_name: String(bank.bank_name || bank.bank || ''),
    account_number: String(bank.account_number || bank.account_no || bank.bank_account_no || bank.bank_deposit_number || '')
  }
})
const payoutChannelLines = computed(() => {
  if (String(claim.value?.payout_method || '') === 'bank_transfer') {
    return [
      bankAccount.value.bank_name || 'บัญชีธนาคาร',
      maskAccountNumber(bankAccount.value.account_number)
    ]
  }

  return [String(claim.value?.payout_wallet?.name || 'G-Wallet')]
})
const prizeAmount = computed(() => {
  const prizesTotal = claimPrizes.value.reduce((total, prize) => total + rewardAmountNumber(prize.amount ?? prize.prize_amount ?? prize.reward), 0)

  return prizesTotal > 0 ? prizesTotal : rewardAmountNumber(claim.value?.prize_amount)
})
const claimPrizeRows = computed(() => {
  if (claimPrizes.value.length > 0) {
    return claimPrizes.value.map((prize, index) => ({
      key: `${prize.prize_type || index}-${prize.prize_number || index}`,
      title: prizeTypeText(prize.prize_type || claim.value?.prize_type),
      amount: rewardAmountNumber(prize.amount ?? prize.prize_amount ?? prize.reward)
    }))
  }

  return [{
    key: 'claim-prize',
    title: prizeTypeText(claim.value?.prize_type),
    amount: prizeAmount.value
  }]
})
const taxAmount = computed(() => Math.round(prizeAmount.value * 0.005))
const feeAmount = computed(() => Math.round(prizeAmount.value * 0.01))
const netAmount = computed(() => prizeAmount.value)
const transferNoteText = computed(() => {
  const status = claimStatusValue(claim.value)

  if (claimIsPaid(claim.value)) {
    return 'โอนเงินรางวัลเข้าบัญชีผู้รับเงินเรียบร้อยแล้ว'
  }

  if (status === 'rejected') {
    return 'รายการขึ้นเงินไม่สำเร็จ กรุณาตรวจสอบรายละเอียดหรือติดต่อผู้ให้บริการ'
  }

  if (status === 'cancelled') {
    return 'รายการขึ้นเงินถูกยกเลิก กรุณาตรวจสอบรายละเอียดหรือติดต่อผู้ให้บริการ'
  }

  if (status === 'approved') {
    return 'รายการได้รับอนุมัติแล้ว กำลังดำเนินการโอนเงินรางวัล'
  }

  return 'เงินรางวัลจะเข้าบัญชีผู้รับเงินภายใน 2 ชั่วโมง หลังจากทำรายการสำเร็จ'
})

const claimStatusValue = (claimOrStatus: unknown) => (
  claimOrStatus && typeof claimOrStatus === 'object'
    ? String((claimOrStatus as Record<string, any>).status || '').toLowerCase()
    : String(claimOrStatus || '').toLowerCase()
)

const claimIsPaid = (claimOrStatus: unknown) => {
  const value = claimStatusValue(claimOrStatus)
  const claimData = claimOrStatus && typeof claimOrStatus === 'object' ? claimOrStatus as Record<string, any> : {}

  return ['paid', 'paid_out'].includes(value) || (value === 'approved' && Boolean(claimData.paid_at || claimData.payout_ledger_id || claimData.payout_method === 'bank_transfer'))
}

const statusText = (claimOrStatus: unknown) => {
  const value = claimStatusValue(claimOrStatus)

  if (claimIsPaid(claimOrStatus)) {
    return 'โอนเงินสำเร็จ'
  }

  if (value === 'rejected') {
    return 'ขึ้นเงินไม่สำเร็จ'
  }

  if (value === 'cancelled') {
    return 'ยกเลิกรายการ'
  }

  if (value === 'approved') {
    return 'อนุมัติแล้ว รอโอนเงิน'
  }

  return 'รอดำเนินการโอนเงิน'
}

const statusClass = (claimOrStatus: unknown) => {
  const value = claimStatusValue(claimOrStatus)

  if (claimIsPaid(claimOrStatus)) {
    return 'is-paid'
  }

  if (['rejected', 'cancelled'].includes(value)) {
    return 'is-rejected'
  }

  return 'is-pending'
}

const prizeTypeText = (type: unknown) => {
  const map: Record<string, string> = {
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

  return map[String(type || '')] || 'ถูกรางวัล'
}

const rewardAmountNumber = (amount: unknown) => {
  if (typeof amount === 'number') {
    return Number.isFinite(amount) ? amount : 0
  }

  if (typeof amount === 'string') {
    const value = Number(amount)

    return Number.isFinite(value) ? value : 0
  }

  if (amount && typeof amount === 'object' && 'amount' in amount) {
    const value = Number((amount as { amount?: unknown }).amount)

    return Number.isFinite(value) ? value / 100 : 0
  }

  return 0
}

const formatMoney = (amount: unknown) => {
  const value = Number(amount || 0)

  return Number.isFinite(value) ? value.toLocaleString('th-TH') : '0'
}

const maskAccountNumber = (value: unknown) => {
  const number = String(value || '').replace(/\D/g, '')

  if (number.length <= 4) {
    return number || 'x xxx9'
  }

  return `x xxx${number.slice(-4)}`
}

const loadClaim = async () => {
  isLoading.value = true
  loadError.value = ''

  try {
    claim.value = await platformApi.rewardClaim(claimId.value)
  } catch (error: any) {
    loadError.value = error?.response?.data?.message || 'โหลดรายการขึ้นเงินไม่สำเร็จ'
    showAlert({
      title: 'โหลดรายการไม่สำเร็จ',
      message: loadError.value,
      variant: 'error'
    })
  } finally {
    isLoading.value = false
  }
}

onMounted(loadClaim)
</script>

<style scoped>
.reward-claim-detail-header {
  min-height: 96px !important;
  padding: 44px 16px 10px;
}

.reward-claim-detail-header :deep(.hero-row) {
  min-height: 36px;
}

.reward-claim-detail-header :deep(.hero-title) {
  font-size: 16px;
  font-weight: 900;
  line-height: 1.25;
}

.reward-claim-detail-header :deep(.hero-back) {
  font-size: 27px;
  height: 36px;
  top: 0;
  width: 36px;
}

.reward-claim-detail-page {
  align-content: start;
  align-items: start;
  background: #fff;
  border-radius: 0;
  display: grid;
  gap: 0;
  grid-auto-rows: max-content;
  margin-left: auto;
  margin-right: auto;
  max-width: 640px;
  min-height: calc(100dvh - 96px);
  padding: 12px 10px calc(24px + env(safe-area-inset-bottom));
}

.reward-claim-receipt {
  background: #fff;
  display: grid;
  gap: 13px;
  min-height: 0;
  min-width: 0;
  padding: 0;
}

.reward-receipt-brand {
  align-items: center;
  display: flex;
  gap: 10px;
  padding-bottom: 2px;
}

.reward-lottery-logo {
  align-items: center;
  border: 1px solid #dbeafe;
  border-radius: 50%;
  color: #0b69dc;
  display: inline-flex;
  flex: 0 0 42px;
  font-size: 14px;
  font-weight: 900;
  height: 42px;
  justify-content: center;
  width: 42px;
}

.reward-receipt-brand strong {
  color: #111827;
  font-size: 15px;
  font-weight: 900;
}

.reward-receipt-list,
.reward-receipt-money {
  display: grid;
  gap: 8px;
  margin: 0;
}

.reward-receipt-list {
  border-top: 1px solid #eef2f7;
  padding-top: 12px;
}

.reward-receipt-list div,
.reward-receipt-money div {
  align-items: start;
  display: grid;
  gap: 8px;
  grid-auto-rows: max-content;
  grid-template-columns: minmax(118px, max-content) minmax(0, 1fr);
  min-height: 0;
}

.reward-receipt-list dt,
.reward-receipt-money dt {
  color: #64748b;
  font-size: 15px;
  font-weight: 500;
  line-height: 1.35;
}

.reward-receipt-list dd,
.reward-receipt-money dd {
  color: #111827;
  font-size: 17px;
  font-weight: 900;
  line-height: 1.35;
  margin: 0;
  overflow-wrap: anywhere;
  text-align: right;
}

.reward-receipt-list dd.blue {
  color: #086bdd;
}

.reward-payout-lines {
  display: grid;
  gap: 3px;
  justify-items: end;
}

.reward-payout-lines span {
  line-height: 1.3;
}

.reward-detail-status-text {
  font-size: 13px;
  font-weight: 900;
  line-height: 1.35;
}

.reward-detail-status-text.is-paid {
  color: #28a81e;
}

.reward-detail-status-text.is-pending {
  color: #e29300;
}

.reward-detail-status-text.is-rejected {
  color: #ed2c25;
}

.reward-detail-transfer-note {
  background: #fff7dc;
  border-radius: 8px;
  color: #b36a00;
  font-size: 13px;
  font-weight: 900;
  line-height: 1.45;
  margin: 0;
  padding: 10px 12px;
  text-align: center;
}

.reward-detail-transfer-note.is-paid {
  background: #effce8;
  color: #28a81e;
}

.reward-detail-transfer-note.is-rejected {
  background: #ffe1df;
  color: #ed2c25;
}

.reward-detail-transfer-note.is-pending {
  background: #fff7dc;
  color: #b36a00;
}

.reward-prize-line {
  display: block;
  line-height: 1.35;
}

.reward-receipt-money {
  border-top: 1px solid #eef2f7;
  padding-top: 12px;
}

.reward-receipt-money .discount dd {
  display: grid;
  gap: 4px;
}

.reward-receipt-money .discount dd span {
  color: #64748b;
  font-size: 12px;
  font-weight: 800;
  line-height: 1.25;
}

.reward-receipt-money .discount dd s {
  color: #94a3b8;
  margin-right: 4px;
}

.reward-receipt-money .discount dd strong {
  color: #16a34a;
  font-size: 14px;
  font-weight: 900;
  line-height: 1.25;
}

.reward-receipt-money .total {
  border-top: 1px solid #eef2f7;
  padding-top: 10px;
}

.reward-receipt-money .total dt,
.reward-receipt-money .total dd {
  color: #111827;
  font-size: 19px;
  font-weight: 500;
}

.reward-detail-admin-note {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  color: #475569;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.45;
  margin: 0;
  padding: 10px 12px;
}

.reward-detail-admin-note.rejected {
  background: #fff1f2;
  border-color: #fecdd3;
  color: #b91c1c;
}
</style>

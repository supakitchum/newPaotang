<template>
  <MobileShell active-nav="menu">
    <BlueHeader
      class="activity-claim-detail-header"
      title="รายละเอียดขึ้นเงินรางวัลกิจกรรม"
      back-to="/activity-claims"
      force-back-to
      min-height="96px"
    />

    <section class="content-sheet flush activity-claim-detail-page">
      <div v-if="isLoading" class="empty-lottery-state">
        กำลังโหลดรายการขึ้นเงินกิจกรรม...
      </div>

      <div v-else-if="loadError" class="empty-lottery-state text-danger">
        {{ loadError }}
      </div>

      <article v-else-if="claim" class="activity-claim-receipt">
        <div class="activity-receipt-brand">
          <span class="activity-receipt-logo"><i class="bi bi-gift" /></span>
          <div>
            <strong>รางวัลกิจกรรม</strong>
            <span>{{ activityName }}</span>
          </div>
        </div>

        <dl class="activity-receipt-list">
          <div>
            <dt>ผู้รับเงิน</dt>
            <dd class="blue">{{ receiverName }}</dd>
          </div>
          <div>
            <dt>ช่องทางขึ้นเงินรางวัล</dt>
            <dd class="blue activity-payout-lines">
              <span v-for="line in payoutChannelLines" :key="line">{{ line }}</span>
            </dd>
          </div>
          <div>
            <dt>วิธีขึ้นเงินรางวัล</dt>
            <dd class="blue">{{ payoutMethodText }}</dd>
          </div>
          <div>
            <dt>สถานะ</dt>
            <dd>
              <span :class="['activity-detail-status-text', statusClass(claim)]">{{ statusText(claim) }}</span>
            </dd>
          </div>
        </dl>

        <p class="activity-detail-transfer-note" :class="statusClass(claim)">
          {{ transferNoteText }}
        </p>

        <dl class="activity-receipt-list">
          <div>
            <dt>กิจกรรม</dt>
            <dd>{{ activityName }}</dd>
          </div>
          <div>
            <dt>ประเภทรางวัล</dt>
            <dd>{{ activityRewardLabel }}</dd>
          </div>
          <div>
            <dt>รหัสรายการ</dt>
            <dd>{{ claim.reference || `#${claim.id}` }}</dd>
          </div>
          <div>
            <dt>วันที่ทำรายการ</dt>
            <dd>{{ formatDateTime(claim.submitted_at || claim.created_at) }}</dd>
          </div>
          <div v-if="claim.reviewed_at || claim.paid_at">
            <dt>{{ claim.paid_at ? 'วันที่โอนเงิน' : 'วันที่ตรวจสอบ' }}</dt>
            <dd>{{ formatDateTime(claim.paid_at || claim.reviewed_at) }}</dd>
          </div>
        </dl>

        <dl class="activity-receipt-money">
          <div>
            <dt>ยอดรางวัลกิจกรรม</dt>
            <dd>{{ formatMoney(claimAmount) }} บาท</dd>
          </div>
          <div class="total">
            <dt>ยอดเงินที่ได้รับ</dt>
            <dd>{{ formatMoney(claimAmount) }} บาท</dd>
          </div>
        </dl>

        <p v-if="claim.admin_note" class="activity-detail-admin-note" :class="{ rejected: isRejected }">
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

const claim = ref<Record<string, any> | null>(null)
const isLoading = ref(true)
const loadError = ref('')
const claimId = computed(() => {
  const value = Array.isArray(route.params.claim_id) ? route.params.claim_id[0] : route.params.claim_id

  return String(value || '')
})
const award = computed(() => claim.value?.award && typeof claim.value.award === 'object' ? claim.value.award : {})
const activityName = computed(() => String(claim.value?.activity_name || award.value.activity_name || 'กิจกรรม'))
const activityRewardLabel = computed(() => {
  const type = String(award.value.type || claim.value?.type || '')

  if (type === 'cashback') {
    return 'เงินคืนกิจกรรม'
  }

  return predictionLabel(award.value.prediction_type || claim.value?.prediction_type)
})
const claimAmount = computed(() => moneyNumber(claim.value?.claim_amount || claim.value?.amount || award.value.amount))
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
const payoutMethodText = computed(() => String(claim.value?.payout_method || '') === 'bank_transfer' ? 'โอนเข้าบัญชีธนาคาร' : 'รับเข้า G-Wallet')
const payoutChannelLines = computed(() => {
  if (String(claim.value?.payout_method || '') === 'bank_transfer') {
    return [
      bankAccount.value.bank_name || 'บัญชีธนาคาร',
      maskAccountNumber(bankAccount.value.account_number)
    ]
  }

  return [String(claim.value?.payout_wallet?.name || 'G-Wallet')]
})
const transferNoteText = computed(() => {
  const status = claimStatusValue(claim.value)

  if (claimIsPaid(claim.value)) {
    return 'โอนเงินรางวัลกิจกรรมเรียบร้อยแล้ว'
  }

  if (status === 'rejected') {
    return 'รายการขึ้นเงินกิจกรรมไม่สำเร็จ กรุณาตรวจสอบรายละเอียดหรือติดต่อผู้ให้บริการ'
  }

  if (status === 'cancelled') {
    return 'รายการขึ้นเงินกิจกรรมถูกยกเลิก กรุณาตรวจสอบรายละเอียดหรือติดต่อผู้ให้บริการ'
  }

  if (status === 'approved') {
    return 'รายการได้รับอนุมัติแล้ว กำลังดำเนินการโอนเงินรางวัลกิจกรรม'
  }

  return 'Partner จะตรวจสอบและดำเนินการจ่ายเงินรางวัลกิจกรรมให้คุณ'
})

const claimStatusValue = (claimOrStatus: unknown) => (
  claimOrStatus && typeof claimOrStatus === 'object'
    ? String((claimOrStatus as Record<string, any>).status || '').toLowerCase()
    : String(claimOrStatus || '').toLowerCase()
)

const claimIsPaid = (claimOrStatus: unknown) => {
  const value = claimStatusValue(claimOrStatus)
  const claimData = claimOrStatus && typeof claimOrStatus === 'object' ? claimOrStatus as Record<string, any> : {}

  return ['paid', 'paid_out'].includes(value) || (value === 'approved' && Boolean(claimData.paid_at || claimData.payout_ledger_id))
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

const predictionLabel = (type: unknown) => ({
  first_prize_last2: 'รางวัลแผงเลขนำโชค 2 ตัวรางวัลที่ 1',
  first_prize_last3: 'รางวัลแผงเลขนำโชค 3 ตัวรางวัลที่ 1',
  last2: 'รางวัลแผงเลขนำโชค 2 ตัวท้าย'
}[String(type || '')] || 'รางวัลกิจกรรม')

const moneyNumber = (amount: unknown) => {
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

const formatDateTime = (value: unknown) => {
  if (!value) {
    return '-'
  }

  const date = new Date(String(value))

  if (Number.isNaN(date.getTime())) {
    return String(value)
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

const loadClaim = async () => {
  isLoading.value = true
  loadError.value = ''

  try {
    claim.value = await platformApi.activityClaim(claimId.value)
  } catch (error: any) {
    loadError.value = error?.response?.data?.message || 'โหลดรายการขึ้นเงินกิจกรรมไม่สำเร็จ'
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
.activity-claim-detail-header {
  min-height: 96px !important;
  padding: 44px 16px 10px;
}

.activity-claim-detail-header :deep(.hero-row) {
  min-height: 36px;
}

.activity-claim-detail-header :deep(.hero-title) {
  font-size: 16px;
  font-weight: 900;
  line-height: 1.25;
}

.activity-claim-detail-header :deep(.hero-back) {
  font-size: 27px;
  height: 36px;
  top: 0;
  width: 36px;
}

.activity-claim-detail-page {
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

.activity-claim-receipt {
  background: #fff;
  display: grid;
  gap: 13px;
  min-height: 0;
  min-width: 0;
  padding: 0;
}

.activity-receipt-brand {
  align-items: center;
  display: flex;
  gap: 10px;
  padding-bottom: 2px;
}

.activity-receipt-logo {
  align-items: center;
  border: 1px solid #dbeafe;
  border-radius: 50%;
  color: #0b69dc;
  display: inline-flex;
  flex: 0 0 42px;
  font-size: 20px;
  font-weight: 900;
  height: 42px;
  justify-content: center;
  width: 42px;
}

.activity-receipt-brand div {
  display: grid;
  gap: 2px;
  min-width: 0;
}

.activity-receipt-brand strong {
  color: #111827;
  font-size: 15px;
  font-weight: 900;
}

.activity-receipt-brand span:not(.activity-receipt-logo) {
  color: #64748b;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.35;
}

.activity-receipt-list,
.activity-receipt-money {
  display: grid;
  gap: 8px;
  margin: 0;
}

.activity-receipt-list {
  border-top: 1px solid #eef2f7;
  padding-top: 12px;
}

.activity-receipt-list div,
.activity-receipt-money div {
  align-items: start;
  display: grid;
  gap: 8px;
  grid-auto-rows: max-content;
  grid-template-columns: minmax(118px, max-content) minmax(0, 1fr);
  min-height: 0;
}

.activity-receipt-list dt,
.activity-receipt-money dt {
  color: #64748b;
  font-size: 15px;
  font-weight: 500;
  line-height: 1.35;
}

.activity-receipt-list dd,
.activity-receipt-money dd {
  color: #111827;
  font-size: 17px;
  font-weight: 900;
  line-height: 1.35;
  margin: 0;
  overflow-wrap: anywhere;
  text-align: right;
}

.activity-receipt-list dd.blue {
  color: #086bdd;
}

.activity-payout-lines {
  display: grid;
  gap: 3px;
  justify-items: end;
}

.activity-detail-status-text {
  font-size: 13px;
  font-weight: 900;
  line-height: 1.35;
}

.activity-detail-status-text.is-paid {
  color: #28a81e;
}

.activity-detail-status-text.is-pending {
  color: #e29300;
}

.activity-detail-status-text.is-rejected {
  color: #ed2c25;
}

.activity-detail-transfer-note {
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

.activity-detail-transfer-note.is-paid {
  background: #effce8;
  color: #28a81e;
}

.activity-detail-transfer-note.is-rejected {
  background: #ffe1df;
  color: #ed2c25;
}

.activity-detail-transfer-note.is-pending {
  background: #fff7dc;
  color: #b36a00;
}

.activity-receipt-money {
  border-top: 1px solid #eef2f7;
  padding-top: 12px;
}

.activity-receipt-money .total {
  border-top: 1px solid #eef2f7;
  padding-top: 10px;
}

.activity-receipt-money .total dt,
.activity-receipt-money .total dd {
  color: #111827;
  font-size: 19px;
  font-weight: 500;
}

.activity-detail-admin-note {
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

.activity-detail-admin-note.rejected {
  background: #fff1f2;
  border-color: #fecdd3;
  color: #b91c1c;
}
</style>

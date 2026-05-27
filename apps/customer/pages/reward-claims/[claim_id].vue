<template>
  <MobileShell active-nav="menu" show-bottom-nav>
    <BlueHeader title="รายละเอียดขึ้นเงิน" back-to="/reward-claims" min-height="218px">
      <div class="reward-claim-detail-hero">
        <span><i class="bi bi-cash-coin" /></span>
        <div>
          <p>{{ claim?.reference || 'รายการขึ้นเงินรางวัล' }}</p>
          <h1>{{ formatMoney(claim?.prize_amount) }} บาท</h1>
        </div>
      </div>
    </BlueHeader>

    <section class="content-sheet reward-claim-detail-page">
      <div v-if="isLoading" class="empty-lottery-state">
        กำลังโหลดรายการขึ้นเงิน...
      </div>

      <div v-else-if="loadError" class="empty-lottery-state text-danger">
        {{ loadError }}
      </div>

      <template v-else-if="claim">
        <article class="reward-claim-detail-card">
          <div class="reward-claim-detail-head">
            <div>
              <span>สถานะรายการ</span>
              <strong>{{ statusText(claim.status) }}</strong>
            </div>
            <span :class="['reward-claim-detail-status', statusClass(claim.status)]">{{ statusText(claim.status) }}</span>
          </div>

          <div class="reward-claim-timeline" :class="{ rejected: isRejected }">
            <div
              v-for="(step, index) in timelineSteps"
              :key="step.key"
              class="reward-claim-step"
              :class="{ active: index <= activeStepIndex, current: index === activeStepIndex }"
            >
              <span><i class="bi" :class="step.icon" /></span>
              <strong>{{ step.label }}</strong>
            </div>
          </div>

          <div v-if="claim.admin_note" class="reward-claim-note" :class="{ rejected: isRejected }">
            <i class="bi bi-chat-left-text" />
            <span>{{ claim.admin_note }}</span>
          </div>
        </article>

        <article class="reward-claim-detail-card">
          <h2>ข้อมูลสลากฯ</h2>
          <div class="reward-claim-detail-grid">
            <div>
              <span>เลขสลากฯ</span>
              <strong>{{ getTicketNumber(claim.ticket) || '-' }}</strong>
            </div>
            <div>
              <span>ประเภทรางวัล</span>
              <strong>{{ claimPrizeTitle }}</strong>
            </div>
            <div>
              <span>เลขรางวัล</span>
              <strong>{{ claimPrizeNumbersText }}</strong>
            </div>
            <div>
              <span>ยอดเงินรางวัล</span>
              <strong>{{ formatMoney(claim.prize_amount) }} บาท</strong>
            </div>
          </div>
          <div v-if="claimPrizes.length > 1" class="reward-claim-prize-list">
            <div v-for="(prize, index) in claimPrizes" :key="`${prize.prize_type || index}-${prize.prize_number || index}`">
              <span>{{ prizeTypeText(prize.prize_type) }}</span>
              <strong>{{ formatMoney(prize.amount) }} บาท</strong>
            </div>
          </div>
        </article>

        <article class="reward-claim-detail-card">
          <h2>ช่องทางรับเงิน</h2>
          <div class="reward-claim-payout">
            <i class="bi" :class="payoutIcon(claim.payout_method)" />
            <div>
              <strong>{{ payoutText(claim.payout_method) }}</strong>
              <span>{{ payoutSubtitle }}</span>
            </div>
          </div>
        </article>

        <article class="reward-claim-detail-card">
          <h2>วันที่ทำรายการ</h2>
          <div class="reward-claim-detail-grid">
            <div>
              <span>ส่งรายการ</span>
              <strong>{{ formatDateTime(claim.submitted_at || claim.created_at) }}</strong>
            </div>
            <div>
              <span>ตรวจสอบ</span>
              <strong>{{ formatDateTime(claim.reviewed_at) }}</strong>
            </div>
            <div>
              <span>จ่ายเงิน</span>
              <strong>{{ formatDateTime(claim.paid_at) }}</strong>
            </div>
          </div>
        </article>
      </template>
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
const { getTicketNumber } = useUserTickets()

const claim = ref<Record<string, any> | null>(null)
const isLoading = ref(true)
const loadError = ref('')
const claimId = computed(() => {
  const value = Array.isArray(route.params.claim_id) ? route.params.claim_id[0] : route.params.claim_id

  return String(value || '')
})
const isRejected = computed(() => String(claim.value?.status || '').toLowerCase() === 'rejected')
const claimPrizes = computed(() => Array.isArray(claim.value?.prizes) ? claim.value.prizes : [])
const claimPrizeTitle = computed(() => {
  if (claimPrizes.value.length > 1) {
    return `ถูกรางวัล ${claimPrizes.value.length.toLocaleString('th-TH')} รางวัล`
  }

  return prizeTypeText(claimPrizes.value[0]?.prize_type || claim.value?.prize_type)
})
const claimPrizeNumbersText = computed(() => {
  const numbers = claimPrizes.value.map((prize) => String(prize.prize_number || '').trim()).filter(Boolean)

  return numbers.length > 0 ? numbers.join(', ') : String(claim.value?.prize_number || '-')
})
const activeStepIndex = computed(() => {
  const status = String(claim.value?.status || '').toLowerCase()

  if (status === 'rejected') {
    return 1
  }

  if (status === 'paid') {
    return 2
  }

  if (status === 'approved') {
    return 1
  }

  return 0
})
const timelineSteps = computed(() => isRejected.value
  ? [
      { key: 'submitted', label: 'ส่งรายการ', icon: 'bi-send-check' },
      { key: 'rejected', label: 'ไม่อนุมัติ', icon: 'bi-x-circle' }
    ]
  : [
      { key: 'submitted', label: 'ส่งรายการ', icon: 'bi-send-check' },
      { key: 'approved', label: 'อนุมัติ', icon: 'bi-patch-check' },
      { key: 'paid', label: 'จ่ายเงิน', icon: 'bi-cash-coin' }
    ]
)
const payoutSubtitle = computed(() => {
  if (!claim.value) {
    return '-'
  }

  if (String(claim.value.payout_method || '') === 'bank_transfer') {
    return 'โอนเข้าบัญชีธนาคารที่บันทึกไว้'
  }

  if (claim.value.payout_wallet?.name) {
    return String(claim.value.payout_wallet.name)
  }

  return 'รับเงินเข้า G-Wallet'
})

const statusText = (status: unknown) => {
  const value = String(status || '').toLowerCase()
  const map: Record<string, string> = {
    submitted: 'ส่งรายการแล้ว',
    under_review: 'กำลังตรวจสอบ',
    approved: 'อนุมัติแล้ว',
    rejected: 'ไม่อนุมัติ',
    paid: 'จ่ายเงินแล้ว'
  }

  return map[value] || 'รอดำเนินการ'
}

const statusClass = (status: unknown) => {
  const value = String(status || '').toLowerCase()

  if (value === 'paid') {
    return 'is-paid'
  }

  if (value === 'approved') {
    return 'is-approved'
  }

  if (value === 'rejected') {
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
const payoutText = (method: unknown) => String(method || '') === 'bank_transfer' ? 'โอนเข้าธนาคาร' : 'เข้า G-Wallet'
const payoutIcon = (method: unknown) => String(method || '') === 'bank_transfer' ? 'bi-bank2' : 'bi-wallet2'
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

  return date.toLocaleString('th-TH', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
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
.reward-claim-detail-hero {
  align-items: flex-start;
  color: #fff;
  display: flex;
  gap: 12px;
  margin-top: 18px;
}

.reward-claim-detail-hero > span {
  background: #fff;
  border-radius: 14px;
  color: #0b69dc;
  display: grid;
  flex: 0 0 48px;
  font-size: 24px;
  height: 48px;
  place-items: center;
  width: 48px;
}

.reward-claim-detail-hero p,
.reward-claim-detail-hero h1 {
  margin: 0;
}

.reward-claim-detail-hero p {
  font-size: 14px;
  font-weight: 800;
  margin-bottom: 4px;
  overflow-wrap: anywhere;
}

.reward-claim-detail-hero h1 {
  font-size: 28px;
  font-weight: 900;
  line-height: 1.15;
}

.reward-claim-detail-page {
  display: grid;
  gap: 14px;
  margin-left: auto;
  margin-right: auto;
  max-width: 640px;
}

.reward-claim-detail-card {
  background: #fff;
  border: 1px solid #e8edf4;
  border-radius: 8px;
  box-shadow: 0 10px 22px rgba(22, 46, 82, .08);
  display: grid;
  gap: 14px;
  padding: 16px;
}

.reward-claim-detail-card h2 {
  color: #111827;
  font-size: 18px;
  font-weight: 900;
  margin: 0;
}

.reward-claim-detail-head {
  align-items: flex-start;
  display: flex;
  gap: 12px;
  justify-content: space-between;
}

.reward-claim-detail-head div {
  display: grid;
  gap: 4px;
}

.reward-claim-detail-head span,
.reward-claim-detail-grid span {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

.reward-claim-detail-head strong {
  color: #111827;
  font-size: 22px;
  font-weight: 900;
}

.reward-claim-detail-status {
  border-radius: 999px;
  flex: 0 0 auto;
  font-size: 12px;
  font-weight: 900;
  padding: 6px 9px;
}

.reward-claim-detail-status.is-paid,
.reward-claim-detail-status.is-approved {
  background: #e7f8ef;
  color: #087a3a;
}

.reward-claim-detail-status.is-pending {
  background: #fff5db;
  color: #9a6100;
}

.reward-claim-detail-status.is-rejected {
  background: #fee2e2;
  color: #b91c1c;
}

.reward-claim-timeline {
  display: grid;
  gap: 8px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.reward-claim-timeline.rejected {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.reward-claim-step {
  align-items: center;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  color: #94a3b8;
  display: grid;
  gap: 6px;
  justify-items: center;
  min-height: 78px;
  padding: 10px 6px;
  text-align: center;
}

.reward-claim-step span {
  border-radius: 50%;
  display: grid;
  height: 30px;
  place-items: center;
  width: 30px;
}

.reward-claim-step strong {
  font-size: 12px;
  font-weight: 900;
}

.reward-claim-step.active {
  background: #eefbf5;
  border-color: #b8ead5;
  color: #087a3a;
}

.reward-claim-timeline.rejected .reward-claim-step.current {
  background: #fee2e2;
  border-color: #fecaca;
  color: #b91c1c;
}

.reward-claim-note {
  align-items: flex-start;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  color: #475569;
  display: flex;
  gap: 9px;
  padding: 12px;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.4;
}

.reward-claim-note.rejected {
  background: #fff1f2;
  border-color: #fecdd3;
  color: #b91c1c;
}

.reward-claim-detail-grid {
  display: grid;
  gap: 12px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.reward-claim-detail-grid div {
  background: #f8fbff;
  border: 1px solid #e5edf8;
  border-radius: 8px;
  display: grid;
  gap: 3px;
  min-width: 0;
  padding: 12px;
}

.reward-claim-detail-grid strong {
  color: #111827;
  font-size: 16px;
  font-weight: 900;
  overflow-wrap: anywhere;
}

.reward-claim-prize-list {
  display: grid;
  gap: 8px;
}

.reward-claim-prize-list div {
  align-items: center;
  background: #fffaf0;
  border: 1px solid #ffe4a8;
  border-radius: 8px;
  display: flex;
  gap: 10px;
  justify-content: space-between;
  padding: 10px 12px;
}

.reward-claim-prize-list span {
  color: #8a5a00;
  font-size: 13px;
  font-weight: 800;
}

.reward-claim-prize-list strong {
  color: #086bdd;
  font-size: 14px;
  font-weight: 900;
}

.reward-claim-payout {
  align-items: center;
  background: #f8fbff;
  border: 1px solid #e5edf8;
  border-radius: 8px;
  display: grid;
  gap: 12px;
  grid-template-columns: 42px minmax(0, 1fr);
  padding: 12px;
}

.reward-claim-payout > i {
  background: #eaf4ff;
  border-radius: 50%;
  color: #0b69dc;
  display: grid;
  height: 42px;
  place-items: center;
  width: 42px;
}

.reward-claim-payout div {
  display: grid;
  gap: 3px;
  min-width: 0;
}

.reward-claim-payout strong {
  color: #17335f;
  font-size: 16px;
  font-weight: 900;
}

.reward-claim-payout span {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

@media (max-width: 420px) {
  .reward-claim-detail-grid {
    grid-template-columns: 1fr;
  }
}
</style>

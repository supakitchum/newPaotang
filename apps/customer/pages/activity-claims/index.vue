<template>
  <MobileShell active-nav="menu">
    <BlueHeader
      class="activity-claims-header"
      title="ประวัติขึ้นเงินรางวัลกิจกรรม"
      back-to="/profile"
      force-back-to
      min-height="96px"
    />

    <section class="content-sheet flush activity-claims-page">
      <div v-if="isLoadingInitial" class="empty-lottery-state">
        กำลังโหลดประวัติขึ้นเงินกิจกรรม...
      </div>

      <div v-else-if="loadError" class="empty-lottery-state text-danger">
        {{ loadError }}
      </div>

      <div v-else-if="claims.length === 0" class="activity-claims-empty">
        <div><i class="bi bi-gift" /></div>
        <h2>ยังไม่มีประวัติขึ้นเงินกิจกรรม</h2>
        <p>เมื่อรับเงินรางวัลหรือเงินคืนจากกิจกรรม รายการจะแสดงที่หน้านี้</p>
        <NuxtLink class="primary-pill activity-claims-empty-action" to="/activities">
          ดูกิจกรรม
        </NuxtLink>
      </div>

      <template v-else>
        <div class="activity-claims-list">
          <NuxtLink
            v-for="claim in claims"
            :key="claim.id"
            class="activity-claim-row"
            :to="`/activity-claims/${encodeURIComponent(String(claim.id))}`"
          >
            <div class="activity-claim-row-main">
              <div class="activity-claim-row-line activity-claim-row-head">
                <strong>เงินรางวัลกิจกรรม</strong>
                <strong>{{ formatMoney(claim.claim_amount || claim.amount) }} บาท</strong>
              </div>
              <div class="activity-claim-row-line activity-claim-row-reward">
                <span class="activity-claim-prize-names">
                  <span>{{ activityRewardLabel(claim) }}</span>
                  <span>{{ activityName(claim) }}</span>
                </span>
                <span :class="['activity-claim-status', statusClass(claim)]">{{ statusText(claim) }}</span>
              </div>
              <div class="activity-claim-row-payout">
                {{ payoutSummary(claim) }}
              </div>
              <div class="activity-claim-row-line activity-claim-row-foot">
                <time>{{ formatDateTime(claim.submitted_at || claim.created_at) }}</time>
                <i class="bi bi-chevron-right" aria-hidden="true" />
              </div>
            </div>
            <div class="visually-hidden">
              <div>รหัสรายการ {{ claim.reference || `#${claim.id}` }}</div>
              <div>กิจกรรม {{ activityName(claim) }}</div>
            </div>
          </NuxtLink>
        </div>

        <button v-if="hasMore" class="outline-pill activity-claims-more" type="button" :disabled="isLoadingMore" @click="loadNextPage">
          {{ isLoadingMore ? 'กำลังโหลด...' : 'โหลดเพิ่มเติม' }}
        </button>
      </template>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: true
})

const platformApi = usePlatformApi()
const { showAlert } = useAppAlert()

const claims = ref<Array<Record<string, any>>>([])
const cursor = ref<string | null>(null)
const hasMore = ref(false)
const isLoadingInitial = ref(true)
const isLoadingMore = ref(false)
const loadError = ref('')
const limit = 20

const claimStatusValue = (claimOrStatus: unknown) => (
  claimOrStatus && typeof claimOrStatus === 'object'
    ? String((claimOrStatus as Record<string, any>).status || '').toLowerCase()
    : String(claimOrStatus || '').toLowerCase()
)

const claimIsPaid = (claimOrStatus: unknown) => {
  const value = claimStatusValue(claimOrStatus)
  const claim = claimOrStatus && typeof claimOrStatus === 'object' ? claimOrStatus as Record<string, any> : {}

  return ['paid', 'paid_out'].includes(value) || (value === 'approved' && Boolean(claim.paid_at || claim.payout_ledger_id))
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

const activityName = (claim: Record<string, any>) => {
  const award = claim.award && typeof claim.award === 'object' ? claim.award : {}

  return String(claim.activity_name || award.activity_name || 'กิจกรรม')
}

const activityRewardLabel = (claim: Record<string, any>) => {
  const award = claim.award && typeof claim.award === 'object' ? claim.award : {}
  const type = String(award.type || claim.type || '')

  if (type === 'cashback') {
    return 'เงินคืนกิจกรรม'
  }

  return predictionLabel(award.prediction_type || claim.prediction_type)
}

const predictionLabel = (type: unknown) => ({
  first_prize_last2: 'รางวัลแผงเลขนำโชค 2 ตัวรางวัลที่ 1',
  first_prize_last3: 'รางวัลแผงเลขนำโชค 3 ตัวรางวัลที่ 1',
  last2: 'รางวัลแผงเลขนำโชค 2 ตัวท้าย'
}[String(type || '')] || 'รางวัลกิจกรรม')

const payoutSummary = (claim: Record<string, any>) => {
  if (String(claim.payout_method || '') !== 'bank_transfer') {
    return 'รับเข้า G-Wallet'
  }

  const account = claim.bank_account || claim.payout_bank_account || claim.bank || {}
  const bankName = String(account.bank_name || account.bank || claim.bank_name || '').replace(/^ธนาคาร/u, '').trim()

  return `รับผ่านบัญชี${bankName || 'ธนาคาร'}`
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

const fetchClaims = async (nextCursor: string | null = null) => {
  if (nextCursor) {
    isLoadingMore.value = true
  } else {
    isLoadingInitial.value = true
  }

  loadError.value = ''

  try {
    const response = await platformApi.activityClaims({
      limit,
      ...(nextCursor ? { cursor: nextCursor } : {})
    })

    claims.value = nextCursor ? [...claims.value, ...response.data] : response.data
    cursor.value = response.meta?.next_cursor || null
    hasMore.value = Boolean(response.meta?.has_more && cursor.value)
  } catch (error: any) {
    loadError.value = error?.response?.data?.message || 'โหลดประวัติขึ้นเงินกิจกรรมไม่สำเร็จ'
    showAlert({
      title: 'โหลดประวัติไม่สำเร็จ',
      message: loadError.value,
      variant: 'error'
    })
  } finally {
    isLoadingInitial.value = false
    isLoadingMore.value = false
  }
}

const loadNextPage = () => {
  if (!cursor.value || isLoadingMore.value) {
    return
  }

  fetchClaims(cursor.value)
}

onMounted(() => fetchClaims())
</script>

<style scoped>
.activity-claims-header {
  min-height: 96px !important;
  padding: 44px 16px 10px;
}

.activity-claims-header :deep(.hero-row) {
  min-height: 36px;
}

.activity-claims-header :deep(.hero-title) {
  font-size: 16px;
  font-weight: 900;
  line-height: 1.25;
}

.activity-claims-header :deep(.hero-back) {
  font-size: 27px;
  height: 36px;
  top: 0;
  width: 36px;
}

.activity-claims-page {
  align-content: start;
  background: #fff;
  border-radius: 0;
  display: grid;
  gap: 0;
  margin-left: auto;
  margin-right: auto;
  max-width: 640px;
  min-height: calc(100dvh - 96px);
  padding: 0 0 calc(22px + env(safe-area-inset-bottom));
}

.activity-claims-empty {
  color: #64748b;
  display: grid;
  gap: 10px;
  justify-items: center;
  padding: 54px 14px;
  text-align: center;
}

.activity-claims-empty div {
  background: #eef7ff;
  border-radius: 50%;
  color: #0b69dc;
  display: grid;
  font-size: 30px;
  height: 64px;
  place-items: center;
  width: 64px;
}

.activity-claims-empty h2 {
  color: #111827;
  font-size: 20px;
  font-weight: 900;
  margin: 0;
}

.activity-claims-empty p {
  font-size: 14px;
  font-weight: 700;
  line-height: 1.45;
  margin: 0;
}

.activity-claims-empty-action {
  align-items: center;
  display: inline-flex;
  justify-content: center;
  margin-top: 6px;
  min-width: 190px;
  padding: 0 18px;
}

.activity-claims-list {
  align-content: start;
  background: #fff;
  display: grid;
  gap: 0;
  grid-auto-rows: max-content;
}

.activity-claim-row {
  background: #fff;
  border-bottom: 1px solid #eef2f7;
  color: inherit;
  display: block;
  min-height: 0;
  padding: 9px 10px 8px;
  text-decoration: none;
}

.activity-claim-row-main {
  display: grid;
  gap: 0;
  min-width: 0;
}

.activity-claim-row-line {
  align-items: start;
  display: grid;
  gap: 10px;
  grid-template-columns: minmax(0, 1fr) auto;
  min-width: 0;
}

.activity-claim-row-head strong {
  color: #202938;
  font-size: 17px;
  font-weight: 900;
  line-height: 1.25;
}

.activity-claim-row-reward {
  margin-top: 3px;
}

.activity-claim-prize-names {
  display: grid;
  gap: 1px;
  min-width: 0;
}

.activity-claim-prize-names span,
.activity-claim-row-payout,
.activity-claim-row-foot time {
  color: #4b5563;
  font-size: 15px;
  line-height: 1.32;
  overflow-wrap: anywhere;
}

.activity-claim-row-payout {
  margin-top: 3px;
}

.activity-claim-status {
  border-radius: 3px;
  display: inline-flex;
  flex: 0 0 auto;
  font-size: 15px;
  font-weight: 900;
  line-height: 1;
  margin-top: 1px;
  padding: 4px 6px;
  white-space: nowrap;
}

.activity-claim-status.is-paid {
  background: #e5f8df;
  color: #28a81e;
}

.activity-claim-status.is-pending {
  background: #fff3d0;
  color: #e29300;
}

.activity-claim-status.is-rejected {
  background: #ffe1df;
  color: #ed2c25;
}

.activity-claim-row-foot {
  align-items: center;
  margin-top: 3px;
}

.activity-claim-row-foot time {
  color: #94a3b8;
  font-size: 11px;
  font-weight: 800;
}

.activity-claim-row-foot i {
  color: #3b9cff;
  font-size: 23px;
  line-height: 1;
}

.activity-claims-more {
  justify-self: center;
  margin-top: 16px;
  min-width: 160px;
}
</style>

<template>
  <MobileShell active-nav="menu">
    <BlueHeader
      class="reward-claims-header"
      title="ประวัติขึ้นเงินรางวัลสลากดิจิทัล"
      back-to="/profile"
      force-back-to
      min-height="96px"
    />

    <section class="content-sheet flush reward-claims-page">
      <div v-if="isLoadingInitial" class="empty-lottery-state">
        กำลังโหลดประวัติขึ้นเงิน...
      </div>

      <div v-else-if="loadError" class="empty-lottery-state text-danger">
        {{ loadError }}
      </div>

      <div v-else-if="claims.length === 0" class="reward-claims-empty">
        <div><i class="bi bi-trophy" /></div>
        <h2>ยังไม่มีประวัติขึ้นเงิน</h2>
        <p>เมื่อส่งรายการขึ้นเงินรางวัลแล้ว รายการจะแสดงที่หน้านี้</p>
        <NuxtLink class="primary-pill reward-claims-empty-action" to="/tickets/history">
          ดูสลากฯ ที่ถูกรางวัล
        </NuxtLink>
      </div>

      <template v-else>
        <div class="reward-claims-list">
          <NuxtLink
            v-for="claim in claims"
            :key="claim.id"
            class="reward-claim-row"
            :to="`/reward-claims/${encodeURIComponent(String(claim.id))}`"
          >
            <div class="reward-claim-row-main">
              <div class="reward-claim-row-line reward-claim-row-head">
                <strong>เงินรางวัลสลากฯ</strong>
                <strong>{{ formatMoney(claim.prize_amount) }} บาท</strong>
              </div>
              <div class="reward-claim-row-line reward-claim-row-reward">
                <span class="reward-claim-prize-names">
                  <span v-for="prizeName in claimPrizeNames(claim)" :key="prizeName">{{ prizeName }}</span>
                </span>
                <span :class="['reward-claim-status', statusClass(claim)]">{{ statusText(claim) }}</span>
              </div>
              <div class="reward-claim-row-payout">
                {{ payoutSummary(claim) }}
              </div>
              <div class="reward-claim-row-line reward-claim-row-foot">
                <time>{{ formatDateTime(claim.submitted_at || claim.created_at) }}</time>
                <i class="bi bi-chevron-right" aria-hidden="true" />
              </div>
            </div>
            <div class="visually-hidden">
              <div>เลขสลากฯ {{ getTicketNumber(claim.ticket) || '-' }}</div>
              <div>รหัสรายการ {{ claim.reference || `#${claim.id}` }}</div>
            </div>
          </NuxtLink>
        </div>

        <button v-if="hasMore" class="outline-pill reward-claims-more" type="button" :disabled="isLoadingMore" @click="loadNextPage">
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
const { getTicketNumber } = useUserTickets()

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

  return ['paid', 'paid_out'].includes(value) || (value === 'approved' && Boolean(claim.paid_at || claim.payout_ledger_id || claim.payout_method === 'bank_transfer'))
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

const payoutSummary = (claim: Record<string, any>) => {
  if (String(claim.payout_method || '') !== 'bank_transfer') {
    return 'รับเข้า G-Wallet'
  }

  const account = claim.payout_bank_account || claim.bank_account || claim.bank || {}
  const bankName = String(account.bank_name || account.bank || claim.bank_name || '').replace(/^ธนาคาร/u, '').trim()

  return `รับผ่านบัญชี${bankName || 'ธนาคาร'}`
}

const claimPrizeSummary = (claim: Record<string, any>) => {
  const prizes = Array.isArray(claim.prizes) ? claim.prizes : []

  if (prizes.length > 1) {
    const firstPrizeTitle = prizeTypeText(prizes[0]?.prize_type || claim.prize_type)

    return `${firstPrizeTitle} และอีก ${(prizes.length - 1).toLocaleString('th-TH')} รางวัล`
  }

  return prizeTypeText(prizes[0]?.prize_type || claim.prize_type)
}

const claimPrizeNames = (claim: Record<string, any>) => {
  const prizes = Array.isArray(claim.prizes) ? claim.prizes : []
  const names = prizes.map((prize) => prizeTypeText(prize?.prize_type || claim.prize_type)).filter(Boolean)

  return names.length > 0 ? Array.from(new Set(names)) : [claimPrizeSummary(claim)]
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
    const response = await platformApi.rewardClaims({
      limit,
      ...(nextCursor ? { cursor: nextCursor } : {})
    })

    claims.value = nextCursor ? [...claims.value, ...response.data] : response.data
    cursor.value = response.meta?.next_cursor || null
    hasMore.value = Boolean(response.meta?.has_more && cursor.value)
  } catch (error: any) {
    loadError.value = error?.response?.data?.message || 'โหลดประวัติขึ้นเงินไม่สำเร็จ'
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
.reward-claims-header {
  min-height: 96px !important;
  padding: 44px 16px 10px;
}

.reward-claims-header :deep(.hero-row) {
  min-height: 36px;
}

.reward-claims-header :deep(.hero-title) {
  font-size: 16px;
  font-weight: 900;
  line-height: 1.25;
}

.reward-claims-header :deep(.hero-back) {
  font-size: 27px;
  height: 36px;
  top: 0;
  width: 36px;
}

.reward-claims-page {
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

.reward-claims-empty {
  color: #64748b;
  display: grid;
  gap: 10px;
  justify-items: center;
  padding: 54px 14px;
  text-align: center;
}

.reward-claims-empty div {
  background: #eef7ff;
  border-radius: 50%;
  color: #0b69dc;
  display: grid;
  font-size: 30px;
  height: 64px;
  place-items: center;
  width: 64px;
}

.reward-claims-empty h2 {
  color: #111827;
  font-size: 20px;
  font-weight: 900;
  margin: 0;
}

.reward-claims-empty p {
  font-size: 14px;
  font-weight: 700;
  line-height: 1.45;
  margin: 0;
}

.reward-claims-empty-action {
  align-items: center;
  display: inline-flex;
  justify-content: center;
  margin-top: 6px;
  min-width: 190px;
  padding: 0 18px;
}

.reward-claims-list {
  align-content: start;
  background: #fff;
  display: grid;
  gap: 0;
  grid-auto-rows: max-content;
}

.reward-claim-row {
  background: #fff;
  border-bottom: 1px solid #eef2f7;
  color: inherit;
  display: block;
  min-height: 0;
  padding: 9px 10px 8px;
  text-decoration: none;
}

.reward-claim-row-main {
  display: grid;
  gap: 0;
  min-width: 0;
}

.reward-claim-row-line {
  align-items: start;
  display: grid;
  gap: 10px;
  grid-template-columns: minmax(0, 1fr) auto;
  min-width: 0;
}

.reward-claim-row-head strong {
  color: #202938;
  font-size: 17px;
  font-weight: 900;
  line-height: 1.25;
}

.reward-claim-row-reward {
  margin-top: 3px;
}

.reward-claim-prize-names {
  display: grid;
  gap: 1px;
  min-width: 0;
}

.reward-claim-prize-names span,
.reward-claim-row-payout,
.reward-claim-row-foot time {
  color: #4b5563;
  font-size: 15px;
  line-height: 1.32;
  overflow-wrap: anywhere;
}

.reward-claim-row-payout {
  margin-top: 3px;
}

.reward-claim-status {
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

.reward-claim-status.is-paid {
  background: #e5f8df;
  color: #28a81e;
}

.reward-claim-status.is-pending {
  background: #fff3d0;
  color: #e29300;
}

.reward-claim-status.is-rejected {
  background: #ffe1df;
  color: #ed2c25;
}

.reward-claim-row-foot {
  align-items: center;
  margin-top: 3px;
}

.reward-claim-row-foot time {
  color: #94a3b8;
  font-size: 11px;
  font-weight: 800;
}

.reward-claim-row-foot i {
  color: #3b9cff;
  font-size: 23px;
  line-height: 1;
}

.reward-claims-more {
  justify-self: center;
  margin-top: 16px;
  min-width: 160px;
}
</style>

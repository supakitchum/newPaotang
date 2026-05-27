<template>
  <MobileShell active-nav="menu" show-bottom-nav>
    <BlueHeader title="ประวัติขึ้นเงินรางวัล" back-to="/profile" min-height="218px">
      <div class="reward-claims-hero">
        <span><i class="bi bi-receipt-cutoff" /></span>
        <div>
          <h1>{{ totalClaimsText }}</h1>
          <p>รายการขึ้นเงินรางวัลสลากดิจิทัล</p>
        </div>
      </div>
    </BlueHeader>

    <section class="content-sheet reward-claims-page">
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
            <div class="reward-claim-row-head">
              <span>{{ claim.reference || `รายการ #${claim.id}` }}</span>
              <strong :class="['reward-claim-status', statusClass(claim.status)]">{{ statusText(claim.status) }}</strong>
            </div>
            <div class="reward-claim-row-body">
              <div>
                <span>เลขสลากฯ</span>
                <strong>{{ getTicketNumber(claim.ticket) || '-' }}</strong>
              </div>
              <div>
                <span>รางวัล</span>
                <strong>{{ claimPrizeSummary(claim) }}</strong>
              </div>
              <div>
                <span>เงินรางวัล</span>
                <strong>{{ formatMoney(claim.prize_amount) }} บาท</strong>
              </div>
            </div>
            <div class="reward-claim-row-foot">
              <span><i class="bi bi-calendar3" />{{ formatDate(claim.submitted_at || claim.created_at) }}</span>
              <span><i class="bi" :class="payoutIcon(claim.payout_method)" />{{ payoutText(claim.payout_method) }}</span>
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

const totalClaimsText = computed(() => claims.value.length > 0 ? `${claims.value.length.toLocaleString('th-TH')} รายการ` : 'ประวัติรายการ')

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

const payoutText = (method: unknown) => String(method || '') === 'bank_transfer' ? 'โอนธนาคาร' : 'เข้า G-Wallet'
const payoutIcon = (method: unknown) => String(method || '') === 'bank_transfer' ? 'bi-bank2' : 'bi-wallet2'
const claimPrizeSummary = (claim: Record<string, any>) => {
  const prizes = Array.isArray(claim.prizes) ? claim.prizes : []

  if (prizes.length > 1) {
    return `ถูกรางวัล ${prizes.length.toLocaleString('th-TH')} รางวัล`
  }

  return prizeTypeText(prizes[0]?.prize_type || claim.prize_type)
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
const formatDate = (value: unknown) => {
  if (!value) {
    return '-'
  }

  const date = new Date(String(value))

  if (Number.isNaN(date.getTime())) {
    return String(value)
  }

  return date.toLocaleDateString('th-TH', {
    day: 'numeric',
    month: 'short',
    year: 'numeric'
  })
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
.reward-claims-hero {
  align-items: flex-start;
  color: #fff;
  display: flex;
  gap: 12px;
  margin-top: 18px;
}

.reward-claims-hero > span {
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

.reward-claims-hero h1,
.reward-claims-hero p {
  margin: 0;
}

.reward-claims-hero h1 {
  font-size: 24px;
  font-weight: 900;
  line-height: 1.2;
}

.reward-claims-hero p {
  font-size: 14px;
  font-weight: 800;
  margin-top: 4px;
  opacity: .92;
}

.reward-claims-page {
  display: grid;
  gap: 14px;
  margin-left: auto;
  margin-right: auto;
  max-width: 640px;
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
  display: grid;
  gap: 12px;
}

.reward-claim-row {
  background: #fff;
  border: 1px solid #e8edf4;
  border-radius: 8px;
  box-shadow: 0 10px 22px rgba(22, 46, 82, .08);
  color: inherit;
  display: grid;
  gap: 12px;
  padding: 16px;
  text-decoration: none;
}

.reward-claim-row-head,
.reward-claim-row-body,
.reward-claim-row-foot {
  display: flex;
  gap: 10px;
  justify-content: space-between;
}

.reward-claim-row-head {
  align-items: flex-start;
}

.reward-claim-row-head > span {
  color: #17335f;
  font-size: 15px;
  font-weight: 900;
  min-width: 0;
  overflow-wrap: anywhere;
}

.reward-claim-status {
  border-radius: 999px;
  flex: 0 0 auto;
  font-size: 12px;
  font-weight: 900;
  padding: 6px 9px;
}

.reward-claim-status.is-paid,
.reward-claim-status.is-approved {
  background: #e7f8ef;
  color: #087a3a;
}

.reward-claim-status.is-pending {
  background: #fff5db;
  color: #9a6100;
}

.reward-claim-status.is-rejected {
  background: #fee2e2;
  color: #b91c1c;
}

.reward-claim-row-body > div {
  display: grid;
  gap: 2px;
}

.reward-claim-row-body > div:last-child {
  text-align: right;
}

.reward-claim-row-body span,
.reward-claim-row-foot {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

.reward-claim-row-body strong {
  color: #111827;
  font-size: 18px;
  font-weight: 900;
}

.reward-claim-row-foot {
  border-top: 1px solid #eef2f7;
  flex-wrap: wrap;
  padding-top: 12px;
}

.reward-claim-row-foot span {
  align-items: center;
  display: inline-flex;
  gap: 6px;
}

.reward-claims-more {
  justify-self: center;
  min-width: 160px;
}
</style>

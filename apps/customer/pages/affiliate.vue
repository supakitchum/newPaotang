<template>
  <MobileShell active-nav="menu" show-bottom-nav>
    <BlueHeader class="affiliate-blue-header" title="แนะนำเพื่อน" back-to="/profile" min-height="280px">
      <div class="affiliate-hero">
        <i class="bi bi-share-fill" />
        <div>
          <h2>Affiliate ของฉัน</h2>
          <p>สมัคร ดูคอมมิชชัน และขอถอนเงินได้ด้วยบัญชีลูกค้านี้</p>
        </div>
      </div>
    </BlueHeader>

    <section class="content-sheet affiliate-page">
      <div v-if="isLoading" class="muted-text text-center py-4">กำลังโหลดข้อมูล...</div>

      <div v-else-if="!overview.is_affiliate" class="affiliate-card affiliate-start-card">
        <div class="affiliate-start-icon">
          <i class="bi bi-person-plus-fill" />
        </div>
        <h2>เริ่มเป็นผู้แนะนำ</h2>
        <p>ระบบจะผูก Affiliate เข้ากับบัญชีลูกค้าของคุณโดยอัตโนมัติ</p>
        <button class="primary-pill" type="button" :disabled="isSubmitting" @click="register">
          <span v-if="isSubmitting" class="spinner-border spinner-border-sm me-2" />
          สมัคร Affiliate
        </button>
      </div>

      <template v-else>
        <section class="affiliate-card affiliate-summary-card">
          <div>
            <span class="muted-text">ยอดถอนได้</span>
            <strong>{{ formatMoney(overview.stats.available_balance) }} บาท</strong>
          </div>
          <div>
            <span class="muted-text">คอมที่อนุมัติแล้ว</span>
            <strong>{{ formatMoney(overview.stats.approved_commission) }} บาท</strong>
          </div>
          <div>
            <span class="muted-text">รอคำนวณ/รออนุมัติ</span>
            <strong>{{ formatMoney(overview.stats.pending_commission) }} บาท</strong>
          </div>
        </section>

        <section class="affiliate-card">
          <div class="affiliate-section-head">
            <div>
              <h2>ลิงก์แนะนำ</h2>
              <p>แชร์ลิงก์นี้ให้เพื่อนสมัครหรือซื้อผ่านร้าน</p>
            </div>
            <span class="affiliate-code">{{ referralCode }}</span>
          </div>
          <div v-if="canonicalReferralLink" class="affiliate-link-box">
            <span>{{ canonicalReferralLink }}</span>
            <button type="button" @click="copyLink">
              <i class="bi bi-copy" />
            </button>
          </div>
          <p v-else class="muted-text mb-0">ยังไม่มีลิงก์แนะนำ</p>
        </section>

        <section class="affiliate-card">
          <div class="affiliate-section-head">
            <div>
              <h2>ขอถอนเงิน</h2>
              <p>ถอนได้ไม่เกินยอดที่อนุมัติและยังไม่ถูกกันไว้</p>
            </div>
          </div>
          <form class="affiliate-payout-form" @submit.prevent="requestPayout">
            <label>
              <span>จำนวนเงิน (บาท)</span>
              <input v-model="payoutAmount" inputmode="decimal" placeholder="0.00">
            </label>
            <label>
              <span>ช่องทางถอน</span>
              <select v-model="payoutMethod">
                <option value="bank_transfer">โอนเข้าบัญชีธนาคาร</option>
                <option value="wallet_credit">เติมเข้า wallet</option>
              </select>
            </label>
            <label v-if="payoutMethod === 'bank_transfer'">
              <span>ธนาคาร</span>
              <input v-model="bankName" placeholder="ชื่อธนาคาร">
            </label>
            <label v-if="payoutMethod === 'bank_transfer'">
              <span>เลขบัญชี</span>
              <input v-model="bankAccountNumber" inputmode="numeric" placeholder="เลขบัญชีธนาคาร">
            </label>
            <button class="primary-pill affiliate-submit" type="submit" :disabled="isSubmitting || overview.stats.available_balance <= 0">
              <span v-if="isSubmitting" class="spinner-border spinner-border-sm me-2" />
              ส่งคำขอถอน
            </button>
          </form>
        </section>

        <section class="affiliate-card">
          <div class="affiliate-section-head">
            <h2>รายการคอมมิชชันล่าสุด</h2>
            <NuxtLink to="/affiliate" @click.prevent="refresh">รีเฟรช</NuxtLink>
          </div>
          <div v-if="overview.commissions.length === 0" class="affiliate-empty">ยังไม่มีรายการคอมมิชชัน</div>
          <article v-for="commission in overview.commissions" v-else :key="commission.id" class="affiliate-row">
            <div>
              <strong>{{ commission.order_id || commission.id }}</strong>
              <span>{{ statusText(commission.status) }} · {{ dateText(commission.calculated_at || commission.created_at) }}</span>
            </div>
            <strong>{{ formatMoney(commission.amount) }} บาท</strong>
          </article>
        </section>

        <section class="affiliate-card">
          <div class="affiliate-section-head">
            <h2>รายการถอนล่าสุด</h2>
          </div>
          <div v-if="overview.payouts.length === 0" class="affiliate-empty">ยังไม่มีรายการถอน</div>
          <article v-for="payout in overview.payouts" v-else :key="payout.id" class="affiliate-row">
            <div>
              <strong>{{ payout.payout_method === 'wallet_credit' ? 'เติมเข้า wallet' : 'โอนเข้าบัญชี' }}</strong>
              <span>{{ statusText(payout.status) }} · {{ dateText(payout.created_at) }}</span>
            </div>
            <strong>{{ formatMoney(payout.amount) }} บาท</strong>
          </article>
        </section>
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

const emptyOverview = () => ({
  is_affiliate: false,
  affiliate: null as Record<string, any> | null,
  links: [] as Record<string, any>[],
  stats: {
    total_commission: 0,
    approved_commission: 0,
    pending_commission: 0,
    requested_payout: 0,
    available_balance: 0,
    converted_count: 0
  },
  commissions: [] as Record<string, any>[],
  payouts: [] as Record<string, any>[]
})

const overview = ref(emptyOverview())
const isLoading = ref(false)
const isSubmitting = ref(false)
const payoutAmount = ref('')
const payoutMethod = ref('bank_transfer')
const bankName = ref('')
const bankAccountNumber = ref('')

const primaryLink = computed(() => overview.value.links[0] || null)
const referralCode = computed(() => String(overview.value.affiliate?.code || primaryLink.value?.code || '').trim())
const isCanonicalRefLink = (value: string) => value.includes(`ref=${encodeURIComponent(referralCode.value)}`) && !value.includes('/a/')
const canonicalReferralLink = computed(() => {
  if (!referralCode.value) {
    return ''
  }

  const backendLink = String(
    primaryLink.value?.canonical_url ||
    primaryLink.value?.url ||
    overview.value.affiliate?.canonical_url ||
    overview.value.affiliate?.referral_url ||
    ''
  )

  if (isCanonicalRefLink(backendLink)) {
    return backendLink
  }

  return `${process.client ? window.location.origin : ''}/?ref=${encodeURIComponent(referralCode.value)}`
})

const formatMoney = (value: unknown) => new Intl.NumberFormat('th-TH', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2
}).format(Number(value || 0))

const dateText = (value: unknown) => {
  if (!value) {
    return '-'
  }

  return new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'short',
    timeStyle: 'short'
  }).format(new Date(String(value)))
}

const statusText = (value: unknown) => {
  const status = String(value || '')
  const map: Record<string, string> = {
    active: 'ใช้งานอยู่',
    calculated: 'รออนุมัติ',
    approved: 'อนุมัติแล้ว',
    pending: 'รอดำเนินการ',
    paid: 'จ่ายแล้ว',
    reversed: 'กลับรายการ'
  }

  return map[status] || status || '-'
}

const refresh = async () => {
  isLoading.value = true
  try {
    overview.value = await platformApi.affiliateOverview()
  } catch (error: any) {
    showAlert({
      title: 'โหลดข้อมูล Affiliate ไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isLoading.value = false
  }
}

const register = async () => {
  isSubmitting.value = true
  try {
    overview.value = await platformApi.registerAffiliate()
    showAlert({ title: 'สมัคร Affiliate สำเร็จ', message: 'ระบบสร้างลิงก์แนะนำให้แล้ว', variant: 'success' })
  } catch (error: any) {
    showAlert({
      title: 'สมัคร Affiliate ไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}

const copyLink = async () => {
  if (!canonicalReferralLink.value) {
    return
  }

  await navigator.clipboard?.writeText(canonicalReferralLink.value)
  showAlert({ title: 'คัดลอกลิงก์แล้ว', message: 'นำลิงก์ไปแชร์ต่อได้ทันที', variant: 'success' })
}

const requestPayout = async () => {
  isSubmitting.value = true
  try {
    await platformApi.createAffiliatePayout({
      amount: payoutAmount.value,
      payout_method: payoutMethod.value,
      bank_account: {
        bank_name: bankName.value,
        account_number: bankAccountNumber.value
      }
    })
    payoutAmount.value = ''
    await refresh()
    showAlert({ title: 'ส่งคำขอถอนสำเร็จ', message: 'รายการถอนถูกบันทึกแล้ว', variant: 'success' })
  } catch (error: any) {
    showAlert({
      title: 'ถอนเงินไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาตรวจสอบจำนวนเงินแล้วลองใหม่',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}

onMounted(refresh)
</script>

<style scoped>
.affiliate-hero {
  align-items: flex-start;
  display: flex;
  gap: 12px;
  margin-top: 22px;
  min-width: 0;
}

.affiliate-hero i,
.affiliate-start-icon {
  background: #fff;
  border-radius: 14px;
  color: #0b69dc;
  display: grid;
  font-size: 26px;
  height: 48px;
  place-items: center;
  width: 48px;
}

.affiliate-hero h2,
.affiliate-card h2 {
  font-size: 20px;
  font-weight: 800;
  margin: 0 0 4px;
}

.affiliate-hero div {
  min-width: 0;
}

.affiliate-hero p,
.affiliate-card p {
  margin: 0;
  overflow-wrap: anywhere;
}

.affiliate-page {
  box-sizing: border-box;
  display: grid;
  gap: 12px;
  margin-top: -18px;
  margin-left: auto;
  margin-right: auto;
  max-width: 960px;
  padding-left: 16px;
  padding-right: 16px;
  width: 100%;
}

.affiliate-card {
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 8px 22px rgba(22, 46, 82, .09);
  min-width: 0;
  padding: 16px;
}

.affiliate-start-card {
  align-items: center;
  display: grid;
  gap: 12px;
  min-height: 260px;
  text-align: center;
}

.affiliate-start-icon {
  background: #eaf5ff;
  height: 72px;
  justify-self: center;
  width: 72px;
}

.affiliate-summary-card {
  display: grid;
  gap: 12px;
}

.affiliate-summary-card div {
  align-items: center;
  border-bottom: 1px solid #edf1f7;
  display: flex;
  justify-content: space-between;
  gap: 12px;
  min-width: 0;
  padding-bottom: 10px;
}

.affiliate-summary-card div:last-child {
  border-bottom: 0;
  padding-bottom: 0;
}

.affiliate-summary-card strong {
  color: #0b69dc;
  font-size: 18px;
  line-height: 1.2;
  text-align: right;
  white-space: nowrap;
}

.affiliate-section-head {
  align-items: flex-start;
  display: flex;
  gap: 12px;
  justify-content: space-between;
  margin-bottom: 12px;
  min-width: 0;
}

.affiliate-section-head > div {
  min-width: 0;
}

.affiliate-section-head a {
  color: #0b69dc;
  font-weight: 700;
}

.affiliate-code {
  background: #eaf5ff;
  border-radius: 999px;
  color: #0b69dc;
  font-size: 12px;
  font-weight: 800;
  max-width: 46%;
  overflow-wrap: anywhere;
  padding: 6px 10px;
  text-align: center;
}

.affiliate-link-box {
  align-items: center;
  background: #f6f8fb;
  border: 1px solid #e4eaf2;
  border-radius: 12px;
  display: grid;
  gap: 8px;
  grid-template-columns: 1fr 42px;
  min-width: 0;
  padding: 10px 12px;
}

.affiliate-link-box span {
  color: #17335f;
  font-size: 13px;
  overflow-wrap: anywhere;
}

.affiliate-link-box button {
  align-items: center;
  background: #0b69dc;
  border: 0;
  border-radius: 50%;
  color: #fff;
  display: grid;
  height: 38px;
  place-items: center;
  width: 38px;
}

.affiliate-payout-form {
  display: grid;
  gap: 10px;
}

.affiliate-payout-form label {
  display: grid;
  gap: 6px;
}

.affiliate-payout-form label span {
  color: #53657d;
  font-size: 13px;
  font-weight: 700;
}

.affiliate-payout-form input,
.affiliate-payout-form select {
  background: #f9fbfe;
  border: 1px solid #d9e2ec;
  border-radius: 12px;
  font: inherit;
  max-width: 100%;
  min-height: 46px;
  min-width: 0;
  padding: 0 12px;
  width: 100%;
}

.affiliate-submit {
  width: 100%;
}

.affiliate-row {
  align-items: center;
  border-top: 1px solid #edf1f7;
  display: flex;
  gap: 10px;
  justify-content: space-between;
  min-width: 0;
  padding: 12px 0;
}

.affiliate-row div {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.affiliate-row strong,
.affiliate-row span {
  overflow-wrap: anywhere;
}

.affiliate-row span,
.affiliate-empty {
  color: #64748b;
  font-size: 13px;
}

@media (max-width: 360px) {
  .affiliate-blue-header {
    padding-left: 18px;
    padding-right: 18px;
  }

  .affiliate-hero {
    gap: 10px;
  }

  .affiliate-hero h2,
  .affiliate-card h2 {
    font-size: 18px;
  }

  .affiliate-section-head,
  .affiliate-row,
  .affiliate-summary-card div {
    align-items: stretch;
    flex-direction: column;
  }

  .affiliate-code {
    max-width: 100%;
  }

  .affiliate-summary-card strong,
  .affiliate-row > strong {
    text-align: left;
  }
}

@media (min-width: 768px) {
  .affiliate-page {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    padding-left: 24px;
    padding-right: 24px;
  }

  .affiliate-summary-card,
  .affiliate-start-card {
    grid-column: 1 / -1;
  }

  .affiliate-summary-card {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .affiliate-summary-card div {
    align-items: flex-start;
    border-bottom: 0;
    border-right: 1px solid #edf1f7;
    display: grid;
    padding-bottom: 0;
    padding-right: 12px;
  }

  .affiliate-summary-card div:last-child {
    border-right: 0;
    padding-right: 0;
  }

  .affiliate-summary-card strong {
    text-align: left;
    white-space: normal;
  }
}
</style>

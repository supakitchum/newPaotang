<template>
  <PinKeypadScreen
    v-if="affiliateStep === 'pin'"
    title="ใส่รหัส PIN 6 หลัก"
    subtitle="เพื่อเข้าใช้ระบบ Affiliate"
    :digits="affiliatePinDigits"
    :error="affiliatePinError"
    :disabled="isVerifyingPin"
    @append="appendAffiliatePinDigit"
    @remove="removeAffiliatePinDigit"
    @back="goBackFromPin"
  />

  <MobileShell v-else active-nav="menu" show-bottom-nav>
    <BlueHeader class="affiliate-blue-header" title="ตัวแทนจำหน่าย" back-to="/profile" min-height="248px">
      <div class="affiliate-hero">
        <div class="affiliate-hero-icon">
          <i class="bi bi-share-fill" />
        </div>
        <div class="affiliate-hero-copy">
          <h1>ตัวแทนจำหน่าย</h1>
          <p>แนะนำผู้อื่นเพื่อรับผลตอบแทนการขาย</p>
        </div>
      </div>
    </BlueHeader>

    <section class="content-sheet affiliate-page">
      <div v-if="isLoading" class="affiliate-loading">กำลังโหลดข้อมูล...</div>

      <div v-else-if="!overview.is_affiliate" class="affiliate-start">
        <div class="affiliate-start-icon">
          <i class="bi bi-person-plus-fill" />
        </div>
        <div>
          <h2>เริ่มเป็นตัวแทนจำหน่าย</h2>
          <p>กรอกชื่อร้านที่จะแสดงให้ลูกค้าเห็น แล้วระบบจะสร้างรหัสแนะนำและลิงก์สำหรับแชร์ให้ทันที</p>
        </div>
        <label class="affiliate-store-field">
          <span>ชื่อร้าน</span>
          <input
            v-model.trim="affiliateStoreName"
            maxlength="80"
            placeholder="เช่น ร้านโชคดีออนไลน์"
            autocomplete="organization"
          >
        </label>
        <p v-if="affiliateStoreNameError" class="affiliate-form-alert mb-0">{{ affiliateStoreNameError }}</p>
        <button class="primary-pill" type="button" :disabled="isSubmitting" @click="register">
          <span v-if="isSubmitting" class="spinner-border spinner-border-sm me-2" />
          สมัครเป็นตัวแทนจำหน่าย
        </button>
      </div>

      <template v-else>
        <article class="affiliate-card affiliate-store-summary">
          <div class="affiliate-store-summary-icon">
            <i class="bi bi-shop" />
          </div>
          <div>
            <span>ชื่อร้านของคุณ</span>
            <strong>{{ affiliateStoreDisplayName }}</strong>
            <p>ชื่อนี้จะแสดงให้ลูกค้าที่เข้าผ่านลิงก์แนะนำเห็น</p>
          </div>
        </article>

        <section class="affiliate-metrics" aria-label="Affiliate summary">
          <article v-for="widget in statWidgets" :key="widget.key" class="affiliate-widget">
            <span>{{ widget.label }}</span>
            <strong>{{ widget.value }}</strong>
            <small>{{ widget.caption }}</small>
          </article>
        </section>

        <nav class="affiliate-tabs" aria-label="Affiliate sections">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            :class="{ active: activeTab === tab.key }"
            type="button"
            @click="activeTab = tab.key"
          >
            <i :class="tab.icon" />
            <span>{{ tab.label }}</span>
          </button>
        </nav>

        <section v-if="activeTab === 'overview'" class="affiliate-stack">
          <article class="affiliate-card">
            <div class="affiliate-section-head">
              <div>
                <h2>ลิงก์แนะนำ</h2>
                <p>แชร์ลิงก์นี้ให้เพื่อนสมัครหรือซื้อผ่านร้าน</p>
              </div>
              <span class="affiliate-code">{{ referralCode }}</span>
            </div>

            <div v-if="canonicalReferralLink" class="affiliate-link-box">
              <span>{{ canonicalReferralLink }}</span>
              <button type="button" aria-label="คัดลอกลิงก์แนะนำ" @click="copyLink">
                <i class="bi bi-copy" />
              </button>
            </div>
            <p v-else class="affiliate-empty mb-0">ยังไม่มีลิงก์แนะนำ</p>
          </article>

          <article class="affiliate-card affiliate-bank-summary">
            <div class="affiliate-section-head">
              <div>
                <h2>บัญชีรับเงิน</h2>
                <p>ใช้บัญชีเดียวกับบัญชีรับเงินรางวัล</p>
              </div>
              <NuxtLink class="affiliate-text-button" to="/profile/reward-bank?redirect=/affiliate">แก้ไข</NuxtLink>
            </div>
            <div v-if="hasBankAccount" class="affiliate-bank-line">
              <strong>{{ bankName }}</strong>
              <span>{{ bankAccountName || '-' }}</span>
              <span>{{ maskedBankAccount }}</span>
            </div>
            <p v-else class="affiliate-empty mb-0">ยังไม่ได้บันทึกบัญชีรับเงิน</p>
          </article>
        </section>

        <section v-else-if="activeTab === 'withdraw'" class="affiliate-stack">
          <article class="affiliate-card affiliate-bank-summary">
            <div class="affiliate-section-head">
              <div>
                <h2>บัญชีรับเงินรางวัล</h2>
                <p>บัญชีนี้จะถูกใช้กับการถอนค่าคอมมิชชันด้วย</p>
              </div>
              <NuxtLink class="affiliate-text-button" to="/profile/reward-bank?redirect=/affiliate">แก้ไข</NuxtLink>
            </div>
            <div v-if="hasBankAccount" class="affiliate-bank-line">
              <strong>{{ bankName }}</strong>
              <span>{{ bankAccountName || '-' }}</span>
              <span>{{ maskedBankAccount }}</span>
            </div>
            <div v-else class="affiliate-bank-empty">
              <p>ยังไม่ได้บันทึกบัญชีรับเงิน</p>
              <NuxtLink class="secondary-pill" to="/profile/reward-bank?redirect=/affiliate">เพิ่มบัญชีรับเงิน</NuxtLink>
            </div>
          </article>

          <article class="affiliate-card">
            <div class="affiliate-section-head">
              <div>
                <h2>ขอถอนเงิน</h2>
                <p>ถอนได้ไม่เกินยอดคงเหลือที่อนุมัติแล้ว</p>
                <p class="affiliate-minimum-note">ถอนขั้นต่ำ {{ formatMoney(minimumPayoutAmount) }} บาท</p>
              </div>
            </div>

            <form class="affiliate-form" @submit.prevent="requestPayout">
              <label>
                <span>จำนวนเงิน (บาท)</span>
                <input v-model="payoutAmount" inputmode="decimal" placeholder="0.00">
              </label>
              <label>
                <span>ช่องทางถอน</span>
                <select v-model="payoutMethod">
                  <option value="bank_transfer">โอนเข้าบัญชีรับเงิน</option>
                  <option value="wallet_credit">เติมเข้า wallet</option>
                </select>
              </label>

              <div v-if="payoutMethod === 'bank_transfer'" class="affiliate-bank-preview" :class="{ missing: !hasBankAccount }">
                <i class="bi bi-bank2" />
                <div>
                  <strong>{{ hasBankAccount ? bankName : 'ยังไม่มีบัญชีรับเงิน' }}</strong>
                  <span>{{ hasBankAccount ? `${bankAccountName || '-'} · ${maskedBankAccount}` : 'กรุณาบันทึกบัญชีรับเงินก่อนถอน' }}</span>
                </div>
              </div>

              <p v-if="!hasMinimumBalance" class="affiliate-form-alert">ยอดถอนได้ยังไม่ถึงขั้นต่ำ {{ formatMoney(minimumPayoutAmount) }} บาท</p>
              <p v-else-if="payoutAmount && !payoutAmountMeetsMinimum" class="affiliate-form-alert">กรุณากรอกยอดถอนอย่างน้อย {{ formatMoney(minimumPayoutAmount) }} บาท</p>

              <button class="primary-pill affiliate-submit" type="submit" :disabled="!canRequestPayout">
                <span v-if="isSubmitting" class="spinner-border spinner-border-sm me-2" />
                ส่งคำขอถอน
              </button>
            </form>
          </article>
        </section>

        <section v-else-if="activeTab === 'commissions'" class="affiliate-card">
          <div class="affiliate-section-head">
            <div>
              <h2>คอมมิชชันล่าสุด</h2>
              <p>รายการที่คำนวณจากยอดซื้อผ่านลิงก์แนะนำ</p>
            </div>
            <button class="affiliate-text-button" type="button" @click="refresh">รีเฟรช</button>
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

        <section v-else class="affiliate-card">
          <div class="affiliate-section-head">
            <div>
              <h2>ประวัติถอนเงิน</h2>
              <p>ติดตามคำขอถอนค่าคอมมิชชันของคุณ</p>
            </div>
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

type AffiliateTab = 'overview' | 'withdraw' | 'commissions' | 'payouts'

const platformApi = usePlatformApi()
const { showAlert } = useAppAlert()
const { setAuthUser, setPinVerified, user } = useAuth()

const emptyOverview = () => ({
  is_affiliate: false,
  affiliate: null as Record<string, any> | null,
  links: [] as Record<string, any>[],
  profile: {} as Record<string, any>,
  stats: {
    total_commission: 0,
    approved_commission: 0,
    pending_commission: 0,
    requested_payout: 0,
    available_balance: 0,
    converted_count: 0,
    visitor_count: 0,
    registered_count: 0
  },
  payout_policy: {
    minimum_payout: 300,
    minimum_payout_amount: 300
  },
  commissions: [] as Record<string, any>[],
  payouts: [] as Record<string, any>[]
})

const overview = ref(emptyOverview())
const activeTab = ref<AffiliateTab>('overview')
const affiliateStep = ref<'pin' | 'content'>('pin')
const affiliatePinDigits = ref('')
const affiliatePinError = ref('')
const isLoading = ref(false)
const isSubmitting = ref(false)
const isVerifyingPin = ref(false)
const affiliateStoreName = ref('')
const affiliateStoreNameError = ref('')
const payoutAmount = ref('')
const payoutMethod = ref('bank_transfer')
const bankName = ref('')
const bankAccountName = ref('')
const bankAccountNumber = ref('')

const tabs = [
  { key: 'overview' as const, label: 'ภาพรวม', icon: 'bi bi-grid-1x2-fill' },
  { key: 'withdraw' as const, label: 'ถอนเงิน', icon: 'bi bi-bank2' },
  { key: 'commissions' as const, label: 'คอม', icon: 'bi bi-cash-stack' },
  { key: 'payouts' as const, label: 'ประวัติ', icon: 'bi bi-clock-history' }
]

const primaryLink = computed(() => overview.value.links[0] || null)
const referralCode = computed(() => String(primaryLink.value?.code || overview.value.affiliate?.code || '').trim())
const affiliateStoreDisplayName = computed(() => String(
  overview.value.affiliate?.name ||
  overview.value.affiliate?.store_name ||
  overview.value.affiliate?.display_name ||
  'ร้านตัวแทนจำหน่าย'
).trim())
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

const bankPayload = computed(() => ({
  bank_name: bankName.value.trim(),
  account_name: bankAccountName.value.trim(),
  account_number: bankAccountNumber.value.trim()
}))

const hasBankAccount = computed(() => Boolean(bankPayload.value.bank_name && bankPayload.value.account_number))
const availableBalance = computed(() => Number(overview.value.stats.available_balance || 0))
const minimumPayoutAmount = computed(() => {
  const policy = overview.value.payout_policy || {}
  const value = Number(policy.minimum_payout_amount ?? policy.minimum_payout ?? 300)

  return Number.isFinite(value) && value > 0 ? value : 300
})
const payoutAmountValue = computed(() => Number(payoutAmount.value || 0))
const hasMinimumBalance = computed(() => availableBalance.value >= minimumPayoutAmount.value)
const payoutAmountMeetsMinimum = computed(() => payoutAmountValue.value >= minimumPayoutAmount.value)
const canRequestPayout = computed(() => {
  if (isSubmitting.value || !hasMinimumBalance.value || !payoutAmountMeetsMinimum.value) {
    return false
  }

  return payoutMethod.value !== 'bank_transfer' || hasBankAccount.value
})
const maskedBankAccount = computed(() => {
  const number = bankAccountNumber.value.replace(/\s+/g, '')

  if (number.length <= 4) {
    return number || '-'
  }

  return `${'*'.repeat(Math.max(0, number.length - 4))}${number.slice(-4)}`
})

const statWidgets = computed(() => [
  {
    key: 'available',
    label: 'ยอดถอนได้',
    value: `${formatMoney(overview.value.stats.available_balance)} บาท`,
    caption: 'พร้อมถอน'
  },
  {
    key: 'approved',
    label: 'อนุมัติแล้ว',
    value: `${formatMoney(overview.value.stats.approved_commission)} บาท`,
    caption: 'คอมมิชชัน'
  },
  {
    key: 'pending',
    label: 'รอตรวจ',
    value: `${formatMoney(overview.value.stats.pending_commission)} บาท`,
    caption: 'รอคำนวณ/อนุมัติ'
  },
  {
    key: 'converted',
    label: 'ยอดสำเร็จ',
    value: `${Number(overview.value.stats.converted_count || 0)}`,
    caption: 'รายการ'
  },
  {
    key: 'visitors',
    label: 'กดลิงก์',
    value: new Intl.NumberFormat('th-TH').format(Number(overview.value.stats.visitor_count || 0)),
    caption: 'ผู้เข้าชม'
  },
  {
    key: 'registered',
    label: 'สมัครผ่านลิงก์',
    value: new Intl.NumberFormat('th-TH').format(Number(overview.value.stats.registered_count || 0)),
    caption: 'บัญชี'
  }
])

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

const hydrateBankAccount = (profile: Record<string, any> | null | undefined) => {
  const bank = profile?.reward_payout_bank_account || profile?.bank_account || overview.value.affiliate?.payout_profile?.bank_account || {}

  bankName.value = String(bank.bank_name || bank.bank || '')
  bankAccountName.value = String(bank.account_name || bank.bank_deposit_name || '')
  bankAccountNumber.value = String(bank.account_number || bank.bank_deposit_number || '')
}

const refresh = async () => {
  isLoading.value = true
  try {
    overview.value = await platformApi.affiliateOverview()
    hydrateBankAccount(overview.value.profile)
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

const resetAffiliatePinEntry = () => {
  affiliatePinDigits.value = ''
  affiliatePinError.value = ''
}

const applyAffiliatePinResponse = (response: Record<string, any>) => {
  setAuthUser(response.user || {
    ...(user.value || {}),
    has_pin: response.has_pin,
    pin_verified: response.pin_verified,
    pin_setup_required: response.pin_setup_required,
    pin_required: response.pin_required
  })
  setPinVerified(Boolean(response.pin_verified))
}

const verifyAffiliatePin = async () => {
  if (isVerifyingPin.value || affiliatePinDigits.value.length !== 6) {
    return
  }

  isVerifyingPin.value = true
  affiliatePinError.value = ''

  try {
    const response = await platformApi.verifyPin({
      pin: affiliatePinDigits.value
    })

    applyAffiliatePinResponse(response)
    affiliateStep.value = 'content'
    resetAffiliatePinEntry()
    await refresh()
  } catch (error: any) {
    affiliatePinDigits.value = ''
    const code = error?.response?.data?.error?.code || error?.response?.data?.code

    if (code === 'pin_invalid') {
      affiliatePinError.value = 'PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง'
      return
    }

    if (code === 'pin_locked') {
      affiliatePinError.value = 'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่แล้วลองใหม่'
      return
    }

    if (code === 'pin_setup_required') {
      affiliatePinError.value = 'กรุณาตั้งค่า PIN ก่อนเข้าใช้ระบบ Affiliate'
      return
    }

    affiliatePinError.value = error?.response?.data?.message || 'ไม่สามารถยืนยัน PIN ได้ กรุณาลองใหม่อีกครั้ง'
  } finally {
    isVerifyingPin.value = false
  }
}

const appendAffiliatePinDigit = async (digit: string) => {
  if (!/^\d$/.test(digit) || affiliatePinDigits.value.length >= 6 || isVerifyingPin.value) {
    return
  }

  affiliatePinError.value = ''
  affiliatePinDigits.value = `${affiliatePinDigits.value}${digit}`

  if (affiliatePinDigits.value.length === 6) {
    await verifyAffiliatePin()
  }
}

const removeAffiliatePinDigit = () => {
  if (isVerifyingPin.value) {
    return
  }

  affiliatePinError.value = ''
  affiliatePinDigits.value = affiliatePinDigits.value.slice(0, -1)
}

const goBackFromPin = async () => {
  if (isVerifyingPin.value) {
    return
  }

  await navigateTo('/profile')
}

const register = async () => {
  if (affiliateStoreName.value.trim() === '') {
    affiliateStoreNameError.value = 'กรุณากรอกชื่อร้านก่อนสมัครเป็นตัวแทนจำหน่าย'
    return
  }

  isSubmitting.value = true
  affiliateStoreNameError.value = ''
  try {
    overview.value = await platformApi.registerAffiliate({
      name: affiliateStoreName.value.trim()
    })
    hydrateBankAccount(overview.value.profile)
    showAlert({ title: 'สมัคร Affiliate สำเร็จ', message: 'ระบบสร้างลิงก์แนะนำให้แล้ว', variant: 'success' })
  } catch (error: any) {
    const fields = error?.response?.data?.error?.details?.fields || error?.response?.data?.details?.fields || {}
    affiliateStoreNameError.value = fields.name?.[0] || ''
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
  if (!hasMinimumBalance.value) {
    showAlert({ title: 'ยอดถอนไม่ถึงขั้นต่ำ', message: `ต้องมียอดถอนได้อย่างน้อย ${formatMoney(minimumPayoutAmount.value)} บาท`, variant: 'error' })
    return
  }

  if (!payoutAmountMeetsMinimum.value) {
    showAlert({ title: 'จำนวนเงินต่ำกว่าขั้นต่ำ', message: `ถอนขั้นต่ำ ${formatMoney(minimumPayoutAmount.value)} บาท`, variant: 'error' })
    return
  }

  if (payoutMethod.value === 'bank_transfer' && !hasBankAccount.value) {
    showAlert({ title: 'กรุณาบันทึกบัญชีรับเงิน', message: 'ต้องมีธนาคารและเลขบัญชีก่อนถอนเข้าบัญชี', variant: 'error' })
    return
  }

  isSubmitting.value = true
  try {
    await platformApi.createAffiliatePayout({
      amount: payoutAmount.value,
      payout_method: payoutMethod.value,
      bank_account: payoutMethod.value === 'bank_transfer' ? bankPayload.value : {}
    })
    payoutAmount.value = ''
    await refresh()
    activeTab.value = 'payouts'
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

onMounted(resetAffiliatePinEntry)
</script>

<style scoped>
.affiliate-blue-header {
  overflow: visible;
}

.affiliate-hero {
  align-items: flex-start;
  display: flex;
  gap: 12px;
  margin-top: 18px;
  min-width: 0;
  padding-right: 4px;
}

.affiliate-hero-icon,
.affiliate-start-icon {
  background: #fff;
  border-radius: 14px;
  color: #0b69dc;
  display: grid;
  flex: 0 0 auto;
  font-size: 24px;
  height: 48px;
  place-items: center;
  width: 48px;
}

.affiliate-hero-copy {
  min-width: 0;
}

.affiliate-hero-copy p {
  font-size: 14px;
  font-weight: 800;
  margin: 0 0 4px;
}

.affiliate-hero-copy h1 {
  font-size: 22px;
  font-weight: 900;
  line-height: 1.28;
  margin: 0;
  overflow-wrap: anywhere;
}

.affiliate-page {
  box-sizing: border-box;
  display: grid;
  gap: 12px;
  margin-left: auto;
  margin-right: auto;
  margin-top: -58px;
  max-width: 920px;
  padding: 16px 16px calc(132px + env(safe-area-inset-bottom));
  width: 100%;
}

.affiliate-page > * {
  justify-self: center;
  margin-left: auto;
  margin-right: auto;
  max-width: 420px;
  width: 100%;
}

.affiliate-loading,
.affiliate-start,
.affiliate-card,
.affiliate-widget {
  background: #fff;
  box-shadow: 0 10px 24px rgba(22, 46, 82, .09);
}

.affiliate-loading {
  border-radius: 14px;
  color: #64748b;
  padding: 22px;
  text-align: center;
}

.affiliate-start {
  align-items: center;
  border-radius: 16px;
  display: grid;
  gap: 14px;
  min-height: 320px;
  padding: 22px;
  text-align: center;
}

.affiliate-start-icon {
  background: #eaf5ff;
  height: 72px;
  justify-self: center;
  width: 72px;
}

.affiliate-start h2,
.affiliate-card h2 {
  color: #111827;
  font-size: 18px;
  font-weight: 900;
  line-height: 1.25;
  margin: 0 0 4px;
}

.affiliate-start p,
.affiliate-card p {
  color: #64748b;
  font-size: 13px;
  line-height: 1.45;
  margin: 0;
}

.affiliate-store-field {
  display: grid;
  gap: 8px;
  text-align: left;
}

.affiliate-store-field span {
  color: #172554;
  font-size: 13px;
  font-weight: 900;
}

.affiliate-store-field input {
  background: #f8fbff;
  border: 1px solid #d8e7f7;
  border-radius: 14px;
  color: #172554;
  font-size: 15px;
  font-weight: 800;
  min-height: 48px;
  outline: 0;
  padding: 0 14px;
  width: 100%;
}

.affiliate-store-field input:focus {
  border-color: #0b69dc;
  box-shadow: 0 0 0 3px rgba(11, 105, 220, .12);
}

.affiliate-card .affiliate-minimum-note {
  color: #0b69dc;
  font-weight: 800;
  margin-top: 3px;
}

.affiliate-store-summary {
  align-items: center;
  border-radius: 16px;
  display: grid;
  gap: 12px;
  grid-template-columns: auto minmax(0, 1fr);
  padding: 16px;
}

.affiliate-store-summary-icon {
  align-items: center;
  background: #eaf5ff;
  border-radius: 14px;
  color: #0b69dc;
  display: inline-flex;
  font-size: 22px;
  height: 48px;
  justify-content: center;
  width: 48px;
}

.affiliate-store-summary span {
  color: #64748b;
  display: block;
  font-size: 12px;
  font-weight: 800;
  margin-bottom: 2px;
}

.affiliate-store-summary strong {
  color: #172554;
  display: block;
  font-size: 17px;
  font-weight: 900;
  line-height: 1.25;
  overflow-wrap: anywhere;
}

.affiliate-store-summary p {
  margin-top: 4px;
}

.affiliate-metrics {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.affiliate-widget {
  border-radius: 14px;
  display: grid;
  gap: 4px;
  min-height: 104px;
  min-width: 0;
  padding: 14px;
}

.affiliate-widget span,
.affiliate-widget small {
  color: #64748b;
  font-size: 12px;
  font-weight: 700;
}

.affiliate-widget strong {
  color: #0b69dc;
  font-size: 20px;
  font-weight: 900;
  line-height: 1.12;
  overflow-wrap: anywhere;
}

.affiliate-tabs {
  background: #eef6ff;
  border-radius: 16px;
  display: grid;
  gap: 4px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  padding: 4px;
}

.affiliate-tabs button {
  align-items: center;
  background: transparent;
  border: 0;
  border-radius: 13px;
  color: #5b6b82;
  display: grid;
  font-size: 11px;
  font-weight: 800;
  gap: 3px;
  min-height: 54px;
  min-width: 0;
  padding: 6px 2px;
}

.affiliate-tabs button.active {
  background: #fff;
  color: #0b69dc;
  box-shadow: 0 8px 18px rgba(37, 99, 235, .16);
}

.affiliate-tabs i {
  font-size: 16px;
}

.affiliate-stack {
  display: grid;
  gap: 12px;
}

.affiliate-card {
  border-radius: 16px;
  min-width: 0;
  padding: 16px;
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

.affiliate-code {
  background: #eaf5ff;
  border-radius: 999px;
  color: #0b69dc;
  flex: 0 1 auto;
  font-size: 12px;
  font-weight: 900;
  max-width: 42%;
  overflow-wrap: anywhere;
  padding: 6px 10px;
  text-align: center;
}

.affiliate-text-button {
  background: transparent;
  border: 0;
  color: #0b69dc;
  flex: 0 0 auto;
  font-weight: 800;
  padding: 0;
}

.affiliate-link-box {
  align-items: center;
  background: #f6f8fb;
  border: 1px solid #e4eaf2;
  border-radius: 14px;
  display: grid;
  gap: 8px;
  grid-template-columns: 1fr 42px;
  min-width: 0;
  padding: 10px 12px;
}

.affiliate-link-box span {
  color: #17335f;
  font-size: 13px;
  font-weight: 700;
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

.affiliate-bank-line {
  background: #f7fbff;
  border: 1px solid #dbeafe;
  border-radius: 14px;
  display: grid;
  gap: 4px;
  padding: 12px;
}

.affiliate-bank-line strong,
.affiliate-bank-preview strong {
  color: #17335f;
  font-size: 15px;
  font-weight: 900;
}

.affiliate-bank-line span,
.affiliate-bank-preview span {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
  overflow-wrap: anywhere;
}

.affiliate-bank-empty {
  display: grid;
  gap: 10px;
}

.affiliate-form {
  display: grid;
  gap: 10px;
}

.affiliate-form-alert {
  background: #fff7ed;
  border: 1px solid #fed7aa;
  border-radius: 12px;
  color: #9a3412;
  font-size: 12px;
  font-weight: 800;
  padding: 9px 10px;
}

.affiliate-form label {
  display: grid;
  gap: 6px;
}

.affiliate-form label span {
  color: #53657d;
  font-size: 13px;
  font-weight: 800;
}

.affiliate-form input,
.affiliate-form select {
  background: #f9fbfe;
  border: 1px solid #d9e2ec;
  border-radius: 12px;
  font: inherit;
  min-height: 48px;
  min-width: 0;
  padding: 0 12px;
  width: 100%;
}

.affiliate-bank-preview {
  align-items: center;
  background: #eefbf5;
  border: 1px solid #b8ead5;
  border-radius: 14px;
  display: grid;
  gap: 10px;
  grid-template-columns: 38px 1fr;
  min-width: 0;
  padding: 10px;
}

.affiliate-bank-preview.missing {
  background: #fff7ed;
  border-color: #fed7aa;
}

.affiliate-bank-preview i {
  align-items: center;
  background: #fff;
  border-radius: 50%;
  color: #0b69dc;
  display: grid;
  height: 38px;
  place-items: center;
  width: 38px;
}

.affiliate-bank-preview div {
  display: grid;
  gap: 2px;
  min-width: 0;
}

.affiliate-submit,
.secondary-pill,
.primary-pill {
  width: 100%;
}

.secondary-pill {
  align-items: center;
  background: #eef6ff;
  border: 1px solid #bfdbfe;
  border-radius: 999px;
  color: #0b69dc;
  display: inline-flex;
  font: inherit;
  font-weight: 900;
  justify-content: center;
  min-height: 46px;
  padding: 0 16px;
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

.affiliate-row > strong {
  color: #111827;
  flex: 0 0 auto;
  text-align: right;
}

.affiliate-row span,
.affiliate-empty {
  color: #64748b;
  font-size: 13px;
}

@media (max-width: 360px) {
  .affiliate-page {
    padding-left: 12px;
    padding-right: 12px;
  }

  .affiliate-hero-copy h1 {
    font-size: 20px;
  }

  .affiliate-widget {
    padding: 12px;
  }

  .affiliate-widget strong {
    font-size: 17px;
  }

  .affiliate-section-head,
  .affiliate-row {
    align-items: stretch;
    flex-direction: column;
  }

  .affiliate-code {
    max-width: 100%;
  }

  .affiliate-row > strong {
    text-align: left;
  }
}

@media (min-width: 768px) {
  .affiliate-page {
    margin-top: -42px;
    padding-left: 24px;
    padding-bottom: calc(140px + env(safe-area-inset-bottom));
    padding-right: 24px;
  }

  .affiliate-page > * {
    max-width: 920px;
  }

  .affiliate-metrics {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .affiliate-stack {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .affiliate-tabs button {
    align-items: center;
    display: flex;
    justify-content: center;
    min-height: 46px;
  }
}
</style>

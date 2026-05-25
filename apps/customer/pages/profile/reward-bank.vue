<template>
  <MobileShell active-nav="menu" show-bottom-nav>
    <BlueHeader title="บัญชีรับเงินรางวัล" back-to="/profile" min-height="214px">
      <div class="reward-bank-hero">
        <span class="reward-bank-icon"><i class="bi bi-bank2" /></span>
        <div>
          <p>ช่องทางรับเงิน</p>
          <h1>ใช้บัญชีนี้สำหรับรับเงินรางวัลและถอนค่าคอมมิชชัน</h1>
        </div>
      </div>
    </BlueHeader>

    <section class="content-sheet reward-bank-page">
      <article class="reward-bank-card">
        <div class="reward-bank-card-head">
          <h2>ข้อมูลบัญชีธนาคาร</h2>
          <p>เลือกชื่อธนาคารในประเทศไทย และกรอกชื่อบัญชีกับเลขบัญชีให้ตรงกับสมุดบัญชี</p>
        </div>

        <form class="reward-bank-form" @submit.prevent="saveBankAccount">
          <label>
            <span>ธนาคาร</span>
            <select v-model="bankName" :disabled="isLoading || isSaving">
              <option value="" disabled>เลือกธนาคาร</option>
              <option v-for="bank in thaiBankOptions" :key="bank" :value="bank">{{ bank }}</option>
            </select>
          </label>

          <label>
            <span>ชื่อบัญชี</span>
            <input
              v-model.trim="accountName"
              autocomplete="name"
              :disabled="isLoading || isSaving"
              placeholder="ชื่อเจ้าของบัญชี"
              type="text"
            >
          </label>

          <label>
            <span>เลขบัญชี</span>
            <input
              v-model="accountNumber"
              autocomplete="off"
              inputmode="numeric"
              :disabled="isLoading || isSaving"
              placeholder="เลขบัญชีธนาคาร"
              type="text"
              @beforeinput="allowDigitsOnly"
              @input="sanitizeAccountNumber"
            >
          </label>

          <div class="reward-bank-preview" :class="{ empty: !hasBankAccount }">
            <i class="bi bi-credit-card-2-front" />
            <div>
              <strong>{{ hasBankAccount ? bankName : 'ยังไม่ได้บันทึกบัญชีรับเงิน' }}</strong>
              <span>{{ hasBankAccount ? `${accountName || '-'} · ${maskedAccountNumber}` : 'บัญชีนี้จะถูกใช้ร่วมกันทั้งเงินรางวัลและ Affiliate' }}</span>
            </div>
          </div>

          <button class="primary-pill reward-bank-submit" type="submit" :disabled="isLoading || isSaving">
            <span v-if="isSaving" class="spinner-border spinner-border-sm me-2" />
            บันทึกบัญชีรับเงิน
          </button>
        </form>
      </article>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { thaiBankOptions } from '~/data/lottery'

definePageMeta({
  requiresAuth: true
})

const platformApi = usePlatformApi()
const route = useRoute()
const { restoreAuthState, setAuthUser } = useAuth()
const { showAlert } = useAppAlert()

const isLoading = ref(false)
const isSaving = ref(false)
const bankName = ref('')
const accountName = ref('')
const accountNumber = ref('')

const bankPayload = computed(() => ({
  bank_name: bankName.value.trim(),
  account_name: accountName.value.trim(),
  account_number: accountNumber.value.trim()
}))

const hasBankAccount = computed(() => Boolean(bankPayload.value.bank_name && bankPayload.value.account_number))
const maskedAccountNumber = computed(() => {
  const number = accountNumber.value.replace(/\D/g, '')

  if (number.length <= 4) {
    return number || '-'
  }

  return `${'*'.repeat(number.length - 4)}${number.slice(-4)}`
})

const hydrateBankAccount = (profile: Record<string, any> | null | undefined) => {
  const bank = profile?.reward_payout_bank_account || profile?.bank_account || {}

  bankName.value = String(bank.bank_name || bank.bank || '')
  accountName.value = String(bank.account_name || bank.bank_deposit_name || '')
  accountNumber.value = String(bank.account_number || bank.account_no || bank.bank_account_no || bank.bank_deposit_number || '').replace(/\D/g, '')
}

const allowDigitsOnly = (event: InputEvent) => {
  if (event.data && !/^\d+$/.test(event.data)) {
    event.preventDefault()
  }
}

const sanitizeAccountNumber = () => {
  accountNumber.value = accountNumber.value.replace(/\D/g, '').slice(0, 20)
}

const loadProfile = async () => {
  isLoading.value = true
  try {
    hydrateBankAccount(await restoreAuthState(true))
  } catch (error: any) {
    showAlert({
      title: 'โหลดบัญชีรับเงินไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isLoading.value = false
  }
}

const saveBankAccount = async () => {
  sanitizeAccountNumber()

  if (!bankPayload.value.bank_name || !bankPayload.value.account_name || !bankPayload.value.account_number) {
    showAlert({
      title: 'กรอกข้อมูลบัญชีไม่ครบ',
      message: 'กรุณาเลือกธนาคาร กรอกชื่อบัญชี และเลขบัญชี',
      variant: 'warning'
    })
    return
  }

  isSaving.value = true
  try {
    const profile = await platformApi.updateProfile({
      reward_payout_bank_account: bankPayload.value
    })
    setAuthUser(profile || {})
    hydrateBankAccount(profile)
    showAlert({
      title: 'บันทึกบัญชีรับเงินแล้ว',
      message: 'บัญชีนี้จะใช้รับเงินรางวัลและถอนค่าคอมมิชชัน',
      variant: 'success'
    })

    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : ''
    if (redirect.startsWith('/') && !redirect.startsWith('//')) {
      await navigateTo(redirect)
    }
  } catch (error: any) {
    showAlert({
      title: 'บันทึกบัญชีไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาตรวจสอบข้อมูลบัญชีแล้วลองใหม่',
      variant: 'error'
    })
  } finally {
    isSaving.value = false
  }
}

onMounted(loadProfile)
</script>

<style scoped>
.reward-bank-hero {
  align-items: flex-start;
  display: flex;
  gap: 12px;
  margin-top: 18px;
  min-width: 0;
}

.reward-bank-icon {
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

.reward-bank-hero p,
.reward-bank-hero h1 {
  margin: 0;
}

.reward-bank-hero p {
  font-size: 14px;
  font-weight: 800;
  margin-bottom: 4px;
}

.reward-bank-hero h1 {
  font-size: 20px;
  font-weight: 900;
  line-height: 1.3;
  overflow-wrap: anywhere;
}

.reward-bank-page {
  box-sizing: border-box;
  margin-left: auto;
  margin-right: auto;
  margin-top: -38px;
  max-width: 640px;
  padding: 16px;
  width: 100%;
}

.reward-bank-card {
  background: #fff;
  border-radius: 16px;
  box-shadow: 0 10px 24px rgba(22, 46, 82, .09);
  padding: 18px;
}

.reward-bank-card-head {
  display: grid;
  gap: 6px;
  margin-bottom: 16px;
}

.reward-bank-card-head h2 {
  color: #111827;
  font-size: 18px;
  font-weight: 900;
  margin: 0;
}

.reward-bank-card-head p {
  color: #64748b;
  font-size: 13px;
  line-height: 1.45;
  margin: 0;
}

.reward-bank-form {
  display: grid;
  gap: 12px;
}

.reward-bank-form label {
  display: grid;
  gap: 6px;
}

.reward-bank-form label span {
  color: #53657d;
  font-size: 13px;
  font-weight: 800;
}

.reward-bank-form input,
.reward-bank-form select {
  background: #f9fbfe;
  border: 1px solid #d9e2ec;
  border-radius: 12px;
  font: inherit;
  min-height: 50px;
  min-width: 0;
  padding: 0 12px;
  width: 100%;
}

.reward-bank-preview {
  align-items: center;
  background: #eefbf5;
  border: 1px solid #b8ead5;
  border-radius: 14px;
  display: grid;
  gap: 10px;
  grid-template-columns: 40px 1fr;
  min-width: 0;
  padding: 12px;
}

.reward-bank-preview.empty {
  background: #f7fbff;
  border-color: #dbeafe;
}

.reward-bank-preview i {
  background: #fff;
  border-radius: 50%;
  color: #0b69dc;
  display: grid;
  height: 40px;
  place-items: center;
  width: 40px;
}

.reward-bank-preview div {
  display: grid;
  gap: 3px;
  min-width: 0;
}

.reward-bank-preview strong {
  color: #17335f;
  font-size: 15px;
  font-weight: 900;
  overflow-wrap: anywhere;
}

.reward-bank-preview span {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
  overflow-wrap: anywhere;
}

.reward-bank-submit {
  width: 100%;
}

@media (min-width: 768px) {
  .reward-bank-page {
    margin-top: -28px;
    padding-left: 24px;
    padding-right: 24px;
  }
}
</style>

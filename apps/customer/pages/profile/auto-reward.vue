<template>
  <MobileShell active-nav="menu">
    <template v-if="step === 'intro'">
      <section class="auto-reward-intro-page">
        <button class="auto-reward-back mt-4" type="button" aria-label="กลับ" @click="goProfile">
          <i class="bi bi-chevron-left"/>
        </button>

        <div class="auto-reward-visual" aria-hidden="true">
          <div class="auto-reward-phone">
            <span/>
            <span/>
            <span/>
          </div>
          <div class="auto-reward-money">
            <small>เงินเข้า</small>
            <strong>+3,940</strong>
            <span>บาท</span>
          </div>
          <i class="bi bi-coin coin one"/>
          <i class="bi bi-coin coin two"/>
          <i class="bi bi-receipt paper one"/>
          <i class="bi bi-receipt paper two"/>
        </div>

        <section class="auto-reward-intro-sheet">
          <h1>ขึ้นเงินรางวัลอัตโนมัติ</h1>
          <p class="auto-reward-subtitle">สะดวก ง่าย ได้เงินเร็ว</p>

          <div class="auto-reward-benefits">
            <div>
              <i class="bi bi-check-lg"></i><span><strong>สะดวก</strong> ไม่ต้องขึ้นรางวัลเอง</span>
            </div>
            <div>
              <i class="bi bi-check-lg"></i><span><strong>ง่าย</strong> โอนเงินเข้า Wallet หรือบัญชีธนาคาร</span>
            </div>
            <div>
              <i class="bi bi-check-lg"></i><span><strong>ได้เงินเร็ว</strong> ใน 2 ชั่วโมง หลังออกรางวัล</span>
            </div>
          </div>

          <h2>เงื่อนไขการตั้งค่า</h2>
          <div class="auto-reward-terms">
            <ul>
              <li>ระบบจะขึ้นเงินรางวัลสลากดิจิทัลทุกใบ ที่ถูกรางวัล และโอนเงินไปยัง Wallet หรือบัญชีธนาคารที่ตั้งค่าไว้โดยอัตโนมัติ</li>
              <li>ธนาคารจะคิดค่าบริการในการขึ้นเงินรางวัลสลากดิจิทัลผ่านการรับเงินเข้าบัญชีธนาคารหรือ Wallet</li>
              <li>หากต้องการเปลี่ยนช่องทางรับเงิน กรุณาตั้งค่าก่อนเวลา 16:00 น. ของวันออกรางวัล</li>
              <li>การตั้งค่าขึ้นเงินรางวัลอัตโนมัติ จะไม่มีผลต่อ สลากดิจิทัลที่ถูกรางวัลในงวดย้อนหลัง</li>
            </ul>
          </div>
        </section>

        <footer class="auto-reward-footer">
          <button class="primary-pill auto-reward-submit w-100" type="button" @click="step = 'select'">
            ตั้งค่าขึ้นเงินรางวัลอัตโนมัติ
          </button>
        </footer>
      </section>
    </template>

    <template v-else>
      <BlueHeader title="ขึ้นเงินรางวัลอัตโนมัติ" back-to="/profile" min-height="164px" class="auto-reward-select-hero">
        <button class="auto-reward-info" type="button" aria-label="ข้อมูลขึ้นเงินรางวัลอัตโนมัติ"
                @click="step = 'intro'">
          <i class="bi bi-info-circle"/>
        </button>
      </BlueHeader>

      <section class="content-sheet flush auto-reward-select-page">
        <h1>เลือกช่องทางรับเงินรางวัลหลัก</h1>
        <p>ระบบจะขึ้นเงินรางวัลสลากฯ และส่งรายการให้ Partner ตามช่องทางรับเงินหลักที่เลือกไว้โดยอัตโนมัติ
          คุณสามารถเปลี่ยนแปลงการตั้งค่าได้ในภายหลัง</p>

        <div class="auto-reward-options">
          <button
              class="auto-reward-option"
              :class="{ active: payoutType === 'wallet' }"
              type="button"
              :disabled="isLoading || isSaving"
              @click="payoutType = 'wallet'"
          >
            <span class="auto-reward-radio"><i class="bi bi-check-lg"/></span>
            <span class="auto-reward-option-copy">
              <strong>G Wallet</strong>
              <small>{{ walletSummary }}</small>
            </span>
            <span class="auto-reward-option-icon wallet">G</span>
            <em>วงเงิน G Wallet รับได้สูงสุด 500,000 บาท</em>
          </button>

          <button
              class="auto-reward-option"
              :class="{ active: payoutType === 'bank_transfer', missing: !hasBankAccount }"
              type="button"
              :disabled="isLoading || isSaving"
              @click="selectBankTransfer"
          >
            <span class="auto-reward-radio"><i class="bi bi-check-lg"/></span>
            <span class="auto-reward-option-copy">
              <strong>{{ bankTitle }}</strong>
              <small>{{ bankSummary }}</small>
            </span>
            <span class="auto-reward-option-icon bank"><i class="bi bi-bank2"/></span>
          </button>
        </div>
      </section>

      <footer class="auto-reward-footer">
        <button class="primary-pill auto-reward-submit" type="button" :disabled="isLoading || isSaving"
                @click="saveAutoReward">
          <span v-if="isSaving" class="spinner-border spinner-border-sm me-2"/>
          ถัดไป
        </button>
      </footer>
    </template>
  </MobileShell>
</template>

<script setup lang="ts">
type PayoutType = 'wallet' | 'bank_transfer'

definePageMeta({
  requiresAuth: true
})

const platformApi = usePlatformApi()
const {restoreAuthState, setAuthUser} = useAuth()
const {showAlert} = useAppAlert()

const step = ref<'intro' | 'select'>('intro')
const payoutType = ref<PayoutType>('wallet')
const profile = ref<Record<string, any> | null>(null)
const isLoading = ref(false)
const isSaving = ref(false)

const benefitItems = [
  'สะดวก ไม่ต้องขึ้นรางวัลเอง',
  'ง่าย โอนเงินเข้า G Wallet หรือบัญชีกรุงไทย',
  'ได้เงินเร็ว หลัง Partner ตรวจสอบรายการ'
]

const bankAccount = computed(() => profile.value?.reward_payout_bank_account || profile.value?.bank_account || {})
const hasBankAccount = computed(() => Boolean(bankAccount.value?.bank_name && bankAccount.value?.account_number))
const bankTitle = computed(() => {
  const bankName = String(bankAccount.value?.bank_name || bankAccount.value?.bank || '').replace(/^ธนาคาร/u, '').trim()

  return bankName ? `บัญชี${bankName}` : 'บัญชีธนาคาร'
})
const bankSummary = computed(() => {
  if (!hasBankAccount.value) {
    return 'กรุณาเพิ่มบัญชีรับเงินก่อนเลือกช่องทางนี้'
  }

  const accountName = String(bankAccount.value.account_name || bankAccount.value.bank_deposit_name || 'ผู้ถือบัญชี')
  const accountNumber = maskAccountNumber(bankAccount.value.account_number || bankAccount.value.account_no || '')

  return `${accountName} · ${accountNumber}`
})
const walletSummary = computed(() => {
  const id = String(profile.value?.wallet?.id || profile.value?.primary_wallet?.id || profile.value?.wallet_id || profile.value?.customer_no || '').replace(/\D/g, '')
  const suffix = id.slice(-4) || '1244'

  return `006 XXXXXXXX ${suffix}`
})

const maskAccountNumber = (value: unknown) => {
  const digits = String(value || '').replace(/\D/g, '')

  if (digits.length <= 4) {
    return digits || '-'
  }

  return `${digits.slice(0, 3)} ${'X'.repeat(Math.max(4, digits.length - 7))} ${digits.slice(-4)}`
}

const hydrateAutoReward = (nextProfile: Record<string, any> | null | undefined) => {
  profile.value = nextProfile || {}
  const setting = profile.value?.auto_reward_claim || {}
  const method = String(setting.type || setting.payout_method || '').toLowerCase()

  payoutType.value = method === 'bank_transfer' ? 'bank_transfer' : 'wallet'
  step.value = setting.enabled ? 'select' : 'intro'
}

const loadProfile = async () => {
  isLoading.value = true
  try {
    hydrateAutoReward(await restoreAuthState(true))
  } catch (error: any) {
    showAlert({
      title: 'โหลดข้อมูลไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isLoading.value = false
  }
}

const selectBankTransfer = () => {
  payoutType.value = 'bank_transfer'

  if (!hasBankAccount.value) {
    showAlert({
      title: 'ยังไม่มีบัญชีรับเงิน',
      message: 'กรุณาเพิ่มบัญชีรับเงินก่อนเลือกบัญชีธนาคาร',
      variant: 'warning'
    })
  }
}

const saveAutoReward = async () => {
  if (payoutType.value === 'bank_transfer' && !hasBankAccount.value) {
    showAlert({
      title: 'ยังไม่มีบัญชีรับเงิน',
      message: 'ไปเพิ่มบัญชีรับเงินก่อน แล้วกลับมาตั้งค่าขึ้นเงินรางวัลอัตโนมัติ',
      variant: 'warning'
    })
    await navigateTo('/profile/reward-bank?redirect=/profile/auto-reward')
    return
  }

  isSaving.value = true
  try {
    const nextProfile = await platformApi.updateProfile({
      auto_reward_claim: {
        enabled: true,
        type: payoutType.value,
        payout_method: payoutType.value === 'bank_transfer' ? 'bank_transfer' : 'wallet_credit'
      }
    })

    setAuthUser(nextProfile || {})
    hydrateAutoReward(nextProfile)
    showAlert({
      title: 'ตั้งค่าขึ้นเงินรางวัลอัตโนมัติแล้ว',
      message: payoutType.value === 'bank_transfer' ? 'รายการถูกรางวัลใหม่จะส่งให้ Partner แบบ bank transfer' : 'รายการถูกรางวัลใหม่จะส่งให้ Partner แบบ wallet',
      variant: 'success'
    })
    await navigateTo('/profile')
  } catch (error: any) {
    showAlert({
      title: 'บันทึกไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSaving.value = false
  }
}

const goProfile = () => navigateTo('/profile')

onMounted(loadProfile)
</script>

<style scoped>
.auto-reward-intro-page {
  background: linear-gradient(180deg, #45ddce 0%, #bff8e7 28%, #fff 28%);
  min-height: 100%;
  padding: 72px 0 116px;
  position: relative;
}

.auto-reward-back {
  align-items: center;
  background: transparent;
  border: 0;
  color: #0b65b9;
  display: flex;
  font-size: 34px;
  height: 44px;
  justify-content: center;
  left: 20px;
  padding: 0;
  position: absolute;
  top: 28px;
  width: 44px;
  z-index: 3;
}

.auto-reward-visual {
  height: 256px;
  margin: 0 auto;
  max-width: 420px;
  position: relative;
}

.auto-reward-phone {
  background: linear-gradient(160deg, #5cc5bf, #0e78c8);
  border-radius: 22px;
  box-shadow: 0 22px 48px rgba(4, 82, 139, .28);
  display: grid;
  gap: 12px;
  height: 172px;
  left: 50%;
  padding: 54px 22px 22px;
  position: absolute;
  top: 18px;
  transform: rotate(-8deg) translateX(-50%);
  width: 104px;
}

.auto-reward-phone span {
  background: rgba(255, 255, 255, .32);
  border-radius: 999px;
  height: 12px;
}

.auto-reward-money {
  align-items: baseline;
  background: #fffef7;
  border: 4px solid #b778df;
  border-radius: 12px;
  box-shadow: 0 14px 32px rgba(65, 75, 140, .18);
  color: #27344c;
  display: flex;
  gap: 6px;
  left: 50%;
  padding: 10px 18px;
  position: absolute;
  top: 36px;
  transform: translateX(-8%);
}

.auto-reward-money small {
  align-self: flex-start;
  display: block;
  font-size: 13px;
  font-weight: 900;
  position: absolute;
  top: 6px;
}

.auto-reward-money strong {
  font-size: 32px;
  font-weight: 1000;
  line-height: 1;
  margin-top: 18px;
}

.auto-reward-money span {
  font-size: 14px;
  font-weight: 900;
}

.coin,
.paper {
  position: absolute;
}

.coin {
  color: #ffcf40;
  filter: drop-shadow(0 8px 8px rgba(176, 116, 0, .22));
  font-size: 42px;
}

.coin.one {
  left: 14%;
  top: 96px;
  transform: rotate(-18deg);
}

.coin.two {
  right: 14%;
  top: 154px;
  transform: rotate(18deg);
}

.paper {
  color: rgba(255, 255, 255, .62);
  font-size: 44px;
}

.paper.one {
  left: 12%;
  top: 36px;
  transform: rotate(17deg);
}

.paper.two {
  right: 10%;
  top: 112px;
  transform: rotate(-14deg);
}

.auto-reward-intro-sheet {
  background: #fff;
  border-radius: 36px 36px 0 0;
  margin-top: -12px;
  padding: 28px 26px 18px;
  position: relative;
  z-index: 2;
}

.auto-reward-intro-sheet h1,
.auto-reward-intro-sheet h2,
.auto-reward-intro-sheet p {
  margin: 0;
}

.auto-reward-intro-sheet h1 {
  color: #242833;
  font-size: 28px;
  font-weight: 1000;
  text-align: center;
}

.auto-reward-subtitle {
  color: #6f7480;
  font-size: 20px;
  font-weight: 800;
  margin-top: 8px !important;
  text-align: center;
}

.auto-reward-benefits {
  display: grid;
  gap: 18px;
  margin: 36px 0;
}

.auto-reward-benefits div {
  align-items: center;
  display: grid;
  gap: 14px;
  grid-template-columns: 42px 1fr;
}

.auto-reward-benefits i {
  align-items: center;
  background: #67bd22;
  border-radius: 50%;
  color: #fff;
  display: flex;
  font-size: 24px;
  height: 36px;
  justify-content: center;
  width: 36px;
}

.auto-reward-benefits span {
  color: #292d36;
  font-size: 19px;
  line-height: 1.35;
}

.auto-reward-intro-sheet h2 {
  color: #242833;
  font-size: 19px;
  font-weight: 1000;
  margin-bottom: 12px;
}

.auto-reward-terms {
  background: #f7f7f8;
  border-radius: 14px;
  font-size: 16px;
  line-height: 1.65;
  overflow: auto;
  padding: 16px 18px;
}

.auto-reward-terms ul {
  display: grid;
  gap: 10px;
  margin: 0;
  padding-left: 20px;
}

.auto-reward-select-hero {
  position: relative;
}

.auto-reward-select-hero :deep(.hero-row) {
  padding-top: 20px;
}

.auto-reward-info {
  align-items: center;
  background: transparent;
  border: 0;
  color: #fff;
  display: flex;
  font-size: 24px;
  height: 44px;
  justify-content: center;
  padding: 0;
  position: absolute;
  right: 22px;
  top: 30px;
  width: 44px;
}

.auto-reward-select-page {
  margin-top: -34px;
  min-height: calc(100% - 130px);
  padding: 28px 28px 116px;
}

.auto-reward-select-page h1 {
  color: #232936;
  font-size: 25px;
  font-weight: 1000;
  line-height: 1.28;
  margin: 0 0 14px;
}

.auto-reward-select-page > p {
  color: #646b77;
  font-size: 17px;
  font-weight: 700;
  line-height: 1.65;
  margin: 0 0 26px;
}

.auto-reward-options {
  display: grid;
  gap: 16px;
}

.auto-reward-option {
  align-items: center;
  background: #fff;
  border: 1px solid #e5e9ef;
  border-radius: 14px;
  box-shadow: 0 4px 14px rgba(29, 42, 74, .04);
  color: inherit;
  display: grid;
  gap: 14px;
  grid-template-columns: 42px minmax(0, 1fr) 56px;
  min-height: 122px;
  padding: 18px 22px;
  position: relative;
  text-align: left;
  width: 100%;
}

.auto-reward-option.active {
  background: #f7fbff;
  border-color: #1479e7;
  box-shadow: 0 0 0 2px rgba(20, 121, 231, .16);
}

.auto-reward-option.missing:not(.active) {
  opacity: .78;
}

.auto-reward-radio {
  align-items: center;
  border: 2px solid #dde4ee;
  border-radius: 50%;
  color: transparent;
  display: flex;
  height: 34px;
  justify-content: center;
  width: 34px;
}

.auto-reward-option.active .auto-reward-radio {
  background: #0b69dc;
  border-color: #0b69dc;
  color: #fff;
}

.auto-reward-option-copy {
  display: grid;
  gap: 6px;
  min-width: 0;
}

.auto-reward-option-copy strong {
  color: #242936;
  font-size: 20px;
  font-weight: 1000;
}

.auto-reward-option-copy small {
  color: #6d7280;
  font-size: 15px;
  font-weight: 800;
  overflow-wrap: anywhere;
}

.auto-reward-option-icon {
  align-items: center;
  border-radius: 14px;
  display: flex;
  font-size: 30px;
  font-weight: 1000;
  height: 54px;
  justify-content: center;
  justify-self: end;
  width: 54px;
}

.auto-reward-option-icon.wallet {
  background: linear-gradient(135deg, #17a8df, #0953bd);
  color: #fff;
}

.auto-reward-option-icon.bank {
  background: #eaf6ff;
  color: #0b69dc;
}

.auto-reward-option em {
  background: #e7f3ff;
  border-radius: 0 0 12px 12px;
  bottom: 0;
  color: #0b69dc;
  font-size: 15px;
  font-style: normal;
  font-weight: 900;
  left: 0;
  line-height: 1.35;
  padding: 11px 22px;
  position: absolute;
  right: 0;
  transform: translateY(100%);
}

.auto-reward-option:first-child {
  margin-bottom: 42px;
}

.auto-reward-footer {
  background: rgba(255, 255, 255, .96);
  bottom: 0;
  box-shadow: 0 -10px 30px rgba(36, 47, 82, .12);
  left: 0;
  margin: 0;
  max-width: none;
  padding: 18px 26px calc(26px + env(safe-area-inset-bottom));
  position: fixed;
  right: 0;
  width: 100%;
  z-index: 26;
}

.auto-reward-submit {
  font-size: 19px;
  font-weight: 1000;
  margin: 0 auto;
  min-height: 64px;
  width: 100%;
}

@media (max-width: 360px) {
  .auto-reward-intro-sheet {
    padding-left: 20px;
    padding-right: 20px;
  }

  .auto-reward-intro-sheet h1 {
    font-size: 24px;
  }

  .auto-reward-benefits span,
  .auto-reward-subtitle {
    font-size: 17px;
  }

  .auto-reward-select-page {
    padding-left: 22px;
    padding-right: 22px;
  }

  .auto-reward-option {
    grid-template-columns: 36px minmax(0, 1fr) 48px;
    padding-left: 16px;
    padding-right: 16px;
  }
}
</style>

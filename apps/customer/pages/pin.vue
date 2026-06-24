<template>
  <PinKeypadScreen
    v-if="!isPasswordResetStep"
    :title="pinTitle"
    :subtitle="pinSubtitle"
    :digits="activeDigits"
    :error="errorMessage"
    :helper="helperMessage"
    :disabled="isSubmitting"
    @append="appendDigit"
    @remove="removeDigit"
    @back="handleBack"
  >
    <template #actions>
      <button
        v-if="showForgotPinAction"
        class="pin-reset-action"
        type="button"
        :disabled="isSubmitting"
        @click="startResetPin"
      >
        ลืม PIN?
      </button>
    </template>
  </PinKeypadScreen>

  <section v-else class="pin-reset-password-screen">
    <header class="pin-reset-topbar">
      <button class="pin-reset-back" type="button" aria-label="กลับ" :disabled="isSubmitting" @click="handleBack">
        <i class="bi bi-chevron-left" />
      </button>
      <h1>เป๋าตัง</h1>
    </header>

    <main class="pin-reset-password-main">
      <div class="pin-reset-card">
        <div class="pin-reset-icon">
          <i class="bi bi-shield-lock" />
        </div>
        <h2>รีเซ็ต PIN</h2>
        <p>กรอกรหัส OTP 6 หลักที่ส่งไปยังเบอร์โทรศัพท์บัญชีนี้ก่อนตั้ง PIN ใหม่</p>

        <form class="pin-reset-form" @submit.prevent="submitResetPassword">
          <label for="pin-reset-otp">รหัส OTP</label>
          <input
            id="pin-reset-otp"
            v-model="resetOtp"
            type="tel"
            autocomplete="one-time-code"
            inputmode="numeric"
            maxlength="6"
            pattern="[0-9]*"
            placeholder="กรอกรหัส OTP"
            :disabled="isSubmitting"
            @beforeinput="allowDigitsOnly"
            @input="sanitizeResetOtp"
          >
          <p class="pin-reset-error" :class="{ visible: Boolean(passwordError) }">
            {{ passwordError }}
          </p>
          <button class="pin-reset-submit" type="submit" :disabled="isSubmitting || resetOtp.trim().length !== 6">
            {{ isSubmitting ? 'กำลังตรวจสอบ' : 'ยืนยัน OTP' }}
          </button>
          <button class="pin-reset-secondary" type="button" :disabled="isSubmitting || resendCountdown > 0" @click="requestPinResetOtp">
            {{ resendCountdown > 0 ? `ส่งรหัสใหม่ได้ใน ${resendCountdown} วินาที` : 'ส่งรหัสใหม่' }}
          </button>
          <button class="pin-reset-secondary" type="button" :disabled="isSubmitting" @click="handleBack">
            กลับไปกรอก PIN
          </button>
        </form>
      </div>
    </main>
  </section>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: true
})

type SetupStep = 'pin' | 'confirmation'
type ResetStep = 'pin' | 'password' | 'new' | 'confirmation'

const route = useRoute()
const platformApi = usePlatformApi()
const { token, user, hasPin, setAuthUser, setPinVerified, restoreAuthState, clearAuthToken, logout } = useAuth()
const { refreshAppInit } = useAppInit()

const pin = ref('')
const pinConfirmation = ref('')
const setupStep = ref<SetupStep>('pin')
const resetStep = ref<ResetStep>('pin')
const resetPassword = ref('')
const resetOtp = ref('')
const resetOtpToken = ref('')
const resetPinValue = ref('')
const resetPinConfirmation = ref('')
const isSubmitting = ref(false)
const errorMessage = ref('')
const passwordError = ref('')
const resendCountdown = ref(0)
let resendTimer: ReturnType<typeof setInterval> | null = null

const mode = computed(() => hasPin.value ? 'verify' : 'setup')
const isResetFlow = computed(() => mode.value === 'verify' && resetStep.value !== 'pin')
const isPasswordResetStep = computed(() => isResetFlow.value && resetStep.value === 'password')
const showForgotPinAction = computed(() => mode.value === 'verify' && resetStep.value === 'pin')
const activeDigits = computed(() => {
  if (isResetFlow.value) {
    return resetStep.value === 'confirmation' ? resetPinConfirmation.value : resetPinValue.value
  }

  return mode.value === 'setup' && setupStep.value === 'confirmation' ? pinConfirmation.value : pin.value
})
const pinTitle = computed(() => {
  if (isResetFlow.value) {
    return resetStep.value === 'confirmation' ? 'ยืนยัน PIN ใหม่' : 'ตั้ง PIN ใหม่'
  }

  if (mode.value === 'verify') {
    return 'ใส่รหัส PIN 6 หลัก'
  }

  return setupStep.value === 'confirmation' ? 'ยืนยันรหัส PIN 6 หลัก' : 'ตั้งรหัส PIN 6 หลัก'
})
const pinSubtitle = computed(() => {
  if (isSubmitting.value) {
    return mode.value === 'setup' || isResetFlow.value ? 'กำลังตั้งรหัสเข้าใช้งาน' : 'กำลังตรวจสอบ'
  }

  if (isResetFlow.value) {
    return resetStep.value === 'confirmation' ? 'กรอก PIN ใหม่อีกครั้ง' : 'กรอกรหัส PIN ใหม่ 6 หลัก'
  }

  if (mode.value === 'verify') {
    return 'เพื่อทำรายการต่อ'
  }

  return setupStep.value === 'confirmation' ? 'กรอกรหัสเดิมอีกครั้ง' : 'เพื่อใช้เข้าใช้งานต่อ'
})
const helperMessage = computed(() => {
  if (isResetFlow.value && !errorMessage.value) {
    return resetStep.value === 'confirmation' ? 'ยืนยัน PIN ใหม่ที่ตั้งไว้' : 'PIN ใหม่จะใช้เข้าใช้งานครั้งถัดไป'
  }

  if (mode.value === 'setup' && setupStep.value === 'confirmation' && !errorMessage.value) {
    return 'ยืนยัน PIN ที่ตั้งไว้'
  }

  return ''
})
const canSubmit = computed(() => {
  if (!/^\d{6}$/.test(pin.value)) {
    return false
  }

  return mode.value === 'verify' || pinConfirmation.value === pin.value
})

const safeRedirect = () => {
  if (typeof route.query.redirect !== 'string') {
    return '/'
  }

  if (!route.query.redirect.startsWith('/') || route.query.redirect.startsWith('//') || route.query.redirect === '/pin') {
    return '/'
  }

  return route.query.redirect
}

const setActiveDigits = (value: string) => {
  if (isResetFlow.value) {
    if (resetStep.value === 'confirmation') {
      resetPinConfirmation.value = value
      return
    }

    resetPinValue.value = value
    return
  }

  if (mode.value === 'setup' && setupStep.value === 'confirmation') {
    pinConfirmation.value = value
    return
  }

  pin.value = value
}

const resetPinEntry = () => {
  pin.value = ''
  pinConfirmation.value = ''
  setupStep.value = 'pin'
}

const resetResetPinEntry = () => {
  resetStep.value = 'pin'
  resetPassword.value = ''
  resetOtp.value = ''
  resetOtpToken.value = ''
  resetPinValue.value = ''
  resetPinConfirmation.value = ''
  passwordError.value = ''
}

const applyPinResponse = async (response: Record<string, any>) => {
  setAuthUser(response.user || {
    ...(user.value || {}),
    has_pin: response.has_pin,
    pin_verified: response.pin_verified,
    pin_setup_required: response.pin_setup_required,
    pin_required: response.pin_required
  })
  setPinVerified(Boolean(response.pin_verified))
  await refreshAppInit()
  await navigateTo(safeRedirect())
}

const startResetPin = () => {
  if (isSubmitting.value) {
    return
  }

  void requestPinResetOtp()
}

const allowDigitsOnly = (event: InputEvent) => {
  if (event.data && !/^\d+$/.test(event.data)) {
    event.preventDefault()
  }
}

const sanitizeResetOtp = () => {
  resetOtp.value = resetOtp.value.replace(/\D/g, '').slice(0, 6)
}

const startResendCountdown = (seconds: number) => {
  resendCountdown.value = Math.max(0, Number(seconds) || 0)
  if (resendTimer) {
    clearInterval(resendTimer)
  }
  if (resendCountdown.value <= 0) {
    return
  }
  resendTimer = setInterval(() => {
    resendCountdown.value = Math.max(0, resendCountdown.value - 1)
    if (resendCountdown.value <= 0 && resendTimer) {
      clearInterval(resendTimer)
      resendTimer = null
    }
  }, 1000)
}

const requestPinResetOtp = async () => {
  if (isSubmitting.value) {
    return
  }

  pin.value = ''
  pinConfirmation.value = ''
  errorMessage.value = ''
  passwordError.value = ''
  resetPassword.value = ''
  resetOtp.value = ''
  resetOtpToken.value = ''
  resetPinValue.value = ''
  resetPinConfirmation.value = ''
  isSubmitting.value = true

  try {
    const response = await platformApi.requestPinResetOtp()
    resetStep.value = 'password'
    startResendCountdown(response?.resend_after_seconds || 60)
  } catch (error: any) {
    const code = error?.data?.error?.code || error?.response?._data?.error?.code || error?.response?.data?.error?.code
    passwordError.value = code === 'sms_otp_provider_not_configured'
      ? 'ร้านค้ายังไม่ได้ตั้งค่า SMS OTP กรุณาติดต่อผู้ดูแลร้านค้า'
      : error?.data?.error?.message || error?.response?._data?.error?.message || error?.response?.data?.error?.message || 'ไม่สามารถส่ง OTP ได้ กรุณาลองใหม่อีกครั้ง'
    resetStep.value = 'password'
  } finally {
    isSubmitting.value = false
  }
}

const submitResetPassword = async () => {
  if (isSubmitting.value || resetOtp.value.trim().length !== 6) {
    return
  }

  isSubmitting.value = true
  passwordError.value = ''
  sanitizeResetOtp()

  try {
    const response = await platformApi.verifyPinResetOtp({
      otp: resetOtp.value
    })
    resetOtpToken.value = response?.otp_verification_token || ''
    resetPinValue.value = ''
    resetPinConfirmation.value = ''
    resetStep.value = 'new'
  } catch (error: any) {
    const code = error?.response?.data?.error?.code || error?.response?.data?.code
    passwordError.value = code === 'password_invalid'
      ? 'รหัสผ่านไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง'
      : error?.response?.data?.message || 'ไม่สามารถตรวจสอบรหัสผ่านได้ กรุณาลองใหม่อีกครั้ง'
  } finally {
    isSubmitting.value = false
  }
}

const submitResetPin = async () => {
  if (isSubmitting.value || !/^\d{6}$/.test(resetPinValue.value) || resetPinConfirmation.value !== resetPinValue.value) {
    return
  }

  isSubmitting.value = true
  errorMessage.value = ''

  try {
    const response = await platformApi.confirmPinResetOtp({
      pin: resetPinValue.value,
      pin_confirmation: resetPinConfirmation.value,
      otp_verification_token: resetOtpToken.value
    })

    await applyPinResponse(response)
  } catch (error: any) {
    const code = error?.response?.data?.error?.code || error?.response?.data?.code

    if (code === 'otp_invalid' || code === 'otp_required') {
      passwordError.value = 'กรุณายืนยัน OTP อีกครั้ง'
      resetStep.value = 'password'
    } else {
      errorMessage.value = error?.response?.data?.message || 'ไม่สามารถตั้ง PIN ใหม่ได้ กรุณาลองใหม่อีกครั้ง'
      resetPinValue.value = ''
      resetPinConfirmation.value = ''
      resetStep.value = 'new'
    }
  } finally {
    isSubmitting.value = false
  }
}

const submitPin = async () => {
  if (isSubmitting.value || !canSubmit.value) {
    return
  }

  isSubmitting.value = true
  errorMessage.value = ''

  try {
    const response = mode.value === 'setup'
      ? await platformApi.setupPin({
          pin: pin.value,
          pin_confirmation: pinConfirmation.value
        })
      : await platformApi.verifyPin({
          pin: pin.value
        })

    await applyPinResponse(response)
  } catch (error: any) {
    const code = error?.response?.data?.error?.code || error?.response?.data?.code

    if (code === 'pin_locked') {
      errorMessage.value = 'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่แล้วลองใหม่'
    } else if (code === 'pin_invalid') {
      errorMessage.value = 'PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง'
    } else {
      errorMessage.value = error?.response?.data?.message || 'ไม่สามารถยืนยัน PIN ได้ กรุณาลองใหม่อีกครั้ง'
    }

    resetPinEntry()
  } finally {
    isSubmitting.value = false
  }
}

const appendDigit = async (digit: string) => {
  if (!/^\d$/.test(digit) || activeDigits.value.length >= 6 || isSubmitting.value) {
    return
  }

  errorMessage.value = ''
  const nextDigits = `${activeDigits.value}${digit}`
  setActiveDigits(nextDigits)

  if (nextDigits.length !== 6) {
    return
  }

  if (isResetFlow.value && resetStep.value === 'new') {
    resetStep.value = 'confirmation'
    return
  }

  if (isResetFlow.value && resetStep.value === 'confirmation') {
    if (resetPinConfirmation.value !== resetPinValue.value) {
      errorMessage.value = 'PIN ไม่ตรงกัน กรุณาตั้งใหม่อีกครั้ง'
      resetPinValue.value = ''
      resetPinConfirmation.value = ''
      resetStep.value = 'new'
      return
    }

    await submitResetPin()
    return
  }

  if (mode.value === 'setup' && setupStep.value === 'pin') {
    setupStep.value = 'confirmation'
    return
  }

  if (mode.value === 'setup' && pinConfirmation.value !== pin.value) {
    errorMessage.value = 'PIN ไม่ตรงกัน กรุณาตั้งใหม่อีกครั้ง'
    resetPinEntry()
    return
  }

  await submitPin()
}

const removeDigit = () => {
  if (isSubmitting.value || activeDigits.value.length === 0) {
    return
  }

  errorMessage.value = ''
  setActiveDigits(activeDigits.value.slice(0, -1))
}

const handleBack = async () => {
  if (resetStep.value === 'password') {
    resetResetPinEntry()
    errorMessage.value = ''
    return
  }

  if (resetStep.value === 'new') {
    resetPinValue.value = ''
    resetPinConfirmation.value = ''
    errorMessage.value = ''
    resetStep.value = 'password'
    return
  }

  if (resetStep.value === 'confirmation') {
    resetPinConfirmation.value = ''
    errorMessage.value = ''
    resetStep.value = 'new'
    return
  }

  if (mode.value === 'setup' && setupStep.value === 'confirmation') {
    pinConfirmation.value = ''
    setupStep.value = 'pin'
    errorMessage.value = ''
    return
  }

  await logout()
  await navigateTo('/login')
}

const handleKeydown = (event: KeyboardEvent) => {
  if (isPasswordResetStep.value) {
    return
  }

  if (/^\d$/.test(event.key)) {
    event.preventDefault()
    void appendDigit(event.key)
    return
  }

  if (event.key === 'Backspace') {
    event.preventDefault()
    removeDigit()
  }
}

watch(mode, () => {
  resetPinEntry()
  resetResetPinEntry()
})

onMounted(async () => {
  try {
    if (!token.value) {
      throw new Error('missing_auth_token')
    }

    await restoreAuthState(true)
  } catch {
    clearAuthToken()
    await navigateTo({
      path: '/login',
      query: {
        redirect: safeRedirect()
      }
    })
    return
  }

  window.addEventListener('keydown', handleKeydown)
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleKeydown)
  if (resendTimer) {
    clearInterval(resendTimer)
  }
})
</script>

<style scoped>
.pin-reset-action {
  background: transparent;
  border: 0;
  color: #0d7fe8;
  font-size: 14px;
  font-weight: 900;
  line-height: 1;
  padding: 7px 10px;
}

.pin-reset-action:disabled {
  opacity: .48;
}

.pin-reset-password-screen {
  background: #fff;
  color: #2f3337;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);
  min-height: 100dvh;
  overflow: hidden;
  padding: calc(12px + env(safe-area-inset-top)) 28px calc(24px + env(safe-area-inset-bottom));
}

.pin-reset-topbar {
  align-items: center;
  display: grid;
  grid-template-columns: 42px 1fr 42px;
  height: 42px;
  margin: 0 auto;
  max-width: 430px;
  width: 100%;
}

.pin-reset-back {
  align-items: center;
  background: transparent;
  border: 0;
  color: #8b9299;
  display: inline-flex;
  font-size: 24px;
  height: 42px;
  justify-content: flex-start;
  padding: 0;
  width: 42px;
}

.pin-reset-back:disabled {
  opacity: .45;
}

.pin-reset-topbar h1 {
  color: #8487f8;
  font-size: 16px;
  font-weight: 900;
  line-height: 1;
  margin: 0;
  text-align: center;
}

.pin-reset-password-main {
  align-items: center;
  display: flex;
  justify-content: center;
  min-height: 0;
  padding: clamp(18px, 8vh, 58px) 0;
}

.pin-reset-card {
  display: grid;
  gap: 14px;
  margin: 0 auto;
  max-width: 390px;
  text-align: center;
  width: 100%;
}

.pin-reset-icon {
  align-items: center;
  background: #e8f3ff;
  border-radius: 22px;
  color: #0d7fe8;
  display: inline-flex;
  font-size: 28px;
  height: 64px;
  justify-content: center;
  justify-self: center;
  width: 64px;
}

.pin-reset-card h2 {
  color: #2f3337;
  font-size: 30px;
  font-weight: 900;
  line-height: 1.18;
  margin: 0;
}

.pin-reset-card > p {
  color: #8a929d;
  font-size: 15px;
  font-weight: 800;
  line-height: 1.5;
  margin: 0 auto;
  max-width: 310px;
}

.pin-reset-form {
  display: grid;
  gap: 10px;
  margin-top: 8px;
  text-align: left;
}

.pin-reset-form label {
  color: #2f3337;
  font-size: 13px;
  font-weight: 900;
}

.pin-reset-form input {
  background: #f6f8fb;
  border: 1px solid #dce4ef;
  border-radius: 18px;
  color: #172b4d;
  font-size: 16px;
  font-weight: 800;
  height: 54px;
  outline: none;
  padding: 0 16px;
  width: 100%;
}

.pin-reset-form input:focus {
  border-color: #0d7fe8;
  box-shadow: 0 0 0 4px rgba(13, 127, 232, .12);
}

.pin-reset-error {
  color: #d3455b;
  font-size: 12px;
  font-weight: 800;
  line-height: 1.35;
  margin: 0;
  min-height: 18px;
  opacity: 0;
  text-align: center;
}

.pin-reset-error.visible {
  opacity: 1;
}

.pin-reset-submit,
.pin-reset-secondary {
  border: 0;
  border-radius: 999px;
  font-size: 16px;
  font-weight: 900;
  height: 52px;
}

.pin-reset-submit {
  background: linear-gradient(135deg, #14a7ff, #0062d9);
  color: #fff;
  box-shadow: 0 14px 28px rgba(0, 98, 217, .2);
}

.pin-reset-secondary {
  background: transparent;
  color: #0d7fe8;
}

.pin-reset-submit:disabled,
.pin-reset-secondary:disabled {
  opacity: .52;
}

@media (max-width: 360px) {
  .pin-reset-password-screen {
    padding-left: 22px;
    padding-right: 22px;
  }
}
</style>

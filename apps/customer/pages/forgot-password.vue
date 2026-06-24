<template>
  <MobileShell time="12:15">
    <BlueHeader title="ลืมรหัสผ่าน" back-to="/login" min-height="220px">
      <div class="forgot-hero">
        <i class="bi bi-shield-lock" />
        <h1>ขอรีเซ็ตรหัสผ่าน</h1>
        <p>ยืนยันตัวตนด้วย OTP แล้วตั้งรหัสผ่านใหม่ได้ทันที</p>
      </div>
    </BlueHeader>

    <section class="content-sheet forgot-sheet">
      <form class="forgot-card" @submit.prevent="submitRequest">
        <div class="forgot-card-head">
          <h2>{{ stepTitle }}</h2>
          <p>{{ stepDescription }}</p>
        </div>

        <label v-if="step === 'phone'" class="forgot-field">
          <span>เบอร์โทรศัพท์</span>
          <div class="forgot-input">
            <i class="bi bi-phone" />
            <input
              v-model="phone"
              type="tel"
              inputmode="numeric"
              maxlength="10"
              autocomplete="tel"
              placeholder="กรอกเบอร์โทรศัพท์"
              @beforeinput="allowDigitsOnly"
              @input="sanitizePhone"
            >
          </div>
        </label>

        <label v-else-if="step === 'otp'" class="forgot-field">
          <span>รหัส OTP</span>
          <div class="forgot-input">
            <i class="bi bi-chat-dots" />
            <input
              v-model="otpCode"
              type="tel"
              inputmode="numeric"
              maxlength="6"
              pattern="[0-9]*"
              placeholder="กรอกรหัส OTP"
              @beforeinput="allowDigitsOnly"
              @input="sanitizeOtp"
            >
          </div>
          <button class="forgot-link-button" type="button" :disabled="resendCountdown > 0 || submitting" @click="requestPasswordOtp">
            {{ resendCountdown > 0 ? `ส่งรหัสใหม่ได้ใน ${resendCountdown} วินาที` : 'ส่งรหัสใหม่' }}
          </button>
        </label>

        <div v-else class="forgot-password-grid">
          <label class="forgot-field">
            <span>รหัสผ่านใหม่</span>
            <div class="forgot-input">
              <i class="bi bi-lock" />
              <input v-model="password" type="password" autocomplete="new-password" placeholder="ตั้งรหัสผ่านใหม่">
            </div>
          </label>
          <label class="forgot-field">
            <span>ยืนยันรหัสผ่านใหม่</span>
            <div class="forgot-input">
              <i class="bi bi-shield-lock" />
              <input v-model="passwordConfirmation" type="password" autocomplete="new-password" placeholder="กรอกรหัสผ่านอีกครั้ง">
            </div>
          </label>
        </div>

        <button class="primary-pill forgot-submit" type="submit" :disabled="submitting">
          {{ submitLabel }}
        </button>

        <div v-if="submitted" class="forgot-success">
          <i class="bi bi-check-circle-fill" />
          <div>
            <strong>เปลี่ยนรหัสผ่านแล้ว</strong>
            <p>คุณสามารถเข้าสู่ระบบด้วยรหัสผ่านใหม่ได้ทันที</p>
          </div>
        </div>
      </form>

      <div class="forgot-card forgot-line-card">
        <div class="forgot-card-head">
          <h2>รีเซ็ตด้วย LINE</h2>
          <p>ถ้าคุณเคยเชื่อมต่อ LINE กับบัญชีนี้ไว้ สามารถยืนยันผ่าน LINE แล้วตั้งรหัสใหม่ได้เลย</p>
        </div>

        <button class="forgot-line-button" type="button" :disabled="lineSubmitting" @click="startLineReset">
          <i class="bi bi-line" />
          <span>{{ lineSubmitting ? 'กำลังเปิด LINE' : 'รีเซ็ตด้วย LINE' }}</span>
        </button>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: false,
  guestOnly: true
})

const phone = ref('')
const otpCode = ref('')
const otpToken = ref('')
const password = ref('')
const passwordConfirmation = ref('')
const step = ref<'phone' | 'otp' | 'password'>('phone')
const submitting = ref(false)
const lineSubmitting = ref(false)
const submitted = ref(false)
const maskedPhone = ref('')
const resendCountdown = ref(0)
let resendTimer: ReturnType<typeof setInterval> | null = null
const platformApi = usePlatformApi()
const { setLineRedirect } = useAuth()
const { showAlert } = useAppAlert()
const lineLiff = useLineLiff()

const allowDigitsOnly = (event: InputEvent) => {
  if (event.data && !/^\d+$/.test(event.data)) {
    event.preventDefault()
  }
}

const sanitizePhone = () => {
  phone.value = phone.value.replace(/\D/g, '').slice(0, 10)
}

const sanitizeOtp = () => {
  otpCode.value = otpCode.value.replace(/\D/g, '').slice(0, 6)
}

const stepTitle = computed(() => {
  if (step.value === 'otp') return 'ยืนยันรหัส OTP'
  if (step.value === 'password') return 'ตั้งรหัสผ่านใหม่'
  return 'รีเซ็ตด้วย SMS OTP'
})

const stepDescription = computed(() => {
  if (step.value === 'otp') return `กรอกรหัส 6 หลักที่ส่งไปยัง ${maskedPhone.value || phone.value}`
  if (step.value === 'password') return 'กรอกรหัสผ่านใหม่สำหรับบัญชีของคุณ'
  return 'กรอกเบอร์โทรศัพท์ที่ใช้สมัครเพื่อรับรหัส OTP'
})

const submitLabel = computed(() => {
  if (submitting.value) return 'กำลังดำเนินการ'
  if (step.value === 'otp') return 'ยืนยัน OTP'
  if (step.value === 'password') return 'บันทึกรหัสผ่านใหม่'
  return 'ส่งรหัส OTP'
})

const apiMessage = (error: any, fallback: string) => error?.data?.error?.message ||
  error?.response?._data?.error?.message ||
  error?.response?.data?.error?.message ||
  error?.message ||
  fallback

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

const requestPasswordOtp = async () => {
  const response = await platformApi.requestOtp({
    phone: phone.value,
    purpose: 'password_reset'
  })
  maskedPhone.value = response?.phone_masked || ''
  otpCode.value = ''
  otpToken.value = ''
  step.value = 'otp'
  startResendCountdown(response?.resend_after_seconds || 60)
}

const submitRequest = async () => {
  if (submitting.value) return

  sanitizePhone()
  submitting.value = true
  submitted.value = false

  try {
    if (step.value === 'phone') {
      await requestPasswordOtp()
      showAlert({
        title: 'ส่งรหัส OTP แล้ว',
        message: 'กรุณากรอกรหัส OTP เพื่อรีเซ็ตรหัสผ่าน',
        variant: 'success'
      })
      return
    }

    if (step.value === 'otp') {
      sanitizeOtp()
      const response = await platformApi.verifyOtp({
        phone: phone.value,
        purpose: 'password_reset',
        otp: otpCode.value
      })
      otpToken.value = response?.otp_verification_token || ''
      step.value = 'password'
      return
    }

    if (password.value !== passwordConfirmation.value) {
      showAlert({
        title: 'รหัสผ่านไม่ตรงกัน',
        message: 'กรุณากรอกรหัสผ่านและยืนยันรหัสผ่านให้ตรงกัน',
        variant: 'warning'
      })
      return
    }

    await platformApi.resetPasswordWithOtp({
      phone: phone.value,
      otp_verification_token: otpToken.value,
      password: password.value,
      password_confirmation: passwordConfirmation.value
    })
    submitted.value = true
    showAlert({
      title: 'เปลี่ยนรหัสผ่านแล้ว',
      message: 'เข้าสู่ระบบด้วยรหัสผ่านใหม่ได้ทันที',
      variant: 'success'
    })
    await navigateTo('/login')
  } catch (error: any) {
    showAlert({
      title: 'รีเซ็ตรหัสผ่านไม่สำเร็จ',
      message: apiMessage(error, 'กรุณาตรวจสอบข้อมูลและลองใหม่อีกครั้ง'),
      variant: 'error'
    })
  } finally {
    submitting.value = false
  }
}

const startLineReset = async () => {
  if (lineSubmitting.value) return

  lineSubmitting.value = true

  try {
    setLineRedirect('/forgot-password')
    const response = await platformApi.lineLogin({ store_id: null, purpose: 'password_reset' })
    const url = typeof response?.url === 'string' ? response.url : ''

    if (response.code === 0 && isSafeLineLoginUrl(url)) {
      await lineLiff.redirectToLineLogin(url)
      return
    }

    throw new Error('missing_line_redirect_url')
  } catch (error: any) {
    showAlert({
      title: 'รีเซ็ตด้วย LINE ไม่สำเร็จ',
      message: error?.response?.data?.message || error?.message || 'บัญชีนี้อาจยังไม่ได้เชื่อมต่อ LINE หรือร้านค้ายังไม่ได้ตั้งค่า LINE',
      variant: 'error'
    })
  } finally {
    lineSubmitting.value = false
  }
}

const isSafeLineLoginUrl = (value: string) => {
  try {
    const url = new URL(value)
    return url.protocol === 'https:' && url.hostname === 'access.line.me'
  } catch {
    return false
  }
}

onBeforeUnmount(() => {
  if (resendTimer) {
    clearInterval(resendTimer)
  }
})
</script>

<style scoped>
.forgot-hero {
  color: #fff;
  margin: 26px auto 0;
  max-width: 330px;
  text-align: center;
}

.forgot-hero i {
  font-size: 34px;
}

.forgot-hero h1 {
  font-size: 24px;
  font-weight: 900;
  margin: 10px 0 8px;
}

.forgot-hero p {
  font-size: 14px;
  font-weight: 700;
  line-height: 1.55;
  margin: 0;
  opacity: .92;
}

.forgot-sheet {
  display: grid;
  gap: 14px;
  padding: 20px 16px 34px;
}

.forgot-card {
  background: #fff;
  border: 1px solid rgba(15, 54, 105, .08);
  border-radius: 22px;
  box-shadow: 0 18px 36px rgba(15, 54, 105, .08);
  padding: 20px;
}

.forgot-card-head h2 {
  color: #17345f;
  font-size: 20px;
  font-weight: 900;
  margin: 0 0 6px;
}

.forgot-card-head p {
  color: #738199;
  font-size: 14px;
  font-weight: 700;
  line-height: 1.5;
  margin: 0;
}

.forgot-field {
  display: grid;
  gap: 8px;
  margin-top: 18px;
}

.forgot-password-grid {
  display: grid;
  gap: 12px;
}

.forgot-field span {
  color: #17345f;
  font-weight: 900;
}

.forgot-input {
  align-items: center;
  background: #f6f9fd;
  border: 1px solid #e4ecf7;
  border-radius: 16px;
  display: flex;
  gap: 10px;
  min-height: 54px;
  padding: 0 14px;
}

.forgot-input i {
  color: #0b84f3;
  font-size: 20px;
}

.forgot-input input {
  background: transparent;
  border: 0;
  color: #17345f;
  flex: 1;
  font-size: 16px;
  font-weight: 800;
  min-width: 0;
  outline: 0;
}

.forgot-submit,
.forgot-line-button {
  border: 0;
  margin-top: 18px;
  min-height: 52px;
  width: 100%;
}

.forgot-link-button {
  background: transparent;
  border: 0;
  color: #0b74de;
  font-weight: 900;
  justify-self: start;
  padding: 0;
}

.forgot-link-button:disabled {
  color: #8c9aad;
}

.forgot-success {
  align-items: flex-start;
  background: #ecfdf5;
  border-radius: 16px;
  color: #087a4a;
  display: flex;
  gap: 12px;
  margin-top: 16px;
  padding: 14px;
}

.forgot-success i {
  font-size: 20px;
}

.forgot-success strong,
.forgot-success p {
  margin: 0;
}

.forgot-success p {
  color: #17815a;
  font-size: 13px;
  font-weight: 700;
  margin-top: 2px;
}

.forgot-line-card {
  background: linear-gradient(180deg, #ffffff 0%, #f5fff8 100%);
}

.forgot-line-button {
  align-items: center;
  background: #06c755;
  border-radius: 999px;
  color: #fff;
  display: inline-flex;
  font-size: 16px;
  font-weight: 900;
  gap: 10px;
  justify-content: center;
}

.forgot-line-button i {
  font-size: 22px;
}
</style>

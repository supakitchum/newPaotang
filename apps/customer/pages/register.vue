<template>
  <section class="login-hero register-hero">
    <div class="login-hero-inner">
      <div class="login-hero-copy register-hero-copy">
        <div class="login-badge">
          <i class="bi bi-person-check" />
          บัญชีเป๋าตัง
        </div>
        <h1>สมัครใช้งาน</h1>
        <p>สร้างบัญชีเพื่อซื้อ ตรวจสลากฯ และเก็บรายการของคุณอย่างปลอดภัย</p>
      </div>
    </div>
  </section>

  <section class="login-sheet register-sheet">
    <form class="login-card register-card" @submit.prevent="handleSubmit">
      <div class="login-form-head">
        <h2>ข้อมูลบัญชี</h2>
        <p>กรอกข้อมูลให้ตรงกับเบอร์โทรศัพท์ที่ใช้งาน</p>
      </div>

      <div class="register-name-grid">
        <label class="login-field">
          <span>ชื่อ</span>
          <div class="login-input">
            <i class="bi bi-person" />
            <input
                v-model.trim="firstName"
                autocomplete="given-name"
                placeholder="กรอกชื่อ"
                type="text"
            >
          </div>
        </label>

        <label class="login-field">
          <span>สกุล</span>
          <div class="login-input">
            <i class="bi bi-person" />
            <input
                v-model.trim="lastName"
                autocomplete="family-name"
                placeholder="กรอกสกุล"
                type="text"
            >
          </div>
        </label>
      </div>

      <label class="login-field">
        <span>เบอร์โทรศัพท์</span>
        <div class="login-input">
          <i class="bi bi-phone" />
          <input
              v-model="phone"
              autocomplete="tel"
              inputmode="numeric"
              maxlength="10"
              pattern="[0-9]*"
              placeholder="กรอกเบอร์โทรศัพท์"
              type="tel"
              @beforeinput="allowDigitsOnly"
              @input="sanitizePhone"
          >
        </div>
      </label>

      <label class="login-field">
        <span>รหัสผ่าน</span>
        <div class="login-input">
          <i class="bi bi-lock" />
          <input
              v-model="password"
              autocomplete="new-password"
              :type="showPassword ? 'text' : 'password'"
              placeholder="ตั้งรหัสผ่าน"
          >
          <button class="login-input-action" type="button" :aria-label="showPassword ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'" @click="showPassword = !showPassword">
            <i :class="showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'" />
          </button>
        </div>
      </label>

      <label class="login-field">
        <span>ยืนยันรหัสผ่าน</span>
        <div class="login-input">
          <i class="bi bi-shield-lock" />
          <input
              v-model="confirmPassword"
              autocomplete="new-password"
              :type="showConfirmPassword ? 'text' : 'password'"
              placeholder="กรอกรหัสผ่านอีกครั้ง"
          >
          <button class="login-input-action" type="button" :aria-label="showConfirmPassword ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'" @click="showConfirmPassword = !showConfirmPassword">
            <i :class="showConfirmPassword ? 'bi bi-eye-slash' : 'bi bi-eye'" />
          </button>
        </div>
      </label>

      <label class="login-check register-consent">
        <input v-model="acceptedTerms" type="checkbox">
        <span>ยอมรับเงื่อนไขการใช้งานและนโยบายความเป็นส่วนตัว</span>
      </label>

      <div v-if="otpSent" class="register-otp-panel">
        <div>
          <strong>ยืนยันเบอร์โทรศัพท์</strong>
          <p>กรอกรหัส OTP 6 หลักที่ส่งไปยัง {{ maskedPhone || phone }}</p>
        </div>
        <label class="login-field">
          <span>รหัส OTP</span>
          <div class="login-input">
            <i class="bi bi-chat-dots" />
            <input
                v-model="otpCode"
                inputmode="numeric"
                maxlength="6"
                pattern="[0-9]*"
                placeholder="กรอกรหัส OTP"
                type="tel"
                @beforeinput="allowDigitsOnly"
                @input="sanitizeOtp"
            >
          </div>
        </label>
        <button class="register-resend" type="button" :disabled="resendCountdown > 0 || isSubmitting" @click="requestRegisterOtp">
          {{ resendCountdown > 0 ? `ส่งรหัสใหม่ได้ใน ${resendCountdown} วินาที` : 'ส่งรหัสใหม่' }}
        </button>
      </div>

      <button class="primary-pill login-submit" type="submit">
        {{ otpSent ? 'ยืนยัน OTP และสมัครใช้งาน' : 'สมัครใช้งาน' }}
      </button>

      <div class="login-register">
        <span>มีบัญชีอยู่แล้ว?</span>
        <NuxtLink :to="loginTo">เข้าสู่ระบบ</NuxtLink>
      </div>
    </form>
  </section>
</template>

<script setup lang="ts">
import { ref } from 'vue'

definePageMeta({
  requiresAuth: false,
  guestOnly: true
})

const firstName = ref('')
const lastName = ref('')
const phone = ref('')
const password = ref('')
const confirmPassword = ref('')
const acceptedTerms = ref(false)
const showPassword = ref(false)
const showConfirmPassword = ref(false)
const isSubmitting = ref(false)
const otpSent = ref(false)
const otpCode = ref('')
const otpToken = ref('')
const maskedPhone = ref('')
const resendCountdown = ref(0)
let resendTimer: ReturnType<typeof setInterval> | null = null
const platformApi = usePlatformApi()
const route = useRoute()
const { setAuthSession } = useAuth()
const { applyStoredRef } = useAffiliateReferral()
const { refreshAppInit } = useAppInit()
const { showAlert } = useAppAlert()

const getSafeRedirect = () => {
  if (typeof route.query.redirect !== 'string') {
    return '/'
  }

  if (!route.query.redirect.startsWith('/') || route.query.redirect.startsWith('//')) {
    return '/'
  }

  return route.query.redirect
}

const needsPinUnlock = (response: Record<string, any>) => Boolean(
  response?.pin_setup_required ||
  response?.pin_required ||
  response?.user?.pin_setup_required ||
  response?.user?.pin_required
)

const loginTo = computed(() => {
  const redirect = getSafeRedirect()

  return redirect === '/'
    ? '/login'
    : { path: '/login', query: { redirect } }
})

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

const apiMessage = (error: any, fallback: string) => error?.data?.error?.message ||
  error?.response?._data?.error?.message ||
  error?.response?.data?.error?.message ||
  error?.message ||
  fallback

const apiCode = (error: any) => error?.data?.error?.code ||
  error?.response?._data?.error?.code ||
  error?.response?.data?.error?.code ||
  error?.code

const formPayload = () => {
  const fullName = `${firstName.value} ${lastName.value}`.trim()

  return {
    first_name: firstName.value,
    last_name: lastName.value,
    name: fullName,
    phone: phone.value,
    username: phone.value,
    password: password.value,
    password_confirmation: confirmPassword.value,
    ...(otpToken.value ? { otp_verification_token: otpToken.value } : {})
  }
}

const requestRegisterOtp = async () => {
  const response = await platformApi.requestOtp({
    phone: phone.value,
    purpose: 'register'
  })
  otpSent.value = true
  otpToken.value = ''
  otpCode.value = ''
  maskedPhone.value = response?.phone_masked || ''
  startResendCountdown(response?.resend_after_seconds || 60)
}

const completeRegistration = async () => {
  const response = await platformApi.register(formPayload())

  if (response?.token) {
    setAuthSession(response)
    await applyStoredRef({ registered: true })

    if (needsPinUnlock(response)) {
      await navigateTo({
        path: '/pin',
        query: {
          redirect: getSafeRedirect()
        }
      })
      return
    }

    await refreshAppInit(response.token)
    await navigateTo(getSafeRedirect())
  }
}

const handleSubmit = async () => {
  if (isSubmitting.value) {
    return
  }

  sanitizePhone()

  if (!acceptedTerms.value) {
    showAlert({
      title: 'กรุณายอมรับเงื่อนไข',
      message: 'ต้องยอมรับเงื่อนไขการใช้งานก่อนสมัครสมาชิก',
      variant: 'warning'
    })
    return
  }

  if (password.value !== confirmPassword.value) {
    showAlert({
      title: 'รหัสผ่านไม่ตรงกัน',
      message: 'กรุณากรอกรหัสผ่านและยืนยันรหัสผ่านให้ตรงกัน',
      variant: 'warning'
    })
    return
  }

  isSubmitting.value = true

  try {
    if (!otpSent.value) {
      try {
        await requestRegisterOtp()
        showAlert({
          title: 'ส่งรหัส OTP แล้ว',
          message: 'กรุณากรอกรหัส OTP เพื่อสมัครสมาชิก',
          variant: 'success'
        })
        return
      } catch (error: any) {
        if (apiCode(error) !== 'sms_otp_provider_not_configured') {
          throw error
        }
      }
    }

    if (otpSent.value && !otpToken.value) {
      sanitizeOtp()
      const verify = await platformApi.verifyOtp({
        phone: phone.value,
        purpose: 'register',
        otp: otpCode.value
      })
      otpToken.value = verify?.otp_verification_token || ''
      if (!otpToken.value) {
        throw new Error('OTP verification failed.')
      }
    }

    await completeRegistration()
  } catch (error: any) {
    showAlert({
      title: 'สมัครใช้งานไม่สำเร็จ',
      message: apiMessage(error, 'กรุณาตรวจสอบข้อมูลและลองใหม่อีกครั้ง'),
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}

onBeforeUnmount(() => {
  if (resendTimer) {
    clearInterval(resendTimer)
  }
})
</script>

<style scoped>
.register-otp-panel {
  background: #f3f8ff;
  border: 1px solid rgba(27, 116, 228, .18);
  border-radius: 18px;
  display: grid;
  gap: 12px;
  padding: 14px;
}

.register-otp-panel p {
  color: #6b7890;
  font-size: .9rem;
  margin: 4px 0 0;
}

.register-resend {
  align-self: flex-start;
  background: transparent;
  border: 0;
  color: #0b74de;
  font-weight: 800;
  padding: 0;
}

.register-resend:disabled {
  color: #8c9aad;
}
</style>

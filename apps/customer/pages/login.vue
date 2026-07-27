<template>
  <section class="login-hero">
    <div class="login-hero-inner">
      <div class="login-hero-copy">
        <div class="login-badge">
          <i class="bi bi-shield-check"/>
          สลากดิจิทัล
        </div>
        <h1>เข้าสู่ระบบ</h1>
        <p>ซื้อ ตรวจสอบ และจัดการสลากฯ ของคุณได้ในที่เดียว</p>
      </div>
    </div>
  </section>

  <section class="login-sheet">
    <form class="login-card" @submit.prevent="handleSubmit">
      <div class="login-form-head">
        <h2>ยืนยันตัวตน</h2>
        <p>ใช้เบอร์โทรศัพท์ที่ผูกกับบัญชีของคุณ</p>
      </div>

      <label class="login-field">
        <span>เบอร์โทรศัพท์</span>
        <div class="login-input">
          <i class="bi bi-phone"/>
          <input
              v-model="phone"
              autocomplete="tel"
              inputmode="numeric"
              maxlength="10"
              :disabled="otpRequired"
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
          <i class="bi bi-lock"/>
          <input
              v-model="password"
              autocomplete="current-password"
              :disabled="otpRequired"
              :type="showPassword ? 'text' : 'password'"
              placeholder="กรอกรหัสผ่าน"
          >
          <button class="login-input-action" type="button" :aria-label="showPassword ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'"
                  @click="showPassword = !showPassword">
            <i :class="showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'"/>
          </button>
        </div>
      </label>

      <div v-if="!otpRequired" class="login-options">
        <label class="login-check">
          <input v-model="rememberMe" type="checkbox">
          <span>จดจำการเข้าสู่ระบบ</span>
        </label>
        <NuxtLink to="/forgot-password">ลืมรหัสผ่าน?</NuxtLink>
      </div>

      <div v-if="otpRequired" class="login-otp-panel">
        <div>
          <strong>ยืนยันการเข้าสู่ระบบด้วย OTP</strong>
          <p>กรอกรหัส OTP 6 หลักที่ส่งไปยัง {{ maskedPhone }}</p>
        </div>
        <label class="login-field">
          <span>รหัส OTP</span>
          <div class="login-input">
            <i class="bi bi-chat-dots"/>
            <input
                v-model="otpCode"
                autocomplete="one-time-code"
                inputmode="numeric"
                maxlength="6"
                pattern="[0-9]*"
                placeholder="กรอกรหัส OTP"
                type="text"
                @input="sanitizeOtp"
            >
          </div>
        </label>
        <div class="login-otp-actions">
          <button type="button" :disabled="isSubmitting" @click="cancelLoginOtp">
            แก้ไขข้อมูลเข้าสู่ระบบ
          </button>
          <button type="button" :disabled="isSubmitting || resendCountdown > 0" @click="resendLoginOtp">
            {{ resendCountdown > 0 ? `ส่งใหม่ได้ใน ${resendCountdown} วินาที` : 'ส่งรหัสใหม่' }}
          </button>
        </div>
      </div>

      <button class="primary-pill login-submit" type="submit" :disabled="isSubmitting">
        {{ submitLabel }}
      </button>

      <div v-if="!otpRequired" class="login-divider">
        <span>หรือ</span>
      </div>

      <button v-if="!otpRequired" class="line-login-button" type="button" :disabled="isSubmitting || isLineSubmitting" @click="handleLineLogin">
        <i class="bi bi-line"/>
        <span>{{ isLineSubmitting ? 'กำลังเชื่อมต่อ LINE' : 'เข้าสู่ระบบด้วย Line' }}</span>
      </button>

      <div v-if="!otpRequired" class="login-register">
        <span>ยังไม่มีบัญชี?</span>
        <NuxtLink :to="registerTo">สมัครใช้งาน</NuxtLink>
      </div>
    </form>
  </section>
</template>

<script setup lang="ts">
import {computed, onBeforeUnmount, ref} from 'vue'
import {handlesCustomerPinInline} from '~/utils/customerAuthRoutes'

definePageMeta({
  requiresAuth: false,
  guestOnly: true
})

const phone = ref('')
const password = ref('')
const rememberMe = ref(true)
const showPassword = ref(false)
const otpCode = ref('')
const loginChallengeToken = ref('')
const maskedPhone = ref('')
const resendCountdown = ref(0)
let resendTimer: ReturnType<typeof setInterval> | null = null
const isSubmitting = ref(false)
const isLineSubmitting = ref(false)
const route = useRoute()
const platformApi = usePlatformApi()
const {setAuthSession, setLineRedirect} = useAuth()
const { applyStoredRef } = useAffiliateReferral()
const {refreshAppInit} = useAppInit()
const {showAlert} = useAppAlert()
const lineLiff = useLineLiff()
const otpRequired = computed(() => Boolean(loginChallengeToken.value))
const submitLabel = computed(() => {
  if (isSubmitting.value) {
    return otpRequired.value ? 'กำลังยืนยัน OTP' : 'กำลังเข้าสู่ระบบ'
  }

  return otpRequired.value ? 'ยืนยัน OTP' : 'เข้าสู่ระบบ'
})

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

const needsPinSetup = (response: Record<string, any>) => Boolean(
  response?.pin_setup_required ||
  response?.user?.pin_setup_required
)

const needsPinVerification = (response: Record<string, any>) => Boolean(
  response?.pin_required ||
  response?.user?.pin_required
)

const shouldUseInlinePinRedirect = (response: Record<string, any>, redirect: string) => (
  !needsPinSetup(response) &&
  needsPinVerification(response) &&
  handlesCustomerPinInline(redirect)
)

const registerTo = computed(() => {
  const redirect = getSafeRedirect()

  return redirect === '/'
    ? '/register'
    : { path: '/register', query: { redirect } }
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

const startResendTimer = (seconds: number) => {
  if (resendTimer) clearInterval(resendTimer)
  resendCountdown.value = Math.max(0, seconds)
  if (resendCountdown.value <= 0) return
  resendTimer = setInterval(() => {
    resendCountdown.value = Math.max(0, resendCountdown.value - 1)
    if (resendCountdown.value === 0 && resendTimer) {
      clearInterval(resendTimer)
      resendTimer = null
    }
  }, 1000)
}

const applyLoginOtpChallenge = (response: Record<string, any>) => {
  loginChallengeToken.value = String(response?.login_challenge_token || '')
  maskedPhone.value = String(response?.phone_masked || phone.value)
  otpCode.value = ''
  startResendTimer(Number(response?.resend_after_seconds || 60))
}

const cancelLoginOtp = () => {
  loginChallengeToken.value = ''
  maskedPhone.value = ''
  otpCode.value = ''
  startResendTimer(0)
}

const completeLogin = async (response: Record<string, any>) => {
  if (!response?.token) return
  setAuthSession(response)
  await applyStoredRef()

  if (needsPinUnlock(response)) {
    const redirect = getSafeRedirect()
    if (shouldUseInlinePinRedirect(response, redirect)) {
      await navigateTo(redirect)
      return
    }
    await navigateTo({path: '/pin', query: {redirect}})
    return
  }

  await refreshAppInit(response.token)
  await navigateTo(getSafeRedirect())
}

const resendLoginOtp = async () => {
  if (isSubmitting.value || !loginChallengeToken.value || resendCountdown.value > 0) return
  isSubmitting.value = true
  try {
    const response = await platformApi.resendLoginOtp({
      login_challenge_token: loginChallengeToken.value
    })
    applyLoginOtpChallenge(response)
  } catch (error: any) {
    showAlert({
      title: 'ส่งรหัส OTP ไม่สำเร็จ',
      message: error?.response?.data?.error?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}

const handleSubmit = async () => {
  if (isSubmitting.value) {
    return
  }

  sanitizePhone()

  isSubmitting.value = true

  try {
    if (otpRequired.value) {
      sanitizeOtp()
      if (!/^\d{6}$/.test(otpCode.value)) {
        throw new Error('กรุณากรอก OTP 6 หลัก')
      }
      const response = await platformApi.verifyLoginOtp({
        login_challenge_token: loginChallengeToken.value,
        otp: otpCode.value
      })
      await completeLogin(response)
      return
    }

    const response = await platformApi.login({
      username: phone.value,
      phone: phone.value,
      password: password.value
    })

    if (response?.otp_required && response?.login_challenge_token) {
      applyLoginOtpChallenge(response)
      return
    }
    await completeLogin(response)
  } catch (error: any) {
    showAlert({
      title: 'เข้าสู่ระบบไม่สำเร็จ',
      message: error?.response?.data?.error?.message || error?.message || 'กรุณาตรวจสอบเบอร์โทรศัพท์และรหัสผ่านอีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}

const handleLineLogin = async () => {
  if (isSubmitting.value || isLineSubmitting.value) {
    return
  }

  isLineSubmitting.value = true

  try {
    setLineRedirect(getSafeRedirect())
    const response = await platformApi.lineLogin({store_id: null})
    const url = typeof response?.url === 'string' ? response.url : ''

    if (response.code === 0 && isSafeLineLoginUrl(url)) {
      await lineLiff.redirectToLineLogin(url)
      return
    }

    throw new Error('missing_line_redirect_url')
  } catch (error: any) {
    showAlert({
      title: 'เข้าสู่ระบบด้วย LINE ไม่สำเร็จ',
      message: error?.response?.data?.message || 'ไม่สามารถเชื่อมต่อ LINE ได้ กรุณาตรวจสอบการตั้งค่า LINE OA แล้วลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isLineSubmitting.value = false
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
  if (resendTimer) clearInterval(resendTimer)
})
</script>

<style scoped>
.login-otp-panel {
  background: #f3f8ff;
  border: 1px solid rgba(27, 116, 228, .18);
  border-radius: 18px;
  display: grid;
  gap: 12px;
  padding: 14px;
}

.login-otp-panel p {
  color: #6b7890;
  font-size: .9rem;
  margin: 4px 0 0;
}

.login-otp-actions {
  display: flex;
  justify-content: space-between;
  gap: 12px;
}

.login-otp-actions button {
  background: transparent;
  border: 0;
  color: #0b74de;
  font-weight: 800;
  padding: 0;
}

.login-otp-actions button:disabled {
  color: #8c9aad;
}
</style>

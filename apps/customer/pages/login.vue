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
              :type="showPassword ? 'text' : 'password'"
              placeholder="กรอกรหัสผ่าน"
          >
          <button class="login-input-action" type="button" :aria-label="showPassword ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'"
                  @click="showPassword = !showPassword">
            <i :class="showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'"/>
          </button>
        </div>
      </label>

      <div class="login-options">
        <label class="login-check">
          <input v-model="rememberMe" type="checkbox">
          <span>จดจำการเข้าสู่ระบบ</span>
        </label>
        <NuxtLink to="/forgot-password">ลืมรหัสผ่าน?</NuxtLink>
      </div>

      <button class="primary-pill login-submit" type="submit" :disabled="isSubmitting">
        {{ isSubmitting ? 'กำลังเข้าสู่ระบบ' : 'เข้าสู่ระบบ' }}
      </button>

      <div class="login-divider">
        <span>หรือ</span>
      </div>

      <button class="line-login-button" type="button" :disabled="isSubmitting || isLineSubmitting" @click="handleLineLogin">
        <i class="bi bi-line"/>
        <span>{{ isLineSubmitting ? 'กำลังเชื่อมต่อ LINE' : 'เข้าสู่ระบบด้วย Line' }}</span>
      </button>

      <div class="login-register">
        <span>ยังไม่มีบัญชี?</span>
        <NuxtLink :to="registerTo">สมัครใช้งาน</NuxtLink>
      </div>
    </form>
  </section>
</template>

<script setup lang="ts">
import {ref} from 'vue'
import {handlesCustomerPinInline} from '~/utils/customerAuthRoutes'

definePageMeta({
  requiresAuth: false,
  guestOnly: true
})

const phone = ref('')
const password = ref('')
const rememberMe = ref(true)
const showPassword = ref(false)
const isSubmitting = ref(false)
const isLineSubmitting = ref(false)
const route = useRoute()
const platformApi = usePlatformApi()
const {setAuthSession, setLineRedirect} = useAuth()
const { applyStoredRef } = useAffiliateReferral()
const {refreshAppInit} = useAppInit()
const {showAlert} = useAppAlert()
const lineLiff = useLineLiff()

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

const handleSubmit = async () => {
  if (isSubmitting.value) {
    return
  }

  sanitizePhone()

  isSubmitting.value = true

  try {
    const response = await platformApi.login({
      username: phone.value,
      phone: phone.value,
      password: password.value
    })

    if (response?.token) {
      setAuthSession(response)
      await applyStoredRef()

      if (needsPinUnlock(response)) {
        const redirect = getSafeRedirect()

        if (shouldUseInlinePinRedirect(response, redirect)) {
          await navigateTo(redirect)
          return
        }

        await navigateTo({
          path: '/pin',
          query: {
            redirect
          }
        })
        return
      }

      await refreshAppInit(response.token)
      await navigateTo(getSafeRedirect())
    }
  } catch (error: any) {
    showAlert({
      title: 'เข้าสู่ระบบไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาตรวจสอบเบอร์โทรศัพท์และรหัสผ่านอีกครั้ง',
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
      redirectToLineLogin(url)
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

const redirectToLineLogin = (url: string) => {
  if (!import.meta.client) {
    void navigateTo(url, { external: true })
    return
  }

  if (lineLiff.isLiffClient.value) {
    const liff = (window as any).liff
    if (liff?.openWindow) {
      liff.openWindow({ url, external: true })
      return
    }
  }

  window.location.assign(url)
}
</script>

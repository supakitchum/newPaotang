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

      <button class="primary-pill login-submit" type="submit">
        สมัครใช้งาน
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
const platformApi = usePlatformApi()
const route = useRoute()
const { setAuthToken, setAuthUser } = useAuth()
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
    const fullName = `${firstName.value} ${lastName.value}`.trim()
    const response = await platformApi.register({
      first_name: firstName.value,
      last_name: lastName.value,
      name: fullName,
      phone: phone.value,
      username: phone.value,
      password: password.value,
      password_confirmation: confirmPassword.value
    })

    if (response?.token) {
      setAuthToken(response.token)
      setAuthUser(response.user || response.customer || {})
      await applyStoredRef({ registered: true })
      await refreshAppInit(response.token)
      await navigateTo(getSafeRedirect())
    }
  } catch (error: any) {
    showAlert({
      title: 'สมัครใช้งานไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาตรวจสอบข้อมูลและลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}
</script>

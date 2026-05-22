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
        <NuxtLink to="/login">ลืมรหัสผ่าน?</NuxtLink>
      </div>

      <button class="primary-pill login-submit" type="submit" :disabled="isSubmitting">
        {{ isSubmitting ? 'กำลังเข้าสู่ระบบ' : 'เข้าสู่ระบบ' }}
      </button>

      <div class="login-divider">
        <span>หรือ</span>
      </div>

      <button class="line-login-button" type="button" @click="handleLineLogin">
        <i class="bi bi-line"/>
        <span>เข้าสู่ระบบด้วย Line</span>
      </button>

      <div class="login-register">
        <span>ยังไม่มีบัญชี?</span>
        <NuxtLink to="/register">สมัครใช้งาน</NuxtLink>
      </div>
    </form>
  </section>
</template>

<script setup lang="ts">
import {ref} from 'vue'

definePageMeta({
  requiresAuth: false,
  guestOnly: true
})

const phone = ref('')
const password = ref('')
const rememberMe = ref(true)
const showPassword = ref(false)
const isSubmitting = ref(false)
const route = useRoute()
const platformApi = usePlatformApi()
const {setAuthSession, setLineRedirect} = useAuth()
const { applyStoredRef } = useAffiliateReferral()
const {refreshAppInit} = useAppInit()
const {showAlert} = useAppAlert()

const getSafeRedirect = () => {
  if (typeof route.query.redirect !== 'string') {
    return '/'
  }

  if (!route.query.redirect.startsWith('/') || route.query.redirect.startsWith('//')) {
    return '/'
  }

  return route.query.redirect
}

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
  setLineRedirect(getSafeRedirect())
  const response = await platformApi.lineLogin({store_id: null})

  if (response.code === 0) {
    await navigateTo(response.url, {external: true})
  }
}
</script>

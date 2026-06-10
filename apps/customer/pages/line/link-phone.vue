<template>
  <MobileShell time="13:09">
    <BlueHeader class="line-link-hero" min-height="220px">
      <HeroBack to="/login" />
      <div class="line-link-title">
        <i class="bi bi-line" />
        <h1>ผูกบัญชีด้วย LINE</h1>
        <p>ยืนยันเบอร์โทรศัพท์เพื่อใช้งานบัญชีเดิม หรือสร้างบัญชีใหม่ด้วย LINE</p>
      </div>
    </BlueHeader>

    <section class="content-sheet line-link-sheet">
      <form class="line-link-card" @submit.prevent="submit">
        <div v-if="lineName" class="line-profile-chip">
          <i class="bi bi-line" />
          <span>{{ lineName }}</span>
        </div>

        <label class="line-link-field">
          <span>เบอร์โทรศัพท์</span>
          <div class="line-link-input">
            <i class="bi bi-phone" />
            <input
              v-model="phone"
              inputmode="numeric"
              maxlength="10"
              autocomplete="tel"
              placeholder="กรอกเบอร์โทรศัพท์"
              @beforeinput="allowDigitsOnly"
              @input="sanitizePhone"
            >
          </div>
        </label>

        <label class="line-link-field">
          <span>รหัสผ่าน</span>
          <div class="line-link-input">
            <i class="bi bi-lock" />
            <input
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              autocomplete="current-password"
              placeholder="รหัสผ่านบัญชีเดิม หรือรหัสผ่านใหม่"
            >
            <button type="button" class="line-link-eye" @click="showPassword = !showPassword">
              <i :class="showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'" />
            </button>
          </div>
        </label>

        <label class="line-link-field">
          <span>ยืนยันรหัสผ่าน</span>
          <div class="line-link-input">
            <i class="bi bi-shield-lock" />
            <input
              v-model="confirmPassword"
              :type="showPassword ? 'text' : 'password'"
              autocomplete="new-password"
              placeholder="กรอกซ้ำเพื่อสร้างบัญชีใหม่"
            >
          </div>
        </label>

        <p class="line-link-note">
          หากเบอร์นี้มีบัญชีอยู่แล้ว ระบบจะตรวจรหัสผ่านเดิมและผูก LINE เข้ากับบัญชีนั้นทันที
        </p>

        <button class="primary-pill line-link-submit" type="submit" :disabled="isSubmitting">
          {{ isSubmitting ? 'กำลังยืนยัน' : 'ยืนยันและเข้าสู่ระบบ' }}
        </button>
      </form>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { handlesCustomerPinInline } from '~/utils/customerAuthRoutes'

definePageMeta({
  requiresAuth: false
})

const route = useRoute()
const platformApi = usePlatformApi()
const { setAuthSession, clearLineRedirect } = useAuth()
const { applyStoredRef } = useAffiliateReferral()
const { refreshAppInit } = useAppInit()
const { showAlert } = useAppAlert()
const phone = ref('')
const password = ref('')
const confirmPassword = ref('')
const showPassword = ref(false)
const isSubmitting = ref(false)

const lineName = computed(() => typeof route.query.name === 'string' ? route.query.name : '')
const linkToken = computed(() => typeof route.query.token === 'string' ? route.query.token : '')
const redirectTo = computed(() => {
  const value = typeof route.query.redirect === 'string' ? route.query.redirect : '/'
  return value.startsWith('/') && !value.startsWith('//') ? value : '/'
})

onMounted(() => {
  if (!linkToken.value) {
    void navigateTo('/login', { replace: true })
  }
})

const allowDigitsOnly = (event: InputEvent) => {
  if (event.data && !/^\d+$/.test(event.data)) {
    event.preventDefault()
  }
}

const sanitizePhone = () => {
  phone.value = phone.value.replace(/\D/g, '').slice(0, 10)
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

const submit = async () => {
  if (isSubmitting.value) return

  sanitizePhone()

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
    const response = await platformApi.lineLinkPhone({
      link_token: linkToken.value,
      phone: phone.value,
      password: password.value,
      password_confirmation: confirmPassword.value
    })

    setAuthSession(response)
    await applyStoredRef()

    if (needsPinUnlock(response)) {
      if (!needsPinSetup(response) && needsPinVerification(response) && handlesCustomerPinInline(redirectTo.value)) {
        clearLineRedirect()
        await navigateTo(redirectTo.value)
        return
      }

      clearLineRedirect()
      await navigateTo({ path: '/pin', query: { redirect: redirectTo.value } })
      return
    }

    await refreshAppInit(response.token)
    clearLineRedirect()
    await navigateTo(redirectTo.value)
  } catch (error: any) {
    showAlert({
      title: 'ผูกบัญชี LINE ไม่สำเร็จ',
      message: error?.response?.data?.message || error?.message || 'กรุณาตรวจสอบข้อมูลและลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}
</script>

<style scoped>
.line-link-hero {
  color: #fff;
}

.line-link-title {
  margin-top: 34px;
  text-align: center;
}

.line-link-title i {
  font-size: 34px;
  color: #06c755;
}

.line-link-title h1 {
  margin: 10px 0 8px;
  font-size: 24px;
  font-weight: 900;
}

.line-link-title p {
  margin: 0 auto;
  max-width: 300px;
  font-weight: 700;
  opacity: .9;
}

.line-link-sheet {
  padding: 20px 16px 32px;
}

.line-link-card {
  display: grid;
  gap: 16px;
}

.line-profile-chip {
  align-items: center;
  background: #effaf2;
  border: 1px solid rgba(6, 199, 85, .24);
  border-radius: 8px;
  color: #057a35;
  display: inline-flex;
  font-weight: 900;
  gap: 8px;
  justify-self: start;
  padding: 8px 12px;
}

.line-link-field {
  display: grid;
  gap: 8px;
  font-weight: 900;
}

.line-link-input {
  align-items: center;
  background: #f5f8fb;
  border: 1px solid #dce6f0;
  border-radius: 8px;
  display: flex;
  gap: 10px;
  padding: 0 12px;
}

.line-link-input input {
  background: transparent;
  border: 0;
  flex: 1;
  font-size: 16px;
  font-weight: 800;
  min-height: 48px;
  outline: 0;
}

.line-link-eye {
  background: transparent;
  border: 0;
  color: #6a7686;
}

.line-link-note {
  background: #fff8e6;
  border-radius: 8px;
  color: #9a6a00;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.45;
  margin: 0;
  padding: 12px;
}

.line-link-submit {
  width: 100%;
}
</style>

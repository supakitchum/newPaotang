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
        <div class="line-profile-card">
          <div class="line-profile-avatar" :class="{ empty: !linePictureUrl }">
            <img v-if="linePictureUrl" :src="linePictureUrl" alt="LINE profile">
            <i v-else class="bi bi-line" />
          </div>
          <div class="line-profile-copy">
            <span class="line-profile-kicker">บัญชี LINE</span>
            <strong>{{ lineName || 'ลูกค้า LINE' }}</strong>
            <small>ยืนยันเบอร์เพื่อผูกบัญชีและเข้าสู่ระบบ</small>
          </div>
          <span class="line-profile-status">
            <i class="bi bi-check2-circle" />
            พร้อมผูกบัญชี
          </span>
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
const linePictureUrl = computed(() => typeof route.query.picture_url === 'string' ? route.query.picture_url : '')
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
  margin: 30px auto 0;
  max-width: min(100%, 360px);
  padding: 0 18px;
  text-align: center;
}

.line-link-title i {
  align-items: center;
  background: rgba(255, 255, 255, .18);
  border: 1px solid rgba(255, 255, 255, .2);
  border-radius: 18px;
  color: #06c755;
  display: inline-flex;
  font-size: 32px;
  height: 58px;
  justify-content: center;
  width: 58px;
}

.line-link-title h1 {
  margin: 10px 0 8px;
  font-size: clamp(22px, 6vw, 28px);
  font-weight: 900;
}

.line-link-title p {
  margin: 0 auto;
  max-width: 320px;
  font-size: clamp(13px, 3.6vw, 15px);
  font-weight: 700;
  line-height: 1.45;
  opacity: .9;
}

.line-link-sheet {
  background: #f5f7fb;
  min-height: calc(100dvh - 156px);
  padding: clamp(18px, 5vw, 28px) 16px 40px;
}

.line-link-card {
  background: #fff;
  border: 1px solid rgba(18, 47, 86, .08);
  border-radius: 18px;
  box-shadow: 0 18px 42px rgba(29, 54, 90, .12);
  display: grid;
  gap: 18px;
  max-width: 520px;
  padding: clamp(16px, 5vw, 24px);
}

.line-profile-card {
  align-items: center;
  background: linear-gradient(135deg, #effaf2 0%, #f7fbff 100%);
  border: 1px solid rgba(6, 199, 85, .18);
  border-radius: 16px;
  display: grid;
  gap: 12px;
  grid-template-columns: auto minmax(0, 1fr);
  padding: 14px;
}

.line-profile-avatar {
  align-items: center;
  background: #06c755;
  border: 4px solid #fff;
  border-radius: 18px;
  box-shadow: 0 10px 24px rgba(6, 199, 85, .22);
  color: #fff;
  display: flex;
  font-size: 28px;
  height: 72px;
  justify-content: center;
  overflow: hidden;
  width: 72px;
}

.line-profile-avatar img {
  display: block;
  height: 100%;
  object-fit: cover;
  width: 100%;
}

.line-profile-avatar.empty {
  background: #06c755;
}

.line-profile-copy {
  align-self: center;
  display: grid;
  gap: 3px;
  min-width: 0;
}

.line-profile-kicker {
  color: #06a948;
  font-size: 12px;
  font-weight: 900;
}

.line-profile-copy strong {
  color: #102a4c;
  display: block;
  font-size: clamp(18px, 5vw, 22px);
  font-weight: 1000;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.line-profile-copy small {
  color: #6a7686;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.35;
}

.line-profile-status {
  align-items: center;
  background: #e7f8ee;
  border-radius: 999px;
  color: #057a35;
  display: inline-flex;
  font-size: 12px;
  font-weight: 900;
  gap: 5px;
  grid-column: 1 / -1;
  justify-self: start;
  padding: 6px 10px;
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
  border-radius: 14px;
  display: flex;
  gap: 10px;
  min-width: 0;
  padding: 0 14px;
}

.line-link-input i {
  color: #0b7fe8;
  flex: 0 0 auto;
}

.line-link-input input {
  background: transparent;
  border: 0;
  flex: 1;
  font-size: 16px;
  font-weight: 800;
  min-height: 52px;
  min-width: 0;
  outline: 0;
}

.line-link-eye {
  background: transparent;
  border: 0;
  color: #6a7686;
}

.line-link-note {
  background: #fff8e6;
  border: 1px solid rgba(238, 176, 34, .24);
  border-radius: 14px;
  color: #9a6a00;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.45;
  margin: 0;
  padding: 12px;
}

.line-link-submit {
  min-height: 54px;
  width: 100%;
}

@media (max-width: 380px) {
  .line-link-sheet {
    padding-inline: 12px;
  }

  .line-link-card {
    border-radius: 16px;
    padding: 14px;
  }

  .line-profile-card {
    grid-template-columns: 1fr;
    justify-items: center;
    text-align: center;
  }

  .line-profile-status {
    justify-self: center;
  }
}

@media (min-width: 768px) {
  .line-link-sheet {
    padding-top: 32px;
  }

  .line-profile-card {
    grid-template-columns: auto minmax(0, 1fr) auto;
  }

  .line-profile-status {
    align-self: center;
    grid-column: auto;
    justify-self: end;
  }
}
</style>

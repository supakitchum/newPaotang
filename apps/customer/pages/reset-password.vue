<template>
  <MobileShell time="12:16">
    <BlueHeader title="ตั้งรหัสผ่านใหม่" back-to="/login" min-height="250px">
      <div class="reset-hero">
        <i class="bi bi-key" />
        <h1>ตั้งรหัสผ่านใหม่</h1>
        <p>{{ isLineSource ? 'ยืนยันผ่าน LINE สำเร็จแล้ว ตั้งรหัสผ่านใหม่เพื่อใช้งานต่อ' : 'ใช้ลิงก์ที่ได้รับจากผู้ดูแลร้านค้าเพื่อตั้งรหัสผ่านใหม่' }}</p>
      </div>
    </BlueHeader>

    <section class="content-sheet reset-sheet">
      <form class="reset-card" @submit.prevent="submit">
        <div v-if="!token" class="reset-warning">
          <i class="bi bi-exclamation-triangle-fill" />
          <div>
            <strong>ลิงก์ไม่ถูกต้อง</strong>
            <p>กรุณาขอลิงก์รีเซ็ตรหัสผ่านใหม่อีกครั้ง</p>
          </div>
        </div>

        <div class="reset-card-head">
          <h2>รหัสผ่านใหม่</h2>
          <p>กรอกรหัสผ่านใหม่และยืนยันให้ตรงกัน</p>
        </div>

        <label class="reset-field">
          <span>รหัสผ่านใหม่</span>
          <div class="reset-input">
            <i class="bi bi-lock" />
            <input
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              autocomplete="new-password"
              placeholder="กรอกรหัสผ่านใหม่"
            >
            <button type="button" class="reset-eye" :aria-label="showPassword ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'" @click="showPassword = !showPassword">
              <i :class="showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'" />
            </button>
          </div>
        </label>

        <label class="reset-field">
          <span>ยืนยันรหัสผ่านใหม่</span>
          <div class="reset-input">
            <i class="bi bi-shield-lock" />
            <input
              v-model="confirmPassword"
              :type="showConfirmPassword ? 'text' : 'password'"
              autocomplete="new-password"
              placeholder="กรอกอีกครั้ง"
            >
            <button type="button" class="reset-eye" :aria-label="showConfirmPassword ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'" @click="showConfirmPassword = !showConfirmPassword">
              <i :class="showConfirmPassword ? 'bi bi-eye-slash' : 'bi bi-eye'" />
            </button>
          </div>
        </label>

        <button class="primary-pill reset-submit" type="submit" :disabled="submitting || !token">
          {{ submitting ? 'กำลังบันทึก' : 'บันทึกรหัสผ่านใหม่' }}
        </button>
      </form>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: false,
  guestOnly: true
})

const route = useRoute()
const platformApi = usePlatformApi()
const { showAlert } = useAppAlert()
const password = ref('')
const confirmPassword = ref('')
const showPassword = ref(false)
const showConfirmPassword = ref(false)
const submitting = ref(false)

const token = computed(() => typeof route.query.token === 'string' ? route.query.token : '')
const isLineSource = computed(() => route.query.source === 'line')

const submit = async () => {
  if (submitting.value || !token.value) return

  if (password.value !== confirmPassword.value) {
    showAlert({
      title: 'รหัสผ่านไม่ตรงกัน',
      message: 'กรุณากรอกรหัสผ่านใหม่และยืนยันรหัสผ่านให้ตรงกัน',
      variant: 'warning'
    })
    return
  }

  submitting.value = true

  try {
    await platformApi.resetPassword({
      token: token.value,
      password: password.value,
      password_confirmation: confirmPassword.value,
      source: isLineSource.value ? 'line_login' : 'admin_reset_link'
    })

    showAlert({
      title: 'ตั้งรหัสผ่านใหม่แล้ว',
      message: 'กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่',
      variant: 'success'
    })
    await navigateTo('/login', { replace: true })
  } catch (error: any) {
    showAlert({
      title: 'ตั้งรหัสผ่านไม่สำเร็จ',
      message: error?.response?.data?.message || error?.message || 'ลิงก์อาจหมดอายุ กรุณาขอลิงก์ใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.reset-hero {
  color: #fff;
  margin: 24px auto 0;
  max-width: 330px;
  padding-bottom: 42px;
  text-align: center;
}

.reset-hero i {
  font-size: 34px;
}

.reset-hero h1 {
  font-size: 24px;
  font-weight: 900;
  margin: 10px 0 8px;
}

.reset-hero p {
  font-size: 14px;
  font-weight: 700;
  line-height: 1.55;
  margin: 0;
  opacity: .92;
}

.reset-sheet {
  margin-top: -34px;
  padding: 22px 16px 34px;
}

.reset-card {
  background: #fff;
  border: 1px solid rgba(15, 54, 105, .08);
  border-radius: 22px;
  box-shadow: 0 18px 36px rgba(15, 54, 105, .08);
  padding: 20px;
}

.reset-card-head h2 {
  color: #17345f;
  font-size: 20px;
  font-weight: 900;
  margin: 0 0 6px;
}

.reset-card-head p {
  color: #738199;
  font-size: 14px;
  font-weight: 700;
  margin: 0;
}

.reset-warning {
  align-items: flex-start;
  background: #fff7ed;
  border-radius: 16px;
  color: #b45309;
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
  padding: 14px;
}

.reset-warning i {
  font-size: 20px;
}

.reset-warning strong,
.reset-warning p {
  margin: 0;
}

.reset-warning p {
  color: #92400e;
  font-size: 13px;
  font-weight: 700;
  margin-top: 2px;
}

.reset-field {
  display: grid;
  gap: 8px;
  margin-top: 18px;
}

.reset-field span {
  color: #17345f;
  font-weight: 900;
}

.reset-input {
  align-items: center;
  background: #f6f9fd;
  border: 1px solid #e4ecf7;
  border-radius: 16px;
  display: flex;
  gap: 10px;
  min-height: 54px;
  padding: 0 14px;
}

.reset-input > i {
  color: #0b84f3;
  font-size: 20px;
}

.reset-input input {
  background: transparent;
  border: 0;
  color: #17345f;
  flex: 1;
  font-size: 16px;
  font-weight: 800;
  min-width: 0;
  outline: 0;
}

.reset-eye {
  align-items: center;
  background: transparent;
  border: 0;
  color: #718096;
  display: inline-flex;
  height: 36px;
  justify-content: center;
  width: 36px;
}

.reset-submit {
  border: 0;
  margin-top: 22px;
  min-height: 52px;
  width: 100%;
}
</style>

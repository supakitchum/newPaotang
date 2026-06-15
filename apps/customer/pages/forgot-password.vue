<template>
  <MobileShell time="12:15">
    <BlueHeader title="ลืมรหัสผ่าน" back-to="/login" min-height="220px">
      <div class="forgot-hero">
        <i class="bi bi-shield-lock" />
        <h1>ขอรีเซ็ตรหัสผ่าน</h1>
        <p>ส่งคำร้องให้ร้านค้าออกลิงก์รีเซ็ตรหัสผ่าน หรือใช้ LINE ที่ผูกไว้เพื่อรีเซ็ตทันที</p>
      </div>
    </BlueHeader>

    <section class="content-sheet forgot-sheet">
      <form class="forgot-card" @submit.prevent="submitRequest">
        <div class="forgot-card-head">
          <h2>ส่งคำร้องให้ร้านค้า</h2>
          <p>กรอกเบอร์โทรศัพท์ที่ใช้สมัคร ระบบจะส่งคำร้องไปยังผู้ดูแลร้านค้า</p>
        </div>

        <label class="forgot-field">
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

        <button class="primary-pill forgot-submit" type="submit" :disabled="submitting">
          {{ submitting ? 'กำลังส่งคำร้อง' : 'ส่งคำร้องลืมรหัสผ่าน' }}
        </button>

        <div v-if="submitted" class="forgot-success">
          <i class="bi bi-check-circle-fill" />
          <div>
            <strong>ส่งคำร้องแล้ว</strong>
            <p>กรุณารอผู้ดูแลร้านค้าออกลิงก์รีเซ็ตรหัสผ่านให้คุณ</p>
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
const submitting = ref(false)
const lineSubmitting = ref(false)
const submitted = ref(false)
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

const submitRequest = async () => {
  if (submitting.value) return

  sanitizePhone()
  submitting.value = true
  submitted.value = false

  try {
    await platformApi.forgotPassword({ phone: phone.value })
    submitted.value = true
    showAlert({
      title: 'ส่งคำร้องแล้ว',
      message: 'ผู้ดูแลร้านค้าจะออกลิงก์รีเซ็ตรหัสผ่านให้คุณ',
      variant: 'success'
    })
  } catch (error: any) {
    showAlert({
      title: 'ส่งคำร้องไม่สำเร็จ',
      message: error?.response?.data?.message || error?.message || 'กรุณาตรวจสอบเบอร์โทรศัพท์และลองใหม่อีกครั้ง',
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
      redirectToLineLogin(url)
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

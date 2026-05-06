<template>
  <MobileShell time="12:59">
    <BlueHeader title="เติมเงินเข้า G-Wallet" back-to="/checkout" :min-height="waitingDeposit ? '340px' : '100vh'">
      <h2 class="fs-5 fw-bold mt-4 mb-3">เลือกช่องทางการเติมเงิน</h2>
      <div class="topup-channels">
        <button
          v-for="channel in channels"
          :key="channel.value"
          class="topup-channel"
          type="button"
          :disabled="Boolean(waitingDeposit)"
          @click="openTopupModal(channel.value)"
        >
          <i class="bi" :class="channel.icon" />
          <span>{{ channel.label }}</span>
        </button>
      </div>

      <NuxtLink class="topup-history-button" to="/topup/history">
        <i class="bi bi-clock-history" />
        <span>ดูประวัติเติมเงิน</span>
        <i class="bi bi-chevron-right" />
      </NuxtLink>
    </BlueHeader>

    <div v-if="waitingDeposit" class="topup-waiting-card">
      <div class="topup-waiting-head">
        <div>
          <div class="topup-waiting-label">รายการเติมเงินที่ยังไม่เสร็จ</div>
          <h2>รายการ #{{ waitingDeposit.id || '-' }}</h2>
        </div>
        <span class="topup-waiting-status">{{ waitingStatusText }}</span>
      </div>

      <div class="topup-waiting-amount">
        <span>ยอดเติมเงิน</span>
        <strong>{{ formatMoney(toNumber(waitingDeposit.amount)) }} บาท</strong>
      </div>

      <div v-if="toNumber(waitingDeposit.bonus_amount) > 0" class="topup-waiting-bonus">
        โบนัส {{ formatMoney(toNumber(waitingDeposit.bonus_amount)) }} บาท
      </div>

      <div class="topup-waiting-date">
        <i class="bi bi-clock" />
        <span>{{ formatDate(waitingDeposit.transfer_at || waitingDeposit.created_at) }}</span>
      </div>

      <div v-if="isWaitingPaymentLoading" class="topup-waiting-loading">
        กำลังโหลดช่องทางชำระเงิน...
      </div>
      <div v-else-if="waitingQrCode" class="topup-waiting-payment">
        <h3>สแกน QR Code เพื่อชำระเงิน</h3>
        <img :src="waitingQrCode" alt="QR Code สำหรับชำระรายการเติมเงินค้างอยู่">
        <p>หลังชำระสำเร็จ ระบบจะเติมเงินเข้า G-Wallet อัตโนมัติ</p>
      </div>
      <div v-else class="topup-waiting-note">
        {{ waitingPaymentMessage || 'รายการนี้รอทีมงานตรวจสอบ' }}
      </div>

      <button class="topup-cancel-button" type="button" :disabled="isCancelingTopup" @click="cancelWaitingTopup">
        {{ isCancelingTopup ? 'กำลังยกเลิก...' : 'ยกเลิกรายการเติมเงินนี้' }}
      </button>
    </div>

    <div v-if="isModalOpen" class="topup-modal-backdrop" @click.self="closeTopupModal">
      <div class="topup-modal" role="dialog" aria-modal="true" :aria-label="modalTitle">
        <div class="topup-modal-head">
          <div class="topup-method-head">
            <i class="bi" :class="currentChannel.icon" />
            <div>
              <h2>{{ modalTitle }}</h2>
              <p>{{ modalDescription }}</p>
            </div>
          </div>
          <button class="topup-modal-close" type="button" aria-label="ปิด" @click="closeTopupModal">
            <i class="bi bi-x-lg" />
          </button>
        </div>

        <div class="topup-amount-panel">
          <label class="topup-label" for="topup-amount">จำนวนเงินที่ต้องการเติม</label>
          <div class="topup-amount-input">
            <input id="topup-amount" v-model.number="amount" type="number" min="1" inputmode="numeric" placeholder="0">
            <span>บาท</span>
          </div>
          <div class="topup-quick-grid">
            <button v-for="price in quickAmounts" :key="price" type="button" @click="amount = price">
              {{ formatMoney(price) }}
            </button>
          </div>
        </div>

        <div v-if="activeChannel === 'qr'" class="topup-method">
          <button class="primary-pill w-100" type="button" :disabled="isSubmitting" @click="createQrTopup">
            {{ isSubmitting ? 'กำลังสร้าง QR...' : 'สร้าง QR Code' }}
          </button>
        </div>

        <div v-else-if="activeChannel === 'credit'" class="topup-method">
          <button class="primary-pill w-100" type="button" :disabled="isSubmitting" @click="createCreditTopup">
            {{ isSubmitting ? 'กำลังเตรียมช่องทาง...' : 'เติมเงินผ่าน Credit Card' }}
          </button>
        </div>

        <form v-else class="topup-method" @submit.prevent="submitBankTransfer">
          <div v-if="bankInfo" class="topup-bank-box">
            <div class="muted-text">บัญชีรับโอน</div>
            <strong>{{ bankInfo.bank?.name || 'ธนาคาร' }}</strong>
            <div>{{ bankInfo.bank_deposit_name || '-' }}</div>
            <div class="topup-bank-number">{{ bankInfo.bank_deposit_number || '-' }}</div>
          </div>

          <label class="topup-label" for="transfer-at">วันเวลาที่โอน</label>
          <input id="transfer-at" v-model="transferAt" class="topup-control" type="datetime-local">

          <label class="topup-label" for="slip">สลิปโอนเงิน</label>
          <input id="slip" class="topup-control" type="file" accept="image/*" @change="handleSlipChange">

          <button class="primary-pill w-100" type="submit" :disabled="isSubmitting">
            {{ isSubmitting ? 'กำลังส่งสลิป...' : 'ยืนยันการชำระเงิน' }}
          </button>
        </form>

        <div v-if="qrCode" class="topup-qr-result">
          <h2>สแกนเพื่อชำระเงิน</h2>
          <img :src="qrCode" alt="QR Code สำหรับเติมเงิน">
          <p class="muted-text">เมื่อชำระสำเร็จ ระบบจะเติมเงินเข้า wallet ให้อัตโนมัติ</p>
        </div>
      </div>
    </div>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: true
})

type TopupChannel = 'qr' | 'credit' | 'bank_transfer'

import type { DepositHistory, WebsiteBank } from '~/composables/useTopup'

const axios = useAxios()
const { showAlert } = useAppAlert()
const { toNumber, formatMoney, formatDate } = useTopup()

const channels: Array<{ value: TopupChannel, label: string, icon: string }> = [
  { value: 'qr', label: 'QR Code', icon: 'bi-qr-code' },
  { value: 'credit', label: 'Credit Card', icon: 'bi-credit-card-2-front' },
  { value: 'bank_transfer', label: 'โอนธนาคาร', icon: 'bi-bank' }
]
const quickAmounts = [100, 300, 500, 1000, 2000, 5000]
const channelDescriptions: Record<TopupChannel, string> = {
  qr: 'สร้าง QR สำหรับเติมเงินเข้า wallet โดยตรง',
  credit: 'ขั้นต่ำ 400 บาท และเติมเข้า wallet หลังระบบชำระเงินยืนยัน',
  bank_transfer: 'โอนเข้าบัญชีบริษัทแล้วแนบสลิปเพื่อให้แอดมินตรวจสอบ'
}

const activeChannel = ref<TopupChannel>('qr')
const amount = ref<number | null>(500)
const waitingDeposit = ref<DepositHistory | null>(null)
const bankInfo = ref<WebsiteBank | null>(null)
const qrCode = ref('')
const waitingQrCode = ref('')
const waitingPaymentMessage = ref('')
const transferAt = ref('')
const slipFile = ref<File | null>(null)
const isSubmitting = ref(false)
const isModalOpen = ref(false)
const isWaitingPaymentLoading = ref(false)
const isCancelingTopup = ref(false)

const currentChannel = computed(() => (
  channels.find((channel) => channel.value === activeChannel.value) || channels[0]
))
const modalTitle = computed(() => currentChannel.value.label)
const modalDescription = computed(() => channelDescriptions[activeChannel.value])
const waitingStatusText = computed(() => {
  if (isWaitingPaymentLoading.value) {
    return 'กำลังโหลด'
  }

  return waitingQrCode.value ? 'รอชำระ' : 'รอตรวจสอบ'
})

const openTopupModal = (channel: TopupChannel) => {
  if (waitingDeposit.value) {
    showAlert({
      title: 'มีรายการเติมเงินค้างอยู่',
      message: 'กรุณาชำระหรือยกเลิกรายการเดิมก่อนสร้างรายการใหม่',
      variant: 'warning'
    })
    return
  }

  activeChannel.value = channel
  qrCode.value = ''
  isModalOpen.value = true
}

const closeTopupModal = (force = false) => {
  if (!force && isSubmitting.value) {
    return
  }

  isModalOpen.value = false
}

const setDefaultTransferAt = () => {
  const now = new Date()
  now.setMinutes(now.getMinutes() - now.getTimezoneOffset())
  transferAt.value = now.toISOString().slice(0, 16)
}

const validateAmount = (minimum = 1) => {
  const value = toNumber(amount.value)

  if (value < minimum) {
    showAlert({
      title: 'จำนวนเงินไม่ถูกต้อง',
      message: minimum > 1 ? `กรุณาระบุจำนวนเงินตั้งแต่ ${formatMoney(minimum)} บาทขึ้นไป` : 'กรุณาระบุจำนวนเงินที่ต้องการเติม',
      variant: 'warning'
    })
    return null
  }

  return value
}

const fetchTopupInfo = async () => {
  try {
    const response = await axios.get('/deposit')
    const result = response.data?.result || {}
    bankInfo.value = result.bank || null
    waitingDeposit.value = result.waiting || null
    waitingQrCode.value = ''
    waitingPaymentMessage.value = ''

    if (waitingDeposit.value?.id) {
      await fetchWaitingPayment(waitingDeposit.value.id)
    }
  } catch (error: any) {
    showAlert({
      title: 'โหลดข้อมูลเติมเงินไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  }
}

const fetchWaitingPayment = async (id: number | string) => {
  isWaitingPaymentLoading.value = true

  try {
    const response = await axios.get(`/deposit/${id}`)
    const result = response.data?.result || {}
    const payment = result.payment || {}

    waitingDeposit.value = result.deposit || waitingDeposit.value
    bankInfo.value = result.bank || bankInfo.value
    waitingQrCode.value = payment.qr_code || ''
    waitingPaymentMessage.value = payment.message || ''
  } catch (error: any) {
    waitingQrCode.value = ''
    waitingPaymentMessage.value = error?.response?.data?.message || 'โหลดช่องทางชำระเงินไม่สำเร็จ'
  } finally {
    isWaitingPaymentLoading.value = false
  }
}

const createQrTopup = async () => {
  const value = validateAmount()
  if (!value) {
    return
  }

  isSubmitting.value = true
  qrCode.value = ''

  try {
    const response = await axios.post('/deposit', {
      topup: 1,
      channel: 'qr',
      amount: value
    })

    qrCode.value = response.data?.qr_code || response.data?.result?.slip || ''
    waitingQrCode.value = response.data?.qr_code || ''
    waitingPaymentMessage.value = 'สแกน QR Code เพื่อชำระเงินรายการนี้'
    waitingDeposit.value = response.data?.result || null
    await fetchTopupInfo()
    closeTopupModal(true)
  } catch (error: any) {
    showAlert({
      title: 'สร้าง QR ไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}

const createCreditTopup = async () => {
  const value = validateAmount(400)
  if (!value) {
    return
  }

  isSubmitting.value = true
  qrCode.value = ''

  try {
    const response = await axios.post('/payments/credit', {
      topup: 1,
      amount: value
    })

    qrCode.value = response.data?.qr_code || response.data?.result?.qr_code || response.data?.result?.slip || ''
    waitingQrCode.value = response.data?.qr_code || response.data?.result?.qr_code || ''
    waitingPaymentMessage.value = 'สแกน QR Code เพื่อชำระเงินรายการนี้'
    waitingDeposit.value = response.data?.result || null
    await fetchTopupInfo()
    closeTopupModal(true)
  } catch (error: any) {
    showAlert({
      title: 'เติมเงินผ่านบัตรไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}

const handleSlipChange = (event: Event) => {
  const target = event.target as HTMLInputElement
  slipFile.value = target.files?.[0] || null
}

const submitBankTransfer = async () => {
  const value = validateAmount()
  if (!value) {
    return
  }

  if (!slipFile.value) {
    showAlert({
      title: 'ยังไม่ได้แนบสลิป',
      message: 'กรุณาแนบรูปสลิปก่อนส่งให้แอดมินตรวจสอบ',
      variant: 'warning'
    })
    return
  }

  const formData = new FormData()
  formData.append('topup', '1')
  formData.append('channel', 'bank_transfer')
  formData.append('amount', String(value))
  formData.append('transfer_at', transferAt.value)
  formData.append('slip', slipFile.value)

  isSubmitting.value = true
  qrCode.value = ''

  try {
    const response = await axios.post('/deposit', formData)
    waitingDeposit.value = response.data?.result || null
    slipFile.value = null
    showAlert({
      title: 'ส่งสลิปสำเร็จ',
      message: response.data?.message || 'กรุณารอแอดมินตรวจสอบสักครู่',
      variant: 'info'
    })
    await fetchTopupInfo()
    closeTopupModal(true)
  } catch (error: any) {
    showAlert({
      title: 'ส่งสลิปไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isSubmitting.value = false
  }
}

const cancelWaitingTopup = async () => {
  if (!waitingDeposit.value?.id || isCancelingTopup.value) {
    return
  }

  if (process.client && !window.confirm('ยืนยันยกเลิกรายการเติมเงินนี้?')) {
    return
  }

  isCancelingTopup.value = true

  try {
    const response = await axios.delete(`/deposit/${waitingDeposit.value.id}`)
    waitingDeposit.value = null
    waitingQrCode.value = ''
    waitingPaymentMessage.value = ''
    qrCode.value = ''
    showAlert({
      title: 'ยกเลิกรายการสำเร็จ',
      message: response.data?.message || 'สามารถสร้างรายการเติมเงินใหม่ได้แล้ว',
      variant: 'info'
    })
    await fetchTopupInfo()
  } catch (error: any) {
    showAlert({
      title: 'ยกเลิกรายการไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isCancelingTopup.value = false
  }
}

watch(activeChannel, () => {
  qrCode.value = ''
})

onMounted(() => {
  setDefaultTransferAt()
  fetchTopupInfo()
})
</script>

<style scoped>
.topup-channels {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.topup-channel {
  min-height: 104px;
  border: 1px solid rgba(255, 255, 255, .25);
  border-radius: 12px;
  background: #fff;
  color: #17335f;
  font-weight: 700;
  display: grid;
  place-items: center;
  gap: 8px;
  padding: 12px 8px;
}

.topup-channel i {
  font-size: 28px;
  color: #0b69dc;
}

.topup-channel:disabled {
  opacity: .55;
  cursor: not-allowed;
}

.topup-history-button {
  width: 100%;
  min-height: 58px;
  margin-top: 14px;
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 12px;
  padding: 0 16px;
  border-radius: 14px;
  background: #fff;
  color: #17335f;
  font-weight: 800;
  box-shadow: 0 10px 24px rgba(22, 46, 82, .14);
  text-decoration: none;
}

.topup-amount-panel {
  padding: 14px;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  background: #fff;
}

.topup-label {
  display: block;
  font-weight: 700;
  color: #17335f;
  margin-bottom: 8px;
}

.topup-amount-input {
  display: grid;
  grid-template-columns: 1fr auto;
  align-items: center;
  border: 1px solid #dce4ef;
  border-radius: 12px;
  padding: 0 14px;
  background: #f8fbff;
}

.topup-amount-input input,
.topup-control {
  width: 100%;
  border: 0;
  background: transparent;
  min-height: 48px;
  font-size: 18px;
  font-weight: 700;
  color: #17335f;
}

.topup-control {
  border: 1px solid #dce4ef;
  border-radius: 12px;
  padding: 0 14px;
  margin-bottom: 14px;
  background: #f8fbff;
}

.topup-amount-input input:focus,
.topup-control:focus {
  outline: none;
}

.topup-quick-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  margin-top: 12px;
}

.topup-quick-grid button {
  border: 1px solid #cfe1f6;
  border-radius: 999px;
  min-height: 38px;
  color: #075ec9;
  background: #fff;
  font-weight: 700;
}

.topup-method-head {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  margin-bottom: 0;
}

.topup-method-head i {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  background: #eaf5ff;
  color: #0b69dc;
  font-size: 24px;
}

.topup-method-head h2,
.topup-qr-result h2 {
  font-size: 18px;
  font-weight: 800;
  margin: 0 0 4px;
  color: #17335f;
}

.topup-method-head p,
.topup-qr-result p {
  margin: 0;
  color: #64748b;
}

.topup-waiting-card {
  width: calc(100% - 32px);
  max-width: var(--content-max);
  display: grid;
  gap: 12px;
  margin: -32px auto 18px;
  padding: 16px;
  border: 1px solid #dbe7f5;
  border-radius: 16px;
  background: #fff;
  color: #17335f;
  box-shadow: 0 16px 34px rgba(22, 46, 82, .14);
}

.topup-waiting-head,
.topup-waiting-amount,
.topup-waiting-date {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  min-width: 0;
}

.topup-waiting-label {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

.topup-waiting-head h2 {
  margin: 2px 0 0;
  color: #17335f;
  font-size: 20px;
  font-weight: 900;
}

.topup-waiting-status {
  border-radius: 999px;
  padding: 6px 10px;
  color: #8b5b00;
  background: #fff1c7;
  font-size: 12px;
  font-weight: 900;
  white-space: nowrap;
}

.topup-waiting-amount {
  padding: 12px;
  border-radius: 12px;
  background: #f5f9ff;
}

.topup-waiting-amount span {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

.topup-waiting-amount strong {
  color: #075ec9;
  font-size: 28px;
  font-weight: 900;
  line-height: 1;
  white-space: nowrap;
}

.topup-waiting-bonus {
  width: fit-content;
  border-radius: 999px;
  padding: 6px 10px;
  color: #047857;
  background: #e6f8ef;
  font-size: 13px;
  font-weight: 800;
}

.topup-waiting-date {
  justify-content: flex-start;
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

.topup-waiting-date i {
  color: #0b69dc;
}

.topup-waiting-loading,
.topup-waiting-note {
  border-radius: 12px;
  padding: 12px;
  background: #f8fafc;
  color: #64748b;
  font-weight: 700;
  text-align: center;
}

.topup-waiting-payment {
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 14px;
  background: #fbfdff;
  text-align: center;
}

.topup-waiting-payment h3 {
  margin: 0;
  color: #17335f;
  font-size: 17px;
  font-weight: 900;
}

.topup-waiting-payment img {
  width: min(240px, 100%);
  aspect-ratio: 1;
  object-fit: contain;
  display: block;
  margin: 12px auto;
}

.topup-waiting-payment p {
  margin: 0;
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

.topup-cancel-button {
  min-height: 44px;
  border: 1px solid #fecaca;
  border-radius: 999px;
  color: #b42318;
  background: #fff5f5;
  font-weight: 900;
}

.topup-cancel-button:disabled {
  color: #9aa5b1;
  background: #f1f5f9;
  border-color: #d8e0ea;
  cursor: not-allowed;
}

.topup-modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 1100;
  display: grid;
  place-items: end center;
  padding: 18px;
  background: rgba(9, 24, 45, .55);
}

.topup-modal {
  width: min(100%, 430px);
  max-height: min(86vh, 720px);
  overflow: auto;
  border-radius: 18px;
  background: #f8fbff;
  box-shadow: 0 24px 70px rgba(0, 0, 0, .28);
  padding: 16px;
}

.topup-modal-head {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 12px;
  align-items: flex-start;
  margin-bottom: 14px;
}

.topup-modal-close {
  width: 40px;
  height: 40px;
  border: 0;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #17335f;
  background: #fff;
  box-shadow: 0 6px 14px rgba(22, 46, 82, .12);
}

.topup-modal .topup-method {
  margin-top: 14px;
}

.topup-modal .topup-qr-result {
  margin-top: 14px;
  box-shadow: none;
  border: 1px solid #e2e8f0;
}

.topup-bank-box {
  border: 1px solid #dce4ef;
  border-radius: 12px;
  padding: 14px;
  margin-bottom: 14px;
  background: #f8fbff;
}

.topup-bank-number {
  font-size: 22px;
  font-weight: 800;
  color: #075ec9;
}

.topup-qr-result {
  text-align: center;
}

.topup-qr-result img {
  width: min(260px, 100%);
  aspect-ratio: 1;
  object-fit: contain;
  margin: 12px auto;
  display: block;
}

</style>

<template>
  <MobileShell time="12:59">
    <BlueHeader title="เติมเงินเข้า G-Wallet" :back-to="topupBackTo" :min-height="waitingDeposit ? '340px' : '100vh'">
      <h2 class="fs-5 fw-bold mt-4 mb-3">เลือกช่องทางการเติมเงิน</h2>
      <div class="topup-channels">
        <button
          v-for="channel in displayChannels"
          :key="channel.value"
          class="topup-channel"
          :class="{ 'is-unavailable': !channel.enabled }"
          type="button"
          :disabled="hasBlockingWaitingTopup || !channel.enabled"
          @click="openTopupModal(channel.value)"
        >
          <i class="bi" :class="channel.icon" />
          <span>{{ channel.label }}</span>
          <span v-if="!channel.enabled" class="topup-channel-badge">ปิดบริการชั่วคราว</span>
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
        <span class="topup-waiting-status" :class="waitingStatusClass">{{ waitingStatusText }}</span>
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
      <div v-else-if="isWaitingTopupTerminal" class="topup-waiting-note" :class="waitingTerminalClass">
        {{ waitingTerminalMessage }}
      </div>
      <div v-else-if="waitingQrCode" class="topup-waiting-payment">
        <h3>สแกน QR Code เพื่อชำระเงิน</h3>
        <img :src="waitingQrCode" alt="QR Code สำหรับชำระรายการเติมเงินค้างอยู่">
        <p>หลังชำระแล้วสามารถแนบสลิปเพื่อให้ร้านค้าตรวจสอบได้</p>
      </div>
      <div v-else class="topup-waiting-note">
        {{ waitingPaymentMessage || 'รายการนี้รอทีมงานตรวจสอบ' }}
      </div>

      <div v-if="!isWaitingTopupTerminal && waitingNeedsSlip" class="topup-waiting-slip">
        <div class="topup-waiting-slip-head">
          <div>
            <h3>สลิปชำระเงิน</h3>
            <p>{{ waitingHasSlip ? 'ได้รับสลิปแล้ว สามารถอัพโหลดใหม่ได้หากต้องแก้ไข' : 'อัพโหลดสลิปหลังจากชำระเงินรายการนี้' }}</p>
          </div>
          <span :class="{ 'is-ready': waitingHasSlip }">{{ waitingHasSlip ? 'ส่งแล้ว' : 'รอสลิป' }}</span>
        </div>
        <input :key="waitingSlipInputKey" class="topup-control" type="file" accept="image/*" @change="handleWaitingSlipChange">
        <button class="primary-pill w-100" type="button" :disabled="!waitingSlipFile || isUploadingWaitingSlip" @click="uploadWaitingSlip">
          {{ isUploadingWaitingSlip ? 'กำลังอัพโหลด...' : waitingHasSlip ? 'อัพโหลดสลิปใหม่' : 'อัพโหลดสลิป' }}
        </button>
      </div>

      <button v-if="!isWaitingTopupTerminal" class="topup-cancel-button" type="button" :disabled="isCancelingTopup" @click="openCancelTopupConfirm">
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
          <div class="topup-deferred-slip-note">
            <i class="bi bi-info-circle" />
            <span>สร้าง QR Code แล้วแนบสลิปหลังชำระเงินเพื่อให้ร้านค้าตรวจสอบ</span>
          </div>
          <button class="primary-pill w-100" type="button" :disabled="isSubmitting" @click="createQrTopup">
            {{ isSubmitting ? 'กำลังสร้าง QR...' : 'สร้าง QR Code' }}
          </button>
        </div>

        <div v-else-if="activeChannel === 'credit'" class="topup-method">
          <div class="topup-deferred-slip-note">
            <i class="bi bi-info-circle" />
            <span>ช่องทางนี้จะแสดงเป็น QR Code และแนบสลิปหลังชำระเงินได้</span>
          </div>
          <button class="primary-pill w-100" type="button" :disabled="isSubmitting" @click="createCreditTopup">
            {{ isSubmitting ? 'กำลังสร้าง QR...' : 'สร้าง QR Code' }}
          </button>
        </div>

        <form v-else class="topup-method" @submit.prevent="submitBankTransfer">
          <div v-if="bankInfo" class="topup-bank-box">
            <div class="muted-text">บัญชีรับโอน</div>
            <div class="topup-bank-name">
              <i class="bi" :class="bankInfo.bank?.icon || bankInfo.bank_icon || 'bi-bank'" />
              <strong>{{ bankInfo.bank?.name || bankInfo.bank_name || 'ธนาคาร' }}</strong>
            </div>
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
          <p class="muted-text">หลังชำระเงินแล้วแนบสลิปในรายการเติมเงินค้างอยู่</p>
        </div>
      </div>
    </div>

    <div v-if="showCancelConfirm" class="topup-confirm-backdrop" @click.self="closeCancelTopupConfirm">
      <section class="topup-confirm-modal" role="dialog" aria-modal="true" aria-labelledby="topup-cancel-title">
        <div class="topup-confirm-icon">
          <i class="bi bi-exclamation-triangle" />
        </div>
        <h2 id="topup-cancel-title">ยกเลิกรายการเติมเงินนี้?</h2>
        <p>
          รายการ #{{ waitingDeposit?.id || '-' }} จะถูกยกเลิก และคุณสามารถสร้างรายการเติมเงินใหม่ได้ทันที
        </p>
        <div class="topup-confirm-amount">
          <span>ยอดเติมเงิน</span>
          <strong>{{ formatMoney(toNumber(waitingDeposit?.amount)) }} บาท</strong>
        </div>
        <div class="topup-confirm-actions">
          <button class="topup-confirm-secondary" type="button" :disabled="isCancelingTopup" @click="closeCancelTopupConfirm">
            ไม่ยกเลิก
          </button>
          <button class="topup-confirm-danger" type="button" :disabled="isCancelingTopup" @click="cancelWaitingTopup">
            {{ isCancelingTopup ? 'กำลังยกเลิก...' : 'ยืนยันยกเลิก' }}
          </button>
        </div>
      </section>
    </div>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: true
})

type TopupChannel = 'qr' | 'credit' | 'bank_transfer'
type TopupChannelConfig = { value: TopupChannel, label: string, icon: string }
type TopupDisplayChannel = TopupChannelConfig & { enabled: boolean }

import type { DepositHistory, WebsiteBank } from '~/composables/useTopup'

const platformApi = usePlatformApi()
const route = useRoute()
const { showAlert } = useAppAlert()
const { toNumber, formatMoney, formatDate } = useTopup()
const { isAuthenticated } = useAuth()
const { config: siteConfig, fetchSiteConfig } = useSiteConfig()

const baseChannels: TopupChannelConfig[] = [
  { value: 'qr', label: 'QR Code', icon: 'bi-qr-code' },
  { value: 'credit', label: 'Credit Card QR', icon: 'bi-qr-code-scan' },
  { value: 'bank_transfer', label: 'โอนธนาคาร', icon: 'bi-bank' }
]
const quickAmounts = [100, 300, 500, 1000, 2000, 5000]
const channelDescriptions: Record<TopupChannel, string> = {
  qr: 'สร้าง QR สำหรับเติมเงินเข้า wallet โดยตรง',
  credit: 'ขั้นต่ำ 400 บาท ระบบจะสร้าง QR Code จากผู้ให้บริการภายนอก',
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
const waitingSlipFile = ref<File | null>(null)
const waitingSlipInputKey = ref(0)
const isSubmitting = ref(false)
const isModalOpen = ref(false)
const isWaitingPaymentLoading = ref(false)
const isCancelingTopup = ref(false)
const isUploadingWaitingSlip = ref(false)
const showCancelConfirm = ref(false)

const topupChannelMethod = (channel: TopupChannel) => channel === 'credit' ? 'credit_card' : channel
const paymentMethodEnabled = (method: string) => {
  const payment = siteConfig.value?.payment || {}
  const methods = Array.isArray(payment.methods) ? payment.methods : []

  if (methods.length > 0) {
    const matched = methods.find((item) => String(item?.key || '') === method)

    return matched ? matched.enabled !== false : true
  }

  const enabledMethods = Array.isArray(payment.enabled_methods) ? payment.enabled_methods : []

  return enabledMethods.length > 0 ? enabledMethods.includes(method) : true
}
const displayChannels = computed<TopupDisplayChannel[]>(() => baseChannels.map((channel) => ({
  ...channel,
  enabled: paymentMethodEnabled(topupChannelMethod(channel.value))
})))
const enabledChannels = computed(() => displayChannels.value.filter((channel) => channel.enabled))
const currentChannel = computed(() => (
  displayChannels.value.find((channel) => channel.value === activeChannel.value) || displayChannels.value[0] || baseChannels[0]
))
const modalTitle = computed(() => currentChannel.value.label)
const modalDescription = computed(() => channelDescriptions[activeChannel.value])
const waitingStatusRaw = computed(() => topupStatusRaw(waitingDeposit.value))
const isWaitingTopupTerminal = computed(() => isTerminalTopupStatus(waitingDeposit.value))
const hasBlockingWaitingTopup = computed(() => Boolean(waitingDeposit.value && !isWaitingTopupTerminal.value))
const waitingStatusText = computed(() => {
  if (waitingStatusRaw.value === 'approved') {
    return 'อนุมัติแล้ว'
  }

  if (waitingStatusRaw.value === 'rejected') {
    return 'ไม่อนุมัติ'
  }

  if (waitingStatusRaw.value === 'cancelled') {
    return 'ยกเลิกแล้ว'
  }

  if (waitingStatusRaw.value === 'expired') {
    return 'หมดอายุ'
  }

  if (isWaitingPaymentLoading.value) {
    return 'กำลังโหลด'
  }

  if (waitingStatusRaw.value === 'pending_review') {
    return 'รอตรวจสอบ'
  }

  return waitingQrCode.value || waitingStatusRaw.value === 'pending_payment' ? 'รอชำระ' : 'รอตรวจสอบ'
})
const waitingStatusClass = computed(() => ({
  'is-success': waitingStatusRaw.value === 'approved',
  'is-danger': waitingStatusRaw.value === 'rejected',
  'is-muted': ['cancelled', 'expired'].includes(waitingStatusRaw.value),
  'is-payment': waitingStatusRaw.value === 'pending_payment',
}))
const waitingTerminalClass = computed(() => ({
  'is-success': waitingStatusRaw.value === 'approved',
  'is-danger': waitingStatusRaw.value === 'rejected',
  'is-muted': ['cancelled', 'expired'].includes(waitingStatusRaw.value),
}))
const waitingTerminalMessage = computed(() => {
  if (waitingStatusRaw.value === 'approved') {
    return 'รายการนี้อนุมัติแล้ว ยอดเงินถูกเติมเข้า wallet เรียบร้อย'
  }

  if (waitingStatusRaw.value === 'rejected') {
    return 'รายการนี้ไม่ผ่านการตรวจสอบ กรุณาสร้างรายการใหม่หรือติดต่อทีมงาน'
  }

  if (waitingStatusRaw.value === 'cancelled') {
    return 'รายการนี้ถูกยกเลิกแล้ว สามารถสร้างรายการเติมเงินใหม่ได้'
  }

  if (waitingStatusRaw.value === 'expired') {
    return 'รายการนี้หมดอายุแล้ว กรุณาสร้างรายการเติมเงินใหม่'
  }

  return 'สถานะรายการเติมเงินถูกอัปเดตแล้ว'
})
const waitingHasSlip = computed(() => Boolean(
  waitingDeposit.value?.slip_url
  || waitingDeposit.value?.slip_thumb_url
  || waitingDeposit.value?.slip
))
const waitingNeedsSlip = computed(() => {
  const channel = String(waitingDeposit.value?.channel || '').toLowerCase()
  const provider = String(waitingDeposit.value?.provider || '').toLowerCase()

  return ['bank_transfer', 'qr', 'credit_card'].includes(channel) || provider === 'manual'
})
const topupBackTo = computed(() => {
  const value = Array.isArray(route.query.back) ? route.query.back[0] : route.query.back
  const target = String(value || '').trim()

  return ['/', '/checkout', '/my-wallet', '/profile'].includes(target) ? target : '/my-wallet'
})

useCustomerStockRealtime({
  enabled: isAuthenticated,
  onTopup: (payload) => applyRealtimeTopupUpdate(payload),
  includePresence: true,
})

const openTopupModal = (channel: TopupChannel) => {
  if (!paymentMethodEnabled(topupChannelMethod(channel))) {
    showAlert({
      title: 'ช่องทางนี้ยังไม่เปิดให้ใช้งาน',
      message: 'กรุณาเลือกช่องทางอื่นหรือติดต่อร้านค้า',
      variant: 'warning'
    })
    return
  }

  if (hasBlockingWaitingTopup.value) {
    showAlert({
      title: 'มีรายการเติมเงินค้างอยู่',
      message: 'กรุณาชำระหรือยกเลิกรายการเดิมก่อนสร้างรายการใหม่',
      variant: 'warning'
    })
    return
  }

  activeChannel.value = channel
  qrCode.value = ''
  slipFile.value = null
  isModalOpen.value = true
}

const closeTopupModal = (force = false) => {
  if (!force && isSubmitting.value) {
    return
  }

  isModalOpen.value = false
  slipFile.value = null
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

const buildTopupPayload = (channel: TopupChannel, value: number, transferAtValue = '') => {
  if (!slipFile.value) {
    return {
      channel,
      amount: value,
      ...(transferAtValue ? { transfer_at: transferAtValue } : {})
    }
  }

  const formData = new FormData()
  formData.append('channel', channel)
  formData.append('amount', String(value))

  if (transferAtValue) {
    formData.append('transfer_at', transferAtValue)
  }

  formData.append('slip', slipFile.value)

  return formData
}

const fetchTopupInfo = async () => {
  try {
    const result = await platformApi.topupOverviewLegacy()
    bankInfo.value = result.bank || null
    waitingDeposit.value = result.waiting || null
    waitingQrCode.value = ''
    waitingPaymentMessage.value = ''
    waitingSlipFile.value = null
    waitingSlipInputKey.value += 1

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
    const result = await platformApi.topupDetailLegacy(id)
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
    const response = await platformApi.createTopupLegacy(buildTopupPayload('qr', value))

    qrCode.value = response.qr_code || response.result?.slip || ''
    waitingQrCode.value = response.qr_code || ''
    waitingPaymentMessage.value = 'สแกน QR Code เพื่อชำระเงินรายการนี้'
    waitingDeposit.value = response.result || null
    slipFile.value = null
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
    const response = await platformApi.createCreditTopupLegacy(
      value
    )

    qrCode.value = response.qr_code || response.result?.qr_code || response.result?.slip || ''
    waitingQrCode.value = response.qr_code || response.result?.qr_code || ''
    waitingPaymentMessage.value = 'สแกน QR Code เพื่อชำระเงินรายการนี้'
    waitingDeposit.value = response.result || null
    slipFile.value = null
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

const handleWaitingSlipChange = (event: Event) => {
  const target = event.target as HTMLInputElement
  waitingSlipFile.value = target.files?.[0] || null
}

const uploadWaitingSlip = async () => {
  if (!waitingDeposit.value?.id || !waitingSlipFile.value || isUploadingWaitingSlip.value) {
    return
  }

  const formData = new FormData()
  formData.append('slip', waitingSlipFile.value)

  if (transferAt.value) {
    formData.append('transfer_at', transferAt.value)
  }

  isUploadingWaitingSlip.value = true

  try {
    const response = await platformApi.uploadTopupSlipLegacy(waitingDeposit.value.id, formData)
    waitingDeposit.value = response.result || response.deposit || waitingDeposit.value
    waitingSlipFile.value = null
    waitingSlipInputKey.value += 1
    showAlert({
      title: 'อัพโหลดสลิปสำเร็จ',
      message: 'ระบบส่งสลิปให้ตรวจสอบแล้ว',
      variant: 'info'
    })
    await fetchTopupInfo()
  } catch (error: any) {
    showAlert({
      title: 'อัพโหลดสลิปไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isUploadingWaitingSlip.value = false
  }
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

  isSubmitting.value = true
  qrCode.value = ''

  try {
    const response = await platformApi.createTopupLegacy(buildTopupPayload('bank_transfer', value, transferAt.value))
    waitingDeposit.value = response.result || null
    slipFile.value = null
    showAlert({
      title: 'ส่งสลิปสำเร็จ',
      message: 'กรุณารอแอดมินตรวจสอบสักครู่',
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

const openCancelTopupConfirm = () => {
  if (!waitingDeposit.value?.id || isCancelingTopup.value) {
    return
  }

  showCancelConfirm.value = true
}

const closeCancelTopupConfirm = () => {
  if (isCancelingTopup.value) {
    return
  }

  showCancelConfirm.value = false
}

const cancelWaitingTopup = async () => {
  if (!waitingDeposit.value?.id || isCancelingTopup.value) {
    return
  }

  isCancelingTopup.value = true

  try {
    const response = await platformApi.cancelTopupLegacy(waitingDeposit.value.id)
    waitingDeposit.value = null
    waitingQrCode.value = ''
    waitingPaymentMessage.value = ''
    waitingSlipFile.value = null
    waitingSlipInputKey.value += 1
    qrCode.value = ''
    showCancelConfirm.value = false
    showAlert({
      title: 'ยกเลิกรายการสำเร็จ',
      message: response.message || 'สามารถสร้างรายการเติมเงินใหม่ได้แล้ว',
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

const topupStatusRaw = (topup?: DepositHistory | null) => (
  String(topup?.presentation_status || topup?.status_raw || '').toLowerCase()
)

const isTerminalTopupStatus = (topup?: DepositHistory | null) => (
  ['approved', 'rejected', 'cancelled', 'expired'].includes(topupStatusRaw(topup))
)

const applyRealtimeTopupUpdate = (payload: any) => {
  const payloadTopup = payload?.topup || payload?.data || payload
  const topupId = String(payload?.topup_id || payloadTopup?.id || '').trim()
  const waitingId = String(waitingDeposit.value?.id || '').trim()

  if (!topupId || !waitingId || topupId !== waitingId) {
    return
  }

  const normalizedTopup = platformApi.normalizeTopupLegacy(payloadTopup) as DepositHistory | null

  if (!normalizedTopup) {
    return
  }

  waitingDeposit.value = {
    ...waitingDeposit.value,
    ...normalizedTopup,
  }
  waitingQrCode.value = normalizedTopup.qr_code || waitingQrCode.value
  waitingPaymentMessage.value = normalizedTopup.message || waitingPaymentMessage.value

  if (isTerminalTopupStatus(normalizedTopup)) {
    qrCode.value = ''
    waitingSlipFile.value = null
    waitingSlipInputKey.value += 1
    showCancelConfirm.value = false
  }
}

watch(activeChannel, () => {
  qrCode.value = ''
  slipFile.value = null
})

watch(enabledChannels, (availableChannels) => {
  if (availableChannels.length > 0 && !availableChannels.some((channel) => channel.value === activeChannel.value)) {
    activeChannel.value = availableChannels[0].value
  }
}, { immediate: true })

onMounted(async () => {
  setDefaultTransferAt()
  await fetchSiteConfig({ force: true }).catch(() => null)
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
  position: relative;
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

.topup-channel.is-unavailable {
  border-color: rgba(148, 163, 184, .38);
  background: #eef2f7;
  color: #64748b;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, .55);
}

.topup-channel i {
  font-size: 28px;
  color: #0b69dc;
}

.topup-channel.is-unavailable i {
  color: #94a3b8;
}

.topup-channel-badge {
  border-radius: 999px;
  background: #e2e8f0;
  color: #475569;
  font-size: 10px;
  font-weight: 900;
  line-height: 1.1;
  padding: 5px 8px;
  white-space: nowrap;
}

.topup-channel:disabled {
  cursor: not-allowed;
}

.topup-channel:disabled:not(.is-unavailable) {
  opacity: .62;
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
  position: relative;
  z-index: 2;
  width: calc(100% - 32px);
  max-width: var(--content-max);
  display: grid;
  gap: 12px;
  margin: -14px auto 18px;
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

.topup-waiting-status.is-payment {
  color: #075ec9;
  background: #eaf5ff;
}

.topup-waiting-status.is-success {
  color: #047857;
  background: #e6f8ef;
}

.topup-waiting-status.is-danger {
  color: #b42318;
  background: #fff5f5;
}

.topup-waiting-status.is-muted {
  color: #475569;
  background: #eef2f7;
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

.topup-waiting-note.is-success {
  color: #047857;
  background: #e6f8ef;
}

.topup-waiting-note.is-danger {
  color: #b42318;
  background: #fff5f5;
}

.topup-waiting-note.is-muted {
  color: #475569;
  background: #eef2f7;
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

.topup-waiting-slip,
.topup-deferred-slip-note {
  border: 1px solid #dbe7f5;
  border-radius: 14px;
  padding: 14px;
  background: #f8fbff;
}

.topup-waiting-slip-head {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 12px;
  align-items: flex-start;
  margin-bottom: 12px;
}

.topup-waiting-slip-head h3 {
  margin: 0 0 2px;
  color: #17335f;
  font-size: 17px;
  font-weight: 900;
}

.topup-waiting-slip-head p {
  margin: 0;
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

.topup-waiting-slip-head span {
  border-radius: 999px;
  padding: 6px 10px;
  color: #8b5b00;
  background: #fff1c7;
  font-size: 12px;
  font-weight: 900;
  white-space: nowrap;
}

.topup-waiting-slip-head span.is-ready {
  color: #047857;
  background: #e6f8ef;
}

.topup-deferred-slip-note {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 10px;
  align-items: flex-start;
  margin-bottom: 14px;
  color: #3b5b84;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.45;
}

.topup-deferred-slip-note i {
  color: #0b69dc;
  font-size: 18px;
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

.topup-bank-name {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 2px;
  color: #17335f;
}

.topup-bank-name i {
  color: #0b69dc;
  font-size: 18px;
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

.topup-confirm-backdrop {
  position: fixed;
  inset: 0;
  z-index: 1120;
  display: grid;
  place-items: center;
  padding: 20px;
  background: rgba(4, 20, 43, .62);
  backdrop-filter: blur(3px);
}

.topup-confirm-modal {
  width: min(100%, 360px);
  padding: 28px 22px 22px;
  border-radius: 20px;
  border: 1px solid rgba(219, 231, 245, .9);
  background: #fff;
  box-shadow: 0 24px 70px rgba(5, 34, 77, .28);
  text-align: center;
  color: #17335f;
}

.topup-confirm-icon {
  width: 64px;
  height: 64px;
  display: grid;
  place-items: center;
  margin: 0 auto 14px;
  border-radius: 20px;
  color: #b42318;
  background: #fff5f5;
  font-size: 30px;
}

.topup-confirm-modal h2 {
  margin: 0;
  color: #17335f;
  font-size: 22px;
  font-weight: 900;
  line-height: 1.28;
}

.topup-confirm-modal p {
  margin: 10px 0 16px;
  color: #64748b;
  font-size: 14px;
  font-weight: 700;
  line-height: 1.55;
}

.topup-confirm-amount {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 18px;
  padding: 12px 14px;
  border-radius: 14px;
  background: #f5f9ff;
}

.topup-confirm-amount span {
  color: #64748b;
  font-size: 13px;
  font-weight: 800;
}

.topup-confirm-amount strong {
  color: #075ec9;
  font-size: 19px;
  font-weight: 900;
  white-space: nowrap;
}

.topup-confirm-actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.topup-confirm-actions button {
  min-height: 48px;
  border-radius: 999px;
  font-weight: 900;
}

.topup-confirm-secondary {
  border: 1px solid #cfe1f6;
  color: #075ec9;
  background: #fff;
}

.topup-confirm-danger {
  border: 0;
  color: #fff;
  background: linear-gradient(135deg, #ef4444 0%, #b42318 100%);
  box-shadow: 0 10px 22px rgba(180, 35, 24, .25);
}

.topup-confirm-actions button:disabled {
  opacity: .68;
  cursor: not-allowed;
}

</style>

<template>
  <MobileShell active-nav="menu">
    <div class="purchase-receipt-bg">
      <button class="purchase-receipt-back mt-4" type="button" aria-label="กลับ" @click="goBack">
        <i class="bi bi-chevron-left" />
      </button>

      <section class="purchase-receipt-card mt-5">
        <div class="purchase-receipt-brand">
          <BrandLogo />
          <span class="purchase-receipt-divider" />
          <span class="lottery-six purchase-receipt-l6">L6</span>
        </div>

        <div class="purchase-receipt-intro">
          <h1>รายการซื้อสลากหกหลักแบบดิจิทัล</h1>
          <p>คุณสามารถดูสลากฯ ได้ที่เมนู ‘สลากฯ ของฉัน’</p>
        </div>

        <div v-if="isLoading" class="purchase-receipt-state muted-text">
          กำลังโหลดรายการ...
        </div>

        <div v-else-if="loadError" class="purchase-receipt-state">
          <strong>{{ loadError }}</strong>
          <button class="outline-pill purchase-receipt-retry" type="button" @click="fetchReceipt">
            ลองใหม่
          </button>
        </div>

        <div v-else class="purchase-receipt-content">
          <dl class="purchase-receipt-lines">
            <div>
              <dt>จำนวนสลากฯ</dt>
              <dd class="text-primary">{{ ticketCount }} ใบ</dd>
            </div>
            <div>
              <dt>สลากฯ งวดวันที่</dt>
              <dd class="text-primary">{{ drawDate }}</dd>
            </div>
          </dl>

          <hr>

          <dl class="purchase-receipt-lines">
            <div>
              <dt>ชำระเงินให้</dt>
              <dd>{{ payeeName }}</dd>
            </div>
            <div>
              <dt>ช่องทางชำระเงิน</dt>
              <dd>
                <span>{{ paymentChannel }}</span>
                <small v-if="paymentReference">{{ paymentReference }}</small>
              </dd>
            </div>
          </dl>

          <hr>

          <div class="purchase-receipt-total">
            <span>ยอดชำระทั้งหมด</span>
            <strong>{{ formatMoney(totalAmount) }} <small>บาท</small></strong>
          </div>

          <div class="purchase-receipt-meta">
            <div>วันที่ทำรายการ {{ paidAtText }}</div>
            <div>รหัสอ้างอิง {{ referenceCode }}</div>
          </div>
        </div>
      </section>

      <button class="purchase-receipt-save" type="button" @click="saveReceipt">
        <i class="bi bi-download" />
        <span>บันทึก</span>
      </button>
    </div>
  </MobileShell>
</template>

<script setup lang="ts">
import { formatDrawDateText } from '~/utils/formatDrawDate'

definePageMeta({
  requiresAuth: true
})

type PurchaseReceipt = Record<string, any>

const route = useRoute()
const platformApi = usePlatformApi()
const receipt = ref<PurchaseReceipt | null>(null)
const isLoading = ref(false)
const loadError = ref('')

const order = computed(() => receipt.value?.order || null)

const toNumber = (value: unknown, fallback = 0) => {
  const number = Number(value)

  return Number.isFinite(number) ? number : fallback
}

const formatMoney = (value: number) => new Intl.NumberFormat('th-TH', {
  minimumFractionDigits: value % 1 === 0 ? 0 : 2,
  maximumFractionDigits: 2
}).format(value)

const formatDateTime = (value: unknown) => {
  if (!value) {
    return '-'
  }

  const date = new Date(String(value))

  if (Number.isNaN(date.getTime())) {
    return '-'
  }

  return new Intl.DateTimeFormat('th-TH', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
    timeZone: 'Asia/Bangkok'
  }).format(date).replace(',', '')
}

const maskReference = (value: unknown) => {
  const raw = String(value || '').replace(/\s+/g, '')

  if (!raw) {
    return ''
  }

  const digits = raw.replace(/\D/g, '')
  const source = digits || raw

  if (source.length <= 4) {
    return source
  }

  return `${source.slice(0, 3)} ${'X'.repeat(Math.max(6, source.length - 7))} ${source.slice(-4)}`
}

const ticketCount = computed(() => toNumber(receipt.value?.count || order.value?.ticket_count || order.value?.lotteries?.length))
const drawDate = computed(() => {
  const formatted = formatDrawDateText(
    receipt.value?.game?.draw_at ||
    receipt.value?.game?.name ||
    order.value?.game?.draw_at ||
    order.value?.game?.name ||
    order.value?.lotteries?.[0]?.game?.draw_at ||
    order.value?.lotteries?.[0]?.game?.name ||
    ''
  )

  return formatted === '-' ? '-' : formatted
})
const payeeName = computed(() => order.value?.store?.name || 'ร้านค้าสลากฯ')
const paymentChannel = computed(() => {
  const method = String(order.value?.payment_method || '')

  if (method === 'wallet') {
    return order.value?.wallet?.name || 'G Wallet'
  }

  return order.value?.payment?.provider || order.value?.wallet?.name || 'G Wallet'
})
const paymentReference = computed(() => maskReference(order.value?.wallet?.id || order.value?.payment?.provider_reference || order.value?.reference))
const totalAmount = computed(() => toNumber(receipt.value?.total || order.value?.total || order.value?.amount))
const paidAtText = computed(() => formatDateTime(receipt.value?.paid_at || order.value?.paid_at || order.value?.updated_at || order.value?.created_at))
const referenceCode = computed(() => receipt.value?.reference || order.value?.reference || (order.value?.id ? `ORDER-${order.value.id}` : '-'))

const fetchReceipt = async () => {
  isLoading.value = true
  loadError.value = ''

  try {
    receipt.value = await platformApi.orderReceiptLegacy(String(route.params.order_id || ''))
  } catch (error: any) {
    loadError.value = error?.response?.data?.message || 'โหลดรายละเอียดรายการไม่สำเร็จ'
  } finally {
    isLoading.value = false
  }
}

const goBack = () => {
  navigateTo('/purchase-history')
}

const saveReceipt = () => {
  if (process.client) {
    window.print()
  }
}

useTenantSeo({
  title: 'รายละเอียดการซื้อสลากฯ',
  canonicalPath: '/purchase-history',
  privatePage: true
})

onMounted(fetchReceipt)
</script>

<style scoped>
.purchase-receipt-bg {
  position: relative;
  min-height: 100%;
  padding: 88px 20px 44px;
  overflow: hidden;
  background:
    radial-gradient(circle at 66% 78%, rgba(0, 91, 198, .5) 0 136px, transparent 138px),
    radial-gradient(circle at 100% 96%, rgba(255, 209, 11, .98) 0 124px, transparent 126px),
    linear-gradient(145deg, #087ff0 0%, #22bff3 100%);
}

.purchase-receipt-bg::before,
.purchase-receipt-bg::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(145deg, transparent 23%, rgba(255, 255, 255, .12) 23.3%, transparent 52%);
  pointer-events: none;
}

.purchase-receipt-bg::after {
  transform: translateX(58px) scaleY(1.25);
  opacity: .45;
}

.purchase-receipt-back,
.purchase-receipt-card,
.purchase-receipt-save {
  position: relative;
  z-index: 1;
}

.purchase-receipt-back {
  position: absolute;
  top: 34px;
  left: 18px;
  display: grid;
  width: 44px;
  height: 44px;
  place-items: center;
  border: 0;
  background: transparent;
  color: #fff;
  font-size: 34px;
}

.purchase-receipt-card {
  width: 100%;
  max-width: var(--content-max);
  margin: 0 auto;
  padding: 28px 22px 24px;
  border-radius: 8px;
  background:
    repeating-linear-gradient(150deg, rgba(5, 130, 226, .042) 0 28px, transparent 28px 66px),
    #fff;
  box-shadow: 0 18px 44px rgba(0, 52, 128, .16);
}

.purchase-receipt-brand {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 18px;
  margin-bottom: 26px;
}

.purchase-receipt-brand :deep(.brand-logo-image) {
  height: 42px;
  max-width: 150px;
}

.purchase-receipt-divider {
  width: 1px;
  height: 38px;
  background: #d7dee8;
}

.purchase-receipt-l6 {
  font-size: 36px;
}

.purchase-receipt-intro {
  margin-bottom: 26px;
  text-align: center;
}

.purchase-receipt-intro h1 {
  margin: 0 0 12px;
  color: var(--app-ink);
  font-size: 24px;
  font-weight: 900;
  line-height: 1.35;
}

.purchase-receipt-intro p {
  margin: 0;
  color: #575f69;
  font-size: 18px;
  font-weight: 700;
  line-height: 1.45;
}

.purchase-receipt-state {
  display: grid;
  justify-items: center;
  gap: 14px;
  padding: 34px 0 18px;
  color: #d14343;
  text-align: center;
}

.purchase-receipt-retry {
  min-height: 42px;
  padding: 0 22px;
}

.purchase-receipt-lines {
  display: grid;
  gap: 18px;
  margin: 0;
}

.purchase-receipt-lines div {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1.1fr);
  gap: 16px;
  align-items: start;
}

.purchase-receipt-lines dt {
  color: #737b85;
  font-size: 18px;
  font-weight: 800;
  line-height: 1.35;
}

.purchase-receipt-lines dd {
  display: grid;
  justify-items: end;
  gap: 4px;
  margin: 0;
  color: #22282f;
  font-size: 18px;
  font-weight: 900;
  line-height: 1.35;
  text-align: right;
}

.purchase-receipt-lines small {
  color: #22282f;
  font-size: 17px;
  font-weight: 700;
}

.purchase-receipt-content hr {
  margin: 24px 0;
  border: 0;
  border-top: 1px solid #e5ebf2;
  opacity: 1;
}

.purchase-receipt-total {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 22px;
}

.purchase-receipt-total span {
  color: #737b85;
  font-size: 18px;
  font-weight: 800;
}

.purchase-receipt-total strong {
  color: #22282f;
  font-size: 31px;
  font-weight: 900;
  line-height: 1;
  white-space: nowrap;
}

.purchase-receipt-total small {
  font-size: 18px;
  font-weight: 700;
}

.purchase-receipt-meta {
  display: grid;
  gap: 7px;
  color: #626b76;
  font-size: 17px;
  font-weight: 700;
  line-height: 1.35;
  text-align: center;
  word-break: break-word;
}

.purchase-receipt-save {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  min-width: 174px;
  min-height: 72px;
  margin: 26px auto 0;
  padding: 0 34px;
  border: 0;
  border-radius: 999px;
  background: #fff;
  color: #086bd5;
  box-shadow: 0 14px 34px rgba(0, 62, 133, .16);
  font-size: 21px;
  font-weight: 900;
}

.purchase-receipt-save i {
  font-size: 29px;
}

@media (max-width: 360px) {
  .purchase-receipt-bg {
    padding-right: 12px;
    padding-left: 12px;
  }

  .purchase-receipt-card {
    padding-right: 16px;
    padding-left: 16px;
  }

  .purchase-receipt-intro h1 {
    font-size: 21px;
  }

  .purchase-receipt-intro p,
  .purchase-receipt-lines dt,
  .purchase-receipt-lines dd,
  .purchase-receipt-total span,
  .purchase-receipt-meta {
    font-size: 15px;
  }

  .purchase-receipt-total strong {
    font-size: 26px;
  }
}
</style>

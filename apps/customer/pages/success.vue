<template>
  <MobileShell time="13:04" active-nav="tickets" show-bottom-nav>
    <div class="success-bg">
      <section class="receipt-card">
        <div class="text-center border-bottom pb-3 mb-3">
          <div class="d-flex align-items-center justify-content-center gap-3 mb-3">
            <BrandLogo />
            <span class="vr" />
            <span class="lottery-six fs-2">L6</span>
          </div>
          <div class="check-mark"><i class="bi bi-check-lg" /></div>
          <h1 class="fs-4 fw-bold">ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ</h1>
          <p class="muted-text mb-0">คุณสามารถดูสลากฯ ได้ที่เมนู ‘สลากฯ ของฉัน’</p>
        </div>

        <div v-if="isLoading" class="text-center muted-text py-4">
          กำลังโหลดข้อมูลการชำระเงิน...
        </div>

        <div v-else-if="loadError && !displayOrder" class="text-center py-4">
          <div class="fw-semibold text-danger mb-2">{{ loadError }}</div>
          <NuxtLink class="outline-pill d-inline-flex" to="/tickets">ดูสลากฯ ของฉัน</NuxtLink>
        </div>

        <div v-else class="d-grid gap-3 fs-6">
          <div class="d-flex justify-content-between">
            <span class="muted-text">จำนวนสลากฯ</span>
            <strong class="text-primary">{{ ticketCount }} ใบ</strong>
          </div>
          <div class="d-flex justify-content-between">
            <span class="muted-text">สลากฯ งวดวันที่</span>
            <strong class="text-primary text-end">{{ drawDate }}</strong>
          </div>
          <div v-if="orderLotteries.length" class="receipt-ticket-preview">
            <LotteryImage
              v-for="(ticket, index) in orderLotteries"
              :key="`${getLotteryNumber(ticket)}-${index}`"
              :src="getLotteryImageUrl(ticket)"
              :thumb-src="getLotteryThumbUrl(ticket)"
              :status="getLotteryImageStatus(ticket)"
              :error-message="getLotteryImageError(ticket)"
              :number="getLotteryNumber(ticket)"
              variant="stub"
            />
          </div>
          <hr>
          <div class="d-flex justify-content-between">
            <span class="muted-text">ชำระเงินให้</span>
            <strong class="text-end">{{ payeeName }}</strong>
          </div>
          <div class="d-flex justify-content-between">
            <span class="muted-text">ช่องทางชำระเงิน</span>
            <strong class="text-end">{{ walletName }}</strong>
          </div>
          <div class="d-flex justify-content-between pt-3">
            <span class="muted-text">ยอดชำระทั้งหมด</span>
            <span><strong class="fs-3">{{ formatMoney(totalAmount) }}</strong> บาท</span>
          </div>
          <div class="text-center muted-text">
            วันที่ทำรายการ {{ paidAtText }}<br>
            รหัสอ้างอิง {{ referenceCode }}
          </div>
        </div>
      </section>

      <div class="px-4 mt-4">
        <button class="btn bg-white text-primary rounded-pill w-50 mx-auto d-flex align-items-center justify-content-center gap-2 fw-semibold py-3" type="button">
          <i class="bi bi-download fs-4" /> บันทึก
        </button>
      </div>
      <div class="px-3" style="margin-top:238px">
        <NuxtLink class="primary-pill d-block text-center py-3" to="/tickets">ดูสลากฯ ของฉัน</NuxtLink>
      </div>
    </div>
  </MobileShell>
</template>

<script setup lang="ts">
import { formatDrawDateText } from '~/utils/formatDrawDate'

definePageMeta({
  requiresAuth: true
})

interface SuccessOrder {
  id?: number | string
  total?: number | string
  amount?: number | string
  price?: number | string
  updated_at?: string
  created_at?: string
  lotteries?: Array<Record<string, unknown>>
  store?: {
    name?: string
  } | null
  [key: string]: unknown
}

interface SuccessReceipt {
  order?: SuccessOrder | null
  game?: {
    name?: string
  } | null
  wallet?: {
    name?: string
  } | null
  count?: number | string
  total?: number | string
  reference?: string
  paid_at?: string
}

const route = useRoute()
const platformApi = usePlatformApi()
const { currentDrawDate } = useAppInit()
const checkoutSuccessOrder = useState<SuccessOrder | null>('checkout_success_order', () => null)

const receipt = ref<SuccessReceipt | null>(null)
const isLoading = ref(true)
const loadError = ref('')

const toNumber = (value: unknown, fallback = 0) => {
  const number = Number(value)

  return Number.isFinite(number) ? number : fallback
}

const getOrderLotteryCount = (order: SuccessOrder | null | undefined) => {
  const lotteries = Array.isArray(order?.lotteries) ? order.lotteries : []

  return lotteries.reduce((total, lottery) => total + Math.max(1, toNumber(lottery.count, 1)), 0)
}

const getOrderTotal = (order: SuccessOrder | null | undefined) => {
  const explicitTotal = toNumber(order?.total ?? order?.amount ?? order?.price)

  if (explicitTotal > 0) {
    return explicitTotal
  }

  const lotteries = Array.isArray(order?.lotteries) ? order.lotteries : []

  return lotteries.reduce((total, lottery) => total + toNumber(lottery.price), 0)
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
    hour12: false
  }).format(date).replace(',', '')
}

const displayOrder = computed(() => receipt.value?.order || checkoutSuccessOrder.value)
const ticketCount = computed(() => {
  const receiptCount = toNumber(receipt.value?.count)

  return receiptCount > 0 ? receiptCount : getOrderLotteryCount(displayOrder.value)
})
const drawDate = computed(() => {
  const apiDrawDate = formatDrawDateText(receipt.value?.game?.name)

  return apiDrawDate !== '-' ? apiDrawDate : currentDrawDate.value
})
const payeeName = computed(() => displayOrder.value?.store?.name || 'ร้านค้าสลากฯ')
const walletName = computed(() => receipt.value?.wallet?.name || 'G Wallet')
const totalAmount = computed(() => {
  const receiptTotal = toNumber(receipt.value?.total)

  return receiptTotal > 0 ? receiptTotal : getOrderTotal(displayOrder.value)
})
const paidAtText = computed(() => formatDateTime(receipt.value?.paid_at || displayOrder.value?.updated_at || displayOrder.value?.created_at))
const referenceCode = computed(() => receipt.value?.reference || (displayOrder.value?.id ? `ORDER-${displayOrder.value.id}` : '-'))
const orderLotteries = computed(() => Array.isArray(displayOrder.value?.lotteries) ? displayOrder.value.lotteries : [])

const getLotteryString = (lottery: Record<string, unknown>, keys: string[]) => {
  const value = keys.find((key) => lottery[key])

  return value ? String(lottery[value] || '') : ''
}

const getLotteryNumber = (lottery: Record<string, unknown>) => getLotteryString(lottery, ['number', 'full_number', 'lottery_number'])
const getLotteryImageUrl = (lottery: Record<string, unknown>) => getLotteryString(lottery, ['image_url', 'image'])
const getLotteryThumbUrl = (lottery: Record<string, unknown>) => getLotteryString(lottery, ['image_thumb_url'])
const getLotteryImageStatus = (lottery: Record<string, unknown>) => getLotteryString(lottery, ['image_status'])
const getLotteryImageError = (lottery: Record<string, unknown>) => getLotteryString(lottery, ['image_error'])

const fetchReceipt = async () => {
  isLoading.value = true
  loadError.value = ''

  try {
    const orderId = route.query.order_id
    receipt.value = typeof orderId === 'string' && orderId
      ? await platformApi.orderReceiptLegacy(orderId)
      : null
    checkoutSuccessOrder.value = receipt.value?.order || checkoutSuccessOrder.value
  } catch (error: any) {
    loadError.value = error?.response?.data?.message || 'โหลดข้อมูลการชำระเงินไม่สำเร็จ'
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  fetchReceipt()
})
</script>

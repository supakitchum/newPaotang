<template>
  <MobileShell active-nav="menu">
    <BlueHeader title="ประวัติการซื้อสลากฯ" back-to="/profile" min-height="176px" />

    <section class="content-sheet flush purchase-history-page">
      <div v-if="isLoading" class="muted-text text-center py-4">กำลังโหลดประวัติการซื้อ...</div>

      <div v-else-if="loadError" class="purchase-history-empty">
        <i class="bi bi-receipt-cutoff" />
        <h2>โหลดประวัติไม่สำเร็จ</h2>
        <p>{{ loadError }}</p>
        <button class="primary-pill purchase-history-action" type="button" @click="fetchOrders()">
          ลองใหม่
        </button>
      </div>

      <div v-else-if="groups.length === 0" class="purchase-history-empty">
        <i class="bi bi-ticket-perforated" />
        <h2>ยังไม่มีประวัติการซื้อสลากฯ</h2>
        <p>เมื่อซื้อสลากสำเร็จ รายการจะแสดงที่หน้านี้</p>
        <NuxtLink class="primary-pill purchase-history-action" to="/buy">
          ซื้อสลากฯ
        </NuxtLink>
      </div>

      <div v-else class="purchase-history-stack">
        <section v-for="group in groups" :key="group.year" class="purchase-history-group">
          <h2>ปี {{ group.year }}</h2>
          <div class="purchase-history-list">
            <NuxtLink
              v-for="order in group.orders"
              :key="String(order.id)"
              class="purchase-history-row"
              :to="`/purchase-history/${encodeURIComponent(String(order.id))}`"
            >
              <div class="purchase-history-main">
                <div class="purchase-history-head">
                  <span class="purchase-history-title">ซื้อสลากฯ</span>
                  <span class="purchase-history-badge">สลากดิจิทัล</span>
                </div>
                <div class="purchase-history-draw">งวดวันที่ {{ drawDate(order) }}</div>
                <div class="purchase-history-date">{{ transactionDate(order) }}</div>
              </div>
              <div class="purchase-history-side">
                <div class="purchase-history-amount">
                  <strong>{{ formatMoney(orderAmount(order)) }}</strong>
                  <span>บาท</span>
                </div>
                <i class="bi bi-chevron-right" />
              </div>
            </NuxtLink>
          </div>
        </section>

        <button v-if="hasMore" class="outline-pill purchase-history-more" type="button" :disabled="isLoadingMore" @click="loadMore">
          {{ isLoadingMore ? 'กำลังโหลด...' : 'โหลดเพิ่มเติม' }}
        </button>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { formatDrawDateText } from '~/utils/formatDrawDate'

definePageMeta({
  requiresAuth: true
})

type PurchaseOrder = Record<string, any>

const platformApi = usePlatformApi()
const orders = ref<PurchaseOrder[]>([])
const isLoading = ref(false)
const isLoadingMore = ref(false)
const loadError = ref('')
const currentPage = ref(1)
const lastPage = ref(1)
const perPage = 20

const toDate = (value: unknown) => {
  if (!value) {
    return null
  }

  const date = new Date(String(value))

  return Number.isNaN(date.getTime()) ? null : date
}

const orderDate = (order: PurchaseOrder) => order.paid_at || order.updated_at || order.created_at
const drawSource = (order: PurchaseOrder) => (
  order.game?.draw_at ||
  order.game?.name ||
  order.lotteries?.[0]?.game?.draw_at ||
  order.lotteries?.[0]?.game?.name ||
  ''
)
const drawDate = (order: PurchaseOrder) => {
  const formatted = formatDrawDateText(drawSource(order))

  return formatted === '-' ? '-' : formatted
}

const transactionDate = (order: PurchaseOrder) => {
  const date = toDate(orderDate(order))

  if (!date) {
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

const yearLabel = (order: PurchaseOrder) => {
  const date = toDate(drawSource(order)) || toDate(orderDate(order))

  if (!date) {
    return '-'
  }

  const yearPart = new Intl.DateTimeFormat('th-TH', {
    year: 'numeric',
    timeZone: 'Asia/Bangkok'
  }).formatToParts(date).find((part) => part.type === 'year')

  return yearPart?.value || '-'
}

const orderAmount = (order: PurchaseOrder) => Number(order.total ?? order.amount ?? order.price ?? 0)
const formatMoney = (value: number) => new Intl.NumberFormat('th-TH', {
  minimumFractionDigits: value % 1 === 0 ? 0 : 2,
  maximumFractionDigits: 2
}).format(value)

const groups = computed(() => {
  const map = new Map<string, PurchaseOrder[]>()

  for (const order of orders.value) {
    const year = yearLabel(order)
    map.set(year, [...(map.get(year) || []), order])
  }

  return Array.from(map.entries()).map(([year, groupOrders]) => ({
    year,
    orders: groupOrders
  }))
})

const hasMore = computed(() => currentPage.value < lastPage.value)

const applyResult = (result: any, append = false) => {
  const nextOrders = Array.isArray(result?.orders) ? result.orders : []
  orders.value = append ? [...orders.value, ...nextOrders] : nextOrders
  currentPage.value = Number(result?.pagination?.current_page || currentPage.value || 1)
  lastPage.value = Number(result?.pagination?.last_page || currentPage.value || 1)
}

const fetchOrders = async (page = 1, append = false) => {
  if (append) {
    isLoadingMore.value = true
  } else {
    isLoading.value = true
  }
  loadError.value = ''

  try {
    const result = await platformApi.orderHistoryLegacy({
      page,
      per_page: perPage
    })
    applyResult(result, append)
  } catch (error: any) {
    loadError.value = error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง'
  } finally {
    isLoading.value = false
    isLoadingMore.value = false
  }
}

const loadMore = async () => {
  if (!hasMore.value || isLoadingMore.value) {
    return
  }

  await fetchOrders(currentPage.value + 1, true)
}

useTenantSeo({
  title: 'ประวัติการซื้อสลากฯ',
  canonicalPath: '/purchase-history',
  privatePage: true
})

onMounted(() => {
  fetchOrders()
})
</script>

<style scoped>
.purchase-history-page {
  min-height: 660px;
  padding: 28px 20px 56px;
  background: #fff;
  border-radius: 22px 22px 0 0;
}

.purchase-history-stack {
  display: grid;
  gap: 32px;
}

.purchase-history-group h2 {
  margin: 0 0 22px;
  color: var(--app-ink);
  font-size: 28px;
  font-weight: 900;
  line-height: 1.2;
}

.purchase-history-list {
  display: grid;
}

.purchase-history-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 16px;
  min-height: 116px;
  padding: 0 0 22px;
  color: inherit;
  text-decoration: none;
  border-bottom: 1px solid #e8edf4;
}

.purchase-history-row + .purchase-history-row {
  padding-top: 22px;
}

.purchase-history-head {
  display: flex;
  align-items: center;
  gap: 9px;
  min-width: 0;
  margin-bottom: 8px;
}

.purchase-history-title {
  color: #252a31;
  font-size: 20px;
  font-weight: 900;
  line-height: 1.2;
}

.purchase-history-badge {
  display: inline-flex;
  max-width: 128px;
  padding: 5px 11px;
  overflow: hidden;
  border-radius: 999px;
  background: #eee7ff;
  color: #8762d6;
  font-size: 15px;
  font-weight: 900;
  line-height: 1;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.purchase-history-draw {
  margin-bottom: 10px;
  color: #626a73;
  font-size: 20px;
  font-weight: 700;
  line-height: 1.3;
}

.purchase-history-date {
  color: #8a929b;
  font-size: 17px;
  font-weight: 700;
  line-height: 1.25;
}

.purchase-history-side {
  display: grid;
  grid-template-rows: auto 1fr;
  justify-items: end;
  min-width: 92px;
  padding-top: 2px;
}

.purchase-history-amount {
  display: inline-flex;
  align-items: baseline;
  gap: 6px;
  color: #2a2f35;
  white-space: nowrap;
}

.purchase-history-amount strong {
  font-size: 22px;
  font-weight: 900;
}

.purchase-history-amount span {
  font-size: 19px;
  font-weight: 600;
}

.purchase-history-side i {
  align-self: center;
  color: var(--app-blue);
  font-size: 34px;
}

.purchase-history-empty {
  display: grid;
  justify-items: center;
  gap: 12px;
  padding: 56px 10px;
  color: #596474;
  text-align: center;
}

.purchase-history-empty i {
  display: grid;
  width: 58px;
  height: 58px;
  place-items: center;
  border-radius: 50%;
  background: #eef7ff;
  color: var(--app-blue);
  font-size: 28px;
}

.purchase-history-empty h2 {
  margin: 0;
  color: var(--app-ink);
  font-size: 20px;
  font-weight: 900;
}

.purchase-history-empty p {
  margin: 0;
  font-size: 15px;
  font-weight: 700;
}

.purchase-history-action {
  display: inline-grid;
  min-width: 148px;
  margin-top: 8px;
  place-items: center;
  padding: 0 22px;
  text-decoration: none;
}

.purchase-history-more {
  min-height: 44px;
  margin: 6px auto 0;
  padding: 0 22px;
}

@media (max-width: 360px) {
  .purchase-history-page {
    padding-right: 16px;
    padding-left: 16px;
  }

  .purchase-history-row {
    gap: 10px;
  }

  .purchase-history-title,
  .purchase-history-draw {
    font-size: 18px;
  }

  .purchase-history-date {
    font-size: 15px;
  }

  .purchase-history-badge {
    max-width: 112px;
    font-size: 13px;
  }

  .purchase-history-amount strong {
    font-size: 19px;
  }

  .purchase-history-amount span {
    font-size: 16px;
  }
}
</style>

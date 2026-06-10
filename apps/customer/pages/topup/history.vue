<template>
  <MobileShell time="12:59">
    <BlueHeader title="ประวัติเติมเงิน" back-to="/topup" min-height="220px">
      <div class="topup-history-summary">
        <i class="bi bi-clock-history" />
        <div>
          <h2>รายการเติมเงินล่าสุด</h2>
          <p>ตรวจสอบสถานะรายการเติมเงินเข้า G-Wallet</p>
        </div>
      </div>
    </BlueHeader>

    <section class="content-sheet flush topup-history-page">
      <div v-if="isLoading" class="muted-text text-center py-4">กำลังโหลดข้อมูล...</div>
      <div v-else-if="histories.length === 0" class="topup-history-empty">
        <div class="topup-history-empty-icon">
          <i class="bi bi-receipt" />
        </div>
        <h2>ยังไม่มีประวัติเติมเงิน</h2>
        <p>เมื่อเติมเงินสำเร็จ รายการจะแสดงที่หน้านี้</p>
        <NuxtLink class="primary-pill topup-history-empty-action" to="/topup">
          เติมเงิน
        </NuxtLink>
      </div>
      <div v-else class="topup-history-stack">
        <div class="topup-history-list">
          <article v-for="history in histories" :key="`${history.id || history.created_at}-${history.amount}`" class="topup-history-card">
            <div :class="['topup-history-icon', getStatusClass(history.status)]">
              <i class="bi" :class="statusIcon(history.status)" />
            </div>

            <div class="topup-history-main">
              <div class="topup-history-title-row">
                <strong>เติมเงินเข้า G-Wallet</strong>
                <span :class="['topup-status', getStatusClass(history.status)]">{{ getStatusText(history.status) }}</span>
              </div>
              <div class="topup-history-meta">
                <span>รายการ #{{ history.id || '-' }}</span>
                <span>{{ formatDate(history.transfer_at || history.created_at) }}</span>
              </div>
              <div v-if="toNumber(history.bonus_amount) > 0" class="topup-history-bonus">
                <i class="bi bi-stars" />
                <span>โบนัส {{ formatMoney(toNumber(history.bonus_amount)) }} บาท</span>
              </div>
            </div>

            <div class="topup-history-amount">
              <strong>{{ formatMoney(toNumber(history.amount)) }}</strong>
              <span>บาท</span>
            </div>
          </article>
        </div>
        <nav v-if="showPagination" class="topup-history-pagination" aria-label="ประวัติเติมเงิน pagination">
          <button type="button" :disabled="isLoading || currentPage <= 1" @click="goToPage(currentPage - 1)">
            <i class="bi bi-chevron-left" />
          </button>
          <button
            v-for="pageNumber in visiblePages"
            :key="pageNumber"
            type="button"
            :class="{ active: pageNumber === currentPage }"
            :disabled="isLoading"
            @click="goToPage(pageNumber)"
          >
            {{ pageNumber }}
          </button>
          <button type="button" :disabled="isLoading || currentPage >= totalPages" @click="goToPage(currentPage + 1)">
            <i class="bi bi-chevron-right" />
          </button>
        </nav>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import type { DepositHistory } from '~/composables/useTopup'

definePageMeta({
  requiresAuth: true
})

const platformApi = usePlatformApi()
const { showAlert } = useAppAlert()
const { toNumber, formatMoney, formatDate, getStatusText, getStatusClass } = useTopup()

const histories = ref<DepositHistory[]>([])
const isLoading = ref(false)
const pagination = ref<DepositPagination | null>(null)
const currentPage = ref(1)
const perPage = 8

interface DepositPagination {
  current_page?: number
  last_page?: number
  per_page?: number
  total?: number
  from?: number | null
  to?: number | null
}

const totalPages = computed(() => pagination.value?.last_page || 1)
const showPagination = computed(() => totalPages.value > 1)
const visiblePages = computed(() => {
  const total = totalPages.value
  const current = currentPage.value
  const maxVisible = 5
  let start = Math.max(1, current - 2)
  const end = Math.min(total, start + maxVisible - 1)

  start = Math.max(1, end - maxVisible + 1)

  return Array.from({ length: end - start + 1 }, (_, index) => start + index)
})

const statusIcon = (status?: number | string) => {
  const value = Number(status)

  if (value === 1) {
    return 'bi-check2'
  }

  if (value === 2) {
    return 'bi-hourglass-split'
  }

  if (value === 0) {
    return 'bi-x-lg'
  }

  return 'bi-wallet2'
}

const fetchHistories = async (page = currentPage.value) => {
  isLoading.value = true

  try {
    const result = await platformApi.topupOverviewLegacy({
      page,
      per_page: perPage
    })
    histories.value = Array.isArray(result.histories) ? result.histories : []
    pagination.value = result.pagination || null
    currentPage.value = pagination.value?.current_page || page
  } catch (error: any) {
    showAlert({
      title: 'โหลดประวัติไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isLoading.value = false
  }
}

const goToPage = async (page: number) => {
  if (isLoading.value || page < 1 || page > totalPages.value || page === currentPage.value) {
    return
  }

  await fetchHistories(page)
}

onMounted(fetchHistories)
</script>

<style scoped>
.topup-history-summary {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  margin-top: 20px;
}

.topup-history-summary i {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  background: #fff;
  color: #0b69dc;
  font-size: 24px;
}

.topup-history-summary h2 {
  font-size: 20px;
  font-weight: 800;
  margin: 0 0 4px;
}

.topup-history-summary p {
  margin: 0;
}

.topup-history-page {
  display: grid;
  min-height: 660px;
  padding: 24px 20px 56px;
  background: #fff;
  border-radius: 18px 18px 0 0;
  align-content: start;
}

.topup-history-page > * {
  width: 100%;
  max-width: none;
  margin-right: 0;
  margin-left: 0;
}

.topup-history-empty {
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 8px 22px rgba(22, 46, 82, .09);
  padding: 12px 14px;
}

.topup-history-empty {
  min-height: 260px;
  display: grid;
  place-items: center;
  align-content: center;
  gap: 10px;
  text-align: center;
  color: #64748b;
  padding: 32px 22px;
}

.topup-history-empty-icon {
  width: 68px;
  height: 68px;
  border-radius: 20px;
  display: grid;
  place-items: center;
  background: #eaf5ff;
  color: #0b69dc;
  font-size: 32px;
}

.topup-history-empty h2 {
  margin: 4px 0 0;
  color: #17335f;
  font-size: 20px;
  font-weight: 800;
}

.topup-history-empty p {
  margin: 0;
  max-width: 260px;
  line-height: 1.5;
}

.topup-history-empty-action {
  width: min(220px, 100%);
  min-height: 46px;
  display: grid;
  place-items: center;
  margin-top: 8px;
  text-decoration: none;
}

.topup-history-stack {
  display: grid;
  gap: 20px;
}

.topup-history-list {
  display: grid;
}

.topup-history-card {
  align-items: center;
  border-bottom: 1px solid #e8edf4;
  color: inherit;
  display: grid;
  gap: 14px;
  grid-template-columns: 46px minmax(0, 1fr) auto;
  min-height: 96px;
  padding: 0 0 18px;
}

.topup-history-card + .topup-history-card {
  padding-top: 18px;
}

.topup-history-card:last-child {
  border-bottom: 0;
}

.topup-history-icon {
  align-items: center;
  border-radius: 999px;
  display: inline-flex;
  font-size: 21px;
  height: 46px;
  justify-content: center;
  width: 46px;
}

.topup-history-main {
  display: grid;
  gap: 7px;
  min-width: 0;
}

.topup-history-title-row {
  align-items: center;
  display: flex;
  gap: 8px;
  justify-content: space-between;
  min-width: 0;
}

.topup-history-title-row strong {
  color: #17335f;
  font-size: 16px;
  font-weight: 900;
  line-height: 1.2;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.topup-status {
  border-radius: 999px;
  padding: 5px 9px;
  font-size: 12px;
  font-weight: 800;
  line-height: 1.2;
  white-space: nowrap;
}

.topup-history-meta {
  color: #64748b;
  display: flex;
  flex-wrap: wrap;
  font-size: 12px;
  font-weight: 700;
  gap: 4px 10px;
  line-height: 1.25;
  min-width: 0;
}

.topup-history-meta span {
  min-width: 0;
}

.topup-history-amount {
  display: grid;
  gap: 2px;
  justify-items: end;
  min-width: 86px;
}

.topup-history-amount strong {
  color: #17335f;
  font-size: 22px;
  font-weight: 900;
  line-height: 1;
  white-space: nowrap;
}

.topup-history-amount span {
  color: #64748b;
  font-size: 12px;
  font-weight: 800;
}

.topup-history-bonus {
  align-items: center;
  background: #e6f8ef;
  border-radius: 999px;
  color: #047857;
  display: inline-flex;
  font-size: 12px;
  font-weight: 800;
  gap: 5px;
  justify-self: start;
  line-height: 1.2;
  padding: 5px 8px;
  white-space: nowrap;
}

.topup-history-pagination {
  display: flex;
  justify-content: center;
  gap: 6px;
}

.topup-history-pagination button {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border: 1px solid #d8e0ea;
  border-radius: 999px;
  background: #fff;
  color: #17335f;
  font-size: 13px;
  font-weight: 800;
}

.topup-history-pagination button.active {
  border-color: #0b69dc;
  color: #fff;
  background: #0b69dc;
}

.topup-history-pagination button:disabled {
  color: #9aa5b1;
  background: #f1f5f9;
  cursor: not-allowed;
}

.status-1 {
  color: #047857;
  background: #dff8eb;
}

.status-2 {
  color: #075ec9;
  background: #e4f0ff;
}

.status-0 {
  color: #b42318;
  background: #ffe4e2;
}

.status-unknown {
  color: #64748b;
  background: #eef2f7;
}

@media (max-width: 360px) {
  .topup-history-card {
    align-items: start;
    grid-template-columns: 42px minmax(0, 1fr);
  }

  .topup-history-icon {
    font-size: 19px;
    height: 42px;
    width: 42px;
  }

  .topup-history-amount {
    grid-column: 2;
    justify-items: start;
    min-width: 0;
  }

  .topup-history-title-row {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>

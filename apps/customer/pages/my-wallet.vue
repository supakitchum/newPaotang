<template>
  <MobileShell active-nav="menu" show-bottom-nav>
    <BlueHeader title="กระเป๋าของฉัน" back-to="/profile" min-height="304px">
      <WalletBalanceCard
        class="my-wallet-hero-card"
        :balance="walletBalance"
        :loading="isWalletLoading"
        :customer-label="customerNoLabel"
        topup-back-to="/my-wallet"
      />
    </BlueHeader>

    <section id="transactions" class="content-sheet flush my-wallet-sheet">
      <div class="my-wallet-section-head">
        <div>
          <h2>ประวัติรายการเดินเงินล่าสุด</h2>
          <p>รายการเติมเงิน ชำระเงิน และรับเงินรางวัล</p>
        </div>
        <button class="my-wallet-refresh" type="button" :disabled="isLedgerLoading || isWalletLoading" aria-label="โหลดรายการใหม่" @click="refreshWallet">
          <i class="bi bi-arrow-clockwise" />
        </button>
      </div>

      <div v-if="isLedgerLoading" class="my-wallet-loading">กำลังโหลดรายการ...</div>

      <div v-else-if="ledgerEntries.length === 0" class="my-wallet-empty">
        <div class="my-wallet-empty-icon">
          <i class="bi bi-receipt" />
        </div>
        <h2>ยังไม่มีรายการเดินเงิน</h2>
        <p>เมื่อมีการเติมเงิน ชำระเงิน หรือรับเงินรางวัล รายการจะแสดงที่นี่</p>
      </div>

      <div v-else class="my-wallet-transactions">
        <article
          v-for="entry in ledgerEntries"
          :key="entry.id || `${entry.created_at}-${entry.amount}`"
          class="my-wallet-transaction"
        >
          <div class="my-wallet-transaction-icon" :class="transactionTone(entry)">
            <i class="bi" :class="transactionIcon(entry)" />
          </div>
          <div class="my-wallet-transaction-main">
            <strong>{{ transactionTitle(entry) }}</strong>
            <span>{{ transactionSubtitle(entry) }}</span>
            <small>{{ formatDate(entry.created_at || entry.posted_at) }}</small>
          </div>
          <div class="my-wallet-transaction-money">
            <strong :class="transactionTone(entry)">{{ formatSignedAmount(entry) }}</strong>
            <span>คงเหลือ {{ formatBaht(toNumber(entry.balance_after)) }}</span>
          </div>
        </article>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: true
})

interface WalletLedgerEntry {
  id?: string
  entry_type?: string
  status?: string
  amount?: number | string
  balance_after?: number | string
  reason?: string
  reference_type?: string
  reference_id?: string
  created_at?: string
  posted_at?: string
}

const platformApi = usePlatformApi()
const { showAlert } = useAppAlert()
const { isAuthenticated, user, restoreAuthState } = useAuth()
const { toNumber, formatDate } = useTopup()
const wallets = ref<Array<Record<string, any>>>([])
const ledgerEntries = ref<WalletLedgerEntry[]>([])
const isWalletLoading = ref(false)
const isLedgerLoading = ref(false)

const primaryWallet = computed(() => (
  wallets.value.find((wallet) => Number(wallet.type) === 1) || wallets.value[0] || null
))
const walletBalance = computed(() => toNumber(primaryWallet.value?.balance))
const customerNoLabel = computed(() => {
  const customerNo = user.value?.customer_no || user.value?.member_no || user.value?.id || ''

  return customerNo ? `รหัสสมาชิก : ${customerNo}` : 'รหัสสมาชิก : -'
})

const formatBaht = (value: number) => `${new Intl.NumberFormat('th-TH', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2
}).format(value)} บาท`

const transactionTone = (entry: WalletLedgerEntry) => {
  const amount = toNumber(entry.amount)

  if (amount > 0) {
    return 'is-credit'
  }

  if (amount < 0) {
    return 'is-debit'
  }

  return 'is-neutral'
}

const transactionIcon = (entry: WalletLedgerEntry) => {
  const type = String(entry.entry_type || '').toLowerCase()

  if (['credit', 'reversal', 'adjustment'].includes(type) && toNumber(entry.amount) >= 0) {
    return 'bi-arrow-down-left'
  }

  if (type === 'debit' || toNumber(entry.amount) < 0) {
    return 'bi-arrow-up-right'
  }

  return 'bi-wallet2'
}

const transactionTitle = (entry: WalletLedgerEntry) => {
  const referenceType = String(entry.reference_type || '').toLowerCase()
  const entryType = String(entry.entry_type || '').toLowerCase()

  if (referenceType.includes('topup')) {
    return 'เติมเงินเข้า G-Wallet'
  }

  if (referenceType === 'order') {
    return 'ชำระค่าสลากดิจิทัล'
  }

  if (referenceType.includes('reward_claim')) {
    return 'รับเงินรางวัลสลากฯ'
  }

  if (referenceType.includes('order_refund') || referenceType.includes('order_cancel')) {
    return 'คืนเงินเข้ากระเป๋า'
  }

  if (entryType === 'debit') {
    return 'เงินออกจากกระเป๋า'
  }

  if (entryType === 'credit') {
    return 'เงินเข้ากระเป๋า'
  }

  return 'รายการกระเป๋า'
}

const transactionSubtitle = (entry: WalletLedgerEntry) => {
  const reason = String(entry.reason || '').trim()

  if (reason) {
    return reason
  }

  const referenceId = String(entry.reference_id || '').trim()

  return referenceId ? `อ้างอิง ${referenceId}` : 'รายการสำเร็จ'
}

const formatSignedAmount = (entry: WalletLedgerEntry) => {
  const amount = toNumber(entry.amount)
  const sign = amount > 0 ? '+' : amount < 0 ? '-' : ''

  return `${sign}${formatBaht(Math.abs(amount))}`
}

const fetchWallet = async () => {
  isWalletLoading.value = true

  try {
    if (!user.value) {
      await restoreAuthState()
    }

    const response = await platformApi.walletLegacy()
    wallets.value = Array.isArray(response.data?.result) ? response.data.result : []
  } catch (error) {
    console.log(error)
    wallets.value = []
  } finally {
    isWalletLoading.value = false
  }
}

const fetchLedger = async () => {
  isLedgerLoading.value = true

  try {
    const result = await platformApi.walletLedgerLegacy({
      limit: 12,
      sort_by: 'created_at',
      sort_dir: 'desc'
    })
    ledgerEntries.value = Array.isArray(result.entries) ? result.entries : []
  } catch (error: any) {
    ledgerEntries.value = []
    showAlert({
      title: 'โหลดประวัติไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    isLedgerLoading.value = false
  }
}

const refreshWallet = async () => {
  await Promise.all([fetchWallet(), fetchLedger()])
}

useCustomerStockRealtime({
  enabled: isAuthenticated,
  onTopup: () => {
    void refreshWallet()
  },
  includePresence: true,
  onReconnect: () => {
    void refreshWallet()
  }
})

onMounted(() => {
  void refreshWallet()
})
</script>

<style scoped>
.my-wallet-hero-card {
  margin-top: 22px;
}

.my-wallet-sheet {
  display: grid;
  gap: 14px;
  margin-top: 0;
  padding-right: 16px;
  padding-left: 16px;
  background: #f4f6f8;
}

.my-wallet-section-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.my-wallet-section-head h2 {
  margin: 0;
  color: #17335f;
  font-size: 19px;
  font-weight: 900;
}

.my-wallet-section-head p {
  margin: 4px 0 0;
  color: #718096;
  font-size: 13px;
  font-weight: 700;
}

.my-wallet-refresh {
  width: 40px;
  height: 40px;
  display: grid;
  flex: 0 0 40px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  color: #075ec9;
  background: #eaf5ff;
  font-size: 19px;
}

.my-wallet-refresh:disabled {
  color: #9aa9bc;
}

.my-wallet-loading,
.my-wallet-empty {
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 8px 22px rgba(22, 46, 82, .09);
}

.my-wallet-loading {
  padding: 28px 16px;
  color: #64748b;
  text-align: center;
  font-weight: 700;
}

.my-wallet-empty {
  min-height: 260px;
  display: grid;
  place-items: center;
  align-content: center;
  gap: 10px;
  padding: 32px 22px;
  color: #64748b;
  text-align: center;
}

.my-wallet-empty-icon {
  width: 68px;
  height: 68px;
  display: grid;
  place-items: center;
  border-radius: 20px;
  color: #0b69dc;
  background: #eaf5ff;
  font-size: 32px;
}

.my-wallet-empty h2 {
  margin: 4px 0 0;
  color: #17335f;
  font-size: 20px;
  font-weight: 900;
}

.my-wallet-empty p {
  margin: 0;
  line-height: 1.45;
}

.my-wallet-transactions {
  overflow: hidden;
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 8px 22px rgba(22, 46, 82, .09);
}

.my-wallet-transaction {
  display: grid;
  grid-template-columns: 42px minmax(0, 1fr) auto;
  gap: 11px;
  align-items: center;
  padding: 13px 12px;
  border-bottom: 1px solid #edf1f6;
}

.my-wallet-transaction:last-child {
  border-bottom: 0;
}

.my-wallet-transaction-icon {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: 999px;
  font-size: 20px;
}

.my-wallet-transaction-icon.is-credit {
  color: #078254;
  background: #e7f8ef;
}

.my-wallet-transaction-icon.is-debit {
  color: #d33b38;
  background: #ffecec;
}

.my-wallet-transaction-icon.is-neutral {
  color: #64748b;
  background: #eef2f7;
}

.my-wallet-transaction-main {
  min-width: 0;
  display: grid;
  gap: 2px;
}

.my-wallet-transaction-main strong,
.my-wallet-transaction-main span,
.my-wallet-transaction-main small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.my-wallet-transaction-main strong {
  color: #17335f;
  font-size: 14px;
  font-weight: 900;
}

.my-wallet-transaction-main span {
  color: #556987;
  font-size: 12px;
  font-weight: 700;
}

.my-wallet-transaction-main small {
  color: #8a9ab0;
  font-size: 11px;
  font-weight: 700;
}

.my-wallet-transaction-money {
  display: grid;
  gap: 3px;
  min-width: 86px;
  text-align: right;
}

.my-wallet-transaction-money strong {
  font-size: 13px;
  font-weight: 900;
}

.my-wallet-transaction-money strong.is-credit {
  color: #078254;
}

.my-wallet-transaction-money strong.is-debit {
  color: #d33b38;
}

.my-wallet-transaction-money strong.is-neutral {
  color: #64748b;
}

.my-wallet-transaction-money span {
  color: #718096;
  font-size: 11px;
  font-weight: 700;
  white-space: nowrap;
}

@media (max-width: 360px) {
  .my-wallet-transaction {
    grid-template-columns: 38px minmax(0, 1fr);
  }

  .my-wallet-transaction-money {
    grid-column: 2;
    min-width: 0;
    text-align: left;
  }
}
</style>

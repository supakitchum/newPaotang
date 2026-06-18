<template>
  <section class="wallet-balance-card" :class="{ 'is-compact': compact }" aria-label="ยอดเงินในกระเป๋า">
    <div class="wallet-card-head">
      <div class="wallet-card-label">
        <i class="bi bi-wallet2" />
        <span>ยอดเงินในกระเป๋า</span>
      </div>
      <NuxtLink class="wallet-card-qr" to="/my-wallet" aria-label="เปิดกระเป๋าของฉัน">
        <i class="bi bi-qr-code-scan" />
      </NuxtLink>
    </div>

    <div class="wallet-card-amount" :aria-busy="loading">
      {{ loading ? 'กำลังโหลด...' : formattedBalance }}
    </div>
    <div v-if="customerLabel && !compact" class="wallet-card-customer">{{ customerLabel }}</div>

    <div class="wallet-card-actions" aria-label="เมนูกระเป๋า">
      <NuxtLink
        v-for="action in enabledActions"
        :key="action.label"
        class="wallet-card-action"
        :to="action.to"
      >
        <span class="wallet-card-action-icon">
          <i class="bi" :class="action.icon" />
        </span>
        <span>{{ action.label }}</span>
      </NuxtLink>
    </div>
  </section>
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  balance?: number | string
  loading?: boolean
  customerLabel?: string
  compact?: boolean
  topupBackTo?: string
}>(), {
  balance: 0,
  loading: false,
  customerLabel: '',
  compact: false,
  topupBackTo: '/my-wallet'
})

const enabledActions = computed(() => [
  { label: 'เติมเงิน', icon: 'bi-plus-lg', to: { path: '/topup', query: { back: props.topupBackTo } } },
  { label: 'สลากฯ', icon: 'bi-ticket-perforated', to: '/tickets' },
  { label: 'ขึ้นเงิน', icon: 'bi-cash-coin', to: '/reward-claims' },
  { label: 'ประวัติ', icon: 'bi-clock-history', to: '/my-wallet#transactions' }
])

const formattedBalance = computed(() => {
  const value = Number(props.balance)
  const safeValue = Number.isFinite(value) ? value : 0

  return `${new Intl.NumberFormat('th-TH', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  }).format(safeValue)} บาท`
})
</script>

<style scoped>
.wallet-balance-card {
  position: relative;
  overflow: hidden;
  display: grid;
  gap: clamp(17px, 4vw, 22px);
  padding: clamp(19px, 5vw, 26px);
  border-radius: 16px;
  color: #fff;
  background:
    radial-gradient(circle at 88% 0%, rgba(255, 211, 41, .92) 0 38px, transparent 39px),
    linear-gradient(135deg, #087bec 0%, #0e95d8 46%, #12a077 100%);
  box-shadow: 0 14px 30px rgba(0, 93, 183, .23);
}

.wallet-balance-card::before {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(145deg, transparent 22%, rgba(255, 255, 255, .13) 22.6%, transparent 54%);
  pointer-events: none;
}

.wallet-balance-card > * {
  position: relative;
  z-index: 1;
}

.wallet-card-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.wallet-card-label {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  color: rgba(255, 255, 255, .9);
  font-size: 12px;
  font-weight: 800;
}

.wallet-card-label i {
  font-size: 17px;
}

.wallet-card-qr {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: 12px;
  color: #fff;
  background: rgba(0, 49, 102, .22);
  font-size: 25px;
}

.wallet-card-amount {
  justify-self: center;
  margin-block: 2px 0;
  max-width: 100%;
  font-size: clamp(26px, 8vw, 34px);
  font-weight: 900;
  line-height: 1;
  letter-spacing: 0;
  text-align: center;
  overflow-wrap: anywhere;
}

.wallet-card-customer {
  justify-self: center;
  margin-top: -12px;
  color: rgba(255, 255, 255, .84);
  font-size: 12px;
  font-weight: 700;
  text-align: center;
}

.wallet-card-actions {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: clamp(8px, 3vw, 14px);
  padding-top: 2px;
}

.wallet-card-action {
  min-width: 0;
  display: grid;
  justify-items: center;
  gap: 6px;
  color: #fff;
  text-align: center;
  text-decoration: none;
  font-size: 11px;
  font-weight: 800;
}

.wallet-card-action span:last-child {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.wallet-card-action-icon {
  width: 40px;
  height: 40px;
  display: grid;
  place-items: center;
  border-radius: 999px;
  color: #fff;
  background: rgba(0, 44, 88, .42);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, .08);
}

.wallet-card-action-icon i {
  font-size: 18px;
}

.wallet-balance-card.is-compact {
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: clamp(15px, 4vw, 20px);
  padding: clamp(18px, 4.8vw, 24px);
}

.wallet-balance-card.is-compact .wallet-card-head,
.wallet-balance-card.is-compact .wallet-card-amount,
.wallet-balance-card.is-compact .wallet-card-actions {
  grid-column: 1 / -1;
}

.wallet-balance-card.is-compact .wallet-card-head {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  align-items: start;
  gap: 0;
}

.wallet-balance-card.is-compact .wallet-card-label {
  grid-column: 1 / 3;
  justify-self: start;
}

.wallet-balance-card.is-compact .wallet-card-qr {
  grid-column: 4;
  justify-self: end;
}

.wallet-balance-card.is-compact .wallet-card-actions {
  gap: 0;
}

.wallet-balance-card.is-compact .wallet-card-customer {
  display: none;
}

@media (max-width: 360px) {
  .wallet-card-actions {
    gap: 6px;
  }

  .wallet-card-action-icon {
    width: 36px;
    height: 36px;
  }

  .wallet-card-action {
    font-size: 10px;
  }
}
</style>

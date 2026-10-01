<template>
  <article class="ticket-stub" :class="{ 'ticket-stub-winning': isWinning }">
    <div class="ticket-stub-main">
      <div class="ticket-stub-mark">
        <span class="lottery-six">L6</span>
        <span class="ticket-stub-price">80<br>บาท</span>
      </div>
      <div class="ticket-stub-body">
        <div class="ticket-brand mb-2">
          <span>สลากกินแบ่งรัฐบาล</span>
        </div>
        <LotteryNumber :number="number" compact />
      </div>
      <div class="ticket-stub-status">
        <div class="ticket-status-text" :class="statusToneClass">{{ status }}</div>
      </div>
      <span class="side-label">สลากดิจิทัล</span>
    </div>
    <div v-if="isWinning" class="ticket-stub-reward">
      <div class="ticket-stub-reward-copy">
        <strong>{{ prizeTitle || 'ถูกรางวัล' }}</strong>
        <div v-if="prizes.length > 1" class="ticket-stub-prize-list">
          <span v-for="(prize, index) in prizes" :key="`${prize.prize_type || index}-${prize.prize_number || index}`">
            {{ prize.title || 'ถูกรางวัล' }} {{ formatPrizeAmount(prize.amount) }} บาท
          </span>
        </div>
        <span v-if="prizeAmount">รับเงินรางวัล {{ prizeAmount }} บาท</span>
      </div>
      <NuxtLink v-if="claimTo" class="ticket-claim-button" :to="claimTo" @click.stop>
        {{ claimLabel }}
      </NuxtLink>
      <span v-else class="ticket-claim-button">{{ claimLabel }}</span>
    </div>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps({
  number: {
    type: String,
    required: true
  },
  status: {
    type: String,
    default: ''
  },
  isWinning: {
    type: Boolean,
    default: false
  },
  prizeTitle: {
    type: String,
    default: ''
  },
  prizeAmount: {
    type: String,
    default: ''
  },
  prizes: {
    type: Array,
    default: () => []
  },
  claimLabel: {
    type: String,
    default: 'ขึ้นรางวัล'
  },
  claimTo: {
    type: String,
    default: ''
  }
})

const statusToneClass = computed(() => {
  const statusText = props.status.trim()

  if (statusText === 'ขึ้นเงินแล้ว') {
    return 'status-success'
  }

  if (statusText === 'ขึ้นเงินไม่สำเร็จ') {
    return 'status-danger'
  }

  return props.isWinning ? 'winning' : ''
})

const formatPrizeAmount = (amount: unknown) => {
  const value = Number(amount || 0)

  return Number.isFinite(value) ? value.toLocaleString('th-TH') : '0'
}
</script>

<style scoped>
.ticket-stub-prize-list {
  display: grid;
  gap: 2px;
  margin-top: 2px;
}

.ticket-stub-prize-list span {
  color: #8a5a00;
  font-size: 11px;
  font-weight: 800;
  line-height: 1.25;
}

.ticket-status-text.status-success {
  color: #16a34a;
}

.ticket-status-text.status-danger {
  color: #dc2626;
}
</style>

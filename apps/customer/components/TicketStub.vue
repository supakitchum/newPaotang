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
        <div class="ticket-status-text" :class="{ winning: isWinning }">{{ status }}</div>
      </div>
    </div>
    <div v-if="isWinning" class="ticket-stub-reward">
      <div class="ticket-stub-reward-copy">
        <strong>{{ prizeTitle || 'ถูกรางวัล' }}</strong>
        <span v-if="prizeAmount">รับเงินรางวัล {{ prizeAmount }} บาท</span>
      </div>
      <span class="ticket-claim-button">{{ claimLabel }}</span>
    </div>
    <span class="side-label">สลากดิจิทัล</span>
  </article>
</template>

<script setup lang="ts">
defineProps({
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
  claimLabel: {
    type: String,
    default: 'ขึ้นรางวัล'
  }
})
</script>

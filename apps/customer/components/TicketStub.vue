<template>
  <article class="ticket-stub" :class="{ 'ticket-stub-winning': isWinning, 'ticket-stub-has-image': showRemoteImage }">
    <div v-if="showRemoteImage" class="ticket-stub-image-main">
      <img
        :src="normalizedImageUrl"
        :alt="imageAlt"
        loading="lazy"
        decoding="async"
        @error="hasImageError = true"
      >
      <div v-if="status" class="ticket-stub-image-status">
        <span class="ticket-status-text" :class="statusToneClass">{{ status }}</span>
      </div>
    </div>
    <div v-else class="ticket-stub-main">
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
import { computed, ref, watch } from 'vue'

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
  },
  imageUrl: {
    type: String,
    default: ''
  },
  imageStatus: {
    type: String,
    default: ''
  }
})

const hasImageError = ref(false)

const normalizedImageUrl = computed(() => {
  const imageUrl = String(props.imageUrl || '').trim()

  if (!imageUrl) {
    return ''
  }

  if (/^https?:\/\//i.test(imageUrl) || imageUrl.startsWith('data:')) {
    return imageUrl
  }

  return imageUrl.startsWith('/') ? imageUrl : `/${imageUrl.replace(/^\/+/, '')}`
})
const normalizedImageStatus = computed(() => String(props.imageStatus || '').toLowerCase())
const showRemoteImage = computed(() => (
  Boolean(normalizedImageUrl.value)
  && !hasImageError.value
  && !['pending_assets', 'missing'].includes(normalizedImageStatus.value)
))
const imageAlt = computed(() => `รูปสลากฯ เลข ${String(props.number || '').replace(/\D/g, '').padStart(6, '0').slice(-6)}`)
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

watch(() => [props.imageUrl, props.imageStatus], () => {
  hasImageError.value = false
})
</script>

<style scoped>
.ticket-stub-has-image {
  min-height: 0;
}

.ticket-stub-image-main {
  aspect-ratio: 500 / 280;
  background: #f5f7fb;
  min-height: 132px;
  padding-right: 22px;
  position: relative;
}

.ticket-stub-image-main img {
  background: #f5f7fb;
  display: block;
  height: 100%;
  object-fit: contain;
  width: 100%;
}

.ticket-stub-image-status {
  background: rgba(255, 255, 255, .86);
  border: 1px solid rgba(211, 222, 239, .92);
  border-radius: 999px;
  box-shadow: 0 5px 12px rgba(20, 38, 72, .12);
  padding: 4px 8px;
  position: absolute;
  right: 30px;
  top: 8px;
}

.ticket-stub-image-status .ticket-status-text {
  font-size: 12px;
  line-height: 1;
}

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

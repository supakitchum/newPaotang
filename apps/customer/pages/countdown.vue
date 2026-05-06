<template>
  <MobileShell time="12:00">
    <section class="countdown-page">
      <div class="countdown-brand">
        <BrandLogo />
        <span class="lottery-six fs-2">L6</span>
      </div>

      <div class="countdown-copy">
        <p class="countdown-kicker">รอเปิดงวดใหม่</p>
        <h1>จะเปิดขายในอีก</h1>
        <p class="countdown-draw">งวดวันที่ {{ currentDrawDate }}</p>
      </div>

      <div class="countdown-grid" aria-label="เวลานับถอยหลัง">
        <div v-for="item in countdownItems" :key="item.label" class="countdown-cell">
          <strong>{{ item.value }}</strong>
          <span>{{ item.label }}</span>
        </div>
      </div>

      <div class="countdown-actions">
        <NuxtLink class="outline-pill" to="/result">
          <i class="bi bi-trophy me-2" />ตรวจผลรางวัล
        </NuxtLink>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

definePageMeta({
  requiresAuth: false
})

const { currentGame, currentDrawDate, refreshAppInit, currentStatus } = useAppInit()
const now = ref(Date.now())
const isCheckingStatus = ref(false)
let timer: ReturnType<typeof setInterval> | null = null

const startAt = computed(() => {
  const value = currentGame.value?.start_at
  const timestamp = value ? Date.parse(String(value)) : Number.NaN

  return Number.isNaN(timestamp) ? null : timestamp
})
const remainingMilliseconds = computed(() => Math.max(0, (startAt.value || now.value) - now.value))
const countdownItems = computed(() => {
  const totalSeconds = Math.floor(remainingMilliseconds.value / 1000)
  const days = Math.floor(totalSeconds / 86400)
  const hours = Math.floor((totalSeconds % 86400) / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60

  return [
    { label: 'วัน', value: String(days).padStart(2, '0') },
    { label: 'ชั่วโมง', value: String(hours).padStart(2, '0') },
    { label: 'นาที', value: String(minutes).padStart(2, '0') },
    { label: 'วินาที', value: String(seconds).padStart(2, '0') }
  ]
})

const tick = async () => {
  now.value = Date.now()

  if (remainingMilliseconds.value <= 0 && !isCheckingStatus.value) {
    isCheckingStatus.value = true
    await refreshAppInit()

    if (currentStatus.value !== 3) {
      await navigateTo(currentStatus.value === 1 ? '/buy' : '/result')
    }

    isCheckingStatus.value = false
  }
}

onMounted(() => {
  timer = setInterval(tick, 1000)
})

onBeforeUnmount(() => {
  if (timer) {
    clearInterval(timer)
  }
})
</script>

<style scoped>
.countdown-page {
  min-height: 100dvh;
  padding: 68px var(--content-pad) 32px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 28px;
  color: #fff;
  text-align: center;
  background: linear-gradient(135deg, #087ff0 0%, #0a66c8 58%, #163970 100%);
}

.countdown-brand {
  display: flex;
  align-items: center;
  gap: 16px;
}

.countdown-copy {
  max-width: 520px;
}

.countdown-kicker,
.countdown-draw {
  margin: 0;
  font-weight: 600;
  opacity: .92;
}

.countdown-kicker {
  color: #ffd10b;
}

.countdown-copy h1 {
  margin: 8px 0;
  font-size: clamp(34px, 8vw, 58px);
  font-weight: 800;
  line-height: 1.08;
}

.countdown-grid {
  width: min(100%, 560px);
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
}

.countdown-cell {
  min-width: 0;
  padding: 16px 8px;
  border: 1px solid rgba(255, 255, 255, .28);
  border-radius: 8px;
  background: rgba(0, 35, 88, .26);
  backdrop-filter: blur(10px);
}

.countdown-cell strong {
  display: block;
  font-size: clamp(26px, 7vw, 44px);
  line-height: 1;
}

.countdown-cell span {
  display: block;
  margin-top: 8px;
  font-size: 13px;
  font-weight: 600;
  opacity: .86;
}

.countdown-actions {
  display: flex;
  justify-content: center;
}

.countdown-actions .outline-pill {
  color: #fff;
  border-color: rgba(255, 255, 255, .68);
  background: rgba(255, 255, 255, .12);
}

@media (max-width: 380px) {
  .countdown-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>

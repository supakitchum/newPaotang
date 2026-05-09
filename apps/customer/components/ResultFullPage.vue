<template>
  <MobileShell time="12:38">
    <BlueHeader
      :title="`ผลรางวัลงวดวันที่ ${drawDate}`"
      back-to="/results"
      min-height="121px"
      class="result-full-hero"
    />
    <section class="content-sheet result-full-sheet">
      <div class="result-highlight-grid">
        <div>
          <div class="result-label">รางวัลที่ 1</div>
          <div class="result-subtitle">รางวัลละ 6,000,000 บาท</div>
            <div class="result-number result-first">{{ summary.first }}</div>
        </div>
        <div>
          <div class="result-label">เลขท้าย 2 ตัว</div>
          <div class="result-subtitle">รางวัลละ 2,000 บาท</div>
            <div class="result-number result-first">{{ summary.last2 }}</div>
        </div>
        <div>
          <div class="result-label">เลขหน้า 3 ตัว</div>
          <div class="result-subtitle">รางวัลละ 4,000 บาท</div>
            <div class="result-number small">{{ summary.front3.join(' ') }}</div>
        </div>
        <div>
          <div class="result-label">เลขท้าย 3 ตัว</div>
          <div class="result-subtitle">รางวัลละ 4,000 บาท</div>
            <div class="result-number small">{{ summary.last3.join(' ') }}</div>
        </div>
      </div>

      <section class="result-bar">
        <span>รางวัลข้างเคียงรางวัลที่ 1</span>
        <span class="muted-text">รางวัลละ 100,000 บาท</span>
      </section>
      <div class="result-number-grid result-number-grid-pair">
        <span v-for="number in besideFirst" :key="number">{{ number }}</span>
      </div>

      <PrizeGroup
        v-for="group in detailGroups"
        :key="group.key"
        :title="group.title"
        :amount="group.amount"
        :numbers="group.numbers"
      />

      <div class="payment-dock text-center muted-text">
        คุณสามารถขึ้นเงินรางวัลได้ที่ ธนาคารกรุงไทย ธ.ก.ส. ออมสิน ทุกสาขา หรือสำนักงานสลากกินแบ่งรัฐบาล
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { LotteryRewardGame } from '~/composables/useLotteryReward'
import { formatDrawDateText } from '~/utils/formatDrawDate'

const route = useRoute()
const platformApi = usePlatformApi()
const {
  getRewardGroups,
  getRewardNumbers,
  toSummary
} = useLotteryReward()
const game = ref<LotteryRewardGame | null>(null)
const requestedGameId = computed(() => {
  const value = Array.isArray(route.query.game_id) ? route.query.game_id[0] : route.query.game_id

  return value ? String(value) : ''
})
const drawDate = computed(() => formatDrawDateText(game.value?.name))
const summary = computed(() => toSummary(game.value))
const besideFirst = computed(() => getRewardNumbers(game.value, 'reward_beside_1'))
const detailGroups = computed(() => getRewardGroups(game.value).filter((group) => ![
  'reward_1',
  'reward_two_digit',
  'reward_three_digit_1',
  'reward_three_digit_2',
  'reward_beside_1'
].includes(group.key)))

onMounted(async () => {
  const response = await platformApi.rewardLegacy(requestedGameId.value || undefined)

  if (response.code === 0) {
    game.value = response.result || null
  }
})
</script>

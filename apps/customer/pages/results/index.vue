<template>
  <MobileShell time="12:36">
    <BlueHeader title="ผลรางวัลสลากฯ" back-to="/" min-height="386px" class="results-index-hero">
      <section v-if="isLoading" class="result-card result-card-featured result-inline-state">
        กำลังโหลดผลรางวัล
      </section>
      <ResultSummaryCard v-else-if="game" :date="drawDate" :result="toSummary(game)" link="/results/full" variant="featured" />
    </BlueHeader>
    <section class="results-history-sheet">
      <h2 class="section-title fs-5 mb-4">ผลรางวัลสลากฯ ย้อนหลัง</h2>
      <ResultSummaryCard
        v-for="result in historyGames"
        :key="result.id || result.name"
        :date="formatDrawDateText(result.name)"
        :result="toSummary(result)"
        link="/results/full"
        variant="history"
        class="mb-4"
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

definePageMeta({
  requiresAuth: false
})

const platformApi = usePlatformApi()
const { toSummary } = useLotteryReward()
const game = ref<LotteryRewardGame | null>(null)
const historyGames = ref<LotteryRewardGame[]>([])
const isLoading = ref(true)
const drawDate = computed(() => formatDrawDateText(game.value?.name))

onMounted(async () => {
  try {
    const liveResponse = await platformApi.rewardLiveLegacy()
    const response = liveResponse.result ? liveResponse : await platformApi.rewardLegacy()

    if (response.code === 0) {
      game.value = response.result || null
      historyGames.value = response.history || []
    }
  } finally {
    isLoading.value = false
  }
})

</script>

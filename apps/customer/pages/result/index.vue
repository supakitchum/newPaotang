<template>
  <MobileShell time="12:36">
    <BlueHeader title="ผลรางวัลสลากฯ" back-to="/" min-height="386px" class="results-index-hero">
      <section v-if="isLoading" class="result-card result-card-featured result-inline-state">
        <i class="bi bi-arrow-repeat" />
        <span>กำลังโหลดผลรางวัล</span>
      </section>

      <section v-else-if="errorMessage" class="result-card result-card-featured result-inline-state">
        <i class="bi bi-exclamation-circle text-danger" />
        <span>{{ errorMessage }}</span>
        <button class="outline-pill result-inline-retry" type="button" @click="fetchReward">
          ลองใหม่
        </button>
      </section>

      <section v-else-if="isWaitingResult" class="result-card result-card-featured result-inline-state">
        <i class="bi bi-hourglass-split text-primary" />
        <span>กำลังรอออกผล {{ drawDate }}</span>
      </section>

      <ResultSummaryCard
        v-else
        :date="drawDate"
        :link="fullLink(game)"
        :result="currentSummary"
        variant="featured"
      />
    </BlueHeader>

    <section class="results-history-sheet">
      <h2 class="section-title fs-5 mb-4">ผลรางวัลสลากฯ ย้อนหลัง</h2>

      <div v-if="isLoading" class="muted-text text-center py-4">
        กำลังโหลดข้อมูลงวดย้อนหลัง
      </div>

      <div v-else-if="!historyGames.length" class="muted-text text-center py-4">
        ยังไม่มีข้อมูลผลรางวัลงวดย้อนหลัง
      </div>

      <ResultSummaryCard
        v-for="history in historyGames"
        :key="history.id || history.name"
        :date="formatDrawDateText(history.name)"
        :link="fullLink(history)"
        :result="toSummary(history)"
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
const game = ref<LotteryRewardGame | null>(null)
const historyGames = ref<LotteryRewardGame[]>([])
const isLoading = ref(true)
const errorMessage = ref('')
const { toSummary } = useLotteryReward()

const drawDate = computed(() => formatDrawDateText(game.value?.name))
const isWaitingResult = computed(() => Number(game.value?.status) === 1)
const currentSummary = computed(() => toSummary(game.value))

const fullLink = (item: LotteryRewardGame | null | undefined) => {
  return item?.id ? `/result/full?game_id=${item.id}` : '/result/full'
}

const fetchReward = async () => {
  isLoading.value = true
  errorMessage.value = ''

  try {
    const response = await platformApi.rewardLegacy()

    if (response.data?.code === 0) {
      game.value = response.data.result || null
      historyGames.value = response.data.history || response.data.histories || []
      return
    }

    errorMessage.value = response.data?.message || 'ไม่พบข้อมูลผลรางวัล'
  } catch (error) {
    errorMessage.value = (error as { response?: { data?: { message?: string } } }).response?.data?.message || 'กรุณาลองใหม่อีกครั้ง'
  } finally {
    isLoading.value = false
  }
}

onMounted(fetchReward)
</script>

<style scoped>
.result-inline-state {
  min-height: 181px;
  display: grid;
  align-content: center;
  justify-items: center;
  gap: 10px;
  color: #20385f;
  text-align: center;
  font-weight: 700;
}

.result-inline-state i {
  font-size: 32px;
}

.result-inline-retry {
  margin-top: 6px;
}
</style>

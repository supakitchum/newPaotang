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

      <ResultSummaryCard
        v-else-if="currentDisplayGame"
        :date="drawDate"
        :link="fullLink(currentDisplayGame)"
        :result="currentSummary"
        :unofficial="hasResolvedRewardSummary(currentDisplayGame) && isUnofficialReward(currentDisplayGame)"
        variant="featured"
      />

      <section v-else class="result-card result-card-featured result-inline-state">
        <i class="bi bi-hourglass-split text-primary" />
        <span>ยังไม่มีข้อมูลผลรางวัลล่าสุด</span>
      </section>
    </BlueHeader>

    <section class="results-history-sheet">
      <h2 class="section-title fs-5 mb-4">ผลรางวัลสลากฯ ย้อนหลัง</h2>

      <div v-if="isLoading" class="muted-text text-center py-4">
        กำลังโหลดข้อมูลงวดย้อนหลัง
      </div>

      <div v-else-if="!displayHistoryGames.length" class="muted-text text-center py-4">
        ยังไม่มีข้อมูลผลรางวัลงวดย้อนหลัง
      </div>

      <ResultSummaryCard
        v-for="history in displayHistoryGames"
        :key="history.id || history.name"
        :date="formatDrawDateText(history.name)"
        :link="fullLink(history)"
        :result="toSummary(history)"
        :unofficial="isUnofficialReward(history)"
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
const { currentGame, currentDrawDate, ensureAppInit } = useAppInit()
const game = ref<LotteryRewardGame | null>(null)
const historyGames = ref<LotteryRewardGame[]>([])
const isLoading = ref(true)
const errorMessage = ref('')
const { isResolvedRewardNumber, toSummary } = useLotteryReward()

const normalizeId = (value: unknown) => String(value || '').trim()
const currentGameId = computed(() => normalizeId(currentGame.value?.id))
const currentFallbackGame = computed<LotteryRewardGame | null>(() => {
  if (!currentGame.value) {
    return null
  }

  return {
    id: currentGame.value.id,
    name: String(currentGame.value.name || ''),
    status: Number(currentGame.value.status) || 1,
    rewards: []
  }
})
const currentDisplayGame = computed(() => game.value || currentFallbackGame.value)
const drawDate = computed(() => {
  const displayDate = formatDrawDateText(currentDisplayGame.value?.name)

  if (displayDate !== '-') {
    return displayDate
  }

  return currentDrawDate.value !== '-' ? currentDrawDate.value : 'รอข้อมูลวันออกผล'
})
const currentSummary = computed(() => toSummary(currentDisplayGame.value))
const hasResolvedRewardSummary = (item: LotteryRewardGame | null | undefined) => {
  const summary = toSummary(item)

  return [
    summary.first,
    summary.last2,
    ...summary.front3,
    ...summary.last3
  ].some(isResolvedRewardNumber)
}
const displayHistoryGames = computed(() => {
  const currentId = normalizeId(currentDisplayGame.value?.id || currentGameId.value)

  return historyGames.value.filter((history) => {
    const historyId = normalizeId(history.id)
    const summary = toSummary(history)
    const hasResolvedSummary = [
      summary.first,
      summary.last2,
      ...summary.front3,
      ...summary.last3
    ].some(isResolvedRewardNumber)

    return hasResolvedSummary && (!currentId || historyId !== currentId)
  })
})

const isUnofficialReward = (item: LotteryRewardGame | null | undefined) => (
  Boolean(item) && Number(item?.status) !== 2
)

const fullLink = (item: LotteryRewardGame | null | undefined) => {
  return item?.id ? `/result/full?game_id=${item.id}` : '/result/full'
}

const fetchReward = async (silent = false) => {
  if (!silent) {
    isLoading.value = true
  }
  errorMessage.value = ''

  try {
    await ensureAppInit()

    const rewardGameId = currentGameId.value || undefined
    const liveResponse = await platformApi.rewardLiveLegacy(rewardGameId)
    const livePayload = liveResponse.data || liveResponse

    if (livePayload.code === 0 && livePayload.result) {
      game.value = livePayload.result || null
    } else {
      const response = await platformApi.rewardLegacy(rewardGameId)
      const payload = response.data || response

      if (payload.code === 0) {
        game.value = payload.result || null
      } else {
        game.value = null
        errorMessage.value = payload.message || 'ไม่พบข้อมูลผลรางวัล'
      }
    }

    const latestPublishedResponse = await platformApi.rewardLegacy()
    const latestPublishedPayload = latestPublishedResponse.data || latestPublishedResponse
    const latestPublished = latestPublishedPayload.code === 0 ? latestPublishedPayload.result || null : null

    historyGames.value = latestPublished && normalizeId(latestPublished.id) !== normalizeId(currentDisplayGame.value?.id || currentGameId.value)
      ? [latestPublished]
      : []

    if (!currentDisplayGame.value && !latestPublished) {
      errorMessage.value = errorMessage.value || 'ไม่พบข้อมูลผลรางวัล'
    }
  } catch (error) {
    errorMessage.value = (error as { response?: { data?: { message?: string } } }).response?.data?.message || 'กรุณาลองใหม่อีกครั้ง'
  } finally {
    if (!silent) {
      isLoading.value = false
    }
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

<template>
  <MobileShell time="13:16" active-nav="tickets" show-bottom-nav>
    <section class="waiting-result-page">
      <div class="waiting-result-hero">
        <div class="waiting-result-mark">
          <BrandLogo />
          <span class="lottery-six">L6</span>
        </div>

        <div class="waiting-result-copy">
          <p>หมดเวลาจำหน่ายสลากแล้ว</p>
          <h1>{{ waitingResultTitle }}</h1>
    <!--          <span>{{ currentGameName }}</span>-->
        </div>

        <section class="waiting-result-result" aria-live="polite">
          <section v-if="isRewardLoading" class="result-card result-card-featured waiting-result-state">
            <i class="bi bi-arrow-repeat" />
            <span>กำลังโหลดผลรางวัล</span>
          </section>

          <section v-else-if="rewardErrorMessage" class="result-card result-card-featured waiting-result-state">
            <i class="bi bi-exclamation-circle text-danger" />
            <span>{{ rewardErrorMessage }}</span>
            <button class="outline-pill waiting-result-retry" type="button" @click="fetchReward">
              ลองใหม่
            </button>
          </section>

          <ResultSummaryCard
              v-else
              :date="rewardDrawDate"
              :result="rewardSummary"
              :unofficial="isUnofficialReward"
              link="/result/full"
              variant="featured"
          />
        </section>

        <section class="waiting-result-live" aria-labelledby="waiting-result-live-title">
          <div class="waiting-result-section-head">
            <i class="bi bi-youtube" />
            <h2 id="waiting-result-live-title">ถ่ายทอดสดประกาศผล</h2>
          </div>

          <div v-if="youtubeEmbedUrl" class="waiting-result-live-frame" :class="{ 'is-alert-open': alertState.visible }">
            <iframe
                :src="youtubeEmbedUrl"
                title="ถ่ายทอดสดประกาศผลรางวัล"
                loading="lazy"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                referrerpolicy="strict-origin-when-cross-origin"
                allowfullscreen
            />
          </div>

          <div v-else class="waiting-result-live-empty">
            ระบบจะแสดงถ่ายทอดสดเมื่อพร้อมใช้งาน
          </div>
        </section>


        <div class="waiting-result-actions">
          <NuxtLink class="primary-pill" to="/tickets">
            <i class="bi bi-ticket-perforated me-2" />สลากของฉัน
          </NuxtLink>
          <NuxtLink class="outline-pill" to="/result">
            <i class="bi bi-trophy me-2" />ตรวจผลรางวัล
          </NuxtLink>
        </div>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { LotteryRewardGame } from '~/composables/useLotteryReward'
import { sanitizeYoutubeEmbedUrl } from '~/utils/youtubeEmbed.js'

definePageMeta({
  alias: ['/wait-result'],
  requiresAuth: false
})

const platformApi = usePlatformApi()
const runtimeConfig = useRuntimeConfig()
const route = useRoute()
const { currentGame, ensureAppInit } = useAppInit()
const { config: siteConfig, fetchSiteConfig } = useSiteConfig()
const { alertState, showAlert } = useAppAlert()
const { isResolvedRewardNumber, toSummary } = useLotteryReward()

const rewardGame = ref<LotteryRewardGame | null>(null)
const isRewardLoading = ref(true)
const rewardErrorMessage = ref('')

const liveRewardTypeMap: Record<string, string> = {
  first_prize: 'reward_1',
  back2: 'reward_two_digit',
  front3: 'reward_three_digit_1',
  back3: 'reward_three_digit_2',
  near_first_prize: 'reward_beside_1',
  second_prize: 'reward_2',
  third_prize: 'reward_3',
  fourth_prize: 'reward_4',
  fifth_prize: 'reward_5'
}

const normalizeDisplayText = (value: unknown) => {
  const label = typeof value === 'string' ? value.trim() : ''

  return label && !['undefined', 'null'].includes(label.toLowerCase()) ? label : ''
}

const currentGameName = computed(() => normalizeDisplayText(currentGame.value?.name) || 'รอข้อมูลเกมปัจจุบัน')
const currentRewardGameId = computed(() => normalizeDisplayText(currentGame.value?.id))
const fallbackRewardGame = computed<LotteryRewardGame>(() => ({
  id: currentGame.value?.id || 'pending',
  name: normalizeDisplayText(currentGame.value?.name) || currentGameName.value,
  status: Number(currentGame.value?.status) || 1,
  rewards: []
}))
const rewardDisplayGame = computed(() => rewardGame.value || fallbackRewardGame.value)
const rewardSummary = computed(() => toSummary(rewardDisplayGame.value))
const rewardDrawDate = computed(() => normalizeDisplayText(rewardGame.value?.name) || currentGameName.value)
const isUnofficialReward = computed(() => Boolean(rewardGame.value) && Number(rewardGame.value?.status) !== 2)
const youtubeLiveUrl = computed(() => (
  normalizeDisplayText(siteConfig.value?.live?.waiting_result_youtube_url)
  || normalizeDisplayText(runtimeConfig.public.waitingResultYoutubeUrl)
))
const youtubeEmbedUrl = computed(() => sanitizeYoutubeEmbedUrl(youtubeLiveUrl.value))
const hasResolvedRewardSummary = computed(() => [
  rewardSummary.value.first,
  rewardSummary.value.last2,
  ...rewardSummary.value.front3,
  ...rewardSummary.value.last3
].some(isResolvedRewardNumber))
const rewardBelongsToCurrentGame = computed(() => {
  if (!currentRewardGameId.value) {
    return Boolean(rewardGame.value)
  }

  return normalizeDisplayText(rewardGame.value?.id) === currentRewardGameId.value
})
const hasCurrentGameRewardResult = computed(() => hasResolvedRewardSummary.value && rewardBelongsToCurrentGame.value)
const waitingResultTitle = computed(() => hasCurrentGameRewardResult.value ? 'ออกรางวัลแล้ว' : 'รอประกาศผลรางวัล')

const consumeSaleClosedNotice = async () => {
  if (String(route.query.sale_closed || '') !== '1') {
    return
  }

  showAlert({
    title: 'หมดเวลาจำหน่ายสลากแล้ว',
    message: 'หมดเวลาจำหน่ายสลากแล้ว กรุณารอประกาศผลรางวัล',
    variant: 'warning'
  })

  const query = { ...route.query }
  delete query.sale_closed
  await navigateTo({ path: route.path, query }, { replace: true })
}

const applyLiveRewardPayload = (payload: any) => {
  if (!payload || !Array.isArray(payload.prizes)) {
    return
  }

  if (currentRewardGameId.value && normalizeDisplayText(payload.game_id) !== currentRewardGameId.value) {
    return
  }

  const grouped = new Map<string, any>()

  payload.prizes.forEach((prize: any) => {
    const slug = liveRewardTypeMap[String(prize.prize_type || '')] || String(prize.prize_type || '')
    const existing = grouped.get(slug) || {
      id: slug,
      game_id: payload.game_id,
      name: slug,
      reward: prize.amount?.amount || prize.reward || 0,
      slug,
      number: []
    }

    existing.number = [...existing.number, String(prize.prize_number || '')].filter(Boolean)
    grouped.set(slug, existing)
  })

  rewardGame.value = {
    id: payload.game_id,
    name: payload.game_name || payload.draw_code || payload.game_code || '',
    status: String(payload.official_status || payload.status || '').toLowerCase() === 'published' ? 2 : 1,
    rewards: Array.from(grouped.values())
  }
}

const fetchReward = async () => {
  isRewardLoading.value = true
  rewardErrorMessage.value = ''
  const rewardGameId = currentRewardGameId.value || undefined

  try {
    const liveResponse = await platformApi.rewardLiveLegacy(rewardGameId)
    const livePayload = liveResponse.data || liveResponse

    if (livePayload.code === 0 && livePayload.result) {
      rewardGame.value = livePayload.result
      return
    }

    const response = await platformApi.rewardLegacy(rewardGameId)
    const payload = response.data || response

    if (payload.code === 0) {
      rewardGame.value = payload.result || null
      return
    }

    rewardGame.value = null
    rewardErrorMessage.value = payload.message || 'ไม่พบข้อมูลผลรางวัล'
  } catch (error) {
    rewardGame.value = null
    rewardErrorMessage.value = (error as { response?: { data?: { message?: string } } }).response?.data?.message || 'กรุณาลองใหม่อีกครั้ง'
  } finally {
    isRewardLoading.value = false
  }
}

useLotteryResultRealtime({
  gameId: currentRewardGameId,
  onResult: applyLiveRewardPayload,
  onReconnect: fetchReward
})

onMounted(async () => {
  await Promise.all([
    ensureAppInit(),
    fetchSiteConfig()
  ])
  await consumeSaleClosedNotice()
  await fetchReward()
})
</script>

<style scoped>
.waiting-result-page {
  min-height: 100dvh;
  padding: 76px var(--content-pad) 120px;
  display: grid;
  align-content: start;
  justify-items: center;
  gap: 22px;
  text-align: center;
  color: #12315c;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, .82), rgba(245, 249, 255, .96)),
    linear-gradient(135deg, #e8f3ff 0%, #f7fbff 42%, #fff7dd 100%);
}

.waiting-result-hero {
  width: min(100%, 520px);
  display: grid;
  justify-items: center;
  gap: 28px;
}

.waiting-result-mark {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14px;
}

.waiting-result-mark .lottery-six {
  font-size: 34px;
}

.waiting-result-copy {
  max-width: 520px;
}

.waiting-result-copy p,
.waiting-result-copy span {
  margin: 0;
  color: #4b6689;
  font-weight: 700;
}

.waiting-result-copy h1 {
  margin: 10px 0;
  font-size: clamp(34px, 9vw, 58px);
  line-height: 1.08;
  font-weight: 800;
  color: #0b69dc;
}

.waiting-result-actions {
  width: min(100%, 360px);
  display: grid;
  gap: 12px;
}

.waiting-result-actions a {
  min-height: 50px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  text-decoration: none;
}

.waiting-result-result,
.waiting-result-live {
  width: min(100%, 520px);
}

.waiting-result-result :deep(.result-number-list) {
  justify-content: center;
}

.waiting-result-result :deep(.result-number-list span) {
  display: inline-flex;
  justify-content: center;
  text-align: center;
}

.waiting-result-state {
  min-height: 168px;
  display: grid;
  align-content: center;
  justify-items: center;
  gap: 10px;
  color: #20385f;
  font-weight: 700;
}

.waiting-result-state i {
  font-size: 30px;
}

.waiting-result-retry {
  margin-top: 4px;
  padding: 10px 24px;
}

.waiting-result-live {
  padding: 18px;
  display: grid;
  gap: 14px;
  overflow: hidden;
  border: 1px solid rgba(8, 127, 240, .12);
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 8px 24px rgba(33, 55, 85, .08);
}

.waiting-result-section-head {
  display: flex;
  align-items: center;
  gap: 10px;
  text-align: left;
}

.waiting-result-section-head i {
  color: #e62117;
  font-size: 24px;
}

.waiting-result-section-head h2 {
  margin: 0;
  color: #20385f;
  font-size: 18px;
  font-weight: 800;
}

.waiting-result-live-frame {
  position: relative;
  width: 100%;
  overflow: hidden;
  border-radius: 8px;
  background: #10213b;
  aspect-ratio: 16 / 9;
}

.waiting-result-live-frame iframe {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  border: 0;
}

.waiting-result-live-frame.is-alert-open iframe {
  pointer-events: none;
}

.waiting-result-live-empty {
  min-height: 124px;
  display: grid;
  place-items: center;
  padding: 18px;
  border-radius: 8px;
  color: #4b6689;
  background: #f5f9ff;
  font-weight: 700;
}
</style>

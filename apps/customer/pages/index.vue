<template>
  <MobileShell active-nav="home" show-bottom-nav>
    <BlueHeader close min-height="352px">
      <div class="d-flex align-items-start justify-content-between mt-2">
        <BrandLogo />
        <div class="text-center me-5">
          <div class="d-inline-grid place-center rounded-circle bg-warning text-white fw-bold" style="width:60px;height:60px;">
            <span class="fs-5 lh-1">80</span>
            <span class="small lh-1">บาท</span>
          </div>
        </div>
      </div>
      <div class="mt-4">
        <h1 class="display-6 fw-bold mb-3">สลากหกหลัก</h1>
        <div class="d-flex justify-content-between align-items-start">
          <div>
            <h2 class="fs-5 fw-bold mb-1">ค้นหาเลขเด็ด <i class="bi bi-info-circle ms-1 fs-6" /></h2>
            <div>งวดวันที่ {{ drawDate }}</div>
          </div>
          <div class="rounded-3 px-3 py-2 text-end" style="background:rgba(0,52,126,.54)">
            <div>เปิดขายงวดนี้</div>
            <div class="text-warning fs-5 fw-bold">30 ล้านใบ!</div>
          </div>
        </div>
        <DigitBoxes class="home-digit-boxes" :digits="luckyDigits" />
      </div>
    </BlueHeader>

    <section class="content-sheet home-sheet">
      <div class="rounded-panel home-quick-card mb-4">
        <NuxtLink class="quick-action" to="/buy">
          <span class="quick-illustration"><i class="bi bi-phone" /></span>
          <span>ซื้อสลากดิจิทัล</span>
        </NuxtLink>
        <NuxtLink class="quick-action" to="/stores">
          <span class="quick-illustration"><i class="bi bi-qr-code-scan" /></span>
          <span>สแกนซื้อสลากฯ</span>
        </NuxtLink>
      </div>

      <section v-if="isRewardLoading" class="result-card mb-3 text-center muted-text">
        กำลังโหลดผลรางวัล
      </section>

      <ResultSummaryCard
        v-else-if="resultGame"
        :date="resultGame.name || '-'"
        :result="resultSummary"
        :link="'/result'"
        class="mb-3"
      />

      <section v-else class="result-card mb-3 text-center muted-text">
        ยังไม่มีข้อมูลผลรางวัล
      </section>

      <section v-if="newsItems.length" class="home-news-slider" aria-label="ข่าวสารและกิจกรรม">
        <a
          class="home-news-slide"
          :href="currentNewsLink"
          :target="currentNewsLinkTarget"
          rel="noopener"
          @click="handleNewsClick"
        >
          <img v-if="currentNewsCover" :src="currentNewsCover" :alt="currentNews?.title || 'ข่าวสารและกิจกรรม'">
          <div v-else class="home-news-image-fallback" />
          <div class="home-news-caption">
            <div class="home-news-kicker">ข่าวสารและกิจกรรม</div>
            <h2>{{ currentNews?.title }}</h2>
          </div>
        </a>

        <template v-if="newsItems.length > 1">
          <button class="home-news-nav is-prev" type="button" aria-label="ก่อนหน้า" @click="previousNews">
            <i class="bi bi-chevron-left" />
          </button>
          <button class="home-news-nav is-next" type="button" aria-label="ถัดไป" @click="nextNews">
            <i class="bi bi-chevron-right" />
          </button>
          <div class="home-news-dots" aria-hidden="true">
            <span
              v-for="(_, index) in newsItems"
              :key="`news-dot-${index}`"
              :class="{ active: index === activeNewsIndex }"
            />
          </div>
        </template>
      </section>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { luckyDigits } from '~/data/lottery'
import type { LotteryRewardGame } from '~/composables/useLotteryReward'

interface NewsItem {
  id?: number
  title?: string
  detail?: string | null
  cover?: string
  url?: string | null
  button?: unknown
}

definePageMeta({
  requiresAuth: false
})

const axios = useAxios()
const config = useRuntimeConfig()
const { toSummary } = useLotteryReward()
const { currentDrawDate: drawDate } = useAppInit()
const latestGame = ref<LotteryRewardGame | null>(null)
const historyGames = ref<LotteryRewardGame[]>([])
const isRewardLoading = ref(true)
const newsItems = ref<NewsItem[]>([])
const activeNewsIndex = ref(0)
let newsTimer: ReturnType<typeof setInterval> | null = null

const hasRewardResult = (game: LotteryRewardGame | null | undefined) => {
  if (!game || Number(game.status) !== 2) {
    return false
  }

  const summary = toSummary(game)
  return summary.first !== '-' || summary.last2 !== '-' || summary.front3[0] !== '-' || summary.last3[0] !== '-'
}

const resultGame = computed(() => {
  if (hasRewardResult(latestGame.value)) {
    return latestGame.value
  }

  return historyGames.value.find((game) => hasRewardResult(game)) || null
})

const resultSummary = computed(() => toSummary(resultGame.value))
const apiAssetBaseUrl = computed(() => {
  const baseUrl = config.public.apiBaseUrl || ''
  return `${baseUrl}`.replace(/\/api\/?$/, '').replace(/\/$/, '')
})
const currentNews = computed(() => newsItems.value[activeNewsIndex.value] || null)
const currentNewsCover = computed(() => {
  const cover = currentNews.value?.cover || ''

  if (!cover) {
    return ''
  }

  if (/^https?:\/\//i.test(cover)) {
    return cover
  }

  const normalizedCover = cover.replace(/^\/+/, '')
  const uploadPath = normalizedCover.startsWith('upload/')
    ? normalizedCover
    : `upload/${normalizedCover}`

  return `${apiAssetBaseUrl.value}/${uploadPath}`
})
const currentNewsLink = computed(() => currentNews.value?.url || '#')
const currentNewsLinkTarget = computed(() => /^https?:\/\//i.test(currentNewsLink.value) ? '_blank' : '_self')

const handleNewsClick = (event: MouseEvent) => {
  if (currentNewsLink.value === '#') {
    event.preventDefault()
  }
}

const fetchReward = async () => {
  isRewardLoading.value = true

  try {
    const response = await axios.get('/reward')

    if (response.data?.code === 0) {
      latestGame.value = response.data.result || null
      historyGames.value = response.data.history || response.data.histories || []
    }
  } catch (error) {
    console.log(error)
  } finally {
    isRewardLoading.value = false
  }
}

const stopNewsTimer = () => {
  if (newsTimer) {
    clearInterval(newsTimer)
    newsTimer = null
  }
}

const startNewsTimer = () => {
  stopNewsTimer()

  if (newsItems.value.length <= 1) {
    return
  }

  newsTimer = setInterval(() => {
    nextNews()
  }, 5000)
}

const nextNews = () => {
  if (!newsItems.value.length) {
    return
  }

  activeNewsIndex.value = (activeNewsIndex.value + 1) % newsItems.value.length
}

const previousNews = () => {
  if (!newsItems.value.length) {
    return
  }

  activeNewsIndex.value = (activeNewsIndex.value - 1 + newsItems.value.length) % newsItems.value.length
}

const fetchNews = async () => {
  try {
    const response = await axios.get('/news')

    if (response.data?.code === 0 && Array.isArray(response.data.result)) {
      newsItems.value = response.data.result
      activeNewsIndex.value = 0
      startNewsTimer()
    }
  } catch (error) {
    console.log(error)
  }
}

onMounted(() => {
  fetchReward()
  fetchNews()
})

onBeforeUnmount(stopNewsTimer)
</script>

<style scoped>
.home-news-slider {
  position: relative;
  overflow: hidden;
  border-radius: 8px;
  background: #e9eef6;
  box-shadow: 0 10px 24px rgba(33, 55, 85, .08);
}

.home-news-slide {
  position: relative;
  min-height: 168px;
  display: block;
  color: #fff;
  text-decoration: none;
}

.home-news-slide img {
  width: 100%;
  height: 190px;
  display: block;
  object-fit: cover;
}

.home-news-image-fallback {
  width: 100%;
  height: 190px;
  background: linear-gradient(135deg, #0a87f5 0%, #20385f 100%);
}

.home-news-slide::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, rgba(8, 32, 66, 0) 28%, rgba(8, 32, 66, .74) 100%);
}

.home-news-caption {
  position: absolute;
  z-index: 2;
  right: 18px;
  bottom: 18px;
  left: 18px;
}

.home-news-kicker {
  margin-bottom: 4px;
  font-size: 12px;
  font-weight: 700;
  opacity: .88;
}

.home-news-caption h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 800;
  line-height: 1.2;
}

.home-news-nav {
  position: absolute;
  z-index: 3;
  top: 50%;
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 50%;
  color: #1f375f;
  background: rgba(255, 255, 255, .9);
  transform: translateY(-50%);
}

.home-news-nav.is-prev {
  left: 10px;
}

.home-news-nav.is-next {
  right: 10px;
}

.home-news-dots {
  position: absolute;
  z-index: 3;
  right: 0;
  bottom: 8px;
  left: 0;
  display: flex;
  justify-content: center;
  gap: 6px;
}

.home-news-dots span {
  width: 6px;
  height: 6px;
  border-radius: 999px;
  background: rgba(255, 255, 255, .55);
}

.home-news-dots span.active {
  width: 18px;
  background: #fff;
}
</style>

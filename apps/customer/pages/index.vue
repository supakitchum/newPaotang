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

      <WalletBalanceCard
        v-if="isAuthenticated"
        class="mb-4"
        :balance="walletBalance"
        :loading="isWalletLoading"
        :customer-label="customerNoLabel"
        topup-back-to="/"
        compact
      />

      <section v-else class="home-guest-panel mb-4">
        <div>
          <h2>เริ่มซื้อสลากดิจิทัล</h2>
          <p>เข้าสู่ระบบหรือสมัครสมาชิกก่อนเลือกสลากและชำระเงิน</p>
        </div>
        <div class="home-guest-actions">
          <NuxtLink to="/login">เข้าสู่ระบบ</NuxtLink>
          <NuxtLink to="/register">สมัครสมาชิก</NuxtLink>
        </div>
      </section>

      <section v-if="activityItems.length" class="home-activities-section" aria-label="กิจกรรม">
        <div class="home-section-heading">
          <h2>กิจกรรม</h2>
          <NuxtLink to="/activities">ดูทั้งหมด</NuxtLink>
        </div>
        <div class="home-activities-rail">
          <NuxtLink
            v-for="(activity, index) in activityItems"
            :key="activityKey(activity, index)"
            class="home-activity-card"
            :to="`/activities/${encodeURIComponent(String(activity.slug || ''))}`"
          >
            <img v-if="activityImage(activity)" :src="activityImage(activity)" :alt="activity.name || 'กิจกรรม'">
            <div v-else class="home-activity-image-fallback">
              <i class="bi bi-stars" />
            </div>
            <div class="home-activity-card-body">
              <div class="home-activity-card-top">
                <span>{{ activityTypeLabel(activity) }}</span>
                <i class="bi bi-chevron-right" />
              </div>
              <h3>{{ activity.name || 'กิจกรรมพิเศษ' }}</h3>
              <p>{{ activityConditionText(activity) }}</p>
              <small>{{ activityMeta(activity) }}</small>
            </div>
          </NuxtLink>
        </div>
      </section>

      <section v-if="isRewardLoading" class="result-card mb-3 text-center muted-text">
        กำลังโหลดผลรางวัล
      </section>

      <ResultSummaryCard
        v-else-if="resultGame"
        :date="resultGame.name || '-'"
        :result="resultSummary"
        :link="'/result'"
        :unofficial="isUnofficialReward"
        class="mb-3"
      />

      <section v-else class="result-card mb-3 text-center muted-text">
        ยังไม่มีข้อมูลผลรางวัล
      </section>

      <section v-if="newsItems.length" class="home-news-section" aria-label="ข่าวสารและกิจกรรม">
        <div class="home-news-heading">
          <h2>ข่าวสาร</h2>
          <NuxtLink to="/news">ดูทั้งหมด</NuxtLink>
        </div>
        <div class="home-news-rail">
          <a
            v-for="(news, index) in newsItems"
            :key="newsKey(news, index)"
            class="home-news-card"
            :href="newsLink(news)"
            :target="newsTarget(news)"
            rel="noopener"
            @click="handleNewsClick($event, news)"
          >
            <img v-if="newsCover(news)" :src="newsCover(news)" :alt="news.title || 'ข่าวสารและกิจกรรม'">
            <div v-else class="home-news-image-fallback" />
            <div class="home-news-card-body">
              <h3>{{ news.title || 'ข่าวประชาสัมพันธ์' }}</h3>
              <time v-if="newsPublishedLabel(news)" class="home-news-card-time" :datetime="newsPublishedIso(news)">
                {{ newsPublishedLabel(news) }}
              </time>
              <p v-if="news.detail || news.summary">{{ news.detail || news.summary }}</p>
            </div>
          </a>
        </div>
      </section>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { luckyDigits } from '~/data/lottery'
import type { LotteryRewardGame } from '~/composables/useLotteryReward'
import { activityConditionText, formatActivityBaht } from '~/utils/activityDisplay'

interface NewsItem {
  id?: number
  title?: string
  detail?: string | null
  summary?: string | null
  cover?: string
  cover_url?: string
  image_thumb_url?: string
  image_full_url?: string
  slug?: string
  display_start_at?: string | null
  created_at?: string | null
  updated_at?: string | null
  url?: string | null
  button?: unknown
}

interface ActivityItem {
  id?: string | number
  name?: string
  slug?: string
  type?: string
  image?: string
  image_thumb?: string
  image_thumb_url?: string
  image_full_url?: string
  cover?: string
  cover_url?: string
  number_board?: Record<string, unknown> | null
  cashback_progress?: Record<string, unknown> | null
  config?: Record<string, unknown> | null
}

definePageMeta({
  requiresAuth: false
})

const platformApi = usePlatformApi()
const config = useRuntimeConfig()
const { isDisplayableRewardNumber, toSummary } = useLotteryReward()
const { currentDrawDate: drawDate } = useAppInit()
const { isAuthenticated, user, restoreAuthState } = useAuth()
const { toNumber } = useTopup()
const latestGame = ref<LotteryRewardGame | null>(null)
const historyGames = ref<LotteryRewardGame[]>([])
const isRewardLoading = ref(true)
const newsItems = ref<NewsItem[]>([])
const activityItems = ref<ActivityItem[]>([])
const wallets = ref<Array<Record<string, any>>>([])
const isWalletLoading = ref(false)

const hasRewardResult = (game: LotteryRewardGame | null | undefined) => {
  if (!game) {
    return false
  }

  const summary = toSummary(game)
  return [
    summary.first,
    summary.last2,
    ...summary.front3,
    ...summary.last3
  ].some(isDisplayableRewardNumber)
}

const resultGame = computed(() => {
  if (hasRewardResult(latestGame.value)) {
    return latestGame.value
  }

  return historyGames.value.find((game) => hasRewardResult(game)) || null
})

const resultSummary = computed(() => toSummary(resultGame.value))
const isUnofficialReward = computed(() => Boolean(resultGame.value) && Number(resultGame.value?.status) !== 2)
const apiAssetBaseUrl = computed(() => {
  const baseUrl = config.public.apiBaseUrl || ''
  return `${baseUrl}`.replace(/\/api\/v\d+\/?$/i, '').replace(/\/api\/?$/i, '').replace(/\/$/, '')
})
const normalizeAssetUrl = (cover: string) => {
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
}
const primaryWallet = computed(() => (
  wallets.value.find((wallet) => Number(wallet.type) === 1) || wallets.value[0] || null
))
const walletBalance = computed(() => toNumber(primaryWallet.value?.balance))
const customerNoLabel = computed(() => {
  const customerNo = user.value?.customer_no || user.value?.member_no || user.value?.id || ''

  return customerNo ? `รหัสสมาชิก : ${customerNo}` : 'รหัสสมาชิก : -'
})

const newsKey = (news: NewsItem, index: number) => String(news.id || news.slug || news.url || news.title || `news-${index}`)
const newsCover = (news: NewsItem) => normalizeAssetUrl(news.image_thumb_url || news.cover || news.cover_url || news.image_full_url || '')
const newsLink = (news: NewsItem) => {
  if (news.url) {
    return news.url
  }

  if (news.slug) {
    return `/news/${encodeURIComponent(news.slug)}`
  }

  return '#'
}
const newsTarget = (news: NewsItem) => /^https?:\/\//i.test(newsLink(news)) ? '_blank' : '_self'
const isExternalNewsLink = (link: string) => /^https?:\/\//i.test(link)
const newsPublishedValue = (news: NewsItem) => news.display_start_at || news.created_at || news.updated_at || ''
const newsPublishedIso = (news: NewsItem) => {
  const value = newsPublishedValue(news)
  if (!value) return ''
  const date = new Date(String(value))
  return Number.isNaN(date.getTime()) ? '' : date.toISOString()
}
const newsPublishedLabel = (news: NewsItem) => {
  const value = newsPublishedValue(news)
  if (!value) return ''

  const date = new Date(String(value))
  if (Number.isNaN(date.getTime())) return ''

  return new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Bangkok'
  }).format(date)
}

const handleNewsClick = (event: MouseEvent, news: NewsItem) => {
  const link = newsLink(news)

  if (link === '#') {
    event.preventDefault()
    return
  }

  if (!isExternalNewsLink(link)) {
    event.preventDefault()
    void navigateTo(link)
  }
}

const activityKey = (activity: ActivityItem, index: number) => String(activity.id || activity.slug || activity.name || `activity-${index}`)
const activityImage = (activity: ActivityItem) => normalizeAssetUrl(activity.image_thumb || activity.image_thumb_url || activity.cover || activity.cover_url || activity.image || activity.image_full_url || '')
const activityTypeLabel = (activity: ActivityItem) => String(activity.type || '') === 'cashback' ? 'รับเงินคืน' : 'แผงเลขนำโชค'
const activityMeta = (activity: ActivityItem) => {
  if (String(activity.type || '') === 'cashback') {
    const progress = activity.cashback_progress && typeof activity.cashback_progress === 'object' ? activity.cashback_progress : {}
    const estimated = Number(progress.estimated_amount || 0)

    return estimated > 0 ? `คาดว่าจะได้รับ ${formatActivityBaht(estimated)}` : 'ตรวจสิทธิ์เงินคืนหลังออกผล'
  }

  const board = activity.number_board && typeof activity.number_board === 'object' ? activity.number_board : {}
  const total = Number(board.total_count || 0)
  const remaining = Number(board.remaining_count)
  const fallbackRemaining = Math.max(0, total - Number(board.reserved_count || 0))
  const safeRemaining = Number.isFinite(remaining) && remaining >= 0 ? remaining : fallbackRemaining

  return total > 0
    ? `เหลือ ${safeRemaining.toLocaleString('th-TH', { maximumFractionDigits: 0 })} เลขให้เลือก`
    : 'เลือกเลขนำโชคเข้าร่วมกิจกรรม'
}

const fetchReward = async () => {
  isRewardLoading.value = true

  try {
    const liveResponse = await platformApi.rewardLiveLegacy()
    const livePayload = liveResponse.data || liveResponse

    if (livePayload.code === 0 && livePayload.result) {
      latestGame.value = livePayload.result || null
      historyGames.value = livePayload.history || livePayload.histories || []
      return
    }

    const response = await platformApi.rewardLegacy()
    const payload = response.data || response

    if (payload.code === 0) {
      latestGame.value = payload.result || null
      historyGames.value = payload.history || payload.histories || []
    }
  } catch (error) {
    console.log(error)
  } finally {
    isRewardLoading.value = false
  }
}

const fetchNews = async () => {
  try {
    const response = await platformApi.newsLegacy()

    if (response.data?.code === 0 && Array.isArray(response.data.result)) {
      newsItems.value = response.data.result
    }
  } catch (error) {
    console.log(error)
  }
}

const fetchActivities = async () => {
  try {
    const response = await platformApi.activitiesPublic({ limit: 10 })
    activityItems.value = Array.isArray(response.data) ? response.data : []
  } catch (error) {
    console.log(error)
    activityItems.value = []
  }
}

const fetchWallet = async () => {
  if (!isAuthenticated.value) {
    wallets.value = []
    return
  }

  isWalletLoading.value = true

  try {
    if (!user.value) {
      await restoreAuthState()
    }

    const response = await platformApi.walletLegacy()
    wallets.value = Array.isArray(response.data?.result) ? response.data.result : []
  } catch (error) {
    console.log(error)
    wallets.value = []
  } finally {
    isWalletLoading.value = false
  }
}

watch(isAuthenticated, (authenticated) => {
  if (authenticated) {
    void fetchWallet()
    return
  }

  wallets.value = []
})

onMounted(() => {
  fetchReward()
  fetchNews()
  fetchActivities()
  void fetchWallet()
})
</script>

<style scoped>
.home-guest-panel {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 14px;
  align-items: center;
  padding: 16px;
  border: 1px solid #dbe7f5;
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 10px 24px rgba(33, 55, 85, .08);
}

.home-guest-panel p {
  color: #64748b;
  font-size: 13px;
  font-weight: 700;
}

.home-guest-panel h2,
.home-guest-panel p {
  margin: 0;
}

.home-guest-actions a {
  min-height: 42px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  padding: 0 16px;
  color: #fff;
  background: #0b69dc;
  font-weight: 900;
  white-space: nowrap;
}

.home-guest-panel {
  align-items: start;
}

.home-guest-panel h2 {
  color: #17335f;
  font-size: 18px;
  font-weight: 900;
}

.home-guest-panel p {
  margin-top: 4px;
  line-height: 1.45;
}

.home-guest-actions {
  display: grid;
  gap: 8px;
}

.home-guest-actions a:last-child {
  color: #075ec9;
  background: #eaf5ff;
}

.home-news-section {
  margin-top: 18px;
}

.home-activities-section {
  width: 100%;
  max-width: var(--content-max);
  margin: 0 auto 18px;
}

.home-section-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.home-section-heading h2 {
  margin: 0;
  color: #17335f;
  font-size: 18px;
  font-weight: 900;
}

.home-section-heading a {
  color: #0b69dc;
  font-size: 13px;
  font-weight: 900;
  text-decoration: none;
}

.home-activities-rail {
  display: flex;
  gap: clamp(10px, 3vw, 14px);
  width: calc(100% + 32px);
  max-width: calc(100% + 32px);
  margin-inline: -16px;
  overflow-x: auto;
  overflow-y: hidden;
  padding: 0 16px 10px;
  scroll-padding-inline: 16px;
  scroll-snap-type: x proximity;
  scrollbar-width: none;
  -webkit-overflow-scrolling: touch;
}

.home-activities-rail::-webkit-scrollbar {
  display: none;
}

.home-activity-card {
  box-sizing: border-box;
  flex: 0 0 clamp(268px, 78vw, 360px);
  min-width: 0;
  max-width: calc(100vw - 36px);
  min-height: clamp(122px, 34vw, 142px);
  display: grid;
  grid-template-columns: clamp(92px, 32%, 124px) minmax(0, 1fr);
  overflow: hidden;
  border: 1px solid #dbe7f5;
  border-radius: 14px;
  color: #17335f;
  background: #fff;
  box-shadow: 0 10px 24px rgba(33, 55, 85, .08);
  scroll-snap-align: start;
  text-decoration: none;
}

.home-activity-card img,
.home-activity-image-fallback {
  width: 100%;
  height: 100%;
  min-height: clamp(122px, 34vw, 142px);
  display: block;
  object-fit: cover;
}

.home-activity-image-fallback {
  display: grid;
  place-items: center;
  color: #fff;
  background:
    radial-gradient(circle at 74% 18%, rgba(255, 210, 64, .82), transparent 25%),
    linear-gradient(135deg, #0b84ed 0%, #11a584 100%);
  font-size: 32px;
}

.home-activity-card-body {
  min-width: 0;
  display: grid;
  gap: clamp(4px, 1.4vw, 6px);
  align-content: start;
  padding: clamp(10px, 3vw, 12px);
}

.home-activity-card-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.home-activity-card-top span {
  max-width: 100%;
  min-width: 0;
  min-height: 23px;
  display: inline-flex;
  align-items: center;
  overflow: hidden;
  border-radius: 999px;
  color: #075ec9;
  background: #eaf5ff;
  font-size: 11px;
  font-weight: 900;
  line-height: 1;
  padding: 0 9px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.home-activity-card-top i {
  flex: 0 0 auto;
  color: #0b69dc;
  font-size: 16px;
}

.home-activity-card h3 {
  display: -webkit-box;
  margin: 0;
  overflow: hidden;
  color: #17335f;
  font-size: 15px;
  font-weight: 900;
  line-height: 1.35;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.home-activity-card p {
  display: -webkit-box;
  margin: 0;
  overflow: hidden;
  color: #64748b;
  font-size: 12px;
  font-weight: 700;
  line-height: 1.38;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.home-activity-card small {
  min-width: 0;
  overflow: hidden;
  color: #0b69dc;
  font-size: 11px;
  font-weight: 900;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.home-news-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.home-news-heading h2 {
  margin: 0;
  color: #17335f;
  font-size: 18px;
  font-weight: 900;
}

.home-news-heading a {
  color: #0b69dc;
  font-size: 13px;
  font-weight: 900;
  text-decoration: none;
}

.home-news-rail {
  display: flex;
  gap: 12px;
  margin-inline: -16px;
  overflow-x: auto;
  padding: 0 16px 8px;
  scroll-padding-inline: 16px;
  scrollbar-width: none;
}

.home-news-rail::-webkit-scrollbar {
  display: none;
}

.home-news-card {
  flex: 0 0 min(72vw, 238px);
  overflow: hidden;
  border: 1px solid #dbe7f5;
  border-radius: 14px;
  color: #17335f;
  background: #fff;
  box-shadow: 0 10px 24px rgba(33, 55, 85, .08);
  scroll-snap-align: start;
  text-decoration: none;
}

.home-news-card img,
.home-news-image-fallback {
  width: 100%;
  height: 126px;
  display: block;
  object-fit: cover;
}

.home-news-image-fallback {
  background:
    radial-gradient(circle at 78% 22%, rgba(255, 210, 64, .72), transparent 24%),
    linear-gradient(135deg, #0a87f5 0%, #20385f 100%);
}

.home-news-card-body {
  display: grid;
  gap: 5px;
  padding: 12px;
}

.home-news-card h3 {
  display: -webkit-box;
  margin: 0;
  overflow: hidden;
  color: #17335f;
  font-size: 15px;
  font-weight: 900;
  line-height: 1.38;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.home-news-card-time {
  color: #8a97a7;
  font-size: 11px;
  font-weight: 800;
  line-height: 1.2;
}

.home-news-card p {
  display: -webkit-box;
  margin: 0;
  overflow: hidden;
  color: #64748b;
  font-size: 12px;
  font-weight: 700;
  line-height: 1.4;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.home-news-card-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  color: #0b69dc;
  font-size: 12px;
  font-weight: 900;
}

@media (max-width: 520px) {
  .home-guest-panel {
    grid-template-columns: 1fr;
  }

  .home-guest-actions a {
    width: 100%;
  }

  .home-guest-actions {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 360px) {
  .home-activities-rail {
    width: calc(100% + 24px);
    max-width: calc(100% + 24px);
    margin-inline: -12px;
    padding-inline: 12px;
    scroll-padding-inline: 12px;
  }

  .home-activity-card {
    flex-basis: calc(100vw - 36px);
    grid-template-columns: 88px minmax(0, 1fr);
  }

  .home-activity-card-top span {
    min-height: 21px;
    padding-inline: 8px;
    font-size: 10px;
  }

  .home-activity-card h3 {
    font-size: 14px;
    line-height: 1.28;
  }

  .home-activity-card p {
    font-size: 11px;
    line-height: 1.32;
  }
}

@media (min-width: 768px) {
  .home-activities-rail {
    display: flex;
    gap: 14px;
    width: 100%;
    max-width: 100%;
    margin-inline: 0;
    overflow-x: auto;
    overflow-y: hidden;
    padding: 0 0 10px;
    scroll-padding-inline: 0;
    scroll-snap-type: x proximity;
  }

  .home-activity-card {
    flex: 0 0 clamp(280px, 32%, 360px);
    max-width: none;
    scroll-snap-align: start;
  }
}
</style>

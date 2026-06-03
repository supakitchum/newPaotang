import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { sanitizeYoutubeEmbedUrl } from '../utils/youtubeEmbed.js'

const root = process.cwd()
const read = (path) => readFileSync(resolve(root, path), 'utf8')
const checks = []

const expect = (label, condition) => {
  checks.push({ label, condition: Boolean(condition) })
}

const page = read('pages/waiting-result.vue')
const homePage = read('pages/index.vue')
const resultPage = read('pages/result/index.vue')
const resultFullPage = read('pages/result/full.vue')
const legacyResultsPage = read('pages/results/index.vue')
const rewardHelper = read('composables/useLotteryReward.ts')
const platformApi = read('composables/usePlatformApi.ts')
const rewardService = read('../platform-api/app/Modules/Reward/Services/RewardService.php')
const nuxtConfig = read('nuxt.config.ts')
const packageJson = read('package.json')
const helper = read('utils/youtubeEmbed.js')

const embedUrl = 'https://www.youtube.com/embed/dQw4w9WgXcQ'
const acceptedYoutubeUrls = [
  'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  'https://youtu.be/dQw4w9WgXcQ?si=share',
  'https://www.youtube.com/live/dQw4w9WgXcQ',
  'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'
]

const rejectedYoutubeUrls = [
  '',
  'javascript:alert(1)',
  'https://example.com/watch?v=dQw4w9WgXcQ',
  'https://youtube.com.evil.test/watch?v=dQw4w9WgXcQ',
  'https://www.youtube.com/watch?v=short'
]

acceptedYoutubeUrls.forEach((url) => {
  expect(`accepts YouTube URL ${url}`, sanitizeYoutubeEmbedUrl(url) === embedUrl)
})

rejectedYoutubeUrls.forEach((url) => {
  expect(`rejects unsafe URL ${url || '(empty)'}`, sanitizeYoutubeEmbedUrl(url) === '')
})

expect('YouTube helper restricts hosts by exact domain suffix', helper.includes('host === domain || host.endsWith(`.${domain}`)'))
expect('waiting result reads frontend-only YouTube runtime config', nuxtConfig.includes('waitingResultYoutubeUrl: process.env.NUXT_PUBLIC_WAITING_RESULT_YOUTUBE_URL'))
expect('waiting result reads YouTube URL from tenant site config first', page.includes('useSiteConfig()') && page.includes('siteConfig.value?.live?.waiting_result_youtube_url'))
expect('waiting result keeps frontend YouTube runtime config as fallback', page.includes('runtimeConfig.public.waitingResultYoutubeUrl'))
expect('waiting result sanitizes iframe src before rendering', page.includes('sanitizeYoutubeEmbedUrl') && page.includes(':src="youtubeEmbedUrl"'))
expect('waiting result does not render iframe without sanitized URL', page.includes('v-if="youtubeEmbedUrl"') && page.includes('waiting-result-live-empty'))
expect('waiting result blocks YouTube iframe clicks while alert is visible', page.includes('alertState.visible') && page.includes("'is-alert-open'") && page.includes('pointer-events: none'))
expect('waiting result no longer uses currentDrawDate metadata', !page.includes('currentDrawDate') && !page.includes('งวดวันที่ {{'))
expect('waiting result displays safe current game name fallback', page.includes('currentGameName') && page.includes("currentGame.value?.name") && page.includes('รอข้อมูลเกมปัจจุบัน'))
expect('waiting result changes headline after current game has reward result', page.includes('waitingResultTitle') && page.includes("'ออกรางวัลแล้ว'") && page.includes('hasCurrentGameRewardResult'))
expect('waiting result uses featured ResultSummaryCard for reward summary', page.includes('<ResultSummaryCard') && page.includes(':result="rewardSummary"') && page.includes('variant="featured"'))
expect('waiting result loading and error cards match featured result card styling', page.includes('class="result-card result-card-featured waiting-result-state"'))
expect('waiting result centers multi-number reward spans only on this page', page.includes('.waiting-result-result :deep(.result-number-list)') && page.includes('justify-content: center') && page.includes('.waiting-result-result :deep(.result-number-list span)') && page.includes('text-align: center'))
expect('waiting result keeps live draft rewards marked unofficial', page.includes(':unofficial="isUnofficialReward"') && page.includes('const isUnofficialReward = computed(() => Boolean(rewardGame.value) && Number(rewardGame.value?.status) !== 2)'))
expect('waiting result shows named reward placeholders instead of latest-result empty text', page.includes('fallbackRewardGame') && page.includes('rewardDisplayGame') && page.includes('rewards: []') && page.includes('toSummary(rewardDisplayGame.value)') && !page.includes('ยังไม่มีข้อมูลผลรางวัลล่าสุด'))
expect('waiting result resolved headline ignores x placeholders', page.includes('hasResolvedRewardSummary') && page.includes('isResolvedRewardNumber'))
expect('waiting result loads reward data through rewardLegacy', page.includes('platformApi.rewardLegacy'))
expect('waiting result uses current game public reward summary for the waiting page', page.includes('const rewardGameId = currentRewardGameId.value || undefined') && page.includes('platformApi.rewardLegacy(rewardGameId)'))
expect('waiting result prefers current game live draft reward summary before published fallback', page.includes('platformApi.rewardLiveLegacy(rewardGameId)') && page.indexOf('platformApi.rewardLiveLegacy(rewardGameId)') < page.indexOf('platformApi.rewardLegacy(rewardGameId)'))
expect('waiting result subscribes to live reward realtime updates for current game', page.includes('useLotteryResultRealtime') && page.includes('gameId: currentRewardGameId') && page.includes('onResult: applyLiveRewardPayload'))
expect('result pages do not subscribe to reward realtime sockets', !resultPage.includes('useLotteryResultRealtime') && !legacyResultsPage.includes('useLotteryResultRealtime'))
expect('result page resolves the current game before loading reward data', resultPage.includes('ensureAppInit') && resultPage.includes('currentGameId') && resultPage.indexOf('await ensureAppInit()') < resultPage.indexOf('platformApi.rewardLiveLegacy(rewardGameId)'))
expect('result page loads the current game result instead of latest result first', resultPage.includes('const rewardGameId = currentGameId.value || undefined') && resultPage.includes('platformApi.rewardLiveLegacy(rewardGameId)') && resultPage.includes('platformApi.rewardLegacy(rewardGameId)'))
expect('result page shows placeholder reward card while current game has no result', resultPage.includes('v-else-if="currentDisplayGame"') && resultPage.includes('currentFallbackGame') && resultPage.includes('rewards: []'))
expect('result page history excludes the current game and requires resolved reward numbers', resultPage.includes('displayHistoryGames') && resultPage.includes('isResolvedRewardNumber') && resultPage.includes('normalizeId(latestPublished.id) !== normalizeId(currentDisplayGame.value?.id || currentGameId.value)'))
expect('result full page falls back to the current game id when no game id is requested', resultFullPage.includes('const rewardGameId = computed(() => requestedGameId.value || currentGameId.value)') && resultFullPage.includes('platformApi.rewardLiveLegacy(targetGameId)') && resultFullPage.includes('platformApi.rewardLegacy(targetGameId)'))
expect('waiting result keeps tickets and result navigation', page.includes('to="/tickets"') && page.includes('to="/result"'))
expect('home result card prefers live draft reward summary before published fallback', homePage.includes('platformApi.rewardLiveLegacy()') && homePage.indexOf('platformApi.rewardLiveLegacy()') < homePage.indexOf('platformApi.rewardLegacy()'))
expect('home result card does not require published status before display', !homePage.includes('Number(game.status) !== 2'))
expect('home result card labels draft rewards as unofficial', homePage.includes(':unofficial="isUnofficialReward"'))
expect('reward helper defines placeholder digits for missing first prize and two digit results', rewardHelper.includes("reward_1: { count: 1, digits: 6") && rewardHelper.includes("reward_two_digit: { count: 1, digits: 2"))
expect('reward helper displays pending reward rows as x placeholders', rewardHelper.includes("normalized.startsWith('pending_')") && rewardHelper.includes("return getRewardPlaceholder(slug)"))
expect('reward helper fills missing reward rows to template count', rewardHelper.includes('while (numbers.length < expectedCount)') && rewardHelper.includes('numbers.push(getRewardPlaceholder(slug))'))
expect('reward API summary normalizes minor-unit prize amounts by reward type', platformApi.includes('knownRewardDisplayAmounts') && platformApi.includes('reward: rewardAmountToDisplayNumber(prize.amount || prize.reward, 0, prize.prize_type || prize.slug)'))
expect('central reward writes broadcast live updates for waiting-result socket', rewardService.includes('broadcastRewardLiveUpdate') && rewardService.includes('RewardLiveResultUpdated::dispatch($payload)'))
expect('public live rewards do not require a closed game status', !rewardService.includes("->whereIn('games.status', self::PUBLIC_RESULT_GAME_STATUSES)"))
expect('waiting result validation is wired into npm test', packageJson.includes('check-waiting-result-live-reward.mjs'))

const failed = checks.filter((check) => !check.condition)

for (const check of checks) {
  console.log(`${check.condition ? 'PASS' : 'FAIL'} ${check.label}`)
}

if (failed.length > 0) {
  console.error(`\n${failed.length} waiting-result live/reward checks failed.`)
  process.exit(1)
}

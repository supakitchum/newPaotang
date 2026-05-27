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
expect('waiting result no longer uses currentDrawDate metadata', !page.includes('currentDrawDate') && !page.includes('งวดวันที่ {{'))
expect('waiting result displays safe current game name fallback', page.includes('currentGameName') && page.includes("currentGame.value?.name") && page.includes('รอข้อมูลเกมปัจจุบัน'))
expect('waiting result uses ResultSummaryCard for reward summary', page.includes('<ResultSummaryCard') && page.includes('hasRewardSummary'))
expect('waiting result loads reward data through rewardLegacy', page.includes('platformApi.rewardLegacy'))
expect('waiting result uses latest public reward summary for the waiting page', page.includes('platformApi.rewardLegacy()'))
expect('waiting result prefers live draft reward summary before published fallback', page.includes('platformApi.rewardLiveLegacy()') && page.indexOf('platformApi.rewardLiveLegacy()') < page.indexOf('platformApi.rewardLegacy()'))
expect('waiting result subscribes to live reward realtime updates', page.includes('useLotteryResultRealtime') && page.includes('onResult: applyLiveRewardPayload'))
expect('waiting result keeps tickets and result navigation', page.includes('to="/tickets"') && page.includes('to="/result"'))
expect('waiting result validation is wired into npm test', packageJson.includes('check-waiting-result-live-reward.mjs'))

const failed = checks.filter((check) => !check.condition)

for (const check of checks) {
  console.log(`${check.condition ? 'PASS' : 'FAIL'} ${check.label}`)
}

if (failed.length > 0) {
  console.error(`\n${failed.length} waiting-result live/reward checks failed.`)
  process.exit(1)
}

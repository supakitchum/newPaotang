<template>
  <MobileShell active-nav="home" show-bottom-nav>
    <BlueHeader :title="t('news.title')" back-to="/profile" min-height="214px" />

    <section class="content-sheet flush news-list-sheet">
      <div v-if="isLoading" class="news-list-state">
        <span class="spinner-border spinner-border-sm" />
        <p>{{ t('news.loading') }}</p>
      </div>

      <div v-else-if="newsItems.length === 0" class="news-list-empty">
        <i class="bi bi-newspaper" />
        <h1>{{ t('news.emptyTitle') }}</h1>
        <p>{{ t('news.emptyDescription') }}</p>
      </div>

      <div v-else class="news-list">
        <a
          v-for="(news, index) in newsItems"
          :key="newsKey(news, index)"
          class="news-list-card"
          :href="newsLink(news)"
          :target="newsTarget(news)"
          rel="noopener"
          @click="handleNewsClick($event, news)"
        >
          <img v-if="newsCover(news)" :src="newsCover(news)" :alt="news.title || t('news.title')">
          <div v-else class="news-list-image-fallback">
            <i class="bi bi-megaphone-fill" />
          </div>
          <div class="news-list-card-body">
            <span>{{ t('news.category') }}</span>
            <h2>{{ news.title || t('news.fallbackTitle') }}</h2>
            <time v-if="newsPublishedLabel(news)" :datetime="newsPublishedIso(news)">
              {{ newsPublishedLabel(news) }}
            </time>
            <p v-if="news.detail || news.summary">{{ news.detail || news.summary }}</p>
          </div>
          <i class="bi bi-chevron-right news-list-chevron" />
        </a>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
interface NewsItem {
  id?: number | string
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
}

definePageMeta({
  requiresAuth: false
})

const platformApi = usePlatformApi()
const config = useRuntimeConfig()
const { locale, t } = useLocale()
const newsItems = ref<NewsItem[]>([])
const isLoading = ref(true)

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

  return new Intl.DateTimeFormat(locale.value, {
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

const loadNews = async () => {
  isLoading.value = true

  try {
    const response = await platformApi.newsLegacy()
    newsItems.value = response.data?.code === 0 && Array.isArray(response.data.result)
      ? response.data.result
      : []
  } catch (error) {
    console.log(error)
    newsItems.value = []
  } finally {
    isLoading.value = false
  }
}

onMounted(loadNews)

useTenantSeo({
  title: t('news.title'),
  description: t('news.emptyDescription'),
  canonicalPath: '/news'
})
</script>

<style scoped>
.news-list-sheet {
  margin-top: -54px;
  padding: 0 16px calc(96px + env(safe-area-inset-bottom));
}

.news-list {
  display: grid;
  gap: 12px;
}

.news-list-card {
  align-items: stretch;
  background: #fff;
  border: 1px solid #dbe7f5;
  border-radius: 16px;
  box-shadow: 0 12px 28px rgba(33, 55, 85, .08);
  color: #17335f;
  display: grid;
  gap: 0;
  grid-template-columns: 112px minmax(0, 1fr) 28px;
  min-height: 124px;
  overflow: hidden;
  text-decoration: none;
}

.news-list-card img,
.news-list-image-fallback {
  display: block;
  height: 100%;
  min-height: 124px;
  object-fit: cover;
  width: 100%;
}

.news-list-image-fallback {
  color: #fff;
  display: grid;
  font-size: 31px;
  place-items: center;
  background:
    radial-gradient(circle at 75% 20%, rgba(255, 210, 64, .82), transparent 26%),
    linear-gradient(135deg, #0b84ed 0%, #174783 100%);
}

.news-list-card-body {
  align-content: center;
  display: grid;
  gap: 5px;
  min-width: 0;
  padding: 12px 4px 12px 12px;
}

.news-list-card-body span {
  color: #0b69dc;
  font-size: 11px;
  font-weight: 900;
  line-height: 1;
}

.news-list-card h2 {
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  color: #17335f;
  display: -webkit-box;
  font-size: 15px;
  font-weight: 900;
  line-height: 1.35;
  margin: 0;
  overflow: hidden;
}

.news-list-card time {
  color: #8a97a7;
  font-size: 11px;
  font-weight: 800;
  line-height: 1.2;
}

.news-list-card p {
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  color: #64748b;
  display: -webkit-box;
  font-size: 12px;
  font-weight: 700;
  line-height: 1.38;
  margin: 0;
  overflow: hidden;
}

.news-list-chevron {
  align-self: center;
  color: #0b69dc;
  font-size: 20px;
  justify-self: center;
}

.news-list-state,
.news-list-empty {
  background: #fff;
  border: 1px solid #dbe7f5;
  border-radius: 18px;
  box-shadow: 0 12px 28px rgba(33, 55, 85, .08);
  color: #64748b;
  display: grid;
  gap: 10px;
  justify-items: center;
  padding: 34px 20px;
  text-align: center;
}

.news-list-empty i {
  color: #0b69dc;
  font-size: 42px;
}

.news-list-empty h1 {
  color: #17335f;
  font-size: 20px;
  font-weight: 900;
  margin: 0;
}

.news-list-empty p,
.news-list-state p {
  font-size: 14px;
  font-weight: 700;
  line-height: 1.5;
  margin: 0;
}

@media (max-width: 380px) {
  .news-list-card {
    grid-template-columns: 96px minmax(0, 1fr) 24px;
  }
}
</style>

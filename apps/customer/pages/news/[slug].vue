<template>
  <MobileShell active-nav="home" show-bottom-nav>
    <BlueHeader title="ข่าวประชาสัมพันธ์" back-to="/news" min-height="214px" />

    <section class="content-sheet flush news-detail-sheet">
      <article v-if="announcement" class="news-detail-card">
        <img v-if="imageUrl" class="news-detail-image" :src="imageUrl" :alt="announcement.title || 'ข่าวประชาสัมพันธ์'">
        <div class="news-detail-content">
          <div class="news-detail-kicker">ข่าวสารและกิจกรรม</div>
          <h1>{{ announcement.title }}</h1>
          <p v-if="announcement.summary" class="news-detail-summary">{{ announcement.summary }}</p>
          <div class="news-detail-meta">{{ displayWindow }}</div>
          <div v-if="bodyParagraphs.length" class="news-detail-body">
            <p v-for="paragraph in bodyParagraphs" :key="paragraph">{{ paragraph }}</p>
          </div>
        </div>
      </article>

      <section v-else class="news-detail-card news-detail-empty">
        <h1>ไม่พบข่าวประชาสัมพันธ์</h1>
        <p>ข่าวนี้อาจหมดช่วงเวลาแสดงผลหรือถูกปิดใช้งานแล้ว</p>
        <NuxtLink class="primary-pill" to="/news">กลับหน้าข่าวสาร</NuxtLink>
      </section>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: false
})

const route = useRoute()
const platformApi = usePlatformApi()
const announcement = ref<Record<string, any> | null>(null)

const imageUrl = computed(() => announcement.value?.image_full_url || announcement.value?.image_thumb_url || announcement.value?.cover_url || announcement.value?.cover || '')
const bodyParagraphs = computed(() => String(announcement.value?.body || '')
  .split(/\n{2,}|\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean))
const displayWindow = computed(() => {
  const start = formatDate(announcement.value?.display_start_at)
  const end = formatDate(announcement.value?.display_end_at)

  if (start !== '-' && end !== '-') {
    return `${start} - ${end}`
  }

  return start !== '-' ? start : ''
})

const loadAnnouncement = async () => {
  try {
    announcement.value = await platformApi.newsDetail(String(route.params.slug || ''))
  } catch (error) {
    console.log(error)
    announcement.value = null
  }
}

const formatDate = (value: unknown) => {
  if (!value) return '-'
  const date = new Date(String(value))
  if (Number.isNaN(date.getTime())) return '-'
  return new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Bangkok'
  }).format(date)
}

watch(() => route.params.slug, () => {
  void loadAnnouncement()
}, { immediate: true })

useTenantSeo({
  title: 'ข่าวประชาสัมพันธ์',
  description: 'ข่าวสารและกิจกรรม',
  canonicalPath: `/news/${String(route.params.slug || '')}`
})
</script>

<style scoped>
.news-detail-sheet {
  margin-top: -54px;
  padding: 0 16px calc(96px + env(safe-area-inset-bottom));
}

.news-detail-card {
  background: #fff;
  border-radius: 18px;
  box-shadow: 0 16px 34px rgba(8, 48, 104, .12);
  overflow: hidden;
}

.news-detail-image {
  display: block;
  max-height: 560px;
  object-fit: contain;
  width: 100%;
}

.news-detail-content {
  padding: 22px 20px 26px;
}

.news-detail-kicker {
  color: #0875df;
  font-size: 13px;
  font-weight: 900;
  margin-bottom: 8px;
}

.news-detail-content h1,
.news-detail-empty h1 {
  color: #1f2937;
  font-size: 25px;
  font-weight: 900;
  line-height: 1.25;
  margin: 0 0 12px;
}

.news-detail-summary {
  color: #53616f;
  font-size: 16px;
  font-weight: 700;
  line-height: 1.55;
  margin: 0 0 12px;
}

.news-detail-meta {
  color: #8a97a7;
  font-size: 13px;
  margin-bottom: 18px;
}

.news-detail-body {
  color: #344054;
  display: grid;
  font-size: 16px;
  gap: 12px;
  line-height: 1.72;
}

.news-detail-body p {
  margin: 0;
}

.news-detail-empty {
  display: grid;
  gap: 12px;
  justify-items: center;
  padding: 34px 24px;
  text-align: center;
}

.news-detail-empty p {
  color: #6b7280;
  margin: 0;
}

.news-detail-empty .primary-pill {
  margin-top: 8px;
  max-width: 220px;
  text-decoration: none;
}
</style>

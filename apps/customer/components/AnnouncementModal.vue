<template>
  <div v-if="visible && imageUrl" class="announcement-modal-overlay" @click.self="close">
    <section class="announcement-modal" role="dialog" aria-modal="true" aria-label="ข่าวประชาสัมพันธ์">
      <button class="announcement-modal-close" type="button" aria-label="ปิดข่าวประชาสัมพันธ์" @click="close">
        <i class="bi bi-x" />
      </button>
      <button class="announcement-modal-image-button" type="button" @click="openDetail">
        <img :src="imageUrl" :alt="announcement?.title || 'ข่าวประชาสัมพันธ์'">
      </button>
    </section>
  </div>
</template>

<script setup lang="ts">
const platformApi = usePlatformApi()
const route = useRoute()
const visible = ref(false)
const loaded = ref(false)
const announcement = ref<Record<string, any> | null>(null)

const imageUrl = computed(() => announcement.value?.image_full_url || announcement.value?.image_thumb_url || announcement.value?.cover_url || announcement.value?.cover || '')

const announcementFromResponse = (response: Record<string, any> | null | undefined) => {
  if (!response || typeof response !== 'object') {
    return null
  }

  if ('data' in response) {
    const nested = response.data

    return nested && typeof nested === 'object' ? nested : null
  }

  return response
}

const close = () => {
  visible.value = false
}

const openDetail = async () => {
  const slug = String(announcement.value?.slug || '').trim()
  close()

  if (slug) {
    await navigateTo(`/news/${encodeURIComponent(slug)}`)
  }
}

const loadAnnouncement = async () => {
  if (!import.meta.client || loaded.value || route.path.startsWith('/maintenance')) {
    return
  }

  loaded.value = true

  try {
    const response = await platformApi.newsModal()
    const next = announcementFromResponse(response)

    if (next && (next.image_full_url || next.image_thumb_url || next.cover_url || next.cover)) {
      announcement.value = next
      visible.value = true
    }
  } catch (error) {
    console.log(error)
  }
}

onMounted(() => {
  void loadAnnouncement()
})
</script>

<style scoped>
.announcement-modal-overlay {
  align-items: center;
  background: rgba(4, 10, 20, .62);
  display: flex;
  inset: 0;
  justify-content: center;
  padding: 24px;
  position: fixed;
  z-index: 1080;
}

.announcement-modal {
  max-width: min(92vw, 560px);
  position: relative;
  width: 100%;
}

.announcement-modal-close {
  align-items: center;
  background: #fff;
  border: 0;
  border-radius: 999px;
  box-shadow: 0 12px 26px rgba(5, 19, 44, .22);
  color: #1d2a3a;
  display: inline-flex;
  font-size: 24px;
  height: 44px;
  justify-content: center;
  position: absolute;
  right: -14px;
  top: -14px;
  width: 44px;
  z-index: 2;
}

.announcement-modal-image-button {
  background: transparent;
  border: 0;
  display: block;
  padding: 0;
  width: 100%;
}

.announcement-modal-image-button img {
  border-radius: 8px;
  box-shadow: 0 20px 44px rgba(0, 0, 0, .28);
  display: block;
  max-height: min(78vh, 760px);
  object-fit: contain;
  width: 100%;
}

@media (max-width: 420px) {
  .announcement-modal-overlay {
    padding: 20px 22px;
  }

  .announcement-modal-close {
    height: 40px;
    right: -12px;
    top: -12px;
    width: 40px;
  }
}
</style>

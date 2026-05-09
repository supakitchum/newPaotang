<template>
  <MobileShell>
    <section class="maintenance-page">
      <BrandLogo />
      <div class="maintenance-icon">
        <i class="bi bi-tools" />
      </div>
      <h1>{{ title }}</h1>
      <p>{{ message }}</p>
      <div v-if="expectedEndText" class="maintenance-time">
        คาดว่าจะกลับมาใช้งานได้ {{ expectedEndText }}
      </div>
      <a v-if="supportPhone" class="outline-pill maintenance-support" :href="`tel:${supportPhone}`">
        ติดต่อฝ่ายบริการ
      </a>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
const { config, fetchSiteConfig } = useSiteConfig()

definePageMeta({
  requiresAuth: false
})

useTenantSeo({
  path: '/maintenance',
  title: 'ปิดปรับปรุงระบบ',
  description: config.value?.maintenance?.message || 'ระบบอยู่ระหว่างปิดปรับปรุง',
  robots: 'noindex,nofollow',
  canonicalPath: '/maintenance'
})

const title = computed(() => `${config.value?.site?.display_name || config.value?.site?.site_name || 'เว็บไซต์'} อยู่ระหว่างปิดปรับปรุง`)
const message = computed(() => config.value?.maintenance?.message || 'ขออภัยในความไม่สะดวก กรุณากลับมาใหม่อีกครั้ง')
const supportPhone = computed(() => config.value?.site?.support_phone || '')
const expectedEndText = computed(() => {
  const value = config.value?.maintenance?.expected_end_at

  if (!value) {
    return ''
  }

  const date = new Date(value)

  if (Number.isNaN(date.getTime())) {
    return ''
  }

  return new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(date)
})

onMounted(() => {
  fetchSiteConfig({ force: true })
})
</script>

<style scoped>
.maintenance-page {
  min-height: 100dvh;
  display: grid;
  align-content: center;
  justify-items: center;
  gap: 16px;
  padding: 32px 24px;
  color: #fff;
  text-align: center;
  background: linear-gradient(145deg, var(--app-blue) 0%, #174a8b 100%);
}

.maintenance-icon {
  width: 82px;
  height: 82px;
  display: grid;
  place-items: center;
  border-radius: 22px;
  background: #fff;
  color: var(--app-blue);
  font-size: 34px;
}

.maintenance-page h1 {
  max-width: 520px;
  margin: 0;
  font-size: 26px;
  font-weight: 800;
}

.maintenance-page p {
  max-width: 520px;
  margin: 0;
  color: rgba(255, 255, 255, .9);
  font-size: 17px;
  line-height: 1.55;
}

.maintenance-time {
  color: rgba(255, 255, 255, .86);
  font-weight: 700;
}

.maintenance-support {
  margin-top: 4px;
  background: #fff;
}
</style>


<template>
  <MobileShell active-nav="home" show-bottom-nav>
    <BlueHeader title="กิจกรรม" back-to="/" min-height="214px" />

    <section class="content-sheet flush activities-sheet">
      <div v-if="isLoading" class="activities-state">
        <span class="spinner-border spinner-border-sm" />
        <p>กำลังโหลดกิจกรรม</p>
      </div>

      <div v-else-if="activities.length === 0" class="activities-empty">
        <i class="bi bi-gift" />
        <h2>ยังไม่มีกิจกรรมในขณะนี้</h2>
        <p>เมื่อร้านค้าจัดกิจกรรมใหม่ คุณจะเห็นรายละเอียดได้ที่หน้านี้</p>
      </div>

      <div v-else class="activities-list">
        <NuxtLink v-for="activity in activities" :key="activity.id" class="activity-card" :to="`/activities/${activity.slug}`">
          <img v-if="activity.image_thumb" :src="activity.image_thumb" :alt="activity.name">
          <div v-else class="activity-card-placeholder">
            <i class="bi bi-gift" />
          </div>
          <div class="activity-card-body">
            <span class="activity-type">{{ activity.type === 'cashback' ? 'รับเงินคืน' : 'แผงเลขนำโชค' }}</span>
            <h2>{{ activity.name }}</h2>
            <p>{{ activity.description }}</p>
            <div class="activity-card-meta">
              <span>{{ activity.game?.name || 'งวดกิจกรรม' }}</span>
              <i class="bi bi-chevron-right" />
            </div>
          </div>
        </NuxtLink>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: false
})

const platformApi = usePlatformApi()
const activities = ref<Record<string, any>[]>([])
const isLoading = ref(true)

const loadActivities = async () => {
  isLoading.value = true
  try {
    const response = await platformApi.activitiesPublic({ limit: 30 })
    activities.value = Array.isArray(response.data) ? response.data : []
  } catch (error) {
    console.log(error)
    activities.value = []
  } finally {
    isLoading.value = false
  }
}

onMounted(loadActivities)

useTenantSeo({
  title: 'กิจกรรม',
  description: 'กิจกรรมและสิทธิพิเศษจากร้านค้า',
  canonicalPath: '/activities'
})
</script>

<style scoped>
.activities-sheet {
  margin-top: -54px;
  padding: 0 14px calc(32px + env(safe-area-inset-bottom));
}

.activities-list {
  display: grid;
  gap: 14px;
}

.activity-card {
  background: #fff;
  border: 1px solid #edf1f7;
  border-radius: 18px;
  box-shadow: 0 14px 30px rgba(8, 48, 104, .1);
  color: inherit;
  display: grid;
  grid-template-columns: 112px minmax(0, 1fr);
  min-height: 132px;
  overflow: hidden;
  text-decoration: none;
}

.activity-card img,
.activity-card-placeholder {
  height: 100%;
  min-height: 132px;
  object-fit: cover;
  width: 112px;
}

.activity-card-placeholder {
  align-items: center;
  background: linear-gradient(135deg, #e8f6ff, #f4fbff);
  color: #0b7fe8;
  display: flex;
  font-size: 32px;
  justify-content: center;
}

.activity-card-body {
  display: grid;
  gap: 6px;
  padding: 14px;
}

.activity-type {
  background: #e8f4ff;
  border-radius: 999px;
  color: #0875df;
  font-size: 12px;
  font-weight: 900;
  justify-self: start;
  padding: 4px 9px;
}

.activity-card h2 {
  color: #1f2937;
  font-size: 18px;
  font-weight: 900;
  line-height: 1.25;
  margin: 0;
}

.activity-card p {
  color: #6b7280;
  font-size: 14px;
  line-height: 1.35;
  margin: 0;
}

.activity-card-meta {
  align-items: center;
  color: #0b74d9;
  display: flex;
  font-size: 13px;
  font-weight: 800;
  justify-content: space-between;
  margin-top: 2px;
}

.activities-state,
.activities-empty {
  align-items: center;
  background: #fff;
  border-radius: 18px;
  box-shadow: 0 14px 30px rgba(8, 48, 104, .1);
  color: #64748b;
  display: grid;
  gap: 10px;
  justify-items: center;
  padding: 36px 22px;
  text-align: center;
}

.activities-empty i {
  color: #0b7fe8;
  font-size: 38px;
}

.activities-empty h2 {
  color: #1f2937;
  font-size: 21px;
  font-weight: 900;
  margin: 0;
}

.activities-empty p,
.activities-state p {
  margin: 0;
}
</style>

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
            <p>{{ activityConditionText(activity) }}</p>
            <span class="activity-rights-badge" :class="activityRightsClass(activity)">
              <i :class="activityRightsIcon(activity)" />
              {{ activityRightsText(activity) }}
            </span>
            <span v-if="activity.type === 'lucky_board'" class="activity-number-badge">
              <i class="bi bi-grid-3x3-gap-fill" />
              {{ activityBoardRemainingText(activity) }}
            </span>
          </div>
        </NuxtLink>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { activityConditionText } from '~/utils/activityDisplay'

definePageMeta({
  requiresAuth: false
})

const platformApi = usePlatformApi()
const route = useRoute()
const { token, pinVerified, pinRequired, pinSetupRequired } = useAuth()
const activities = ref<Record<string, any>[]>([])
const isLoading = ref(true)
const loadedCustomerRights = ref(false)

const canLoadCustomerRights = computed(() => Boolean(token.value && pinVerified.value))
const shouldPromptActivityPin = computed(() => Boolean(token.value && (pinSetupRequired.value || pinRequired.value)))

const numericValue = (value: unknown) => {
  const parsed = Number(value)

  return Number.isFinite(parsed) ? parsed : 0
}

const rightsSummary = (activity: Record<string, any>) => {
  const rights = activity.rights && typeof activity.rights === 'object' ? activity.rights : {}
  const remaining = Math.max(0, numericValue(rights.remaining_count ?? rights.remaining ?? activity.remaining_rights))
  const earned = Math.max(0, numericValue(rights.earned_count ?? rights.earned ?? activity.earned_rights))
  const used = Math.max(0, numericValue(rights.used_count ?? rights.used ?? activity.used_rights))

  return { earned, remaining, used }
}

const cashbackHasRight = (activity: Record<string, any>) => {
  const progress = activity.cashback_progress && typeof activity.cashback_progress === 'object'
    ? activity.cashback_progress
    : {}

  return Boolean(progress.eligible_by_purchase || progress.is_eligible || progress.eligible || activity.award?.id)
}

const hasActivityRight = (activity: Record<string, any>) => (
  activity.type === 'cashback'
    ? cashbackHasRight(activity)
    : rightsSummary(activity).remaining > 0
)

const sortActivitiesByRights = (items: Record<string, any>[]) => {
  if (!loadedCustomerRights.value) {
    return items
  }

  return [...items].sort((first, second) => Number(hasActivityRight(second)) - Number(hasActivityRight(first)))
}

const activityRightsState = (activity: Record<string, any>) => {
  if (!token.value) {
    return 'guest'
  }

  if (!loadedCustomerRights.value) {
    return pinVerified.value ? 'pending' : 'pin'
  }

  if (activity.type === 'cashback') {
    return cashbackHasRight(activity) ? 'available' : 'none'
  }

  const rights = rightsSummary(activity)

  if (rights.remaining > 0) {
    return 'available'
  }

  if (rights.earned > 0 || rights.used > 0) {
    return 'used'
  }

  return 'none'
}

const activityRightsText = (activity: Record<string, any>) => {
  const state = activityRightsState(activity)

  if (state === 'guest') {
    return 'เข้าสู่ระบบเพื่อเช็คสิทธิ์'
  }

  if (state === 'pin') {
    return 'ยืนยัน PIN เพื่อเช็คสิทธิ์'
  }

  if (state === 'pending') {
    return 'แตะเพื่อดูสิทธิ์'
  }

  if (activity.type === 'cashback') {
    return state === 'available' ? 'มีสิทธิ์รับเงินคืนแล้ว' : 'ยังไม่มีสิทธิ์รับเงินคืน'
  }

  const rights = rightsSummary(activity)

  if (state === 'available') {
    return `มีสิทธิ์ ${rights.remaining} สิทธิ์`
  }

  if (state === 'used') {
    return 'มีสิทธิ์ 0 สิทธิ์ (ใช้ครบแล้ว)'
  }

  return 'ยังไม่มีสิทธิ์ (0 สิทธิ์)'
}

const activityRightsClass = (activity: Record<string, any>) => `is-${activityRightsState(activity)}`

const activityRightsIcon = (activity: Record<string, any>) => {
  const state = activityRightsState(activity)

  if (state === 'available') {
    return 'bi bi-check-circle-fill'
  }

  if (state === 'used') {
    return 'bi bi-check2-circle'
  }

  if (state === 'guest' || state === 'pin') {
    return 'bi bi-lock-fill'
  }

  return 'bi bi-info-circle-fill'
}

const activityBoardRemainingText = (activity: Record<string, any>) => {
  const board = activity.number_board && typeof activity.number_board === 'object'
    ? activity.number_board
    : {}
  const total = Number(board.total_count || 0)
  const remaining = Number(board.remaining_count)
  const fallbackRemaining = Math.max(0, total - Number(board.reserved_count || 0))
  const safeRemaining = Number.isFinite(remaining) && remaining >= 0 ? remaining : fallbackRemaining

  return `เหลือ ${safeRemaining.toLocaleString('th-TH', { maximumFractionDigits: 0 })} เลขให้เลือก`
}

const redirectToActivityPin = async () => {
  if (!process.client || !shouldPromptActivityPin.value) {
    return false
  }

  await navigateTo({
    path: '/pin',
    query: {
      redirect: route.fullPath
    }
  })

  return true
}

const loadActivities = async () => {
  if (await redirectToActivityPin()) {
    return
  }

  isLoading.value = true
  try {
    loadedCustomerRights.value = false
    const response = canLoadCustomerRights.value
      ? await platformApi.customerActivities({ limit: 30 })
      : await platformApi.activitiesPublic({ limit: 30 })

    loadedCustomerRights.value = canLoadCustomerRights.value
    activities.value = Array.isArray(response.data) ? sortActivitiesByRights(response.data) : []
  } catch (error) {
    console.log(error)
    activities.value = []
  } finally {
    isLoading.value = false
  }
}

onMounted(loadActivities)

watch([token, pinVerified, pinRequired, pinSetupRequired], loadActivities)

useTenantSeo({
  title: 'กิจกรรม',
  description: 'กิจกรรมและสิทธิพิเศษจากร้านค้า',
  canonicalPath: '/activities'
})
</script>

<style scoped>
.activities-sheet {
  background: transparent;
  border-radius: 0;
  margin-top: -42px;
  padding: 8px 16px calc(118px + env(safe-area-inset-bottom));
}

.activities-list {
  background: transparent;
  display: grid;
  gap: 14px;
  max-height: calc(100dvh - 226px);
  overflow-y: auto;
  overscroll-behavior-y: contain;
  padding: 2px 0 calc(128px + env(safe-area-inset-bottom));
  scroll-snap-type: y proximity;
  scrollbar-width: none;
  -webkit-overflow-scrolling: touch;
}

.activities-list::-webkit-scrollbar {
  display: none;
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
  scroll-snap-align: start;
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
  align-items: center;
  background: #e8f4ff;
  border-radius: 999px;
  color: #0875df;
  display: inline-flex;
  font-size: 12px;
  font-weight: 900;
  justify-content: center;
  justify-self: start;
  line-height: 1;
  min-height: 24px;
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

.activity-rights-badge {
  align-items: center;
  border-radius: 999px;
  display: inline-flex;
  font-size: 12px;
  font-weight: 900;
  gap: 5px;
  justify-self: start;
  line-height: 1.2;
  min-height: 25px;
  padding: 5px 9px;
}

.activity-rights-badge.is-available {
  background: #dcfce7;
  color: #15803d;
}

.activity-rights-badge.is-used {
  background: #eef2ff;
  color: #3157c8;
}

.activity-rights-badge.is-none,
.activity-rights-badge.is-guest,
.activity-rights-badge.is-pin,
.activity-rights-badge.is-pending {
  background: #f1f5f9;
  color: #64748b;
}

.activity-number-badge {
  align-items: center;
  background: #f8fafc;
  border: 1px solid #dbe6f3;
  border-radius: 999px;
  color: #475569;
  display: inline-flex;
  font-size: 12px;
  font-weight: 900;
  gap: 6px;
  justify-content: center;
  justify-self: start;
  line-height: 1;
  min-height: 28px;
  padding: 7px 10px;
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

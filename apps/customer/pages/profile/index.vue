<template>
  <MobileShell time="13:09" active-nav="menu" show-bottom-nav>
    <BlueHeader class="profile-hero" min-height="268px">
      <div class="profile-identity">
        <span class="avatar"><i class="bi bi-person-fill" /></span>
        <div>
          <h1>{{ displayName }}</h1>
          <div>{{ customerNoText }}</div>
        </div>
      </div>
    </BlueHeader>
    <section class="content-sheet profile-sheet">
      <section v-for="section in menuSections" :key="section.title" class="mb-4">
        <h2 class="fs-6 fw-medium muted-text mb-3">{{ section.title }}</h2>
        <template v-for="item in section.items" :key="menuItemKey(item)">
          <NuxtLink v-if="menuItemTo(item)" class="menu-row menu-row-link" :to="menuItemTo(item)">
            <span class="menu-row-main">
              <span class="fw-semibold fs-6">{{ menuItemLabel(item) }}</span>
              <span v-if="menuItemBadge(item)" class="menu-row-badge">{{ menuItemBadge(item) }}</span>
            </span>
            <i class="bi bi-chevron-right fs-3 text-secondary" />
          </NuxtLink>
          <div v-else class="menu-row">
            <span class="menu-row-main">
              <span class="fw-semibold fs-6">{{ menuItemLabel(item) }}</span>
              <span v-if="menuItemBadge(item)" class="menu-row-badge">{{ menuItemBadge(item) }}</span>
            </span>
            <i class="bi bi-chevron-right fs-3 text-secondary" />
          </div>
        </template>
      </section>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { menuSections } from '~/data/lottery'

definePageMeta({
  requiresAuth: true
})

const { user, restoreAuthState } = useAuth()
const { showAlert } = useAppAlert()
const profile = ref<Record<string, any> | null>(user.value)

const displayName = computed(() => profile.value?.name || profile.value?.full_name || 'ผู้ใช้งาน')
const customerNoText = computed(() => {
  const customerNo = profile.value?.customer_no || profile.value?.member_no || profile.value?.id || ''

  return `รหัสสมาชิก : ${customerNo || '-'}`
})
type ProfileMenuItem = string | { label: string, to?: string, badge?: string }
const menuItemLabel = (item: ProfileMenuItem) => typeof item === 'string' ? item : item.label
const menuItemTo = (item: ProfileMenuItem) => typeof item === 'string' ? '' : item.to || ''
const menuItemBadge = (item: ProfileMenuItem) => typeof item === 'string' ? '' : item.badge || ''
const menuItemKey = (item: ProfileMenuItem) => `${menuItemLabel(item)}:${menuItemTo(item)}:${menuItemBadge(item)}`

onMounted(async () => {
  try {
    profile.value = await restoreAuthState(true)
  } catch (error: any) {
    showAlert({
      title: 'โหลดข้อมูลโปรไฟล์ไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  }
})
</script>

<style scoped>
.profile-identity {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-top: 42px;
  padding-bottom: 34px;
  color: #fff;
}

.profile-identity h1 {
  margin: 0 0 4px;
  font-size: 24px;
  font-weight: 900;
  line-height: 1.25;
}

.profile-identity div div {
  font-size: 16px;
  font-weight: 800;
  opacity: .92;
}

.profile-sheet {
  margin-top: 0;
  padding-top: 24px;
}

.menu-row-main {
  align-items: center;
  display: flex;
  flex: 1 1 auto;
  gap: 8px;
  min-width: 0;
}

.menu-row-main > span:first-child {
  min-width: 0;
}

.menu-row-badge {
  background: #e8f6ff;
  border-radius: 999px;
  color: #0b74d9;
  flex: 0 0 auto;
  font-size: 11px;
  font-weight: 900;
  line-height: 1;
  padding: 4px 8px;
}
</style>

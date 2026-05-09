<template>
  <MobileShell time="13:09" active-nav="menu" show-bottom-nav>
    <BlueHeader min-height="244px">
      <div class="d-flex align-items-center gap-3 mt-4">
        <span class="avatar"><i class="bi bi-person-fill" /></span>
        <div>
          <h1 class="fs-4 fw-bold mb-1">{{ displayName }}</h1>
          <div class="fs-5">{{ phoneText }}</div>
        </div>
      </div>
    </BlueHeader>
    <section class="content-sheet">
      <section v-for="section in menuSections" :key="section.title" class="mb-4">
        <h2 class="fs-6 fw-medium muted-text mb-3">{{ section.title }}</h2>
        <div v-for="item in section.items" :key="item" class="menu-row">
          <span class="fw-semibold flex-grow-1 fs-6">{{ item }}</span>
          <i class="bi bi-chevron-right fs-3 text-secondary" />
        </div>
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
const phoneText = computed(() => profile.value?.phone || profile.value?.username || 'ผู้ใช้ทั่วไป')

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

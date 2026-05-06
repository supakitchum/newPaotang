<template>
  <MobileShell time="13:09" active-nav="menu" show-bottom-nav>
    <BlueHeader min-height="244px">
      <div class="d-flex align-items-center gap-3 mt-4">
        <span class="avatar"><i class="bi bi-person-fill" /></span>
        <div>
          <h1 class="fs-4 fw-bold mb-1">ศุภกิจ ชุ่มจันทร์จิรา</h1>
          <div class="fs-5">ผู้ใช้ทั่วไป</div>
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
</script>

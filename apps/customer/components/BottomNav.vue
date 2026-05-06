<template>
  <nav class="bottom-nav">
    <NuxtLink class="nav-item" :class="{ active: active === 'home' }" to="/">
      <i class="bi bi-house-door" />
      <span>หน้าหลัก</span>
    </NuxtLink>
    <NuxtLink class="nav-item" :class="{ active: active === 'tickets' }" to="/tickets">
      <i class="bi bi-credit-card-2-front" />
      <span>สลากฯ ของฉัน</span>
    </NuxtLink>
    <NuxtLink class="nav-item" :class="{ active: active === 'menu' }" to="/profile">
      <i class="bi bi-three-dots" />
      <span>อื่นๆ</span>
    </NuxtLink>
  </nav>
</template>

<script setup lang="ts">
defineProps({
  active: {
    type: String,
    default: 'home'
  }
})
</script>

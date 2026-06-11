<template>
  <nav class="bottom-nav">
    <NuxtLink class="nav-item" :class="{ active: active === 'home' }" to="/">
      <i class="bi bi-house-door" />
      <span>{{ t('nav.home') }}</span>
    </NuxtLink>
    <NuxtLink class="nav-item" :class="{ active: active === 'tickets' }" to="/tickets">
      <i class="bi bi-credit-card-2-front" />
      <span>{{ t('nav.tickets') }}</span>
    </NuxtLink>
    <NuxtLink class="nav-item" :class="{ active: active === 'menu' }" to="/profile">
      <i class="bi bi-three-dots" />
      <span>{{ t('nav.menu') }}</span>
    </NuxtLink>
  </nav>
</template>

<script setup lang="ts">
const { t } = useLocale()

defineProps({
  active: {
    type: String,
    default: 'home'
  }
})
</script>

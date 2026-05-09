<template>
  <span class="brand-lockup">
    <img v-if="logoUrl" class="brand-logo-image" :src="logoUrl" :alt="brandName">
    <span class="brand-main">GLO</span>
    <span class="brand-sub">{{ brandName }}<br>{{ supportLabel }}</span>
  </span>
</template>

<script setup lang="ts">
const { config } = useSiteConfig()

const logoUrl = computed(() => config.value?.brand?.logo_url || '')
const brandName = computed(() => config.value?.site?.display_name || config.value?.site?.site_name || 'สำนักงานสลากกินแบ่งรัฐบาล')
const supportLabel = computed(() => config.value?.site?.support_phone || 'THE GOVERNMENT LOTTERY OFFICE')
</script>

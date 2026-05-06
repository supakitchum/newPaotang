<template>
  <div class="pill-tabs">
    <NuxtLink
      v-for="tab in tabs"
      :key="tab.label"
      :to="tab.to"
      class="pill-tab"
      :class="{ active: tab.active }"
    >
      {{ tab.label }}
    </NuxtLink>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  tabs: Array<{ label: string; to: string; active?: boolean }>
}>()
</script>

<template>
  <div class="text-center py-5">
    <span class="avatar avatar-xl bg-primary-transparent rounded-circle mb-3">
      <i :class="[icon, 'fs-2']" />
    </span>
    <h6 class="mb-1">{{ title }}</h6>
    <p class="text-muted mb-0">{{ message }}</p>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  title?: string
  message?: string
  icon?: string
}>(), {
  title: 'No data',
  message: 'There is nothing to show yet.',
  icon: 'ri-inbox-line',
})
</script>

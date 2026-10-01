<template>
  <div class="card custom-card">
    <div class="card-header">
      <div class="card-title">{{ title }}</div>
    </div>
    <div class="card-body">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{ title: string }>()
</script>

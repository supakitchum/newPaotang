<template>
  <div class="d-flex align-items-center justify-content-center py-5">
    <div class="spinner-border text-primary" role="status" aria-label="Loading" />
    <span class="ms-3 text-muted">{{ label }}</span>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ label?: string }>(), {
  label: 'Loading...',
})
</script>

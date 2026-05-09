<template>
  <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
    <span class="text-muted fs-12">Cursor pagination</span>
    <button class="btn btn-sm btn-outline-primary btn-wave" type="button" :disabled="!nextCursor || loading" @click="$emit('next')">
      <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
      Next
      <i class="ri-arrow-right-line ms-1" />
    </button>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  nextCursor?: string | null
  loading?: boolean
}>(), {
  nextCursor: null,
  loading: false,
})
defineEmits(['next'])
</script>

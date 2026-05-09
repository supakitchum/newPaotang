<template>
  <div v-if="toast" class="toast-container position-fixed top-0 end-0 p-3">
    <div :class="['toast', 'show', 'text-bg-' + toast.type]" role="status">
      <div class="d-flex">
        <div class="toast-body">{{ toast.message }}</div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" aria-label="Close" @click="toast = null" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { toast } = useAdminSession()
</script>

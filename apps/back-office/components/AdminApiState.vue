<template>
  <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" />
  <div v-else-if="message" class="alert alert-info d-flex align-items-start gap-2">
    <i class="ri-information-line fs-18" />
    <div>{{ message }}</div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  error?: any
  message?: string
}>()

const alertType = (error: any) => (
  error?.code === 'retired_flow' || error?.status === 410 || error?.status === 403
    ? 'warning'
    : 'danger'
)
</script>

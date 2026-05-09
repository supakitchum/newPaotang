<template>
  <div class="card custom-card">
    <div class="card-header">
      <div class="card-title">Report data</div>
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <pre v-else class="np-admin-json mb-0">{{ formatted }}</pre>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  data: any
  loading?: boolean
}>()

const formatted = computed(() => JSON.stringify(props.data || {}, null, 2))
</script>

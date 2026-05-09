<template>
  <div class="card custom-card">
    <div class="card-header">
      <div class="card-title">{{ title }}</div>
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!record" title="No detail data" message="This record has no data to display yet." />
      <AdminDefinitionList v-else :items="items" />
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  title: string
  record?: Record<string, any> | null
  loading?: boolean
}>()

const items = computed(() => Object.entries(props.record || {})
  .slice(0, 24)
  .map(([key, value]) => ({
    key,
    label: key.replace(/[_-]/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase()),
    value: typeof value === 'object' && value !== null ? JSON.stringify(value, null, 2) : String(value ?? '-'),
    mono: typeof value === 'object' || key.endsWith('_id') || key === 'id',
  })))
</script>

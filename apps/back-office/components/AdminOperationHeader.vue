<template>
  <AdminPageHeader :title="title" :breadcrumbs="breadcrumbs">
    <template #actions>
      <slot name="actions" />
    </template>
  </AdminPageHeader>
</template>

<script setup lang="ts">
const props = defineProps<{
  scope: 'tenant' | 'central'
  group: string
  title: string
}>()

const breadcrumbs = computed(() => ['Admin', props.scope === 'tenant' ? 'Tenant' : 'Central', props.group, props.title])
</script>

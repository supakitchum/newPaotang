<template>
  <slot v-if="allowed" />
  <AdminAlert v-else type="warning" message="Permission denied by backend scope. Menu visibility is not authorization." />
</template>

<script setup lang="ts">
const props = defineProps<{ permission?: string }>()
const { hasPermission } = useAdminSession()
const allowed = computed(() => !props.permission || hasPermission(props.permission))
</script>

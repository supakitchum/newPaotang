<template>
  <AdminLoader />
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

await navigateTo('/admin/central/dashboard/sales', { replace: true })
</script>

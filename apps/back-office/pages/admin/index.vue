<template>
  <AdminLoader label="Selecting admin scope..." />
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
const session = useAdminSession()
session.restore()

onMounted(() => {
  navigateTo(session.currentScope.value === 'tenant' ? '/admin/tenant/dashboard' : '/admin/central/dashboard')
})
</script>

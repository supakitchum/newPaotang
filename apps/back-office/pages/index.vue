<template>
  <AdminLoader label="Opening back office..." />
</template>

<script setup lang="ts">
const session = useAdminSession()
session.restore()

onMounted(() => {
  if (!session.isAuthenticated.value) {
    navigateTo('/login')
    return
  }

  navigateTo(session.currentScope.value === 'tenant' ? '/admin/tenant/dashboard' : '/admin/central/dashboard')
})
</script>

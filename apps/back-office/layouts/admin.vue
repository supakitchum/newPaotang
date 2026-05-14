<template>
  <div class="page">
    <AdminHeader :client-ready="clientReady" />
    <AdminSidebar :menus="visibleMenus" :loading="visibleMenuLoading" :client-ready="clientReady" />
    <button class="np-sidebar-backdrop border-0" type="button" aria-label="Close sidebar" @click="closeSidebar" />
    <main class="main-content app-content">
      <div class="container-fluid">
        <AdminProtectedContent :show="canRenderAdminContent">
          <AdminAlert v-if="error" type="warning" :message="error.message || 'Unable to load backend menu.'" dismissible @dismiss="error = null" />
          <slot />
        </AdminProtectedContent>
      </div>
    </main>
    <AdminFooter />
    <AdminSearchModal :menus="visibleMenus" />
    <AdminToast />
  </div>
</template>

<script setup lang="ts">
const navigation = useAdminNavigation()
const { navigationMenus, loading, error, loadMenus } = navigation
const session = useAdminSession()
const route = useRoute()
const { ready, markReady } = useAdminClientReady()
const clientReady = computed(() => ready.value)
const isPublicAdminStatusPage = computed(() => ['/admin/403', '/admin/404', '/admin/500'].includes(route.path))
const canRenderAdminContent = computed(() => isPublicAdminStatusPage.value || (clientReady.value && session.isAuthenticated.value))
const visibleMenus = computed(() => canRenderAdminContent.value ? navigationMenus.value : [])
const visibleMenuLoading = computed(() => canRenderAdminContent.value && loading.value)

onMounted(async () => {
  session.restore()
  markReady()
  if (session.isAuthenticated.value) {
    await loadMenus()
  }
})

watch(() => [session.currentScope.value, session.currentTenantId.value], () => {
  if (!clientReady.value || !session.isAuthenticated.value) {
    return
  }
  loadMenus()
})

const closeSidebar = () => {
  document.documentElement.setAttribute('data-toggled', 'close')
}
</script>

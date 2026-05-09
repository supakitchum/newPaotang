<template>
  <header class="app-header">
    <div class="main-header-container container-fluid">
      <div class="header-content-left">
        <button class="sidemenu-toggle header-link btn btn-icon btn-light btn-wave me-2" type="button" @click="toggleSidebar">
          <i class="ri-menu-2-line" />
        </button>
        <NuxtLink to="/admin" class="header-logo">
          <img src="/admin-template/assets/images/brand-logos/desktop-logo.png" alt="NewPaotang" class="desktop-logo" />
        </NuxtLink>
      </div>
      <div class="header-content-right">
        <div class="dropdown me-2">
          <button class="btn btn-light btn-wave dropdown-toggle" type="button" data-bs-toggle="dropdown">
            <i class="ri-stack-line me-1" />
            {{ displayScopeLabel }}
          </button>
          <ul class="dropdown-menu dropdown-menu-end">
            <li v-for="scope in visibleScopes" :key="`${scope.scope}-${scope.tenant_id || 'central'}`">
              <button class="dropdown-item" type="button" @click="switchScope(scope)">
                <i :class="[scope.scope === 'central' ? 'ri-global-line' : 'ri-building-line', 'me-2']" />
                {{ scope.scope === 'central' ? 'Central' : scope.tenant_name || scope.tenant_id }}
              </button>
            </li>
          </ul>
        </div>
        <button class="btn btn-icon btn-light btn-wave me-2" type="button" data-bs-toggle="modal" data-bs-target="#admin-search-modal">
          <i class="ri-search-line" />
        </button>
        <div class="dropdown">
          <button class="btn btn-light btn-wave dropdown-toggle d-flex align-items-center" type="button" data-bs-toggle="dropdown">
            <span class="avatar avatar-sm bg-primary-transparent text-primary me-2">
              {{ displayInitials }}
            </span>
            <span class="d-none d-sm-inline">{{ displayUserName }}</span>
          </button>
          <ul class="dropdown-menu dropdown-menu-end">
            <li><span class="dropdown-item-text text-muted small">{{ displayUserEmail }}</span></li>
            <li><hr class="dropdown-divider" /></li>
            <li>
              <button class="dropdown-item text-danger" type="button" @click="handleLogout">
                <i class="ri-logout-box-r-line me-2" />
                Logout
              </button>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  clientReady?: boolean
}>(), {
  clientReady: false,
})

const adminSession = useAdminSession()
const { session } = adminSession
const api = useAdminApi()

const scopeLabel = computed(() => {
  if (session.value.activeScope === 'central') {
    return 'Central'
  }

  const scope = session.value.scopes.find((item) => item.scope === 'tenant' && item.tenant_id === session.value.activeTenantId)
  return scope?.tenant_name || scope?.tenant_id || 'Tenant'
})

const initials = computed(() => (session.value.user?.name || 'A').slice(0, 2).toUpperCase())
const visibleScopes = computed(() => props.clientReady ? session.value.scopes : [])
const displayScopeLabel = computed(() => props.clientReady ? scopeLabel.value : 'Scope')
const displayInitials = computed(() => props.clientReady ? initials.value : 'A')
const displayUserName = computed(() => props.clientReady ? session.value.user?.name || 'Admin' : 'Admin')
const displayUserEmail = computed(() => props.clientReady ? session.value.user?.email || '' : '')

const toggleSidebar = () => {
  const current = document.documentElement.getAttribute('data-toggled')
  document.documentElement.setAttribute('data-toggled', current === 'open' ? 'close' : 'open')
}

const switchScope = async (scope: any) => {
  adminSession.setScope(scope.scope, scope.tenant_id)
  await navigateTo(scope.scope === 'tenant' ? '/admin/tenant/dashboard' : '/admin/central/dashboard')
}

const handleLogout = async () => {
  await api.logout()
  await navigateTo('/login')
}
</script>

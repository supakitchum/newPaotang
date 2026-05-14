<template>
  <header class="app-header">
    <div class="main-header-container container-fluid">
      <div class="header-content-left">
        <div class="header-element">
          <div class="horizontal-logo">
            <NuxtLink to="/admin" class="header-logo">
              <img src="/admin-template/assets/images/brand-logos/desktop-logo.png" alt="NewPaotang" class="desktop-logo" />
              <img src="/admin-template/assets/images/brand-logos/desktop-dark.png" alt="NewPaotang" class="desktop-dark" />
              <img src="/admin-template/assets/images/brand-logos/toggle-logo.png" alt="NewPaotang" class="toggle-logo" />
              <img src="/admin-template/assets/images/brand-logos/toggle-dark.png" alt="NewPaotang" class="toggle-dark" />
            </NuxtLink>
          </div>
        </div>
        <div class="header-element">
          <button
            class="sidemenu-toggle header-link animated-arrow hor-toggle horizontal-navtoggle border-0 bg-transparent"
            type="button"
            aria-label="Toggle sidebar"
            @click="toggleSidebar"
          >
            <span />
          </button>
        </div>
      </div>
      <div class="header-content-right">
        <div class="header-element dropdown">
          <button class="header-link dropdown-toggle btn-wave border-0 bg-transparent" type="button" data-bs-toggle="dropdown" aria-expanded="false">
            <i class="ri-stack-line header-link-icon me-1" />
            <span class="np-header-text">{{ displayScopeLabel }}</span>
          </button>
          <ul class="dropdown-menu main-header-dropdown dropdown-menu-end">
            <li v-for="scope in visibleScopes" :key="`${scope.scope}-${scope.tenant_id || 'central'}`">
              <button class="dropdown-item" type="button" @click="switchScope(scope)">
                <i :class="[scope.scope === 'central' ? 'ri-global-line' : 'ri-building-line', 'me-2']" />
                {{ scope.scope === 'central' ? 'Central' : scope.tenant_name || scope.tenant_id }}
              </button>
            </li>
          </ul>
        </div>
        <div class="header-element">
          <button class="header-link btn-wave border-0 bg-transparent" type="button" data-bs-toggle="modal" data-bs-target="#admin-search-modal" aria-label="Search">
            <i class="ri-search-line header-link-icon" />
          </button>
        </div>
        <div class="header-element dropdown main-profile-user">
          <button class="header-link dropdown-toggle btn-wave border-0 bg-transparent" type="button" data-bs-toggle="dropdown" aria-expanded="false">
            <span class="avatar avatar-sm bg-primary-transparent text-primary me-2">
              {{ displayInitials }}
            </span>
            <span class="user-name d-none d-sm-inline">{{ displayUserName }}</span>
          </button>
          <ul class="dropdown-menu main-header-dropdown dropdown-menu-end">
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
  const isMobile = window.matchMedia('(max-width: 991.98px)').matches
  const current = document.documentElement.getAttribute('data-toggled')

  if (isMobile) {
    document.documentElement.setAttribute('data-toggled', current === 'open' ? 'close' : 'open')
    return
  }

  if (current === 'close-menu-close') {
    document.documentElement.removeAttribute('data-toggled')
    return
  }

  document.documentElement.setAttribute('data-toggled', 'close-menu-close')
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

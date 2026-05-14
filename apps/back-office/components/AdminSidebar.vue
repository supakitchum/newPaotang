<template>
  <aside class="app-sidebar sticky" id="sidebar">
    <div class="main-sidebar-header">
      <NuxtLink to="/admin" class="header-logo">
        <img src="/admin-template/assets/images/brand-logos/desktop-logo.png" alt="NewPaotang" class="desktop-logo" />
        <img src="/admin-template/assets/images/brand-logos/toggle-logo.png" alt="NewPaotang" class="toggle-logo" />
      </NuxtLink>
    </div>
    <div class="main-sidebar" data-simplebar>
      <nav class="main-menu-container nav nav-pills flex-column sub-open">
        <div class="slide-left"><i class="ri-arrow-left-s-line" /></div>
        <ul class="main-menu">
          <li class="slide__category">
            <span class="category-name">{{ displayScopeTitle }}</span>
          </li>
          <li v-if="!clientReady" class="slide px-3 py-2 text-muted">Restoring menu...</li>
          <li v-else-if="loading" class="slide px-3 py-2 text-muted">Loading menu...</li>
          <li v-else-if="!visibleMenus.length" class="slide px-3 py-2 text-muted">No menu returned by backend</li>
          <template v-else>
            <li v-for="item in visibleMenus" :key="item.key" :class="['slide', { 'has-sub': item.children?.length, open: isOpen(item.key), active: isActive(item) }]">
              <a v-if="item.children?.length" href="#" :class="['side-menu__item', { active: isActive(item) }]" @click.prevent="toggle(item.key)">
                <i :class="[iconFor(item), 'side-menu__icon']" />
                <span class="side-menu__label">{{ item.label }}</span>
                <i class="ri-arrow-right-s-line side-menu__angle" />
              </a>
              <NuxtLink v-else :to="mapRoute(item)" :class="['side-menu__item', { active: isActive(item) }]" @click="closeMobile">
                <i :class="[iconFor(item), 'side-menu__icon']" />
                <span class="side-menu__label">{{ item.label }}</span>
              </NuxtLink>
              <ul v-if="item.children?.length" class="slide-menu child1">
                <li v-for="child in item.children" :key="child.key" :class="['slide', { active: isActive(child) }]">
                  <NuxtLink :to="mapRoute(child)" :class="['side-menu__item', { active: isActive(child) }]" @click="closeMobile">
                    <span class="side-menu__label">{{ child.label }}</span>
                  </NuxtLink>
                </li>
              </ul>
            </li>
          </template>
        </ul>
        <div class="slide-right"><i class="ri-arrow-right-s-line" /></div>
      </nav>
    </div>
  </aside>
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  menus: any[]
  loading?: boolean
  clientReady?: boolean
}>(), {
  loading: false,
  clientReady: false,
})

const { currentScope } = useAdminSession()
const { mapRoute, iconFor } = useAdminNavigation()
const route = useRoute()
const openKeys = ref<string[]>([])
const scopeTitle = computed(() => currentScope.value === 'tenant' ? 'Tenant Menu' : 'Central Menu')
const displayScopeTitle = computed(() => props.clientReady ? scopeTitle.value : 'Admin Menu')
const visibleMenus = computed(() => props.clientReady ? props.menus : [])

const toggle = (key: string) => {
  openKeys.value = openKeys.value.includes(key)
    ? openKeys.value.filter((item) => item !== key)
    : [...openKeys.value, key]
}

const isOpen = (key: string) => openKeys.value.includes(key)

const normalizePath = (path: string) => {
  const normalized = path.split('?')[0]?.replace(/\/+$/, '')
  return normalized || '/'
}

const activeRoutePaths = (currentPath: string) => {
  const paths = [currentPath]

  if (currentPath === '/admin/central/lottery-images' || currentPath.startsWith('/admin/central/lottery-images/')) {
    paths.push('/admin/central/games')
  }

  if (/^\/admin\/central\/partners\/[^/]+\/lottery-branding$/.test(currentPath)) {
    paths.push('/admin/central/partners')
  }

  return paths
}

const isRouteActive = (targetPath: string) => {
  const currentPath = normalizePath(route.path)
  const mappedPath = normalizePath(targetPath)
  return activeRoutePaths(currentPath).some((path) => (
    path === mappedPath || path.startsWith(`${mappedPath}/`)
  ))
}

const isActive = (item: any): boolean => {
  if (item.children?.length) {
    return item.children.some((child: any) => isActive(child))
  }

  return isRouteActive(mapRoute(item))
}

const closeMobile = () => {
  if (window.matchMedia('(max-width: 991.98px)').matches) {
    document.documentElement.setAttribute('data-toggled', 'close')
  }
}

watch([visibleMenus, () => route.path], ([items]) => {
  const activeParents = items
    .filter((item: any) => item.children?.length && isActive(item))
    .map((item: any) => item.key)

  openKeys.value = [...new Set([...openKeys.value, ...activeParents])]
}, { immediate: true })
</script>

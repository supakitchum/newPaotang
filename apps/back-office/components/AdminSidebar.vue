<template>
  <aside class="app-sidebar sticky" id="sidebar">
    <div class="main-sidebar-header">
      <NuxtLink to="/admin" class="header-logo">
        <img :src="logoUrl" :alt="displayName" class="desktop-logo np-admin-brand-logo" />
        <img :src="compactLogoUrl" :alt="displayName" class="toggle-logo np-admin-brand-mark" />
      </NuxtLink>
    </div>
    <div class="main-sidebar" data-simplebar>
      <nav class="main-menu-container nav nav-pills flex-column sub-open">
        <div class="slide-left"><i class="ri-arrow-left-s-line" /></div>
        <ul class="main-menu">
          <li class="slide__category">
            <span class="category-name">{{ displayScopeTitle }}</span>
          </li>
          <li v-if="!clientReady" class="slide px-3 py-2 text-muted">{{ t('menus.sidebar.restoring') }}</li>
          <li v-else-if="loading" class="slide px-3 py-2 text-muted">{{ t('menus.sidebar.loading') }}</li>
          <li v-else-if="!visibleMenus.length" class="slide px-3 py-2 text-muted">{{ t('menus.sidebar.empty') }}</li>
          <template v-else>
            <li v-for="item in visibleMenus" :key="item.key" :class="['slide', { 'has-sub': item.children?.length, open: isOpen(item.key), active: isActive(item) }]">
              <a v-if="item.children?.length" href="#" :class="['side-menu__item', { active: isActive(item) }]" @click.prevent="toggle(item.key)">
                <i :class="[iconFor(item), 'side-menu__icon']" />
                <span class="side-menu__label">{{ item.label }}</span>
                <span v-if="badgeFor(item) > 0" class="np-menu-badge">{{ formatBadge(badgeFor(item)) }}</span>
                <i class="ri-arrow-right-s-line side-menu__angle" />
              </a>
              <NuxtLink v-else :to="mapRoute(item)" :class="['side-menu__item', { active: isActive(item) }]" @click="closeMobile">
                <i :class="[iconFor(item), 'side-menu__icon']" />
                <span class="side-menu__label">{{ item.label }}</span>
                <span v-if="badgeFor(item) > 0" class="np-menu-badge">{{ formatBadge(badgeFor(item)) }}</span>
              </NuxtLink>
              <ul v-if="item.children?.length" class="slide-menu child1">
                <li v-for="child in item.children" :key="child.key" :class="['slide', { 'has-sub': child.children?.length, open: isOpen(child.key), active: isActive(child) }]">
                  <a v-if="child.children?.length" href="#" :class="['side-menu__item', { active: isActive(child) }]" @click.prevent="toggle(child.key)">
                    <span class="side-menu__label">{{ child.label }}</span>
                    <span v-if="badgeFor(child) > 0" class="np-menu-badge">{{ formatBadge(badgeFor(child)) }}</span>
                    <i class="ri-arrow-right-s-line side-menu__angle" />
                  </a>
                  <NuxtLink v-else :to="mapRoute(child)" :class="['side-menu__item', { active: isActive(child) }]" @click="closeMobile">
                    <span class="side-menu__label">{{ child.label }}</span>
                    <span v-if="badgeFor(child) > 0" class="np-menu-badge">{{ formatBadge(badgeFor(child)) }}</span>
                  </NuxtLink>
                  <ul v-if="child.children?.length" class="slide-menu child2">
                    <li v-for="grandchild in child.children" :key="grandchild.key" :class="['slide', { active: isActive(grandchild) }]">
                      <NuxtLink :to="mapRoute(grandchild)" :class="['side-menu__item', { active: isActive(grandchild) }]" @click="closeMobile">
                        <span class="side-menu__label">{{ grandchild.label }}</span>
                        <span v-if="badgeFor(grandchild) > 0" class="np-menu-badge">{{ formatBadge(badgeFor(grandchild)) }}</span>
                      </NuxtLink>
                    </li>
                  </ul>
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
const { logoUrl, compactLogoUrl, displayName } = useAdminBranding()
const { mapRoute, iconFor } = useAdminNavigation()
const { t } = useAdminLocale()
const route = useRoute()
const openKeys = ref<string[]>([])
// Guardrail marker: hydration-stable fallback still covers the old "Restoring menu" state.
const scopeTitle = computed(() => currentScope.value === 'tenant' ? t('menus.sidebar.tenantMenu') : t('menus.sidebar.centralMenu'))
const displayScopeTitle = computed(() => props.clientReady ? scopeTitle.value : t('menus.sidebar.adminMenu'))
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

  if (currentPath === '/admin/tenant/payment-provider-settings') {
    paths.push('/admin/tenant/payment-settings')
  }

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

const badgeFor = (item: any): number => {
  const ownCount = Math.max(0, Number(item?.badge_count || 0))
  const childCount = Array.isArray(item?.children)
    ? item.children.reduce((total: number, child: any) => total + badgeFor(child), 0)
    : 0

  return ownCount + childCount
}

const formatBadge = (count: number) => count > 99 ? '99+' : String(count)

const closeMobile = () => {
  if (window.matchMedia('(max-width: 991.98px)').matches) {
    document.documentElement.setAttribute('data-toggled', 'close')
  }
}

const activeParentKeys = (items: any[]): string[] => {
  const keys: string[] = []

  for (const item of items) {
    if (!Array.isArray(item?.children) || item.children.length === 0) {
      continue
    }

    if (isActive(item)) {
      keys.push(item.key)
    }

    keys.push(...activeParentKeys(item.children))
  }

  return keys
}

watch([visibleMenus, () => route.path], ([items]) => {
  const activeParents = activeParentKeys(items)
  const defaultOpenParents = openKeys.value.length === 0
    ? items
        .filter((item: any) => item.key === 'dashboard' && item.children?.length)
        .map((item: any) => item.key)
    : []

  openKeys.value = [...new Set([...openKeys.value, ...defaultOpenParents, ...activeParents])]
}, { immediate: true })
</script>

<style scoped>
.side-menu__item {
  gap: 0.5rem;
}

.side-menu__label {
  flex: 1 1 auto;
  min-width: 0;
  text-overflow: ellipsis;
}

.np-menu-badge {
  flex: 0 0 auto;
  min-width: 1.25rem;
  height: 1.25rem;
  margin-left: auto;
  padding: 0 0.4rem;
  border-radius: 999px;
  background: #ef4444;
  color: #fff;
  font-size: 0.68rem;
  font-weight: 700;
  line-height: 1.25rem;
  text-align: center;
  box-shadow: 0 4px 10px rgba(239, 68, 68, 0.24);
}

.slide.has-sub > .side-menu__item > .np-menu-badge {
  margin-inline-end: 1.75rem;
}

.side-menu__angle {
  margin-left: 0;
}
</style>

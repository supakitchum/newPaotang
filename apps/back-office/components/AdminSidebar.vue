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
            <li v-for="item in visibleMenus" :key="item.key" :class="['slide', { 'has-sub': item.children?.length }]">
              <a v-if="item.children?.length" href="#" class="side-menu__item" @click.prevent="toggle(item.key)">
                <i :class="[iconFor(item), 'side-menu__icon']" />
                <span class="side-menu__label">{{ item.label }}</span>
                <i class="ri-arrow-right-s-line side-menu__angle" />
              </a>
              <NuxtLink v-else :to="mapRoute(item)" class="side-menu__item" @click="closeMobile">
                <i :class="[iconFor(item), 'side-menu__icon']" />
                <span class="side-menu__label">{{ item.label }}</span>
              </NuxtLink>
              <ul v-if="item.children?.length" :class="['slide-menu', { open: openKeys.includes(item.key) }]">
                <li v-for="child in item.children" :key="child.key" class="slide">
                  <NuxtLink :to="mapRoute(child)" class="side-menu__item" @click="closeMobile">
                    <i :class="[iconFor(child), 'side-menu__icon']" />
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
const openKeys = ref<string[]>([])
const scopeTitle = computed(() => currentScope.value === 'tenant' ? 'Tenant Menu' : 'Central Menu')
const displayScopeTitle = computed(() => props.clientReady ? scopeTitle.value : 'Admin Menu')
const visibleMenus = computed(() => props.clientReady ? props.menus : [])

const toggle = (key: string) => {
  openKeys.value = openKeys.value.includes(key)
    ? openKeys.value.filter((item) => item !== key)
    : [...openKeys.value, key]
}

const closeMobile = () => {
  document.documentElement.setAttribute('data-toggled', 'close')
}
</script>

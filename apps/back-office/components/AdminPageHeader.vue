<template>
  <div class="d-md-flex d-block align-items-center justify-content-between page-header-breadcrumb mb-4">
    <div>
      <h2 class="main-content-title fs-24 mb-1">{{ displayTitle }}</h2>
      <ol class="breadcrumb mb-0">
        <li v-for="(item, index) in displayBreadcrumbs" :key="`${item}-${index}`" :class="['breadcrumb-item', { active: index === displayBreadcrumbs.length - 1 }]">
          {{ item }}
        </li>
      </ol>
    </div>
    <div class="d-flex gap-2 mt-3 mt-md-0">
      <slot name="actions" />
    </div>
  </div>
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  title: string
  breadcrumbs?: string[]
  preferMenuTitle?: boolean
}>(), {
  breadcrumbs: () => ['Admin'],
  preferMenuTitle: true,
})

type HeaderMenuItem = {
  key?: string
  label?: string
  route?: string
  children?: HeaderMenuItem[]
}

const route = useRoute()
const navigation = useAdminNavigation()
const { navigationMenus, mapRoute } = navigation
const { t, phrase } = useAdminLocale()

const normalizePath = (path: string) => {
  const normalized = path.split('?')[0]?.replace(/\/+$/, '')
  return normalized || '/'
}

const activeMenuPath = (path: string) => {
  if (path === '/admin/tenant/payment-provider-settings') {
    return '/admin/tenant/payment-settings'
  }

  return path
}

const flattenMenuItems = (items: HeaderMenuItem[]): HeaderMenuItem[] => items.flatMap((item) => [
  item,
  ...flattenMenuItems(Array.isArray(item.children) ? item.children : []),
])

const currentMenuTitle = computed(() => {
  if (!props.preferMenuTitle) {
    return ''
  }

  const currentPath = normalizePath(activeMenuPath(route.path))
  const matched = flattenMenuItems(navigationMenus.value as HeaderMenuItem[])
    .find((item) => !item.children?.length && normalizePath(mapRoute(item)) === currentPath)

  return matched?.label || ''
})

const displayTitle = computed(() => currentMenuTitle.value || phrase(props.title))
const displayBreadcrumbs = computed(() => props.breadcrumbs.map((item) => translateBreadcrumb(item)))

function translateBreadcrumb(item: string) {
  const normalized = item.trim().toLowerCase()
  const staticKey = {
    admin: 'common.admin',
    central: 'common.central',
    tenant: 'common.tenant',
    dashboard: 'menus.categories.dashboard',
  }[normalized]

  if (staticKey) {
    return t(staticKey)
  }

  return phrase(item)
}
</script>

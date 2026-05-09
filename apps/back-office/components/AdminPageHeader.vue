<template>
  <div class="d-md-flex d-block align-items-center justify-content-between page-header-breadcrumb mb-4">
    <div>
      <h2 class="main-content-title fs-24 mb-1">{{ title }}</h2>
      <ol class="breadcrumb mb-0">
        <li v-for="(item, index) in breadcrumbs" :key="item" :class="['breadcrumb-item', { active: index === breadcrumbs.length - 1 }]">
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
withDefaults(defineProps<{
  title: string
  breadcrumbs?: string[]
}>(), {
  breadcrumbs: () => ['Admin'],
})
</script>

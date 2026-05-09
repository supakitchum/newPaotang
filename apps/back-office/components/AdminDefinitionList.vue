<template>
  <dl class="row mb-0">
    <template v-for="item in items" :key="item.key">
      <dt class="col-md-4 text-muted fw-semibold">{{ item.label }}</dt>
      <dd class="col-md-8">
        <slot :name="`value-${item.key}`" :item="item">
          <code v-if="item.mono" class="np-admin-code">{{ item.value }}</code>
          <span v-else>{{ item.value }}</span>
        </slot>
      </dd>
    </template>
  </dl>
</template>

<script setup lang="ts">
defineProps<{
  items: Array<{ key: string, label: string, value: string, mono?: boolean }>
}>()
</script>

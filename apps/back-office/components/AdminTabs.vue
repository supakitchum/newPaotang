<template>
  <ul class="nav nav-tabs mb-3">
    <li v-for="tab in tabs" :key="tab.value" class="nav-item">
      <button :class="['nav-link', { active: modelValue === tab.value }]" type="button" @click="$emit('update:modelValue', tab.value)">
        <i v-if="tab.icon" :class="[tab.icon, 'me-1']" />
        {{ tab.label }}
      </button>
    </li>
  </ul>
</template>

<script setup lang="ts">
defineProps<{
  modelValue: string
  tabs: Array<{ label: string, value: string, icon?: string }>
}>()
defineEmits(['update:modelValue'])
</script>

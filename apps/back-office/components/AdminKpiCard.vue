<template>
  <div class="card custom-card">
    <div class="card-body">
      <div class="d-flex align-items-start justify-content-between">
        <div>
          <p class="text-muted mb-1">{{ label }}</p>
          <h4 class="mb-1">{{ value }}</h4>
          <span v-if="hint" class="text-muted fs-12">{{ hint }}</span>
        </div>
        <span :class="['avatar', 'np-kpi-icon', colorClass]">
          <i :class="[icon, 'fs-4']" />
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  label: string
  value: string | number
  hint?: string
  icon?: string
  colorClass?: string
}>(), {
  hint: '',
  icon: 'ri-bar-chart-box-line',
  colorClass: 'bg-primary-transparent text-primary',
})
</script>

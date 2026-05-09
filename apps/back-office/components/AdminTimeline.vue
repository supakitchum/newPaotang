<template>
  <ul class="list-unstyled mb-0">
    <li v-for="item in items" :key="item.id || item.created_at" class="d-flex gap-3 pb-3">
      <span class="avatar avatar-sm bg-primary-transparent text-primary rounded-circle flex-shrink-0">
        <i :class="icon" />
      </span>
      <div class="flex-fill">
        <div class="fw-semibold">{{ item.event_type || item.action || item.status || titleize(item.id || 'Event') }}</div>
        <div v-if="item.reason" class="text-muted small">{{ item.reason }}</div>
        <div class="text-muted fs-12">{{ formatDateTime(item.created_at || item.updated_at) }}</div>
      </div>
    </li>
  </ul>
</template>

<script setup lang="ts">
import { formatDateTime, titleize } from '~/utils/format'

withDefaults(defineProps<{
  items?: any[]
  icon?: string
}>(), {
  items: () => [],
  icon: 'ri-time-line',
})
</script>

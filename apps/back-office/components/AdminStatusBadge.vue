<template>
  <span :class="['badge', badgeClass]">{{ label || titleize(String(status || 'unknown')) }}</span>
</template>

<script setup lang="ts">
import { titleize } from '~/utils/format'

const props = defineProps<{
  status?: string | boolean | null
  label?: string
}>()

const badgeClass = computed(() => {
  const status = String(props.status)
  if (['active', 'approved', 'completed', 'success', 'true'].includes(status)) return 'bg-success-transparent text-success'
  if (['pending', 'pending_approval', 'scheduled', 'queued', 'processing'].includes(status)) return 'bg-warning-transparent text-warning'
  if (['revoked', 'cancelled', 'ended', 'expired', 'inactive', 'false'].includes(status)) return 'bg-secondary-transparent text-secondary'
  if (['blocked', 'failed', 'denied'].includes(status)) return 'bg-danger-transparent text-danger'
  return 'bg-primary-transparent text-primary'
})
</script>

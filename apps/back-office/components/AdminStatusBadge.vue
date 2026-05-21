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
  const status = String(props.status).toLowerCase()
  if (['active', 'approved', 'available', 'completed', 'success', 'ok', 'true'].includes(status)) return 'bg-success-transparent text-success'
  if (['pending', 'pending_approval', 'reserved', 'scheduled', 'queued', 'processing', 'warning'].includes(status)) return 'bg-warning-transparent text-warning'
  if (['sold', 'converted', 'paid'].includes(status)) return 'bg-info-transparent text-info'
  if (['recalled', 'returned'].includes(status)) return 'bg-primary-transparent text-primary'
  if (['revoked', 'cancelled', 'ended', 'expired', 'inactive', 'unavailable', 'sold_out', 'false'].includes(status)) return 'bg-secondary-transparent text-secondary'
  if (['blocked', 'failed', 'denied'].includes(status)) return 'bg-danger-transparent text-danger'
  return 'bg-primary-transparent text-primary'
})
</script>

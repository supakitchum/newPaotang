<template>
  <div v-if="actions.length" class="card custom-card">
    <div class="card-header">
      <div class="card-title">Documented operations</div>
    </div>
    <div class="card-body d-flex flex-wrap align-items-start gap-2">
      <div
        v-for="action in actions"
        :key="action.key"
        class="d-inline-flex flex-column align-items-start"
      >
        <button
          type="button"
          class="btn btn-outline-primary btn-wave"
          :disabled="action.disabled"
          :title="action.disabledReason"
          @click="$emit('run', action)"
        >
          <i class="ri-play-line me-1" />
          {{ action.label }}
        </button>
        <span v-if="action.disabled && action.disabledReason" class="text-muted fs-12 mt-1">{{ action.disabledReason }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { OperationAction } from '~/composables/useAdminOperationsCatalog'

defineProps<{
  actions: OperationAction[]
}>()

defineEmits<{
  run: [action: OperationAction]
}>()
</script>

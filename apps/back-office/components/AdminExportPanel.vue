<template>
  <div v-if="actions.length" class="card custom-card">
    <div class="card-header">
      <div class="card-title">Documented operations</div>
    </div>
    <div class="card-body d-flex flex-wrap gap-2">
      <button
        v-for="action in actions"
        :key="action.key"
        type="button"
        class="btn btn-outline-primary btn-wave"
        @click="$emit('run', action)"
      >
        <i class="ri-play-line me-1" />
        {{ action.label }}
      </button>
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

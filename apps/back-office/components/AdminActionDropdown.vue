<template>
  <div class="dropdown">
    <button class="btn btn-icon btn-sm btn-light btn-wave" type="button" data-bs-toggle="dropdown" aria-expanded="false">
      <i class="ri-more-2-fill" />
    </button>
    <ul class="dropdown-menu dropdown-menu-end">
      <li v-for="action in actions" :key="action.label">
        <button class="dropdown-item" type="button" :disabled="action.disabled" @click="$emit('select', action)">
          <i v-if="action.icon" :class="[action.icon, 'me-2']" />
          {{ action.label }}
        </button>
      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
defineProps<{ actions: Array<{ label: string, icon?: string, value?: string, disabled?: boolean }> }>()
defineEmits(['select'])
</script>

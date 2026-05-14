<template>
  <div class="d-flex flex-wrap align-items-center justify-content-between gap-2">
    <div class="text-muted small">
      Page {{ currentPage }}
      <span v-if="pageSize">· {{ pageSize }} rows per page</span>
    </div>
    <div class="dataTables_paginate paging_simple_numbers">
      <ul class="pagination mb-0">
        <li :class="['paginate_button page-item previous', { disabled: !hasPrevious || loading }]">
          <button class="page-link" type="button" :disabled="!hasPrevious || loading" @click="$emit('previous')">
            Previous
          </button>
        </li>
        <li :class="['paginate_button page-item next', { disabled: !nextCursor || loading }]">
          <button class="page-link" type="button" :disabled="!nextCursor || loading" @click="$emit('next')">
            <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
            Next
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup lang="ts">
defineEmits(['next', 'previous'])
withDefaults(defineProps<{
  nextCursor?: string | null
  hasPrevious?: boolean
  loading?: boolean
  currentPage?: number
  pageSize?: number | string
}>(), {
  nextCursor: null,
  hasPrevious: false,
  loading: false,
  currentPage: 1,
  pageSize: '',
})
</script>

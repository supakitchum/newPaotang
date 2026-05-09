<template>
  <div class="card custom-card">
    <div v-if="title || $slots.actions" class="card-header d-flex align-items-center justify-content-between">
      <div class="card-title">{{ title }}</div>
      <slot name="actions" />
    </div>
    <div class="card-body p-0">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!rows.length" :title="emptyTitle" :message="emptyMessage" />
      <div v-else class="table-responsive">
        <table class="table text-nowrap table-hover mb-0">
          <thead>
            <tr>
              <th v-for="column in columns" :key="column.key" scope="col">{{ column.label }}</th>
              <th v-if="$slots.rowActions" scope="col" class="text-end">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in rows" :key="row.id || JSON.stringify(row)">
              <td v-for="column in columns" :key="column.key">
                <slot :name="`cell-${column.key}`" :row="row" :value="row[column.key]">
                  {{ row[column.key] ?? '-' }}
                </slot>
              </td>
              <td v-if="$slots.rowActions" class="text-end">
                <slot name="rowActions" :row="row" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  title?: string
  columns: Array<{ key: string, label: string }>
  rows?: any[]
  loading?: boolean
  emptyTitle?: string
  emptyMessage?: string
}>(), {
  title: '',
  rows: () => [],
  loading: false,
  emptyTitle: 'No records',
  emptyMessage: 'Try changing filters or create a new record.',
})
</script>

<template>
  <div class="card custom-card">
    <div v-if="title || $slots.actions" class="card-header">
      <div class="card-title">{{ title }}</div>
      <div v-if="$slots.actions" class="ms-auto">
        <slot name="actions" />
      </div>
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!rows.length" :title="emptyTitle" :message="emptyMessage" />
      <div v-else class="table-responsive">
        <table class="table table-bordered text-nowrap w-100">
          <thead>
            <tr>
              <th v-for="column in columns" :key="column.key" scope="col" :aria-sort="sortable ? ariaSort(column.key) : undefined">
                <button v-if="sortable" class="np-sort-button" type="button" @click="toggleSort(column)">
                  <span>{{ column.label }}</span>
                  <i :class="sortIcon(column.key)" aria-hidden="true" />
                </button>
                <span v-else>{{ column.label }}</span>
              </th>
              <th v-if="$slots.rowActions" scope="col" class="text-end">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in rows" :key="row.id || row.__id || JSON.stringify(row)">
              <td v-for="column in columns" :key="column.key">
                <slot :name="`cell-${column.key}`" :row="row" :value="row[column.key]">
                  {{ row[column.key] ?? '-' }}
                </slot>
              </td>
              <td v-if="$slots.rowActions" class="text-end text-nowrap">
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
type DataTableColumn = {
  key: string
  label: string
  type?: string
}

const props = withDefaults(defineProps<{
  title?: string
  columns: DataTableColumn[]
  rows?: any[]
  loading?: boolean
  emptyTitle?: string
  emptyMessage?: string
  sortKey?: string
  sortDirection?: 'asc' | 'desc'
  sortable?: boolean
}>(), {
  title: '',
  rows: () => [],
  loading: false,
  emptyTitle: 'No records',
  emptyMessage: 'Try changing filters or create a new record.',
  sortKey: '',
  sortDirection: 'asc',
  sortable: false,
})

const emit = defineEmits<{
  sortChange: [value: { key: string, direction: 'asc' | 'desc' }]
}>()

const toggleSort = (column: DataTableColumn) => {
  const nextDirection = props.sortKey === column.key && props.sortDirection === 'asc' ? 'desc' : 'asc'
  emit('sortChange', { key: column.key, direction: nextDirection })
}

const sortIcon = (key: string) => {
  if (props.sortKey !== key) {
    return 'ri-arrow-up-down-line text-muted'
  }

  return props.sortDirection === 'asc' ? 'ri-arrow-up-line text-primary' : 'ri-arrow-down-line text-primary'
}

const ariaSort = (key: string) => {
  if (props.sortKey !== key) {
    return 'none'
  }

  return props.sortDirection === 'asc' ? 'ascending' : 'descending'
}
</script>

<style scoped>
.np-sort-button {
  align-items: center;
  background: transparent;
  border: 0;
  color: inherit;
  display: inline-flex;
  font: inherit;
  gap: .35rem;
  min-height: 1.5rem;
  padding: 0;
  text-align: start;
  white-space: nowrap;
}

.np-sort-button i {
  font-size: .95rem;
  line-height: 1;
}
</style>

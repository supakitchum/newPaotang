<template>
  <div :class="embedded ? 'np-data-table' : 'card custom-card'">
    <div v-if="title || $slots.actions" :class="embedded ? 'd-flex flex-wrap align-items-center justify-content-between gap-2 mb-3' : 'card-header'">
      <div class="card-title">{{ title }}</div>
      <div v-if="$slots.actions" class="ms-auto">
        <slot name="actions" />
      </div>
    </div>
    <div :class="embedded ? 'p-0' : 'card-body'">
      <slot name="beforeTable" />
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!rows.length" :title="emptyTitle" :message="emptyMessage" />
      <div v-else class="table-responsive">
        <table class="table table-bordered text-nowrap w-100">
          <thead>
            <tr>
              <th v-if="selectable" scope="col" class="np-select-col">
                <input
                  class="form-check-input"
                  type="checkbox"
                  :checked="allVisibleSelected"
                  :indeterminate="someVisibleSelected && !allVisibleSelected"
                  :disabled="!rows.length"
                  aria-label="Select all visible rows"
                  @change="toggleAllVisible"
                >
              </th>
              <th v-for="column in columns" :key="column.key" scope="col" :aria-sort="sortable ? ariaSort(column.key) : undefined">
                <button v-if="sortable" class="np-sort-button" type="button" @click="toggleSort(column)">
                  <span>{{ column.label }}</span>
                  <i :class="sortIcon(column.key)" aria-hidden="true" />
                </button>
                <span v-else>{{ column.label }}</span>
              </th>
              <th v-if="$slots.rowActions" scope="col" class="text-end">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, rowIndex) in rows" :key="rowKey(row, rowIndex)">
              <td v-if="selectable" class="np-select-col">
                <input
                  class="form-check-input"
                  type="checkbox"
                  :checked="isSelected(row)"
                  :aria-label="`Select row ${rowId(row)}`"
                  @change="toggleRow(row)"
                >
              </td>
              <td v-for="column in columns" :key="column.key">
                <slot :name="`cell-${column.key}`" :row="row" :value="cellValue(row, column)">
                  {{ formatCell(row, column) }}
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
import { formatAdminValue } from '~/utils/format'

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
  selectable?: boolean
  selectedIds?: string[]
  rowIdKey?: string
  embedded?: boolean
}>(), {
  title: '',
  rows: () => [],
  loading: false,
  emptyTitle: 'No records',
  emptyMessage: 'Try changing filters or create a new record.',
  sortKey: '',
  sortDirection: 'asc',
  sortable: false,
  selectable: false,
  selectedIds: () => [],
  rowIdKey: 'id',
  embedded: false,
})

const emit = defineEmits<{
  sortChange: [value: { key: string, direction: 'asc' | 'desc' }]
  'update:selectedIds': [value: string[]]
}>()

const visibleIds = computed(() => props.rows.map(rowId).filter(Boolean))
const selectedSet = computed(() => new Set(props.selectedIds))
const allVisibleSelected = computed(() => visibleIds.value.length > 0 && visibleIds.value.every((id) => selectedSet.value.has(id)))
const someVisibleSelected = computed(() => visibleIds.value.some((id) => selectedSet.value.has(id)))

const rowId = (row: any): string => String(row?.[props.rowIdKey] || row?.id || row?.__id || '')
const isSelected = (row: any) => selectedSet.value.has(rowId(row))
const rowKey = (row: any, rowIndex: number) => {
  const stableKey = row?.[props.rowIdKey]
    || row?.id
    || row?.__id
    || row?.stock_ref
    || row?.stock_item_id
    || [
      row?.game_id,
      row?.full_number,
      row?.virtual_copy_index,
      row?.dimension,
      row?.number,
    ].filter((value) => value !== undefined && value !== null && value !== '').join(':')

  return stableKey ? String(stableKey) : `row-${rowIndex}`
}

const toggleAllVisible = () => {
  const next = new Set(props.selectedIds)

  if (allVisibleSelected.value) {
    visibleIds.value.forEach((id) => next.delete(id))
  } else {
    visibleIds.value.forEach((id) => next.add(id))
  }

  emit('update:selectedIds', Array.from(next))
}

const toggleRow = (row: any) => {
  const id = rowId(row)
  if (!id) return

  const next = new Set(props.selectedIds)
  if (next.has(id)) {
    next.delete(id)
  } else {
    next.add(id)
  }

  emit('update:selectedIds', Array.from(next))
}

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

const cellValue = (row: any, column: DataTableColumn) => row?.[column.key]

const formatCell = (row: any, column: DataTableColumn) => formatAdminValue(cellValue(row, column), column.type, column.key)
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

.np-select-col {
  text-align: center;
  width: 44px;
}
</style>

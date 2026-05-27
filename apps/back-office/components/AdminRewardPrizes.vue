<template>
  <AdminDataTable
    title="Summary"
    :columns="columns"
    :rows="sortedRows"
    sortable
    :sort-key="sortKey"
    :sort-direction="sortDirection"
    empty-title="No prizes"
    empty-message="This reward result has no prize rows yet."
    @sort-change="setSort"
  >
    <template #cell-label="{ row }">
      <div class="fw-semibold">{{ row.label }}</div>
      <div class="text-muted fs-12">{{ row.type }}</div>
    </template>
    <template #cell-amount="{ row }">
      <span class="badge bg-primary-transparent text-primary">
        {{ formatRewardPrizeAmount(row.amount, row.currency) }}
      </span>
    </template>
    <template #cell-numbers="{ row }">
      <div class="np-reward-number-list">
        <span
          v-for="(number, index) in row.numbers"
          :key="`${row.type}-${index}`"
          class="np-reward-number"
          :class="{ 'text-muted': !displayRewardNumber(number) }"
        >
          {{ displayRewardNumber(number) || '-' }}
        </span>
      </div>
    </template>
  </AdminDataTable>
</template>

<script setup lang="ts">
type SortDirection = 'asc' | 'desc'

const props = defineProps<{
  prizes?: unknown[] | null
}>()

const groups = computed(() => normalizeRewardPrizeGroups(props.prizes || []))
const sortKey = ref('sort_order')
const sortDirection = ref<SortDirection>('asc')
const columns = [
  { key: 'label', label: 'Prize' },
  { key: 'count', label: 'Rows', type: 'number' },
  { key: 'digits', label: 'Digits', type: 'number' },
  { key: 'amount', label: 'Payout amount', type: 'money' },
  { key: 'numbers', label: 'Winning numbers' },
]

const rows = computed(() => groups.value.map((group, index) => ({
  ...group,
  sort_order: index,
  numbers_text: group.numbers.map((number) => displayRewardNumber(number)).join(' '),
})))

const sortedRows = computed(() => {
  const direction = sortDirection.value === 'desc' ? -1 : 1
  const key = sortKey.value

  return [...rows.value].sort((left, right) => compareSortValue(sortValue(left, key), sortValue(right, key)) * direction)
})

const displayRewardNumber = (value: string) => {
  const normalized = String(value || '').trim()
  return normalized && !normalized.startsWith('pending_') ? normalized : ''
}

const setSort = (value: { key: string, direction: SortDirection }) => {
  sortKey.value = value.key
  sortDirection.value = value.direction
}

const sortValue = (row: Record<string, any>, key: string) => {
  if (key === 'numbers') {
    return row.numbers_text
  }

  return row[key]
}

const compareSortValue = (left: any, right: any) => {
  if (left === right) return 0
  if (left === undefined || left === null || left === '') return 1
  if (right === undefined || right === null || right === '') return -1

  const leftNumber = Number(left)
  const rightNumber = Number(right)
  if (Number.isFinite(leftNumber) && Number.isFinite(rightNumber)) {
    return leftNumber - rightNumber
  }

  return String(left).localeCompare(String(right), 'th')
}
</script>

<style scoped>
.np-reward-number-list {
  display: flex;
  flex-wrap: wrap;
  gap: .5rem;
  white-space: normal;
}

.np-reward-number {
  border: 1px solid var(--default-border);
  border-radius: 4px;
  font-family: var(--default-font-family);
  font-size: .875rem;
  line-height: 1.2;
  min-width: 4.75rem;
  padding: .35rem .5rem;
  text-align: center;
}
</style>

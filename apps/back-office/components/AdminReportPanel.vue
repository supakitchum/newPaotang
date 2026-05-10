<template>
  <div>
    <div class="card custom-card">
      <div class="card-header d-flex align-items-center justify-content-between">
        <div class="card-title">Report summary</div>
        <span v-if="metadata" class="badge bg-light text-default">{{ metadata }}</span>
      </div>
      <div class="card-body">
        <AdminLoader v-if="loading" />
        <div v-else-if="summaryItems.length" class="row g-3">
          <div v-for="item in summaryItems" :key="item.key" class="col-sm-6 col-xl-3">
            <div class="border rounded-2 p-3 h-100">
              <p class="text-muted mb-1">{{ item.label }}</p>
              <h6 class="mb-0 text-break">{{ item.value }}</h6>
            </div>
          </div>
        </div>
        <AdminEmptyState v-else title="No report summary" message="No summary values were returned for this report." />
      </div>
    </div>

    <AdminDataTable
      title="Report rows"
      :columns="rowColumns"
      :rows="rowValues"
      :loading="loading"
      empty-title="No report rows"
      empty-message="No row-level report data was returned for the selected filters."
    />

    <div class="card custom-card">
      <div class="card-header">
        <div class="card-title">Raw report payload</div>
      </div>
      <div class="card-body">
        <AdminLoader v-if="loading" />
        <pre v-else class="np-admin-json mb-0">{{ formatted }}</pre>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  data: any
  loading?: boolean
}>()

const formatted = computed(() => JSON.stringify(props.data || {}, null, 2))
const report = computed(() => props.data || {})
const metadata = computed(() => {
  if (!report.value.report_key) return ''
  const parts = [report.value.scope, report.value.report_key, report.value.tenant_id].filter(Boolean)
  return parts.join(' / ')
})
const summaryItems = computed(() => Object.entries(report.value.summary || {})
  .map(([key, value]) => ({
    key,
    label: labelize(key),
    value: formatReportValue(value),
  })))
const rawRows = computed(() => Array.isArray(report.value.rows) ? report.value.rows : [])
const rowColumns = computed(() => {
  const keys = Array.from(new Set(rawRows.value.flatMap((row: any) => Object.keys(row || {})))).slice(0, 8)
  return keys.map((key) => ({ key, label: labelize(key) }))
})
const rowValues = computed(() => rawRows.value.map((row: any) => Object.fromEntries(rowColumns.value.map((column) => [
  column.key,
  formatReportValue(row?.[column.key]),
]))))

const labelize = (key: string) => key
  .replace(/[._-]/g, ' ')
  .replace(/\b\w/g, (char) => char.toUpperCase())

const formatReportValue = (value: any): string => {
  if (value === undefined || value === null || value === '') return '-'
  if (typeof value === 'object') {
    if ('amount' in value) {
      const currency = value.currency ? ` ${value.currency}` : ''
      return `${new Intl.NumberFormat('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(value.amount || 0))}${currency}`
    }

    return JSON.stringify(value)
  }

  return String(value)
}
</script>

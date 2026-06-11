<template>
  <div>
    <div class="card custom-card">
      <div class="card-header d-flex align-items-center justify-content-between">
        <div class="card-title">{{ translateReportText('Report summary', locale) }}</div>
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
        <AdminEmptyState
          v-else
          :title="translateReportText('No report summary', locale)"
          :message="translateReportText('No summary values were returned for this report.', locale)"
        />
      </div>
    </div>

    <div v-if="sections.length" class="row g-3 mb-3">
      <div v-for="(section, sectionIndex) in sections" :key="sectionKey(section, sectionIndex)" class="col-12">
        <div class="card custom-card mb-0">
          <div class="card-header">
            <div>
              <div class="card-title mb-1">{{ translateReportText(section.title, locale) }}</div>
              <p v-if="section.description" class="text-muted fs-12 mb-0">{{ translateReportText(section.description, locale) }}</p>
            </div>
          </div>
          <div class="card-body">
            <div v-if="sectionItems(section).length" class="row g-3">
              <div v-for="item in sectionItems(section)" :key="item.key" class="col-sm-6 col-xl-3">
                <div class="border rounded-2 p-3 h-100">
                  <p class="text-muted mb-1">{{ item.label }}</p>
                  <h6 class="mb-0 text-break">{{ item.value }}</h6>
                </div>
              </div>
            </div>
            <AdminDataTable
              v-else
              :columns="translatedSectionColumns(section)"
              :rows="sortedSectionRows(section, sectionIndex)"
              :embedded="true"
              :sortable="sectionRows(section).length > 1"
              :sort-key="sectionSortKey(section, sectionIndex)"
              :sort-direction="sectionSortDirection(section, sectionIndex)"
              :empty-title="translateReportText('No section rows', locale)"
              :empty-message="translateReportText('No data was returned for this report section.', locale)"
              @sort-change="setSectionSort(section, sectionIndex, $event)"
            >
              <template v-for="column in translatedSectionColumns(section)" :key="column.key" #[`cell-${column.key}`]="{ value }">
                {{ formatReportValue(value, column) }}
              </template>
            </AdminDataTable>
          </div>
        </div>
      </div>
    </div>

    <AdminDataTable
      :title="translateReportText('Report rows', locale)"
      :columns="translatedRowColumns"
      :rows="rowValues"
      :loading="loading"
      :sortable="rawRows.length > 1"
      :sort-key="mainSort.key"
      :sort-direction="mainSort.direction"
      :empty-title="translateReportText('No report rows', locale)"
      :empty-message="translateReportText('No row-level report data was returned for the selected filters.', locale)"
      @sort-change="setMainSort"
    >
      <template v-for="column in translatedRowColumns" :key="column.key" #[`cell-${column.key}`]="{ value }">
        {{ formatReportValue(value, column) }}
      </template>
    </AdminDataTable>
  </div>
</template>

<script setup lang="ts">
import { formatAdminValue, labelize } from '~/utils/format'
import { translateReportColumns, translateReportFieldLabel, translateReportText, translateReportValue } from '~/utils/reportI18n'

const props = defineProps<{
  data: any
  loading?: boolean
}>()

type ReportSort = {
  key: string
  direction: 'asc' | 'desc'
}

const { locale } = useAdminLocale()
const report = computed(() => props.data || {})
const metadata = computed(() => {
  if (!report.value.report_key) return ''
  const parts = [report.value.scope, report.value.report_key, report.value.tenant_id, report.value.game_id].filter(Boolean)
  return parts.join(' / ')
})
const summaryItems = computed(() => Object.entries(report.value.summary || {})
  .map(([key, value]) => ({
    key,
    label: translateReportFieldLabel(key, labelize(key), locale.value),
    value: formatReportValue(value, { key }),
  })))
const sections = computed(() => Array.isArray(report.value.sections) ? report.value.sections : [])
const rawRows = computed(() => Array.isArray(report.value.rows) ? report.value.rows : [])
const rowColumns = computed(() => {
  if (Array.isArray(report.value.columns) && report.value.columns.length) {
    return report.value.columns
  }

  const keys = Array.from(new Set(rawRows.value.flatMap((row: any) => Object.keys(row || {}))))
  return keys.map((key) => ({ key, label: labelize(key) }))
})
const translatedRowColumns = computed(() => translateReportColumns(rowColumns.value, locale.value))
const mainSort = reactive<ReportSort>({ key: '', direction: 'asc' })
const sectionSorts = reactive<Record<string, ReportSort>>({})
const rowValues = computed(() => sortRows(rawRows.value, rowColumns.value, mainSort))

const sectionItems = (section: any) => {
  if (!Array.isArray(section?.items)) return []

  return section.items.map((item: any) => ({
    key: item.key || item.label,
    label: translateReportFieldLabel(item.key || item.label, item.label || labelize(item.key || ''), locale.value),
    value: formatReportValue(item.value, item),
  }))
}

const sectionRows = (section: any) => Array.isArray(section?.rows) ? section.rows : []
const sectionColumns = (section: any) => {
  if (Array.isArray(section?.columns) && section.columns.length) {
    return section.columns
  }

  const keys = Array.from(new Set(sectionRows(section).flatMap((row: any) => Object.keys(row || {}))))
  return keys.map((key) => ({ key, label: labelize(key) }))
}

const sectionKey = (section: any, index: number) => String(section?.key || section?.title || `section-${index}`)
const translatedSectionColumns = (section: any) => translateReportColumns(sectionColumns(section), locale.value)

const sectionSort = (section: any, index: number): ReportSort => {
  const key = sectionKey(section, index)
  if (!sectionSorts[key]) {
    sectionSorts[key] = { key: '', direction: 'asc' }
  }

  return sectionSorts[key]
}

const sectionSortKey = (section: any, index: number) => sectionSort(section, index).key
const sectionSortDirection = (section: any, index: number) => sectionSort(section, index).direction
const sortedSectionRows = (section: any, index: number) => sortRows(sectionRows(section), sectionColumns(section), sectionSort(section, index))

const setMainSort = (value: ReportSort) => {
  mainSort.key = value.key
  mainSort.direction = value.direction
}

const setSectionSort = (section: any, index: number, value: ReportSort) => {
  const state = sectionSort(section, index)
  state.key = value.key
  state.direction = value.direction
}

const sortRows = (rows: any[], columns: any[], sort: ReportSort) => {
  if (!sort.key) {
    return rows
  }

  const column = columns.find((item: any) => item.key === sort.key)
  const direction = sort.direction === 'desc' ? -1 : 1

  return [...rows].sort((left, right) => compareValues(sortValue(left?.[sort.key], column), sortValue(right?.[sort.key], column)) * direction)
}

const sortValue = (value: any, column: any) => {
  if (value === undefined || value === null) return ''
  if (typeof value === 'object') {
    if ('amount' in value) return Number(value.amount || 0)
    if ('value' in value) return value.value
    return formatAdminValue(value, column?.type, column?.key)
  }
  if (typeof value === 'boolean') return value ? 1 : 0
  if (typeof value === 'number') return value
  if (column?.type === 'datetime' || String(column?.key || '').endsWith('_at')) {
    const timestamp = Date.parse(String(value))
    return Number.isNaN(timestamp) ? String(value).toLowerCase() : timestamp
  }

  const numeric = Number(String(value).replace(/,/g, ''))
  if (String(value).trim() !== '' && !Number.isNaN(numeric)) {
    return numeric
  }

  return String(value).toLowerCase()
}

const formatReportValue = (value: any, column: any) => translateReportValue(formatAdminValue(value, column?.type, column?.key), locale.value)

const compareValues = (left: any, right: any) => {
  if (left === right) return 0
  if (left === '') return 1
  if (right === '') return -1
  return left > right ? 1 : -1
}
</script>

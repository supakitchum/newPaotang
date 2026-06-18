<template>
  <div>
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
              <template v-for="column in translatedSectionColumns(section)" :key="column.key" #[`cell-${column.key}`]="{ row, value }">
                <button
                  v-if="column.type === 'report-details'"
                  class="btn btn-info btn-sm np-report-detail-button"
                  type="button"
                  :disabled="!hasReportDetails(row)"
                  @click="openReportDetails(row, section.title)"
                >
                  <i class="ri-list-check-2" aria-hidden="true" />
                  <span class="visually-hidden">{{ translateReportText('More', locale) }}</span>
                </button>
                <template v-else>
                  {{ formatReportValue(value, column) }}
                </template>
              </template>
            </AdminDataTable>
          </div>
        </div>
      </div>
    </div>

    <AdminDataTable
      v-if="showMainRows"
      :title="mainRowsTitle"
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
      <template v-for="column in translatedRowColumns" :key="column.key" #[`cell-${column.key}`]="{ row, value }">
        <button
          v-if="column.type === 'report-details'"
          class="btn btn-info btn-sm np-report-detail-button"
          type="button"
          :disabled="!hasReportDetails(row)"
          @click="openReportDetails(row, mainRowsTitle)"
        >
          <i class="ri-list-check-2" aria-hidden="true" />
          <span class="visually-hidden">{{ translateReportText('More', locale) }}</span>
        </button>
        <template v-else>
          {{ formatReportValue(value, column) }}
        </template>
      </template>
    </AdminDataTable>

    <Teleport to="body">
      <div v-if="detailModal.open" class="modal fade show np-report-detail-modal" tabindex="-1" role="dialog" aria-modal="true">
        <div class="modal-dialog modal-xl modal-dialog-scrollable">
          <div class="modal-content">
            <div class="modal-header">
              <div>
                <h5 class="modal-title">{{ translateReportText(detailModal.title, locale) }}</h5>
                <p class="text-muted fs-12 mb-0">
                  {{ translateReportText('Total count', locale) }}: {{ formatReportValue(detailModal.rows.length, { type: 'number' }) }}
                </p>
              </div>
              <button class="btn-close" type="button" :aria-label="translateReportText('Close', locale)" @click="closeReportDetails" />
            </div>
            <div class="modal-body">
              <AdminDataTable
                :columns="translatedDetailColumns"
                :rows="sortedDetailRows"
                :embedded="true"
                :sortable="detailModal.rows.length > 1"
                :sort-key="detailSort.key"
                :sort-direction="detailSort.direction"
                :empty-title="translateReportText('No section rows', locale)"
                :empty-message="translateReportText('No data was returned for this report section.', locale)"
                @sort-change="setDetailSort"
              >
                <template v-for="column in translatedDetailColumns" :key="column.key" #[`cell-${column.key}`]="{ value }">
                  {{ formatReportValue(value, column) }}
                </template>
              </AdminDataTable>
            </div>
            <div class="modal-footer">
              <button class="btn btn-light" type="button" @click="closeReportDetails">
                {{ translateReportText('Close', locale) }}
              </button>
            </div>
          </div>
        </div>
      </div>
      <div v-if="detailModal.open" class="modal-backdrop fade show" @click="closeReportDetails" />
    </Teleport>
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
const sections = computed(() => Array.isArray(report.value.sections) ? report.value.sections : [])
const rawRows = computed(() => Array.isArray(report.value.rows) ? report.value.rows : [])
const showMainRows = computed(() => {
  if (report.value.report_key === 'overview') {
    return false
  }

  if (props.loading) {
    return true
  }

  return rawRows.value.length > 0 || sections.value.length === 0
})
const mainRowsTitle = computed(() => (
  report.value.report_key === 'overview'
    ? translateReportText('Revenue summary', locale.value)
    : translateReportText('Report rows', locale.value)
))
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
const detailSort = reactive<ReportSort>({ key: '', direction: 'asc' })
const detailModal = reactive<{
  open: boolean
  title: string
  columns: any[]
  rows: any[]
}>({
  open: false,
  title: '',
  columns: [],
  rows: [],
})
const rowValues = computed(() => sortRows(rawRows.value, rowColumns.value, mainSort))
const translatedDetailColumns = computed(() => translateReportColumns(detailModal.columns, locale.value))
const sortedDetailRows = computed(() => sortRows(detailModal.rows, detailModal.columns, detailSort))

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

const setDetailSort = (value: ReportSort) => {
  detailSort.key = value.key
  detailSort.direction = value.direction
}

const detailColumnsForRow = (row: any) => {
  if (Array.isArray(row?.detail_columns) && row.detail_columns.length) {
    return row.detail_columns
  }

  const detailRows = Array.isArray(row?.detail_rows) ? row.detail_rows : []
  const keys = Array.from(new Set(detailRows.flatMap((detailRow: any) => Object.keys(detailRow || {}))))
  return keys.map((key) => ({ key, label: labelize(key) }))
}

const hasReportDetails = (row: any) => Array.isArray(row?.detail_rows) && row.detail_rows.length > 0

const openReportDetails = (row: any, fallbackTitle?: string) => {
  if (!hasReportDetails(row)) {
    return
  }

  detailModal.title = row?.detail_title || fallbackTitle || 'Report rows'
  detailModal.columns = detailColumnsForRow(row)
  detailModal.rows = Array.isArray(row?.detail_rows) ? row.detail_rows : []
  detailSort.key = ''
  detailSort.direction = 'asc'
  detailModal.open = true
}

const closeReportDetails = () => {
  detailModal.open = false
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

<style scoped>
.np-report-detail-button {
  align-items: center;
  display: inline-flex;
  justify-content: center;
  min-width: 42px;
}

.np-report-detail-modal {
  display: block;
  z-index: 1085;
}

:global(.modal-backdrop.show) {
  z-index: 1080;
}
</style>

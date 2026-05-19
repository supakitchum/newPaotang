<template>
  <div class="np-stock-number-detail">
    <AdminApiState :error="error" />
    <AdminLoader v-if="loading" />
    <AdminEmptyState
      v-else-if="!record"
      title="No number detail"
      message="Select a stock generation row to load full-number capacity and ticket rows."
      icon="ri-search-line"
    />
    <template v-else>
      <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-3">
        <div>
          <div class="d-flex flex-wrap align-items-center gap-2 mb-1">
            <h5 class="mb-0 font-monospace">{{ record.full_number || '-' }}</h5>
            <span :class="['badge', stockModeBadgeClass]">{{ titleize(String(record.stock_mode || 'stock')) }}</span>
          </div>
          <div class="text-muted fs-12">
            Game {{ record.game_id || '-' }}
            <span v-if="record.batch_id"> | Batch {{ record.batch_id }}</span>
            <span v-if="record.profile_id"> | Profile {{ record.profile_id }}</span>
          </div>
        </div>
        <div class="d-flex flex-wrap gap-2">
          <span class="badge bg-light text-default border">Front 3 {{ record.front3 || '-' }}</span>
          <span class="badge bg-light text-default border">Back 3 {{ record.back3 || '-' }}</span>
          <span class="badge bg-light text-default border">Back 2 {{ record.back2 || '-' }}</span>
        </div>
      </div>

      <div class="np-stock-number-detail__metric-grid mb-3">
        <div v-for="metric in metrics" :key="metric.key">
          <span class="text-muted fs-12">{{ metric.label }}</span>
          <strong>{{ metric.value }}</strong>
        </div>
      </div>

      <div v-if="unmaterializedCapacity > 0" class="alert alert-info d-flex align-items-start gap-2">
        <i class="ri-information-line fs-18" />
        <div>
          <div class="fw-semibold">Virtual capacity without ticket rows</div>
          <div>
            {{ formatNumber(unmaterializedCapacity) }} generated tickets are still virtual. Per-ticket image URLs appear only after stock is materialized.
          </div>
        </div>
      </div>

      <div class="row g-3">
        <div class="col-12 col-xl-6">
          <section class="np-stock-number-detail__panel">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Central effective limits</h6>
              <span class="badge bg-primary-transparent text-primary">Central</span>
            </div>
            <LimitTable :rows="centralLimitRows" />
          </section>
        </div>
        <div class="col-12 col-xl-6">
          <section class="np-stock-number-detail__panel">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Partner effective limits</h6>
              <span class="badge bg-info-transparent text-info">Partner scope</span>
            </div>
            <template v-if="partnerLimitRows.length">
              <div class="np-stock-number-detail__partner-grid mb-3">
                <div>
                  <span class="text-muted fs-12">Assigned capacity</span>
                  <strong>{{ formatNumber(record.partner_limits?.assigned_capacity) }}</strong>
                </div>
                <div>
                  <span class="text-muted fs-12">Partner available</span>
                  <strong>{{ formatNumber(record.partner_limits?.available_count) }}</strong>
                </div>
                <div>
                  <span class="text-muted fs-12">Partner reserved</span>
                  <strong>{{ formatNumber(record.partner_limits?.reserved_count) }}</strong>
                </div>
                <div>
                  <span class="text-muted fs-12">Partner sold</span>
                  <strong>{{ formatNumber(record.partner_limits?.sold_count) }}</strong>
                </div>
              </div>
              <LimitTable :rows="partnerLimitRows" />
            </template>
            <AdminEmptyState
              v-else
              title="No partner scope selected"
              message="Choose partner scope and enter a partner ID to inspect partner-specific limits."
              icon="ri-building-4-line"
            />
          </section>
        </div>
      </div>

      <section class="np-stock-number-detail__panel mt-3">
        <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
          <h6 class="mb-0">Materialized central tickets</h6>
          <span class="badge bg-secondary-transparent text-secondary">{{ formatNumber(stockItems.length) }} rows</span>
        </div>
        <TicketTable :rows="stockItems" empty-message="No central stock item rows have been materialized for this virtual number yet." />
      </section>

      <section class="np-stock-number-detail__panel mt-3">
        <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
          <h6 class="mb-0">Materialized local tickets</h6>
          <span class="badge bg-secondary-transparent text-secondary">{{ formatNumber(localStockItems.length) }} rows</span>
        </div>
        <TicketTable :rows="localStockItems" empty-message="No local partner ticket rows have been materialized for this number yet." />
      </section>
    </template>
  </div>
</template>

<script setup lang="ts">
import type { PropType } from 'vue'
import { defineComponent, h, resolveComponent } from 'vue'
import { formatDateTime, titleize } from '~/utils/format'

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
  error?: any
}>()

const record = computed(() => props.record || null)
const stockItems = computed(() => Array.isArray(record.value?.stock_items) ? record.value.stock_items : [])
const localStockItems = computed(() => Array.isArray(record.value?.local_stock_items) ? record.value.local_stock_items : [])
const unmaterializedCapacity = computed(() => numberValue(record.value?.unmaterialized_capacity_count))
const stockModeBadgeClass = computed(() => String(record.value?.stock_mode || '').toLowerCase() === 'virtual'
  ? 'bg-info-transparent text-info'
  : 'bg-secondary-transparent text-secondary')
const centralLimitRows = computed(() => limitRows(record.value?.central_limits))
const partnerLimitRows = computed(() => limitRows(record.value?.partner_limits))
const metrics = computed(() => [
  { key: 'generated_capacity', label: 'Generated capacity', value: formatNumber(record.value?.generated_capacity) },
  { key: 'total_count', label: 'Total tickets', value: formatNumber(record.value?.total_count) },
  { key: 'available_count', label: 'Available', value: formatNumber(record.value?.available_count) },
  { key: 'reserved_count', label: 'Reserved', value: formatNumber(record.value?.reserved_count ?? record.value?.allocated_count) },
  { key: 'sold_count', label: 'Sold', value: formatNumber(record.value?.sold_count) },
  { key: 'materialized_stock_count', label: 'Central rows', value: formatNumber(record.value?.materialized_stock_count) },
  { key: 'materialized_local_stock_count', label: 'Local rows', value: formatNumber(record.value?.materialized_local_stock_count) },
  { key: 'unmaterialized_capacity_count', label: 'Virtual only', value: formatNumber(record.value?.unmaterialized_capacity_count) },
])

function limitRows(source: any) {
  const limits = source?.limits || {}
  return ['front3', 'back3', 'back2']
    .map((dimension) => limits[dimension])
    .filter((entry) => entry && typeof entry === 'object')
    .map((entry) => ({
      dimension: titleize(String(entry.dimension || '')),
      value: entry.value || '-',
      defaultLimit: formatLimit(entry.default_limit),
      overrideLimit: formatLimit(entry.override_limit),
      effectiveLimit: formatLimit(entry.effective_limit),
      used: formatNumber(entry.used_count),
      remaining: formatLimit(entry.remaining_limit),
    }))
}

function numberValue(value: any) {
  const parsed = Number(value || 0)
  return Number.isFinite(parsed) ? parsed : 0
}

function formatNumber(value: any) {
  if (value === undefined || value === null || value === '') {
    return '-'
  }
  return new Intl.NumberFormat('th-TH', { maximumFractionDigits: 0 }).format(numberValue(value))
}

function formatLimit(value: any) {
  if (value === null) {
    return 'Unlimited'
  }
  return formatNumber(value)
}

const LimitTable = defineComponent({
  props: {
    rows: {
      type: Array as PropType<Array<Record<string, any>>>,
      required: true,
    },
  },
  setup(componentProps) {
    return () => componentProps.rows.length
      ? h('div', { class: 'table-responsive' }, [
          h('table', { class: 'table table-bordered text-nowrap w-100 mb-0' }, [
            h('thead', [
              h('tr', [
                h('th', 'Dimension'),
                h('th', 'Value'),
                h('th', 'Default'),
                h('th', 'Override'),
                h('th', 'Effective'),
                h('th', 'Used'),
                h('th', 'Remaining'),
              ]),
            ]),
            h('tbody', componentProps.rows.map((row) => h('tr', { key: `${row.dimension}-${row.value}` }, [
              h('td', row.dimension),
              h('td', { class: 'font-monospace' }, row.value),
              h('td', row.defaultLimit),
              h('td', row.overrideLimit),
              h('td', row.effectiveLimit),
              h('td', row.used),
              h('td', row.remaining),
            ]))),
          ]),
        ])
      : h(resolveComponent('AdminEmptyState'), {
          title: 'No limit details',
          message: 'The backend did not return limit details for this scope.',
          icon: 'ri-list-check-3',
        })
  },
})

const TicketTable = defineComponent({
  props: {
    rows: {
      type: Array as PropType<Array<Record<string, any>>>,
      required: true,
    },
    emptyMessage: {
      type: String,
      required: true,
    },
  },
  setup(componentProps) {
    return () => componentProps.rows.length
      ? h('div', { class: 'table-responsive' }, [
          h('table', { class: 'table table-bordered text-nowrap w-100 mb-0' }, [
            h('thead', [
              h('tr', [
                h('th', 'Ticket'),
                h('th', 'Status'),
                h('th', 'Copy'),
                h('th', 'Partner'),
                h('th', 'Tenant'),
                h('th', 'Image status'),
                h('th', 'Image URLs'),
                h('th', 'Updated'),
              ]),
            ]),
            h('tbody', componentProps.rows.map((row) => h('tr', { key: ticketKey(row) }, [
              h('td', { class: 'font-monospace text-break' }, row.id || '-'),
              h('td', [h(resolveComponent('AdminStatusBadge'), { status: row.status || 'unknown' })]),
              h('td', formatNumber(row.virtual_copy_index)),
              h('td', { class: 'font-monospace text-break' }, row.partner_id || '-'),
              h('td', { class: 'font-monospace text-break' }, row.tenant_id || '-'),
              h('td', [
                h(resolveComponent('AdminStatusBadge'), {
                  status: row.image_generation_status || (row.image_url ? 'available' : 'not_materialized'),
                  label: row.image_generation_status || (row.image_url ? 'Image ready' : 'No image'),
                }),
                row.image_generation_error
                  ? h('div', { class: 'text-danger small text-break mt-1' }, row.image_generation_error)
                  : null,
              ]),
              h('td', imageUrlNodes(row)),
              h('td', formatDateTime(row.updated_at || row.created_at || row.synced_at)),
            ]))),
          ]),
        ])
      : h(resolveComponent('AdminEmptyState'), {
          title: 'No materialized tickets',
          message: componentProps.emptyMessage,
          icon: 'ri-ticket-2-line',
        })
  },
})

function ticketKey(row: any) {
  return String(row?.id || row?.stock_item_id || row?.virtual_stock_ref || JSON.stringify(row))
}

function imageUrlNodes(row: any) {
  const links = [
    { label: 'Image', url: row.image_url },
    { label: 'Thumb', url: row.image_thumb_url },
  ].filter((link) => typeof link.url === 'string' && link.url.trim() !== '')

  if (!links.length) {
    return '-'
  }

  return h('div', { class: 'd-flex flex-wrap gap-2' }, links.map((link) => h('a', {
    key: link.label,
    href: link.url,
    target: '_blank',
    rel: 'noopener noreferrer',
    class: 'btn btn-sm btn-light btn-wave',
  }, link.label)))
}
</script>

<style scoped>
.np-stock-number-detail__metric-grid,
.np-stock-number-detail__partner-grid {
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(auto-fit, minmax(8rem, 1fr));
}

.np-stock-number-detail__metric-grid > div,
.np-stock-number-detail__partner-grid > div {
  background: rgb(var(--light-rgb));
  border: 1px solid var(--default-border);
  border-radius: 4px;
  display: grid;
  gap: .25rem;
  padding: .65rem .75rem;
}

.np-stock-number-detail__panel {
  background: var(--custom-white);
  border: 1px solid var(--default-border);
  border-radius: 6px;
  padding: 1rem;
}
</style>

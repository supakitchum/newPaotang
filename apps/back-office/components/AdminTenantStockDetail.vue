<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Tenant Stock detail</div>
        <p class="text-muted fs-12 mb-0">{{ subtitle }}</p>
      </div>
      <AdminStatusBadge v-if="record" :status="record.status" />
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!record" title="No detail data" message="This stock record has no data to display yet." />
      <div v-else class="row g-3">
        <div v-for="section in sections" :key="section.title" class="col-12 col-xl-6">
          <div class="border rounded p-3 h-100">
            <h6 class="mb-3">{{ section.title }}</h6>
            <dl class="row mb-0 gy-2">
              <template v-for="item in section.items" :key="item.key">
                <dt class="col-sm-5 text-muted fw-semibold">{{ item.label }}</dt>
                <dd class="col-sm-7 mb-0">
                  <AdminStatusBadge v-if="item.type === 'status'" :status="item.value" />
                  <a v-else-if="item.type === 'link' && item.value" :href="item.value" target="_blank" rel="noopener">{{ item.value }}</a>
                  <code v-else-if="item.mono" class="np-admin-code">{{ item.value || '-' }}</code>
                  <span v-else>{{ item.value || '-' }}</span>
                </dd>
              </template>
            </dl>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime } from '~/utils/format'

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
}>()

const subtitle = computed(() => {
  if (!props.record) {
    return 'Readable stock ownership, timing, and image state.'
  }

  return [props.record.full_number, props.record.game_id].filter(Boolean).join(' · ')
})

const sections = computed(() => {
  const record = props.record || {}
  return [
    {
      title: 'Ticket',
      items: [
        item('full_number', 'Number', record.full_number, true),
        item('status', 'Status', record.status, false, 'status'),
        item('stock_mode', 'Stock mode', record.stock_mode),
        item('id', 'Stock ID', record.id, true),
        item('stock_ref', 'Stock ref', record.stock_ref, true),
        item('virtual_copy_index', 'Virtual copy', record.virtual_copy_index),
      ],
    },
    {
      title: 'Ownership',
      items: [
        item('owner_customer_id', 'Owner', record.owner_customer_id || record.owner, true),
        item('tenant_id', 'Tenant', record.tenant_id, true),
        item('partner_id', 'Partner', record.partner_id, true),
        item('allocation_id', 'Allocation', record.allocation_id, true),
        item('remaining_count', 'Remaining', record.remaining_count),
        item('availability_status', 'Availability', record.availability_status, false, 'status'),
      ],
    },
    {
      title: 'Timing',
      items: [
        item('created_at', 'Created', formatMaybeDate(record.created_at)),
        item('updated_at', 'Updated', formatMaybeDate(record.updated_at)),
        item('synced_at', 'Synced', formatMaybeDate(record.synced_at)),
        item('reserved_at', 'Reserved', formatMaybeDate(record.reserved_at)),
        item('sold_at', 'Sold', formatMaybeDate(record.sold_at)),
      ],
    },
    {
      title: 'Image',
      items: [
        item('image_status', 'Status', record.image_status || record.image_generation_status, false, 'status'),
        item('image_error', 'Error', record.image_error || record.image_generation_error),
        item('preview_image_url', 'Preview URL', record.preview_image_url || record.image_thumb_url, false, 'link'),
        item('image_url', 'Full URL', record.image_url, false, 'link'),
      ],
    },
  ]
})

function item(key: string, label: string, value: any, mono = false, type: string | null = null) {
  return {
    key,
    label,
    value: normalizeValue(value),
    mono,
    type,
  }
}

function normalizeValue(value: any) {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  if (typeof value === 'object') {
    if ('amount' in value && 'currency' in value) {
      return `${value.amount} ${value.currency}`
    }
    return Object.entries(value)
      .map(([key, entry]) => `${key}: ${entry}`)
      .join(', ')
  }

  return String(value)
}

function formatMaybeDate(value: any) {
  if (!value) {
    return ''
  }

  return formatDateTime(String(value))
}
</script>

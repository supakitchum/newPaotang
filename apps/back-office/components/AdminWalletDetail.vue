<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Wallet detail</div>
        <p class="text-muted fs-12 mb-0">{{ subtitle }}</p>
      </div>
      <AdminStatusBadge v-if="displayRecord?.status" :status="displayRecord.status" />
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!displayRecord" title="No wallet data" message="This wallet has no detail data to display yet." />
      <div v-else class="row g-3">
        <div v-for="section in sections" :key="section.title" class="col-12 col-xl-6">
          <div class="border rounded p-3 h-100">
            <h6 class="mb-3">{{ section.title }}</h6>
            <dl class="row mb-0 gy-2">
              <template v-for="item in section.items" :key="item.key">
                <dt class="col-sm-5 text-muted fw-semibold">{{ item.label }}</dt>
                <dd class="col-sm-7 mb-0">
                  <AdminStatusBadge v-if="item.type === 'status'" :status="item.value" />
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
import { computed } from 'vue'
import { formatDateTime, formatMoney as formatAdminMoney, titleize } from '~/utils/format'

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
}>()

const displayRecord = computed(() => props.record || null)

const formatMoney = (value: any) => {
  const amount = typeof value === 'object' ? Number(value.amount || 0) / 100 : Number(value) / 100
  const currency = typeof value === 'object' ? String(value.currency || 'THB') : 'THB'

  if (!Number.isFinite(amount)) {
    return '-'
  }

  return formatAdminMoney(amount, currency)
}

const valueOrDash = (value: unknown) => {
  const text = String(value ?? '').trim()

  return text === '' ? '-' : text
}

const subtitle = computed(() => {
  const row = displayRecord.value

  if (!row) {
    return 'Customer wallet and balance'
  }

  return [
    row.customer_no || row.member_no,
    row.customer_name,
    row.id,
  ].filter(Boolean).join(' · ')
})

const sections = computed(() => {
  const row = displayRecord.value

  if (!row) {
    return []
  }

  return [
    {
      title: 'Wallet',
      items: [
        { key: 'id', label: 'Wallet ID', value: valueOrDash(row.id), mono: true },
        { key: 'name', label: 'Wallet name', value: valueOrDash(row.name) },
        { key: 'type', label: 'Wallet type', value: titleize(valueOrDash(row.type)) },
        { key: 'status', label: 'Status', value: valueOrDash(row.status), type: 'status' },
      ],
    },
    {
      title: 'Customer',
      items: [
        { key: 'customer_no', label: 'Customer no', value: valueOrDash(row.customer_no || row.member_no) },
        { key: 'customer_name', label: 'Name', value: valueOrDash(row.customer_name || row.customer?.name) },
        { key: 'phone', label: 'Phone', value: valueOrDash(row.customer?.phone) },
        { key: 'email', label: 'Email', value: valueOrDash(row.customer?.email) },
        { key: 'customer_id', label: 'Customer ID', value: valueOrDash(row.customer_id), mono: true },
      ],
    },
    {
      title: 'Balance',
      items: [
        { key: 'balance', label: 'Balance', value: formatMoney(row.balance) },
        { key: 'currency', label: 'Currency', value: valueOrDash(row.balance?.currency || row.currency || 'THB') },
      ],
    },
    {
      title: 'Timestamps',
      items: [
        { key: 'created_at', label: 'Created', value: formatDateTime(row.created_at) },
        { key: 'updated_at', label: 'Updated', value: formatDateTime(row.updated_at) },
      ],
    },
  ]
})
</script>

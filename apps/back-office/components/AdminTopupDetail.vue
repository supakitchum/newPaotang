<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Topup detail</div>
        <p class="text-muted fs-12 mb-0">{{ subtitle }}</p>
      </div>
      <AdminStatusBadge v-if="displayRecord?.status" :status="displayRecord.status" />
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!displayRecord" title="No topup data" message="This topup has no detail data to display yet." />
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
        <div class="col-12">
          <div class="border rounded p-3">
            <h6 class="mb-3">Slip</h6>
            <AdminImagePreview :image="displayRecord.slip" label="Topup slip" />
            <p v-if="displayRecord.slip?.expires_at" class="text-muted fs-12 mt-2 mb-0">
              Retention expires {{ formatDateTime(displayRecord.slip.expires_at) }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { formatDateTime } from '~/utils/format'

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
}>()

const displayRecord = computed(() => props.record || null)
const customer = computed(() => displayRecord.value?.customer || null)
const wallet = computed(() => displayRecord.value?.wallet || null)

const valueOrDash = (value: unknown) => {
  const text = String(value ?? '').trim()

  return text === '' || text === '[object Object]' ? '-' : text
}

const formatMoney = (value: any) => {
  const amount = typeof value === 'object' && value !== null ? value.amount : value
  const currency = typeof value === 'object' && value !== null ? String(value.currency || 'THB') : 'THB'

  if (amount === undefined || amount === null || amount === '' || !Number.isFinite(Number(amount))) {
    return '-'
  }

  return `${new Intl.NumberFormat('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(amount) / 100)} ${currency === 'THB' ? 'บาท' : currency}`
}

const subtitle = computed(() => {
  const row = displayRecord.value

  if (!row) {
    return 'Topup request and payment proof'
  }

  return [
    row.reference,
    customer.value?.customer_no || customer.value?.member_no,
    customer.value?.name,
  ].filter(Boolean).join(' · ')
})

const sections = computed(() => {
  const row = displayRecord.value

  if (!row) {
    return []
  }

  return [
    {
      title: 'Topup',
      items: [
        { key: 'id', label: 'Topup ID', value: valueOrDash(row.id), mono: true },
        { key: 'reference', label: 'Reference', value: valueOrDash(row.reference), mono: true },
        { key: 'channel', label: 'Channel', value: valueOrDash(row.channel) },
        { key: 'status', label: 'Status', value: valueOrDash(row.status), type: 'status' },
        { key: 'amount', label: 'Amount', value: formatMoney(row.amount) },
        { key: 'bonus_amount', label: 'Bonus', value: formatMoney(row.bonus_amount) },
      ],
    },
    {
      title: 'Customer',
      items: [
        { key: 'customer_no', label: 'Customer no', value: valueOrDash(customer.value?.customer_no || customer.value?.member_no) },
        { key: 'customer_name', label: 'Name', value: valueOrDash(customer.value?.name || customer.value?.display_name) },
        { key: 'customer_phone', label: 'Phone', value: valueOrDash(customer.value?.phone) },
        { key: 'customer_email', label: 'Email', value: valueOrDash(customer.value?.email) },
        { key: 'customer_id', label: 'Customer ID', value: valueOrDash(customer.value?.id || row.customer_id), mono: true },
      ],
    },
    {
      title: 'Review',
      items: [
        { key: 'transfer_at', label: 'Transfer at', value: formatDateTime(row.transfer_at) },
        { key: 'reviewed_at', label: 'Reviewed at', value: formatDateTime(row.reviewed_at) },
        { key: 'reviewed_by_admin_id', label: 'Reviewed by', value: valueOrDash(row.reviewed_by_admin_id), mono: true },
        { key: 'admin_note', label: 'Reason', value: valueOrDash(row.admin_note) },
      ],
    },
    {
      title: 'Wallet',
      items: [
        { key: 'wallet_id', label: 'Wallet ID', value: valueOrDash(wallet.value?.id), mono: true },
        { key: 'wallet_name', label: 'Wallet name', value: valueOrDash(wallet.value?.name) },
        { key: 'wallet_balance', label: 'Balance', value: formatMoney(wallet.value?.balance) },
        { key: 'created_at', label: 'Created', value: formatDateTime(row.created_at) },
      ],
    },
  ]
})
</script>

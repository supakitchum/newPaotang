<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Customer detail</div>
        <p class="text-muted fs-12 mb-0">{{ subtitle }}</p>
      </div>
      <div v-if="displayRecord" class="d-flex align-items-center gap-2">
        <AdminStatusBadge :status="displayRecord.online_status" />
        <AdminStatusBadge :status="displayRecord.status" />
      </div>
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!displayRecord" title="No customer data" message="This customer has no detail data to display yet." />
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
            <h6 class="mb-3">Wallets</h6>
            <AdminEmptyState v-if="walletRows.length === 0" title="No wallets" message="This customer has no wallet records." />
            <div v-else class="table-responsive">
              <table class="table table-bordered text-nowrap mb-0">
                <thead>
                  <tr>
                    <th scope="col">Wallet</th>
                    <th scope="col">Status</th>
                    <th scope="col">Balance</th>
                    <th scope="col">Currency</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="wallet in walletRows" :key="wallet.id">
                    <td><code class="np-admin-code">{{ wallet.id }}</code></td>
                    <td><AdminStatusBadge :status="wallet.status" /></td>
                    <td>{{ wallet.balance }}</td>
                    <td>{{ wallet.currency }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { formatDateTime, formatMoney as formatAdminMoney } from '~/utils/format'

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
}>()

const displayRecord = computed(() => props.record || null)

const formatMoney = (value: any) => {
  if (!value) {
    return '-'
  }

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
  if (!displayRecord.value) {
    return 'Customer profile and activity'
  }

  return [
    displayRecord.value.customer_no || displayRecord.value.member_no,
    displayRecord.value.name,
    displayRecord.value.phone,
  ].filter(Boolean).join(' · ')
})

const sections = computed(() => {
  const row = displayRecord.value

  if (!row) {
    return []
  }

  return [
    {
      title: 'Basic',
      items: [
        { key: 'id', label: 'Customer ID', value: valueOrDash(row.id), mono: true },
        { key: 'customer_no', label: 'Customer no', value: valueOrDash(row.customer_no || row.member_no) },
        { key: 'tenant_id', label: 'Tenant ID', value: valueOrDash(row.tenant_id), mono: true },
        { key: 'status', label: 'Status', value: valueOrDash(row.status), type: 'status' },
      ],
    },
    {
      title: 'Contact',
      items: [
        { key: 'name', label: 'Name', value: valueOrDash(row.name) },
        { key: 'phone', label: 'Phone', value: valueOrDash(row.phone) },
        { key: 'email', label: 'Email', value: valueOrDash(row.email) },
      ],
    },
    {
      title: 'Online',
      items: [
        { key: 'online_status', label: 'Online', value: valueOrDash(row.online_status), type: 'status' },
        { key: 'last_online_at', label: 'Last online', value: formatDateTime(row.last_online_at) },
        { key: 'last_login_at', label: 'Last login', value: formatDateTime(row.last_login_at) },
      ],
    },
    {
      title: 'Activity',
      items: [
        { key: 'order_count', label: 'Orders', value: valueOrDash(row.order_count) },
        { key: 'lifetime_spend', label: 'Lifetime spend', value: formatMoney(row.lifetime_spend) },
        { key: 'created_at', label: 'Created', value: formatDateTime(row.created_at) },
        { key: 'updated_at', label: 'Updated', value: formatDateTime(row.updated_at) },
      ],
    },
  ]
})

const walletRows = computed(() => {
  const wallets = Array.isArray(displayRecord.value?.wallets) ? displayRecord.value.wallets : []

  return wallets.map((wallet: Record<string, any>) => ({
    id: valueOrDash(wallet.id),
    status: valueOrDash(wallet.status),
    balance: formatMoney(wallet.balance),
    currency: valueOrDash(wallet.balance?.currency || wallet.currency || 'THB'),
  }))
})
</script>

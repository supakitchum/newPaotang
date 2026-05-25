<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Order detail</div>
        <p class="text-muted fs-12 mb-0">{{ subtitle }}</p>
      </div>
      <div v-if="displayRecord" class="d-flex flex-wrap align-items-center gap-2">
        <AdminStatusBadge :status="displayRecord.status" />
        <AdminStatusBadge :status="displayRecord.payment_status" />
      </div>
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!displayRecord" title="No order data" message="This order has no detail data to display yet." />
      <div v-else class="row g-3">
        <div v-for="section in sections" :key="section.title" class="col-12 col-xl-6">
          <div class="border rounded p-3 h-100">
            <h6 class="mb-3">{{ section.title }}</h6>
            <dl class="row mb-0 gy-2">
              <template v-for="item in section.items" :key="item.key">
                <dt class="col-sm-5 text-muted fw-semibold">{{ item.label }}</dt>
                <dd class="col-sm-7 mb-0">
                  <AdminStatusBadge v-if="item.type === 'status'" :status="item.value" />
                  <a v-else-if="item.type === 'link' && item.value !== '-'" :href="item.value" target="_blank" rel="noreferrer">{{ item.value }}</a>
                  <code v-else-if="item.mono" class="np-admin-code">{{ item.value || '-' }}</code>
                  <span v-else>{{ item.value || '-' }}</span>
                </dd>
              </template>
            </dl>
          </div>
        </div>

        <div class="col-12">
          <div class="border rounded p-3">
            <h6 class="mb-3">Tickets</h6>
            <AdminEmptyState v-if="ticketRows.length === 0" title="No tickets" message="This order has no ticket rows." />
            <div v-else class="table-responsive">
              <table class="table table-bordered text-nowrap mb-0">
                <thead>
                  <tr>
                    <th scope="col">Ticket ID</th>
                    <th scope="col">Number</th>
                    <th scope="col">Game</th>
                    <th scope="col">Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="ticket in ticketRows" :key="ticket.id">
                    <td><code class="np-admin-code">{{ ticket.id }}</code></td>
                    <td>{{ ticket.full_number }}</td>
                    <td><code class="np-admin-code">{{ ticket.game_id }}</code></td>
                    <td><AdminStatusBadge :status="ticket.status" /></td>
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
import { formatDateTime } from '~/utils/format'

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
}>()

const displayRecord = computed(() => props.record || null)
const customer = computed(() => displayRecord.value?.customer || null)
const wallet = computed(() => displayRecord.value?.wallet || null)
const payment = computed(() => displayRecord.value?.payment || null)

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

const customerName = computed(() => valueOrDash(customer.value?.name || customer.value?.display_name || customer.value?.full_name))

const subtitle = computed(() => {
  const row = displayRecord.value

  if (!row) {
    return 'Order, payment, and ticket summary'
  }

  return [
    row.id,
    row.reference,
    customerName.value !== '-' ? customerName.value : '',
  ].filter(Boolean).join(' · ')
})

const sections = computed(() => {
  const row = displayRecord.value

  if (!row) {
    return []
  }

  return [
    {
      title: 'Order',
      items: [
        { key: 'id', label: 'Order ID', value: valueOrDash(row.id), mono: true },
        { key: 'reference', label: 'Reference', value: valueOrDash(row.reference), mono: true },
        { key: 'tenant_id', label: 'Tenant ID', value: valueOrDash(row.tenant_id), mono: true },
        { key: 'game_id', label: 'Game ID', value: valueOrDash(row.game_id), mono: true },
        { key: 'status', label: 'Status', value: valueOrDash(row.status), type: 'status' },
        { key: 'payment_status', label: 'Payment status', value: valueOrDash(row.payment_status), type: 'status' },
        { key: 'total', label: 'Total', value: formatMoney(row.total) },
        { key: 'ticket_count', label: 'Tickets', value: valueOrDash(row.ticket_count || ticketRows.value.length) },
      ],
    },
    {
      title: 'Customer',
      items: [
        { key: 'customer_name', label: 'Name', value: customerName.value },
        { key: 'customer_no', label: 'Customer no', value: valueOrDash(customer.value?.customer_no || customer.value?.member_no) },
        { key: 'customer_phone', label: 'Phone', value: valueOrDash(customer.value?.phone) },
        { key: 'customer_email', label: 'Email', value: valueOrDash(customer.value?.email) },
        { key: 'customer_id', label: 'Customer ID', value: valueOrDash(customer.value?.id || row.customer_id), mono: true },
      ],
    },
    {
      title: 'Payment',
      items: [
        { key: 'payment_id', label: 'Payment ID', value: valueOrDash(payment.value?.id), mono: true },
        { key: 'provider', label: 'Provider', value: valueOrDash(payment.value?.provider) },
        { key: 'payment_reference', label: 'Reference', value: valueOrDash(payment.value?.reference), mono: true },
        { key: 'provider_reference', label: 'Provider ref', value: valueOrDash(payment.value?.provider_reference), mono: true },
        { key: 'payment_status', label: 'Status', value: valueOrDash(payment.value?.status), type: 'status' },
        { key: 'payment_amount', label: 'Amount', value: formatMoney(payment.value ? { amount: payment.value.amount, currency: payment.value.currency } : null) },
        { key: 'redirect_url', label: 'Redirect URL', value: valueOrDash(payment.value?.redirect_url), type: 'link' },
        { key: 'paid_at', label: 'Paid at', value: formatDateTime(payment.value?.paid_at) },
      ],
    },
    {
      title: 'Wallet & timestamps',
      items: [
        { key: 'wallet_id', label: 'Wallet ID', value: valueOrDash(wallet.value?.id), mono: true },
        { key: 'wallet_name', label: 'Wallet name', value: valueOrDash(wallet.value?.name) },
        { key: 'wallet_balance', label: 'Wallet balance', value: formatMoney(wallet.value?.balance) },
        { key: 'created_at', label: 'Created', value: formatDateTime(row.created_at) },
        { key: 'paid_at', label: 'Order paid at', value: formatDateTime(row.paid_at) },
        { key: 'admin_note', label: 'Admin note', value: valueOrDash(row.admin_note) },
      ],
    },
  ]
})

const ticketRows = computed(() => {
  const tickets = Array.isArray(displayRecord.value?.tickets) ? displayRecord.value.tickets : []

  return tickets.map((ticket: Record<string, any>) => ({
    id: valueOrDash(ticket.id),
    full_number: valueOrDash(ticket.full_number),
    game_id: valueOrDash(ticket.game_id),
    status: valueOrDash(ticket.status),
  }))
})
</script>

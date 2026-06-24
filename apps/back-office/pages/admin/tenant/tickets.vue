<template>
  <div>
    <AdminPageHeader title="Tickets" :breadcrumbs="['Admin', 'Tenant', 'Tickets']">
      <template #actions>
        <button class="btn btn-outline-primary btn-wave" type="button" :disabled="loading || !tenantId" @click="loadCustomers()">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before viewing ticket inventory." />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" dismissible @dismiss="error = null" />

    <div class="card custom-card">
      <div class="card-body">
        <div class="row g-3 align-items-end">
          <div class="col-12 col-lg-5">
            <label class="form-label" for="ticket-game-filter">Game / Draw</label>
            <select id="ticket-game-filter" v-model="filters.game_id" class="form-select" :disabled="loading" @change="loadCustomers()">
              <option v-if="!gameOptions.length" value="">No game found</option>
              <option v-for="game in gameOptions" :key="game.id" :value="game.id">
                {{ gameLabel(game) }}
              </option>
            </select>
          </div>
          <div class="col-12 col-lg-5">
            <label class="form-label" for="ticket-search-filter">Search customer / number</label>
            <input
              id="ticket-search-filter"
              v-model="filters.search"
              class="form-control"
              type="search"
              placeholder="Customer no, name, phone, or lottery number"
              @keyup.enter="loadCustomers()"
            >
          </div>
          <div class="col-12 col-lg-2">
            <button class="btn btn-primary btn-wave w-100" type="button" :disabled="loading || !tenantId" @click="loadCustomers()">
              <i class="ri-filter-3-line me-1" />
              Apply
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="row g-3 mb-3">
      <div class="col-12 col-md-4">
        <div class="card custom-card np-ticket-kpi">
          <div class="card-body">
            <span class="text-muted fs-12">Customers in draw</span>
            <h4 class="mb-0">{{ formatNumber(rows.length) }}</h4>
          </div>
        </div>
      </div>
      <div class="col-12 col-md-4">
        <div class="card custom-card np-ticket-kpi">
          <div class="card-body">
            <span class="text-muted fs-12">Tickets on this page</span>
            <h4 class="mb-0">{{ formatNumber(pageTicketCount) }}</h4>
          </div>
        </div>
      </div>
      <div class="col-12 col-md-4">
        <div class="card custom-card np-ticket-kpi">
          <div class="card-body">
            <span class="text-muted fs-12">Selected draw</span>
            <h6 class="mb-0 text-truncate">{{ selectedGameLabel }}</h6>
          </div>
        </div>
      </div>
    </div>

    <AdminDataTable
      title="Customer ticket inventory"
      :columns="customerColumns"
      :rows="rows"
      :loading="loading"
      empty-title="No customer tickets"
      empty-message="Customers with tickets in the selected draw will appear here."
    >
      <template #cell-customer="{ row }">
        <div class="fw-semibold">{{ row.customer_name || '-' }}</div>
        <div class="text-muted fs-12">{{ row.customer_no || row.customer_id }}</div>
      </template>
      <template #cell-contact="{ row }">
        <div>{{ row.phone || '-' }}</div>
        <div class="text-muted fs-12">{{ row.email || '-' }}</div>
      </template>
      <template #cell-ticket_count="{ row }">
        <span class="fw-semibold">{{ formatNumber(row.ticket_count) }}</span>
      </template>
      <template #cell-order_count="{ row }">
        {{ formatNumber(row.order_count) }}
      </template>
      <template #cell-last_ticket_at="{ row }">
        {{ formatDateTime(row.last_ticket_at) }}
      </template>
      <template #cell-customer_status="{ row }">
        <AdminStatusBadge :status="row.customer_status || 'active'" />
      </template>
      <template #rowActions="{ row }">
        <button class="btn btn-sm btn-primary btn-wave" type="button" @click="openTicketModal(row)">
          <i class="ri-ticket-2-line me-1" />
          View tickets
        </button>
      </template>
      <template #footer>
        <AdminPagination
          :next-cursor="meta.next_cursor"
          :has-previous="pageState.index > 0"
          :loading="loading"
          :current-page="pageState.index + 1"
          :page-size="filters.limit"
          @previous="loadPreviousCustomers"
          @next="loadNextCustomers"
        />
      </template>
    </AdminDataTable>

    <AdminModal v-model="ticketModal.open" :title="ticketModalTitle" size="xl">
      <AdminAlert v-if="ticketModal.error" :type="alertType(ticketModal.error)" :message="ticketModal.error.message" :details="ticketModal.error.details" dismissible @dismiss="ticketModal.error = null" />
      <div v-if="ticketModal.customer" class="np-ticket-customer-summary mb-3">
        <div>
          <div class="fw-semibold">{{ ticketModal.customer.customer_name || ticketModal.customer.customer?.name || '-' }}</div>
          <div class="text-muted fs-12">{{ ticketModal.customer.customer_no || ticketModal.customer.customer_id }}</div>
        </div>
        <div class="text-end">
          <div class="text-muted fs-12">Tickets in draw</div>
          <div class="fw-bold">{{ formatNumber(ticketModal.customer.ticket_count) }}</div>
        </div>
      </div>

      <AdminDataTable
        title="Lottery tickets"
        :columns="ticketColumns"
        :rows="ticketModal.rows"
        :loading="ticketModal.loading"
        empty-title="No tickets"
        empty-message="This customer has no tickets in the selected draw."
        embedded
      >
        <template #cell-image="{ row }">
          <AdminImagePreview :image="ticketImage(row)" label="Ticket image" />
        </template>
        <template #cell-full_number="{ row }">
          <span class="np-ticket-number">{{ row.full_number }}</span>
        </template>
        <template #cell-status="{ row }">
          <AdminStatusBadge :status="row.status" />
        </template>
        <template #cell-price="{ row }">
          {{ formatMoney(row.price) }}
        </template>
        <template #cell-reward="{ row }">
          <div>{{ titleize(row.reward_status?.status || '-') }}</div>
          <div v-if="row.reward_status?.prize_amount" class="text-muted fs-12">{{ formatMoney(row.reward_status.prize_amount) }}</div>
        </template>
        <template #cell-created_at="{ row }">
          {{ formatDateTime(row.created_at) }}
        </template>
        <template #rowActions="{ row }">
          <button class="btn btn-sm btn-light btn-wave" type="button" @click="selectTicket(row)">
            Detail
          </button>
        </template>
        <template #footer>
          <AdminPagination
            :next-cursor="ticketModal.meta.next_cursor"
            :has-previous="ticketModal.pageState.index > 0"
            :loading="ticketModal.loading"
            :current-page="ticketModal.pageState.index + 1"
            :page-size="ticketModal.limit"
            @previous="loadPreviousTickets"
            @next="loadNextTickets"
          />
        </template>
      </AdminDataTable>

      <div v-if="ticketModal.selected" class="card custom-card mt-3 mb-0">
        <div class="card-header">
          <div class="card-title">Ticket detail</div>
        </div>
        <div class="card-body">
          <div class="row g-3">
            <div class="col-12 col-lg-4">
              <div class="np-ticket-image-panel">
                <img v-if="ticketFullImage(ticketModal.selected)" :src="ticketFullImage(ticketModal.selected)" alt="Ticket image">
                <div v-else class="text-muted">No ticket image</div>
              </div>
            </div>
            <div class="col-12 col-lg-8">
              <div class="row g-3">
                <div v-for="item in selectedTicketFields" :key="item.label" class="col-12 col-md-6">
                  <div class="text-muted fs-12">{{ item.label }}</div>
                  <div class="fw-semibold text-break">{{ item.value }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <template #footer>
        <button class="btn btn-light btn-wave" type="button" @click="ticketModal.open = false">Close</button>
      </template>
    </AdminModal>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, formatMoney, titleize } from '~/utils/format'

definePageMeta({
  layout: 'admin',
})

type AnyRecord = Record<string, any>

const api = useAdminApi()
const session = useAdminSession()
const tenantId = computed(() => session.currentTenantId.value)
const numberFormatter = new Intl.NumberFormat('th-TH')

const filters = reactive({
  game_id: '',
  search: '',
  limit: 20,
})
const rows = ref<AnyRecord[]>([])
const gameOptions = ref<AnyRecord[]>([])
const loading = ref(false)
const error = ref<any>(null)
const meta = reactive({ next_cursor: null as string | null, has_more: false })
const pageState = reactive<{ cursors: Array<string | null>, index: number }>({ cursors: [null], index: 0 })

const ticketModal = reactive<{
  open: boolean
  customer: AnyRecord | null
  rows: AnyRecord[]
  loading: boolean
  error: any
  selected: AnyRecord | null
  limit: number
  meta: { next_cursor: string | null, has_more: boolean }
  pageState: { cursors: Array<string | null>, index: number }
}>({
  open: false,
  customer: null,
  rows: [],
  loading: false,
  error: null,
  selected: null,
  limit: 20,
  meta: { next_cursor: null, has_more: false },
  pageState: { cursors: [null], index: 0 },
})

const customerColumns = [
  { key: 'customer', label: 'Customer' },
  { key: 'contact', label: 'Contact' },
  { key: 'ticket_count', label: 'Tickets', type: 'number' },
  { key: 'order_count', label: 'Orders', type: 'number' },
  { key: 'customer_status', label: 'Customer status', type: 'status' },
  { key: 'last_ticket_at', label: 'Latest ticket', type: 'datetime' },
]
const ticketColumns = [
  { key: 'image', label: 'Image' },
  { key: 'full_number', label: 'Lottery number' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'price', label: 'Price', type: 'money' },
  { key: 'reward', label: 'Reward status' },
  { key: 'created_at', label: 'Created', type: 'datetime' },
]

const selectedGameLabel = computed(() => {
  const game = gameOptions.value.find((item) => String(item.id) === String(filters.game_id))
  return game ? gameLabel(game) : '-'
})
const pageTicketCount = computed(() => rows.value.reduce((sum, row) => sum + Number(row.ticket_count || 0), 0))
const ticketModalTitle = computed(() => {
  const customer = ticketModal.customer
  if (!customer) return 'Customer tickets'
  return `${customer.customer_name || customer.customer_no || customer.customer_id} - tickets`
})
const selectedTicketFields = computed(() => {
  const row = ticketModal.selected || {}
  return [
    { label: 'Ticket ID', value: row.id || '-' },
    { label: 'Lottery number', value: row.full_number || '-' },
    { label: 'Game', value: row.game?.name || row.game?.code || row.game_id || '-' },
    { label: 'Order', value: row.order?.reference || row.order_id || '-' },
    { label: 'Customer', value: row.customer?.name || row.customer?.customer_no || row.customer_id || '-' },
    { label: 'Status', value: titleize(row.status || '-') },
    { label: 'Reward status', value: titleize(row.reward_status?.status || '-') },
    { label: 'Price', value: formatMoney(row.price) },
    { label: 'Created', value: formatDateTime(row.created_at) },
    { label: 'Image status', value: titleize(row.image_status || '-') },
  ]
})

watch(tenantId, () => {
  resetCustomerPagination()
  void loadCustomers()
})

onMounted(() => {
  void loadCustomers()
})

async function loadCustomers(cursor: string | null = null, mode: 'reset' | 'next' | 'previous' | 'current' = 'reset') {
  if (!tenantId.value) return
  loading.value = true
  error.value = null
  try {
    const response: any = await api.apiFetch('/admin/tenant/tickets', {
      scope: 'tenant',
      query: {
        game_id: filters.game_id || undefined,
        search: filters.search || undefined,
        limit: filters.limit,
        cursor: cursor || undefined,
      },
    })
    const responseMeta = response?.meta || {}
    gameOptions.value = Array.isArray(responseMeta.games) ? responseMeta.games : gameOptions.value
    if (!filters.game_id && responseMeta.selected_game_id) {
      filters.game_id = String(responseMeta.selected_game_id)
    }
    rows.value = Array.isArray(response?.data) ? response.data : []
    meta.next_cursor = responseMeta.next_cursor || null
    meta.has_more = Boolean(responseMeta.has_more || responseMeta.next_cursor)
    updatePageState(pageState, cursor, mode)
  } catch (err: any) {
    error.value = err
  } finally {
    loading.value = false
  }
}

function openTicketModal(row: AnyRecord) {
  ticketModal.open = true
  ticketModal.customer = row
  ticketModal.rows = []
  ticketModal.selected = null
  ticketModal.error = null
  ticketModal.pageState = { cursors: [null], index: 0 }
  ticketModal.meta = { next_cursor: null, has_more: false }
  void loadCustomerTickets()
}

async function loadCustomerTickets(cursor: string | null = null, mode: 'reset' | 'next' | 'previous' | 'current' = 'reset') {
  if (!tenantId.value || !ticketModal.customer?.customer_id) return
  ticketModal.loading = true
  ticketModal.error = null
  try {
    const response: any = await api.apiFetch('/admin/tenant/tickets', {
      scope: 'tenant',
      query: {
        view: 'tickets',
        customer_id: ticketModal.customer.customer_id,
        game_id: filters.game_id || undefined,
        limit: ticketModal.limit,
        cursor: cursor || undefined,
      },
    })
    ticketModal.rows = Array.isArray(response?.data) ? response.data : []
    ticketModal.meta.next_cursor = response?.meta?.next_cursor || null
    ticketModal.meta.has_more = Boolean(response?.meta?.has_more || response?.meta?.next_cursor)
    ticketModal.selected = ticketModal.rows[0] || null
    updatePageState(ticketModal.pageState, cursor, mode)
  } catch (err: any) {
    ticketModal.error = err
  } finally {
    ticketModal.loading = false
  }
}

async function selectTicket(row: AnyRecord) {
  ticketModal.selected = row
  if (!row?.id) return
  try {
    const detail: any = await api.apiFetch(`/admin/tenant/tickets/${encodeURIComponent(row.id)}`, { scope: 'tenant' })
    ticketModal.selected = detail || row
  } catch {
    ticketModal.selected = row
  }
}

function loadNextCustomers() {
  if (!meta.next_cursor) return
  void loadCustomers(meta.next_cursor, 'next')
}

function loadPreviousCustomers() {
  if (pageState.index <= 0) return
  void loadCustomers(pageState.cursors[pageState.index - 1] || null, 'previous')
}

function loadNextTickets() {
  if (!ticketModal.meta.next_cursor) return
  void loadCustomerTickets(ticketModal.meta.next_cursor, 'next')
}

function loadPreviousTickets() {
  if (ticketModal.pageState.index <= 0) return
  void loadCustomerTickets(ticketModal.pageState.cursors[ticketModal.pageState.index - 1] || null, 'previous')
}

function resetCustomerPagination() {
  pageState.cursors = [null]
  pageState.index = 0
  meta.next_cursor = null
  meta.has_more = false
}

function updatePageState(state: { cursors: Array<string | null>, index: number }, cursor: string | null, mode: 'reset' | 'next' | 'previous' | 'current') {
  if (mode === 'reset') {
    state.cursors = [null]
    state.index = 0
    return
  }
  if (mode === 'next') {
    state.index += 1
    state.cursors[state.index] = cursor
    return
  }
  if (mode === 'previous') {
    state.index = Math.max(0, state.index - 1)
  }
}

function ticketImage(row: AnyRecord) {
  return {
    url: row.image_url || row.preview_image_url || row.image_thumb_url || '',
    thumb_url: row.image_thumb_url || row.preview_image_url || row.image_url || '',
  }
}

function ticketFullImage(row: AnyRecord | null) {
  if (!row) return ''
  return String(row.image_url || row.preview_image_url || row.image_thumb_url || '').trim()
}

function gameLabel(game: AnyRecord) {
  const ticketCount = Number(game.ticket_count || 0)
  const suffix = ticketCount > 0 ? ` (${formatNumber(ticketCount)} tickets)` : ''
  return `${game.name || game.code || game.id}${game.draw_at ? ` - ${formatDateTime(game.draw_at)}` : ''}${suffix}`
}

function formatNumber(value: unknown) {
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numberFormatter.format(numeric) : String(value ?? '-')
}

function alertType(err: any) {
  const status = Number(err?.status || 0)
  if (status === 401 || status === 403) return 'danger'
  if (status >= 500) return 'danger'
  return 'warning'
}
</script>

<style scoped>
.np-ticket-kpi .card-body {
  min-height: 92px;
}

.np-ticket-customer-summary {
  align-items: center;
  background: rgba(248, 250, 252, 0.9);
  border: 1px solid rgba(148, 163, 184, 0.22);
  border-radius: 8px;
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
}

.np-ticket-number {
  background: #fff8db;
  border-radius: 6px;
  color: #111827;
  display: inline-flex;
  font-weight: 800;
  letter-spacing: .18em;
  padding: .25rem .55rem;
}

.np-ticket-image-panel {
  align-items: center;
  background: #f8fafc;
  border: 1px solid #dbe3ef;
  border-radius: 8px;
  display: flex;
  justify-content: center;
  min-height: 220px;
  overflow: hidden;
  padding: .75rem;
}

.np-ticket-image-panel img {
  border-radius: 6px;
  max-height: 52vh;
  max-width: 100%;
  object-fit: contain;
}
</style>

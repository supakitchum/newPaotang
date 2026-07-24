<template>
  <div>
    <AdminPageHeader title="Customer Notifications" :breadcrumbs="['Admin', 'Tenant', 'Customer Notifications']">
      <template #actions>
        <button class="btn btn-primary-light btn-wave" type="button" :disabled="loadingHistory || !tenantId" @click="refreshPage">
          <i class="ri-refresh-line me-1" />
          {{ phrase('Refresh') }}
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" :message="phrase('Select a tenant scope before managing customer notifications.')" />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" dismissible @dismiss="error = null" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="row g-4">
      <div class="col-12 col-xxl-5">
        <div class="card custom-card np-customer-notification-composer">
          <div class="card-header">
            <div>
              <div class="card-title">{{ phrase('Send notification') }}</div>
              <div class="text-muted fs-12">{{ phrase('Direct message to one customer') }}</div>
            </div>
          </div>
          <div class="card-body">
            <div class="mb-4">
              <label class="form-label" for="notification-customer-search">{{ phrase('Customer') }}</label>
              <div class="input-group">
                <span class="input-group-text"><i class="ri-search-line" /></span>
                <input
                  id="notification-customer-search"
                  v-model="customerSearch"
                  class="form-control"
                  :placeholder="phrase('Search name, phone, email, or customer number')"
                  autocomplete="off"
                  @focus="customerResultsOpen = true"
                  @keyup.enter="searchCustomers"
                >
                <button class="btn btn-primary" type="button" :disabled="loadingCustomers || !tenantId" @click="searchCustomers">
                  <span v-if="loadingCustomers" class="spinner-border spinner-border-sm" />
                  <span v-else>{{ phrase('Search') }}</span>
                </button>
              </div>

              <div v-if="customerResultsOpen && customers.length" class="list-group np-customer-notification-results mt-2">
                <button
                  v-for="customer in customers"
                  :key="customer.id"
                  class="list-group-item list-group-item-action d-flex align-items-center gap-3"
                  type="button"
                  @click="selectCustomer(customer)"
                >
                  <span class="np-customer-notification-avatar"><i class="ri-user-3-line" /></span>
                  <span class="min-w-0 flex-grow-1 text-start">
                    <span class="d-block fw-semibold text-truncate">{{ customer.name || customer.phone || customer.customer_no }}</span>
                    <span class="d-block text-muted fs-12 text-truncate">{{ customerSummary(customer) }}</span>
                  </span>
                  <i class="ri-arrow-right-s-line text-muted" />
                </button>
              </div>

              <div v-if="selectedCustomer" class="np-customer-notification-selected mt-3">
                <span class="np-customer-notification-avatar is-selected"><i class="ri-user-check-line" /></span>
                <div class="min-w-0 flex-grow-1">
                  <div class="fw-semibold text-truncate">{{ selectedCustomer.name || selectedCustomer.phone }}</div>
                  <div class="text-muted fs-12 text-truncate">{{ customerSummary(selectedCustomer) }}</div>
                </div>
                <button class="btn btn-sm btn-icon btn-light" type="button" :aria-label="phrase('Clear customer')" @click="clearCustomer">
                  <i class="ri-close-line" />
                </button>
              </div>
              <div v-if="fieldError('customer_id')" class="text-danger fs-12 mt-1">{{ fieldError('customer_id') }}</div>
            </div>

            <div class="d-flex align-items-center justify-content-between gap-2 mb-3">
              <label class="form-label mb-0">{{ phrase('Message content') }}</label>
              <div class="btn-group btn-group-sm" role="group" :aria-label="phrase('Message language')">
                <button
                  v-for="locale in localeOptions"
                  :key="locale.value"
                  class="btn"
                  :class="contentLocale === locale.value ? 'btn-primary' : 'btn-outline-primary'"
                  type="button"
                  @click="contentLocale = locale.value"
                >
                  {{ locale.label }}
                </button>
              </div>
            </div>

            <div class="mb-3">
              <label class="form-label" :for="`notification-title-${contentLocale}`">{{ phrase('Title') }} ({{ localeLabel(contentLocale) }})</label>
              <input
                :id="`notification-title-${contentLocale}`"
                v-model="form.title[contentLocale]"
                class="form-control"
                :class="{ 'is-invalid': fieldError('title') }"
                maxlength="160"
              >
              <div class="invalid-feedback">{{ fieldError('title') }}</div>
              <div class="form-text text-end">{{ form.title[contentLocale].length }}/160</div>
            </div>

            <div class="mb-4">
              <label class="form-label" :for="`notification-body-${contentLocale}`">{{ phrase('Message') }} ({{ localeLabel(contentLocale) }})</label>
              <textarea
                :id="`notification-body-${contentLocale}`"
                v-model="form.body[contentLocale]"
                class="form-control"
                :class="{ 'is-invalid': fieldError('body') }"
                rows="5"
                maxlength="1000"
              />
              <div class="invalid-feedback">{{ fieldError('body') }}</div>
              <div class="form-text text-end">{{ form.body[contentLocale].length }}/1000</div>
            </div>

            <div class="row g-3">
              <div :class="selectedAction?.entity_required ? 'col-md-6' : 'col-12'">
                <label class="form-label" for="notification-destination">{{ phrase('Destination') }}</label>
                <select id="notification-destination" v-model="form.action_key" class="form-select" :class="{ 'is-invalid': fieldError('action_key') }">
                  <option v-for="option in actionOptions" :key="option.key" :value="option.key">{{ phrase(option.label) }}</option>
                </select>
                <div class="invalid-feedback">{{ fieldError('action_key') }}</div>
              </div>
              <div v-if="selectedAction?.entity_required" class="col-md-6">
                <label class="form-label" for="notification-entity-id">{{ phrase('Record ID') }}</label>
                <input
                  id="notification-entity-id"
                  v-model="form.action_entity_id"
                  class="form-control"
                  :class="{ 'is-invalid': fieldError('action_entity_id') }"
                  maxlength="100"
                >
                <div class="invalid-feedback">{{ fieldError('action_entity_id') }}</div>
              </div>
            </div>
          </div>
          <div class="card-footer d-flex justify-content-between gap-2">
            <button class="btn btn-light btn-wave" type="button" :disabled="sending" @click="resetMessage">
              {{ phrase('Clear') }}
            </button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="!canSend" @click="openConfirmation">
              <i class="ri-send-plane-2-line me-1" />
              {{ phrase('Send notification') }}
            </button>
          </div>
        </div>
      </div>

      <div class="col-12 col-xxl-7">
        <div class="card custom-card">
          <div class="card-header flex-wrap gap-3">
            <div>
              <div class="card-title">{{ phrase('Send history') }}</div>
              <div class="text-muted fs-12">{{ phrase('Read and native push delivery status') }}</div>
            </div>
            <div class="ms-auto d-flex flex-wrap align-items-center gap-2">
              <label v-if="selectedCustomer" class="form-check form-switch mb-0">
                <input v-model="historySelectedOnly" class="form-check-input" type="checkbox" @change="resetHistory">
                <span class="form-check-label">{{ phrase('Selected customer only') }}</span>
              </label>
            </div>
          </div>
          <div class="card-body">
            <AdminDataTable
              :columns="historyColumns"
              :rows="historyRows"
              :loading="loadingHistory"
              :empty-title="phrase('No notifications sent')"
              :empty-message="phrase('Direct customer notifications will appear here.')"
              embedded
            >
              <template #cell-message="{ row }">
                <div class="np-customer-notification-message">
                  <span class="np-customer-notification-category"><i :class="categoryIcon(row.category)" /></span>
                  <div class="min-w-0">
                    <div class="fw-semibold text-wrap">{{ localizedText(row.title) || '-' }}</div>
                    <div class="text-muted fs-12 text-wrap np-customer-notification-preview">{{ localizedText(row.body) }}</div>
                    <div class="text-muted fs-11 mt-1">{{ destinationLabel(row.action) }}</div>
                  </div>
                </div>
              </template>
              <template #cell-customer="{ row }">
                <div class="fw-semibold">{{ row.recipient?.customer?.name || row.recipient?.customer?.phone || '-' }}</div>
                <div class="text-muted fs-12">{{ customerSummary(row.recipient?.customer || {}) }}</div>
              </template>
              <template #cell-read="{ row }">
                <AdminStatusBadge :status="row.recipient?.is_read ? 'read' : 'unread'" :label="phrase(row.recipient?.is_read ? 'Read' : 'Unread')" />
                <div v-if="row.recipient?.read_at" class="text-muted fs-11 mt-1">{{ formatDateTime(row.recipient.read_at) }}</div>
              </template>
              <template #cell-push="{ row }">
                <AdminStatusBadge :status="row.recipient?.push?.status || 'not_registered'" :label="phrase(pushLabel(row.recipient?.push?.status))" />
                <div v-if="Number(row.recipient?.push?.total_count || 0) > 0" class="text-muted fs-11 mt-1 text-wrap">
                  {{ pushCountSummary(row.recipient?.push) }}
                </div>
                <div v-if="row.recipient?.push?.last_error_code" class="text-danger fs-11 mt-1 text-wrap">{{ safeFailureLabel(row.recipient.push.last_error_code) }}</div>
              </template>
              <template #cell-creator="{ row }">
                <div>{{ creatorLabel(row.creator) }}</div>
                <div v-if="row.creator?.id" class="text-muted fs-11">{{ row.creator.id }}</div>
              </template>
              <template #cell-created_at="{ row }">
                <span class="text-nowrap">{{ formatDateTime(row.published_at) }}</span>
              </template>
            </AdminDataTable>
          </div>
          <div class="card-footer">
            <AdminPagination
              :next-cursor="historyMeta.next_cursor"
              :has-previous="historyPage.index > 0"
              :loading="loadingHistory"
              :current-page="historyPage.index + 1"
              :page-size="20"
              @previous="previousHistoryPage"
              @next="nextHistoryPage"
            />
          </div>
        </div>
      </div>
    </div>

    <AdminModal v-model="confirmationOpen" :title="phrase('Confirm notification')" size="md">
      <div class="np-customer-notification-confirm-row">
        <span>{{ phrase('Customer') }}</span>
        <strong>{{ selectedCustomer?.name || selectedCustomer?.phone }}</strong>
      </div>
      <div class="np-customer-notification-confirm-row">
        <span>{{ phrase('Destination') }}</span>
        <strong>{{ phrase(selectedAction?.label || 'No destination') }}</strong>
      </div>
      <div class="np-customer-notification-confirm-message mt-3">
        <div class="fw-semibold">{{ localizedDraft(form.title) }}</div>
        <div class="text-muted mt-1">{{ localizedDraft(form.body) }}</div>
      </div>
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" :disabled="sending" @click="confirmationOpen = false">{{ phrase('Cancel') }}</button>
        <button class="btn btn-primary btn-wave" type="button" :disabled="sending" @click="sendNotification">
          <span v-if="sending" class="spinner-border spinner-border-sm me-2" />
          <i v-else class="ri-send-plane-2-line me-1" />
          {{ phrase('Send') }}
        </button>
      </template>
    </AdminModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

type AnyRecord = Record<string, any>
type LocaleKey = 'th-TH' | 'en-US'
type ActionOption = { key: string, label: string, entity_required: boolean }

const api = useAdminApi()
const route = useRoute()
const session = useAdminSession()
const adminLocale = useAdminLocale()
const phrase = (source: unknown) => adminLocale.phrase(source)
const tenantId = computed(() => session.currentTenantId.value)
const localeOptions: Array<{ value: LocaleKey, label: string }> = [
  { value: 'th-TH', label: 'TH' },
  { value: 'en-US', label: 'EN' },
]
const historyColumns = [
  { key: 'message', label: 'Message' },
  { key: 'customer', label: 'Customer' },
  { key: 'read', label: 'Read state' },
  { key: 'push', label: 'Push delivery' },
  { key: 'creator', label: 'Creator' },
  { key: 'created_at', label: 'Sent at' },
]

const loadingCustomers = ref(false)
const loadingHistory = ref(false)
const sending = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const customerSearch = ref('')
const customers = ref<AnyRecord[]>([])
const selectedCustomer = ref<AnyRecord | null>(null)
const customerResultsOpen = ref(false)
const contentLocale = ref<LocaleKey>('th-TH')
const actionOptions = ref<ActionOption[]>([])
const notifications = ref<AnyRecord[]>([])
const historyMeta = ref<AnyRecord>({})
const historyPage = ref({ index: 0, cursors: [''] })
const historySelectedOnly = ref(false)
const confirmationOpen = ref(false)
const fieldErrors = ref<Record<string, string[]>>({})
const form = reactive({
  title: localizedDefaults(),
  body: localizedDefaults(),
  action_key: 'none',
  action_entity_id: '',
})
let customerSearchTimer: ReturnType<typeof setTimeout> | null = null

const selectedAction = computed(() => actionOptions.value.find(option => option.key === form.action_key) || actionOptions.value[0] || null)
const canSend = computed(() => Boolean(
  tenantId.value
  && selectedCustomer.value?.id
  && localizedDraft(form.title)
  && localizedDraft(form.body)
  && form.action_key
  && (!selectedAction.value?.entity_required || form.action_entity_id.trim())
  && !sending.value,
))
const historyRows = computed(() => notifications.value.flatMap((notification) => {
  const recipients = Array.isArray(notification.recipients) ? notification.recipients : []
  return recipients.map((recipient: AnyRecord) => ({ ...notification, recipient }))
}))

watch(customerSearch, () => {
  if (customerSearchTimer) clearTimeout(customerSearchTimer)
  customerSearchTimer = setTimeout(() => {
    void loadCustomers({ q: customerSearch.value })
  }, 300)
})

watch(() => form.action_key, () => {
  if (!selectedAction.value?.entity_required) form.action_entity_id = ''
  delete fieldErrors.value.action_key
  delete fieldErrors.value.action_entity_id
})

watch(tenantId, async () => {
  resetState()
  if (tenantId.value) await initializePage()
})

onMounted(async () => {
  if (tenantId.value) await initializePage()
})

onBeforeUnmount(() => {
  if (customerSearchTimer) clearTimeout(customerSearchTimer)
})

async function initializePage() {
  const requestedCustomerId = typeof route.query.customer_id === 'string' ? route.query.customer_id.trim() : ''
  await Promise.all([
    loadCustomers(requestedCustomerId ? { customer_id: requestedCustomerId } : {}),
    loadHistory(),
  ])
  if (requestedCustomerId && customers.value.length) {
    selectCustomer(customers.value[0])
    historySelectedOnly.value = true
    await resetHistory()
  }
}

async function loadCustomers(query: AnyRecord = {}) {
  if (!tenantId.value) return
  loadingCustomers.value = true
  error.value = null
  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/customer-notifications/customers', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: { limit: 20, ...query },
    })
    customers.value = Array.isArray(response.data) ? response.data : []
    const options = Array.isArray(response.meta?.action_options) ? response.meta.action_options : []
    if (options.length) {
      actionOptions.value = options.map(normalizeActionOption).filter(option => option.key)
      if (!actionOptions.value.some(option => option.key === form.action_key)) {
        form.action_key = actionOptions.value[0]?.key || 'none'
      }
    }
    customerResultsOpen.value = Boolean(customerSearch.value.trim() && customers.value.length)
  } catch (err: any) {
    error.value = err
    customers.value = []
  } finally {
    loadingCustomers.value = false
  }
}

function searchCustomers() {
  customerResultsOpen.value = true
  void loadCustomers({ q: customerSearch.value })
}

function selectCustomer(customer: AnyRecord) {
  selectedCustomer.value = customer
  customerSearch.value = customer.name || customer.phone || customer.customer_no || ''
  customerResultsOpen.value = false
  fieldErrors.value = { ...fieldErrors.value, customer_id: [] }
}

function clearCustomer() {
  selectedCustomer.value = null
  customerSearch.value = ''
  customers.value = []
  historySelectedOnly.value = false
  void resetHistory()
}

async function loadHistory(cursor = '') {
  if (!tenantId.value) return
  loadingHistory.value = true
  error.value = null
  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/customer-notifications', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: {
        limit: 20,
        cursor: cursor || undefined,
        creator_type: 'tenant_admin',
        customer_id: historySelectedOnly.value ? selectedCustomer.value?.id : undefined,
      },
    })
    notifications.value = Array.isArray(response.data) ? response.data : []
    historyMeta.value = response.meta || {}
    if (!actionOptions.value.length && Array.isArray(response.meta?.action_options)) {
      actionOptions.value = response.meta.action_options.map(normalizeActionOption).filter((option: ActionOption) => option.key)
    }
  } catch (err: any) {
    error.value = err
    notifications.value = []
    historyMeta.value = {}
  } finally {
    loadingHistory.value = false
  }
}

function nextHistoryPage() {
  const cursor = String(historyMeta.value.next_cursor || '')
  if (!cursor) return
  historyPage.value.cursors[historyPage.value.index + 1] = cursor
  historyPage.value.index += 1
  void loadHistory(cursor)
}

function previousHistoryPage() {
  if (historyPage.value.index <= 0) return
  historyPage.value.index -= 1
  void loadHistory(historyPage.value.cursors[historyPage.value.index] || '')
}

async function resetHistory() {
  historyPage.value = { index: 0, cursors: [''] }
  await loadHistory()
}

function openConfirmation() {
  fieldErrors.value = {}
  if (!canSend.value) return
  confirmationOpen.value = true
}

async function sendNotification() {
  if (!canSend.value || !tenantId.value || !selectedCustomer.value) return
  sending.value = true
  error.value = null
  successMessage.value = ''
  fieldErrors.value = {}
  try {
    await api.apiFetch('/admin/tenant/customer-notifications', {
      method: 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      successMessage: false,
      body: {
        customer_id: selectedCustomer.value.id,
        title: normalizedLocalized(form.title),
        body: normalizedLocalized(form.body),
        action_key: form.action_key,
        action_entity_id: selectedAction.value?.entity_required ? form.action_entity_id.trim() : null,
      },
    })
    confirmationOpen.value = false
    successMessage.value = phrase('Notification sent.')
    historySelectedOnly.value = true
    resetMessage(false)
    await resetHistory()
  } catch (err: any) {
    confirmationOpen.value = false
    error.value = err
    fieldErrors.value = normalizeFieldErrors(err)
  } finally {
    sending.value = false
  }
}

async function refreshPage() {
  await Promise.all([
    loadCustomers(selectedCustomer.value?.id ? { customer_id: selectedCustomer.value.id } : { q: customerSearch.value }),
    loadHistory(historyPage.value.cursors[historyPage.value.index] || ''),
  ])
}

function resetMessage(clearSelectedCustomer = false) {
  Object.assign(form, {
    title: localizedDefaults(),
    body: localizedDefaults(),
    action_key: actionOptions.value[0]?.key || 'none',
    action_entity_id: '',
  })
  fieldErrors.value = {}
  contentLocale.value = 'th-TH'
  if (clearSelectedCustomer) clearCustomer()
}

function resetState() {
  selectedCustomer.value = null
  customerSearch.value = ''
  customers.value = []
  actionOptions.value = []
  notifications.value = []
  historyMeta.value = {}
  historyPage.value = { index: 0, cursors: [''] }
  historySelectedOnly.value = false
  error.value = null
  successMessage.value = ''
  resetMessage()
}

function localizedDefaults(): Record<LocaleKey, string> {
  return { 'th-TH': '', 'en-US': '' }
}

function normalizedLocalized(value: Record<LocaleKey, string>) {
  return Object.fromEntries(Object.entries(value).map(([locale, text]) => [locale, String(text || '').trim()]).filter(([, text]) => text))
}

function localizedDraft(value: Record<LocaleKey, string>) {
  const preferred = String(adminLocale.locale.value).toLowerCase().startsWith('en') ? 'en-US' : 'th-TH'
  return value[preferred] || value['th-TH'] || value['en-US'] || ''
}

function localizedText(value: unknown) {
  if (typeof value === 'string') return value
  if (!value || typeof value !== 'object') return ''
  return localizedDraft(value as Record<LocaleKey, string>)
}

function localeLabel(locale: LocaleKey) {
  return locale === 'th-TH' ? phrase('Thai') : phrase('English')
}

function normalizeActionOption(value: AnyRecord): ActionOption {
  return {
    key: String(value?.key || ''),
    label: String(value?.label || value?.key || ''),
    entity_required: Boolean(value?.entity_required),
  }
}

function customerSummary(customer: AnyRecord) {
  return [customer.customer_no, customer.phone, customer.email].filter(Boolean).join(' · ') || '-'
}

function destinationLabel(action: AnyRecord) {
  const option = actionOptions.value.find(item => item.key === action?.key)
  const label = phrase(option?.label || action?.key || 'No destination')
  return action?.entity_id ? `${label} · ${action.entity_id}` : label
}

function creatorLabel(creator: AnyRecord) {
  if (creator?.type !== 'tenant_admin') return phrase('System')
  return creator?.name || creator?.username || creator?.email || phrase('Tenant admin')
}

function pushLabel(status: unknown) {
  const labels: Record<string, string> = {
    sent: 'Sent',
    partial: 'Partially delivered',
    queued: 'Queued',
    sending: 'Sending',
    failed: 'Failed',
    skipped: 'Skipped',
    not_registered: 'No registered device',
  }
  return labels[String(status || 'not_registered')] || String(status || 'not_registered')
}

function pushCountSummary(push: AnyRecord) {
  return [
    Number(push?.sent_count || 0) > 0 ? `${Number(push.sent_count)} ${phrase('Sent')}` : '',
    Number(push?.pending_count || 0) > 0 ? `${Number(push.pending_count)} ${phrase('Pending')}` : '',
    Number(push?.failed_count || 0) > 0 ? `${Number(push.failed_count)} ${phrase('Failed')}` : '',
  ].filter(Boolean).join(' · ')
}

function safeFailureLabel(code: unknown) {
  return String(code || '').replaceAll('_', ' ')
}

function categoryIcon(category: unknown) {
  const icons: Record<string, string> = {
    order: 'ri-shopping-bag-3-line',
    lottery: 'ri-ticket-2-line',
    topup: 'ri-add-circle-line',
    wallet: 'ri-wallet-3-line',
    reward: 'ri-trophy-line',
    activity: 'ri-gift-line',
    affiliate: 'ri-team-line',
    news: 'ri-newspaper-line',
    account: 'ri-shield-user-line',
    admin: 'ri-notification-3-line',
  }
  return icons[String(category || 'admin')] || icons.admin
}

function formatDateTime(value: unknown) {
  if (!value) return '-'
  const date = new Date(String(value))
  if (Number.isNaN(date.getTime())) return String(value)
  return new Intl.DateTimeFormat(adminLocale.locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date)
}

function fieldError(key: string) {
  return fieldErrors.value[key]?.[0] || ''
}

function normalizeFieldErrors(err: AnyRecord) {
  const source = err?.details?.fields || err?.details || {}
  if (!source || typeof source !== 'object') return {}
  return Object.fromEntries(Object.entries(source).map(([key, value]) => [key, Array.isArray(value) ? value.map(String) : [String(value)]]))
}

function alertType(err: AnyRecord) {
  return [403, 409, 422].includes(Number(err?.status)) ? 'warning' : 'danger'
}
</script>

<style scoped>
.np-customer-notification-composer {
  position: sticky;
  top: 5.5rem;
}

.np-customer-notification-results {
  max-height: 18rem;
  overflow-y: auto;
}

.np-customer-notification-avatar,
.np-customer-notification-category {
  align-items: center;
  background: rgba(var(--primary-rgb), .1);
  border-radius: 50%;
  color: var(--primary-color);
  display: inline-flex;
  flex: 0 0 auto;
  height: 2.5rem;
  justify-content: center;
  width: 2.5rem;
}

.np-customer-notification-avatar.is-selected {
  background: rgba(var(--success-rgb), .12);
  color: rgb(var(--success-rgb));
}

.np-customer-notification-selected {
  align-items: center;
  background: rgba(var(--primary-rgb), .05);
  border: 1px solid rgba(var(--primary-rgb), .18);
  border-radius: .375rem;
  display: flex;
  gap: .75rem;
  padding: .75rem;
}

.np-customer-notification-message {
  align-items: flex-start;
  display: flex;
  gap: .65rem;
  min-width: 18rem;
  white-space: normal;
}

.np-customer-notification-category {
  height: 2rem;
  width: 2rem;
}

.np-customer-notification-preview {
  display: -webkit-box;
  max-width: 22rem;
  overflow: hidden;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.np-customer-notification-confirm-row {
  align-items: flex-start;
  display: flex;
  gap: 1rem;
  justify-content: space-between;
  padding: .4rem 0;
}

.np-customer-notification-confirm-row span {
  color: var(--text-muted);
}

.np-customer-notification-confirm-message {
  background: var(--custom-white);
  border: 1px solid var(--default-border);
  border-radius: .375rem;
  padding: 1rem;
  white-space: pre-wrap;
}

.fs-11 {
  font-size: .6875rem;
}

.min-w-0 {
  min-width: 0;
}

@media (max-width: 1399.98px) {
  .np-customer-notification-composer {
    position: static;
  }
}
</style>

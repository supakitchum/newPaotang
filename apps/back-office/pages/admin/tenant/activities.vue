<template>
  <div>
    <AdminPageHeader title="Activities" :breadcrumbs="['Admin', 'Tenant', 'Activities']">
      <template #actions>
        <button class="btn btn-light btn-wave" type="button" :disabled="!tenantId" @click="openCreateModal">
          <i class="ri-add-line me-1" />
          New activity
        </button>
        <button class="btn btn-primary btn-wave" type="button" :disabled="!tenantId" @click="loadAll">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before editing activities." />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="row g-3">
      <div class="col-12">
        <div class="card custom-card">
          <div class="card-header align-items-center gap-3">
            <div class="card-title">Activity list</div>
            <div class="ms-auto d-flex flex-wrap gap-2">
              <input v-model="filters.q" class="form-control form-control-sm np-act-search" placeholder="Search activity" @keyup.enter="loadActivities">
              <select v-model="filters.type" class="form-select form-select-sm np-act-filter" @change="loadActivities">
                <option value="">All types</option>
                <option value="lucky_board">Lucky board</option>
                <option value="cashback">Cashback</option>
              </select>
              <select v-model="filters.status" class="form-select form-select-sm np-act-filter" @change="loadActivities">
                <option value="">All statuses</option>
                <option v-for="status in statuses" :key="status" :value="status">{{ titleize(status) }}</option>
              </select>
            </div>
          </div>
          <div class="card-body">
            <AdminDataTable
              :columns="activityColumns"
              :rows="activities"
              :loading="loading"
              empty-title="No activities"
              empty-message="Create a lucky board or cashback campaign for this partner."
              sortable
              embedded
              :sort-key="sort.key"
              :sort-direction="sort.direction"
              @sort-change="handleSort"
            >
              <template #cell-name="{ row }">
                <button class="btn btn-link p-0 fw-semibold text-start" type="button" @click="selectActivity(row)">
                  {{ row.name }}
                </button>
                <div class="text-muted fs-12">{{ row.slug }}</div>
              </template>
              <template #cell-type="{ row }">
                <span class="badge" :class="row.type === 'cashback' ? 'bg-success-transparent text-success' : 'bg-primary-transparent text-primary'">
                  {{ row.type === 'cashback' ? 'Cashback' : 'Lucky board' }}
                </span>
              </template>
              <template #cell-game="{ row }">
                <div class="fw-semibold">{{ row.game?.name || row.game_id }}</div>
                <div class="text-muted fs-12">{{ row.game?.status || '-' }}</div>
              </template>
              <template #cell-config_summary="{ row }">
                <div>{{ configSummary(row) }}</div>
                <div v-if="row.type === 'lucky_board'" class="text-muted fs-12">{{ rightsSummary(row) }}</div>
              </template>
              <template #rowActions="{ row }">
                <div class="d-flex flex-wrap gap-2">
                  <button class="btn btn-sm btn-primary-light btn-wave" type="button" @click="selectActivity(row)">
                    View
                  </button>
                  <button class="btn btn-sm btn-light btn-wave" type="button" @click="openEditModal(row)">
                    Edit
                  </button>
                </div>
              </template>
            </AdminDataTable>
            <AdminPagination
              class="mt-3"
              :next-cursor="meta.next_cursor"
              :has-previous="pageState.index > 0"
              :loading="loading"
              @previous="loadPreviousPage"
              @next="loadNextPage"
            />
          </div>
        </div>
      </div>

      <div v-if="selectedActivity" class="col-12">
        <div class="card custom-card">
          <div class="card-header align-items-start gap-3">
            <div class="np-act-selected">
              <img v-if="selectedActivity.image_thumb_url" :src="selectedActivity.image_thumb_url" alt="Activity thumbnail">
              <div>
                <div class="card-title mb-1">{{ selectedActivity.name }}</div>
                <div class="text-muted fs-12">{{ selectedActivity.game?.name || selectedActivity.game_id }} · {{ titleize(selectedActivity.status) }}</div>
              </div>
            </div>
            <div class="ms-auto d-flex flex-wrap gap-2">
              <button class="btn btn-sm btn-light btn-wave" type="button" @click="openEditModal(selectedActivity)">
                Edit activity
              </button>
              <button class="btn btn-sm btn-primary btn-wave" type="button" @click="loadActivityDetails">
                Refresh detail
              </button>
            </div>
          </div>
          <div class="card-body">
            <ul class="nav nav-tabs mb-3">
              <li class="nav-item">
                <button class="nav-link" :class="{ active: detailTab === 'entries' }" type="button" @click="setDetailTab('entries')">Entries</button>
              </li>
              <li class="nav-item">
                <button class="nav-link" :class="{ active: detailTab === 'awards' }" type="button" @click="setDetailTab('awards')">Awards</button>
              </li>
              <li class="nav-item">
                <button class="nav-link" :class="{ active: detailTab === 'claims' }" type="button" @click="setDetailTab('claims')">Claims</button>
              </li>
            </ul>

            <AdminDataTable
              v-if="detailTab === 'entries'"
              :columns="entryColumns"
              :rows="entries"
              :loading="detailLoading"
              empty-title="No entries"
              empty-message="Customer lucky board entries will appear here."
              embedded
            >
              <template #cell-customer="{ row }">
                <div class="fw-semibold">{{ row.customer?.name || row.customer_id }}</div>
                <div class="text-muted fs-12">{{ row.customer?.phone || '-' }}</div>
              </template>
              <template #cell-selected_number="{ row }">
                <span class="np-act-number">{{ row.selected_number }}</span>
              </template>
            </AdminDataTable>

            <AdminDataTable
              v-else-if="detailTab === 'awards'"
              :columns="awardColumns"
              :rows="awards"
              :loading="detailLoading"
              empty-title="No awards"
              empty-message="Awards are created after reward results are published."
              embedded
            >
              <template #cell-amount="{ row }">{{ formatMoney(row.amount) }}</template>
              <template #cell-source="{ row }">{{ row.type === 'cashback' ? 'Cashback' : titleize(row.prediction_type || 'Lucky board') }}</template>
            </AdminDataTable>

            <AdminDataTable
              v-else
              :columns="claimColumns"
              :rows="claims"
              :loading="detailLoading"
              empty-title="No activity claims"
              empty-message="Customer payout claims for activity awards will appear here."
              embedded
            >
              <template #cell-customer="{ row }">
                <div class="fw-semibold">{{ row.customer?.name || row.customer_id }}</div>
                <div class="text-muted fs-12">{{ row.customer?.phone || '-' }}</div>
              </template>
              <template #cell-claim_amount="{ row }">{{ formatMoney(row.claim_amount) }}</template>
              <template #rowActions="{ row }">
                <div class="d-flex flex-wrap gap-2">
                  <button v-if="isPendingClaim(row)" class="btn btn-sm btn-success-light btn-wave" type="button" :disabled="saving" @click="approveClaim(row)">
                    Approve
                  </button>
                  <button v-if="isPendingClaim(row)" class="btn btn-sm btn-danger-light btn-wave" type="button" :disabled="saving" @click="rejectClaim(row)">
                    Reject
                  </button>
                </div>
              </template>
            </AdminDataTable>
          </div>
        </div>
      </div>
    </div>

    <div v-if="formModalOpen" class="modal fade show np-act-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-xl modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">{{ form.id ? 'Edit activity' : 'Create activity' }}</h5>
              <div class="text-muted fs-12">Configure lucky board or cashback campaign for one draw.</div>
            </div>
            <button class="btn-close" type="button" aria-label="Close" :disabled="saving" @click="closeFormModal" />
          </div>
          <div class="modal-body">
            <form class="row g-3" @submit.prevent="saveActivity">
              <div class="col-12">
                <div class="d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <label class="form-label mb-0">Localized content</label>
                  <div class="btn-group btn-group-sm" role="group" aria-label="Activity language tabs">
                    <button
                      v-for="option in localeOptions"
                      :key="option.value"
                      class="btn"
                      :class="contentLocale === option.value ? 'btn-primary' : 'btn-outline-primary'"
                      type="button"
                      @click="contentLocale = option.value"
                    >
                      {{ option.label }}
                    </button>
                  </div>
                </div>
                <div class="form-text">Customer activity pages use the selected language and fall back to Thai/default if blank.</div>
              </div>
              <div class="col-12 col-lg-7">
                <label class="form-label">Activity name ({{ localeLabel(contentLocale) }})</label>
                <input v-model="form.name_i18n[contentLocale]" class="form-control" :class="invalidClass('name')" placeholder="Customer-facing campaign name">
                <div class="invalid-feedback">{{ fieldError('name') }}</div>
              </div>
              <div class="col-12 col-lg-5">
                <label class="form-label">Activity code</label>
                <input :value="form.slug || 'Generated after save'" class="form-control" disabled>
                <div class="form-text">Generated automatically from partner code.</div>
              </div>
              <div class="col-md-4">
                <label class="form-label">Game</label>
                <select v-model="form.game_id" class="form-select" :class="invalidClass('game_id')">
                  <option value="">Select game</option>
                  <option v-for="game in games" :key="game.id" :value="game.id">{{ gameLabel(game) }}</option>
                </select>
                <div class="invalid-feedback">{{ fieldError('game_id') }}</div>
              </div>
              <div class="col-md-4">
                <label class="form-label">Activity type</label>
                <select v-model="form.type" class="form-select" :class="invalidClass('type')">
                  <option value="lucky_board">Lucky board</option>
                  <option value="cashback">Cashback</option>
                </select>
                <div class="invalid-feedback">{{ fieldError('type') }}</div>
              </div>
              <div class="col-md-2">
                <label class="form-label">Status</label>
                <select v-model="form.status" class="form-select" :class="invalidClass('status')">
                  <option v-for="status in statuses" :key="status" :value="status">{{ titleize(status) }}</option>
                </select>
                <div class="invalid-feedback">{{ fieldError('status') }}</div>
              </div>
              <div class="col-md-2">
                <label class="form-label">Sort order</label>
                <input v-model.number="form.sort_order" type="number" class="form-control" :class="invalidClass('sort_order')">
                <div class="invalid-feedback">{{ fieldError('sort_order') }}</div>
              </div>

              <template v-if="form.type === 'lucky_board'">
                <div class="col-12">
                  <div class="np-act-config-title">Lucky board settings</div>
                </div>
                <div class="col-md-6">
                  <label class="form-label">Eligibility rule</label>
                  <select v-model="form.config.eligibility_rule" class="form-select" :class="invalidClass('config.eligibility_rule')">
                    <option value="cumulative_tickets">Every N cumulative tickets gives 1 right</option>
                    <option value="single_order_exact_tickets">Every N tickets in one order gives 1 right</option>
                  </select>
                  <div class="invalid-feedback">{{ fieldError('config.eligibility_rule') }}</div>
                </div>
                <div class="col-md-6">
                  <label class="form-label">Threshold tickets</label>
                  <input v-model.number="form.config.threshold_tickets" type="number" min="1" class="form-control" :class="invalidClass('config.threshold_tickets')">
                  <div class="invalid-feedback">{{ fieldError('config.threshold_tickets') }}</div>
                </div>
                <div class="col-md-6">
                  <label class="form-label">Prediction type</label>
                  <select v-model="form.config.prediction_type" class="form-select" :class="invalidClass('config.prediction_type')">
                    <option v-for="option in predictionTypeOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
                  </select>
                  <div class="invalid-feedback">{{ fieldError('config.prediction_type') }}</div>
                </div>
                <div v-if="form.config.prediction_type === 'first_prize_last2'" class="col-md-6">
                  <label class="form-label">First prize last 2 payout (baht)</label>
                  <input v-model.number="form.config.first_prize_last2_baht" type="number" min="0" step="0.01" class="form-control">
                </div>
                <div v-else-if="form.config.prediction_type === 'first_prize_last3'" class="col-md-6">
                  <label class="form-label">First prize last 3 payout (baht)</label>
                  <input v-model.number="form.config.first_prize_last3_baht" type="number" min="0" step="0.01" class="form-control">
                </div>
                <div v-else class="col-md-6">
                  <label class="form-label">Last 2 payout (baht)</label>
                  <input v-model.number="form.config.last2_baht" type="number" min="0" step="0.01" class="form-control">
                </div>
              </template>

              <template v-else>
                <div class="col-12">
                  <div class="np-act-config-title">Cashback settings</div>
                </div>
                <div class="col-md-4">
                  <label class="form-label">Cashback type</label>
                  <select v-model="form.config.cashback_type" class="form-select" :class="invalidClass('config.cashback_type')">
                    <option value="percent">Percent of purchase amount</option>
                    <option value="fixed">Fixed amount</option>
                  </select>
                  <div class="invalid-feedback">{{ fieldError('config.cashback_type') }}</div>
                </div>
                <div v-if="form.config.cashback_type === 'percent'" class="col-md-4">
                  <label class="form-label">Cashback percent</label>
                  <input v-model.number="form.config.cashback_percent" type="number" min="0.01" max="100" step="0.01" class="form-control">
                </div>
                <div v-else class="col-md-4">
                  <label class="form-label">Fixed cashback (baht)</label>
                  <input v-model.number="form.config.fixed_baht" type="number" min="0" step="0.01" class="form-control">
                </div>
                <div class="col-md-4">
                  <label class="form-label">Minimum by</label>
                  <select v-model="form.config.minimum_type" class="form-select" :class="invalidClass('config.minimum_type')">
                    <option value="tickets">Tickets</option>
                    <option value="amount">Purchase amount</option>
                  </select>
                  <div class="invalid-feedback">{{ fieldError('config.minimum_type') }}</div>
                </div>
                <div v-if="form.config.minimum_type === 'tickets'" class="col-md-4">
                  <label class="form-label">Minimum tickets</label>
                  <input v-model.number="form.config.min_ticket_count" type="number" min="0" class="form-control">
                </div>
                <div v-else class="col-md-4">
                  <label class="form-label">Minimum purchase (baht)</label>
                  <input v-model.number="form.config.min_purchase_baht" type="number" min="0" step="0.01" class="form-control">
                </div>
              </template>

              <div class="col-12">
                <label class="form-label">Activity image</label>
                <input class="form-control" type="file" accept="image/*" :class="invalidClass('file')" @change="handleImageChange">
                <div class="invalid-feedback">{{ fieldError('file') || imageError }}</div>
                <div class="form-text">The API stores full and thumbnail variants for customer pages.</div>
              </div>
              <div v-if="previewUrl || form.image_thumb_url" class="col-12">
                <div class="np-act-preview">
                  <img :src="previewUrl || form.image_thumb_url" alt="Activity preview">
                </div>
              </div>
              <button class="d-none" type="submit" aria-hidden="true" tabindex="-1" />
            </form>
          </div>
          <div class="modal-footer justify-content-between">
            <button v-if="form.id" class="btn btn-danger-light btn-wave" type="button" :disabled="saving" @click="archiveActivity">
              <i class="ri-archive-line me-1" />
              Archive
            </button>
            <span v-else />
            <div class="d-flex gap-2">
              <button class="btn btn-light btn-wave" type="button" :disabled="saving" @click="resetForm">Reset</button>
              <button class="btn btn-primary btn-wave" type="button" :disabled="saveDisabled" @click="saveActivity">
                <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                Save activity
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div v-if="formModalOpen" class="modal-backdrop fade show np-act-modal-backdrop" />
  </div>
</template>

<script setup lang="ts">
definePageMeta({
  layout: 'admin',
})

type AnyRecord = Record<string, any>

const api = useAdminApi()
const session = useAdminSession()
const tenantId = computed(() => session.currentTenantId.value)
const statuses = ['draft', 'active', 'inactive', 'archived']
const localeOptions = [
  { value: 'th-TH', label: 'TH' },
  { value: 'en-US', label: 'EN' },
] as const
const predictionTypeOptions = [
  { value: 'first_prize_last2', label: 'First prize last 2 digits' },
  { value: 'first_prize_last3', label: 'First prize last 3 digits' },
  { value: 'last2', label: 'Last 2 digits' },
]
const activityColumns = [
  { key: 'name', label: 'Activity' },
  { key: 'type', label: 'Type' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'game', label: 'Game' },
  { key: 'config_summary', label: 'Rules' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]
const entryColumns = [
  { key: 'customer', label: 'Customer' },
  { key: 'prediction_type', label: 'Prediction' },
  { key: 'selected_number', label: 'Number' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'created_at', label: 'Submitted', type: 'datetime' },
]
const awardColumns = [
  { key: 'source', label: 'Source' },
  { key: 'amount', label: 'Amount' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'calculated_at', label: 'Calculated', type: 'datetime' },
]
const claimColumns = [
  { key: 'reference', label: 'Reference' },
  { key: 'customer', label: 'Customer' },
  { key: 'claim_amount', label: 'Amount' },
  { key: 'payout_method', label: 'Method' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'submitted_at', label: 'Submitted', type: 'datetime' },
]

const loading = ref(false)
const detailLoading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const activities = ref<AnyRecord[]>([])
const games = ref<AnyRecord[]>([])
const meta = ref<AnyRecord>({})
const pageState = ref({ index: 0, cursors: [''] })
const sort = reactive({ key: 'created_at', direction: 'desc' as 'asc' | 'desc' })
const filters = reactive({ q: '', status: '', type: '' })
const formModalOpen = ref(false)
const contentLocale = ref<'th-TH' | 'en-US'>('th-TH')
const fieldErrors = ref<Record<string, string[]>>({})
const selectedImage = ref<File | null>(null)
const previewUrl = ref('')
const imageError = ref('')
const form = reactive<AnyRecord>(defaultForm())
const selectedActivity = ref<AnyRecord | null>(null)
const detailTab = ref<'entries' | 'awards' | 'claims'>('entries')
const entries = ref<AnyRecord[]>([])
const awards = ref<AnyRecord[]>([])
const claims = ref<AnyRecord[]>([])

const saveDisabled = computed(() => (
  saving.value
  || !tenantId.value
  || !firstLocalizedValue(form.name_i18n, form.name)
  || !String(form.game_id || '').trim()
  || Boolean(imageError.value)
))

function defaultForm() {
  return {
    id: '',
    name: '',
    name_i18n: localizedDefaults(),
    slug: '',
    game_id: '',
    type: 'lucky_board',
    status: 'draft',
    sort_order: 0,
    image_full_url: '',
    image_thumb_url: '',
    config: {
      prediction_type: 'first_prize_last2',
      eligibility_rule: 'cumulative_tickets',
      threshold_tickets: 1,
      first_prize_last2_baht: 0,
      first_prize_last3_baht: 0,
      last2_baht: 0,
      cashback_type: 'percent',
      cashback_percent: 5,
      fixed_baht: 0,
      minimum_type: 'tickets',
      min_ticket_count: 0,
      min_purchase_baht: 0,
    },
  }
}

const loadGames = async () => {
  if (!tenantId.value) return
  const response: any = await api.apiFetch('/admin/tenant/stock/games', {
    scope: 'tenant',
    tenantId: tenantId.value,
  })
  games.value = Array.isArray(response.data) ? response.data : []
  if (!form.game_id && response.meta?.default_game_id) {
    form.game_id = response.meta.default_game_id
  }
}

const loadActivities = async (cursor = '') => {
  if (!tenantId.value) return
  loading.value = true
  error.value = null

  try {
    const response: any = await api.apiFetch('/admin/tenant/activities', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: {
        limit: 25,
        cursor: cursor || undefined,
        q: filters.q || undefined,
        status: filters.status || undefined,
        type: filters.type || undefined,
        sort: sort.key,
        direction: sort.direction,
      },
    })
    activities.value = Array.isArray(response.data) ? response.data : []
    meta.value = response.meta || {}
    if (selectedActivity.value) {
      selectedActivity.value = activities.value.find((row) => row.id === selectedActivity.value?.id) || selectedActivity.value
    }
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const loadAll = async () => {
  await Promise.all([loadGames(), loadActivities(pageState.value.cursors[pageState.value.index] || '')])
  if (selectedActivity.value) {
    await loadActivityDetails()
  }
}

const loadNextPage = () => {
  const cursor = String(meta.value.next_cursor || '')
  if (!cursor) return
  pageState.value.cursors[pageState.value.index + 1] = cursor
  pageState.value.index += 1
  void loadActivities(cursor)
}

const loadPreviousPage = () => {
  if (pageState.value.index <= 0) return
  pageState.value.index -= 1
  void loadActivities(pageState.value.cursors[pageState.value.index] || '')
}

const handleSort = (next: { key: string, direction: 'asc' | 'desc' }) => {
  const keyMap: Record<string, string> = {
    name: 'name',
    type: 'type',
    status: 'status',
    updated_at: 'updated_at',
  }
  sort.key = keyMap[next.key] || 'created_at'
  sort.direction = next.direction
  pageState.value = { index: 0, cursors: [''] }
  void loadActivities()
}

const selectActivity = async (row: AnyRecord) => {
  selectedActivity.value = row
  detailTab.value = row.type === 'cashback' ? 'awards' : 'entries'
  await loadActivityDetails()
}

const loadActivityDetails = async () => {
  if (!tenantId.value || !selectedActivity.value) return
  detailLoading.value = true
  error.value = null

  try {
    if (detailTab.value === 'entries') {
      const response: any = await api.apiFetch(`/admin/tenant/activities/${encodeURIComponent(selectedActivity.value.id)}/entries`, {
        scope: 'tenant',
        tenantId: tenantId.value,
        query: { limit: 100 },
      })
      entries.value = Array.isArray(response.data) ? response.data : []
    } else if (detailTab.value === 'awards') {
      const response: any = await api.apiFetch(`/admin/tenant/activities/${encodeURIComponent(selectedActivity.value.id)}/awards`, {
        scope: 'tenant',
        tenantId: tenantId.value,
        query: { limit: 100 },
      })
      awards.value = Array.isArray(response.data) ? response.data : []
    } else {
      const response: any = await api.apiFetch('/admin/tenant/activity-claims', {
        scope: 'tenant',
        tenantId: tenantId.value,
        query: { limit: 100, activity_id: selectedActivity.value.id },
      })
      claims.value = Array.isArray(response.data) ? response.data : []
    }
  } catch (err) {
    error.value = err
  } finally {
    detailLoading.value = false
  }
}

const setDetailTab = (tab: 'entries' | 'awards' | 'claims') => {
  detailTab.value = tab
  void loadActivityDetails()
}

const openCreateModal = async () => {
  resetForm()
  await loadGames()
  formModalOpen.value = true
}

const openEditModal = (row: AnyRecord) => {
  clearPreview()
  Object.assign(form, defaultForm(), {
    id: row.id,
    name: row.name,
    name_i18n: localizedFrom(row.name_i18n, row.name),
    slug: row.slug,
    game_id: row.game_id,
    type: row.type,
    status: row.status,
    sort_order: row.sort_order,
    image_full_url: row.image_full_url,
    image_thumb_url: row.image_thumb_url,
  })
  applyConfigToForm(row)
  fieldErrors.value = {}
  formModalOpen.value = true
}

const closeFormModal = () => {
  if (saving.value) return
  formModalOpen.value = false
  resetForm()
}

const resetForm = () => {
  clearPreview()
  Object.assign(form, defaultForm())
  if (games.value.length > 0) {
    const defaultGame = games.value.find((game) => game.is_default) || games.value[0]
    form.game_id = defaultGame?.id || ''
  }
  fieldErrors.value = {}
  error.value = null
}

const saveActivity = async () => {
  if (saveDisabled.value || !tenantId.value) return
  saving.value = true
  error.value = null
  fieldErrors.value = {}
  successMessage.value = ''

  try {
    const payload = buildPayload()
    const saved: any = form.id
      ? await api.apiFetch(`/admin/tenant/activities/${encodeURIComponent(form.id)}`, {
        method: 'PATCH',
        scope: 'tenant',
        tenantId: tenantId.value,
        idempotencyKey: api.idempotencyKey(),
        body: payload,
      })
      : await api.apiFetch('/admin/tenant/activities', {
        method: 'POST',
        scope: 'tenant',
        tenantId: tenantId.value,
        idempotencyKey: api.idempotencyKey(),
        body: payload,
      })

    if (selectedImage.value) {
      await uploadImage(saved.id)
    }

    successMessage.value = 'Activity saved.'
    formModalOpen.value = false
    resetForm()
    await loadActivities(pageState.value.cursors[pageState.value.index] || '')
    selectedActivity.value = activities.value.find((row) => row.id === saved.id) || saved
    await loadActivityDetails()
  } catch (err: any) {
    error.value = err
    fieldErrors.value = normalizeFieldErrors(err)
  } finally {
    saving.value = false
  }
}

const archiveActivity = async () => {
  if (!tenantId.value || !form.id || saving.value) return
  saving.value = true
  error.value = null

  try {
    await api.apiFetch(`/admin/tenant/activities/${encodeURIComponent(form.id)}`, {
      method: 'DELETE',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      body: { reason: 'Archived from activity manager' },
    })
    successMessage.value = 'Activity archived.'
    formModalOpen.value = false
    resetForm()
    await loadActivities()
  } catch (err) {
    error.value = err
  } finally {
    saving.value = false
  }
}

const uploadImage = async (activityId: string) => {
  if (!tenantId.value || !selectedImage.value) return
  const body = new FormData()
  body.append('file', selectedImage.value)
  await api.apiFetch(`/admin/tenant/activities/${encodeURIComponent(activityId)}/image`, {
    method: 'POST',
    scope: 'tenant',
    tenantId: tenantId.value,
    successMessage: false,
    body,
  })
}

const approveClaim = async (row: AnyRecord) => claimAction(row, 'approve')
const rejectClaim = async (row: AnyRecord) => claimAction(row, 'reject')

const claimAction = async (row: AnyRecord, action: 'approve' | 'reject') => {
  if (!tenantId.value || saving.value) return
  saving.value = true
  error.value = null

  try {
    await api.apiFetch(`/admin/tenant/activity-claims/${encodeURIComponent(row.id)}/${action}`, {
      method: 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      body: { reason: `${titleize(action)} from activity manager` },
    })
    successMessage.value = action === 'approve' ? 'Activity claim approved.' : 'Activity claim rejected.'
    await loadActivityDetails()
  } catch (err) {
    error.value = err
  } finally {
    saving.value = false
  }
}

const buildPayload = () => {
  const config = form.type === 'cashback'
    ? {
        cashback_type: form.config.cashback_type,
        cashback_percent_bps: Math.round(Number(form.config.cashback_percent || 0) * 100),
        fixed_amount: bahtToMinor(form.config.fixed_baht),
        minimum_type: form.config.minimum_type === 'amount' ? 'amount' : 'tickets',
        min_ticket_count: form.config.minimum_type === 'tickets' ? Number(form.config.min_ticket_count || 0) : 0,
        min_purchase_amount: form.config.minimum_type === 'amount' ? bahtToMinor(form.config.min_purchase_baht) : 0,
      }
    : {
        prediction_type: selectedPredictionType(form.config),
        first_prize_last2_enabled: selectedPredictionType(form.config) === 'first_prize_last2',
        first_prize_last3_enabled: selectedPredictionType(form.config) === 'first_prize_last3',
        last2_enabled: selectedPredictionType(form.config) === 'last2',
        eligibility_rule: form.config.eligibility_rule,
        threshold_tickets: Number(form.config.threshold_tickets || 1),
        first_prize_last2_amount: bahtToMinor(form.config.first_prize_last2_baht),
        first_prize_last3_amount: bahtToMinor(form.config.first_prize_last3_baht),
        last2_amount: bahtToMinor(form.config.last2_baht),
      }

  return {
    name: firstLocalizedValue(form.name_i18n, form.name),
    name_i18n: normalizedLocalized(form.name_i18n),
    game_id: form.game_id,
    type: form.type,
    status: form.status,
    sort_order: Number.isFinite(Number(form.sort_order)) ? Number(form.sort_order) : 0,
    config,
  }
}

const applyConfigToForm = (row: AnyRecord) => {
  const config = row.config || {}
  if (row.type === 'cashback') {
    form.config.cashback_type = config.cashback_type || 'percent'
    form.config.cashback_percent = Number(config.cashback_percent_bps || 0) / 100
    form.config.fixed_baht = minorToBaht(config.fixed_amount)
    form.config.minimum_type = selectedMinimumType(config)
    form.config.min_ticket_count = form.config.minimum_type === 'tickets' ? Number(config.min_ticket_count || 0) : 0
    form.config.min_purchase_baht = form.config.minimum_type === 'amount' ? minorToBaht(config.min_purchase_amount) : 0
  } else {
    const predictions = config.prediction_types || {}
    const prizes = config.prizes || {}
    form.config.prediction_type = selectedPredictionType(config.prediction_type ? config : predictions)
    form.config.eligibility_rule = config.eligibility_rule || 'cumulative_tickets'
    form.config.threshold_tickets = Number(config.threshold_tickets || 1)
    form.config.first_prize_last2_baht = minorToBaht(prizes.first_prize_last2)
    form.config.first_prize_last3_baht = minorToBaht(prizes.first_prize_last3)
    form.config.last2_baht = minorToBaht(prizes.last2)
  }
}

const handleImageChange = (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] || null
  clearPreview()
  imageError.value = ''

  if (!file) return

  if (!file.type.startsWith('image/')) {
    imageError.value = 'Only image files are accepted.'
    return
  }

  if (file.size < 1 || file.size > 8 * 1024 * 1024) {
    imageError.value = 'Image size must be between 1 byte and 8 MB.'
    return
  }

  selectedImage.value = file
  previewUrl.value = URL.createObjectURL(file)
}

const clearPreview = () => {
  if (previewUrl.value) {
    URL.revokeObjectURL(previewUrl.value)
  }
  previewUrl.value = ''
  selectedImage.value = null
  imageError.value = ''
}

const configSummary = (row: AnyRecord) => {
  const config = row.config || {}
  if (row.type === 'cashback') {
    return config.cashback_type === 'fixed'
      ? `Cashback ${formatMoney(config.fixed_amount)}`
      : `Cashback ${Number(config.cashback_percent_bps || 0) / 100}%`
  }

  const prizes = config.prizes || {}
  const predictionType = selectedPredictionType(config.prediction_type ? config : (config.prediction_types || {}))
  const prize = predictionType === 'first_prize_last3'
    ? prizes.first_prize_last3
    : predictionType === 'last2'
      ? prizes.last2
      : prizes.first_prize_last2
  return `${predictionLabel(predictionType)}: ${formatMoney(prize)}`
}

const rightsSummary = (row: AnyRecord) => {
  const config = row.config || {}
  const rule = config.eligibility_rule === 'single_order_exact_tickets' ? 'Per order' : 'Cumulative'
  return `${rule}: every ${Number(config.threshold_tickets || 1)} tickets = 1 right`
}

const gameLabel = (game: AnyRecord) => `${game.name || game.code || game.id}${game.status ? ` (${game.status})` : ''}`
const isPendingClaim = (row: AnyRecord) => ['submitted', 'under_review', 'approved'].includes(String(row.status || ''))
const fieldError = (field: string) => (fieldErrors.value[field] || [])[0] || ''
const invalidClass = (field: string) => (fieldError(field) || (field === 'file' && imageError.value) ? 'is-invalid' : '')
const selectedPredictionType = (config: AnyRecord) => {
  const direct = String(config?.prediction_type || '')
  if (predictionTypeOptions.some((option) => option.value === direct)) return direct
  const mapped = predictionTypeOptions.find((option) => config?.[option.value] === true)
  if (mapped) return mapped.value
  const enabled = predictionTypeOptions.find((option) => config?.[`${option.value}_enabled`] === true)
  return enabled?.value || 'first_prize_last2'
}
const selectedMinimumType = (config: AnyRecord) => {
  const direct = String(config?.minimum_type || '')
  if (direct === 'amount' || direct === 'tickets') return direct
  return minorToBaht(config?.min_purchase_amount) > 0 && Number(config?.min_ticket_count || 0) < 1 ? 'amount' : 'tickets'
}
const predictionLabel = (value: string) => predictionTypeOptions.find((option) => option.value === value)?.label || titleize(value)
const normalizeFieldErrors = (err: any) => {
  const details = err?.details?.fields || err?.details || {}
  return Object.fromEntries(Object.entries(details).map(([key, value]) => [key, Array.isArray(value) ? value : [String(value)]]))
}
const minorToBaht = (value: any) => {
  const amount = value && typeof value === 'object' && 'amount' in value ? Number(value.amount) : Number(value || 0)
  return Number.isFinite(amount) ? amount / 100 : 0
}
const bahtToMinor = (value: any) => Math.max(0, Math.round(Number(value || 0) * 100))
const formatMoney = (value: any) => `${minorToBaht(value).toLocaleString('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} บาท`
const titleize = (value: string) => String(value || '-').replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase())
const alertType = (err: any) => ([403, 409, 422].includes(Number(err?.status)) ? 'warning' : 'danger')
const localeLabel = (value: 'th-TH' | 'en-US') => localeOptions.find((option) => option.value === value)?.label || value
function localizedDefaults() {
  return { 'th-TH': '', 'en-US': '' }
}
const localizedFrom = (value: any, fallback = '') => {
  const next = localizedDefaults()
  if (value && typeof value === 'object') {
    next['th-TH'] = String(value['th-TH'] || value.th || '')
    next['en-US'] = String(value['en-US'] || value.en || '')
  }
  if (!next['th-TH'] && fallback) {
    next['th-TH'] = String(fallback)
  }
  return next
}
const firstLocalizedValue = (value: any, fallback = '') => String(
  value?.['th-TH']
  || value?.['en-US']
  || fallback
  || '',
).trim()
const normalizedLocalized = (value: any) => ({
  'th-TH': String(value?.['th-TH'] || '').trim(),
  'en-US': String(value?.['en-US'] || '').trim(),
})

watch(tenantId, () => {
  resetForm()
  formModalOpen.value = false
  selectedActivity.value = null
  pageState.value = { index: 0, cursors: [''] }
  void loadAll()
}, { immediate: true })

onBeforeUnmount(() => {
  clearPreview()
})
</script>

<style scoped>
.np-act-search {
  min-width: 220px;
}

.np-act-filter {
  min-width: 150px;
}

.np-act-selected {
  align-items: center;
  display: flex;
  gap: .85rem;
}

.np-act-selected img {
  border-radius: .65rem;
  height: 58px;
  object-fit: cover;
  width: 82px;
}

.np-act-number {
  background: #f1f5ff;
  border-radius: .5rem;
  color: #0d6efd;
  display: inline-flex;
  font-size: 1.05rem;
  font-weight: 800;
  letter-spacing: .08em;
  padding: .25rem .55rem;
}

.np-act-config-title {
  border-bottom: 1px solid #edf1f7;
  color: #1f2937;
  font-weight: 800;
  padding-bottom: .5rem;
}

.np-act-preview {
  background: #f8fafc;
  border: 1px dashed #d7dde8;
  border-radius: .65rem;
  display: grid;
  min-height: 220px;
  overflow: hidden;
  place-items: center;
}

.np-act-preview img {
  display: block;
  max-height: 360px;
  max-width: 100%;
  object-fit: contain;
}

.np-act-modal {
  display: block;
  z-index: 2000;
}

.np-act-modal-backdrop {
  z-index: 1990;
}
</style>

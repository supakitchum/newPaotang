<template>
  <div>
    <AdminPageHeader :title="pageTitle" :breadcrumbs="[adminLabel, scopeLabel, pageTitle]">
      <template #actions>
        <div class="d-flex align-items-center gap-2">
          <AdminStatusBadge :status="realtimeStatus" :label="realtimeLabel" />
          <button class="btn btn-primary btn-wave" type="button" :disabled="loading" @click="loadAll()">
            <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
            <i v-else class="ri-refresh-line me-1" />
            {{ common('refresh') }}
          </button>
        </div>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="scope === 'tenant' && !tenantId" type="warning" :message="rr('scopeMissing')" />
    <AdminApiState :error="error" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="np-risk-tabs" role="tablist" :aria-label="rr('tabsAria')">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        class="np-risk-tab"
        :class="{ active: activeTab === tab.key }"
        type="button"
        role="tab"
        :aria-selected="activeTab === tab.key"
        @click="activeTab = tab.key"
      >
        <i :class="tab.icon" />
        {{ tab.label }}
      </button>
    </div>

    <template v-if="activeTab === 'overview'">
      <div v-if="scope === 'tenant'" class="card custom-card">
        <div class="card-header">
          <div>
            <div class="card-title">{{ rr('settingsTitle') }}</div>
            <div class="text-muted fs-12">{{ rr('readOnlyDescription') }}</div>
          </div>
          <div class="form-check form-switch ms-auto">
            <input id="risk-enabled" v-model="settingsForm.enabled" class="form-check-input" type="checkbox">
            <label class="form-check-label" for="risk-enabled">{{ settingsForm.enabled ? rr('enabled') : rr('disabled') }}</label>
          </div>
        </div>
        <div class="card-body">
          <div class="row g-4">
            <div class="col-xl-9">
              <label class="form-label">{{ rr('prizeTypesToMonitor') }}</label>
              <div class="np-risk-prize-grid">
                <label v-for="prize in prizeTypes" :key="prize.key" class="np-risk-prize-option">
                  <input v-model="settingsForm.monitored_prize_types" class="form-check-input" type="checkbox" :value="prize.key">
                  <span>
                    <strong>{{ prize.label }}</strong>
                    <small>{{ prize.key }}</small>
                  </span>
                </label>
              </div>
            </div>
            <div class="col-xl-3">
              <label class="form-label" for="risk-multiplier">{{ rr('thresholdMultiplier') }}</label>
              <div class="input-group">
                <input id="risk-multiplier" v-model="settingsForm.threshold_multiplier" class="form-control" type="number" min="0.01" max="1000" step="0.01">
                <span class="input-group-text">x</span>
              </div>
              <div class="form-text">{{ rr('allowedRange') }}</div>
              <button class="btn btn-primary btn-wave w-100 mt-3" type="button" :disabled="savingSettings || !tenantId" @click="saveSettings">
                <span v-if="savingSettings" class="spinner-border spinner-border-sm me-1" />
                <i v-else class="ri-save-line me-1" />
                {{ rr('saveSettings') }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="card custom-card">
        <div class="card-body">
          <div class="row g-3 align-items-end">
            <div v-if="scope === 'central'" class="col-lg-4">
              <label class="form-label" for="risk-tenant-filter">{{ rr('tenantId') }}</label>
              <input id="risk-tenant-filter" v-model.trim="filters.tenant_id" class="form-control" :placeholder="rr('allTenants')">
            </div>
            <div class="col-lg-4">
              <label class="form-label" for="risk-game-filter">{{ rr('gameId') }}</label>
              <input id="risk-game-filter" v-model.trim="filters.game_id" class="form-control" :placeholder="rr('latestAllGames')">
            </div>
            <div :class="scope === 'central' ? 'col-lg-2' : 'col-lg-4'">
              <label class="form-label" for="risk-phase-filter">{{ rr('phase') }}</label>
              <select id="risk-phase-filter" v-model="filters.phase" class="form-select">
                <option value="">{{ rr('allPhases') }}</option>
                <option value="provisional">{{ rr('provisional') }}</option>
                <option value="final">{{ rr('final') }}</option>
              </select>
            </div>
            <div :class="scope === 'central' ? 'col-lg-2' : 'col-lg-4'">
              <button class="btn btn-outline-primary btn-wave w-100" type="button" :disabled="loading" @click="applyFilters">
                <i class="ri-filter-3-line me-1" />
                {{ rr('apply') }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <AdminLoader v-if="loading && !hasOverview" />
      <template v-else>
        <div class="row">
          <div v-for="card in summaryCards" :key="card.key" class="col-xxl-3 col-md-6">
            <AdminKpiCard :label="card.label" :value="card.value" :hint="card.hint" :icon="card.icon" :color-class="card.colorClass" />
          </div>
        </div>

        <div v-if="scope === 'tenant'" class="row">
          <div v-for="phase in tenantPhaseRows" :key="phase.key" class="col-xl-6">
            <div class="card custom-card h-100">
              <div class="card-header">
                <div>
                  <div class="card-title">{{ phase.label }}</div>
                  <div class="text-muted fs-12">{{ phase.run?.game_name || phase.run?.game_id || rr('noAssessmentYet') }}</div>
                </div>
                <AdminStatusBadge :status="phase.run?.status || 'inactive'" :label="phase.run ? statusLabel(phase.run.status) : rr('waiting')" />
              </div>
              <div class="card-body">
                <div v-if="phase.run" class="np-risk-phase-metrics">
                  <div><span>{{ rr('rewardVersion') }}</span><strong>{{ phase.run.reward_version }}</strong></div>
                  <div><span>{{ rr('groupsEvaluated') }}</span><strong>{{ number(phase.run.evaluated_group_count) }}</strong></div>
                  <div><span>{{ rr('findings') }}</span><strong>{{ number(phase.run.finding_count) }}</strong></div>
                  <div><span>{{ rr('prizeExposure') }}</span><strong>{{ money(phase.run.total_prize_amount) }}</strong></div>
                </div>
                <AdminEmptyState v-else :title="rr('noAssessment')" :message="rr('noAssessmentMessage')" />
              </div>
            </div>
          </div>
        </div>
      </template>
    </template>

    <template v-else-if="activeTab === 'findings'">
      <div class="card custom-card">
        <div class="card-body">
          <div class="row g-3 align-items-end">
            <div v-if="scope === 'central'" class="col-lg-3">
              <label class="form-label">{{ rr('tenantId') }}</label>
              <input v-model.trim="filters.tenant_id" class="form-control" :placeholder="rr('allTenants')">
            </div>
            <div class="col-lg-3">
              <label class="form-label">{{ rr('gameId') }}</label>
              <input v-model.trim="filters.game_id" class="form-control" :placeholder="rr('allGames')">
            </div>
            <div class="col-lg-3">
              <label class="form-label">{{ rr('prizeType') }}</label>
              <select v-model="filters.prize_type" class="form-select">
                <option value="">{{ rr('allPrizeTypes') }}</option>
                <option v-for="prize in prizeTypes" :key="prize.key" :value="prize.key">{{ prize.label }}</option>
              </select>
            </div>
            <div class="col-lg-3">
              <button class="btn btn-outline-primary btn-wave w-100" type="button" :disabled="loadingFindings" @click="loadFindings(false)">
                <i class="ri-search-line me-1" />
                {{ rr('filterFindings') }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <AdminDataTable
        :title="rr('thresholdFindings')"
        :columns="findingColumns"
        :rows="findings"
        :loading="loadingFindings && !findings.length"
        :empty-title="rr('noThresholdFindings')"
        :empty-message="rr('noThresholdFindingsMessage')"
      >
        <template #cell-tenant="{ row }">
          <div class="fw-semibold">{{ row.tenant_name || row.tenant_id }}</div>
          <div v-if="row.partner_name" class="text-muted fs-12">{{ row.partner_name }}</div>
        </template>
        <template #cell-customer="{ row }">
          <div class="fw-semibold">{{ row.customer?.customer_no || '-' }}</div>
          <div class="text-muted fs-12">{{ row.customer?.name || row.customer?.phone || '-' }}</div>
        </template>
        <template #cell-full_number="{ value }"><code class="np-risk-number">{{ value }}</code></template>
        <template #cell-prize_types="{ value }">
          <span v-for="type in value" :key="type" class="badge bg-primary-transparent text-primary me-1 mb-1">{{ prizeLabel(type) }}</span>
        </template>
        <template #cell-prize_amount="{ value }"><strong>{{ money(value) }}</strong></template>
        <template #cell-threshold_amount="{ value }">{{ money(value) }}</template>
        <template #cell-excess_amount="{ value }"><strong class="text-danger">{{ money(value) }}</strong></template>
        <template #cell-phase="{ value }"><AdminStatusBadge :status="value" :label="statusLabel(value)" /></template>
        <template #rowActions="{ row }">
          <button class="btn btn-sm btn-primary-light btn-wave" type="button" @click="openFinding(row.id)">
            <i class="ri-eye-line me-1" />{{ rr('details') }}
          </button>
        </template>
        <template #footer>
          <div class="d-flex justify-content-between align-items-center">
            <span class="text-muted fs-12">{{ number(findings.length) }} {{ rr('loaded') }}</span>
            <button v-if="findingMeta.has_more" class="btn btn-sm btn-outline-primary" type="button" :disabled="loadingFindings" @click="loadFindings(true)">{{ rr('loadMore') }}</button>
          </div>
        </template>
      </AdminDataTable>
    </template>

    <template v-else>
      <AdminDataTable
        :title="rr('assessmentHistory')"
        :columns="runColumns"
        :rows="runs"
        :loading="loadingRuns && !runs.length"
        :empty-title="rr('noAssessmentHistory')"
        :empty-message="rr('noAssessmentHistoryMessage')"
      >
        <template #cell-tenant="{ row }">
          <div class="fw-semibold">{{ row.tenant_name || row.tenant_id }}</div>
          <div v-if="row.partner_name" class="text-muted fs-12">{{ row.partner_name }}</div>
        </template>
        <template #cell-phase="{ value }"><AdminStatusBadge :status="value" :label="statusLabel(value)" /></template>
        <template #cell-status="{ row }">
          <AdminStatusBadge :status="row.status" :label="row.is_current ? statusLabel(row.status) : statusLabel('superseded')" />
        </template>
        <template #cell-total_purchase_amount="{ value }">{{ money(value) }}</template>
        <template #cell-total_prize_amount="{ value }">{{ money(value) }}</template>
        <template #footer>
          <div class="d-flex justify-content-between align-items-center">
            <span class="text-muted fs-12">{{ number(runs.length) }} {{ rr('loaded') }}</span>
            <button v-if="runMeta.has_more" class="btn btn-sm btn-outline-primary" type="button" :disabled="loadingRuns" @click="loadRuns(true)">{{ rr('loadMore') }}</button>
          </div>
        </template>
      </AdminDataTable>
    </template>

    <div v-if="detailOpen" class="modal fade show d-block np-risk-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">{{ rr('findingDetail') }}</h5>
              <div class="text-muted fs-12">{{ findingDetail?.id || rr('loading') }}</div>
            </div>
            <button class="btn-close" type="button" @click="closeDetail" />
          </div>
          <div class="modal-body">
            <AdminLoader v-if="loadingDetail" />
            <AdminApiState v-else-if="detailError" :error="detailError" />
            <template v-else-if="findingDetail">
              <div class="np-risk-detail-grid">
                <div><span>{{ rr('customer') }}</span><strong>{{ findingDetail.customer?.customer_no || '-' }}</strong></div>
                <div><span>{{ rr('fullNumber') }}</span><strong>{{ findingDetail.full_number }}</strong></div>
                <div><span>{{ rr('purchaseAmount') }}</span><strong>{{ money(findingDetail.purchase_amount) }}</strong></div>
                <div><span>{{ rr('prizeAmount') }}</span><strong>{{ money(findingDetail.prize_amount) }}</strong></div>
                <div><span>{{ rr('threshold') }}</span><strong>{{ money(findingDetail.threshold_amount) }} ({{ findingDetail.threshold_multiplier }}x)</strong></div>
                <div><span>{{ rr('excess') }}</span><strong class="text-danger">{{ money(findingDetail.excess_amount) }}</strong></div>
              </div>
              <div class="table-responsive mt-4">
                <table class="table table-bordered align-middle mb-0">
                  <thead><tr><th>{{ rr('ticket') }}</th><th>{{ rr('prize') }}</th><th>{{ rr('prizeNumber') }}</th><th class="text-end">{{ rr('amount') }}</th></tr></thead>
                  <tbody>
                    <tr v-for="ticket in findingDetail.tickets || []" :key="ticket.id">
                      <td><code>{{ ticket.ticket_id || '-' }}</code></td>
                      <td>{{ prizeLabel(ticket.prize_type) }}</td>
                      <td>{{ ticket.prize_number }}</td>
                      <td class="text-end fw-semibold">{{ money(ticket.amount) }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </template>
          </div>
          <div class="modal-footer"><button class="btn btn-light" type="button" @click="closeDetail">{{ rr('close') }}</button></div>
        </div>
      </div>
      <div class="modal-backdrop fade show" @click="closeDetail" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatMoney, titleize } from '~/utils/format'

type Scope = 'central' | 'tenant'

const props = defineProps<{ scope: Scope }>()
const api = useAdminApi()
const session = useAdminSession()
const adminLocale = useAdminLocale()
const rr = (key: string) => adminLocale.t(`rewardRisk.${key}`)
const common = (key: string) => adminLocale.t(`common.${key}`)
const scope = computed(() => props.scope)
const tenantId = computed(() => session.currentTenantId.value)
const adminLabel = computed(() => common('admin'))
const scopeLabel = computed(() => scope.value === 'central' ? common('central') : common('tenant'))
const pageTitle = computed(() => rr('title'))
const activeTab = ref<'overview' | 'findings' | 'history'>('overview')
const tabs = computed(() => [
  { key: 'overview', label: rr('overview'), icon: 'ri-dashboard-line' },
  { key: 'findings', label: rr('findings'), icon: 'ri-radar-line' },
  { key: 'history', label: rr('history'), icon: 'ri-history-line' },
] as const)

const prizeTypes = computed(() => [
  { key: 'first_prize', label: rr('prizes.first_prize') },
  { key: 'near_first_prize', label: rr('prizes.near_first_prize') },
  { key: 'second_prize', label: rr('prizes.second_prize') },
  { key: 'third_prize', label: rr('prizes.third_prize') },
  { key: 'fourth_prize', label: rr('prizes.fourth_prize') },
  { key: 'fifth_prize', label: rr('prizes.fifth_prize') },
  { key: 'front3', label: rr('prizes.front3') },
  { key: 'back3', label: rr('prizes.back3') },
  { key: 'back2', label: rr('prizes.back2') },
])

const settingsForm = reactive({ enabled: false, monitored_prize_types: [] as string[], threshold_multiplier: '1.00' })
const overview = ref<any>(null)
const findings = ref<any[]>([])
const runs = ref<any[]>([])
const findingMeta = reactive({ next_cursor: '', has_more: false })
const runMeta = reactive({ next_cursor: '', has_more: false })
const filters = reactive({ tenant_id: '', game_id: '', phase: '', prize_type: '' })
const loading = ref(false)
const loadingFindings = ref(false)
const loadingRuns = ref(false)
const savingSettings = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const detailOpen = ref(false)
const findingDetail = ref<any>(null)
const loadingDetail = ref(false)
const detailError = ref<any>(null)
let refreshTimer: ReturnType<typeof setTimeout> | null = null
let pollTimer: ReturnType<typeof setInterval> | null = null

const basePath = computed(() => `/admin/${scope.value}/reward-risk`)
const apiOptions = computed(() => ({ scope: scope.value, tenantId: scope.value === 'tenant' ? tenantId.value : undefined, successMessage: false as const }))
const query = (extra: Record<string, any> = {}) => Object.fromEntries(Object.entries({
  tenant_id: scope.value === 'central' ? filters.tenant_id : undefined,
  game_id: filters.game_id,
  phase: filters.phase,
  ...extra,
}).filter(([, value]) => value !== undefined && value !== ''))

const realtimeChannel = computed(() => scope.value === 'central'
  ? 'private-admin.central.reward-risk'
  : (tenantId.value ? `private-admin.tenant.${tenantId.value}.reward-risk` : ''))
const realtime = useAdminRealtimeSubscription({
  channelName: realtimeChannel,
  eventName: 'reward.risk.updated',
  enabled: computed(() => Boolean(realtimeChannel.value)),
  onEvent: () => scheduleRefresh(),
  onReconnect: () => scheduleRefresh(),
})
const realtimeStatus = computed(() => realtime.status.value === 'connected' ? 'active' : (realtime.status.value === 'error' ? 'failed' : 'pending'))
const realtimeLabel = computed(() => realtime.status.value === 'connected' ? rr('realtime') : rr('polling'))
const hasOverview = computed(() => overview.value !== null)

const tenantPhaseRows = computed(() => [
  { key: 'provisional', label: rr('liveProvisionalAssessment'), run: overview.value?.provisional || null },
  { key: 'final', label: rr('publishedFinalAssessment'), run: overview.value?.final || null },
])

const summaryCards = computed(() => {
  if (scope.value === 'central') {
    return [
      { key: 'tenants', label: rr('enabledTenants'), value: number(overview.value?.enabled_tenant_count || 0), hint: rr('tenantSettingsEnabled'), icon: 'ri-building-4-line', colorClass: 'bg-primary-transparent text-primary' },
      { key: 'runs', label: rr('currentRuns'), value: number(overview.value?.run_count || 0), hint: filters.phase ? statusLabel(filters.phase) : rr('allPhases'), icon: 'ri-pulse-line', colorClass: 'bg-info-transparent text-info' },
      { key: 'findings', label: rr('findings'), value: number(overview.value?.finding_count || 0), hint: rr('thresholdExceeded'), icon: 'ri-radar-line', colorClass: 'bg-warning-transparent text-warning' },
      { key: 'exposure', label: rr('prizeExposure'), value: money(overview.value?.total_prize_amount || 0), hint: rr('currentMatchingRewardAmount'), icon: 'ri-money-dollar-circle-line', colorClass: 'bg-danger-transparent text-danger' },
    ]
  }
  const selected = filters.phase ? overview.value?.[filters.phase] : (overview.value?.final || overview.value?.provisional)
  return [
    { key: 'status', label: rr('assessmentStatus'), value: selected ? statusLabel(selected.status) : rr('waiting'), hint: selected ? statusLabel(selected.phase) : rr('noRunYet'), icon: 'ri-pulse-line', colorClass: 'bg-primary-transparent text-primary' },
    { key: 'groups', label: rr('groupsEvaluated'), value: number(selected?.evaluated_group_count || 0), hint: rr('customerFullNumberGroups'), icon: 'ri-group-line', colorClass: 'bg-info-transparent text-info' },
    { key: 'findings', label: rr('findings'), value: number(selected?.finding_count || 0), hint: rr('thresholdExceeded'), icon: 'ri-radar-line', colorClass: 'bg-warning-transparent text-warning' },
    { key: 'exposure', label: rr('prizeExposure'), value: money(selected?.total_prize_amount || 0), hint: rr('selectedPrizeTypes'), icon: 'ri-money-dollar-circle-line', colorClass: 'bg-danger-transparent text-danger' },
  ]
})

const findingColumns = computed(() => [
  ...(scope.value === 'central' ? [{ key: 'tenant', label: rr('tenant') }] : []),
  { key: 'customer', label: rr('customer') },
  { key: 'full_number', label: rr('fullNumber') },
  { key: 'prize_types', label: rr('prizeTypes') },
  { key: 'ticket_count', label: rr('tickets'), type: 'number' },
  { key: 'prize_amount', label: rr('prizeAmount') },
  { key: 'threshold_amount', label: rr('threshold') },
  { key: 'excess_amount', label: rr('excess') },
  { key: 'phase', label: rr('phase') },
])
const runColumns = computed(() => [
  ...(scope.value === 'central' ? [{ key: 'tenant', label: rr('tenant') }] : []),
  { key: 'game_name', label: rr('game') },
  { key: 'phase', label: rr('phase') },
  { key: 'reward_version', label: rr('version'), type: 'number' },
  { key: 'evaluated_group_count', label: rr('groups'), type: 'number' },
  { key: 'finding_count', label: rr('findings'), type: 'number' },
  { key: 'total_purchase_amount', label: rr('purchases') },
  { key: 'total_prize_amount', label: rr('prizeExposure') },
  { key: 'status', label: rr('status') },
  { key: 'created_at', label: rr('created'), type: 'datetime' },
])

function number(value: any) {
  return new Intl.NumberFormat(adminLocale.locale.value).format(Number(value || 0))
}

function money(value: any) {
  return formatMoney({ amount: Number(value || 0), currency: 'THB' })
}

function prizeLabel(type: string) {
  return prizeTypes.value.find(prize => prize.key === type)?.label || titleize(type || '')
}

function statusLabel(value: unknown) {
  const status = String(value || '').trim().toLowerCase()
  if (!status) return '-'
  const key = `rewardRisk.statuses.${status}`
  const translated = adminLocale.t(key)
  return translated === key ? titleize(status) : translated
}

function applySettings(resource: any) {
  settingsForm.enabled = Boolean(resource?.enabled)
  settingsForm.monitored_prize_types = Array.isArray(resource?.monitored_prize_types) ? [...resource.monitored_prize_types] : []
  settingsForm.threshold_multiplier = String(resource?.threshold_multiplier || '1.00')
}

async function loadAll(silent = false) {
  if (scope.value === 'tenant' && !tenantId.value) return
  if (!silent) loading.value = true
  error.value = null
  try {
    const requests: Promise<any>[] = [
      api.apiFetch(`${basePath.value}/overview`, { ...apiOptions.value, query: query() }),
      api.apiFetch(`${basePath.value}/findings`, { ...apiOptions.value, query: query({ prize_type: filters.prize_type, limit: 30 }) }),
      api.apiFetch(`${basePath.value}/runs`, { ...apiOptions.value, query: query({ limit: 30 }) }),
    ]
    if (scope.value === 'tenant') requests.push(api.apiFetch(`${basePath.value}/settings`, apiOptions.value))
    const [nextOverview, nextFindings, nextRuns, settings] = await Promise.all(requests)
    overview.value = nextOverview
    findings.value = Array.isArray(nextFindings?.data) ? nextFindings.data : []
    runs.value = Array.isArray(nextRuns?.data) ? nextRuns.data : []
    Object.assign(findingMeta, nextFindings?.meta || { next_cursor: '', has_more: false })
    Object.assign(runMeta, nextRuns?.meta || { next_cursor: '', has_more: false })
    if (scope.value === 'tenant') applySettings(settings || nextOverview?.settings)
  } catch (err) {
    if (!silent) error.value = err
  } finally {
    if (!silent) loading.value = false
  }
}

async function loadFindings(append: boolean) {
  loadingFindings.value = true
  error.value = null
  try {
    const response: any = await api.apiFetch(`${basePath.value}/findings`, {
      ...apiOptions.value,
      query: query({ prize_type: filters.prize_type, limit: 30, cursor: append ? findingMeta.next_cursor : '' }),
    })
    const next = Array.isArray(response?.data) ? response.data : []
    findings.value = append ? [...findings.value, ...next] : next
    Object.assign(findingMeta, response?.meta || { next_cursor: '', has_more: false })
  } catch (err) {
    error.value = err
  } finally {
    loadingFindings.value = false
  }
}

async function loadRuns(append: boolean) {
  loadingRuns.value = true
  error.value = null
  try {
    const response: any = await api.apiFetch(`${basePath.value}/runs`, {
      ...apiOptions.value,
      query: query({ limit: 30, cursor: append ? runMeta.next_cursor : '' }),
    })
    const next = Array.isArray(response?.data) ? response.data : []
    runs.value = append ? [...runs.value, ...next] : next
    Object.assign(runMeta, response?.meta || { next_cursor: '', has_more: false })
  } catch (err) {
    error.value = err
  } finally {
    loadingRuns.value = false
  }
}

async function saveSettings() {
  savingSettings.value = true
  error.value = null
  successMessage.value = ''
  try {
    const resource: any = await api.apiFetch(`${basePath.value}/settings`, {
      ...apiOptions.value,
      method: 'PUT',
      idempotencyKey: api.idempotencyKey(),
      body: {
        enabled: settingsForm.enabled,
        monitored_prize_types: settingsForm.monitored_prize_types,
        threshold_multiplier: settingsForm.threshold_multiplier,
      },
    })
    applySettings(resource)
    successMessage.value = rr('settingsSaved')
    await loadAll(true)
  } catch (err) {
    error.value = err
  } finally {
    savingSettings.value = false
  }
}

async function openFinding(id: string) {
  detailOpen.value = true
  loadingDetail.value = true
  detailError.value = null
  findingDetail.value = null
  try {
    findingDetail.value = await api.apiFetch(`${basePath.value}/findings/${id}`, apiOptions.value)
  } catch (err) {
    detailError.value = err
  } finally {
    loadingDetail.value = false
  }
}

function closeDetail() {
  detailOpen.value = false
  findingDetail.value = null
  detailError.value = null
}

function applyFilters() {
  void loadAll()
}

function scheduleRefresh() {
  if (refreshTimer !== null) window.clearTimeout(refreshTimer)
  refreshTimer = window.setTimeout(() => {
    refreshTimer = null
    void loadAll(true)
  }, 500)
}

watch(() => [scope.value, tenantId.value], () => void loadAll())
onMounted(() => {
  void loadAll()
  pollTimer = window.setInterval(() => {
    if (realtime.status.value !== 'connected') void loadAll(true)
  }, 15000)
})
onBeforeUnmount(() => {
  if (refreshTimer !== null) window.clearTimeout(refreshTimer)
  if (pollTimer !== null) window.clearInterval(pollTimer)
})
</script>

<style scoped>
.np-risk-tabs {
  display: flex;
  gap: .35rem;
  margin-bottom: 1rem;
  overflow-x: auto;
}

.np-risk-tab {
  align-items: center;
  background: transparent;
  border: 0;
  border-bottom: 2px solid transparent;
  color: var(--default-text-color);
  display: inline-flex;
  gap: .4rem;
  padding: .7rem 1rem;
  white-space: nowrap;
}

.np-risk-tab.active {
  border-bottom-color: rgb(var(--primary-rgb));
  color: rgb(var(--primary-rgb));
  font-weight: 600;
}

.np-risk-prize-grid {
  display: grid;
  gap: .65rem;
  grid-template-columns: repeat(auto-fit, minmax(185px, 1fr));
}

.np-risk-prize-option {
  align-items: flex-start;
  border: 1px solid var(--default-border);
  border-radius: 6px;
  cursor: pointer;
  display: flex;
  gap: .65rem;
  min-height: 64px;
  padding: .75rem;
}

.np-risk-prize-option small,
.np-risk-phase-metrics span,
.np-risk-detail-grid span {
  color: var(--text-muted);
  display: block;
  font-size: .75rem;
}

.np-risk-phase-metrics,
.np-risk-detail-grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.np-risk-phase-metrics strong,
.np-risk-detail-grid strong {
  display: block;
  margin-top: .2rem;
}

.np-risk-number {
  color: rgb(var(--primary-rgb));
  font-size: .9rem;
  font-weight: 700;
  letter-spacing: 0;
}

.np-risk-modal {
  z-index: 1060;
}

.np-risk-modal .modal-dialog {
  position: relative;
  z-index: 1062;
}

.np-risk-modal .modal-backdrop {
  z-index: 1061;
}

@media (max-width: 575.98px) {
  .np-risk-phase-metrics,
  .np-risk-detail-grid {
    grid-template-columns: 1fr;
  }
}
</style>

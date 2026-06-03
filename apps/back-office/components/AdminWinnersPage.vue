<template>
  <div>
    <AdminPageHeader title="Winners" :breadcrumbs="pageBreadcrumbs">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" :disabled="isRefreshing || !selectedGameId" @click="refreshWinners()">
          <span v-if="isRefreshing" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminApiState :error="error" />

    <div class="card custom-card">
      <div class="card-body">
        <div class="row g-3 align-items-end">
          <div class="col-lg-7">
            <label class="form-label" for="winner-game">Game</label>
            <select
              id="winner-game"
              v-model="selectedGameId"
              class="form-select"
              :disabled="loadingGames || !games.length"
            >
              <option v-if="!games.length" value="">No game</option>
              <option v-for="game in games" :key="game.id" :value="game.id">
                {{ gameLabel(game) }}
              </option>
            </select>
          </div>
          <div class="col-lg-5">
            <div class="d-flex flex-wrap align-items-center justify-content-lg-end gap-2">
              <AdminStatusBadge :status="realtimeBadgeStatus" :label="realtimeStatusLabel" />
              <span v-if="realtime.lastEventAt.value" class="text-muted fs-12">
                Last event {{ formatDateTime(realtime.lastEventAt.value) }}
              </span>
              <span v-else-if="meta?.updated_at" class="text-muted fs-12">
                Updated {{ formatDateTime(meta.updated_at) }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <AdminLoader v-if="loadingGames && !games.length" />
    <AdminApiState v-else-if="!games.length" message="No games." />

    <template v-else>
      <div class="row">
        <div v-for="card in summaryCards" :key="card.key" class="col-xxl-3 col-md-6">
          <AdminKpiCard :label="card.label" :value="card.value" :icon="card.icon" :color-class="card.colorClass" />
        </div>
      </div>

      <AdminApiState v-if="meta && !meta.has_live_result && !visibleRows.length" message="Waiting for lotto-scraper live result data or confirmed winners." />

      <div v-if="pageScope === 'central'" class="card custom-card np-live-result-card">
        <div class="card-header d-flex flex-wrap align-items-start justify-content-between gap-2">
          <div>
            <h6 class="card-title mb-1">Realtime reward results</h6>
            <p class="text-muted fs-12 mb-0">Live prize numbers from lotto-scraper for the selected game.</p>
          </div>
          <div class="d-flex flex-wrap align-items-center justify-content-end gap-2">
            <AdminStatusBadge :status="liveResultBadgeStatus" :label="liveResultStatusLabel" />
            <span v-if="liveResultUpdatedAt" class="text-muted fs-12">
              Updated {{ formatDateTime(liveResultUpdatedAt) }}
            </span>
          </div>
        </div>
        <div class="card-body p-0">
          <div v-if="!livePrizeRows.length" class="p-3 text-muted">
            No realtime reward results yet.
          </div>
          <div v-else class="table-responsive">
            <table class="table table-hover mb-0 np-live-result-table">
              <thead>
                <tr>
                  <th scope="col">Prize</th>
                  <th scope="col">Numbers</th>
                  <th scope="col" class="text-end">Payout</th>
                  <th scope="col" class="text-end">Count</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in livePrizeRows" :key="row.key">
                  <td>
                    <div class="fw-semibold">{{ row.label }}</div>
                    <div v-if="row.pendingCount" class="text-muted fs-12">
                      {{ formatNumber(row.pendingCount) }} pending
                    </div>
                  </td>
                  <td>
                    <div class="np-live-result-numbers">
                      <span v-for="number in row.visibleNumbers" :key="`${row.key}-${number}`" class="badge bg-light text-dark border np-live-result-number">
                        {{ number }}
                      </span>
                      <span v-if="row.hiddenCount" class="badge bg-secondary-transparent text-secondary">
                        +{{ formatNumber(row.hiddenCount) }}
                      </span>
                    </div>
                  </td>
                  <td class="text-end fw-semibold">{{ row.payoutLabel }}</td>
                  <td class="text-end">{{ formatNumber(row.count) }}</td>
                  <td>
                    <AdminStatusBadge :status="row.badgeStatus" :label="row.statusLabel" />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <AdminDataTable
        :title="winnerTableTitle"
        :columns="winnerColumns"
        :rows="visibleRows"
        :loading="loadingWinners && !visibleRows.length"
        empty-title="No winners"
        :empty-message="winnerEmptyMessage"
        sortable
        :sort-key="sortKey"
        :sort-direction="sortDirection"
        @sort-change="setSort"
      >
        <template #beforeTable>
          <ul v-if="prizeTabs.length > 1" class="nav nav-tabs np-winner-prize-tabs" role="tablist" aria-label="Prize groups">
            <li v-for="tab in prizeTabs" :key="tab.key" class="nav-item" role="presentation">
              <button
                class="nav-link np-winner-prize-tab"
                :class="{ active: activePrizeTab === tab.key }"
                type="button"
                role="tab"
                :aria-selected="activePrizeTab === tab.key"
                @click="activePrizeTab = tab.key"
              >
                <span>{{ tab.label }} ({{ formatNumber(tab.ticketCount) }})</span>
              </button>
            </li>
          </ul>
        </template>
        <template #cell-full_number="{ row }">
          <span class="np-winner-ticket-number">{{ row.full_number || '-' }}</span>
        </template>
        <template #cell-customer_no="{ row }">
          <div>{{ row.customer_no || '-' }}</div>
          <div v-if="row.customer_count > 1" class="text-muted fs-12">{{ formatNumber(row.customer_count) }} customers</div>
        </template>
        <template #cell-prize_summary="{ row }">
          <div class="fw-semibold text-break">{{ prizeSummary(row) }}</div>
          <div v-if="prizeNumberSummary(row)" class="text-muted fs-12">{{ prizeNumberSummary(row) }}</div>
        </template>
        <template #cell-ticket_count="{ value }">
          {{ formatNumber(value) }}
        </template>
        <template #cell-total_prize_amount="{ value }">
          {{ formatMoney(value) }}
        </template>
        <template #cell-tenant_summary="{ row }">
          <div>{{ row.tenant_summary || row.tenant_name || row.tenant_code || '-' }}</div>
          <div v-if="row.tenant_count > 1" class="text-muted fs-12">{{ formatNumber(row.tenant_count) }} tenants</div>
        </template>
        <template #cell-status="{ value }">
          <AdminStatusBadge :status="winnerStatusValue(value)" :label="winnerStatusLabel(value)" />
        </template>
      </AdminDataTable>
    </template>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, formatMoney, titleize } from '~/utils/format'
import { rewardPrizeLabel, thaiLotteryPrizeDefinitions } from '~/composables/useRewardPrizes'

type SortDirection = 'asc' | 'desc'
type AdminWinnerScope = 'central' | 'tenant'

const props = withDefaults(defineProps<{
  scope?: AdminWinnerScope
}>(), {
  scope: 'central',
})

const api = useAdminApi()
const session = useAdminSession()
const route = useRoute()

const games = ref<any[]>([])
const rowsRaw = ref<any[]>([])
const meta = ref<any>(null)
const liveResult = ref<any>(null)
const loadingGames = ref(false)
const loadingWinners = ref(false)
const error = ref<any>(null)
const selectedGameId = ref('')
const activePrizeTab = ref('all')
const sortKey = ref('updated_at')
const sortDirection = ref<SortDirection>('desc')

let realtimeRefreshTimer: ReturnType<typeof setTimeout> | null = null
let activeWinnersRequest: Promise<void> | null = null
let activeWinnersGameId = ''
let lastWinnersLoadedAt = 0
let lastWinnersLoadedGameId = ''

const winnersRefreshCooldownMs = 1000
const pageScope = computed<AdminWinnerScope>(() => props.scope)
const pageScopeLabel = computed(() => pageScope.value === 'tenant' ? 'Tenant' : 'Central')
const pageBreadcrumbs = computed(() => ['Admin', pageScopeLabel.value, 'Winners'])
const winnersEndpoint = computed(() => `/admin/${pageScope.value}/winners`)
const winnerGamesEndpoint = computed(() => `/admin/${pageScope.value}/winners/games`)

const realtime = useRewardLivePublicRealtime({
  gameId: selectedGameId,
  enabled: computed(() => Boolean(selectedGameId.value)),
  onResult: handleRealtimeResult,
  onReconnect: () => scheduleWinnersRefresh(),
})

const winnerColumns = [
  { key: 'full_number', label: 'Ticket number' },
  { key: 'customer_no', label: 'Customer no' },
  { key: 'prize_summary', label: 'Prize' },
  { key: 'ticket_count', label: 'Tickets' },
  { key: 'total_prize_amount', label: 'Total prize', type: 'money' },
  { key: 'tenant_summary', label: 'Tenant' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]

const isRefreshing = computed(() => loadingWinners.value)

const groupedRows = computed(() => groupWinnerRows(rowsRaw.value, activePrizeTab.value))

const rows = computed(() => {
  const next = [...groupedRows.value]
  const key = sortKey.value
  const direction = sortDirection.value === 'desc' ? -1 : 1

  next.sort((left, right) => compareValues(readSortValue(left, key), readSortValue(right, key)) * direction)
  return next
})

const visibleRows = computed(() => rows.value)

const prizeTabs = computed(() => {
  const types = new Set<string>()
  for (const row of rowsRaw.value) {
    for (const entry of prizeEntriesForRow(row)) {
      if (entry.type) {
        types.add(entry.type)
      }
    }
  }
  for (const row of prizeBreakdownRows.value) {
    const prizeType = normalizePrizeType(row?.prize_type)
    if (prizeType) {
      types.add(prizeType)
    }
  }

  const orderedTypes = [
    ...thaiLotteryPrizeDefinitions.map((definition) => definition.type),
    ...[...types].filter((type) => !thaiLotteryPrizeDefinitions.some((definition) => definition.type === type)).sort(),
  ]

  return [
    {
      key: 'all',
      label: 'All prizes',
      ticketCount: winnerTicketCount('all'),
    },
    ...orderedTypes
      .map((type) => {
        return {
          key: type,
          label: rewardPrizeDisplayLabel(type),
          ticketCount: winnerTicketCount(type),
        }
      })
      .filter((tab) => tab.ticketCount > 0),
  ]
})

const prizeBreakdownRows = computed(() => (
  Array.isArray(meta.value?.prize_breakdown) ? meta.value.prize_breakdown : []
))

const liveResultData = computed(() => liveResult.value || meta.value?.live_result || null)

const liveResultStatusValue = computed(() => String(
  liveResultData.value?.status
  || liveResultData.value?.official_status
  || (meta.value?.has_live_result ? 'live_draft' : 'pending')
).trim())

const liveResultBadgeStatus = computed(() => {
  const status = liveResultStatusValue.value
  if (status === 'published' || status === 'confirmed') {
    return 'approved'
  }
  if (status === 'failed') {
    return 'failed'
  }
  if (status === 'pending') {
    return 'pending'
  }

  return 'processing'
})

const liveResultStatusLabel = computed(() => {
  const status = liveResultStatusValue.value
  const labels: Record<string, string> = {
    live_draft: 'Live draft',
    live_unconfirmed: 'Live unconfirmed',
    published: 'Confirmed',
    confirmed: 'Confirmed',
    pending: 'Waiting for result',
  }

  return labels[status] || titleize(status || 'pending')
})

const liveResultUpdatedAt = computed(() => liveResultData.value?.updated_at || meta.value?.updated_at || '')

const livePrizeRows = computed(() => buildLivePrizeRows(liveResultData.value))

const activePrizeLabel = computed(() => (
  prizeTabs.value.find((tab) => tab.key === activePrizeTab.value)?.label || 'All prizes'
))

const winnerTableTitle = computed(() => (
  activePrizeTab.value === 'all'
    ? 'Winners'
    : `Winners - ${activePrizeLabel.value}`
))

const winnerEmptyMessage = computed(() => (
  activePrizeTab.value === 'all'
    ? 'Winning tickets will appear when live prize numbers or confirmed reward results match sold tickets.'
    : `Winning tickets for ${activePrizeLabel.value} will appear when live prize numbers or confirmed reward results match sold tickets.`
))

const summaryCards = computed(() => [
  {
    key: 'completion',
    label: 'Live completion',
    value: `${formatPercent(meta.value?.completion_percent)}%`,
    icon: 'ri-broadcast-line',
    colorClass: 'bg-primary-transparent text-primary',
  },
  {
    key: 'winners',
    label: 'Winners',
    value: formatNumber(meta.value?.winner_count ?? 0),
    icon: 'ri-trophy-line',
    colorClass: 'bg-success-transparent text-success',
  },
  {
    key: 'rows',
    label: 'Winning rows',
    value: formatNumber(meta.value?.winning_row_count ?? 0),
    icon: 'ri-list-check-3',
    colorClass: 'bg-info-transparent text-info',
  },
  {
    key: 'payout',
    label: 'Estimated payout',
    value: formatMoney(meta.value?.total_prize_amount || { amount: 0, currency: 'THB' }),
    icon: 'ri-money-dollar-circle-line',
    colorClass: 'bg-warning-transparent text-warning',
  },
])

const realtimeBadgeStatus = computed(() => {
  if (!realtime.isConfigured.value) {
    return 'unavailable'
  }

  return realtime.status.value === 'error' ? 'failed' : realtime.status.value
})

const realtimeStatusLabel = computed(() => {
  if (!realtime.isConfigured.value) {
    return 'Realtime unavailable'
  }

  const labels: Record<string, string> = {
    connected: 'Realtime connected',
    connecting: 'Realtime connecting',
    reconnecting: 'Realtime reconnecting',
    idle: 'Realtime idle',
    error: 'Realtime error',
  }

  return labels[realtime.status.value] || titleize(realtime.status.value)
})

watch(selectedGameId, (next, previous) => {
  if (next && next !== previous) {
    activePrizeTab.value = 'all'
    void refreshWinners()
  }
})

watch(prizeTabs, (tabs) => {
  if (!tabs.some((tab) => tab.key === activePrizeTab.value)) {
    activePrizeTab.value = 'all'
  }
})

onMounted(() => {
  session.setScope(pageScope.value)
  void loadGames()
})

onBeforeUnmount(() => {
  if (realtimeRefreshTimer !== null && import.meta.client) {
    window.clearTimeout(realtimeRefreshTimer)
  }
})

async function loadGames() {
  loadingGames.value = true
  error.value = null

  try {
    const response = await api.apiFetch(winnerGamesEndpoint.value, { scope: pageScope.value })
    games.value = extractItems(response)
    const defaultGameId = String(response?.meta?.default_game_id || '')
    const requestedGameId = String(route.query.game_id || '')
    const requestedGame = games.value.find((game) => String(game.id) === requestedGameId)
    selectedGameId.value = String(requestedGame?.id || defaultGameId || games.value[0]?.id || '')
    if (!selectedGameId.value) {
      rowsRaw.value = []
      meta.value = null
      liveResult.value = null
    }
  } catch (err) {
    error.value = err
    games.value = []
    rowsRaw.value = []
    meta.value = null
    liveResult.value = null
  } finally {
    loadingGames.value = false
  }
}

async function refreshWinners(options: { silent?: boolean } = {}) {
  if (!selectedGameId.value) {
    rowsRaw.value = []
    meta.value = null
    liveResult.value = null
    return
  }

  await loadWinners(options)
}

async function loadWinners(options: { silent?: boolean } = {}) {
  const gameId = selectedGameId.value
  if (!gameId) {
    rowsRaw.value = []
    meta.value = null
    liveResult.value = null
    return
  }

  if (activeWinnersRequest && activeWinnersGameId === gameId) {
    return activeWinnersRequest
  }

  activeWinnersGameId = gameId
  activeWinnersRequest = runWinnersRequest(gameId, !options.silent)

  try {
    await activeWinnersRequest
  } finally {
    if (activeWinnersGameId === gameId) {
      activeWinnersRequest = null
      activeWinnersGameId = ''
    }
  }
}

async function runWinnersRequest(gameId: string, showLoader: boolean) {
  if (showLoader) {
    loadingWinners.value = true
  }
  error.value = null

  try {
    const response = await api.apiFetch(winnersEndpoint.value, {
      scope: pageScope.value,
      query: {
        game_id: gameId,
        limit: 100,
      },
    })

    if (selectedGameId.value !== gameId) {
      return
    }

    rowsRaw.value = extractItems(response)
    meta.value = response?.meta || null
    liveResult.value = normalizeLiveResult(meta.value?.live_result || null)
    lastWinnersLoadedAt = Date.now()
    lastWinnersLoadedGameId = gameId
  } catch (err) {
    if (selectedGameId.value === gameId) {
      error.value = err
    }
  } finally {
    if (showLoader && selectedGameId.value === gameId) {
      loadingWinners.value = false
    }
  }
}

function handleRealtimeResult(payload: any) {
  const payloadGameId = String(payload?.game_id || '').trim()
  if (payloadGameId && payloadGameId !== selectedGameId.value) {
    return
  }

  const normalized = normalizeLiveResult(payload)
  if (normalized) {
    const merged = mergeLiveResults(liveResult.value || meta.value?.live_result || null, normalized)
    liveResult.value = merged
    meta.value = {
      ...(meta.value || {}),
      has_live_result: true,
      live_result: merged,
      completion_percent: merged?.completion_percent ?? meta.value?.completion_percent,
      source: merged?.source ?? meta.value?.source,
      updated_at: merged?.updated_at || meta.value?.updated_at,
    }
  }

  scheduleWinnersRefresh()
}

function scheduleWinnersRefresh() {
  if (!selectedGameId.value) {
    return
  }

  if (!import.meta.client) {
    void loadWinnersIfStale()
    return
  }

  if (realtimeRefreshTimer !== null) {
    window.clearTimeout(realtimeRefreshTimer)
  }

  realtimeRefreshTimer = window.setTimeout(() => {
    realtimeRefreshTimer = null
    void loadWinnersIfStale()
  }, 350)
}

function loadWinnersIfStale() {
  const gameId = selectedGameId.value
  if (!gameId) {
    return
  }

  if (loadingWinners.value) {
    return
  }

  if (activeWinnersRequest && activeWinnersGameId === gameId) {
    return
  }

  if (lastWinnersLoadedGameId === gameId && Date.now() - lastWinnersLoadedAt < winnersRefreshCooldownMs) {
    return
  }

  void loadWinners({ silent: true })
}

function setSort(value: { key: string, direction: SortDirection }) {
  sortKey.value = value.key
  sortDirection.value = value.direction
}

function winnerStatusValue(value: any) {
  const status = String(value || '').trim()
  return status === 'live_result' ? 'live_draft' : status || 'pending'
}

function winnerStatusLabel(value: any) {
  const status = winnerStatusValue(value)
  if (status === 'live_draft') {
    return 'Live draft'
  }
  if (status === 'pending_confirmation') {
    return 'Pending confirmation'
  }

  return titleize(status)
}

function normalizePrizeType(value: any) {
  return String(value || '').trim().toLowerCase()
}

function rewardPrizeDisplayLabel(value: any) {
  const prizeType = normalizePrizeType(value)
  if (!prizeType) {
    return '-'
  }

  const label = rewardPrizeLabel(prizeType)
  return label === prizeType ? titleize(prizeType) : label
}

function normalizeLiveResult(value: any) {
  if (!value || typeof value !== 'object') {
    return null
  }

  const prizes = Array.isArray(value.prizes) ? value.prizes : []

  return {
    ...value,
    prizes,
  }
}

function mergeLiveResults(currentValue: any, nextValue: any) {
  const current = normalizeLiveResult(currentValue)
  const next = normalizeLiveResult(nextValue)
  if (!current) {
    return next
  }
  if (!next) {
    return current
  }

  const nextPrizeTypes = new Set(next.prizes.map((prize: any) => normalizePrizeType(prize?.prize_type)).filter(Boolean))
  const preservedPrizes = current.prizes.filter((prize: any) => !nextPrizeTypes.has(normalizePrizeType(prize?.prize_type)))

  return {
    ...current,
    ...next,
    prizes: [
      ...preservedPrizes,
      ...next.prizes,
    ],
  }
}

function buildLivePrizeRows(result: any) {
  const prizes = Array.isArray(result?.prizes) ? result.prizes : []
  const groups = new Map<string, any>()

  prizes.forEach((prize: any) => {
    const prizeType = normalizePrizeType(prize?.prize_type)
    if (!prizeType) {
      return
    }

    const group = groups.get(prizeType) || {
      key: prizeType,
      type: prizeType,
      label: rewardPrizeDisplayLabel(prizeType),
      numbers: [],
      count: 0,
      pendingCount: 0,
      amount: prize?.amount || prize?.payout_amount || null,
      sortOrder: livePrizeSortOrder(prizeType),
      status: 'live_draft',
    }

    const number = livePrizeNumber(prize)
    if (number) {
      group.numbers.push(number)
    }
    if (isLivePrizePending(prize)) {
      group.pendingCount += 1
    }
    if (!group.amount && (prize?.amount || prize?.payout_amount)) {
      group.amount = prize?.amount || prize?.payout_amount
    }
    group.count += 1
    group.status = livePrizeStatus(result, group)
    groups.set(prizeType, group)
  })

  return Array.from(groups.values())
    .map((group) => {
      const uniqueNumbers = Array.from(new Set(group.numbers))
      const visibleNumbers = uniqueNumbers.slice(0, 12)
      const badgeStatus = livePrizeBadgeStatus(group.status, group.pendingCount, group.count)

      return {
        ...group,
        numbers: uniqueNumbers,
        visibleNumbers,
        hiddenCount: Math.max(uniqueNumbers.length - visibleNumbers.length, 0),
        payoutLabel: formatLivePrizeMoney(group.amount),
        badgeStatus,
        statusLabel: livePrizeStatusLabel(badgeStatus),
      }
    })
    .sort((left, right) => (
      compareValues(left.sortOrder, right.sortOrder)
      || compareValues(left.label, right.label)
    ))
}

function livePrizeSortOrder(prizeType: string) {
  const index = thaiLotteryPrizeDefinitions.findIndex((definition) => definition.type === prizeType)
  return index >= 0 ? index : thaiLotteryPrizeDefinitions.length + 1
}

function livePrizeNumber(prize: any) {
  const number = String(prize?.prize_number ?? prize?.number ?? '').trim()
  if (!number || number.startsWith('pending_')) {
    return ''
  }

  return number
}

function isLivePrizePending(prize: any) {
  return Boolean(prize?.is_pending) || String(prize?.prize_number || '').startsWith('pending_')
}

function livePrizeStatus(result: any, group: any) {
  if (group.pendingCount >= group.count) {
    return 'pending'
  }

  return String(result?.status || result?.official_status || 'live_draft')
}

function livePrizeBadgeStatus(status: string, pendingCount: number, count: number) {
  if (pendingCount >= count) {
    return 'pending'
  }
  if (status === 'published' || status === 'confirmed') {
    return 'approved'
  }
  if (status === 'failed') {
    return 'failed'
  }

  return 'processing'
}

function livePrizeStatusLabel(status: string) {
  const labels: Record<string, string> = {
    approved: 'Confirmed',
    failed: 'Failed',
    pending: 'Pending',
    processing: 'Live',
  }

  return labels[status] || titleize(status)
}

function formatLivePrizeMoney(value: any) {
  if (!value) {
    return '-'
  }

  return formatMoney(moneyAmount(value), moneyCurrency(value))
}

function winnerTicketCount(prizeType: string) {
  if (prizeType === 'all') {
    const metaCount = Number(meta.value?.winner_count)
    if (Number.isFinite(metaCount)) {
      return metaCount
    }

    return groupWinnerRows(rowsRaw.value, 'all').reduce((sum, row) => sum + Number(row.ticket_count || 0), 0)
  }

  const breakdown = prizeBreakdownRows.value.find((row: any) => normalizePrizeType(row?.prize_type) === prizeType)
  const breakdownCount = Number(breakdown?.winner_count ?? breakdown?.ticket_count ?? breakdown?.winning_row_count)
  if (Number.isFinite(breakdownCount)) {
    return breakdownCount
  }

  return groupWinnerRows(rowsRaw.value, prizeType).reduce((sum, row) => sum + Number(row.ticket_count || 0), 0)
}

function groupWinnerRows(sourceRows: any[], prizeType: string) {
  const groups = new Map<string, any>()

  sourceRows.forEach((row, rowIndex) => {
    const number = String(row?.full_number || '').trim()
    if (!number) {
      return
    }

    const entries = prizeEntriesForRow(row).filter((entry) => (
      prizeType === 'all' || entry.type === prizeType
    ))
    if (!entries.length) {
      return
    }

    const group = groups.get(number) || {
      id: `winner-group-${number}-${prizeType}`,
      full_number: number,
      prize_summary: '',
      prize_numbers: new Set<string>(),
      prize_types: new Set<string>(),
      ticket_count: 0,
      total_prize_amount: { amount: 0, currency: winnerCurrency(row) },
      customer_no: '',
      customer_count: Math.max(Number(row?.customer_count || 0), customerNoValuesForRow(row).length),
      tenant_summary: row?.tenant_summary || row?.tenant_name || row?.tenant_code || '',
      tenant_name: row?.tenant_name,
      tenant_code: row?.tenant_code,
      tenant_count: Number(row?.tenant_count || 0),
      tenants: Array.isArray(row?.tenants) ? row.tenants : [],
      status: row?.status || 'live_draft',
      updated_at: row?.updated_at,
      _ticketCounts: new Map<string, number>(),
      _customerNos: new Set<string>(),
      _entries: [],
    }

    entries.forEach((entry) => {
      group.prize_types.add(entry.type)
      entry.prizeNumbers.forEach((numberValue) => group.prize_numbers.add(numberValue))
      group.total_prize_amount.amount += entry.totalAmount
      group.total_prize_amount.currency = entry.currency || group.total_prize_amount.currency
      group._entries.push(entry)
    })

    const ticketKey = winnerTicketKey(row, rowIndex)
    const ticketCount = prizeType === 'all'
      ? winnerRowTicketCount(row)
      : entries.reduce((sum, entry) => sum + entry.ticketCount, 0)
    group._ticketCounts.set(ticketKey, Math.max(group._ticketCounts.get(ticketKey) || 0, ticketCount))
    group.ticket_count = Array.from(group._ticketCounts.values()).reduce((sum, count) => sum + count, 0)
    customerNoValuesForRow(row).forEach((value) => group._customerNos.add(value))
    group.customer_count = Math.max(
      Number(group.customer_count || 0),
      Number(row?.customer_count || 0),
      group._customerNos.size,
    )
    group.tenant_count = Math.max(group.tenant_count || 0, Array.isArray(group.tenants) ? group.tenants.length : 0)

    groups.set(number, group)
  })

  return Array.from(groups.values()).map((group) => ({
    ...group,
    prize_summary: prizeSummary(group),
    prize_numbers: Array.from(group.prize_numbers),
    prize_types: Array.from(group.prize_types),
    customer_no: customerNoSummary(Array.from(group._customerNos), group.customer_count),
  }))
}

function prizeEntriesForRow(row: any) {
  const breakdown = Array.isArray(row?.prize_breakdown) ? row.prize_breakdown : []
  if (breakdown.length) {
    return breakdown
      .map((entry: any) => {
        const type = normalizePrizeType(entry?.prize_type)
        const totalMoney = entry?.total_prize_amount || entry?.prize_amount || row?.total_prize_amount || row?.prize_amount

        return {
          type,
          label: rewardPrizeDisplayLabel(type),
          prizeNumbers: arrayValues(entry?.prize_numbers),
          ticketCount: Number(entry?.ticket_count ?? entry?.winner_count ?? entry?.winning_row_count ?? row?.ticket_count ?? 0),
          totalAmount: moneyAmount(totalMoney),
          currency: moneyCurrency(totalMoney),
        }
      })
      .filter((entry: any) => entry.type)
  }

  const type = normalizePrizeType(row?.prize_type)
  const money = row?.total_prize_amount || row?.prize_amount

  return type
    ? [{
        type,
        label: rewardPrizeDisplayLabel(type),
        prizeNumbers: arrayValues(row?.prize_numbers ?? row?.prize_number),
        ticketCount: winnerRowTicketCount(row),
        totalAmount: moneyAmount(money),
        currency: moneyCurrency(money),
      }]
    : []
}

function winnerRowTicketCount(row: any) {
  const count = Number(row?.ticket_count ?? row?.winner_count ?? row?.winning_row_count)
  return Number.isFinite(count) && count > 0 ? count : 1
}

function winnerTicketKey(row: any, rowIndex: number) {
  const ticketId = String(row?.ticket_id || '').trim()
  if (ticketId) {
    return `ticket:${ticketId}`
  }

  const tenantId = String(row?.tenant_id || '').trim()
  if (tenantId) {
    return `tenant:${tenantId}`
  }

  return `row:${String(row?.id || rowIndex)}`
}

function prizeSummary(row: any) {
  const entries = Array.isArray(row?._entries) && row._entries.length
    ? row._entries
    : prizeEntriesForRow(row)
  const labels = Array.from(new Set(entries.map((entry: any) => entry.label).filter(Boolean)))

  return labels.length ? labels.join(', ') : '-'
}

function prizeNumberSummary(row: any) {
  const numbers = Array.isArray(row?.prize_numbers)
    ? row.prize_numbers
    : Array.from(row?.prize_numbers || [])

  if (!numbers.length) {
    return ''
  }

  const visible = numbers.slice(0, 4)
  const suffix = numbers.length > visible.length ? ` +${formatNumber(numbers.length - visible.length)} more` : ''

  return `Prize numbers: ${visible.join(', ')}${suffix}`
}

function arrayValues(value: any) {
  if (Array.isArray(value)) {
    return value.map((next) => String(next || '').trim()).filter(Boolean)
  }

  const normalized = String(value || '').trim()
  return normalized ? [normalized] : []
}

function customerNoValuesForRow(row: any) {
  if (Array.isArray(row?.customers)) {
    return row.customers
      .map((customer: any) => String(customer?.customer_no || customer?.member_no || '').trim())
      .filter(Boolean)
  }

  return arrayValues(row?.customer_no || row?.customer?.customer_no || row?.member_no)
}

function customerNoSummary(values: string[], count: number) {
  const uniqueValues = Array.from(new Set(values.map((value) => String(value || '').trim()).filter(Boolean)))
  if (!uniqueValues.length) {
    return ''
  }

  const visible = uniqueValues.slice(0, 2)
  const total = Math.max(Number(count || 0), uniqueValues.length)
  const suffix = total > visible.length ? ` +${formatNumber(total - visible.length)} more` : ''
  return `${visible.join(', ')}${suffix}`
}

function moneyAmount(value: any) {
  const amount = Number(value?.amount ?? value ?? 0)
  return Number.isFinite(amount) ? amount : 0
}

function moneyCurrency(value: any) {
  return String(value?.currency || 'THB')
}

function winnerCurrency(row: any) {
  return moneyCurrency(row?.total_prize_amount || row?.prize_amount)
}

function gameLabel(game: any) {
  const code = game?.code || game?.game_code || ''
  const name = game?.name || game?.game_name || game?.title || game?.id || ''
  const status = game?.status ? ` · ${titleize(String(game.status))}` : ''
  const defaultLabel = game?.is_default ? ' · Default' : ''
  return `${[code, name].filter(Boolean).join(' - ')}${status}${defaultLabel}`
}

function extractItems(response: any) {
  if (Array.isArray(response?.data)) {
    return response.data
  }

  if (Array.isArray(response)) {
    return response
  }

  return []
}

function readSortValue(row: any, key: string) {
  const value = row?.[key]
  if (value && typeof value === 'object' && 'amount' in value) {
    return Number(value.amount)
  }

  return value
}

function compareValues(left: any, right: any) {
  if (left === right) {
    return 0
  }

  if (left === undefined || left === null || left === '') {
    return 1
  }

  if (right === undefined || right === null || right === '') {
    return -1
  }

  const leftNumber = Number(left)
  const rightNumber = Number(right)
  if (Number.isFinite(leftNumber) && Number.isFinite(rightNumber)) {
    return leftNumber - rightNumber
  }

  const leftTime = Date.parse(String(left))
  const rightTime = Date.parse(String(right))
  if (Number.isFinite(leftTime) && Number.isFinite(rightTime)) {
    return leftTime - rightTime
  }

  return String(left).localeCompare(String(right))
}

function formatPercent(value: any) {
  const number = Number(value)
  if (!Number.isFinite(number)) {
    return '0'
  }

  return number.toLocaleString('th-TH', {
    minimumFractionDigits: Number.isInteger(number) ? 0 : 2,
    maximumFractionDigits: 2,
  })
}

function formatNumber(value: any) {
  const number = Number(value)
  if (!Number.isFinite(number)) {
    return '0'
  }

  return number.toLocaleString('th-TH')
}
</script>

<style scoped>
.np-winner-ticket-number {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
  font-size: 1rem;
  font-weight: 700;
  letter-spacing: 0;
}

.np-winner-prize-tabs {
  border-bottom: 0;
  display: flex;
  flex-wrap: wrap;
  gap: .5rem;
}

.np-winner-prize-tab {
  align-items: center;
  border: 1px solid var(--default-border);
  border-radius: 6px;
  display: inline-flex;
  gap: .5rem;
  min-height: 2.375rem;
}

.np-live-result-table th {
  color: var(--text-muted);
  font-size: .75rem;
  font-weight: 700;
  text-transform: uppercase;
}

.np-live-result-numbers {
  align-items: center;
  display: flex;
  flex-wrap: wrap;
  gap: .375rem;
  min-width: 12rem;
}

.np-live-result-number {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
  font-size: .8125rem;
  font-weight: 700;
  letter-spacing: 0;
}
</style>

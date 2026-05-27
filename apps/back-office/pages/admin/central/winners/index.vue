<template>
  <div>
    <AdminPageHeader title="Winners" :breadcrumbs="['Admin', 'Central', 'Winners']">
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

definePageMeta({ layout: 'admin' })

type SortDirection = 'asc' | 'desc'

const api = useAdminApi()
const session = useAdminSession()
const route = useRoute()

const games = ref<any[]>([])
const rowsRaw = ref<any[]>([])
const meta = ref<any>(null)
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

const realtime = useRewardLivePublicRealtime({
  gameId: selectedGameId,
  enabled: computed(() => Boolean(selectedGameId.value)),
  onResult: handleRealtimeResult,
  onReconnect: () => scheduleWinnersRefresh(),
})

const winnerColumns = [
  { key: 'full_number', label: 'Ticket number' },
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
  session.setScope('central')
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
    const response = await api.apiFetch('/admin/central/winners/games', { scope: 'central' })
    games.value = extractItems(response)
    const defaultGameId = String(response?.meta?.default_game_id || '')
    const requestedGameId = String(route.query.game_id || '')
    const requestedGame = games.value.find((game) => String(game.id) === requestedGameId)
    selectedGameId.value = String(requestedGame?.id || defaultGameId || games.value[0]?.id || '')
    if (!selectedGameId.value) {
      rowsRaw.value = []
      meta.value = null
    }
  } catch (err) {
    error.value = err
    games.value = []
    rowsRaw.value = []
    meta.value = null
  } finally {
    loadingGames.value = false
  }
}

async function refreshWinners(options: { silent?: boolean } = {}) {
  if (!selectedGameId.value) {
    rowsRaw.value = []
    meta.value = null
    return
  }

  await loadWinners(options)
}

async function loadWinners(options: { silent?: boolean } = {}) {
  const gameId = selectedGameId.value
  if (!gameId) {
    rowsRaw.value = []
    meta.value = null
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
    const response = await api.apiFetch('/admin/central/winners', {
      scope: 'central',
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
      tenant_summary: row?.tenant_summary || row?.tenant_name || row?.tenant_code || '',
      tenant_name: row?.tenant_name,
      tenant_code: row?.tenant_code,
      tenant_count: Number(row?.tenant_count || 0),
      tenants: Array.isArray(row?.tenants) ? row.tenants : [],
      status: row?.status || 'live_draft',
      updated_at: row?.updated_at,
      _ticketCounts: new Map<string, number>(),
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
    group.tenant_count = Math.max(group.tenant_count || 0, Array.isArray(group.tenants) ? group.tenants.length : 0)

    groups.set(number, group)
  })

  return Array.from(groups.values()).map((group) => ({
    ...group,
    prize_summary: prizeSummary(group),
    prize_numbers: Array.from(group.prize_numbers),
    prize_types: Array.from(group.prize_types),
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
</style>

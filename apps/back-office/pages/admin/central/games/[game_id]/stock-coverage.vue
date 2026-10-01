<template>
  <div>
    <AdminPageHeader
      title="Stock Pattern Coverage"
      :breadcrumbs="['Central', 'Games', gameId]"
    >
      <template #actions>
        <NuxtLink to="/admin/central/games" class="btn btn-light btn-wave">
          Back to games
        </NuxtLink>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading" @click="reloadCurrent">
          <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
          Reload
        </button>
      </template>
    </AdminPageHeader>

    <AdminApiState :error="error" />

    <div class="card custom-card">
      <div class="card-body border-bottom">
        <div class="row g-3 align-items-end">
          <div class="col-12 col-md-4 col-xl-3">
            <label class="form-label">Scope</label>
            <select v-model="scopeType" class="form-select">
              <option value="central">Central</option>
              <option value="partner">Partner</option>
            </select>
          </div>
          <div v-if="scopeType === 'partner'" class="col-12 col-md-5 col-xl-4">
            <label class="form-label">Partner</label>
            <select v-model="scopeId" class="form-select" :disabled="partnersLoading">
              <option value="">{{ partnersLoading ? 'Loading partners...' : 'Select partner' }}</option>
              <option v-for="partner in partners" :key="partner.id" :value="partner.id">
                {{ partner.name || partner.id }}
              </option>
            </select>
          </div>
          <div class="col-12 col-md-auto">
            <button class="btn btn-outline-primary btn-wave" type="button" :disabled="loading || !canLoadScope" @click="resetAndLoad">
              Apply
            </button>
          </div>
        </div>
      </div>

      <div class="card-body border-bottom">
        <div class="row g-3 align-items-end">
          <div class="col-12 col-md-4 col-xl-3">
            <label class="form-label">Limit รวม 2 ตัวท้าย</label>
            <input v-model="limitDraft.back2_limit" type="number" min="0" step="1" class="form-control" placeholder="ไม่จำกัด">
          </div>
          <div class="col-12 col-md-4 col-xl-3">
            <label class="form-label">Limit รวม 3 ตัวหน้า</label>
            <input v-model="limitDraft.front3_limit" type="number" min="0" step="1" class="form-control" placeholder="ไม่จำกัด">
          </div>
          <div class="col-12 col-md-4 col-xl-3">
            <label class="form-label">Limit รวม 3 ตัวท้าย</label>
            <input v-model="limitDraft.back3_limit" type="number" min="0" step="1" class="form-control" placeholder="ไม่จำกัด">
          </div>
          <div class="col-12 col-xl-auto">
            <button class="btn btn-success btn-wave" type="button" :disabled="savingLimits || loading || !canLoadScope" @click="saveLimitSettings">
              <span v-if="savingLimits" class="spinner-border spinner-border-sm me-2" />
              Save limits
            </button>
          </div>
        </div>
      </div>

      <div class="card-header border-bottom-0 pb-0">
        <ul class="nav nav-tabs card-header-tabs" role="tablist">
          <li v-for="tab in tabs" :key="tab.key" class="nav-item" role="presentation">
            <button
              :class="['nav-link', { active: activeTab === tab.key }]"
              type="button"
              role="tab"
              @click="changeTab(tab.key)"
            >
              {{ tab.label }} ({{ formatNumber(tab.total?.sold_count || 0) }})
            </button>
          </li>
        </ul>
      </div>

      <div class="card-body">
        <form class="input-group mb-3" @submit.prevent="resetAndLoad">
          <span class="input-group-text"><i class="ri-search-line" /></span>
          <input
            v-model="search"
            type="search"
            class="form-control"
            placeholder="ค้นหาข้อมูลในตาราง"
          >
          <button class="btn btn-outline-primary" type="submit" :disabled="loading">Search</button>
        </form>

        <AdminDataTable
          embedded
          title=""
          :columns="columns"
          :rows="rows"
          :loading="loading"
          :sort-key="sortState.key"
          :sort-direction="sortState.direction"
          sortable
          empty-title="No records"
          empty-message="No stock pattern rows matched the current filters."
          @sort-change="applySort"
        >
          <template #cell-number="{ row }">
            <span class="fw-semibold">{{ row.number }}</span>
          </template>
          <template #cell-generated_count="{ row }">
            {{ formatNumber(row.generated_count) }}
          </template>
          <template #cell-reserved_count="{ row }">
            {{ formatNumber(row.reserved_count) }}
          </template>
          <template #cell-sold_count="{ row }">
            {{ formatNumber(row.sold_count) }}
          </template>
          <template #cell-default_limit="{ row }">
            {{ formatLimit(row.default_limit) }}
          </template>
          <template #cell-override_limit="{ row }">
            <input
              :value="draftValue(row)"
              type="number"
              min="0"
              :max="row.generated_count"
              step="1"
              class="form-control form-control-sm"
              :placeholder="formatLimit(row.default_limit)"
              @input="setDraft(row, $event)"
            >
          </template>
          <template #cell-remaining_limit="{ row }">
            {{ formatLimit(row.remaining_limit) }}
          </template>
          <template #cell-sellable_remaining_count="{ row }">
            <span :class="{ 'text-danger fw-semibold': row.limit_exceeds_supply }">
              {{ formatNumber(row.sellable_remaining_count) }}
            </span>
          </template>
          <template #rowActions="{ row }">
            <button class="btn btn-sm btn-primary btn-wave" type="button" :disabled="savingKey === row.id" @click="saveOverride(row)">
              <span v-if="savingKey === row.id" class="spinner-border spinner-border-sm me-1" />
              Save
            </button>
          </template>
        </AdminDataTable>

        <AdminPagination
          class="mt-3"
          :next-cursor="meta.next_cursor"
          :has-previous="pageState.index > 0"
          :loading="loading"
          :current-page="pageState.index + 1"
          :page-size="pageSize"
          @previous="loadPreviousPage"
          @next="loadNextPage"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

type PatternKey = 'back2' | 'front3' | 'back3'
type PatternRow = {
  id: string
  number: string
  generated_count?: number
  reserved_count: number
  sold_count: number
  default_limit?: number | null
  override_limit?: number | null
  remaining_limit?: number | null
  sellable_remaining_count?: number
  limit_exceeds_supply?: boolean
}
type PartnerOption = {
  id: string
  name?: string
}

const route = useRoute()
const api = useAdminApi()
const gameId = computed(() => String(route.params.game_id || ''))
const loading = ref(false)
const partnersLoading = ref(false)
const error = ref<any>(null)
const search = ref('')
const activeTab = ref<PatternKey>('back2')
const scopeType = ref<'central' | 'partner'>('central')
const scopeId = ref('central')
const partners = ref<PartnerOption[]>([])
const report = ref<any>(null)
const rows = ref<PatternRow[]>([])
const overrideDrafts = reactive<Record<string, string>>({})
const limitDraft = reactive({
  back2_limit: '',
  back3_limit: '',
  front3_limit: '',
})
const savingKey = ref('')
const savingLimits = ref(false)
const pageSize = ref(50)
const meta = reactive<{ next_cursor: string | null, has_more: boolean }>({
  next_cursor: null,
  has_more: false,
})
const pageState = reactive<{ cursors: Array<string | null>, index: number }>({
  cursors: [null],
  index: 0,
})
const sortState = reactive<{ key: string, direction: 'asc' | 'desc' }>({
  key: 'number',
  direction: 'asc',
})

const columns = [
  { key: 'number', label: 'หมายเลข' },
  { key: 'generated_count', label: 'Generated' },
  { key: 'reserved_count', label: 'Reserved' },
  { key: 'sold_count', label: 'Sold' },
  { key: 'default_limit', label: 'Limit' },
  { key: 'override_limit', label: 'Override' },
  { key: 'remaining_limit', label: 'Limit remaining' },
  { key: 'sellable_remaining_count', label: 'Remaining' },
]
const tabs = computed(() => [
  { key: 'back2' as const, label: 'สองตัว', total: report.value?.totals?.back2 },
  { key: 'front3' as const, label: 'สามตัวหน้า', total: report.value?.totals?.front3 },
  { key: 'back3' as const, label: 'สามตัวหลัง', total: report.value?.totals?.back3 },
])
const canLoadScope = computed(() => scopeType.value === 'central' || Boolean(scopeId.value))

watch(gameId, () => {
  resetAndLoad()
}, { immediate: true })
watch(scopeType, (value) => {
  scopeId.value = value === 'central' ? 'central' : ''
  report.value = null
  rows.value = []
  resetPaging()
  if (value === 'partner' && partners.value.length === 0) {
    void loadPartners()
  }
})
watch(scopeId, () => {
  if (canLoadScope.value) {
    resetAndLoad()
  }
})

function changeTab(tab: PatternKey) {
  if (activeTab.value === tab) {
    return
  }

  activeTab.value = tab
  sortState.key = 'number'
  sortState.direction = 'asc'
  resetAndLoad()
}

function applySort(next: { key: string, direction: 'asc' | 'desc' }) {
  sortState.key = next.key
  sortState.direction = next.direction
  resetAndLoad()
}

function resetAndLoad() {
  resetPaging()
  void loadPatterns(null, 'reset')
}

function reloadCurrent() {
  void loadPatterns(pageState.cursors[pageState.index] || null, 'current')
}

async function loadPatterns(cursor: string | null = null, pageMode: 'reset' | 'next' | 'previous' | 'current' = 'reset') {
  if (!import.meta.client || !gameId.value || !canLoadScope.value) {
    return
  }

  loading.value = true
  error.value = null

  try {
    const response: any = await api.apiFetch('/admin/central/stock/patterns', {
      scope: 'central',
      query: {
        game_id: gameId.value,
        scope_type: scopeType.value,
        scope_id: scopeId.value,
        dimension: activeTab.value,
        q: search.value.trim() || undefined,
        limit: pageSize.value,
        cursor: cursor || undefined,
        sort_by: sortState.key,
        sort_dir: sortState.direction,
      },
    })
    report.value = response
    rows.value = extractItems(response)
    const nextMeta = response?.meta || {}
    meta.next_cursor = nextMeta.next_cursor || null
    meta.has_more = Boolean(nextMeta.has_more || nextMeta.next_cursor)
    if (pageMode === 'reset') {
      pageState.cursors = [null]
      pageState.index = 0
    } else if (pageMode === 'next') {
      pageState.index += 1
      pageState.cursors[pageState.index] = cursor
    } else if (pageMode === 'previous') {
      pageState.index = Math.max(0, pageState.index - 1)
    }
    resetDrafts()
    syncLimitDraft()
  } catch (err) {
    error.value = err
    report.value = null
    rows.value = []
    syncLimitDraft()
  } finally {
    loading.value = false
  }
}

function loadNextPage() {
  if (!meta.next_cursor) {
    return
  }

  void loadPatterns(meta.next_cursor, 'next')
}

function loadPreviousPage() {
  if (pageState.index <= 0) {
    return
  }

  const previousCursor = pageState.cursors[pageState.index - 1] || null
  void loadPatterns(previousCursor, 'previous')
}

async function loadPartners() {
  partnersLoading.value = true
  try {
    const response: any = await api.apiFetch('/admin/central/partners', {
      scope: 'central',
      query: { limit: 100 },
    })
    partners.value = extractItems(response)
      .map((row: any) => ({ id: String(row.id || row.partner_id || ''), name: row.name || row.code || row.id }))
      .filter((partner: PartnerOption) => partner.id)
  } finally {
    partnersLoading.value = false
  }
}

async function saveLimitSettings() {
  if (!canLoadScope.value) {
    return
  }

  savingLimits.value = true
  error.value = null

  try {
    await api.apiFetch('/admin/central/stock/limit-settings', {
      method: 'PUT',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        game_id: gameId.value,
        scope_type: scopeType.value,
        scope_id: scopeId.value,
        back2_limit: parseLimitDraft(limitDraft.back2_limit),
        back3_limit: parseLimitDraft(limitDraft.back3_limit),
        front3_limit: parseLimitDraft(limitDraft.front3_limit),
      },
    })
    reloadCurrent()
  } catch (err) {
    error.value = err
  } finally {
    savingLimits.value = false
  }
}

async function saveOverride(row: PatternRow) {
  savingKey.value = row.id
  error.value = null

  try {
    await api.apiFetch('/admin/central/stock/limit-overrides', {
      method: 'PUT',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        game_id: gameId.value,
        scope_type: scopeType.value,
        scope_id: scopeId.value,
        dimension: activeTab.value,
        overrides: [{
          value: row.number,
          limit: draftValue(row) === '' ? null : Number(draftValue(row)),
        }],
      },
    })
    reloadCurrent()
  } catch (err) {
    error.value = err
  } finally {
    savingKey.value = ''
  }
}

function resetPaging() {
  pageState.cursors = [null]
  pageState.index = 0
  meta.next_cursor = null
  meta.has_more = false
}

function resetDrafts() {
  for (const key of Object.keys(overrideDrafts)) {
    delete overrideDrafts[key]
  }
}

function syncLimitDraft() {
  const limits = report.value?.limits || {}
  limitDraft.back2_limit = limits.back2_limit === null || limits.back2_limit === undefined ? '' : String(limits.back2_limit)
  limitDraft.back3_limit = limits.back3_limit === null || limits.back3_limit === undefined ? '' : String(limits.back3_limit)
  limitDraft.front3_limit = limits.front3_limit === null || limits.front3_limit === undefined ? '' : String(limits.front3_limit)
}

function draftValue(row: PatternRow) {
  return overrideDrafts[row.number] ?? (row.override_limit === null || row.override_limit === undefined ? '' : String(row.override_limit))
}

function setDraft(row: PatternRow, event: Event) {
  overrideDrafts[row.number] = String((event.target as HTMLInputElement).value ?? '')
}

function extractItems(response: any) {
  return Array.isArray(response?.data) ? response.data : Array.isArray(response) ? response : []
}

function parseLimitDraft(value: string) {
  const normalized = String(value ?? '').trim()
  return normalized === '' ? null : Number(normalized)
}

function formatNumber(value: number | string | null | undefined) {
  return new Intl.NumberFormat('th-TH', { maximumFractionDigits: 0 }).format(Number(value || 0))
}

function formatLimit(value: number | null | undefined) {
  return value === null || value === undefined ? 'ไม่จำกัด' : formatNumber(value)
}
</script>

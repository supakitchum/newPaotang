<template>
  <div>
    <AdminPageHeader
      title="Result Entry"
      :breadcrumbs="['Admin', 'Central', 'Lottery Operations', 'Result Entry']"
    >
      <template #actions>
        <button class="btn btn-outline-primary btn-wave" type="button" :disabled="loading" @click="refreshAll">
          <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminApiState :error="error" />

    <div v-if="loading && !sessionData" class="card custom-card">
      <div class="card-body text-center py-5">
        <span class="spinner-border spinner-border-sm me-2" />
        Loading reward entry...
      </div>
    </div>

    <div v-else-if="!sessionData" class="card custom-card">
      <div class="card-body text-center py-5">
        <i class="ri-calendar-check-line fs-1 text-muted" />
        <h5 class="mt-3 mb-1">No game is waiting for reward entry</h5>
        <p class="text-muted mb-0">Reward entry opens after a game is closed and waiting for results.</p>
      </div>
    </div>

    <div v-else class="row g-3">
      <div class="col-12 col-xl-4">
        <div class="card custom-card h-100">
          <div class="card-body">
            <div class="d-flex align-items-start justify-content-between gap-3">
              <div>
                <p class="text-muted mb-1">Current game</p>
                <h5 class="mb-1">{{ sessionData.game?.name || sessionData.game?.code }}</h5>
                <div class="text-muted fs-12">{{ sessionData.game?.code }}</div>
              </div>
              <span :class="['badge', statusClass(sessionData.status)]">{{ titleize(sessionData.status) }}</span>
            </div>

            <div class="np-entry-stats mt-4">
              <div>
                <span class="text-muted">Expected officers</span>
                <strong>{{ sessionData.expected_operator_count }}</strong>
              </div>
              <div>
                <span class="text-muted">Submitted</span>
                <strong>{{ sessionData.submitted_count }}</strong>
              </div>
              <div>
                <span class="text-muted">Draw time</span>
                <strong>{{ formatDateTime(sessionData.game?.draw_at) }}</strong>
              </div>
            </div>

            <div v-if="!sessionData.expected_operator_count" class="alert alert-warning mt-4 mb-0">
              No active Result Officer was found when this session was created. Assign the role, then create a new session for the next draw.
            </div>

            <div v-if="sessionData.is_expected_operator" class="alert alert-info mt-4 mb-0">
              Submit only your own official result entry. Other officers' entries and winner data are hidden from this role.
            </div>
          </div>
        </div>
      </div>

      <div class="col-12 col-xl-8">
        <div class="card custom-card h-100">
          <div class="card-header d-flex align-items-center justify-content-between gap-3">
            <div>
              <div class="card-title mb-0">My reward entry</div>
              <div class="text-muted fs-12">Save draft first, then submit once every prize number is complete.</div>
            </div>
            <AdminStatusBadge v-if="sessionData.submission" :status="sessionData.submission.status" />
          </div>
          <div class="card-body">
            <div v-if="!sessionData.is_expected_operator" class="text-muted">
              This account is not part of the expected result-officer snapshot for this session.
            </div>

            <template v-else>
              <AdminRewardEntryGrid v-model="entryGroups" :readonly="entrySubmitted" />

              <div class="d-flex flex-wrap justify-content-end gap-2 mt-3">
                <button
                  class="btn btn-light btn-wave"
                  type="button"
                  :disabled="saving || entrySubmitted"
                  @click="saveDraft"
                >
                  <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                  Save draft
                </button>
                <button
                  class="btn btn-primary btn-wave"
                  type="button"
                  :disabled="submitting || entrySubmitted || !entryComplete"
                  @click="submitEntry"
                >
                  <span v-if="submitting" class="spinner-border spinner-border-sm me-2" />
                  Submit result
                </button>
              </div>

              <div v-if="!entryComplete && !entrySubmitted" class="text-muted fs-12 text-end mt-2">
                Complete every prize number before submitting.
              </div>
            </template>
          </div>
        </div>
      </div>

      <div v-if="entrySubmitted" class="col-12">
        <div class="card custom-card">
          <div class="card-header">
            <div class="card-title mb-0">Diff with lotto-scraper</div>
          </div>
          <div class="card-body">
            <div v-if="!submissionDiff?.summary?.has_scraper" class="alert alert-warning mb-0">
              Lotto-scraper draft is not available for this session yet.
            </div>
            <template v-else>
              <div class="d-flex flex-wrap gap-2 mb-3">
                <span class="badge bg-light text-default">Mismatches: {{ submissionDiff.summary.mismatch_count }}</span>
                <span class="badge bg-light text-default">Missing scraper rows: {{ submissionDiff.summary.missing_scraper_count }}</span>
              </div>
              <div class="table-responsive np-entry-diff-table">
                <table class="table table-sm table-hover align-middle">
                  <thead>
                    <tr>
                      <th>Prize</th>
                      <th>My entry</th>
                      <th>Lotto-scraper</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="row in submissionDiff.rows" :key="row.key">
                      <td>{{ prizeLabel(row.prize_type) }} #{{ Number(row.index) + 1 }}</td>
                      <td class="fw-semibold">{{ row.operator_number || '-' }}</td>
                      <td>{{ row.scraper_number || '-' }}</td>
                      <td>
                        <span :class="['badge', row.matches ? 'bg-success-transparent text-success' : 'bg-danger-transparent text-danger']">
                          {{ row.matches ? 'Match' : 'Mismatch' }}
                        </span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </template>
          </div>
        </div>
      </div>

      <div v-if="canResolve" class="col-12">
        <div class="card custom-card">
          <div class="card-header d-flex align-items-center justify-content-between gap-3">
            <div>
              <div class="card-title mb-0">Platform Owner queue</div>
              <div class="text-muted fs-12">Compare lotto-scraper and submitted entries, then resolve into the existing reward flow.</div>
            </div>
            <button class="btn btn-sm btn-outline-primary" type="button" :disabled="queueLoading" @click="loadOwnerQueue">
              <span v-if="queueLoading" class="spinner-border spinner-border-sm me-1" />
              Reload queue
            </button>
          </div>
          <div class="card-body">
            <div class="btn-group mb-3" role="group" aria-label="Queue filter">
              <button
                v-for="tab in ownerTabs"
                :key="tab.value"
                :class="['btn btn-sm', ownerTab === tab.value ? 'btn-primary' : 'btn-outline-primary']"
                type="button"
                @click="ownerTab = tab.value"
              >
                {{ tab.label }}
              </button>
            </div>

            <div class="table-responsive">
              <table class="table table-hover align-middle">
                <thead>
                  <tr>
                    <th>Game</th>
                    <th>Status</th>
                    <th>Progress</th>
                    <th>Ready at</th>
                    <th class="text-end">Action</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="row in filteredQueue" :key="row.id">
                    <td>
                      <div class="fw-semibold">{{ row.game?.name || row.game?.code }}</div>
                      <div class="text-muted fs-12">{{ row.game?.code }}</div>
                    </td>
                    <td><span :class="['badge', statusClass(row.status)]">{{ titleize(row.status) }}</span></td>
                    <td>{{ row.submitted_count }} / {{ row.expected_operator_count }}</td>
                    <td>{{ formatDateTime(row.ready_at) }}</td>
                    <td class="text-end">
                      <button class="btn btn-sm btn-primary-light" type="button" @click="openComparison(row)">
                        Compare
                      </button>
                    </td>
                  </tr>
                  <tr v-if="!filteredQueue.length">
                    <td colspan="5" class="text-center text-muted py-4">No sessions in this tab.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <div v-if="comparisonData" class="col-12">
        <div class="card custom-card">
          <div class="card-header d-flex align-items-center justify-content-between gap-3">
            <div>
              <div class="card-title mb-0">Owner comparison</div>
              <div class="text-muted fs-12">{{ comparisonData.session?.game?.name || comparisonData.session?.game?.code }}</div>
            </div>
            <button class="btn btn-sm btn-light" type="button" @click="comparisonData = null">
              Close
            </button>
          </div>
          <div class="card-body">
            <div class="d-flex flex-wrap gap-2 mb-3">
              <button
                v-for="source in comparisonData.sources"
                :key="source.id"
                :class="['btn btn-sm', selectedSourceId === source.id ? 'btn-primary' : 'btn-outline-primary']"
                type="button"
                @click="selectSource(source)"
              >
                {{ source.label }}
              </button>
              <button
                :class="['btn btn-sm', selectedSourceId === 'manual' ? 'btn-primary' : 'btn-outline-primary']"
                type="button"
                @click="selectManual"
              >
                Manual edit
              </button>
            </div>

            <div class="table-responsive np-entry-comparison-table mb-4">
              <table class="table table-sm table-bordered align-middle">
                <thead>
                  <tr>
                    <th>Prize</th>
                    <th v-for="source in comparisonData.sources" :key="source.id">{{ source.label }}</th>
                    <th>Match</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="row in comparisonData.matrix" :key="row.key">
                    <td>{{ prizeLabel(row.prize_type) }} #{{ Number(row.index) + 1 }}</td>
                    <td v-for="value in row.values" :key="`${row.key}:${value.source_id}`" class="fw-semibold">
                      {{ value.number || '-' }}
                    </td>
                    <td>
                      <span :class="['badge', row.all_match ? 'bg-success-transparent text-success' : 'bg-danger-transparent text-danger']">
                        {{ row.all_match ? 'Aligned' : 'Review' }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <h6 class="mb-3">Final result to send into reward flow</h6>
            <AdminRewardEntryGrid v-model="finalGroups" />

            <div class="mt-3">
              <label class="form-label">Resolve reason / audit note</label>
              <textarea v-model.trim="resolveReason" class="form-control" rows="3" placeholder="Explain why this source or manual correction is selected." />
            </div>

            <div class="d-flex justify-content-end gap-2 mt-3">
              <button class="btn btn-primary btn-wave" type="button" :disabled="resolving || !finalComplete || !resolveReason" @click="resolveEntry">
                <span v-if="resolving" class="spinner-border spinner-border-sm me-2" />
                Resolve to reward flow
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  hasCompleteRewardPrizeGroups,
  normalizeRewardPrizeGroups,
  rewardPrizeGroupsToPayload,
  rewardPrizeLabel,
} from '~/composables/useRewardPrizes'

definePageMeta({ layout: 'admin' })

type RewardEntrySession = Record<string, any>
type RewardEntrySource = Record<string, any>

const api = useAdminApi()
const session = useAdminSession()
const route = useRoute()

const loading = ref(false)
const queueLoading = ref(false)
const saving = ref(false)
const submitting = ref(false)
const resolving = ref(false)
const error = ref<any>(null)
const sessionData = ref<RewardEntrySession | null>(null)
const entryGroups = ref(normalizeRewardPrizeGroups([]))
const ownerQueue = ref<RewardEntrySession[]>([])
const ownerTab = ref('ready_for_owner')
const comparisonData = ref<any | null>(null)
const finalGroups = ref(normalizeRewardPrizeGroups([]))
const selectedSourceId = ref<string | null>(null)
const selectedSourceType = ref('manual')
const selectedSubmissionId = ref<string | null>(null)
const resolveReason = ref('')

const canResolve = computed(() => session.currentPermissions.value.includes('reward_entry.resolve'))
const entrySubmitted = computed(() => sessionData.value?.submission?.status === 'submitted')
const submissionDiff = computed(() => sessionData.value?.submission?.diff_to_scraper || null)
const entryComplete = computed(() => hasCompleteRewardPrizeGroups(entryGroups.value))
const finalComplete = computed(() => hasCompleteRewardPrizeGroups(finalGroups.value))
const ownerTabs = [
  { value: 'ready_for_owner', label: 'Ready for Owner' },
  { value: 'collecting', label: 'Collecting' },
  { value: 'resolved', label: 'Resolved' },
]
const filteredQueue = computed(() => ownerQueue.value.filter((row) => row.status === ownerTab.value))

const refreshAll = async () => {
  await loadCurrent()
  if (canResolve.value) {
    await loadOwnerQueue()
  }
}

const loadCurrent = async () => {
  loading.value = true
  error.value = null
  try {
    const response: any = await api.apiFetch('/admin/central/reward-entry/sessions/current', {
      scope: 'central',
      query: typeof route.query.game_id === 'string' ? { game_id: route.query.game_id } : {},
    })
    sessionData.value = response?.data || null
    const prizes = sessionData.value?.submission?.prizes || response?.meta?.template_prizes || []
    entryGroups.value = normalizeRewardPrizeGroups(prizes)
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const loadOwnerQueue = async () => {
  if (!canResolve.value) return
  queueLoading.value = true
  try {
    const response: any = await api.apiFetch('/admin/central/reward-entry/owner-queue', { scope: 'central' })
    ownerQueue.value = Array.isArray(response?.data) ? response.data : []
  } catch (err) {
    error.value = err
  } finally {
    queueLoading.value = false
  }
}

const saveDraft = async () => {
  if (!sessionData.value?.id) return
  saving.value = true
  error.value = null
  try {
    const response: any = await api.apiFetch(`/admin/central/reward-entry/sessions/${sessionData.value.id}/submission`, {
      method: 'PUT',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: { prizes: rewardPrizeGroupsToPayload(entryGroups.value) },
    })
    sessionData.value = response || sessionData.value
    entryGroups.value = normalizeRewardPrizeGroups(sessionData.value?.submission?.prizes || [])
  } catch (err) {
    error.value = err
  } finally {
    saving.value = false
  }
}

const submitEntry = async () => {
  if (!sessionData.value?.id || !entryComplete.value) return
  submitting.value = true
  error.value = null
  try {
    const response: any = await api.apiFetch(`/admin/central/reward-entry/sessions/${sessionData.value.id}/submit`, {
      method: 'POST',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: { prizes: rewardPrizeGroupsToPayload(entryGroups.value) },
    })
    sessionData.value = response || sessionData.value
    entryGroups.value = normalizeRewardPrizeGroups(sessionData.value?.submission?.prizes || [])
    await loadOwnerQueue()
  } catch (err) {
    error.value = err
  } finally {
    submitting.value = false
  }
}

const openComparison = async (row: RewardEntrySession) => {
  error.value = null
  try {
    const response: any = await api.apiFetch(`/admin/central/reward-entry/sessions/${row.id}/comparison`, { scope: 'central' })
    comparisonData.value = response?.data || null
    const firstSource = comparisonData.value?.sources?.[0]
    if (firstSource) {
      selectSource(firstSource)
    } else {
      selectManual()
    }
  } catch (err) {
    error.value = err
  }
}

const selectSource = (source: RewardEntrySource) => {
  selectedSourceId.value = source.id
  selectedSourceType.value = source.source_type
  selectedSubmissionId.value = source.source_type === 'submission' ? source.id : null
  finalGroups.value = normalizeRewardPrizeGroups(source.prizes || [])
}

const selectManual = () => {
  selectedSourceId.value = 'manual'
  selectedSourceType.value = 'manual'
  selectedSubmissionId.value = null
  if (!finalGroups.value.length) {
    finalGroups.value = normalizeRewardPrizeGroups([])
  }
}

const resolveEntry = async () => {
  if (!comparisonData.value?.session?.id || !finalComplete.value || !resolveReason.value) return
  resolving.value = true
  error.value = null
  try {
    await api.apiFetch(`/admin/central/reward-entry/sessions/${comparisonData.value.session.id}/resolve`, {
      method: 'POST',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        selected_source_type: selectedSourceType.value,
        selected_submission_id: selectedSubmissionId.value,
        final_prizes: rewardPrizeGroupsToPayload(finalGroups.value),
        reason: resolveReason.value,
      },
    })
    comparisonData.value = null
    resolveReason.value = ''
    await refreshAll()
    ownerTab.value = 'resolved'
  } catch (err) {
    error.value = err
  } finally {
    resolving.value = false
  }
}

const prizeLabel = (type: string) => rewardPrizeLabel(type)
const titleize = (value: unknown) => String(value || '').replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase())
const statusClass = (status: string) => {
  if (status === 'ready_for_owner') return 'bg-warning-transparent text-warning'
  if (status === 'resolved') return 'bg-success-transparent text-success'
  if (status === 'cancelled') return 'bg-danger-transparent text-danger'
  return 'bg-info-transparent text-info'
}
const formatDateTime = (value: unknown) => {
  if (!value) return '-'
  const date = new Date(String(value))
  if (Number.isNaN(date.getTime())) return '-'
  return new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Bangkok',
  }).format(date)
}

onMounted(refreshAll)
</script>

<style scoped>
.np-entry-stats {
  display: grid;
  gap: 0.75rem;
}

.np-entry-stats > div {
  align-items: center;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  display: flex;
  justify-content: space-between;
  padding-bottom: 0.75rem;
}

.np-entry-diff-table,
.np-entry-comparison-table {
  max-height: 520px;
  overflow: auto;
}
</style>

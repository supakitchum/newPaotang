<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-start justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Stock settings</div>
        <p class="text-muted fs-12 mb-0">Base values for Generate Stock and Stock Pattern Coverage forms.</p>
      </div>
      <button class="btn btn-sm btn-light btn-wave" type="button" :disabled="loading" @click="loadSettings">
        <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
        <i v-else class="ri-refresh-line me-1" />
        Refresh
      </button>
    </div>
    <div class="card-body">
      <AdminApiState :error="error" />
      <AdminLoader v-if="loading && !loaded" />
      <template v-else>
        <div v-if="savedAt" class="alert alert-success d-flex align-items-start gap-2">
          <i class="ri-checkbox-circle-line fs-18" />
          <div>Saved stock settings at {{ savedAt }}.</div>
        </div>

        <section class="np-stock-coverage-settings__panel mb-3">
          <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
            <div>
              <h6 class="mb-1">Default set distribution</h6>
              <p class="text-muted fs-12 mb-0">Default value loaded into the Generate Stock form.</p>
            </div>
            <button class="btn btn-sm btn-outline-primary btn-wave" type="button" @click="addSetDistributionRow">
              <i class="ri-add-line me-1" /> Add set
            </button>
          </div>

          <div class="np-stock-set-table">
            <div class="np-stock-set-table__head">
              <span>Set size</span>
              <span>Percent</span>
              <span />
            </div>
            <div v-for="(row, index) in setDistribution" :key="row.__key || index" class="np-stock-set-table__row">
              <input
                v-model.number="row.set_size"
                class="form-control"
                :class="{ 'is-invalid': setDistributionMessages(index, 'set_size').length }"
                type="number"
                min="1"
                max="99"
                step="1"
                placeholder="2"
              >
              <div class="input-group">
                <input
                  v-model.number="row.percent"
                  class="form-control"
                  :class="{ 'is-invalid': setDistributionMessages(index, 'percent').length }"
                  type="number"
                  min="0"
                  max="100"
                  step="0.01"
                  placeholder="10"
                >
                <span class="input-group-text">%</span>
              </div>
              <button class="btn btn-light btn-icon" type="button" title="Remove set" @click="removeSetDistributionRow(index)">
                <i class="ri-delete-bin-line" />
              </button>
              <div class="np-stock-set-table__messages">
                <div v-for="message in setDistributionMessages(index, 'set_size')" :key="`size-${message}`" class="invalid-feedback d-block">
                  {{ message }}
                </div>
                <div v-for="message in setDistributionMessages(index, 'percent')" :key="`percent-${message}`" class="invalid-feedback d-block">
                  {{ message }}
                </div>
              </div>
            </div>
          </div>
          <div v-for="message in setDistributionSummaryMessages" :key="message" class="text-danger fs-12 mt-2">
            {{ message }}
          </div>
        </section>

        <div class="row g-3">
          <div class="col-12 col-xl-6">
            <section class="np-stock-coverage-settings__panel">
              <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
                <h6 class="mb-0">Central coverage default</h6>
                <span class="badge bg-primary-transparent text-primary">Central ceiling</span>
              </div>
              <div class="row g-3">
                <div v-for="field in coverageFields" :key="`central-${field.key}`" class="col-md-4">
                  <label class="form-label" :for="fieldId(`central-${field.key}`)">{{ field.label }}</label>
                  <input
                    :id="fieldId(`central-${field.key}`)"
                    v-model="form.central[field.key]"
                    class="form-control"
                    :class="{ 'is-invalid': fieldMessages('central', field.key).length }"
                    type="number"
                    min="0"
                    step="1"
                  >
                  <div v-for="message in fieldMessages('central', field.key)" :key="message" class="invalid-feedback d-block">
                    {{ message }}
                  </div>
                </div>
              </div>
            </section>
          </div>

          <div class="col-12 col-xl-6">
            <section class="np-stock-coverage-settings__panel">
              <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
                <h6 class="mb-0">Partner coverage default</h6>
                <span class="badge bg-info-transparent text-info">Must not exceed central</span>
              </div>
              <div class="row g-3">
                <div v-for="field in coverageFields" :key="`partner-${field.key}`" class="col-md-4">
                  <label class="form-label" :for="fieldId(`partner-${field.key}`)">{{ field.label }}</label>
                  <div class="input-group">
                    <input
                      :id="fieldId(`partner-${field.key}`)"
                      v-model="form.partner[field.key]"
                      class="form-control"
                      :class="{ 'is-invalid': fieldMessages('partner', field.key).length }"
                      type="number"
                      min="0"
                      step="1"
                      :max="centralNumber(field.key)"
                    >
                    <span class="input-group-text">Max {{ formatNumber(centralNumber(field.key)) }}</span>
                  </div>
                  <div v-for="message in fieldMessages('partner', field.key)" :key="message" class="invalid-feedback d-block">
                    {{ message }}
                  </div>
                </div>
              </div>
            </section>
          </div>
        </div>
      </template>
    </div>
    <div class="card-footer d-flex flex-wrap justify-content-end gap-2">
      <button class="btn btn-light btn-wave" type="button" :disabled="loading || saving" @click="resetForm">Reset</button>
      <button class="btn btn-primary btn-wave" type="button" :disabled="saving || Boolean(clientMessages.length) || Boolean(setDistributionSummaryMessages.length)" @click="saveSettings">
        <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
        Save defaults
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
const emit = defineEmits<{
  saved: [record: Record<string, any>]
}>()

const api = useAdminApi()
const session = useAdminSession()
const loading = ref(false)
const saving = ref(false)
const loaded = ref(false)
const error = ref<any>(null)
const savedAt = ref('')
const detail = ref<Record<string, any> | null>(null)
const setDistribution = ref<Array<Record<string, any>>>([])
const form = reactive<Record<'central' | 'partner', Record<string, any>>>({
  central: { back2_limit: '', back3_limit: '', front3_limit: '' },
  partner: { back2_limit: '', back3_limit: '', front3_limit: '' },
})
const coverageFields = [
  { key: 'back2_limit', label: 'Back 2' },
  { key: 'back3_limit', label: 'Back 3' },
  { key: 'front3_limit', label: 'Front 3' },
] as const
const defaultCoverage = () => ({
  central: { back2_limit: 500, back3_limit: 300, front3_limit: 200 },
  partner: { back2_limit: 200, back3_limit: 100, front3_limit: 80 },
})
const defaultSetDistribution = () => [
  { __key: setDistributionRowKey(2, 10), set_size: 2, percent: 10 },
  { __key: setDistributionRowKey(3, 15), set_size: 3, percent: 15 },
]

const clientMessages = computed(() => {
  const messages: string[] = []
  for (const field of coverageFields) {
    const partner = numberFromInput(form.partner[field.key])
    const central = numberFromInput(form.central[field.key])
    if (partner !== null && central !== null && partner > central) {
      messages.push(`Partner ${field.label} may not exceed central ${formatNumber(central)}.`)
    }
  }
  return messages
})
const setDistributionSummaryMessages = computed(() => {
  const totalPercent = setDistribution.value.reduce((sum, row) => sum + (decimalFromInput(row.percent) ?? 0), 0)
  const messages: string[] = []

  if (!setDistribution.value.length) {
    messages.push('At least one set distribution row is required.')
  }
  if (totalPercent > 100) {
    messages.push('Set distribution percent total must not exceed 100%.')
  }

  return messages
})

onMounted(() => {
  void loadSettings()
})

async function loadSettings() {
  if (!session.isAuthenticated.value) {
    return
  }

  loading.value = true
  error.value = null
  try {
    const response = await api.apiFetch('/admin/central/stock/settings', { scope: 'central' })
    detail.value = extractData(response)
    resetForm()
    loaded.value = true
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

function resetForm() {
  setDistribution.value = extractSetDistribution(detail.value)
  const coverage = extractCoverage(detail.value)
  for (const field of coverageFields) {
    form.central[field.key] = coverage.central[field.key]
    form.partner[field.key] = coverage.partner[field.key]
  }
  savedAt.value = ''
}

async function saveSettings() {
  if (clientMessages.value.length || setDistributionSummaryMessages.value.length) {
    error.value = {
      status: 422,
      message: 'The request payload is invalid.',
      details: { fields: { partner: clientMessages.value, set_distribution: setDistributionSummaryMessages.value } },
    }
    return
  }

  saving.value = true
  error.value = null
  savedAt.value = ''
  try {
    const payload = {
      settings: {
        stock_set_distribution_default: normalizeSetDistributionForPayload(),
        stock_pattern_coverage_default: normalizeCoverageForPayload(),
      },
    }
    const response = await api.apiFetch('/admin/central/stock/settings', {
      scope: 'central',
      method: 'PATCH',
      body: payload,
      idempotencyKey: api.idempotencyKey(),
    })
    detail.value = extractData(response)
    resetForm()
    savedAt.value = new Intl.DateTimeFormat('th-TH', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date())
    emit('saved', detail.value || {})
  } catch (err) {
    error.value = err
  } finally {
    saving.value = false
  }
}

function extractSetDistribution(source: any) {
  const distribution = source?.settings?.stock_set_distribution_default
    || source?.stock_set_distribution_default
    || defaultSetDistribution()

  return normalizeSetDistribution(distribution)
}

function extractCoverage(source: any) {
  const coverage = source?.settings?.stock_pattern_coverage_default
    || source?.stock_pattern_coverage_default
    || defaultCoverage()
  const defaults = defaultCoverage()

  return {
    central: {
      back2_limit: numericOrDefault(coverage?.central?.back2_limit, defaults.central.back2_limit),
      back3_limit: numericOrDefault(coverage?.central?.back3_limit, defaults.central.back3_limit),
      front3_limit: numericOrDefault(coverage?.central?.front3_limit, defaults.central.front3_limit),
    },
    partner: {
      back2_limit: numericOrDefault(coverage?.partner?.back2_limit, defaults.partner.back2_limit),
      back3_limit: numericOrDefault(coverage?.partner?.back3_limit, defaults.partner.back3_limit),
      front3_limit: numericOrDefault(coverage?.partner?.front3_limit, defaults.partner.front3_limit),
    },
  }
}

function normalizeSetDistributionForPayload() {
  return normalizeSetDistribution(setDistribution.value)
    .map((row) => ({
      set_size: numberFromInput(row.set_size) ?? 1,
      percent: decimalFromInput(row.percent) ?? 0,
    }))
}

function normalizeCoverageForPayload() {
  return {
    central: {
      back2_limit: numberFromInput(form.central.back2_limit) ?? 0,
      back3_limit: numberFromInput(form.central.back3_limit) ?? 0,
      front3_limit: numberFromInput(form.central.front3_limit) ?? 0,
    },
    partner: {
      back2_limit: numberFromInput(form.partner.back2_limit) ?? 0,
      back3_limit: numberFromInput(form.partner.back3_limit) ?? 0,
      front3_limit: numberFromInput(form.partner.front3_limit) ?? 0,
    },
  }
}

function addSetDistributionRow() {
  setDistribution.value = [
    ...setDistribution.value,
    { __key: setDistributionRowKey(2, 0), set_size: 2, percent: '' },
  ]
}

function removeSetDistributionRow(index: number) {
  const rows = [...setDistribution.value]
  rows.splice(index, 1)
  setDistribution.value = rows.length ? rows : [{ __key: setDistributionRowKey(2, 0), set_size: 2, percent: '' }]
}

function setDistributionMessages(index: number, key: 'set_size' | 'percent') {
  const row = setDistribution.value[index] || {}
  const messages: string[] = []

  if (key === 'set_size') {
    const setSize = numberFromInput(row.set_size)
    if (setSize === null || setSize < 1 || setSize > 99) {
      messages.push('Set size must be between 1 and 99.')
    }
  }

  if (key === 'percent') {
    const percent = decimalFromInput(row.percent)
    if (percent === null || percent < 0 || percent > 100) {
      messages.push('Percent must be between 0 and 100.')
    }
  }

  return [...messages, ...backendSetDistributionMessages(index, key)]
}

function fieldMessages(scope: 'central' | 'partner', key: string) {
  const messages = [...clientFieldMessages(scope, key), ...backendFieldMessages(scope, key)]
  return [...new Set(messages)]
}

function clientFieldMessages(scope: 'central' | 'partner', key: string) {
  if (scope !== 'partner') {
    return []
  }

  const partner = numberFromInput(form.partner[key])
  const central = numberFromInput(form.central[key])
  if (partner !== null && central !== null && partner > central) {
    return [`Partner value may not exceed central ${formatNumber(central)}.`]
  }

  return []
}

function backendFieldMessages(scope: 'central' | 'partner', key: string) {
  const fields = error.value?.details?.fields
  if (!fields || typeof fields !== 'object') {
    return []
  }

  const aliases = [
    `stock_pattern_coverage_default.${scope}.${key}`,
    `settings.stock_pattern_coverage_default.${scope}.${key}`,
    `${scope}.${key}`,
    key,
  ]

  return aliases.flatMap((alias) => {
    const value = fields[alias]
    if (Array.isArray(value)) return value.map(String)
    return value ? [String(value)] : []
  })
}

function backendSetDistributionMessages(index: number, key: 'set_size' | 'percent') {
  const fields = error.value?.details?.fields
  if (!fields || typeof fields !== 'object') {
    return []
  }

  const aliases = [
    `stock_set_distribution_default.${index}.${key}`,
    `settings.stock_set_distribution_default.${index}.${key}`,
    `set_distribution.${index}.${key}`,
  ]

  return aliases.flatMap((alias) => {
    const value = fields[alias]
    if (Array.isArray(value)) return value.map(String)
    return value ? [String(value)] : []
  })
}

function centralNumber(key: string) {
  return numberFromInput(form.central[key]) ?? 0
}

function normalizeSetDistribution(value: any) {
  const rows = Array.isArray(value) ? value : []
  const normalized = rows
    .map((row, index) => ({
      __key: row?.__key || setDistributionRowKey(row?.set_size ?? index + 2, row?.percent ?? 0),
      set_size: numberFromInput(row?.set_size) ?? 1,
      percent: decimalFromInput(row?.percent) ?? 0,
    }))
    .filter((row) => row.set_size >= 1 && row.percent >= 0)

  return normalized.length ? normalized : defaultSetDistribution()
}

function numberFromInput(value: any) {
  if (value === '' || value === undefined || value === null) {
    return null
  }
  const parsed = Number(value)
  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : null
}

function decimalFromInput(value: any) {
  if (value === '' || value === undefined || value === null) {
    return null
  }
  const parsed = Number(value)
  return Number.isFinite(parsed) ? Math.max(0, parsed) : null
}

function numericOrDefault(value: any, fallback: number) {
  const parsed = numberFromInput(value)
  return parsed === null ? fallback : parsed
}

function formatNumber(value: any) {
  const parsed = numberFromInput(value)
  return parsed === null ? '-' : new Intl.NumberFormat('th-TH', { maximumFractionDigits: 0 }).format(parsed)
}

function extractData(response: any) {
  return response?.data ?? response
}

function fieldId(key: string) {
  return `stock-settings-${key.replace(/[^a-z0-9_-]/gi, '-')}`
}

function setDistributionRowKey(setSize: any, percent: any) {
  return `set-${String(setSize || 'new')}-${String(percent || 0)}-${Math.random().toString(36).slice(2)}`
}
</script>

<style scoped>
.np-stock-coverage-settings__panel {
  background: var(--custom-white);
  border: 1px solid var(--default-border);
  border-radius: 6px;
  padding: 1rem;
}

.np-stock-set-table {
  display: grid;
  gap: .75rem;
}

.np-stock-set-table__head,
.np-stock-set-table__row {
  align-items: start;
  display: grid;
  gap: .75rem;
  grid-template-columns: minmax(7rem, 10rem) minmax(9rem, 14rem) 2.5rem;
}

.np-stock-set-table__head {
  color: var(--text-muted);
  font-size: .75rem;
  font-weight: 600;
}

.np-stock-set-table__messages {
  grid-column: 1 / -1;
}

@media (max-width: 575.98px) {
  .np-stock-set-table__head {
    display: none;
  }

  .np-stock-set-table__row {
    grid-template-columns: 1fr;
  }
}
</style>

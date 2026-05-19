<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-start justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Stock pattern coverage defaults</div>
        <p class="text-muted fs-12 mb-0">Base values for new central and partner Stock Pattern Coverage forms.</p>
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
          <div>Saved coverage defaults at {{ savedAt }}.</div>
        </div>

        <div class="row g-3">
          <div class="col-12 col-xl-6">
            <section class="np-stock-coverage-settings__panel">
              <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
                <h6 class="mb-0">Central default</h6>
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
                <h6 class="mb-0">Partner default</h6>
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
      <button class="btn btn-primary btn-wave" type="button" :disabled="saving || Boolean(clientMessages.length)" @click="saveSettings">
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
  const coverage = extractCoverage(detail.value)
  for (const field of coverageFields) {
    form.central[field.key] = coverage.central[field.key]
    form.partner[field.key] = coverage.partner[field.key]
  }
  savedAt.value = ''
}

async function saveSettings() {
  if (clientMessages.value.length) {
    error.value = {
      status: 422,
      message: 'The request payload is invalid.',
      details: { fields: { partner: clientMessages.value } },
    }
    return
  }

  saving.value = true
  error.value = null
  savedAt.value = ''
  try {
    const payload = {
      settings: {
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

function centralNumber(key: string) {
  return numberFromInput(form.central[key]) ?? 0
}

function numberFromInput(value: any) {
  if (value === '' || value === undefined || value === null) {
    return null
  }
  const parsed = Number(value)
  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : null
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
  return `stock-coverage-settings-${key.replace(/[^a-z0-9_-]/gi, '-')}`
}
</script>

<style scoped>
.np-stock-coverage-settings__panel {
  background: var(--custom-white);
  border: 1px solid var(--default-border);
  border-radius: 6px;
  padding: 1rem;
}
</style>

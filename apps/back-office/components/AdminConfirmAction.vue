<template>
  <AdminModal :model-value="modelValue" :title="title" @update:model-value="emit('update:modelValue', $event)">
    <AdminApiState :error="error" />
    <p class="text-muted mb-3">{{ message }}</p>

    <div v-if="contextItems.length" class="border rounded-2 bg-light p-3 mb-3">
      <dl class="row small mb-0">
        <template v-for="item in contextItems" :key="item.key">
          <dt class="col-sm-4 text-muted">{{ item.label }}</dt>
          <dd class="col-sm-8 mb-2 font-monospace text-break">{{ item.value }}</dd>
        </template>
      </dl>
    </div>

    <div v-if="visibleFormFields.length" class="row g-3 mb-3">
      <div v-for="field in visibleFormFields" :key="field.key" :class="fieldColumnClass(field)">
        <div v-if="field.type === 'checkbox'" class="form-check form-switch mt-4">
          <input :id="fieldId(field.key)" v-model="formState[field.key]" class="form-check-input" type="checkbox">
          <label class="form-check-label" :for="fieldId(field.key)">{{ field.label }}</label>
          <div v-if="field.help" class="form-text">{{ field.help }}</div>
        </div>
        <template v-else>
          <label class="form-label" :for="fieldId(field.key)">
            {{ field.label }}
            <span v-if="field.required" class="text-danger">*</span>
          </label>
          <select
            v-if="field.type === 'select'"
            :id="fieldId(field.key)"
            v-model="formState[field.key]"
            class="form-select"
            :class="{ 'is-invalid': fieldValidationMessages(field).length }"
            :disabled="fieldDisabled(field)"
          >
            <option v-if="!field.hideEmptyOption" value="">{{ field.emptyOptionLabel || translateReportText('Select', locale) }}</option>
            <option v-else-if="!visibleOptions(field).length" value="" disabled>{{ field.emptyOptionLabel || translateReportText('No options available', locale) }}</option>
            <option
              v-for="option in visibleOptions(field)"
              :key="optionValue(option)"
              :value="optionValue(option)"
              :disabled="optionDisabled(option)"
            >
              {{ optionLabel(option) }}
            </option>
          </select>
          <div
            v-else-if="field.type === 'checkbox-group'"
            class="np-checkbox-group"
            :class="{ 'is-invalid': fieldValidationMessages(field).length }"
          >
            <div v-if="!visibleOptions(field).length" class="text-muted small">
              {{ field.emptyOptionLabel || translateReportText('No options available', locale) }}
            </div>
            <div v-else class="np-checkbox-grid">
              <label
                v-for="option in visibleOptions(field)"
                :key="optionValue(option)"
                class="form-check np-checkbox-option"
                :class="{ 'text-muted': fieldDisabled(field) || optionDisabled(option) }"
              >
                <input
                  v-model="formState[field.key]"
                  class="form-check-input"
                  type="checkbox"
                  :value="optionValue(option)"
                  :disabled="fieldDisabled(field) || optionDisabled(option)"
                >
                <span class="form-check-label">{{ optionLabel(option) }}</span>
              </label>
            </div>
          </div>
          <div v-else-if="field.type === 'datetime-range'" class="np-admin-datetime-range">
            <div class="row g-2">
              <div class="col-md-6">
                <label class="form-label text-muted small" :for="fieldId(`${field.key}-start`)">{{ field.rangeStartLabel || 'Start' }}</label>
                <input
                  :id="fieldId(`${field.key}-start`)"
                  v-model="formState[rangeStartFormKey(field)]"
                  class="form-control"
                  type="datetime-local"
                >
              </div>
              <div class="col-md-6">
                <label class="form-label text-muted small" :for="fieldId(`${field.key}-end`)">{{ field.rangeEndLabel || 'End' }}</label>
                <input
                  :id="fieldId(`${field.key}-end`)"
                  v-model="formState[rangeEndFormKey(field)]"
                  class="form-control"
                  type="datetime-local"
                >
              </div>
            </div>
          </div>
          <div v-else-if="isRewardPrizeField(field)" class="np-reward-prize-editor">
            <section v-for="group in formState[field.key]" :key="group.type" class="np-reward-prize-editor__group">
              <div class="d-flex flex-wrap align-items-end justify-content-between gap-3 mb-3">
                <div>
                  <h6 class="mb-1">{{ group.label }}</h6>
                  <div class="text-muted small">{{ group.count }} rows · {{ group.digits }} digits</div>
                </div>
                <span v-if="field.type === 'reward-prize-number-grid'" class="badge bg-primary-transparent text-primary">
                  {{ formatRewardPrizeAmount(group.amount, group.currency) }}
                </span>
                <div v-else class="np-reward-prize-editor__amount">
                  <label class="form-label text-muted small" :for="fieldId(`${field.key}-${group.type}-amount`)">Amount per prize</label>
                  <div class="input-group">
                    <input
                      :id="fieldId(`${field.key}-${group.type}-amount`)"
                      v-model.number="group.amount"
                      class="form-control"
                      type="number"
                      min="0"
                      :step="field.type === 'reward-prize-amount-grid' ? 0.01 : 1"
                    >
                    <span class="input-group-text">{{ group.currency }}</span>
                  </div>
                </div>
              </div>
              <div v-if="field.type !== 'reward-prize-amount-grid'" class="np-reward-prize-editor__numbers">
                <div v-for="(_, index) in group.numbers" :key="`${group.type}-${index}`">
                  <label class="form-label text-muted small" :for="fieldId(`${field.key}-${group.type}-${index}`)">#{{ index + 1 }}</label>
                  <input
                    :id="fieldId(`${field.key}-${group.type}-${index}`)"
                    v-model="group.numbers[index]"
                    class="form-control"
                    :maxlength="Math.max(group.digits, 32)"
                    inputmode="numeric"
                  >
                </div>
              </div>
            </section>
          </div>
          <div v-else-if="field.type === 'stock-set-distribution'" class="np-stock-config-panel">
            <div class="np-stock-set-table">
              <div class="np-stock-set-table__head">
                <span>Set size</span>
                <span>Percent</span>
                <span></span>
              </div>
              <div v-for="(row, index) in formState[field.key]" :key="row.__key || index" class="np-stock-set-table__row">
                <input
                  v-model.number="row.set_size"
                  class="form-control"
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
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    placeholder="10"
                  >
                  <span class="input-group-text">%</span>
                </div>
                <button class="btn btn-light btn-icon" type="button" title="Remove set" @click="removeStockSetDistributionRow(field, index)">
                  <i class="ri-delete-bin-line" />
                </button>
              </div>
            </div>
            <button class="btn btn-outline-primary btn-sm btn-wave mt-3" type="button" @click="addStockSetDistributionRow(field)">
              <i class="ri-add-line me-1" /> Add set
            </button>
          </div>
          <div v-else-if="field.type === 'stock-sale-limits'" class="np-stock-config-panel">
            <div class="np-stock-config-grid">
              <div>
                <label class="form-label text-muted small" :for="fieldId(`${field.key}-back2`)">2 เลขท้าย</label>
                <input :id="fieldId(`${field.key}-back2`)" v-model.number="formState[field.key].back2_limit" class="form-control" type="number" min="0" step="1">
              </div>
              <div>
                <label class="form-label text-muted small" :for="fieldId(`${field.key}-back3`)">3 เลขท้าย</label>
                <input :id="fieldId(`${field.key}-back3`)" v-model.number="formState[field.key].back3_limit" class="form-control" type="number" min="0" step="1">
              </div>
              <div>
                <label class="form-label text-muted small" :for="fieldId(`${field.key}-front3`)">3 เลขหน้า</label>
                <input :id="fieldId(`${field.key}-front3`)" v-model.number="formState[field.key].front3_limit" class="form-control" type="number" min="0" step="1">
              </div>
            </div>
          </div>
          <div v-else-if="field.type === 'stock-partner-distribution'" class="np-stock-config-panel">
            <AdminEmptyState v-if="!(formState[field.key] || []).length" title="No partners" message="Create or load partners before setting partner distribution." icon="ri-store-2-line" />
            <div v-else class="np-stock-partner-table">
              <div class="np-stock-partner-table__head">
                <span>Partner</span>
                <span>Distribution %</span>
              </div>
              <div v-for="row in formState[field.key]" :key="row.partner_id" class="np-stock-partner-table__row">
                <div class="text-truncate">{{ row.label }}</div>
                <input v-model.number="row.percent" class="form-control" type="number" min="0" max="100" step="0.01">
              </div>
            </div>
          </div>
          <div v-else-if="field.type === 'stock-partner-limits'" class="np-stock-config-panel">
            <AdminEmptyState v-if="!(formState[field.key] || []).length" title="No partners" message="Create or load partners before setting partner limits." icon="ri-store-2-line" />
            <div v-else class="np-stock-partner-table np-stock-partner-table--limits">
              <div class="np-stock-partner-table__head">
                <span>Partner</span>
                <span>2 ท้าย</span>
                <span>3 ท้าย</span>
                <span>3 หน้า</span>
              </div>
              <div v-for="row in formState[field.key]" :key="row.partner_id" class="np-stock-partner-table__row">
                <div class="text-truncate">{{ row.label }}</div>
                <input v-model.number="row.back2_limit" class="form-control" type="number" min="0" step="1">
                <input v-model.number="row.back3_limit" class="form-control" type="number" min="0" step="1">
                <input v-model.number="row.front3_limit" class="form-control" type="number" min="0" step="1">
              </div>
            </div>
          </div>
          <div v-else-if="field.type === 'allocation-partner-percent-list'" class="np-stock-config-panel">
            <AdminEmptyState v-if="!(formState[field.key] || []).length" title="No available partners" message="Every active partner is already opened, has no active store, or no latest open game is selected." icon="ri-store-2-line" />
            <template v-else>
              <div class="np-allocation-bulk-summary" :class="{ 'is-over': bulkAllocationOverLimit }">
                <div>
                  <span class="text-muted fs-12">Existing active allocation</span>
                  <strong>{{ formatNumber(bulkAllocationExistingPercent) }}%</strong>
                </div>
                <div>
                  <span class="text-muted fs-12">New partner total</span>
                  <strong>{{ formatNumber(bulkAllocationNewPercentTotal) }}%</strong>
                </div>
                <div>
                  <span class="text-muted fs-12">{{ bulkAllocationRemainingPercent < 0 ? 'Over limit' : 'Remaining' }}</span>
                  <strong>{{ formatNumber(Math.abs(bulkAllocationRemainingPercent)) }}%</strong>
                </div>
              </div>
              <div class="np-stock-partner-table np-allocation-partner-table">
                <div class="np-stock-partner-table__head">
                  <span>Partner</span>
                  <span>Allocation %</span>
                  <span>Status</span>
                </div>
                <div v-for="row in formState[field.key]" :key="row.partner_id" class="np-stock-partner-table__row">
                  <div class="text-truncate">
                    <strong>{{ row.label }}</strong>
                    <div v-if="row.tenant_label" class="text-muted fs-12 text-truncate">{{ row.tenant_label }}</div>
                  </div>
                  <div class="input-group">
                    <input v-model.number="row.allocation_percent" class="form-control" type="number" min="0" max="100" step="0.01" :disabled="row.disabled">
                    <span class="input-group-text">%</span>
                  </div>
                  <span class="badge" :class="row.disabled ? 'bg-light text-muted' : 'bg-primary-transparent text-primary'">
                    {{ row.disabled_reason || 'Ready' }}
                  </span>
                </div>
              </div>
            </template>
          </div>
          <textarea
            v-else-if="field.type === 'textarea' || field.type === 'json' || field.type === 'lines' || field.type === 'prize-lines'"
            :id="fieldId(field.key)"
            v-model="formState[field.key]"
            class="form-control"
            rows="4"
            :placeholder="field.placeholder"
          />
          <input
            v-else
            :id="fieldId(field.key)"
            v-model="formState[field.key]"
            class="form-control"
            :class="{ 'is-invalid': fieldValidationMessages(field).length }"
            :type="inputType(field)"
            :min="field.min"
            :max="field.max"
            :step="field.step"
            :placeholder="field.placeholder"
            :disabled="fieldDisabled(field)"
            @input="handleFieldInput(field, $event)"
          >
          <div v-if="field.help" class="form-text">{{ field.help }}</div>
          <div v-for="message in fieldValidationMessages(field)" :key="message" class="invalid-feedback d-block">
            {{ message }}
          </div>
        </template>
      </div>
    </div>

    <div v-if="allocationPreviewMetrics.length" class="alert alert-primary bg-primary-transparent border-primary-subtle mb-3">
      <div class="d-flex align-items-center gap-2 mb-2">
        <i class="ri-pie-chart-2-line" />
        <span class="fw-semibold">Allocation preview</span>
      </div>
      <div class="np-allocation-preview">
        <div v-for="metric in allocationPreviewMetrics" :key="metric.key">
          <span class="text-muted fs-12">{{ metric.label }}</span>
          <strong>{{ metric.value }}</strong>
        </div>
      </div>
    </div>

    <label v-if="requiresPayload" class="form-label">Payload JSON</label>
    <textarea v-if="requiresPayload" v-model="payloadJson" class="form-control np-admin-json-editor mb-3" rows="8" spellcheck="false" />
    <label v-if="requiresReason" class="form-label">
      Reason
      <span v-if="optionalReason" class="text-muted fw-normal">(optional)</span>
    </label>
    <textarea v-if="requiresReason" v-model="reason" class="form-control" rows="3" />
    <AdminApiState :error="allocationOptionError" />
    <div v-if="allocationOptionLoading" class="np-confirm-progress mb-3">
      <div class="d-flex align-items-center justify-content-between gap-3 small mb-2">
        <span class="fw-semibold">Preparing available partner tenants</span>
        <span class="text-muted">Please wait</span>
      </div>
      <div class="progress" role="progressbar" aria-label="Loading allocation options">
        <div class="progress-bar progress-bar-striped progress-bar-animated" style="width: 100%" />
      </div>
    </div>
    <div v-if="loading" class="np-confirm-progress mb-3">
      <div class="d-flex align-items-center justify-content-between gap-3 small mb-2">
        <span class="fw-semibold">{{ submitProgressTitle }}</span>
        <span class="text-muted">{{ submitProgressHint }}</span>
      </div>
      <div class="progress" role="progressbar" :aria-label="submitProgressTitle">
        <div class="progress-bar progress-bar-striped progress-bar-animated" style="width: 100%" />
      </div>
    </div>
    <template #footer>
      <button class="btn btn-light btn-wave" type="button" :disabled="loading" @click="emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary btn-wave" type="button" :disabled="confirmDisabled" @click="confirm">
        <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
        Confirm
      </button>
    </template>
  </AdminModal>
</template>

<script setup lang="ts">
import type { OperationFormField, OperationOption } from '~/composables/useAdminOperationsCatalog'
import { formatAdminValue, formatMoney, formatRewardMoney } from '~/utils/format'
import { translateReportText } from '~/utils/reportI18n'

const props = defineProps<{
  modelValue: boolean
  title: string
  message: string
  requiresReason?: boolean
  optionalReason?: boolean
  requiresPayload?: boolean
  payloadTemplate?: Record<string, any> | null
  formFields?: OperationFormField[]
  recordContext?: Record<string, any> | null
  contextFields?: string[]
  loading?: boolean
  error?: any
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  confirm: [reason: string, payloadJson: string, formValues: Record<string, any>]
}>()

const reason = ref('')
const payloadJson = ref('')
const formState = reactive<Record<string, any>>({})
const api = useAdminApi()
const { locale } = useAdminLocale()
const allocationPartnerOptions = ref<OperationOption[]>([])
const allocationTenantOptions = ref<OperationOption[]>([])
const allocationOptionLoading = ref(false)
const allocationOptionError = ref<any>(null)
let allocationOptionRequestId = 0

const formFields = computed(() => props.formFields || [])
const visibleFormFields = computed(() => formFields.value.filter(isFieldVisible))
const sourceRecord = computed(() => props.recordContext?.__raw || props.recordContext || {})
const contextItems = computed(() => {
  const fields = props.contextFields || []
  const moneyAmountRoots = new Set(fields
    .filter(isMoneyAmountPath)
    .map((key) => key.slice(0, -'.amount'.length)))

  return fields
    .filter((key) => !isCurrencyPathForMoneyAmount(key, moneyAmountRoots))
    .map((key) => ({
      key,
      label: contextLabel(key),
      value: formatContextValue(key, getPath(sourceRecord.value, key)),
    }))
    .filter((item) => item.value !== '-')
    .slice(0, 13)
})
const partnerField = computed(() => formFields.value.find((field) => field.key === 'partner_id'))
const tenantField = computed(() => formFields.value.find((field) => field.key === 'tenant_id'))
const gameField = computed(() => formFields.value.find((field) => field.key === 'game_id'))
const allocationPercentField = computed(() => formFields.value.find((field) => field.key === 'allocation_percent'))
const allocationPartnerPercentListField = computed(() => formFields.value.find((field) => field.type === 'allocation-partner-percent-list'))
const isAllocationPercentForm = computed(() => Boolean(
  allocationPercentField.value
  && partnerField.value?.optionSource === 'allocation-partners'
  && tenantField.value?.optionSource === 'allocation-tenants'
  && gameField.value?.optionSource === 'allocation-games',
))
const isAllocationCreateForm = computed(() => Boolean(
  isAllocationPercentForm.value
  && !partnerField.value?.readonly,
))
const isBulkAllocationForm = computed(() => Boolean(
  allocationPartnerPercentListField.value
  && gameField.value?.optionSource === 'allocation-games',
))
const usesAllocationOptions = computed(() => isAllocationPercentForm.value || isBulkAllocationForm.value)
const submitProgressTitle = computed(() => isBulkAllocationForm.value ? 'Opening partner allocations' : isAllocationCreateForm.value ? 'Creating allocation' : 'Submitting request')
const submitProgressHint = computed(() => isBulkAllocationForm.value ? 'Preparing all selected partners' : isAllocationCreateForm.value ? 'Preparing stock allocation' : 'API request is running')
const selectedPartnerOption = computed(() => partnerField.value ? findOption(partnerField.value, formState.partner_id) : null)
const selectedGameOption = computed(() => gameField.value ? findOption(gameField.value, formState.game_id) : null)
const bulkAllocationRows = computed(() => {
  const field = allocationPartnerPercentListField.value
  return field && Array.isArray(formState[field.key]) ? formState[field.key] : []
})
const bulkAllocationExistingPercent = computed(() => (
  optionNumber(selectedGameOption.value, 'existingGameAllocationPercent')
  ?? optionNumber(allocationPartnerOptions.value[0], 'existingAllocationPercent')
  ?? 0
))
const bulkAllocationNewPercentTotal = computed(() => bulkAllocationRows.value.reduce((sum: number, row: any) => {
  if (row?.disabled) {
    return sum
  }
  const percent = numberOrNull(row?.allocation_percent)
  return sum + (percent === null || percent < 0 ? 0 : percent)
}, 0))
const bulkAllocationGrandTotal = computed(() => bulkAllocationExistingPercent.value + bulkAllocationNewPercentTotal.value)
const bulkAllocationRemainingPercent = computed(() => 100 - bulkAllocationGrandTotal.value)
const bulkAllocationOverLimit = computed(() => bulkAllocationGrandTotal.value > 100.000001)
const allocationPreviewMetrics = computed(() => {
  if (!allocationPercentField.value) {
    return []
  }

  const percent = numberOrNull(formState.allocation_percent)
  const generatedSupply = optionNumber(selectedGameOption.value, 'generatedSupplyCount')
  const estimatedAllocation = generatedSupply !== null && percent !== null
    ? Math.floor((generatedSupply * percent) / 100)
    : null
  const partnerExistingPercent = optionNumber(selectedPartnerOption.value, 'existingAllocationPercent')
    ?? optionNumber(selectedPartnerOption.value, 'allocationPercent')
    ?? numberOrNull(getPath(sourceRecord.value, 'active_partner_percent'))
    ?? numberOrNull(getPath(sourceRecord.value, 'allocation_percent'))
  const partnerExistingRemaining = optionNumber(selectedPartnerOption.value, 'existingRemainingCount')
    ?? optionNumber(selectedPartnerOption.value, 'remainingCount')
    ?? numberOrNull(getPath(sourceRecord.value, 'remaining_count'))

  return [
    { key: 'supply', label: 'Generated supply', value: formatNumberOrDash(generatedSupply) },
    { key: 'remaining', label: 'Existing remaining', value: formatNumberOrDash(partnerExistingRemaining) },
    { key: 'active', label: 'Existing partner %', value: partnerExistingPercent === null ? '-' : `${formatNumber(partnerExistingPercent)}%` },
    { key: 'percent', label: 'Percent', value: percent === null ? '-' : `${formatNumber(percent)}%` },
    { key: 'estimate', label: 'Estimated supply', value: formatNumberOrDash(estimatedAllocation) },
  ]
})

const missingRequired = computed(() => {
  if (props.requiresReason && !props.optionalReason && reason.value.trim() === '') {
    return true
  }

  return visibleFormFields.value.some((field) => {
    if (!field.required) return false
    if (field.type === 'datetime-range') {
      return isBlank(formState[rangeStartFormKey(field)]) || isBlank(formState[rangeEndFormKey(field)])
    }
    if (field.type === 'reward-prize-number-grid') {
      return field.partial
        ? !hasAnyRewardPrizeNumberUpdate(formState[field.key] || [])
        : !hasCompleteRewardPrizeGroups(formState[field.key] || [])
    }
    if (field.type === 'reward-prize-grid') {
      return !hasCompleteRewardPrizeGroups(formState[field.key] || [])
    }
    if (field.type === 'reward-prize-amount-grid') {
      return !hasCompleteRewardPrizeAmounts(formState[field.key] || [])
    }
    const value = formState[field.key]
    return isBlank(value)
  })
})

const formValidationMessages = computed(() => [...new Set(Object.values(validationMessagesByField.value).flat())])
const confirmDisabled = computed(() => Boolean(props.loading || missingRequired.value || formValidationMessages.value.length))
const validationMessagesByField = computed(() => {
  const messages: Record<string, string[]> = {}
  const add = (key: string, message: string) => {
    messages[key] = [...(messages[key] || []), message]
  }

  for (const field of formFields.value) {
    if (!isFieldVisible(field)) {
      continue
    }

    if (field.type === 'number' || field.type === 'money' || field.type === 'reward-money') {
      const value = numberOrNull(formState[field.key])
      if (value !== null && field.min !== undefined && value < Number(field.min)) {
        add(field.key, `${field.label} must be at least ${field.min}.`)
      }
      if (value !== null && field.max !== undefined && value > Number(field.max)) {
        add(field.key, `${field.label} must be at most ${field.max}.`)
      }
    }

    if (field.defaultValueSource === 'current-game' && field.required && isCurrentGameField(field)) {
      const currentGame = currentOnlyGameOption(field)
      if (isBlank(formState[field.key])) {
        add(field.key, currentGameMissingMessage(field))
        add('__form', 'Select a current game before submitting.')
      } else if (field.currentOnly && currentGame && String(formState[field.key]) !== String(optionValue(currentGame))) {
        add(field.key, 'The game must be the latest open game.')
        add('__form', 'Use the latest open game before submitting.')
      }
    }
  }

  const tenant = tenantField.value
  if (tenant && isFieldVisible(tenant)) {
    const partner = selectedPartnerOption.value
    const activeTenantCount = optionNumber(partner, 'activeTenantCount')
    if (partner && activeTenantCount === 0) {
      add(tenant.key, 'The selected partner has no active tenant.')
      add('__form', 'Select a partner with at least one active tenant before submitting.')
    } else if (partner && activeTenantCount !== null && activeTenantCount > 1 && isBlank(formState[tenant.key])) {
      add(tenant.key, 'Select a tenant for this multi-tenant partner.')
    }
  }

  const bulkField = allocationPartnerPercentListField.value
  if (bulkField && isFieldVisible(bulkField)) {
    const rows = bulkAllocationRows.value
    const activeRows = rows.filter((row: any) => !row?.disabled && (numberOrNull(row?.allocation_percent) || 0) > 0)

    if (allocationOptionLoading.value) {
      add(bulkField.key, 'Loading partner allocation percentages.')
    } else if (!activeRows.length) {
      add(bulkField.key, 'Enter at least one partner allocation percent greater than 0.')
    }

    rows.forEach((row: any) => {
      if (row?.disabled) {
        return
      }
      const percent = numberOrNull(row?.allocation_percent)
      if (percent !== null && (percent < 0 || percent > 100)) {
        add(bulkField.key, `${row.label || row.partner_id} must be between 0 and 100%.`)
      }
    })

    if (bulkAllocationOverLimit.value) {
      add(bulkField.key, `Total allocation is ${formatNumber(bulkAllocationGrandTotal.value)}%, which exceeds 100%.`)
      add('__form', 'Reduce partner percentages until the total allocation is at most 100%.')
    }
  }

  return messages
})

const resetFormState = () => {
  for (const key of Object.keys(formState)) {
    delete formState[key]
  }

  for (const field of formFields.value) {
    if (field.type === 'datetime-range') {
      const startValue = getPath(sourceRecord.value, field.rangeStartSourceKey || field.rangeStartKey || `${field.key}.start`)
      const endValue = getPath(sourceRecord.value, field.rangeEndSourceKey || field.rangeEndKey || `${field.key}.end`)
      formState[rangeStartFormKey(field)] = startValue !== undefined && startValue !== null
        ? formatDateTimeLocalValue(startValue)
        : ''
      formState[rangeEndFormKey(field)] = endValue !== undefined && endValue !== null
        ? formatDateTimeLocalValue(endValue)
        : ''
      continue
    }

    const recordValue = getPath(sourceRecord.value, field.sourceKey || field.key)
    formState[field.key] = recordValue !== undefined && recordValue !== null
      ? normalizeInitialValue(field, recordValue)
      : field.defaultValue !== undefined ? field.defaultValue : normalizeInitialValue(field, recordValue)
  }

  syncDependentTenant()
}

const fieldValidationMessages = (field: OperationFormField) => validationMessagesByField.value[field.key] || []

const isFieldVisible = (field: OperationFormField) => {
  if (!field.visibleForGenerationModes?.length) {
    return true
  }

  return field.visibleForGenerationModes.includes(String(formState.generation_mode || ''))
}

const isCurrentGameField = (field: OperationFormField) => (
  field.key === 'game_id'
  && (field.optionSource === 'central-games' || field.optionSource === 'allocation-games')
)

const currentOnlyGameOption = (field: OperationFormField) => {
  const currentOptions = (field.options || []).filter((option) => (
    typeof option === 'object'
    && option !== null
    && (option.isCurrent || String(option.status || '').toLowerCase() === 'open')
  ))

  return currentOptions[0] || null
}

const currentGameMissingMessage = (field: OperationFormField) => (
  field.optionSource === 'allocation-games'
    ? 'No latest open game is available for allocation.'
    : 'No single current draw/current game is available. Open exactly one current game before generating stock.'
)

const fieldDisabled = (field: OperationFormField) => {
  if (field.readonly) {
    return true
  }

  if (field.currentOnly && isCurrentGameField(field)) {
    return true
  }

  if (field.dependsOn && isBlank(formState[field.dependsOn])) {
    return true
  }

  if (isAllocationPercentForm.value && (field.key === 'partner_id' || field.key === 'tenant_id')) {
    if (isBlank(formState.game_id) || allocationOptionLoading.value) {
      return true
    }
  }

  if (field.key === 'tenant_id') {
    const activeTenantCount = optionNumber(selectedPartnerOption.value, 'activeTenantCount')
    return activeTenantCount === 0 || activeTenantCount === 1
  }

  return false
}

const visibleOptions = (field: OperationFormField) => {
  if (field.key === 'tenant_id') {
    const partner = selectedPartnerOption.value
    const singleTenantId = optionString(partner, 'singleTenantId')
    if (partner && optionNumber(partner, 'activeTenantCount') === 1 && singleTenantId) {
      return [{
        value: singleTenantId,
        label: optionString(partner, 'singleTenantLabel') || singleTenantId,
        partnerId: optionValue(partner),
      }]
    }
  }

  const options = fieldOptions(field)
  const withCurrentReadonlyOption = (nextOptions: any[]) => {
    const value = formState[field.key]
    if (!field.readonly || isBlank(value) || nextOptions.some((option) => String(optionValue(option)) === String(value))) {
      return nextOptions
    }

    const label = [
      getPath(sourceRecord.value, 'code'),
      getPath(sourceRecord.value, 'name'),
      value,
    ].filter(Boolean).join(' - ')
    return [{ value, label }, ...nextOptions]
  }

  if (!field.dependsOn) {
    return withCurrentReadonlyOption(options)
  }

  const dependencyValue = formState[field.dependsOn]
  if (!dependencyValue) {
    return withCurrentReadonlyOption([])
  }

  return withCurrentReadonlyOption(options.filter((option) => optionPartnerId(option) === String(dependencyValue)))
}

const fieldOptions = (field: OperationFormField) => {
  if (isAllocationPercentForm.value && !isBlank(formState.game_id)) {
    if (field.key === 'partner_id') {
      return allocationPartnerOptions.value
    }

    if (field.key === 'tenant_id') {
      return allocationTenantOptions.value
    }
  }

  return field.options || []
}

const loadAllocationOptions = async () => {
  const requestId = ++allocationOptionRequestId

  if (!props.modelValue || !usesAllocationOptions.value) {
    allocationPartnerOptions.value = []
    allocationTenantOptions.value = []
    allocationOptionError.value = null
    allocationOptionLoading.value = false
    syncBulkAllocationRows()
    return
  }

  const gameId = String(formState.game_id || '').trim()
  const partnerId = String(formState.partner_id || '').trim()
  const availableForCreate = isAllocationCreateForm.value || isBulkAllocationForm.value ? 1 : undefined

  if (!gameId) {
    allocationPartnerOptions.value = []
    allocationTenantOptions.value = []
    allocationOptionError.value = null
    allocationOptionLoading.value = false
    syncBulkAllocationRows()
    return
  }

  allocationOptionLoading.value = true
  allocationOptionError.value = null

  try {
    const [partnerResponse, tenantResponse] = await Promise.all([
      api.apiFetch('/admin/central/allocation-options/partners', {
        scope: 'central',
        query: compactQuery({ limit: 500, game_id: gameId, available_for_create: availableForCreate }),
      }),
      api.apiFetch('/admin/central/allocation-options/tenants', {
        scope: 'central',
        query: compactQuery({ limit: 500, game_id: gameId, partner_id: partnerId, available_for_create: availableForCreate }),
      }),
    ])

    if (requestId !== allocationOptionRequestId) {
      return
    }

    allocationPartnerOptions.value = normalizeAllocationPartnerOptions(extractItems(partnerResponse))
    allocationTenantOptions.value = normalizeAllocationTenantOptions(extractItems(tenantResponse))
    syncBulkAllocationRows()

    if (!partnerField.value?.readonly && !isBlank(formState.partner_id) && !allocationPartnerOptions.value.some((option) => String(optionValue(option)) === String(formState.partner_id))) {
      formState.partner_id = ''
      formState.tenant_id = ''
    }

    syncDependentTenant()
    syncAllocationPercentFromPartner()

    const tenant = tenantField.value
    if (tenant && !isBlank(formState.tenant_id) && !visibleOptions(tenant).some((option) => String(optionValue(option)) === String(formState.tenant_id))) {
      formState.tenant_id = ''
    }
  } catch (err) {
    if (requestId === allocationOptionRequestId) {
      allocationPartnerOptions.value = []
      allocationTenantOptions.value = []
      syncBulkAllocationRows()
      allocationOptionError.value = err
    }
  } finally {
    if (requestId === allocationOptionRequestId) {
      allocationOptionLoading.value = false
    }
  }
}

const syncBulkAllocationRows = () => {
  const field = allocationPartnerPercentListField.value
  if (!field) {
    return
  }

  const currentRows = new Map((Array.isArray(formState[field.key]) ? formState[field.key] : [])
    .filter((row: any) => row?.partner_id)
    .map((row: any) => [String(row.partner_id), row]))

  formState[field.key] = allocationPartnerOptions.value.map((option) => {
    const partnerId = String(optionValue(option))
    const existing = currentRows.get(partnerId)
    const activeTenantCount = optionNumber(option, 'activeTenantCount')
    const singleTenantId = optionString(option, 'singleTenantId')
    const defaultPercent = optionNumber(option, 'defaultAllocationPercent')
      ?? optionNumber(option, 'stockPercent')
      ?? 0
    const disabledReason = activeTenantCount === 0
      ? 'No active tenant'
      : activeTenantCount !== null && activeTenantCount > 1
        ? 'Select tenant manually'
        : ''

    return {
      partner_id: partnerId,
      tenant_id: singleTenantId,
      label: optionLabel(option),
      tenant_label: optionString(option, 'singleTenantLabel'),
      allocation_percent: existing?.allocation_percent ?? existing?.percent ?? defaultPercent,
      disabled: Boolean(disabledReason || optionDisabled(option)),
      disabled_reason: disabledReason || (optionDisabled(option) ? 'Unavailable' : ''),
    }
  }).filter((row) => !isBlank(row.partner_id))
}

const addStockSetDistributionRow = (field: OperationFormField) => {
  const rows = Array.isArray(formState[field.key]) ? formState[field.key] : []
  const usedSetSizes = new Set(rows.map((row: any) => Number(row?.set_size)).filter(Number.isFinite))
  let nextSetSize = 2
  while (usedSetSizes.has(nextSetSize)) {
    nextSetSize += 1
  }

  rows.push({
    __key: stockSetRowKey(nextSetSize, rows.length),
    set_size: nextSetSize,
    percent: '',
  })
  formState[field.key] = rows
}

const removeStockSetDistributionRow = (field: OperationFormField, index: number) => {
  const rows = Array.isArray(formState[field.key]) ? formState[field.key] : []
  rows.splice(index, 1)
  formState[field.key] = rows.length ? rows : [{
    __key: stockSetRowKey(2, 0),
    set_size: 2,
    percent: '',
  }]
}

const handleFieldInput = (_field: OperationFormField, _event: Event) => {}

const syncDependentTenant = () => {
  const field = tenantField.value
  if (!field) {
    return
  }

  const partner = selectedPartnerOption.value
  const activeTenantCount = optionNumber(partner, 'activeTenantCount')
  const singleTenantId = optionString(partner, 'singleTenantId')

  if (!partner || activeTenantCount === 0) {
    formState[field.key] = ''
    return
  }

  if (activeTenantCount === 1 && singleTenantId) {
    formState[field.key] = singleTenantId
    return
  }

  const allowed = new Set(visibleOptions(field).map((option) => String(optionValue(option))))
  if (formState[field.key] && !allowed.has(String(formState[field.key]))) {
    formState[field.key] = ''
  }
}

const syncAllocationPercentFromPartner = () => {
  const field = allocationPercentField.value
  if (!field) {
    return
  }

  const existingPercent = isAllocationCreateForm.value
    ? (
        optionNumber(selectedPartnerOption.value, 'defaultAllocationPercent')
        ?? optionNumber(selectedPartnerOption.value, 'stockPercent')
      )
    : optionNumber(selectedPartnerOption.value, 'allocationPercent')
  if (existingPercent === null) {
    return
  }

  const currentValue = numberOrNull(formState[field.key])
  if (currentValue === null || currentValue === optionNumber(sourceRecord.value, field.key)) {
    formState[field.key] = existingPercent
  }
}

const normalizeInitialValue = (field: OperationFormField, value: any) => {
  if (field.type === 'checkbox') {
    return Boolean(value)
  }

  if (field.type === 'checkbox-group') {
    return normalizeCheckboxGroupValue(value, field)
  }

  if (field.type === 'datetime-local') {
    return formatDateTimeLocalValue(value)
  }

  if (field.type === 'json') {
    return formatJsonFieldValue(value)
  }

  if (field.type === 'money') {
    return minorUnitToMajor(value)
  }

  if (field.type === 'reward-money') {
    return wholeBahtValue(value)
  }

  if (field.type === 'stock-set-distribution') {
    return normalizeStockSetDistribution(value, field)
  }

  if (field.type === 'stock-sale-limits') {
    return normalizeStockSaleLimits(value)
  }

  if (field.type === 'stock-partner-distribution') {
    return normalizeStockPartnerDistribution(value, field)
  }

  if (field.type === 'stock-partner-limits') {
    return normalizeStockPartnerLimits(value, field)
  }

  if (field.type === 'allocation-partner-percent-list') {
    return []
  }

  if (field.type === 'lines') {
    return formatLines(value, field.valueKey || field.itemKey)
  }

  if (field.type === 'prize-lines') {
    return formatPrizeLines(value)
  }

  if (isRewardPrizeField(field)) {
    const groups = normalizeRewardPrizeGroups(value)
    return field.type === 'reward-prize-amount-grid'
      ? groups.map((group) => ({ ...group, amount: minorUnitToMajor(group.amount) || 0 }))
      : groups
  }

  if (value === undefined || value === null || typeof value === 'object') {
    return ''
  }

  return value
}

const confirm = () => {
  if (confirmDisabled.value) {
    return
  }

  emit('confirm', reason.value, payloadJson.value, normalizeSubmitFormValues())
}

const fieldId = (key: string) => `admin-confirm-${key.replace(/[^a-z0-9_-]/gi, '-')}`
const rangeStartFormKey = (field: OperationFormField) => `${field.key}.__start`
const rangeEndFormKey = (field: OperationFormField) => `${field.key}.__end`
const isBlank = (value: any) => value === undefined || value === null || String(value).trim() === ''

const minorUnitToMajor = (value: any) => {
  const amount = typeof value === 'object' && value !== null ? value.amount : value
  if (amount === undefined || amount === null || amount === '') {
    return ''
  }

  const parsed = Number(amount)
  return Number.isFinite(parsed) ? parsed / 100 : ''
}

const wholeBahtValue = (value: any) => {
  const amount = typeof value === 'object' && value !== null ? value.amount : value
  if (amount === undefined || amount === null || amount === '') {
    return ''
  }

  const parsed = Number(amount)
  return Number.isFinite(parsed) ? Math.round(parsed) : ''
}

const normalizeSubmitFormValues = () => {
  const values: Record<string, any> = { ...formState }

  for (const field of formFields.value) {
    if (field.type !== 'reward-prize-amount-grid') {
      continue
    }

    values[field.key] = (Array.isArray(formState[field.key]) ? formState[field.key] : []).map((group: any) => {
      const amount = Number(group?.amount)
      return {
        ...group,
        amount: Number.isFinite(amount) ? Math.round(amount * 100) : 0,
      }
    })
  }

  return values
}

const fieldColumnClass = (field: OperationFormField) => (
  field.type === 'textarea'
  || field.type === 'json'
  || field.type === 'lines'
  || field.type === 'checkbox-group'
  || field.type === 'prize-lines'
  || field.type === 'stock-set-distribution'
  || field.type === 'stock-sale-limits'
  || field.type === 'stock-partner-distribution'
  || field.type === 'stock-partner-limits'
  || field.type === 'allocation-partner-percent-list'
  || isRewardPrizeField(field)
  || field.type === 'datetime-range'
) ? 'col-12' : 'col-md-6'

const inputType = (field: OperationFormField) => {
  if (field.type === 'number' || field.type === 'money' || field.type === 'reward-money') return 'number'
  if (field.type === 'datetime-local') return 'datetime-local'
  if (field.type === 'date') return 'date'
  if (field.type === 'password') return 'password'
  if (field.type === 'color') return 'color'
  return 'text'
}

const isRewardPrizeField = (field: OperationFormField) => (
  field.type === 'reward-prize-grid'
  || field.type === 'reward-prize-number-grid'
  || field.type === 'reward-prize-amount-grid'
)

const getPath = (value: any, path: string) => path.split('.').reduce((current, key) => current?.[key], value)

const labelize = (key: string) => key
  .replace(/[._-]/g, ' ')
  .replace(/\b\w/g, (char) => char.toUpperCase()) || key

const optionValue = (option: any) => typeof option === 'object' && option !== null ? option.value : option
const optionLabel = (option: any) => typeof option === 'object' && option !== null ? option.label : String(option)
const optionDisabled = (option: any) => Boolean(typeof option === 'object' && option !== null && option.disabled)
const optionPartnerId = (option: any) => String(typeof option === 'object' && option !== null ? option.partnerId || option.partner_id || '' : '')
const optionString = (option: any, key: string) => {
  const value = typeof option === 'object' && option !== null ? option[key] : undefined
  return value === undefined || value === null ? '' : String(value)
}
const optionNumber = (option: any, key: string) => {
  const value = typeof option === 'object' && option !== null ? option[key] : null
  return numberOrNull(value)
}
const findOption = (field: OperationFormField, value: any) => {
  if (isBlank(value)) {
    return null
  }
  return fieldOptions(field).find((option) => String(optionValue(option)) === String(value)) || null
}
const numberOrNull = (value: any) => {
  if (value === undefined || value === null || value === '') {
    return null
  }
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}
const formatNumber = (value: number) => new Intl.NumberFormat('th-TH', { maximumFractionDigits: 2 }).format(value)
const formatNumberOrDash = (value: number | null) => value === null ? '-' : formatNumber(value)

const formatContextValue = (key: string, value: any) => {
  if (value === undefined || value === null || value === '') return '-'
  if (isMoneyAmountPath(key)) {
    const root = key.slice(0, -'.amount'.length)
    if (isRewardMoneyRoot(root)) {
      return formatRewardMoney(value, getPath(sourceRecord.value, `${root}.currency`) || 'THB')
    }
    return formatMoney({
      amount: value,
      currency: getPath(sourceRecord.value, `${root}.currency`) || 'THB',
    })
  }
  if (isMoneyObject(value)) return formatMoney(value)
  return formatAdminValue(value, undefined, key)
}

const contextLabel = (key: string) => {
  if (isMoneyAmountPath(key)) {
    return labelize(key.slice(0, -'.amount'.length))
  }

  return labelize(key)
}

const isMoneyAmountPath = (key: string) => key.endsWith('.amount')
const isRewardMoneyRoot = (key: string) => ['central_reward_amount', 'partner_payout_amount', 'adjustment_amount', 'payout_amount'].includes(key)
const isCurrencyPathForMoneyAmount = (key: string, moneyAmountRoots: Set<string>) => (
  key.endsWith('.currency')
  && moneyAmountRoots.has(key.slice(0, -'.currency'.length))
)

const isMoneyObject = (value: any) => (
  typeof value === 'object'
  && value !== null
  && Object.prototype.hasOwnProperty.call(value, 'amount')
)

const formatJsonFieldValue = (value: any) => {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  if (typeof value === 'string') {
    return value
  }

  return JSON.stringify(value, null, 2)
}

const formatDateTimeLocalValue = (value: any) => {
  if (value === undefined || value === null || value === '') return ''

  const raw = String(value)
  const localMatch = raw.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?$/)
  if (localMatch) {
    return `${localMatch[1]}T${localMatch[2]}`
  }

  const date = new Date(raw)
  if (Number.isNaN(date.getTime())) {
    return raw
  }

  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Bangkok',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(date)
  const part = (type: string) => parts.find((entry) => entry.type === type)?.value || '00'
  return `${part('year')}-${part('month')}-${part('day')}T${part('hour')}:${part('minute')}`
}

const formatPrizeLines = (value: any) => {
  if (!Array.isArray(value)) {
    return ''
  }

  return value.map((prize) => [
    prize?.prize_type,
    prize?.prize_number,
    prize?.amount?.amount,
    prize?.amount?.currency || 'THB',
  ].filter((entry) => entry !== undefined && entry !== null && entry !== '').join(',')).join('\n')
}

const formatLines = (value: any, valueKey?: string) => {
  if (!Array.isArray(value)) {
    return value === undefined || value === null ? '' : String(value)
  }

  return value
    .map((entry) => {
      if (valueKey && entry && typeof entry === 'object') {
        return getPath(entry, valueKey)
      }

      if (entry && typeof entry === 'object') {
        return JSON.stringify(entry)
      }

      return entry
    })
    .filter((entry) => entry !== undefined && entry !== null && entry !== '')
    .join('\n')
}

const normalizeCheckboxGroupValue = (value: any, field: OperationFormField) => {
  const entries = Array.isArray(value)
    ? value
    : value === undefined || value === null || value === ''
      ? []
      : [value]
  const valueKey = field.valueKey || field.itemKey || 'value'

  return entries
    .map((entry) => {
      if (entry && typeof entry === 'object') {
        return getPath(entry, valueKey) || entry.code || entry.id
      }

      return entry
    })
    .filter((entry) => entry !== undefined && entry !== null && entry !== '')
    .map((entry) => String(entry))
}

const normalizeStockSetDistribution = (value: any, field: OperationFormField) => {
  const source = Array.isArray(value) && value.length ? value : Array.isArray(field.defaultValue) ? field.defaultValue : []
  const rows = source
    .map((row: any, index: number) => ({
      __key: row?.__key || stockSetRowKey(row?.set_size ?? row?.size ?? 1, index),
      set_size: Number(row?.set_size ?? row?.size ?? 1),
      percent: numberOrBlank(row?.percent ?? basisPointsToPercent(row?.percent_basis_points)),
    }))
    .filter((row: any) => Number.isFinite(row.set_size))

  return rows.length ? rows : [
    { __key: stockSetRowKey(2, 0), set_size: 2, percent: 10 },
    { __key: stockSetRowKey(3, 1), set_size: 3, percent: 15 },
  ]
}

const stockSetRowKey = (setSize: any, index: number) => `set-${Number(setSize) || 1}-${index}-${Date.now()}`

const normalizeStockSaleLimits = (value: any) => ({
  back2_limit: numberOrBlank(value?.back2_limit ?? value?.back2),
  back3_limit: numberOrBlank(value?.back3_limit ?? value?.back3),
  front3_limit: numberOrBlank(value?.front3_limit ?? value?.front3),
})

const normalizeStockPartnerDistribution = (value: any, field: OperationFormField) => {
  const current = new Map((Array.isArray(value) ? value : [])
    .filter((row: any) => row?.partner_id)
    .map((row: any) => [String(row.partner_id), row]))

  return (field.options || []).map((option) => {
    const partnerId = String(optionValue(option))
    const existing = current.get(partnerId)
    return {
      partner_id: partnerId,
      label: optionLabel(option),
      percent: numberOrBlank(existing?.percent ?? basisPointsToPercent(existing?.percent_basis_points)),
    }
  }).filter((row) => !isBlank(row.partner_id))
}

const normalizeStockPartnerLimits = (value: any, field: OperationFormField) => {
  const current = new Map((Array.isArray(value) ? value : [])
    .filter((row: any) => row?.partner_id)
    .map((row: any) => [String(row.partner_id), row]))

  return (field.options || []).map((option) => {
    const partnerId = String(optionValue(option))
    const existing = current.get(partnerId)
    return {
      partner_id: partnerId,
      label: optionLabel(option),
      back2_limit: numberOrBlank(existing?.back2_limit ?? existing?.back2),
      back3_limit: numberOrBlank(existing?.back3_limit ?? existing?.back3),
      front3_limit: numberOrBlank(existing?.front3_limit ?? existing?.front3),
    }
  }).filter((row) => !isBlank(row.partner_id))
}

const numberOrBlank = (value: any) => {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : ''
}

const basisPointsToPercent = (value: any) => {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed / 100 : ''
}

const extractItems = (response: any): any[] => {
  const data = response?.data?.data || response?.data || response?.items || response
  return Array.isArray(data) ? data : []
}

const compactQuery = (query: Record<string, any>) => Object.fromEntries(
  Object.entries(query).filter(([, value]) => !isBlank(value)),
)

const normalizeAllocationPartnerOptions = (items: any[]): OperationOption[] => items
  .map(allocationPartnerOption)
  .filter((option) => !isBlank(optionValue(option)))

const normalizeAllocationTenantOptions = (items: any[]): OperationOption[] => items
  .map(allocationTenantOption)
  .filter((option) => !isBlank(optionValue(option)))

const allocationPartnerOption = (partner: any): OperationOption => {
  const id = partner?.partner_id || partner?.id || partner?.uuid || partner?.code
  const code = partner?.code || partner?.partner_code || ''
  const name = partner?.name || partner?.partner_name || partner?.display_name || id
  const singleTenantId = partner?.single_tenant_id || ''
  const singleTenantLabel = [partner?.single_tenant_code, partner?.single_tenant_name]
    .filter(Boolean)
    .join(' - ')

  return {
    value: id,
    label: partner?.label || [code, name].filter(Boolean).join(' - ') || String(id || ''),
    code,
    name,
    partnerId: id,
    activeTenantCount: Number(partner?.active_tenant_count || 0),
    singleTenantId,
    singleTenantLabel: singleTenantLabel || singleTenantId,
    allocationPercent: numberOrNull(partner?.allocation_percent),
    allocationPercentBasisPoints: numberOrNull(partner?.allocation_percent_basis_points),
    stockPercent: numberOrNull(partner?.stock_percent),
    stockPercentBasisPoints: numberOrNull(partner?.stock_percent_basis_points),
    defaultAllocationPercent: numberOrNull(partner?.default_allocation_percent),
    defaultAllocationPercentBasisPoints: numberOrNull(partner?.default_allocation_percent_basis_points),
    remainingCount: numberOrNull(partner?.remaining_count),
    existingAllocationPercent: numberOrNull(partner?.existing_allocation_percent),
    existingAllocationPercentBasisPoints: numberOrNull(partner?.existing_allocation_percent_basis_points),
    existingAllocatedCount: numberOrNull(partner?.existing_allocated_count),
    existingRemainingCount: numberOrNull(partner?.existing_remaining_count),
    status: String(partner?.status || '').toLowerCase(),
  }
}

const allocationTenantOption = (tenant: any): OperationOption => {
  const id = tenant?.tenant_id || tenant?.id || tenant?.uuid || tenant?.code
  const code = tenant?.code || tenant?.tenant_code || ''
  const name = tenant?.name || tenant?.tenant_name || id
  const partnerCode = tenant?.partner_code || ''

  return {
    value: id,
    label: tenant?.label || [code, name].filter(Boolean).join(' - ') || String(id || ''),
    code,
    name,
    tenantId: id,
    partnerId: tenant?.partner_id || '',
    status: String(tenant?.status || '').toLowerCase(),
    disabled: String(tenant?.status || '').toLowerCase() !== 'active',
    singleTenantLabel: partnerCode ? `${partnerCode} / ${name}` : name,
  }
}

watch(() => [props.modelValue, props.payloadTemplate, props.formFields, props.recordContext] as const, () => {
  if (props.modelValue) {
    reason.value = ''
    payloadJson.value = JSON.stringify(props.payloadTemplate || {}, null, 2)
    resetFormState()
  }
}, { immediate: true })

watch(() => [formState.partner_id, props.modelValue, props.formFields] as const, () => {
  if (props.modelValue) {
    syncDependentTenant()
    syncAllocationPercentFromPartner()
  }
}, { deep: true })

watch(() => [props.modelValue, formState.game_id, formState.partner_id, usesAllocationOptions.value] as const, () => {
  loadAllocationOptions()
}, { deep: true })
</script>

<style scoped>
.np-reward-prize-editor {
  display: grid;
  gap: 1rem;
}

.np-reward-prize-editor__group {
  border: 1px solid var(--default-border);
  border-radius: 6px;
  padding: 1rem;
}

.np-reward-prize-editor__amount {
  min-width: min(100%, 16rem);
}

.np-reward-prize-editor__numbers {
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(auto-fit, minmax(7.5rem, 1fr));
}

.np-reward-prize-editor__numbers--readonly {
  display: flex;
  flex-wrap: wrap;
  gap: .5rem;
}

.np-reward-prize-editor__number-pill {
  border: 1px solid var(--default-border);
  border-radius: 4px;
  font-size: .875rem;
  line-height: 1.2;
  min-width: 4.75rem;
  padding: .35rem .5rem;
  text-align: center;
}

.np-stock-config-panel {
  border: 1px solid var(--default-border);
  border-radius: 6px;
  max-width: 100%;
  overflow: hidden;
  padding: 1rem;
}

.np-checkbox-group {
  border: 1px solid var(--default-border);
  border-radius: 6px;
  max-height: 22rem;
  overflow: auto;
  padding: .75rem;
}

.np-checkbox-group.is-invalid {
  border-color: rgb(var(--danger-rgb));
}

.np-checkbox-grid {
  display: grid;
  gap: .5rem .75rem;
  grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
}

.np-checkbox-option {
  align-items: flex-start;
  border: 1px solid var(--default-border);
  border-radius: 6px;
  display: flex;
  gap: .5rem;
  margin: 0;
  min-height: 2.75rem;
  padding: .55rem .65rem;
}

.np-checkbox-option .form-check-input {
  margin-left: 0;
  margin-top: .15rem;
}

.np-allocation-preview {
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(auto-fit, minmax(8.5rem, 1fr));
}

.np-allocation-preview > div {
  display: grid;
  gap: .15rem;
}

.np-allocation-bulk-summary {
  background: rgba(var(--primary-rgb), .08);
  border: 1px solid rgba(var(--primary-rgb), .18);
  border-radius: 6px;
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(auto-fit, minmax(min(9rem, 100%), 1fr));
  margin-bottom: 1rem;
  padding: .875rem;
}

.np-allocation-bulk-summary.is-over {
  background: rgba(var(--danger-rgb), .08);
  border-color: rgba(var(--danger-rgb), .25);
}

.np-allocation-bulk-summary > div {
  display: grid;
  gap: .15rem;
}

.np-confirm-progress {
  border: 1px solid var(--default-border);
  border-radius: 6px;
  padding: .75rem;
}

.np-confirm-progress .progress {
  height: .5rem;
}

.np-stock-config-grid {
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(auto-fit, minmax(10rem, 1fr));
}

.np-stock-config-grid--small {
  grid-template-columns: repeat(auto-fit, minmax(9rem, 12rem));
}

.np-stock-set-table {
  display: grid;
  gap: .5rem;
}

.np-stock-set-table__head,
.np-stock-set-table__row {
  align-items: center;
  display: grid;
  gap: .75rem;
  grid-template-columns: minmax(7rem, 10rem) minmax(9rem, 14rem) 2.5rem;
}

.np-stock-set-table__head {
  color: var(--text-muted);
  font-size: .75rem;
  font-weight: 600;
}

.np-stock-partner-table {
  display: grid;
  gap: .5rem;
}

.np-stock-partner-table__head,
.np-stock-partner-table__row {
  align-items: center;
  display: grid;
  gap: .75rem;
  grid-template-columns: minmax(10rem, 1fr) minmax(7rem, 10rem);
}

.np-stock-partner-table--limits .np-stock-partner-table__head,
.np-stock-partner-table--limits .np-stock-partner-table__row {
  grid-template-columns: minmax(10rem, 1fr) repeat(3, minmax(6rem, 8rem));
}

.np-allocation-partner-table .np-stock-partner-table__head,
.np-allocation-partner-table .np-stock-partner-table__row {
  grid-template-columns: minmax(0, 1fr) minmax(8rem, 10rem) minmax(6.5rem, 8rem);
}

.np-allocation-partner-table .np-stock-partner-table__row > * {
  min-width: 0;
}

.np-allocation-partner-table .input-group {
  min-width: 0;
  width: 100%;
}

.np-allocation-partner-table .badge {
  min-width: 0;
  overflow-wrap: anywhere;
  text-align: center;
  white-space: normal;
}

.np-stock-partner-table__head {
  color: var(--text-muted);
  font-size: .75rem;
  font-weight: 600;
}

@media (max-width: 767.98px) {
  .np-stock-config-panel {
    padding: .75rem;
  }

  .np-allocation-partner-table .np-stock-partner-table__head {
    display: none;
  }

  .np-allocation-partner-table .np-stock-partner-table__row {
    align-items: stretch;
    border: 1px solid var(--default-border);
    border-radius: 6px;
    gap: .6rem;
    grid-template-columns: 1fr;
    padding: .75rem;
  }

  .np-allocation-partner-table .badge {
    justify-self: start;
  }
}

@media (max-width: 575.98px) {
  .np-stock-partner-table__head {
    display: none;
  }

  .np-stock-set-table__head {
    display: none;
  }

  .np-stock-set-table__row,
  .np-stock-partner-table__row,
  .np-stock-partner-table--limits .np-stock-partner-table__row,
  .np-allocation-partner-table .np-stock-partner-table__row {
    grid-template-columns: 1fr;
  }
}
</style>

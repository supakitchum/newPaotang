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

    <div v-if="formFields.length" class="row g-3 mb-3">
      <div v-for="field in formFields" :key="field.key" :class="fieldColumnClass(field)">
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
          >
            <option v-if="!field.hideEmptyOption" value="">{{ field.emptyOptionLabel || 'Select' }}</option>
            <option v-else-if="!(field.options || []).length" value="" disabled>{{ field.emptyOptionLabel || 'No options available' }}</option>
            <option
              v-for="option in field.options || []"
              :key="optionValue(option)"
              :value="optionValue(option)"
              :disabled="optionDisabled(option)"
            >
              {{ optionLabel(option) }}
            </option>
          </select>
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
                      step="1"
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
              <div v-else class="np-reward-prize-editor__numbers np-reward-prize-editor__numbers--readonly">
                <span
                  v-for="(number, index) in group.numbers"
                  :key="`${group.type}-${index}`"
                  class="np-reward-prize-editor__number-pill"
                  :class="{ 'text-muted': isBlank(number) }"
                >
                  {{ displayRewardNumber(number) }}
                </span>
              </div>
            </section>
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
            :step="field.step"
            :placeholder="field.placeholder"
            @input="handleFieldInput(field, $event)"
          >
          <div v-if="field.help" class="form-text">{{ field.help }}</div>
          <div v-for="message in fieldValidationMessages(field)" :key="message" class="invalid-feedback d-block">
            {{ message }}
          </div>
        </template>
      </div>
      <div v-if="hasStockGenerateQuotaFields" class="col-12">
        <div class="np-stock-quota-panel" :class="{ 'np-stock-quota-panel--invalid': formValidationMessages.length }">
          <div class="d-flex flex-wrap align-items-start justify-content-between gap-2 mb-2">
            <div>
              <div class="fw-semibold">Stock quota check</div>
              <div class="text-muted small">2-tail = 10 x 3-tail, 3-front = 3-tail, total = 1,000 x 3-tail.</div>
            </div>
          </div>
          <div class="np-stock-quota-panel__grid">
            <div>
              <span class="text-muted small">2-tail</span>
              <strong>{{ stockQuotaPreview.back2 }}</strong>
            </div>
            <div>
              <span class="text-muted small">3-tail</span>
              <strong>{{ stockQuotaPreview.back3 }}</strong>
            </div>
            <div>
              <span class="text-muted small">3-front</span>
              <strong>{{ stockQuotaPreview.front3 }}</strong>
            </div>
            <div>
              <span class="text-muted small">Total</span>
              <strong>{{ stockQuotaPreview.total }}</strong>
            </div>
          </div>
          <div v-if="formValidationMessages.length" class="text-danger small mt-2">
            <div v-for="message in formValidationMessages" :key="message">{{ message }}</div>
          </div>
        </div>
      </div>
    </div>

    <label v-if="requiresPayload" class="form-label">Payload JSON</label>
    <textarea v-if="requiresPayload" v-model="payloadJson" class="form-control np-admin-json-editor mb-3" rows="8" spellcheck="false" />
    <label v-if="requiresReason" class="form-label">Reason</label>
    <textarea v-if="requiresReason" v-model="reason" class="form-control" rows="3" />
    <template #footer>
      <button class="btn btn-light btn-wave" type="button" @click="emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary btn-wave" type="button" :disabled="confirmDisabled" @click="confirm">
        <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
        Confirm
      </button>
    </template>
  </AdminModal>
</template>

<script setup lang="ts">
import type { OperationFormField } from '~/composables/useAdminOperationsCatalog'

const props = defineProps<{
  modelValue: boolean
  title: string
  message: string
  requiresReason?: boolean
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

const formFields = computed(() => props.formFields || [])
const sourceRecord = computed(() => props.recordContext?.__raw || props.recordContext || {})
const contextItems = computed(() => (props.contextFields || [])
  .map((key) => ({
    key,
    label: labelize(key),
    value: formatContextValue(getPath(sourceRecord.value, key)),
  }))
  .filter((item) => item.value !== '-')
  .slice(0, 13))

const missingRequired = computed(() => {
  if (props.requiresReason && reason.value.trim() === '') {
    return true
  }

  return formFields.value.some((field) => {
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
const hasStockGenerateQuotaFields = computed(() => stockGenerateQuotaKeys.every((key) => (
  formFields.value.some((field) => field.key === key)
)))
const stockQuotaPreview = computed(() => ({
  back2: formatQuotaPreview(formState.back2_count_per_number),
  back3: formatQuotaPreview(formState.back3_count_per_number),
  front3: formatQuotaPreview(formState.front3_count_per_number),
  total: formatQuotaPreview(formState.total_count),
}))
const validationMessagesByField = computed(() => {
  const messages: Record<string, string[]> = {}
  const add = (key: string, message: string) => {
    messages[key] = [...(messages[key] || []), message]
  }

  for (const field of formFields.value) {
    if (
      field.defaultValueSource === 'current-game'
      && field.required
      && field.optionSource === 'central-games'
      && isBlank(formState[field.key])
    ) {
      add(field.key, 'No single current draw/current game is available. Open exactly one current game before generating stock.')
      add('__form', 'Select a current game before submitting.')
    }
  }

  if (!hasStockGenerateQuotaFields.value) {
    return messages
  }

  const total = integerValue(formState.total_count)
  const back2 = integerValue(formState.back2_count_per_number)
  const back3 = integerValue(formState.back3_count_per_number)
  const front3 = integerValue(formState.front3_count_per_number)
  const hasAnyQuotaInput = [
    formState.total_count,
    formState.back2_count_per_number,
    formState.back3_count_per_number,
    formState.front3_count_per_number,
  ].some((value) => !isBlank(value))

  if (!hasAnyQuotaInput) {
    add('__form', 'Enter total tickets or one quota value before submitting.')
  }

  if (hasAnyQuotaInput) {
    for (const [key, label] of [
      ['total_count', 'Total tickets'],
      ['back2_count_per_number', '2-tail quota'],
      ['back3_count_per_number', '3-tail quota'],
      ['front3_count_per_number', '3-front quota'],
    ]) {
      if (isBlank(formState[key])) {
        add(key, `${label} must stay filled after quota sync.`)
      }
    }
  }

  if (!isBlank(formState.total_count)) {
    if (total === null || total < 1000) {
      add('total_count', 'Total tickets must be at least 1,000.')
    } else if (total > 10000) {
      add('total_count', 'Total tickets must not exceed 10,000 for synchronous generation.')
    } else if (total % 1000 !== 0) {
      add('total_count', 'Total tickets must be divisible by 1,000.')
    }
  }

  if (!isBlank(formState.back2_count_per_number)) {
    if (back2 === null || back2 < 1) {
      add('back2_count_per_number', '2-tail quota must be a positive whole number.')
    } else if (back2 % 10 !== 0) {
      add('back2_count_per_number', '2-tail quota must be divisible by 10.')
    } else if (back2 > 100) {
      add('back2_count_per_number', '2-tail quota must not create more than 10,000 stock items.')
    }
  }

  if (!isBlank(formState.back3_count_per_number)) {
    if (back3 === null || back3 < 1) {
      add('back3_count_per_number', '3-tail quota must be a positive whole number.')
    } else if (back3 > 10) {
      add('back3_count_per_number', '3-tail quota must not create more than 10,000 stock items.')
    }
  }

  if (!isBlank(formState.front3_count_per_number)) {
    if (front3 === null || front3 < 1) {
      add('front3_count_per_number', '3-front quota must be a positive whole number.')
    } else if (front3 > 10) {
      add('front3_count_per_number', '3-front quota must not create more than 10,000 stock items.')
    }
  }

  if (back2 !== null && back3 !== null && back2 !== back3 * 10) {
    add('back2_count_per_number', '2-tail quota must equal 10 x 3-tail quota.')
  }

  if (front3 !== null && back3 !== null && front3 !== back3) {
    add('front3_count_per_number', '3-front quota must equal 3-tail quota.')
  }

  if (total !== null && back3 !== null && total !== back3 * 1000) {
    add('total_count', 'Total tickets must equal 1,000 x 3-tail quota.')
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
}

const stockGenerateQuotaKeys = [
  'total_count',
  'back2_count_per_number',
  'back3_count_per_number',
  'front3_count_per_number',
]

const fieldValidationMessages = (field: OperationFormField) => validationMessagesByField.value[field.key] || []

const handleFieldInput = (field: OperationFormField, event: Event) => {
  if (!stockGenerateQuotaKeys.includes(field.key)) {
    return
  }

  const target = event.target as HTMLInputElement | null
  if (target) {
    formState[field.key] = target.value
  }

  syncStockQuotaFields(field.key)
}

const syncStockQuotaFields = (sourceKey: string) => {
  if (!hasStockGenerateQuotaFields.value) {
    return
  }

  const sourceValue = integerValue(formState[sourceKey])
  if (sourceValue === null || sourceValue < 1) {
    return
  }

  const back3 = back3FromQuotaSource(sourceKey, sourceValue)
  if (back3 === null || back3 < 1 || back3 > 10) {
    return
  }

  formState.back2_count_per_number = back3 * 10
  formState.back3_count_per_number = back3
  formState.front3_count_per_number = back3
  formState.total_count = back3 * 1000
}

const back3FromQuotaSource = (sourceKey: string, value: number) => {
  if (sourceKey === 'total_count') {
    return value % 1000 === 0 ? value / 1000 : null
  }

  if (sourceKey === 'back2_count_per_number') {
    return value % 10 === 0 ? value / 10 : null
  }

  if (sourceKey === 'back3_count_per_number' || sourceKey === 'front3_count_per_number') {
    return value
  }

  return null
}

const integerValue = (value: any) => {
  if (isBlank(value)) {
    return null
  }

  const parsed = Number(value)
  if (!Number.isInteger(parsed)) {
    return null
  }

  return parsed
}

const formatQuotaPreview = (value: any) => {
  const parsed = integerValue(value)
  if (parsed === null) {
    return '-'
  }

  return new Intl.NumberFormat('th-TH', { maximumFractionDigits: 0 }).format(parsed)
}

const normalizeInitialValue = (field: OperationFormField, value: any) => {
  if (field.type === 'checkbox') {
    return Boolean(value)
  }

  if (field.type === 'datetime-local') {
    return formatDateTimeLocalValue(value)
  }

  if (field.type === 'json') {
    return formatJsonFieldValue(value)
  }

  if (field.type === 'lines') {
    return formatLines(value, field.valueKey || field.itemKey)
  }

  if (field.type === 'prize-lines') {
    return formatPrizeLines(value)
  }

  if (isRewardPrizeField(field)) {
    return normalizeRewardPrizeGroups(value)
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

  emit('confirm', reason.value, payloadJson.value, { ...formState })
}

const fieldId = (key: string) => `admin-confirm-${key.replace(/[^a-z0-9_-]/gi, '-')}`
const rangeStartFormKey = (field: OperationFormField) => `${field.key}.__start`
const rangeEndFormKey = (field: OperationFormField) => `${field.key}.__end`
const isBlank = (value: any) => value === undefined || value === null || String(value).trim() === ''

const displayRewardNumber = (value: any) => {
  const normalized = String(value || '').trim()
  return normalized && !normalized.startsWith('pending_') ? normalized : '-'
}

const fieldColumnClass = (field: OperationFormField) => (
  field.type === 'textarea'
  || field.type === 'json'
  || field.type === 'lines'
  || field.type === 'prize-lines'
  || isRewardPrizeField(field)
  || field.type === 'datetime-range'
) ? 'col-12' : 'col-md-6'

const inputType = (field: OperationFormField) => {
  if (field.type === 'number') return 'number'
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

const formatContextValue = (value: any) => {
  if (value === undefined || value === null || value === '') return '-'
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

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
  const localMatch = raw.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/)
  if (localMatch) {
    return `${localMatch[1]}T${localMatch[2]}`
  }

  const date = new Date(raw)
  if (Number.isNaN(date.getTime())) {
    return raw
  }

  const pad = (entry: number) => String(entry).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
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

watch(() => [props.modelValue, props.payloadTemplate, props.formFields, props.recordContext] as const, () => {
  if (props.modelValue) {
    reason.value = ''
    payloadJson.value = JSON.stringify(props.payloadTemplate || {}, null, 2)
    resetFormState()
  }
}, { immediate: true })
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

.np-stock-quota-panel {
  background: rgb(var(--light-rgb));
  border: 1px solid var(--default-border);
  border-radius: 6px;
  padding: 1rem;
}

.np-stock-quota-panel--invalid {
  background: rgba(var(--bs-danger-rgb), .06);
  border-color: rgba(var(--bs-danger-rgb), .35);
}

.np-stock-quota-panel__grid {
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(auto-fit, minmax(7rem, 1fr));
}

.np-stock-quota-panel__grid > div {
  background: var(--custom-white);
  border: 1px solid var(--default-border);
  border-radius: 4px;
  display: grid;
  gap: .25rem;
  padding: .65rem .75rem;
}
</style>

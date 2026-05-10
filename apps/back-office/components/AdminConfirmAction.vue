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
      <div v-for="field in formFields" :key="field.key" :class="field.type === 'textarea' || field.type === 'lines' ? 'col-12' : 'col-md-6'">
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
          >
            <option value="">Select</option>
            <option v-for="option in field.options || []" :key="option" :value="option">{{ option }}</option>
          </select>
          <textarea
            v-else-if="field.type === 'textarea' || field.type === 'lines'"
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
            :type="field.type === 'number' ? 'number' : field.type === 'date' ? 'date' : field.type === 'password' ? 'password' : 'text'"
            :min="field.min"
            :step="field.step"
            :placeholder="field.placeholder"
          >
          <div v-if="field.help" class="form-text">{{ field.help }}</div>
        </template>
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
    const value = formState[field.key]
    return value === undefined || value === null || String(value).trim() === ''
  })
})

const confirmDisabled = computed(() => Boolean(props.loading || missingRequired.value))

const resetFormState = () => {
  for (const key of Object.keys(formState)) {
    delete formState[key]
  }

  for (const field of formFields.value) {
    const recordValue = getPath(sourceRecord.value, field.key)
    formState[field.key] = recordValue !== undefined && recordValue !== null
      ? normalizeInitialValue(field, recordValue)
      : field.defaultValue !== undefined ? field.defaultValue : normalizeInitialValue(field, recordValue)
  }
}

const normalizeInitialValue = (field: OperationFormField, value: any) => {
  if (field.type === 'checkbox') {
    return Boolean(value)
  }

  if (value === undefined || value === null || typeof value === 'object') {
    return ''
  }

  return value
}

const confirm = () => {
  emit('confirm', reason.value, payloadJson.value, { ...formState })
}

const fieldId = (key: string) => `admin-confirm-${key.replace(/[^a-z0-9_-]/gi, '-')}`

const getPath = (value: any, path: string) => path.split('.').reduce((current, key) => current?.[key], value)

const labelize = (key: string) => key
  .replace(/[._-]/g, ' ')
  .replace(/\b\w/g, (char) => char.toUpperCase()) || key

const formatContextValue = (value: any) => {
  if (value === undefined || value === null || value === '') return '-'
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

watch(() => [props.modelValue, props.payloadTemplate, props.formFields, props.recordContext] as const, () => {
  if (props.modelValue) {
    reason.value = ''
    payloadJson.value = JSON.stringify(props.payloadTemplate || {}, null, 2)
    resetFormState()
  }
}, { immediate: true })
</script>

<template>
  <div class="np-payment-settings">
    <section class="card custom-card np-payment-settings-card">
      <div class="card-header">
        <div>
          <div class="card-title mb-1">{{ phrase('General payment setup') }}</div>
          <p class="text-muted mb-0 fs-12">{{ phrase('Base status, provider mode, and customer-facing payment label.') }}</p>
        </div>
      </div>
      <div class="card-body">
        <div class="row g-3">
          <div
            v-for="field in generalFields"
            :key="field.key"
            :class="field.type === 'textarea' || field.type === 'json' || field.type === 'lines' ? 'col-12' : 'col-md-6 col-xl-4'"
          >
            <div v-if="field.type === 'checkbox'" class="form-check form-switch np-payment-switch">
              <input
                :id="fieldId(field.key)"
                class="form-check-input"
                type="checkbox"
                :checked="Boolean(modelValue[field.key])"
                @change="updateCheckbox(field, $event)"
              >
              <label class="form-check-label" :for="fieldId(field.key)">{{ fieldLabel(field) }}</label>
              <div v-if="field.help" class="form-text">{{ fieldHelpText(field) }}</div>
            </div>
            <template v-else>
              <label class="form-label" :for="fieldId(field.key)">{{ fieldLabel(field) }}</label>
              <select
                v-if="field.type === 'select'"
                :id="fieldId(field.key)"
                class="form-select"
                :value="modelValue[field.key]"
                @change="updateFieldFromEvent(field, $event)"
              >
                <option value="">{{ phrase('Select') }}</option>
                <option v-for="option in field.options || []" :key="optionValue(option)" :value="optionValue(option)">
                  {{ optionLabel(option) }}
                </option>
              </select>
              <textarea
                v-else-if="field.type === 'textarea' || field.type === 'json' || field.type === 'lines'"
                :id="fieldId(field.key)"
                class="form-control"
                rows="3"
                :value="modelValue[field.key]"
                :placeholder="fieldPlaceholder(field)"
                @input="updateFieldFromEvent(field, $event)"
              />
              <input
                v-else
                :id="fieldId(field.key)"
                class="form-control"
                :type="inputType(field)"
                :value="modelValue[field.key]"
                :min="field.min"
                :step="field.step"
                :placeholder="fieldPlaceholder(field)"
                @input="updateFieldFromEvent(field, $event)"
              >
              <div v-if="field.help" class="form-text">{{ fieldHelpText(field) }}</div>
            </template>
          </div>
        </div>
      </div>
      <div class="card-footer np-payment-card-footer">
        <button class="btn btn-light btn-wave" type="button" :disabled="props.loading || props.saving" @click="emit('reset')">{{ phrase('Reset') }}</button>
        <button class="btn btn-primary btn-wave" type="button" :disabled="props.saving" @click="emit('save')">
          <span v-if="props.saving" class="spinner-border spinner-border-sm me-2" />
          {{ phrase('Save') }}
        </button>
      </div>
    </section>

    <div class="np-payment-method-grid">
      <section
        v-for="method in paymentMethodCards"
        :key="method.key"
        class="card custom-card np-payment-method-card"
      >
        <div class="card-body">
          <div class="d-flex align-items-start justify-content-between gap-3 mb-3">
            <div class="d-flex align-items-start gap-3">
              <span class="np-payment-method-icon" :class="method.iconClass">
                <i :class="method.icon" />
              </span>
              <div>
                <h6 class="mb-1">{{ phrase(method.title) }}</h6>
                <p class="text-muted fs-12 mb-0">{{ phrase(method.description) }}</p>
              </div>
            </div>
            <span class="badge" :class="methodEnabled(method.enabledKey) ? 'bg-success-transparent text-success' : 'bg-light text-muted'">
              {{ methodEnabled(method.enabledKey) ? phrase('Enabled') : phrase('Disabled') }}
            </span>
          </div>

          <div class="form-check form-switch np-payment-method-toggle">
            <input
              :id="fieldId(method.enabledKey)"
              class="form-check-input"
              type="checkbox"
              :checked="methodEnabled(method.enabledKey)"
              @change="updateCheckboxByKey(method.enabledKey, $event)"
            >
            <label class="form-check-label" :for="fieldId(method.enabledKey)">
              {{ phrase(method.toggleLabel) }}
            </label>
            <div v-if="fieldHelp(method.enabledKey)" class="form-text">{{ fieldHelp(method.enabledKey) }}</div>
          </div>

          <div v-if="method.fields.length" class="np-payment-method-fields">
            <div v-for="field in method.fields" :key="field.key">
              <label class="form-label" :for="fieldId(field.key)">{{ fieldLabel(field) }}</label>
              <select
                v-if="field.type === 'select'"
                :id="fieldId(field.key)"
                class="form-select"
                :value="modelValue[field.key]"
                @change="updateFieldFromEvent(field, $event)"
              >
                <option value="">{{ phrase('Select') }}</option>
                <option v-for="option in field.options || []" :key="optionValue(option)" :value="optionValue(option)">
                  {{ optionLabel(option) }}
                </option>
              </select>
              <input
                v-else
                :id="fieldId(field.key)"
                class="form-control"
                :type="inputType(field)"
                :value="modelValue[field.key]"
                :placeholder="fieldPlaceholder(field)"
                @input="updateFieldFromEvent(field, $event)"
              >
              <div v-if="field.help" class="form-text">{{ fieldHelpText(field) }}</div>
            </div>
          </div>
        </div>
        <div class="card-footer np-payment-card-footer">
          <button class="btn btn-light btn-wave" type="button" :disabled="props.loading || props.saving" @click="emit('reset')">{{ phrase('Reset') }}</button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="props.saving" @click="emit('save')">
            <span v-if="props.saving" class="spinner-border spinner-border-sm me-2" />
            {{ phrase('Save') }}
          </button>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { OperationFormField, OperationOption } from '~/composables/useAdminOperationsCatalog'

const props = defineProps<{
  fields: OperationFormField[]
  loading?: boolean
  modelValue: Record<string, any>
  saving?: boolean
}>()

const emit = defineEmits<{
  (event: 'reset'): void
  (event: 'save'): void
  (event: 'update:field', payload: { key: string, value: any }): void
}>()

const adminLocale = useAdminLocale()
const phrase = (source: unknown) => adminLocale.phrase(source)

const generalFieldKeys = [
  'status',
  'provider_mode',
  'default_currency',
  'allow_manual_topup',
  'allow_external_payment',
  'payment_provider_status',
  'config.display_name',
]

const fieldMap = computed(() => new Map(props.fields.map((field) => [field.key, field])))

const fieldByKey = (key: string) => fieldMap.value.get(key)

const generalFields = computed(() => generalFieldKeys
  .map((key) => fieldByKey(key))
  .filter((field): field is OperationFormField => Boolean(field)))

const paymentMethodCards = computed(() => [
  {
    key: 'qr',
    enabledKey: 'config.payment_methods.qr.enabled',
    title: 'QR Code topup',
    description: 'Customer can top up by generated QR Code.',
    toggleLabel: fieldByKey('config.payment_methods.qr.enabled')?.label || 'Enable QR Code topup',
    icon: 'ri-qr-code-line',
    iconClass: 'is-primary',
    fields: [],
  },
  {
    key: 'credit-card',
    enabledKey: 'config.payment_methods.credit_card.enabled',
    title: 'Credit card QR topup',
    description: 'Customer can top up through the configured credit card QR provider.',
    toggleLabel: fieldByKey('config.payment_methods.credit_card.enabled')?.label || 'Enable credit card QR topup',
    icon: 'ri-bank-card-line',
    iconClass: 'is-info',
    fields: [],
  },
  {
    key: 'bank-transfer',
    enabledKey: 'config.payment_methods.bank_transfer.enabled',
    title: 'Bank transfer',
    description: 'Customer can upload a transfer slip to the selected bank account.',
    toggleLabel: fieldByKey('config.payment_methods.bank_transfer.enabled')?.label || 'Enable bank transfer topup',
    icon: 'ri-bank-line',
    iconClass: 'is-success',
    fields: [
      fieldByKey('config.bank_transfer.bank_code'),
      fieldByKey('config.bank_transfer.account_name'),
      fieldByKey('config.bank_transfer.account_number'),
    ].filter((field): field is OperationFormField => Boolean(field)),
  },
])

const fieldId = (key: string) => `admin-payment-settings-${key.replace(/[^a-z0-9_-]/gi, '-')}`

const optionValue = (option: OperationOption) => typeof option === 'string' ? option : option.value

const optionLabel = (option: OperationOption) => phrase(typeof option === 'string' ? option : option.label)

const fieldLabel = (field: OperationFormField) => phrase(field.label)

const fieldHelpText = (field: OperationFormField) => phrase(field.help || '')

const fieldPlaceholder = (field: OperationFormField) => phrase(field.placeholder || '')

const inputType = (field: OperationFormField) => {
  if (field.type === 'number' || field.type === 'money' || field.type === 'reward-money') return 'number'
  if (field.type === 'datetime-local') return 'datetime-local'
  if (field.type === 'date') return 'date'
  if (field.type === 'password') return 'password'
  if (field.type === 'color') return 'color'
  return 'text'
}

const updateValue = (field: OperationFormField, value: any) => {
  emit('update:field', { key: field.key, value })
}

const updateFieldFromEvent = (field: OperationFormField, event: Event) => {
  updateValue(field, (event.target as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement).value)
}

const updateCheckbox = (field: OperationFormField, event: Event) => {
  updateValue(field, (event.target as HTMLInputElement).checked)
}

const updateCheckboxByKey = (key: string, event: Event) => {
  emit('update:field', { key, value: (event.target as HTMLInputElement).checked })
}

const methodEnabled = (key: string) => Boolean(props.modelValue[key])

const fieldHelp = (key: string) => phrase(fieldByKey(key)?.help || '')
</script>

<style scoped>
.np-payment-settings {
  display: grid;
  gap: 1.25rem;
  margin-bottom: 1.25rem;
}

.np-payment-settings-card,
.np-payment-method-card {
  border: 1px solid rgba(148, 163, 184, 0.24);
  border-radius: 0.5rem;
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.04);
}

.np-payment-method-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1.25rem;
}

.np-payment-method-card {
  display: flex;
  flex-direction: column;
  min-height: 100%;
}

.np-payment-method-card .card-body {
  flex: 1 1 auto;
}

.np-payment-card-footer {
  align-items: center;
  background: rgba(248, 250, 252, 0.72);
  border-top: 1px solid rgba(148, 163, 184, 0.18);
  display: flex;
  gap: 0.65rem;
  justify-content: flex-end;
  padding: 0.85rem 1rem;
}

.np-payment-method-icon {
  align-items: center;
  border-radius: 0.5rem;
  display: inline-flex;
  flex: 0 0 auto;
  font-size: 1.35rem;
  height: 2.75rem;
  justify-content: center;
  width: 2.75rem;
}

.np-payment-method-icon.is-primary {
  background: rgba(59, 130, 246, 0.12);
  color: #2563eb;
}

.np-payment-method-icon.is-info {
  background: rgba(14, 165, 233, 0.12);
  color: #0284c7;
}

.np-payment-method-icon.is-success {
  background: rgba(34, 197, 94, 0.12);
  color: #16a34a;
}

.np-payment-switch,
.np-payment-method-toggle {
  background: rgba(248, 250, 252, 0.8);
  border: 1px solid rgba(148, 163, 184, 0.18);
  border-radius: 0.5rem;
  margin-top: 0;
  padding: 0.85rem 0.85rem 0.85rem 3rem;
}

.np-payment-method-fields {
  border-top: 1px solid rgba(148, 163, 184, 0.18);
  display: grid;
  gap: 0.85rem;
  margin-top: 1rem;
  padding-top: 1rem;
}

@media (max-width: 1199.98px) {
  .np-payment-method-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 767.98px) {
  .np-payment-method-grid {
    grid-template-columns: 1fr;
  }
}
</style>

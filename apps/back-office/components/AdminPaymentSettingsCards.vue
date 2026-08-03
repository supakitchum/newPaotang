<template>
  <div class="np-payment-settings">
    <section v-if="showProviderSetup" class="card custom-card np-payment-settings-card">
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
                <option value="">{{ phrase(selectEmptyLabel(field)) }}</option>
                <option v-for="option in field.options || []" :key="optionValue(option)" :value="optionValue(option)">
                  {{ optionLabel(option, field) }}
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

    <section v-if="showProviderSetup" class="card custom-card np-payment-settings-card">
      <div class="card-header">
        <div>
          <div class="card-title mb-1">{{ phrase('Provider Connection') }}</div>
          <p class="text-muted mb-0 fs-12">{{ phrase('Connect DeePay KBank before enabling QR Code or Credit QR Code topup.') }}</p>
        </div>
        <span class="badge" :class="deepayReady ? 'bg-success-transparent text-success' : 'bg-warning-transparent text-warning'">
          {{ deepayReady ? phrase('Configured') : phrase('Not configured') }}
        </span>
      </div>
      <div class="card-body">
        <div class="np-provider-connection-grid">
          <div class="np-provider-field">
            <label class="form-label" for="admin-payment-provider-status">{{ phrase('Status') }}</label>
            <select id="admin-payment-provider-status" v-model="deepayStatus" class="form-select" :disabled="deepaySaving || deepayLoading">
              <option value="active">{{ phrase('Active') }}</option>
              <option value="inactive">{{ phrase('Inactive') }}</option>
              <option value="disabled">{{ phrase('Disabled') }}</option>
            </select>
          </div>
          <div class="np-provider-field">
            <label class="form-label" for="admin-payment-provider-api-key">{{ phrase('DeePay KBank x-api-key') }}</label>
            <input
              id="admin-payment-provider-api-key"
              v-model="deepayApiKey"
              class="form-control"
              type="password"
              autocomplete="new-password"
              :placeholder="deepayConnection?.api_key_masked || phrase('Paste x-api-key')"
              :disabled="deepaySaving || deepayLoading"
            >
            <div class="form-text">{{ phrase('Leave blank to keep the existing API key.') }}</div>
          </div>
          <div class="np-provider-field">
            <label class="form-label">{{ phrase('Webhook verification') }}</label>
            <div class="alert alert-warning mb-0 py-2">
              {{ phrase('DeePay callbacks are trusted without a webhook secret and must match an existing payment transaction.') }}
            </div>
          </div>
          <div class="np-provider-callback">
            <span>{{ phrase('Callback URL') }}</span>
            <code>{{ deepayConnection?.callback_url || deepayConnection?.callback_path || '/api/v1/webhooks/topups/deepay_kbank' }}</code>
          </div>
        </div>
        <div v-if="deepayError" class="alert alert-danger mt-3 mb-0 py-2">
          {{ deepayError }}
        </div>
      </div>
      <div class="card-footer np-payment-card-footer">
        <button class="btn btn-light btn-wave" type="button" :disabled="deepayLoading || deepaySaving" @click="loadDeepayConnection">{{ phrase('Refresh') }}</button>
        <button class="btn btn-outline-danger btn-wave" type="button" :disabled="deepayLoading || deepaySaving || !deepayConfigured" @click="deactivateDeepayConnection">{{ phrase('Deactivate') }}</button>
        <button class="btn btn-primary btn-wave" type="button" :disabled="deepaySaving || deepayLoading" @click="saveDeepayConnection">
          <span v-if="deepaySaving" class="spinner-border spinner-border-sm me-2" />
          {{ phrase('Save DeePay connection') }}
        </button>
      </div>
    </section>

    <section v-if="showProviderSetup" class="card custom-card np-payment-settings-card">
      <div class="card-header">
        <div>
          <div class="card-title mb-1">{{ phrase('Payment provider routing') }}</div>
          <p class="text-muted mb-0 fs-12">{{ phrase('Choose which provider generates QR Code and Credit QR Code topup requests.') }}</p>
        </div>
      </div>
      <div class="card-body">
        <div class="row g-3">
          <div v-for="field in providerRoutingFields" :key="field.key" class="col-md-6">
            <label class="form-label" :for="fieldId(field.key)">{{ fieldLabel(field) }}</label>
            <select
              :id="fieldId(field.key)"
              class="form-select"
              :value="modelValue[field.key]"
              @change="updateFieldFromEvent(field, $event)"
            >
              <option value="">{{ phrase(selectEmptyLabel(field)) }}</option>
              <option v-for="option in field.options || []" :key="optionValue(option)" :value="optionValue(option)">
                {{ optionLabel(option, field) }}
              </option>
            </select>
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

    <div v-if="showChannelCards" class="np-payment-method-grid">
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
              :disabled="methodToggleDisabled(method)"
              @change="updateCheckboxByKey(method.enabledKey, $event)"
            >
            <label class="form-check-label" :for="fieldId(method.enabledKey)">
              {{ phrase(method.toggleLabel) }}
            </label>
            <div v-if="methodToggleDisabled(method)" class="form-text text-danger">
              {{ phrase('Select a configured provider before enabling this method.') }}
            </div>
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
                <option value="">{{ phrase(selectEmptyLabel(field)) }}</option>
                <option v-for="option in field.options || []" :key="optionValue(option)" :value="optionValue(option)">
                  {{ optionLabel(option, field) }}
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
import { computed, onMounted, ref, watch } from 'vue'
import type { OperationFormField, OperationOption } from '~/composables/useAdminOperationsCatalog'

const props = defineProps<{
  fields: OperationFormField[]
  loading?: boolean
  mode?: 'channels' | 'provider'
  modelValue: Record<string, any>
  providerOptions?: OperationOption[]
  saving?: boolean
}>()

const emit = defineEmits<{
  (event: 'reset'): void
  (event: 'save'): void
  (event: 'update:field', payload: { key: string, value: any }): void
}>()

const adminLocale = useAdminLocale()
const phrase = (source: unknown) => adminLocale.phrase(source)
const api = useAdminApi()

const deepayConnection = ref<Record<string, any> | null>(null)
const deepayApiKey = ref('')
const deepayStatus = ref('active')
const deepayLoading = ref(false)
const deepaySaving = ref(false)
const deepayError = ref('')

const deepayConfigured = computed(() => Boolean(deepayConnection.value?.configured))
const deepayReady = computed(() => Boolean(deepayConnection.value?.ready))

const generalFieldKeys = [
  'status',
  'provider_mode',
  'default_currency',
  'allow_manual_topup',
  'allow_external_payment',
  'payment_provider_status',
  'config.display_name',
  'config.checkout.external_payment.provider',
  'config.checkout.external_payment.redirect_url_template',
]

const fieldMap = computed(() => new Map(props.fields.map((field) => [field.key, field])))

const fieldByKey = (key: string) => fieldMap.value.get(key)
const showProviderSetup = computed(() => (props.mode || 'channels') === 'provider')
const showChannelCards = computed(() => !showProviderSetup.value)
const providerBackedEnabledKeys = [
  'config.payment_methods.qr.enabled',
  'config.payment_methods.credit_card.enabled',
]

const generalFields = computed(() => generalFieldKeys
  .map((key) => fieldByKey(key))
  .filter((field): field is OperationFormField => Boolean(field)))

const providerConnectionByKey = computed(() => {
  const map = new Map<string, Record<string, any>>()

  for (const option of props.providerOptions || []) {
    if (typeof option === 'string') {
      continue
    }

    map.set(String(option.value), option as Record<string, any>)
  }

  if (deepayConnection.value) {
    map.set('deepay_kbank', {
      ...(map.get('deepay_kbank') || {}),
      ...deepayConnection.value,
    })
  }

  return map
})

const configuredProviderOptions = computed<OperationOption[]>(() => {
  const fromApi = (props.providerOptions || [])
    .filter((option): option is Exclude<OperationOption, string> => typeof option !== 'string')
    .filter((option) => {
      const record = option as Record<string, any>

      return record.ready === true || (record.configured === true && record.status === 'active')
    })

  return fromApi.length > 0 ? fromApi : []
})

const providerField = (key: string) => {
  const field = fieldByKey(key)

  if (!field) {
    return null
  }

  return {
    ...field,
    options: configuredProviderOptions.value,
    emptyOptionLabel: configuredProviderOptions.value.length > 0
      ? field.emptyOptionLabel
      : phrase('No configured providers'),
  }
}

const providerRoutingFields = computed(() => [
  providerField('config.payment_methods.qr.provider'),
  providerField('config.payment_methods.credit_card.provider'),
].filter((field): field is OperationFormField => Boolean(field)))

const providerKeyForEnabledKey = (enabledKey: string) => enabledKey.replace(/\.enabled$/, '.provider')

const selectedReadyProviderForEnabledKey = (enabledKey: string) => {
  const provider = String(props.modelValue[providerKeyForEnabledKey(enabledKey)] || '').trim()

  if (provider === '') {
    return false
  }

  return configuredProviderOptions.value.some((option) => String(optionValue(option)) === provider)
}

const isProviderBackedEnabledKey = (key: string) => providerBackedEnabledKeys.includes(key)

const methodToggleDisabled = (method: { enabledKey: string }) => (
  isProviderBackedEnabledKey(method.enabledKey) && !selectedReadyProviderForEnabledKey(method.enabledKey)
)

const paymentMethodCards = computed(() => [
  {
    key: 'qr',
    enabledKey: 'config.payment_methods.qr.enabled',
    title: 'QR Code topup',
    description: 'Customer can top up by generated QR Code.',
    toggleLabel: fieldByKey('config.payment_methods.qr.enabled')?.label || 'Enable QR Code topup',
    icon: 'ri-qr-code-line',
    iconClass: 'is-primary',
    fields: [
      providerField('config.payment_methods.qr.provider'),
    ].filter((field): field is OperationFormField => Boolean(field)),
  },
  {
    key: 'credit-card',
    enabledKey: 'config.payment_methods.credit_card.enabled',
    title: 'Credit card QR topup',
    description: 'Customer can top up through the configured credit card QR provider.',
    toggleLabel: fieldByKey('config.payment_methods.credit_card.enabled')?.label || 'Enable credit card QR topup',
    icon: 'ri-bank-card-line',
    iconClass: 'is-info',
    fields: [
      providerField('config.payment_methods.credit_card.provider'),
    ].filter((field): field is OperationFormField => Boolean(field)),
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

const optionLabel = (option: OperationOption, field?: OperationFormField) => {
  const label = phrase(typeof option === 'string' ? option : option.label)
  const value = String(optionValue(option))

  if (field?.key?.startsWith('config.payment_methods.') && field.key.endsWith('.provider')) {
    const connection = providerConnectionByKey.value.get(value)
    const isReady = Boolean(connection?.ready || (connection?.configured && connection?.status === 'active'))
    const status = isReady
      ? phrase('Configured')
      : phrase('Not configured')

    return `${label} (${status})`
  }

  return label
}

const fieldLabel = (field: OperationFormField) => phrase(field.label)

const fieldHelpText = (field: OperationFormField) => phrase(field.help || '')

const fieldPlaceholder = (field: OperationFormField) => phrase(field.placeholder || '')

const selectEmptyLabel = (field: OperationFormField) => field.emptyOptionLabel || 'Select'

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

const methodEnabled = (key: string) => Boolean(props.modelValue[key]) && (
  !isProviderBackedEnabledKey(key) || selectedReadyProviderForEnabledKey(key)
)

const fieldHelp = (key: string) => phrase(fieldByKey(key)?.help || '')

const loadDeepayConnection = async () => {
  deepayLoading.value = true
  deepayError.value = ''

  try {
    const response = await api.apiFetch<Record<string, any>>('/admin/tenant/payment-settings/deepay-kbank', {
      scope: 'tenant',
    })
    deepayConnection.value = response || null
    deepayStatus.value = String(response?.status || 'active')
    deepayApiKey.value = ''
  } catch (error: any) {
    deepayError.value = error?.message || phrase('Failed to load provider connection.')
  } finally {
    deepayLoading.value = false
  }
}

const saveDeepayConnection = async () => {
  deepaySaving.value = true
  deepayError.value = ''

  try {
    const response = await api.apiFetch<Record<string, any>>('/admin/tenant/payment-settings/deepay-kbank', {
      method: 'PUT',
      scope: 'tenant',
      idempotencyKey: api.idempotencyKey(),
      body: {
        status: deepayStatus.value,
        api_key: deepayApiKey.value,
      },
    })
    deepayConnection.value = response || null
    deepayStatus.value = String(response?.status || deepayStatus.value || 'active')
    deepayApiKey.value = ''
  } catch (error: any) {
    deepayError.value = error?.message || phrase('Failed to save provider connection.')
  } finally {
    deepaySaving.value = false
  }
}

const deactivateDeepayConnection = async () => {
  deepaySaving.value = true
  deepayError.value = ''

  try {
    const response = await api.apiFetch<Record<string, any>>('/admin/tenant/payment-settings/deepay-kbank', {
      method: 'DELETE',
      scope: 'tenant',
      idempotencyKey: api.idempotencyKey(),
      body: {},
    })
    deepayConnection.value = response || null
    deepayStatus.value = String(response?.status || 'inactive')
    deepayApiKey.value = ''
  } catch (error: any) {
    deepayError.value = error?.message || phrase('Failed to deactivate provider connection.')
  } finally {
    deepaySaving.value = false
  }
}

onMounted(() => {
  if (showProviderSetup.value) {
    void loadDeepayConnection()
  }
})

watch(
  () => [
    props.modelValue['config.payment_methods.qr.enabled'],
    props.modelValue['config.payment_methods.qr.provider'],
    props.modelValue['config.payment_methods.credit_card.enabled'],
    props.modelValue['config.payment_methods.credit_card.provider'],
    configuredProviderOptions.value.map((option) => String(optionValue(option))).join('|'),
  ],
  () => {
    for (const enabledKey of providerBackedEnabledKeys) {
      if (props.modelValue[enabledKey] && !selectedReadyProviderForEnabledKey(enabledKey)) {
        emit('update:field', { key: enabledKey, value: false })
      }
    }
  },
  { immediate: true },
)
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

.np-provider-connection-grid {
  align-items: start;
  display: grid;
  gap: 1rem;
  grid-template-columns: minmax(12rem, 0.9fr) minmax(18rem, 1.6fr);
}

.np-provider-field {
  align-content: start;
  display: grid;
  gap: 0.45rem;
}

.np-provider-field .form-label {
  align-items: center;
  display: flex;
  margin-bottom: 0;
  min-height: 1.25rem;
}

.np-provider-field .form-control,
.np-provider-field .form-select {
  min-height: 2.45rem;
}

.np-provider-callback {
  background: rgba(248, 250, 252, 0.86);
  border: 1px solid rgba(148, 163, 184, 0.18);
  border-radius: 0.5rem;
  display: grid;
  gap: 0.35rem;
  grid-column: 1 / -1;
  padding: 0.75rem 0.85rem;
}

.np-provider-callback span {
  color: #64748b;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
}

.np-provider-callback code {
  color: #0f172a;
  font-size: 0.8rem;
  overflow-wrap: anywhere;
  white-space: normal;
}

@media (max-width: 1199.98px) {
  .np-payment-method-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 767.98px) {
  .np-provider-connection-grid,
  .np-payment-method-grid {
    grid-template-columns: 1fr;
  }
}
</style>

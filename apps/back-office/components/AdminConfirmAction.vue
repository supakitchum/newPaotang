<template>
  <AdminModal :model-value="modelValue" :title="title" @update:model-value="$emit('update:modelValue', $event)">
    <AdminApiState :error="error" />
    <p class="text-muted mb-3">{{ message }}</p>
    <label v-if="requiresPayload" class="form-label">Payload JSON</label>
    <textarea v-if="requiresPayload" v-model="payloadJson" class="form-control np-admin-json-editor mb-3" rows="8" spellcheck="false" />
    <label v-if="requiresReason" class="form-label">Reason</label>
    <textarea v-if="requiresReason" v-model="reason" class="form-control" rows="3" />
    <template #footer>
      <button class="btn btn-light btn-wave" type="button" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary btn-wave" type="button" :disabled="loading" @click="$emit('confirm', reason, payloadJson)">
        <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
        Confirm
      </button>
    </template>
  </AdminModal>
</template>

<script setup lang="ts">
const props = defineProps<{
  modelValue: boolean
  title: string
  message: string
  requiresReason?: boolean
  requiresPayload?: boolean
  payloadTemplate?: Record<string, any> | null
  loading?: boolean
  error?: any
}>()

defineEmits<{
  'update:modelValue': [value: boolean]
  confirm: [reason: string, payloadJson: string]
}>()

const reason = ref('')
const payloadJson = ref('')

watch(() => [props.modelValue, props.payloadTemplate] as const, () => {
  if (props.modelValue) {
    reason.value = ''
    payloadJson.value = JSON.stringify(props.payloadTemplate || {}, null, 2)
  }
}, { immediate: true })
</script>

<template>
  <div v-if="message" :class="['alert', `alert-${type}`, 'alert-dismissible', 'fade', 'show']" role="alert">
    <i :class="['me-2', icon]" />
    <span>{{ message }}</span>
    <button v-if="dismissible" type="button" class="btn-close" aria-label="Close" @click="$emit('dismiss')" />
    <div v-if="detailsText" class="small mt-2 opacity-75">{{ detailsText }}</div>
  </div>
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  type?: string
  message?: string | null
  details?: any
  dismissible?: boolean
}>(), {
  type: 'primary',
  message: null,
  details: null,
  dismissible: false,
})

defineEmits(['dismiss'])

const icon = computed(() => {
  const icons: Record<string, string> = {
    danger: 'ri-error-warning-line',
    warning: 'ri-alert-line',
    success: 'ri-checkbox-circle-line',
    info: 'ri-information-line',
    primary: 'ri-information-line',
  }
  return icons[props.type] || icons.primary
})

const detailsText = computed(() => {
  const fields = props.details?.fields
  if (!fields || typeof fields !== 'object') {
    return ''
  }

  return Object.entries(fields)
    .map(([field, messages]) => `${field}: ${Array.isArray(messages) ? messages.join(', ') : messages}`)
    .join(' | ')
})
</script>

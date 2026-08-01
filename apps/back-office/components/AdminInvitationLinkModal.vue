<template>
  <AdminModal
    :model-value="modelValue"
    title="Admin invitation link"
    size="lg"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="d-flex align-items-start gap-3 mb-4">
      <span class="avatar avatar-lg bg-primary-transparent text-primary flex-shrink-0">
        <i class="ri-user-add-line fs-4" />
      </span>
      <div>
        <h6 class="mb-1">Share this link with the admin</h6>
        <p class="text-muted mb-0">The recipient will create their own password. The link can be used once and replaces email invitations.</p>
      </div>
    </div>

    <dl class="row mb-3">
      <dt class="col-sm-3 text-muted fw-normal">Username</dt>
      <dd class="col-sm-9 fw-semibold mb-2">{{ username || '-' }}</dd>
      <dt class="col-sm-3 text-muted fw-normal">Expires</dt>
      <dd class="col-sm-9 mb-0">{{ formattedExpiry }}</dd>
    </dl>

    <label class="form-label">Invitation link</label>
    <div class="input-group">
      <input class="form-control font-monospace" :value="url" type="text" readonly @focus="selectInput">
      <button class="btn btn-primary" type="button" :disabled="!url" @click="copyLink">
        <i class="ri-file-copy-line me-1" />
        Copy
      </button>
    </div>
    <p v-if="feedback" class="small mt-2 mb-0" :class="feedbackError ? 'text-danger' : 'text-success'">{{ feedback }}</p>

    <template #footer>
      <button
        v-if="canShare"
        class="btn btn-outline-primary btn-wave"
        type="button"
        :disabled="!url"
        @click="shareLink"
      >
        <i class="ri-share-forward-line me-1" />
        Share
      </button>
      <button class="btn btn-light btn-wave" type="button" @click="$emit('update:modelValue', false)">Close</button>
    </template>
  </AdminModal>
</template>

<script setup lang="ts">
const props = defineProps<{
  modelValue: boolean
  url: string
  username?: string
  expiresAt?: string
}>()

defineEmits<{
  'update:modelValue': [value: boolean]
}>()

const feedback = ref('')
const feedbackError = ref(false)
const canShare = computed(() => import.meta.client && typeof navigator.share === 'function')
const formattedExpiry = computed(() => {
  if (!props.expiresAt) return '-'
  const date = new Date(props.expiresAt)
  return Number.isNaN(date.getTime()) ? props.expiresAt : date.toLocaleString()
})

watch(() => props.modelValue, () => {
  feedback.value = ''
  feedbackError.value = false
})

const copyLink = async () => {
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(props.url)
    } else {
      fallbackCopy(props.url)
    }
    feedback.value = 'Invitation link copied.'
    feedbackError.value = false
  } catch {
    feedback.value = 'Could not copy the link. Select it and copy manually.'
    feedbackError.value = true
  }
}

const fallbackCopy = (value: string) => {
  const textarea = document.createElement('textarea')
  textarea.value = value
  textarea.style.position = 'fixed'
  textarea.style.opacity = '0'
  document.body.appendChild(textarea)
  textarea.select()
  const copied = document.execCommand('copy')
  textarea.remove()

  if (!copied) {
    throw new Error('Copy failed')
  }
}

const selectInput = (event: FocusEvent) => {
  if (event.target instanceof HTMLInputElement) {
    event.target.select()
  }
}

const shareLink = async () => {
  try {
    await navigator.share({
      title: 'Admin invitation',
      text: props.username ? `Admin invitation for ${props.username}` : 'Admin invitation',
      url: props.url,
    })
  } catch (error: any) {
    if (error?.name !== 'AbortError') {
      feedback.value = 'Could not open the share menu.'
      feedbackError.value = true
    }
  }
}
</script>

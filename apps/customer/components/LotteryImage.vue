<template>
  <figure class="lottery-image" :class="[`lottery-image-${variant}`, { 'has-image': showImage }]">
    <img
      v-if="showImage"
      :src="displaySrc"
      :alt="altText"
      loading="lazy"
      decoding="async"
      @error="hasImageError = true"
    >
    <figcaption v-else class="lottery-image-fallback">
      <i :class="fallbackIcon" aria-hidden="true" />
      <span>{{ fallbackText }}</span>
    </figcaption>
  </figure>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'

const props = withDefaults(defineProps<{
  src?: string | null
  thumbSrc?: string | null
  status?: string | null
  errorMessage?: string | null
  alt?: string
  number?: string | number | null
  variant?: 'card' | 'stub' | 'preview'
}>(), {
  src: '',
  thumbSrc: '',
  status: '',
  errorMessage: '',
  alt: '',
  number: '',
  variant: 'card'
})

const hasImageError = ref(false)

const normalizeUrl = (value: string | null | undefined) => {
  const url = String(value || '').trim()

  if (!url) {
    return ''
  }

  if (/^https?:\/\//i.test(url) || url.startsWith('data:')) {
    return url
  }

  return url.startsWith('/') ? url : `/${url.replace(/^\/+/, '')}`
}

const displaySrc = computed(() => normalizeUrl(props.thumbSrc || props.src))
const normalizedStatus = computed(() => String(props.status || '').toLowerCase())
const showImage = computed(() => Boolean(displaySrc.value) && !hasImageError.value && !['pending_assets', 'failed', 'missing'].includes(normalizedStatus.value))
const altText = computed(() => props.alt || `รูปสลากฯ เลข ${props.number || ''}`.trim())
const fallbackIcon = computed(() => {
  if (normalizedStatus.value === 'pending_assets') {
    return 'bi bi-hourglass-split'
  }

  if (normalizedStatus.value === 'failed' || hasImageError.value) {
    return 'bi bi-image'
  }

  return 'bi bi-ticket-perforated'
})
const fallbackText = computed(() => {
  if (hasImageError.value) {
    return 'โหลดรูปสลากฯ ไม่สำเร็จ'
  }

  if (normalizedStatus.value === 'pending_assets') {
    return 'กำลังเตรียมรูปสลากฯ'
  }

  if (normalizedStatus.value === 'failed') {
    return props.errorMessage || 'รูปสลากฯ ยังไม่พร้อม'
  }

  return 'รอรูปสลากฯ'
})

watch(() => [props.src, props.thumbSrc, props.status], () => {
  hasImageError.value = false
})
</script>

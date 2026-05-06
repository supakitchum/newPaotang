<template>
  <span class="ticket-number" :class="{ compact }">
    <span
      v-for="(digit, index) in digits"
      :key="index"
      :class="{ faded: isFaded(index) }"
    >{{ digit }}</span>
  </span>
</template>

<script setup lang="ts">
const props = defineProps({
  number: {
    type: String,
    required: true
  },
  highlight: {
    type: String,
    default: ''
  },
  highlightDigits: {
    type: Array as () => Array<string | null>,
    default: null
  },
  compact: {
    type: Boolean,
    default: false
  }
})

const digits = computed(() => props.number.split(''))
const fadedUntil = computed(() => {
  if (!props.highlight || !props.number.endsWith(props.highlight)) return 0
  return props.number.length - props.highlight.length
})
const hasHighlightDigits = computed(() => Array.isArray(props.highlightDigits) && props.highlightDigits.some(Boolean))
const isFaded = (index: number) => {
  if (hasHighlightDigits.value) {
    return props.highlightDigits[index] !== digits.value[index]
  }

  return fadedUntil.value > index
}
</script>

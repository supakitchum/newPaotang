<template>
  <div class="draw-number-row">
    <label
      v-for="(_, index) in normalizedDigits"
      :key="index"
      class="draw-box"
      :class="{ filled: values[index] }"
    >
      <input
        ref="digitInputs"
        v-model="values[index]"
        class="draw-box-input"
        inputmode="numeric"
        pattern="[0-9]*"
        maxlength="1"
        type="text"
        :aria-label="`เลขหลักที่ ${index + 1}`"
        @beforeinput="handleBeforeInput"
        @focus="handleInputFocus"
        @input="handleInput($event, index)"
        @keydown="handleKeydown($event, index)"
        @paste="handlePaste($event, index)"
        @pointerdown="handleInputPointerDown"
      >
      <span class="draw-box-visual" aria-hidden="true">
        {{ values[index] || index + 1 }}
      </span>
    </label>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'

const props = defineProps({
  digits: {
    type: Array as () => Array<string | number>,
    default: () => ['', '', '', '', '', '']
  },
  filled: {
    type: Boolean,
    default: false
  }
})
const emit = defineEmits<{
  'update:digits': [digits: string[]]
  change: [digits: string[]]
}>()

const normalizedDigits = computed(() => {
  const digits = props.digits.slice(0, 6)
  return Array.from({ length: 6 }, (_, index) => String(digits[index] ?? ''))
})

const values = ref<string[]>([])
const digitInputs = ref<HTMLInputElement[]>([])
const route = useRoute()
const isStoreLotteryRoute = computed(() => route.path === '/stores/lotteries')
const shouldRedirectToSearch = computed(() => route.path === '/' || route.path === '/buy' || isStoreLotteryRoute.value)

const resetValues = () => {
  values.value = normalizedDigits.value.map((digit) => props.filled ? digit.replace(/\D/g, '').slice(0, 1) : '')
}

const focusInput = async (index: number) => {
  await nextTick()
  digitInputs.value[index]?.focus()
  digitInputs.value[index]?.select()
}

const fillDigits = (rawValue: string, startIndex: number) => {
  const digits = rawValue.replace(/\D/g, '').slice(0, values.value.length - startIndex)

  if (!digits) {
    values.value[startIndex] = ''
    emitDigits()
    return
  }

  digits.split('').forEach((digit, offset) => {
    values.value[startIndex + offset] = digit
  })

  emitDigits()

  const nextIndex = Math.min(startIndex + digits.length, values.value.length - 1)
  if (startIndex + digits.length < values.value.length) {
    focusInput(nextIndex)
  } else {
    digitInputs.value[nextIndex]?.blur()
  }
}

const handleBeforeInput = (event: InputEvent) => {
  if (event.data && !/^\d+$/.test(event.data)) {
    event.preventDefault()
  }
}

const emitDigits = () => {
  const digits = values.value.slice(0, 6)
  emit('update:digits', digits)
  emit('change', digits)
}

const redirectToSearch = () => {
  if (!shouldRedirectToSearch.value) {
    return
  }

  if (isStoreLotteryRoute.value) {
    navigateTo({
      path: '/buy/search',
      query: {
        store_id: route.query.store_id
      }
    })
    return
  }

  navigateTo('/buy/search')
}

const handleInputPointerDown = (event: PointerEvent) => {
  if (!shouldRedirectToSearch.value) {
    return
  }

  event.preventDefault()
  redirectToSearch()
}

const handleInputFocus = (event: FocusEvent) => {
  if (!shouldRedirectToSearch.value) {
    return
  }

  const input = event.target as HTMLInputElement
  input.blur()
  redirectToSearch()
}

const handleInput = (event: Event, index: number) => {
  const input = event.target as HTMLInputElement
  fillDigits(input.value, index)
}

const handlePaste = (event: ClipboardEvent, index: number) => {
  event.preventDefault()
  fillDigits(event.clipboardData?.getData('text') ?? '', index)
}

const handleKeydown = (event: KeyboardEvent, index: number) => {
  if (event.key === 'Backspace' && !values.value[index] && index > 0) {
    values.value[index - 1] = ''
    emitDigits()
    focusInput(index - 1)
    return
  }

  if (event.key === 'ArrowLeft' && index > 0) {
    event.preventDefault()
    focusInput(index - 1)
    return
  }

  if (event.key === 'ArrowRight' && index < values.value.length - 1) {
    event.preventDefault()
    focusInput(index + 1)
  }
}

watch(() => [props.digits, props.filled], resetValues, { immediate: true, deep: true })
</script>

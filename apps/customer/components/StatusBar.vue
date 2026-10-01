<template>
  <div class="status-bar">
    <div>{{ currentTime }}</div>
    <div class="status-icons">
      <i class="bi bi-people-fill" /> {{ onlineCount }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

defineProps({
  time: {
    type: String,
    default: '12:29'
  }
})

const { onlineCount } = useCustomerPresence()
const now = ref(new Date())
let clockTimer: ReturnType<typeof setInterval> | null = null

const currentTime = computed(() => {
  const date = now.value
  const hours = String(date.getHours()).padStart(2, '0')
  const minutes = String(date.getMinutes()).padStart(2, '0')

  return `${hours}:${minutes}`
})

onMounted(() => {
  now.value = new Date()
  clockTimer = window.setInterval(() => {
    now.value = new Date()
  }, 1000)
})

onBeforeUnmount(() => {
  if (clockTimer !== null) {
    window.clearInterval(clockTimer)
    clockTimer = null
  }
})
</script>

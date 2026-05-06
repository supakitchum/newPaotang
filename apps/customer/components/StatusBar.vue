<template>
  <div class="status-bar">
    <div>{{ new Date().toTimeString().slice(0, 5) }}</div>
    <div class="status-icons">
      <i class="bi bi-people-fill" /> 200
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps({
  time: {
    type: String,
    default: '12:29'
  }
})
</script>

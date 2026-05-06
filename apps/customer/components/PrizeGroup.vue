<template>
  <section class="prize-group">
    <div class="result-bar">
      <span>{{ title }}</span>
      <span class="muted-text">รางวัลละ {{ amount }} บาท</span>
    </div>
    <div class="result-number-grid">
      <div v-for="number in numbers" :key="number" class="result-number small">
        {{ number }}
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  title: string
  amount: string
  numbers: string[]
}>()
</script>

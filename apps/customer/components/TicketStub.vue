<template>
  <article class="ticket-stub">
    <div class="ticket-stub-mark">
      <span class="lottery-six">L6</span>
    </div>
    <div class="ticket-stub-body">
      <div class="ticket-brand mb-2">
        <span>สลากกินแบ่งรัฐบาล</span>
      </div>
      <LotteryNumber :number="number" compact />
    </div>
    <div class="text-end muted-text fw-semibold small">{{ status }}</div>
    <span class="side-label">สลากดิจิทัล</span>
  </article>
</template>

<script setup lang="ts">
defineProps({
  number: {
    type: String,
    required: true
  },
  status: {
    type: String,
    default: ''
  }
})
</script>

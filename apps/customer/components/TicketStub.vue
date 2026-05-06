<template>
  <article class="ticket-stub">
    <div class="text-center text-danger fw-bold">
      <div class="fs-4">80</div>
      <div class="tiny-label">บาท</div>
    </div>
    <div>
      <div class="ticket-brand mb-2">
        <span class="lottery-six">L6</span>
        <span>สลากกินแบ่งรัฐบาล</span>
      </div>
      <LotteryNumber :number="number" compact />
    </div>
    <div class="d-flex gap-3">
      <span>
        <span class="tiny-label">งวดที่</span>
        <span class="tiny-value">{{ draw }}</span>
      </span>
      <span>
        <span class="tiny-label">ชุดที่</span>
        <span class="tiny-value">{{ set }}</span>
      </span>
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
  draw: {
    type: [String, Number],
    default: 57
  },
  set: {
    type: [String, Number],
    default: 20
  },
  status: {
    type: String,
    default: ''
  }
})
</script>

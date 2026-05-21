<template>
  <article class="ticket-stub">
    <LotteryImage
      :src="imageUrl"
      :thumb-src="imageThumbUrl"
      :status="imageStatus"
      :error-message="imageError"
      :number="number"
      variant="stub"
    />
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
  },
  imageUrl: {
    type: String,
    default: ''
  },
  imageThumbUrl: {
    type: String,
    default: ''
  },
  imageStatus: {
    type: String,
    default: ''
  },
  imageError: {
    type: String,
    default: ''
  }
})
</script>

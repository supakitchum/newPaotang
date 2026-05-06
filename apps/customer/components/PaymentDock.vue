<template>
  <div class="payment-dock" :class="`payment-dock-${variant}`">
    <template v-if="variant === 'selection'">
      <div>
        <div class="fw-semibold">คุณมีสลากฯ ที่เลือกไว้</div>
        <div class="selection-count"><span>{{ count }}</span> ใบ</div>
      </div>
      <NuxtLink class="selection-pay-button" :to="to">
        <span>{{ button }}</span>
        <small v-if="timer">{{ timer }} นาที</small>
      </NuxtLink>
    </template>

    <template v-else-if="variant === 'review'">
      <div class="review-payment-timer">
        กรุณาชำระเงินภายใน <span>{{ timer }}</span> นาที
      </div>
      <div class="review-payment-row">
        <div>
          <div class="review-payment-label">{{ label }}</div>
          <div class="review-payment-count"><span>{{ count }}</span> ใบ</div>
        </div>
        <NuxtLink class="review-payment-button" :to="to">
          {{ button }}
        </NuxtLink>
      </div>
    </template>

    <template v-else>
    <div class="text-center fw-semibold mb-3">
      กรุณาชำระเงินภายใน <span class="text-primary">{{ timer }}</span> นาที
    </div>
    <div class="d-flex align-items-center justify-content-between mb-3">
      <span class="muted-text fw-medium">{{ label }}</span>
      <span class="fw-medium"><span class="fs-3 fw-bold text-primary">{{ amount }}</span> บาท</span>
    </div>
    <NuxtLink class="primary-pill w-100 d-grid place-center text-center py-3" :to="to">
      {{ button }}
    </NuxtLink>
    </template>
  </div>
</template>

<script setup lang="ts">
defineProps({
  timer: {
    type: String,
    default: '11'
  },
  amount: {
    type: [String, Number],
    default: 80
  },
  label: {
    type: String,
    default: 'ยอดชำระทั้งหมด'
  },
  button: {
    type: String,
    default: 'ชำระเงิน'
  },
  to: {
    type: String,
    default: '/checkout'
  },
  count: {
    type: [String, Number],
    default: 1
  },
  variant: {
    type: String,
    default: 'default'
  }
})
</script>

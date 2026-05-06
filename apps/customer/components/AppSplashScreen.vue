<template>
  <div
    v-if="shouldShow"
    class="app-splash"
    :class="{ 'is-leaving': isLeaving }"
    role="status"
    aria-live="polite"
  >
    <div class="app-splash-inner">
      <BrandLogo />
      <div class="app-splash-mark">L6</div>
      <div class="app-splash-loader" aria-hidden="true">
        <span />
      </div>
      <p>กำลังเตรียมข้อมูลระบบ</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'

const MIN_SPLASH_MS = 650
const SPLASH_FADE_MS = 260

const { isReady } = useAppInit()
const canHide = ref(false)
const isLeaving = ref(false)
const shouldRender = ref(true)
const shouldShow = computed(() => shouldRender.value && (!isReady.value || !canHide.value || isLeaving.value))

const closeSplash = () => {
  if (!isReady.value || !canHide.value || isLeaving.value) {
    return
  }

  isLeaving.value = true

  setTimeout(() => {
    shouldRender.value = false
  }, SPLASH_FADE_MS)
}

onMounted(() => {
  setTimeout(() => {
    canHide.value = true
    closeSplash()
  }, MIN_SPLASH_MS)

  watch(isReady, closeSplash, {
    immediate: true
  })
})
</script>

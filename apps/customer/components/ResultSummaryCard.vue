<template>
  <section class="result-card" :class="`result-card-${variant}`">
    <div v-if="variant === 'history'" class="result-card-history-head">
      <div>
        <div class="muted-text">งวดวันที่</div>
        <div class="result-history-date">{{ formattedDate }}</div>
      </div>
      <NuxtLink v-if="link" :to="link" class="result-card-link" aria-label="ดูผลรางวัลแบบเต็ม">
        <i class="bi bi-chevron-right" />
      </NuxtLink>
    </div>

    <div v-else class="d-flex align-items-center justify-content-between mb-3">
      <div>
        <h2 class="section-title fs-5">
          ผลรางวัลสลากฯ
          <NuxtLink class="result-info-link" to="/term-reward" aria-label="เงื่อนไขเงินรางวัล">
            <i class="bi bi-info-circle ms-1 fs-6 text-secondary" />
          </NuxtLink>
        </h2>
        <div class="muted-text">งวดวันที่ <strong v-if="variant === 'featured'" class="result-card-date">{{ formattedDate }}</strong><template v-else>{{ formattedDate }}</template></div>
      </div>
      <NuxtLink v-if="link" :to="link" class="result-card-link" aria-label="ดูผลรางวัลแบบเต็ม">
        <i class="bi bi-chevron-right" />
      </NuxtLink>
    </div>

    <div v-if="variant === 'history'" class="result-card-divider" />

    <div class="row g-3">
      <div class="col-7">
        <div class="muted-text">รางวัลที่ 1</div>
        <div class="result-number">{{ result.first }}</div>
      </div>
      <div class="col-5">
        <div class="muted-text">เลขท้าย 2 ตัว</div>
        <div class="result-number">{{ result.last2 }}</div>
      </div>
      <div class="col-7">
        <div class="muted-text">เลขหน้า 3 ตัว</div>
        <div class="result-number small">{{ result.front3.join(' ') }}</div>
      </div>
      <div class="col-5">
        <div class="muted-text">เลขท้าย 3 ตัว</div>
        <div class="result-number small">{{ result.last3.join(' ') }}</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { formatDrawDateText } from '~/utils/formatDrawDate'

const props = withDefaults(defineProps<{
  date: string
  link?: string
  variant?: 'default' | 'featured' | 'history'
  result: {
    first: string
    front3: string[]
    last2: string
    last3: string[]
  }
}>(), {
  variant: 'default'
})

const formattedDate = computed(() => formatDrawDateText(props.date))
</script>

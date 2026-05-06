<template>
  <MobileShell time="12:36">
    <BlueHeader title="ผลรางวัลสลากฯ" back-to="/" min-height="386px" class="results-index-hero">
      <ResultSummaryCard :date="resultDate" :result="currentResults" link="/results/full" variant="featured" />
    </BlueHeader>
    <section class="results-history-sheet">
      <h2 class="section-title fs-5 mb-4">ผลรางวัลสลากฯ ย้อนหลัง</h2>
      <ResultSummaryCard
        v-for="result in pastResults"
        :key="result.date"
        :date="result.date"
        :result="result"
        link="/results/full"
        variant="history"
        class="mb-4"
      />
      <div class="payment-dock text-center muted-text">
        คุณสามารถขึ้นเงินรางวัลได้ที่ ธนาคารกรุงไทย ธ.ก.ส. ออมสิน ทุกสาขา หรือสำนักงานสลากกินแบ่งรัฐบาล
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { currentResults, pastResults, resultDate } from '~/data/lottery'

definePageMeta({
  requiresAuth: false
})
</script>

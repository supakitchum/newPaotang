<template>
  <MobileShell time="12:38">
    <BlueHeader
      :title="`ผลรางวัลงวดวันที่ ${formatDrawDateText(resultDate)}`"
      back-to="/results"
      min-height="121px"
      class="result-full-hero"
    />
    <section class="content-sheet result-full-sheet">
      <div class="result-highlight-grid">
        <div>
          <div class="result-label">รางวัลที่ 1</div>
          <div class="result-subtitle">รางวัลละ 6,000,000 บาท</div>
          <div class="result-number result-first">{{ currentResults.first }}</div>
        </div>
        <div>
          <div class="result-label">เลขท้าย 2 ตัว</div>
          <div class="result-subtitle">รางวัลละ 2,000 บาท</div>
          <div class="result-number result-first">{{ currentResults.last2 }}</div>
        </div>
        <div>
          <div class="result-label">เลขหน้า 3 ตัว</div>
          <div class="result-subtitle">รางวัลละ 4,000 บาท</div>
          <div class="result-number small">{{ currentResults.front3.join(' ') }}</div>
        </div>
        <div>
          <div class="result-label">เลขท้าย 3 ตัว</div>
          <div class="result-subtitle">รางวัลละ 4,000 บาท</div>
          <div class="result-number small">{{ currentResults.last3.join(' ') }}</div>
        </div>
      </div>

      <section class="result-bar">
        <span>รางวัลข้างเคียงรางวัลที่ 1</span>
        <span class="muted-text">รางวัลละ 100,000 บาท</span>
      </section>
      <div class="result-number-grid result-number-grid-pair">
        <span v-for="number in currentResults.nearFirst" :key="number">{{ number }}</span>
      </div>

      <PrizeGroup title="รางวัลที่ 2" amount="200,000" :numbers="currentResults.second" />
      <PrizeGroup title="รางวัลที่ 3" amount="80,000" :numbers="currentResults.third" />

      <div class="payment-dock text-center muted-text">
        คุณสามารถขึ้นเงินรางวัลได้ที่ ธนาคารกรุงไทย ธ.ก.ส. ออมสิน ทุกสาขา หรือสำนักงานสลากกินแบ่งรัฐบาล
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { currentResults, resultDate } from '~/data/lottery'
import { formatDrawDateText } from '~/utils/formatDrawDate'
</script>

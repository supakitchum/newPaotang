<template>
  <MobileShell time="14:12">
    <BlueHeader title="เงื่อนไขเงินรางวัล" back-to="/" min-height="176px" class="term-reward-hero" />
    <section class="content-sheet term-reward-sheet">
      <div class="term-reward-logo">
        <span>GLO</span>
        <small>สำนักงานสลากกินแบ่งรัฐบาล<br>THE GOVERNMENT LOTTERY OFFICE</small>
      </div>

      <h1>รายละเอียดเงินรางวัล</h1>
      <p>
        สลากดิจิทัลหกหลักแบบดิจิทัล 1 ชุด มี 1 ล้านฉบับ<br>
        ฉบับละ 80 บาท โดยมีเงินรางวัลต่อชุด ดังนี้
      </p>

      <div class="reward-table">
        <div class="reward-row reward-head">
          <div>ประเภทรางวัล</div>
          <div>จำนวน</div>
          <div>มูลค่ารางวัลละ</div>
        </div>
        <div v-for="item in rewardRows" :key="item.title" class="reward-row">
          <div class="reward-title">{{ item.title }}</div>
          <div>{{ item.count }}</div>
          <div>{{ item.amount }}</div>
        </div>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: false
})

const rewardRows = [
  { title: 'รางวัลที่ 1', count: '1 รางวัล', amount: '6,000,000 บาท' },
  { title: 'รางวัลที่ 2', count: '5 รางวัล', amount: '200,000 บาท' },
  { title: 'รางวัลที่ 3', count: '10 รางวัล', amount: '80,000 บาท' },
  { title: 'รางวัลที่ 4', count: '50 รางวัล', amount: '40,000 บาท' },
  { title: 'รางวัลที่ 5', count: '100 รางวัล', amount: '20,000 บาท' },
  { title: 'รางวัลข้างเคียง\nรางวัลที่ 1', count: '2 รางวัล', amount: '100,000 บาท' },
  { title: 'เลขหน้า 3 ตัว', count: 'เสี่ยง 2 ครั้ง\n2,000 รางวัล', amount: '4,000 บาท' },
  { title: 'เลขท้าย 3 ตัว', count: 'เสี่ยง 2 ครั้ง\n2,000 รางวัล', amount: '4,000 บาท' },
  { title: 'เลขท้าย 2 ตัว', count: 'เสี่ยง 1 ครั้ง\n10,000 รางวัล', amount: '2,000 บาท' }
]
</script>

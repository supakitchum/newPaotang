<template>
  <MobileShell active-nav="menu">
    <BlueHeader class="lottery-knowledge-hero" title="ข้อควรรู้การซื้อ-ขายสลากฯ" back-to="/profile" min-height="340px">
      <div class="lottery-knowledge-brand">
        <BrandLogo />
        <h2>ข้อควรรู้การซื้อ-ขายสลากฯ</h2>
      </div>
    </BlueHeader>

    <section class="content-sheet flush lottery-knowledge-sheet">
      <div class="lottery-knowledge-stack">
        <article v-for="section in knowledgeSections" :key="section.title" class="lottery-knowledge-card">
          <h3>{{ section.title }}</h3>
          <ol class="lottery-knowledge-list">
            <li v-for="item in section.items" :key="item">
              <span class="lottery-knowledge-number">{{ itemNumber(section.items, item) }}</span>
              <span>{{ item }}</span>
            </li>
          </ol>
        </article>

        <footer class="lottery-knowledge-more">
          <p>ศึกษารายละเอียดเพิ่มเติม ได้ที่</p>
          <a href="https://www.glo.or.th" target="_blank" rel="noopener noreferrer">www.glo.or.th</a>
          <span>หรือโทร <a href="tel:025289682">02-528-9682</a></span>
        </footer>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: false
})

const knowledgeSections = [
  {
    title: 'สลากหกหลักแบบดิจิทัล',
    items: [
      'ห้ามนำสลากหกหลักแบบดิจิทัลไปขายต่อผ่านช่องทางอื่น',
      'ผู้ซื้อมีสิทธิ์หรือเป็นเจ้าของสลากหกหลักแบบดิจิทัลเมื่อทำรายการซื้อสำเร็จและไม่สามารถโอนสิทธิ์ให้กับผู้อื่นได้',
      'การซื้อสลากหกหลักแบบดิจิทัล ผ่านแอปฯ เป๋าตัง ช่วยป้องกันการถูกฉ้อโกงจากมิจฉาชีพ'
    ]
  },
  {
    title: 'สำหรับผู้จำหน่ายสลากกินแบ่งรัฐบาล',
    items: [
      'ห้ามขายสลากฯ ในราคาเกินกว่าที่สำนักงานสลากกินแบ่งรัฐบาลกำหนด',
      'ห้ามขายสลากฯ ในสถานศึกษา',
      'ห้ามขายสลากฯ ให้แก่บุคคลที่มีอายุต่ำกว่า 20 ปีบริบูรณ์'
    ]
  }
]

const itemNumber = (items: string[], item: string) => String(items.indexOf(item) + 1)

useTenantSeo({
  title: 'ข้อควรรู้การซื้อ-ขายสลากฯ',
  description: 'ข้อควรรู้สำหรับการซื้อและจำหน่ายสลากหกหลักแบบดิจิทัล',
  canonicalPath: '/lottery-knowledge'
})
</script>

<style scoped>
.lottery-knowledge-hero {
  padding-bottom: 112px;
}

.lottery-knowledge-brand {
  display: grid;
  justify-items: center;
  gap: 28px;
  padding-top: 28px;
  text-align: center;
}

.lottery-knowledge-brand :deep(.brand-lockup) {
  transform: scale(1.48);
  transform-origin: center;
}

.lottery-knowledge-brand :deep(.brand-logo-image) {
  max-width: 128px;
  height: 46px;
  object-position: center;
}

.lottery-knowledge-brand h2 {
  margin: 0;
  color: #fff;
  font-size: 29px;
  font-weight: 900;
  line-height: 1.22;
}

.lottery-knowledge-sheet {
  margin-top: -88px;
  padding: 0 18px calc(42px + env(safe-area-inset-bottom));
  background: transparent;
  border-radius: 0;
}

.lottery-knowledge-stack {
  display: grid;
  gap: 24px;
}

.lottery-knowledge-card {
  padding: 28px 26px;
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 12px 32px rgba(15, 88, 165, .11);
  color: var(--app-ink);
}

.lottery-knowledge-card h3 {
  margin: 0 0 24px;
  color: #252f3f;
  font-size: 24px;
  font-weight: 900;
  line-height: 1.3;
}

.lottery-knowledge-list {
  display: grid;
  gap: 28px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.lottery-knowledge-list li {
  display: grid;
  grid-template-columns: 42px minmax(0, 1fr);
  gap: 18px;
  align-items: flex-start;
  color: #2f3746;
  font-size: 22px;
  font-weight: 800;
  line-height: 1.55;
}

.lottery-knowledge-number {
  display: inline-grid;
  width: 34px;
  height: 34px;
  place-items: center;
  margin-top: 3px;
  border-radius: 50%;
  background: #086bcf;
  color: #fff;
  font-size: 18px;
  font-weight: 900;
  line-height: 1;
}

.lottery-knowledge-more {
  display: grid;
  justify-items: center;
  gap: 4px;
  padding: 4px 12px 0;
  color: #4b5565;
  font-size: 20px;
  font-weight: 800;
  line-height: 1.45;
  text-align: center;
}

.lottery-knowledge-more p {
  margin: 0;
}

.lottery-knowledge-more a {
  color: #096fd8;
  font-weight: 900;
  text-decoration: none;
}

@media (max-width: 390px) {
  .lottery-knowledge-hero {
    padding-bottom: 96px;
  }

  .lottery-knowledge-brand h2 {
    font-size: 25px;
  }

  .lottery-knowledge-sheet {
    margin-top: -80px;
    padding-right: 14px;
    padding-left: 14px;
  }

  .lottery-knowledge-card {
    padding: 24px 22px;
  }

  .lottery-knowledge-card h3 {
    font-size: 21px;
  }

  .lottery-knowledge-list li {
    grid-template-columns: 38px minmax(0, 1fr);
    gap: 14px;
    font-size: 19px;
  }

  .lottery-knowledge-more {
    font-size: 18px;
  }
}
</style>

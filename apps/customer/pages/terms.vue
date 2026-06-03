<template>
  <MobileShell active-nav="menu">
    <BlueHeader class="terms-hero" title="ข้อตกลงและเงื่อนไข" back-to="/profile" min-height="330px">
      <div class="terms-brand">
        <BrandLogo />
        <p>{{ siteName }}</p>
        <h2>{{ termsTitle }}</h2>
      </div>
    </BlueHeader>

    <section class="content-sheet flush terms-sheet">
      <div class="terms-stack">
        <article class="terms-card">
          <div class="terms-card-head">
            <span>ข้อตกลงการใช้งาน</span>
          </div>

          <ol v-if="numberedTerms.length" class="terms-list">
            <li v-for="term in numberedTerms" :key="term.number">
              <span class="terms-number">{{ term.number }}</span>
              <span>{{ term.text }}</span>
            </li>
          </ol>
          <div v-else class="terms-plain">{{ plainTermsContent }}</div>

          <p v-for="paragraph in extraParagraphs" :key="paragraph" class="terms-paragraph">
            {{ paragraph }}
          </p>
        </article>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: false
})

const { config } = useSiteConfig()

const defaultTermsContent = (siteName: string) => [
  'ข้อตกลงการใช้งาน',
  `1. ${siteName}เป็นระบบจำหน่ายลอตเตอรี่ออนไลน์`,
  '2. บริษัทไม่สนับสนุนการจำหน่ายสลากให้กับบุคคลที่มีอายุไม่ถึง 20 ปี',
  '3. บริษัทสนับสนุนผู้ไม่มีรายได้ ผู้พิการ ในการเป็นตัวแทนจำหน่ายลอตเตอรี่ออนไลน์',
  '4. บริษัทเก็บรักษาสลากที่ลูกค้าซื้อเพื่อความปลอดภัย รวมถึงการขึ้นรางวัลให้กับลูกค้า',
  '5. หากผู้ซื้อนำรูปภาพสลากหรือสลากจริงไปขายต่อ ทางบริษัทไม่มีส่วนเกี่ยวข้องและไม่รับผิดชอบความเสียหายในทุกกรณี',
  '6. หลังจาก ทำรายการ และ กดปุ่ม " ชำระเงิน " ทางบริษัทถือว่า ผู้สั่งซื้อได้รับทราบ ข้อตกลงและเงื่อนไขต่างๆของบริษัทเป็นที่เรียบร้อย',
  '7. บริษัทขอสงวนสิทธิ์ ขึ้นเงินรางวัลให้ลูกค้าที่ซื้อกับระบบ ในกรณีลูกค้าถูกรางวัล โดยไม่มีค่าใช้จ่ายใดๆ ทั้งสิ้น',
  '8. ลูกค้าสามารถยกเลิกการสั่งซื้อสลากได้ภายใน 15 นาทีทุกกรณี หากเกินระยะเวลาที่กำหนด บริษัทขอสงวนสิทธิ์ไม่คืนเงินค่าสลากทุกกรณี',
].join('\n')

const siteName = computed(() => {
  const site = config.value?.site || {}

  return String(site.display_name || site.site_name || 'เว็บไซต์นี้')
})
const termsContent = computed(() => {
  const content = config.value?.legal?.terms_content

  return typeof content === 'string' && content.trim() ? content : defaultTermsContent(siteName.value)
})
const termsLines = computed(() => termsContent.value
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean))
const isNumberedLine = (line: string) => /^\d+\.\s*/.test(line)
const termsTitle = computed(() => {
  const firstLine = termsLines.value[0] || 'ข้อตกลงการใช้งาน'

  return isNumberedLine(firstLine) ? 'ข้อตกลงการใช้งาน' : firstLine
})
const numberedTerms = computed(() => termsLines.value
  .map((line) => {
    const match = line.match(/^(\d+)\.\s*(.+)$/)

    return match ? { number: match[1], text: match[2] } : null
  })
  .filter((term): term is { number: string, text: string } => Boolean(term)))
const extraParagraphs = computed(() => termsLines.value
  .filter((line, index) => !(index === 0 && line === termsTitle.value))
  .filter((line) => !isNumberedLine(line)))
const plainTermsContent = computed(() => termsLines.value
  .filter((line, index) => !(index === 0 && line === termsTitle.value))
  .join('\n'))

useTenantSeo({
  title: 'ข้อตกลงและเงื่อนไข',
  description: `ข้อตกลงการใช้งานของ ${siteName.value}`,
  canonicalPath: '/terms'
})
</script>

<style scoped>
.terms-hero {
  padding-bottom: 104px;
}

.terms-brand {
  display: grid;
  justify-items: center;
  gap: 14px;
  padding-top: 26px;
  text-align: center;
}

.terms-brand :deep(.brand-lockup) {
  transform: scale(1.34);
  transform-origin: center;
}

.terms-brand :deep(.brand-logo-image) {
  max-width: 128px;
  height: 46px;
  object-position: center;
}

.terms-brand p {
  max-width: min(320px, 100%);
  margin: 16px 0 0;
  overflow: hidden;
  color: rgba(255, 255, 255, .9);
  font-size: 14px;
  font-weight: 900;
  line-height: 1.35;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.terms-brand h2 {
  margin: 0;
  color: #fff;
  font-size: 29px;
  font-weight: 900;
  line-height: 1.24;
}

.terms-sheet {
  margin-top: -82px;
  padding: 0 18px calc(42px + env(safe-area-inset-bottom));
  background: transparent;
  border-radius: 0;
}

.terms-stack {
  display: grid;
  gap: 22px;
}

.terms-card {
  padding: 26px 24px;
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 12px 32px rgba(15, 88, 165, .11);
  color: var(--app-ink);
}

.terms-card-head {
  display: flex;
  margin-bottom: 20px;
}

.terms-card-head span {
  display: inline-flex;
  max-width: 100%;
  padding: 8px 14px;
  overflow: hidden;
  border-radius: 999px;
  background: #eef7ff;
  color: #086bcf;
  font-size: 14px;
  font-weight: 900;
  line-height: 1;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.terms-list {
  display: grid;
  gap: 20px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.terms-list li {
  display: grid;
  grid-template-columns: 40px minmax(0, 1fr);
  gap: 16px;
  align-items: flex-start;
  color: #2f3746;
  font-size: 18px;
  font-weight: 800;
  line-height: 1.6;
}

.terms-number {
  display: inline-grid;
  width: 34px;
  height: 34px;
  place-items: center;
  margin-top: 2px;
  border-radius: 50%;
  background: #086bcf;
  color: #fff;
  font-size: 17px;
  font-weight: 900;
  line-height: 1;
}

.terms-list li span {
  min-width: 0;
}

.terms-paragraph,
.terms-plain {
  color: #2f3746;
  font-size: 18px;
  font-weight: 800;
  line-height: 1.7;
  white-space: pre-line;
}

.terms-paragraph {
  margin: 22px 0 0;
}

.terms-plain {
  margin: 0;
}

@media (max-width: 390px) {
  .terms-hero {
    padding-bottom: 94px;
  }

  .terms-brand h2 {
    font-size: 25px;
  }

  .terms-sheet {
    margin-top: -76px;
    padding-right: 14px;
    padding-left: 14px;
  }

  .terms-card {
    padding: 24px 22px;
  }

  .terms-list {
    gap: 18px;
  }

  .terms-list li {
    grid-template-columns: 38px minmax(0, 1fr);
    gap: 14px;
    font-size: 16px;
  }

  .terms-paragraph,
  .terms-plain {
    font-size: 16px;
  }
}
</style>

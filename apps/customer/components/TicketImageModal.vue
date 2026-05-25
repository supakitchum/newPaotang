<template>
  <div class="modal-overlay ticket-image-overlay" @click.self="$emit('close')">
    <section class="ticket-modal ticket-image-modal" role="dialog" aria-modal="true" aria-labelledby="ticket-image-title">
      <div class="ticket-image-modal-head">
        <div class="ticket-image-brand-lockup">
          <BrandLogo />
          <span class="lottery-six">L6</span>
        </div>
        <h2 id="ticket-image-title" class="visually-hidden">รูปสลากฯ</h2>
        <button class="ticket-image-close" type="button" aria-label="ปิดรูปสลากฯ" @click="$emit('close')">
          <i class="bi bi-x-lg" />
        </button>
      </div>

      <div class="ticket-image-frame">
        <img
          v-if="showRemoteImage"
          :src="displayImageUrl"
          :alt="altText"
          loading="eager"
          decoding="async"
          @error="hasImageError = true"
        >
        <div v-else class="ticket-generated-image" :aria-label="altText">
          <div class="ticket-generated-watermark">GLO</div>
          <div class="ticket-generated-head">
            <div>
              <strong>สลากกินแบ่งรัฐบาล</strong>
              <span>THAI GOVERNMENT LOTTERY</span>
            </div>
            <span class="lottery-six">L6</span>
          </div>
          <div class="ticket-generated-body">
            <div class="ticket-generated-illustration">
              <i class="bi bi-ticket-perforated" />
            </div>
            <div class="ticket-generated-main">
              <div class="ticket-generated-label">เลขสลากฯ ดิจิทัล</div>
              <div class="ticket-generated-number">
                <span v-for="(digit, index) in displayDigits" :key="index">{{ digit }}</span>
              </div>
              <div class="ticket-generated-meta">
                <span>งวดปัจจุบัน</span>
                <span>แบบดิจิทัล</span>
              </div>
            </div>
          </div>
        </div>
        <div class="ticket-sold-watermarks" aria-hidden="true">
          <span>ขายแล้ว</span>
          <span>ขายแล้ว</span>
          <span>ขายแล้ว</span>
          <span>ขายแล้ว</span>
          <span>ขายแล้ว</span>
          <span>ขายแล้ว</span>
        </div>
      </div>

      <div class="ticket-image-modal-note">
        <div class="ticket-image-paotang">เป๋าตัง</div>
        <p>สลากฯ ใบนี้ขายที่บริการ ‘สลากหกหลัก’<br>บนแอปฯ เป๋าตังเท่านั้น</p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'

const props = defineProps({
  number: {
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

defineEmits<{
  close: []
}>()

const hasImageError = ref(false)

const normalizeUrl = (value: string | null | undefined) => {
  const url = String(value || '').trim()

  if (!url) {
    return ''
  }

  if (/^https?:\/\//i.test(url) || url.startsWith('data:')) {
    return url
  }

  return url.startsWith('/') ? url : `/${url.replace(/^\/+/, '')}`
}

const displayImageUrl = computed(() => normalizeUrl(props.imageUrl || props.imageThumbUrl))
const normalizedStatus = computed(() => String(props.imageStatus || '').toLowerCase())
const showRemoteImage = computed(() => Boolean(displayImageUrl.value) && !hasImageError.value && !['pending_assets', 'missing'].includes(normalizedStatus.value))
const displayDigits = computed(() => {
  const digits = String(props.number || '').replace(/\D/g, '').padStart(6, '0').slice(-6)

  return digits.split('')
})
const altText = computed(() => `รูปสลากฯ เลข ${displayDigits.value.join('')}`)

watch(() => [props.imageUrl, props.imageThumbUrl, props.imageStatus], () => {
  hasImageError.value = false
})
</script>

<style scoped>
.ticket-image-overlay {
  padding: 20px;
}

.ticket-image-modal {
  max-width: 530px;
  overflow: hidden;
  padding: 24px 24px 0;
}

.ticket-image-modal-head {
  align-items: center;
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  margin-bottom: 16px;
}

.ticket-image-brand-lockup {
  align-items: center;
  display: flex;
  gap: 14px;
  grid-column: 2;
  justify-content: center;
}

.ticket-image-brand-lockup :deep(.brand-logo-image),
.ticket-image-brand-lockup :deep(.brand-logo-fallback) {
  max-height: 46px;
}

.ticket-image-brand-lockup .lottery-six {
  font-size: 34px;
}

.ticket-image-close {
  align-items: center;
  background: transparent;
  border: 0;
  color: #111827;
  display: inline-flex;
  font-size: 30px;
  grid-column: 3;
  justify-self: end;
  padding: 0;
}

.ticket-image-frame {
  aspect-ratio: 5 / 2.8;
  background: #f5f7fb;
  border: 1px solid #dce7f5;
  border-radius: 8px;
  overflow: hidden;
  position: relative;
  width: 100%;
}

.ticket-image-frame img {
  background: #f5f7fb;
  display: block;
  height: 100%;
  object-fit: contain;
  width: 100%;
}

.ticket-generated-image {
  background:
    radial-gradient(circle at 12% 18%, rgba(255, 122, 133, .2), transparent 18%),
    radial-gradient(circle at 78% 30%, rgba(18, 152, 215, .16), transparent 22%),
    repeating-linear-gradient(135deg, rgba(5, 130, 226, .06) 0 8px, transparent 8px 18px),
    linear-gradient(135deg, #ffffff 0%, #f7fcff 55%, #fff8dc 100%);
  color: #1f2937;
  display: grid;
  height: 100%;
  overflow: hidden;
  padding: 18px;
  position: relative;
  width: 100%;
}

.ticket-generated-watermark {
  color: rgba(0, 132, 205, .08);
  font-size: clamp(54px, 16vw, 96px);
  font-weight: 900;
  left: 50%;
  letter-spacing: 0;
  line-height: 1;
  position: absolute;
  top: 50%;
  transform: translate(-50%, -50%) rotate(-14deg);
  white-space: nowrap;
}

.ticket-generated-head,
.ticket-generated-body,
.ticket-generated-meta {
  position: relative;
  z-index: 1;
}

.ticket-generated-head {
  align-items: flex-start;
  display: flex;
  justify-content: space-between;
}

.ticket-generated-head strong,
.ticket-generated-head span {
  display: block;
}

.ticket-generated-head strong {
  color: #008dd2;
  font-size: clamp(14px, 3.5vw, 20px);
  line-height: 1.1;
}

.ticket-generated-head span {
  color: #526173;
  font-size: clamp(8px, 2vw, 11px);
  font-weight: 700;
}

.ticket-generated-head .lottery-six {
  color: #0d73d9;
  font-size: clamp(24px, 7vw, 42px);
}

.ticket-generated-body {
  align-items: center;
  display: grid;
  gap: 14px;
  grid-template-columns: minmax(58px, .8fr) minmax(0, 1.4fr);
  margin-top: 10px;
}

.ticket-generated-illustration {
  align-items: center;
  aspect-ratio: 1;
  background:
    linear-gradient(135deg, rgba(0, 141, 210, .14), rgba(255, 210, 0, .24)),
    #fff;
  border: 1px solid rgba(0, 141, 210, .22);
  border-radius: 12px;
  color: #008dd2;
  display: grid;
  font-size: clamp(26px, 8vw, 54px);
  justify-items: center;
}

.ticket-generated-main {
  min-width: 0;
}

.ticket-generated-label {
  color: #6b7280;
  font-size: clamp(10px, 2.4vw, 13px);
  font-weight: 800;
  margin-bottom: 6px;
}

.ticket-generated-number {
  background: linear-gradient(180deg, #fff4a8, #ffe46e);
  border: 1px solid rgba(204, 164, 0, .5);
  border-radius: 6px;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, .7);
  display: grid;
  gap: clamp(2px, 1vw, 6px);
  grid-template-columns: repeat(6, minmax(0, 1fr));
  padding: clamp(5px, 1.5vw, 9px);
}

.ticket-generated-number span {
  color: #111827;
  font-size: clamp(18px, 6vw, 36px);
  font-weight: 900;
  line-height: 1;
  text-align: center;
}

.ticket-generated-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}

.ticket-generated-meta span {
  background: rgba(255, 255, 255, .74);
  border: 1px solid rgba(13, 115, 217, .18);
  border-radius: 999px;
  color: #526173;
  font-size: clamp(9px, 2vw, 12px);
  font-weight: 800;
  padding: 4px 8px;
}

.ticket-sold-watermarks {
  inset: 0;
  pointer-events: none;
  position: absolute;
  z-index: 4;
}

.ticket-sold-watermarks span {
  color: rgba(210, 44, 64, .58);
  font-size: clamp(14px, 4.2vw, 28px);
  font-weight: 900;
  letter-spacing: 0;
  line-height: 1;
  position: absolute;
  transform: translate(-50%, -50%) rotate(-17deg);
  white-space: nowrap;
}

.ticket-sold-watermarks span:nth-child(1) {
  left: 20%;
  top: 24%;
}

.ticket-sold-watermarks span:nth-child(2) {
  font-size: clamp(13px, 4vw, 26px);
  left: 55%;
  top: 22%;
}

.ticket-sold-watermarks span:nth-child(3) {
  font-size: clamp(12px, 3.7vw, 24px);
  left: 84%;
  top: 34%;
}

.ticket-sold-watermarks span:nth-child(4) {
  font-size: clamp(13px, 3.9vw, 25px);
  left: 28%;
  top: 53%;
}

.ticket-sold-watermarks span:nth-child(5) {
  color: rgba(210, 44, 64, .52);
  font-size: clamp(12px, 3.6vw, 24px);
  left: 68%;
  top: 59%;
}

.ticket-sold-watermarks span:nth-child(6) {
  color: rgba(210, 44, 64, .56);
  font-size: clamp(14px, 4.1vw, 27px);
  left: 46%;
  top: 81%;
}

.ticket-image-modal-note {
  align-items: center;
  background: #edf8ff;
  display: grid;
  gap: 12px;
  grid-template-columns: 52px 1fr;
  margin: 18px -24px 0;
  padding: 14px 18px;
}

.ticket-image-paotang {
  align-items: center;
  background: #1298d7;
  border-radius: 12px;
  color: #fff;
  display: grid;
  font-size: 13px;
  font-weight: 900;
  height: 52px;
  justify-items: center;
  line-height: 1.1;
  text-align: center;
  width: 52px;
}

.ticket-image-modal-note p {
  color: #4b5563;
  font-size: 15px;
  font-weight: 800;
  line-height: 1.35;
  margin: 0;
}

@media (max-width: 420px) {
  .ticket-image-overlay {
    padding: 14px;
  }

  .ticket-image-modal {
    padding: 20px 18px 0;
  }

  .ticket-image-modal-note {
    margin-left: -18px;
    margin-right: -18px;
  }

  .ticket-image-brand-lockup .lottery-six {
    font-size: 30px;
  }
}
</style>

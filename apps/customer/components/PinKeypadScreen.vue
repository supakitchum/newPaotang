<template>
  <section class="pin-keypad-screen">
    <header class="pin-keypad-topbar">
      <button class="pin-keypad-back" type="button" aria-label="กลับ" :disabled="disabled" @click="$emit('back')">
        <i class="bi bi-chevron-left" />
      </button>
      <h1>{{ brand }}</h1>
    </header>

    <main class="pin-keypad-main">
      <div class="pin-keypad-copy">
        <h2>{{ title }}</h2>
        <p>{{ subtitle }}</p>
      </div>

      <div class="pin-keypad-dots" aria-label="PIN">
        <span v-for="index in length" :key="index" :class="{ active: digits.length >= index, error: Boolean(error) }" />
      </div>

      <p class="pin-keypad-message" :class="{ visible: Boolean(error || helper) }">
        {{ error || helper }}
      </p>

      <div v-if="$slots.actions" class="pin-keypad-actions">
        <slot name="actions" />
      </div>
    </main>

    <nav class="pin-keypad-grid" aria-label="PIN keypad">
      <template v-for="key in keys" :key="key || 'blank'">
        <span v-if="key === ''" class="pin-keypad-spacer" aria-hidden="true" />
        <button
          v-else-if="key === 'backspace'"
          class="pin-keypad-delete"
          type="button"
          aria-label="ลบตัวเลข"
          :disabled="disabled || digits.length === 0"
          @click="$emit('remove')"
        >
          <i class="bi bi-backspace" />
        </button>
        <button v-else type="button" :disabled="disabled" @click="$emit('append', key)">
          {{ key }}
        </button>
      </template>
    </nav>
  </section>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  brand?: string
  title: string
  subtitle: string
  digits: string
  error?: string
  helper?: string
  disabled?: boolean
  length?: number
}>(), {
  brand: 'เป๋าตัง',
  error: '',
  helper: '',
  disabled: false,
  length: 6
})

defineEmits<{
  append: [digit: string]
  remove: []
  back: []
}>()

const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'backspace']
</script>

<style scoped>
.pin-keypad-screen {
  background: #fff;
  color: #2f3337;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr) auto;
  min-height: 100dvh;
  overflow: hidden;
  padding: calc(12px + env(safe-area-inset-top)) 28px calc(22px + env(safe-area-inset-bottom));
  text-align: center;
}

.pin-keypad-topbar {
  align-items: center;
  display: grid;
  grid-template-columns: 42px 1fr 42px;
  height: 42px;
  margin: 0 auto;
  max-width: 430px;
  width: 100%;
}

.pin-keypad-back {
  align-items: center;
  background: transparent;
  border: 0;
  color: #8b9299;
  display: inline-flex;
  font-size: 24px;
  height: 42px;
  justify-content: flex-start;
  padding: 0;
  width: 42px;
}

.pin-keypad-back:disabled {
  opacity: .45;
}

.pin-keypad-topbar h1 {
  color: #8487f8;
  font-size: 16px;
  font-weight: 900;
  line-height: 1;
  margin: 0;
}

.pin-keypad-main {
  align-content: center;
  display: grid;
  grid-template-rows: min-content min-content min-content;
  margin: 0 auto;
  max-width: 430px;
  min-height: 0;
  padding: clamp(10px, 5vh, 58px) 0;
  width: 100%;
}

.pin-keypad-copy {
  display: grid;
  gap: 4px;
}

.pin-keypad-copy h2 {
  color: #2f3337;
  font-size: 30px;
  font-weight: 900;
  line-height: 1.2;
  margin: 0;
}

.pin-keypad-copy p {
  color: #9aa0a6;
  font-size: 20px;
  font-weight: 800;
  line-height: 1.35;
  margin: 0;
}

.pin-keypad-dots {
  align-items: center;
  display: flex;
  gap: 12px;
  justify-content: center;
  margin-top: clamp(21px, 5vh, 34px);
}

.pin-keypad-dots span {
  background: #dddddf;
  border-radius: 50%;
  height: 9px;
  transition: background-color .14s ease;
  width: 9px;
}

.pin-keypad-dots span.active {
  background: #2f3337;
}

.pin-keypad-dots span.error {
  background: #f2b6bd;
}

.pin-keypad-message {
  color: #d3455b;
  font-size: 12px;
  font-weight: 800;
  line-height: 1.35;
  margin: clamp(12px, 3vh, 17px) auto 0;
  max-width: 260px;
  min-height: clamp(18px, 4vh, 33px);
  opacity: 0;
}

.pin-keypad-message.visible {
  opacity: 1;
}

.pin-keypad-actions {
  align-items: center;
  display: flex;
  justify-content: center;
  min-height: 32px;
}

.pin-keypad-grid {
  display: grid;
  gap: clamp(17px, 5vh, 26px) 30px;
  grid-template-columns: repeat(3, minmax(54px, 1fr));
  margin: 0 auto;
  max-width: 340px;
  width: min(100%, 340px);
}

.pin-keypad-grid button,
.pin-keypad-spacer {
  align-items: center;
  background: transparent;
  border: 0;
  color: #2f3337;
  display: inline-flex;
  font-size: 20px;
  font-weight: 900;
  height: clamp(36px, 8.5vh, 43px);
  justify-content: center;
  line-height: 1;
  min-width: 54px;
  padding: 0;
}

.pin-keypad-grid button:active:not(:disabled) {
  transform: scale(.94);
}

.pin-keypad-grid button:disabled {
  opacity: .42;
}

.pin-keypad-delete {
  color: #6d747c;
  font-size: 17px;
}

@media (max-width: 360px) {
  .pin-keypad-screen {
    padding-left: 22px;
    padding-right: 22px;
  }

  .pin-keypad-grid {
    gap: 17px 24px;
  }
}
</style>

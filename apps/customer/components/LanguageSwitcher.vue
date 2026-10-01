<template>
  <div class="language-switcher" role="group" :aria-label="t('common.language')">
    <button
      v-for="option in options"
      :key="option.value"
      class="language-option"
      :class="{ active: locale === option.value }"
      type="button"
      @click="setLocale(option.value)"
    >
      {{ option.label }}
    </button>
  </div>
</template>

<script setup lang="ts">
const { locale, setLocale, t } = useLocale()
const options = computed(() => [
  { value: 'th-TH', label: t('common.thai') },
  { value: 'en-US', label: t('common.english') },
])
</script>

<style scoped>
.language-switcher {
  background: #eef6ff;
  border: 1px solid #d7e8ff;
  border-radius: 999px;
  display: inline-grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 4px;
  padding: 4px;
}

.language-option {
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: #2d5b8e;
  font-size: 13px;
  font-weight: 900;
  min-height: 34px;
  padding: 0 14px;
}

.language-option.active {
  background: #0b82f0;
  box-shadow: 0 8px 18px rgba(8, 93, 196, .22);
  color: #fff;
}
</style>

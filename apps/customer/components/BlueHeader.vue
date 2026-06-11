<template>
  <header class="blue-hero" :style="{ minHeight }">
    <div class="hero-row">
      <button v-if="backTo" class="hero-back" type="button" :aria-label="t('common.back')" @click="goBack">
        <i class="bi bi-chevron-left" />
      </button>
      <h1 v-if="title" class="hero-title">{{ title }}</h1>
      <button v-if="searchButton" class="hero-action circle-action" type="button" :aria-label="t('common.search')" @click="emit('search')">
        <i class="bi bi-search" />
      </button>
      <NuxtLink v-else-if="searchTo" class="hero-action circle-action" :to="searchTo" :aria-label="t('common.search')">
        <i class="bi bi-search" />
      </NuxtLink>
    </div>
    <div class="hero-content">
      <slot />
    </div>
  </header>
</template>

<script setup lang="ts">
const props = defineProps({
  title: {
    type: String,
    default: ''
  },
  backTo: {
    type: String,
    default: ''
  },
  searchTo: {
    type: String,
    default: ''
  },
  searchButton: {
    type: Boolean,
    default: false
  },
  close: {
    type: Boolean,
    default: false
  },
  forceBackTo: {
    type: Boolean,
    default: false
  },
  minHeight: {
    type: String,
    default: '174px'
  }
})
const emit = defineEmits(['search'])
const { t } = useLocale()

const goBack = () => {
  navigateTo(props.backTo)
}
</script>

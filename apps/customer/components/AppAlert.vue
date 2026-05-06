<template>
  <div
    v-if="alertState.visible"
    class="modal-overlay app-alert-overlay"
    @click.self="closeAlert"
  >
    <section
      class="app-alert-modal"
      :class="`is-${alertState.variant}`"
      role="dialog"
      aria-modal="true"
      aria-labelledby="app-alert-title"
    >
      <div class="app-alert-icon">
        <i :class="iconClass" />
      </div>
      <h2 id="app-alert-title">{{ alertTitle }}</h2>
      <p>{{ alertState.message }}</p>
      <button class="primary-pill app-alert-button" type="button" @click="closeAlert">
        {{ alertState.button }}
      </button>
    </section>
  </div>
</template>

<script setup lang="ts">
const { alertState, closeAlert } = useAppAlert()

const alertTitle = computed(() => alertState.value.title || 'แจ้งเตือน')
const iconClass = computed(() => {
  if (alertState.value.variant === 'error') {
    return 'bi bi-x-lg'
  }

  if (alertState.value.variant === 'warning') {
    return 'bi bi-exclamation-lg'
  }

  return 'bi bi-info-lg'
})
</script>

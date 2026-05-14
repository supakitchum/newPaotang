<template>
  <div v-if="modelValue" class="modal fade show d-block" tabindex="-1" role="dialog">
    <div class="modal-dialog modal-dialog-centered modal-dialog-scrollable" :class="size ? `modal-${size}` : ''">
      <div class="modal-content">
        <div class="modal-header">
          <h6 class="modal-title">{{ title }}</h6>
          <button type="button" class="btn-close" aria-label="Close" @click="$emit('update:modelValue', false)" />
        </div>
        <div class="modal-body">
          <slot />
        </div>
        <div class="modal-footer">
          <slot name="footer">
            <button type="button" class="btn btn-light btn-wave" @click="$emit('update:modelValue', false)">Close</button>
          </slot>
        </div>
      </div>
    </div>
  </div>
  <div v-if="modelValue" class="modal-backdrop fade show" />
</template>

<script setup lang="ts">
defineProps<{
  modelValue: boolean
  title: string
  size?: string
}>()
defineEmits(['update:modelValue'])
</script>

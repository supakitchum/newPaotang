<template>
  <div class="row g-2 align-items-end">
    <div class="col-sm-4">
      <label class="form-label">From</label>
      <input v-model="draft.date_from" type="date" class="form-control" />
    </div>
    <div class="col-sm-4">
      <label class="form-label">To</label>
      <input v-model="draft.date_to" type="date" class="form-control" />
    </div>
    <div class="col-sm-4">
      <button class="btn btn-outline-primary btn-wave w-100" type="button" @click="$emit('apply', { ...draft })">Apply range</button>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  modelValue: Record<string, any>
}>()

defineEmits<{
  apply: [value: Record<string, any>]
}>()

const draft = reactive({ date_from: '', date_to: '' })

watch(() => props.modelValue, (value) => {
  draft.date_from = value?.date_from || ''
  draft.date_to = value?.date_to || ''
}, { immediate: true, deep: true })
</script>

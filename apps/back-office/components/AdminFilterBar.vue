<template>
  <div class="card custom-card">
    <div class="card-body">
      <div class="row g-2 align-items-end">
        <div v-for="filter in filters" :key="filter.key" class="col-sm-6 col-lg-3">
          <label class="form-label">{{ filter.label }}</label>
          <select v-if="filter.type === 'select'" v-model="draft[filter.key]" class="form-select">
            <option v-if="!filter.hideEmptyOption" value="">{{ filter.emptyOptionLabel || 'All' }}</option>
            <option v-else-if="!visibleOptions(filter).length" value="" disabled>{{ filter.emptyOptionLabel || 'No options available' }}</option>
            <option
              v-for="option in visibleOptions(filter)"
              :key="optionValue(option)"
              :value="optionValue(option)"
              :disabled="optionDisabled(option)"
            >
              {{ optionLabel(option) }}
            </option>
          </select>
          <input
            v-else
            v-model="draft[filter.key]"
            class="form-control"
            :type="filter.type === 'number' ? 'number' : filter.type === 'date' ? 'date' : filter.type === 'datetime-local' ? 'datetime-local' : 'text'"
            :min="filter.type === 'number' ? 1 : undefined"
          />
        </div>
        <div class="col-sm-6 col-lg-3">
          <button class="btn btn-outline-primary btn-wave w-100" type="button" @click="$emit('apply', cleanDraft())">
            <i class="ri-filter-3-line me-1" />
            Apply filters
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { OperationFilter } from '~/composables/useAdminOperationsCatalog'
import { titleize } from '~/utils/format'

const props = defineProps<{
  filters: OperationFilter[]
  modelValue: Record<string, any>
}>()

defineEmits<{
  'update:modelValue': [value: Record<string, any>]
  apply: [value: Record<string, any>]
}>()

const draft = reactive<Record<string, any>>({})

watch(() => props.modelValue, (value) => {
  for (const filter of props.filters) {
    draft[filter.key] = value?.[filter.key] ?? (filter.key === 'limit' ? 20 : '')
  }
}, { immediate: true, deep: true })

watch(draft, () => {
  for (const filter of props.filters) {
    if (!filter.dependsOn || !draft[filter.key]) {
      continue
    }
    const allowed = new Set(visibleOptions(filter).map((option) => String(optionValue(option))))
    if (!allowed.has(String(draft[filter.key]))) {
      draft[filter.key] = ''
    }
  }
}, { deep: true })

const cleanDraft = () => {
  const next: Record<string, any> = {}
  for (const filter of props.filters) {
    const value = draft[filter.key]
    next[filter.key] = value === '' ? undefined : value
  }
  return next
}

const visibleOptions = (filter: OperationFilter) => {
  const options = filter.options || []
  if (!filter.dependsOn) {
    return options
  }

  const dependencyValue = draft[filter.dependsOn]
  if (!dependencyValue) {
    return []
  }

  return options.filter((option) => optionPartnerId(option) === String(dependencyValue))
}

const optionValue = (option: any) => typeof option === 'object' && option !== null ? option.value : option
const optionLabel = (option: any) => typeof option === 'object' && option !== null ? option.label : titleize(String(option))
const optionDisabled = (option: any) => Boolean(typeof option === 'object' && option !== null && option.disabled)
const optionPartnerId = (option: any) => String(typeof option === 'object' && option !== null ? option.partnerId || option.partner_id || '' : '')
</script>

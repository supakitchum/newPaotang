<template>
  <div class="np-entry-grid">
    <div v-for="(group, groupIndex) in groups" :key="group.type" class="np-entry-group">
      <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-2">
        <div>
          <h6 class="mb-0">{{ group.label }}</h6>
          <span class="text-muted fs-12">{{ group.count }} number(s), {{ group.digits }} digits</span>
        </div>
        <span class="badge bg-light text-default">{{ group.amount.toLocaleString('th-TH') }} THB</span>
      </div>
      <div class="np-entry-number-grid" :style="{ '--np-entry-columns': group.digits === 6 ? 5 : 8 }">
        <input
          v-for="(_, numberIndex) in group.numbers"
          :key="numberIndex"
          class="form-control form-control-sm np-entry-number-input"
          inputmode="numeric"
          :maxlength="group.digits"
          :placeholder="String(numberIndex + 1)"
          :readonly="readonly"
          :value="group.numbers[numberIndex]"
          @input="updateNumber(groupIndex, numberIndex, $event)"
        >
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { RewardPrizeGroupState } from '~/composables/useRewardPrizes'

const props = withDefaults(defineProps<{
  modelValue: RewardPrizeGroupState[]
  readonly?: boolean
}>(), {
  readonly: false,
})

const emit = defineEmits<{
  'update:modelValue': [value: RewardPrizeGroupState[]]
}>()

const groups = computed({
  get: () => props.modelValue,
  set: (value: RewardPrizeGroupState[]) => emit('update:modelValue', value),
})

const updateNumber = (groupIndex: number, numberIndex: number, event: Event) => {
  const target = event.target as HTMLInputElement | null
  const next = groups.value.map((group) => ({
    ...group,
    numbers: [...group.numbers],
  }))
  const group = next[groupIndex]
  if (!group) return
  group.numbers[numberIndex] = String(target?.value || '').replace(/\D/g, '').slice(0, group.digits)
  groups.value = next
}
</script>

<style scoped>
.np-entry-grid {
  display: grid;
  gap: 1rem;
}

.np-entry-group {
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.5rem;
  padding: 1rem;
}

.np-entry-number-grid {
  display: grid;
  gap: 0.5rem;
  grid-template-columns: repeat(var(--np-entry-columns), minmax(0, 1fr));
}

.np-entry-number-input {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-weight: 700;
  letter-spacing: 0;
  text-align: center;
}

@media (max-width: 767.98px) {
  .np-entry-number-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>

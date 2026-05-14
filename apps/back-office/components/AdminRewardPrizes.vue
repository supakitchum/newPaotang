<template>
  <div class="card custom-card">
    <div class="card-header">
      <div>
        <div class="card-title mb-1">Prizes</div>
        <p class="text-muted mb-0 small">Thai Government Lottery reward rows</p>
      </div>
    </div>
    <div class="card-body">
      <AdminEmptyState v-if="!groups.length" title="No prizes" message="This reward result has no prize rows yet." />
      <div v-else class="np-reward-prize-groups">
        <section v-for="group in groups" :key="group.type" class="np-reward-prize-group">
          <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-2">
            <div>
              <h6 class="mb-1">{{ group.label }}</h6>
              <div class="text-muted small">{{ group.count }} rows · {{ group.digits }} digits</div>
            </div>
            <span class="badge bg-primary-transparent text-primary">
              {{ formatRewardPrizeAmount(group.amount, group.currency) }}
            </span>
          </div>
          <div class="np-reward-number-list">
            <span
              v-for="(number, index) in group.numbers"
              :key="`${group.type}-${index}`"
              class="np-reward-number"
              :class="{ 'text-muted': !displayRewardNumber(number) }"
            >
              {{ displayRewardNumber(number) || '-' }}
            </span>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  prizes?: unknown[] | null
}>()

const groups = computed(() => normalizeRewardPrizeGroups(props.prizes || []))
const displayRewardNumber = (value: string) => {
  const normalized = String(value || '').trim()
  return normalized && !normalized.startsWith('pending_') ? normalized : ''
}
</script>

<style scoped>
.np-reward-prize-groups {
  display: grid;
  gap: 1rem;
}

.np-reward-prize-group {
  border: 1px solid var(--default-border);
  border-radius: 6px;
  padding: 1rem;
}

.np-reward-number-list {
  display: flex;
  flex-wrap: wrap;
  gap: .5rem;
}

.np-reward-number {
  border: 1px solid var(--default-border);
  border-radius: 4px;
  font-family: var(--default-font-family);
  font-size: .875rem;
  line-height: 1.2;
  min-width: 4.75rem;
  padding: .35rem .5rem;
  text-align: center;
}
</style>

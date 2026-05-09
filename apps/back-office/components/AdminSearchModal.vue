<template>
  <div id="admin-search-modal" class="modal fade" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <div class="modal-content">
        <div class="modal-header">
          <h6 class="modal-title">Search menu</h6>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close" />
        </div>
        <div class="modal-body">
          <div class="input-group mb-3">
            <span class="input-group-text"><i class="ri-search-line" /></span>
            <input v-model="query" class="form-control" type="search" placeholder="Search backend menu" />
          </div>
          <div class="list-group">
            <NuxtLink v-for="item in filtered" :key="item.key" :to="mapRoute(item)" class="list-group-item list-group-item-action">
              <i :class="[iconFor(item), 'me-2']" />
              {{ item.label }}
            </NuxtLink>
          </div>
          <AdminEmptyState v-if="query && !filtered.length" title="No matches" message="Only menu items returned by the backend are searchable." />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{ menus: any[] }>()
const query = ref('')
const { mapRoute, iconFor } = useAdminNavigation()
const flat = computed(() => props.menus.flatMap((item) => item.children?.length ? [item, ...item.children] : [item]))
const filtered = computed(() => {
  const value = query.value.trim().toLowerCase()
  if (!value) return flat.value.slice(0, 6)
  return flat.value.filter((item) => `${item.label} ${item.key}`.toLowerCase().includes(value)).slice(0, 10)
})
</script>

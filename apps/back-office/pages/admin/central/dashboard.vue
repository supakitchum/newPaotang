<template>
  <div>
    <AdminPageHeader title="Central Dashboard" :breadcrumbs="['Admin', 'Central', 'Dashboard']">
      <template #actions>
        <NuxtLink to="/admin/central/lottery-images" class="btn btn-light btn-wave">
          <i class="ri-image-2-line me-1" />
          Lottery Images
        </NuxtLink>
        <button class="btn btn-primary btn-wave" type="button" @click="load">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>
    <AdminAlert v-if="error" :type="error.status === 403 ? 'warning' : 'danger'" :message="error.message" :details="error.details" />
    <AdminLoader v-if="loading" />
    <template v-else>
      <div class="row">
        <div v-for="card in cards" :key="card.key" class="col-xxl-3 col-md-6">
          <AdminKpiCard :label="card.label" :value="card.value" :icon="card.icon" :color-class="card.color" />
        </div>
      </div>
      <div class="card custom-card">
        <div class="card-header">
          <div class="card-title">Activity</div>
        </div>
        <div class="card-body">
          <AdminEmptyState v-if="!summary?.alerts?.length" title="No active alerts" message="Central dashboard alerts will appear here when backend returns them." icon="ri-notification-off-line" />
          <div v-else class="list-group">
            <div v-for="alert in summary.alerts" :key="alert.id || alert.message" class="list-group-item">{{ alert.message || alert }}</div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

const api = useAdminApi()
const session = useAdminSession()
const loading = ref(false)
const error = ref<any>(null)
const summary = ref<any>(null)

const cards = computed(() => {
  const kpis = summary.value?.kpis || {}
  return [
    { key: 'partners_total', label: 'Partners', value: kpis.partners_total ?? 0, icon: 'ri-building-4-line', color: 'bg-primary-transparent text-primary' },
    { key: 'tenants_active', label: 'Active tenants', value: kpis.tenants_active ?? 0, icon: 'ri-store-2-line', color: 'bg-success-transparent text-success' },
    { key: 'admin_users_total', label: 'Admin users', value: kpis.admin_users_total ?? 0, icon: 'ri-user-settings-line', color: 'bg-info-transparent text-info' },
    { key: 'audit_logs_total', label: 'Audit logs', value: kpis.audit_logs_total ?? 0, icon: 'ri-history-line', color: 'bg-warning-transparent text-warning' },
  ]
})

const load = async () => {
  session.setScope('central')
  loading.value = true
  error.value = null

  try {
    summary.value = await api.apiFetch('/admin/central/dashboard/summary', { scope: 'central' })
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div>
    <AdminPageHeader title="Tenant Dashboard" :breadcrumbs="['Admin', 'Tenant', 'Dashboard']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" @click="load">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>
    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before opening tenant pages." />
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
          <div class="card-title">Tenant operations</div>
        </div>
        <div class="card-body">
          <div class="row g-3">
            <div class="col-md-6">
              <NuxtLink to="/admin/tenant/maintenance" class="btn btn-outline-primary btn-wave w-100 text-start">
                <i class="ri-tools-line me-2" />
                Maintenance controls
              </NuxtLink>
            </div>
            <div class="col-md-6">
              <NuxtLink to="/admin/tenant/support-access" class="btn btn-outline-primary btn-wave w-100 text-start">
                <i class="ri-customer-service-2-line me-2" />
                Support access
              </NuxtLink>
            </div>
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
const tenantId = computed(() => session.currentTenantId.value)

const cards = computed(() => {
  const kpis = summary.value?.kpis || {}
  return [
    { key: 'admin_users_total', label: 'Admin users', value: kpis.admin_users_total ?? 0, icon: 'ri-user-settings-line', color: 'bg-primary-transparent text-primary' },
    { key: 'roles_total', label: 'Roles', value: kpis.roles_total ?? 0, icon: 'ri-shield-user-line', color: 'bg-success-transparent text-success' },
    { key: 'orders_total', label: 'Orders', value: kpis.orders_total ?? 0, icon: 'ri-shopping-bag-3-line', color: 'bg-info-transparent text-info' },
    { key: 'audit_logs_total', label: 'Audit logs', value: kpis.audit_logs_total ?? 0, icon: 'ri-history-line', color: 'bg-warning-transparent text-warning' },
  ]
})

const load = async () => {
  if (!tenantId.value) return
  session.setScope('tenant', tenantId.value)
  loading.value = true
  error.value = null

  try {
    summary.value = await api.apiFetch('/admin/tenant/dashboard/summary', { scope: 'tenant', tenantId: tenantId.value })
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

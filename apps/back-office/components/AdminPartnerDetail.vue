<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Partner detail</div>
        <p class="text-muted fs-12 mb-0">{{ subtitle }}</p>
      </div>
      <AdminStatusBadge v-if="record?.status" :status="record.status" />
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!record" title="No detail data" message="This partner has no data to display yet." />
      <div v-else class="row g-3">
        <div v-for="section in sections" :key="section.title" class="col-12 col-xl-6">
          <div class="border rounded p-3 h-100">
            <h6 class="mb-3">{{ section.title }}</h6>
            <dl class="row mb-0 gy-2">
              <template v-for="item in section.items" :key="item.key">
                <dt class="col-sm-5 text-muted fw-semibold">{{ item.label }}</dt>
                <dd class="col-sm-7 mb-0">
                  <AdminStatusBadge v-if="item.type === 'status'" :status="item.value" />
                  <code v-else-if="item.mono" class="np-admin-code">{{ item.value || '-' }}</code>
                  <span v-else>{{ item.value || '-' }}</span>
                </dd>
              </template>
            </dl>
          </div>
        </div>

        <div class="col-12">
          <div class="border rounded p-3">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Tenants</h6>
              <span class="badge bg-light text-default">{{ tenants.length }}</span>
            </div>
            <div v-if="tenants.length" class="table-responsive">
              <table class="table table-sm text-nowrap align-middle mb-0">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Code</th>
                    <th>Status</th>
                    <th>Tenant ID</th>
                    <th>Updated</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="tenant in tenantRows" :key="tenant.id">
                    <td>{{ tenant.name }}</td>
                    <td><code class="np-admin-code">{{ tenant.code }}</code></td>
                    <td><AdminStatusBadge :status="tenant.status" /></td>
                    <td><code class="np-admin-code">{{ tenant.id }}</code></td>
                    <td>{{ tenant.updatedAt }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <AdminEmptyState v-else title="No tenants" message="Provision this partner before a tenant appears here." />
          </div>
        </div>

        <div class="col-12">
          <div class="border rounded p-3">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Domains</h6>
              <span class="badge bg-light text-default">{{ domains.length }}</span>
            </div>
            <div v-if="domains.length" class="table-responsive">
              <table class="table table-sm text-nowrap align-middle mb-0">
                <thead>
                  <tr>
                    <th>Storefront host</th>
                    <th>Back Office host</th>
                    <th>Type</th>
                    <th>Status</th>
                    <th>Primary</th>
                    <th>Updated</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="domain in domainRows" :key="domain.id">
                    <td><code class="np-admin-code">{{ domain.host }}</code></td>
                    <td><code class="np-admin-code">{{ domain.boHost }}</code></td>
                    <td>{{ domain.type }}</td>
                    <td><AdminStatusBadge :status="domain.status" /></td>
                    <td>{{ domain.primary }}</td>
                    <td>{{ domain.updatedAt }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <AdminEmptyState v-else title="No domains" message="Provision this partner before a domain appears here." />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, titleize } from '~/utils/format'

type DetailItem = {
  key: string
  label: string
  value: string
  mono?: boolean
  type?: string | null
}

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
}>()

const tenants = computed<Record<string, any>[]>(() => (
  Array.isArray(props.record?.tenants) ? props.record?.tenants : []
))
const domains = computed<Record<string, any>[]>(() => (
  Array.isArray(props.record?.domains) ? props.record?.domains : []
))
const primaryTenant = computed(() => tenants.value[0] || null)
const primaryDomain = computed(() => domains.value.find((domain) => domain?.is_primary) || domains.value[0] || null)
const runtime = computed(() => plainObject(props.record?.runtime) || {})

const subtitle = computed(() => {
  if (!props.record) {
    return 'Partner, tenant, domain, and runtime summary.'
  }

  return [props.record.name, props.record.code].filter(Boolean).join(' - ')
})

const sections = computed(() => {
  const record = props.record || {}
  const tenant = primaryTenant.value || {}
  const domain = primaryDomain.value || {}

  return [
    {
      title: 'Partner',
      items: compactItems([
        item('name', 'Name', record.name),
        item('code', 'Code', record.code, true),
        item('type', 'Type', titleValue(record.type)),
        item('status', 'Status', record.status, false, 'status'),
        item('stock_percent', 'Stock percent', percentValue(record.stock_percent)),
        item('id', 'Partner ID', record.id, true),
      ]),
    },
    {
      title: 'Primary tenant',
      items: compactItems([
        item('tenant_name', 'Name', tenant.name),
        item('tenant_code', 'Code', tenant.code, true),
        item('tenant_status', 'Status', tenant.status, false, 'status'),
        item('tenant_id', 'Tenant ID', tenant.id || record.tenant_id, true),
        item('tenant_count', 'Tenant count', tenants.value.length),
      ]),
    },
    {
      title: 'Primary domain',
      items: compactItems([
        item('storefront_host', 'Storefront host', domain.host, true),
        item('bo_host', 'Back Office host', boHost(domain.host), true),
        item('domain_type', 'Type', titleValue(domain.type)),
        item('domain_status', 'Status', domain.status, false, 'status'),
        item('is_primary', 'Primary', yesNo(domain.is_primary)),
      ]),
    },
    {
      title: 'Runtime',
      items: compactItems([
        item('billing_status', 'Billing', runtime.value.billing_status, false, 'status'),
        item('monitoring_status', 'Monitoring', runtime.value.monitoring_status, false, 'status'),
        item('api_clients_total', 'API clients', runtime.value.api_clients_total),
        item('created_at', 'Created', formatMaybeDate(record.created_at)),
        item('updated_at', 'Updated', formatMaybeDate(record.updated_at)),
      ]),
    },
  ]
})

const tenantRows = computed(() => tenants.value.map((tenant) => ({
  id: normalizeValue(tenant.id),
  code: normalizeValue(tenant.code),
  name: normalizeValue(tenant.name),
  status: normalizeValue(tenant.status) || 'unknown',
  updatedAt: formatMaybeDate(tenant.updated_at),
})))

const domainRows = computed(() => domains.value.map((domain) => ({
  id: normalizeValue(domain.id || domain.host),
  host: normalizeValue(domain.host),
  boHost: boHost(domain.host),
  type: titleValue(domain.type),
  status: normalizeValue(domain.status) || 'unknown',
  primary: yesNo(domain.is_primary),
  updatedAt: formatMaybeDate(domain.updated_at),
})))

function item(key: string, label: string, value: any, mono = false, type: string | null = null): DetailItem {
  return {
    key,
    label,
    value: normalizeValue(value),
    mono,
    type,
  }
}

function compactItems(items: DetailItem[]) {
  return items.filter((entry) => entry.value !== '')
}

function normalizeValue(value: any) {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  if (typeof value === 'number') {
    return new Intl.NumberFormat('th-TH', { maximumFractionDigits: 2 }).format(value)
  }

  if (typeof value === 'boolean') {
    return yesNo(value)
  }

  if (Array.isArray(value)) {
    return value.map((entry) => normalizeValue(entry)).filter(Boolean).join(', ')
  }

  if (typeof value === 'object') {
    return Object.entries(value)
      .map(([key, entry]) => `${titleValue(key)}: ${normalizeValue(entry) || '-'}`)
      .join(', ')
  }

  return String(value)
}

function percentValue(value: any) {
  const normalized = normalizeValue(value)

  return normalized === '' ? '' : `${normalized}%`
}

function titleValue(value: any) {
  const normalized = normalizeValue(value)

  return normalized === '' ? '' : titleize(normalized)
}

function boHost(host: any) {
  const normalized = normalizeValue(host)

  return normalized === '' ? '' : `bo.${normalized.replace(/^bo\./, '')}`
}

function yesNo(value: any) {
  return value ? 'Yes' : 'No'
}

function plainObject(value: any) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : null
}

function formatMaybeDate(value: any) {
  if (!value) {
    return ''
  }

  return formatDateTime(String(value))
}
</script>

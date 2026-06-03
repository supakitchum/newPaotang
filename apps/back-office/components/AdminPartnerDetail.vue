<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Partner/Tenant detail</div>
        <p class="text-muted fs-12 mb-0">{{ subtitle }}</p>
      </div>
      <AdminStatusBadge v-if="displayRecord?.status" :status="displayRecord.status" />
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!displayRecord" title="No detail data" message="This partner has no data to display yet." />
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
              <h6 class="mb-0">Partner basic</h6>
              <button class="btn btn-primary btn-sm btn-wave" type="button" :disabled="sectionBusy('partner')" @click="saveSection('partner')">
                <span v-if="savingSection === 'partner'" class="spinner-border spinner-border-sm me-2" />
                Save
              </button>
            </div>
            <div v-if="sectionErrors.partner" class="alert alert-danger py-2">{{ errorMessage(sectionErrors.partner) }}</div>
            <div class="row g-3">
              <div class="col-12 col-md-6">
                <label class="form-label">Partner name</label>
                <input v-model="partnerForm.name" class="form-control" type="text">
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">Partner code</label>
                <input v-model="partnerForm.code" class="form-control" type="text">
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">Type</label>
                <select v-model="partnerForm.type" class="form-select">
                  <option v-for="option in partnerTypeOptions" :key="option" :value="option">{{ titleValue(option) }}</option>
                </select>
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">Status</label>
                <select v-model="partnerForm.status" class="form-select">
                  <option v-for="option in partnerStatusOptions" :key="option" :value="option">{{ titleValue(option) }}</option>
                </select>
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">Stock %</label>
                <input v-model.number="partnerForm.stock_percent" class="form-control" type="number" min="0" max="100" step="0.01">
              </div>
            </div>
          </div>
        </div>

        <div class="col-12">
          <div class="border rounded p-3">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Tenant basic</h6>
              <button class="btn btn-primary btn-sm btn-wave" type="button" :disabled="!primaryTenant || sectionBusy('tenant')" @click="saveSection('tenant')">
                <span v-if="savingSection === 'tenant'" class="spinner-border spinner-border-sm me-2" />
                Save
              </button>
            </div>
            <div v-if="sectionErrors.tenant" class="alert alert-danger py-2">{{ errorMessage(sectionErrors.tenant) }}</div>
            <div class="row g-3">
              <div class="col-12 col-md-5">
                <label class="form-label">Tenant name</label>
                <input v-model="tenantForm.name" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">Tenant code</label>
                <input v-model="tenantForm.code" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-3">
                <label class="form-label">Status</label>
                <select v-model="tenantForm.status" class="form-select" :disabled="!primaryTenant">
                  <option v-for="option in tenantStatusOptions" :key="option" :value="option">{{ titleValue(option) }}</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        <div class="col-12">
          <div class="border rounded p-3">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Domain</h6>
              <button class="btn btn-primary btn-sm btn-wave" type="button" :disabled="!primaryTenant || sectionBusy('domain')" @click="saveSection('domain')">
                <span v-if="savingSection === 'domain'" class="spinner-border spinner-border-sm me-2" />
                Save
              </button>
            </div>
            <div v-if="sectionErrors.domain" class="alert alert-danger py-2">{{ errorMessage(sectionErrors.domain) }}</div>
            <div class="row g-3">
              <div class="col-12 col-xl-5">
                <label class="form-label">Storefront host</label>
                <input v-model="domainForm.host" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-xl-3">
                <label class="form-label">Type</label>
                <select v-model="domainForm.type" class="form-select" :disabled="!primaryTenant">
                  <option v-for="option in domainTypeOptions" :key="option" :value="option">{{ titleValue(option) }}</option>
                </select>
              </div>
              <div class="col-12 col-xl-3">
                <label class="form-label">Status</label>
                <select v-model="domainForm.status" class="form-select" :disabled="!primaryTenant">
                  <option v-for="option in domainStatusOptions" :key="option" :value="option">{{ titleValue(option) }}</option>
                </select>
              </div>
              <div class="col-12 col-xl-1 d-flex align-items-end">
                <div class="form-check mb-2">
                  <input id="partner-domain-primary" v-model="domainForm.is_primary" class="form-check-input" type="checkbox" :disabled="!primaryTenant">
                  <label class="form-check-label" for="partner-domain-primary">Primary</label>
                </div>
              </div>
              <div class="col-12">
                <span class="text-muted fs-12">Back Office: </span>
                <code class="np-admin-code">{{ boHost(domainForm.host) || '-' }}</code>
              </div>
            </div>
          </div>
        </div>

        <div class="col-12">
          <div class="border rounded p-3">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Site settings</h6>
              <button class="btn btn-primary btn-sm btn-wave" type="button" :disabled="!primaryTenant || sectionBusy('settings')" @click="saveSection('settings')">
                <span v-if="savingSection === 'settings'" class="spinner-border spinner-border-sm me-2" />
                Save
              </button>
            </div>
            <div v-if="sectionErrors.settings" class="alert alert-danger py-2">{{ errorMessage(sectionErrors.settings) }}</div>
            <div class="row g-3">
              <div class="col-12 col-md-6">
                <label class="form-label">Site name</label>
                <input v-model="settingsForm.site_name" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">Display name</label>
                <input v-model="settingsForm.display_name" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-3">
                <label class="form-label">Locale</label>
                <input v-model="settingsForm.locale" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-3">
                <label class="form-label">Timezone</label>
                <input v-model="settingsForm.timezone" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-3">
                <label class="form-label">Support email</label>
                <input v-model="settingsForm.support_email" class="form-control" type="email" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-3">
                <label class="form-label">Support phone</label>
                <input v-model="settingsForm.support_phone" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">Default title</label>
                <input v-model="settingsForm.default_title" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">Title template</label>
                <input v-model="settingsForm.title_template" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">Default description</label>
                <textarea v-model="settingsForm.default_description" class="form-control" rows="3" :disabled="!primaryTenant" />
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">Default keywords</label>
                <textarea v-model="settingsForm.default_keywords" class="form-control" rows="3" :disabled="!primaryTenant" />
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">Robots default</label>
                <input v-model="settingsForm.robots_default" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-4 d-flex align-items-end gap-3">
                <div class="form-check mb-2">
                  <input id="partner-sitemap-enabled" v-model="settingsForm.sitemap_enabled" class="form-check-input" type="checkbox" :disabled="!primaryTenant">
                  <label class="form-check-label" for="partner-sitemap-enabled">Sitemap</label>
                </div>
                <div class="form-check mb-2">
                  <input id="partner-robots-enabled" v-model="settingsForm.robots_enabled" class="form-check-input" type="checkbox" :disabled="!primaryTenant">
                  <label class="form-check-label" for="partner-robots-enabled">Robots</label>
                </div>
              </div>
              <div class="col-12 col-md-4 d-flex align-items-end">
                <div class="form-check mb-2">
                  <input id="partner-maintenance-active" v-model="settingsForm.maintenance_active" class="form-check-input" type="checkbox" :disabled="!primaryTenant">
                  <label class="form-check-label" for="partner-maintenance-active">Maintenance</label>
                </div>
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">Maintenance mode</label>
                <select v-model="settingsForm.maintenance_mode" class="form-select" :disabled="!primaryTenant">
                  <option value="">None</option>
                  <option v-for="option in maintenanceModeOptions" :key="option" :value="option">{{ titleValue(option) }}</option>
                </select>
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">Retry after seconds</label>
                <input v-model.number="settingsForm.maintenance_retry_after_seconds" class="form-control" type="number" min="0" step="1" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">API base URL</label>
                <input v-model="settingsForm.api_base_url" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12">
                <label class="form-label">Maintenance message</label>
                <textarea v-model="settingsForm.maintenance_message" class="form-control" rows="2" :disabled="!primaryTenant" />
              </div>
              <div class="col-12">
                <label class="form-label">Terms and conditions</label>
                <textarea v-model="settingsForm.terms_content" class="form-control" rows="6" :disabled="!primaryTenant" />
                <div class="form-text">Shown on the customer Terms page. Leave blank to use the default text with the current site name.</div>
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">Realtime URL</label>
                <input v-model="settingsForm.realtime_url" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">Asset CDN base URL</label>
                <input v-model="settingsForm.asset_cdn_base_url" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
            </div>
          </div>
        </div>

        <div class="col-12">
          <div class="border rounded p-3">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Theme/logo</h6>
              <button class="btn btn-primary btn-sm btn-wave" type="button" :disabled="!primaryTenant || sectionBusy('theme')" @click="saveSection('theme')">
                <span v-if="savingSection === 'theme'" class="spinner-border spinner-border-sm me-2" />
                Save
              </button>
            </div>
            <div v-if="sectionErrors.theme" class="alert alert-danger py-2">{{ errorMessage(sectionErrors.theme) }}</div>
            <div class="row g-3">
              <div class="col-12 col-md-4">
                <label class="form-label">Logo URL</label>
                <input v-model="themeForm.logo_url" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">Favicon URL</label>
                <input v-model="themeForm.favicon_url" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">OG image URL</label>
                <input v-model="themeForm.og_image_url" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div v-for="field in colorFields" :key="field.key" class="col-12 col-md-4 col-xl-2">
                <label class="form-label">{{ field.label }}</label>
                <div class="input-group">
                  <input v-model="themeForm[field.key]" class="form-control form-control-color np-partner-color-input" type="color" :disabled="!primaryTenant">
                  <input v-model="themeForm[field.key]" class="form-control" type="text" :disabled="!primaryTenant">
                </div>
              </div>
              <div class="col-12 col-xl-2">
                <label class="form-label">Font family</label>
                <input v-model="themeForm.font_family" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
            </div>
          </div>
        </div>

        <div class="col-12">
          <div class="border rounded p-3">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Owner/admin</h6>
              <button class="btn btn-primary btn-sm btn-wave" type="button" :disabled="!primaryTenant || sectionBusy('owner')" @click="saveSection('owner')">
                <span v-if="savingSection === 'owner'" class="spinner-border spinner-border-sm me-2" />
                Save
              </button>
            </div>
            <div v-if="sectionErrors.owner" class="alert alert-danger py-2">{{ errorMessage(sectionErrors.owner) }}</div>
            <div class="row g-3">
              <div class="col-12 col-md-4">
                <label class="form-label">Owner email</label>
                <input v-model="ownerForm.owner_email" class="form-control" type="email" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-4">
                <label class="form-label">Owner name</label>
                <input v-model="ownerForm.owner_name" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-2">
                <label class="form-label">Owner phone</label>
                <input v-model="ownerForm.owner_phone" class="form-control" type="text" :disabled="!primaryTenant">
              </div>
              <div class="col-12 col-md-2">
                <label class="form-label">Password</label>
                <input v-model="ownerForm.owner_password" class="form-control" type="password" autocomplete="new-password" :disabled="!primaryTenant">
              </div>
            </div>
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

type SectionKey = 'partner' | 'tenant' | 'domain' | 'settings' | 'theme' | 'owner'

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
}>()

const emit = defineEmits<{
  saved: [record: Record<string, any>]
}>()

const api = useAdminApi()
const displayRecord = ref<Record<string, any> | null>(null)
const savingSection = ref<SectionKey | null>(null)
const sectionErrors = reactive<Record<string, any>>({})

const partnerForm = reactive<Record<string, any>>({})
const tenantForm = reactive<Record<string, any>>({})
const domainForm = reactive<Record<string, any>>({})
const settingsForm = reactive<Record<string, any>>({})
const themeForm = reactive<Record<string, any>>({})
const ownerForm = reactive<Record<string, any>>({})

const partnerTypeOptions = ['partner_store', 'agent_network', 'white_label', 'api_partner', 'internal']
const partnerStatusOptions = ['draft', 'active', 'suspended', 'closed']
const tenantStatusOptions = ['provisioning', 'active', 'maintenance', 'suspended', 'closed']
const domainTypeOptions = ['subdomain', 'custom_domain']
const domainStatusOptions = ['pending_verification', 'active', 'failed', 'disabled', 'suspended']
const maintenanceModeOptions = ['full_site', 'customer_web_only', 'admin_only', 'checkout_payment_only', 'read_only', 'scheduled']
const colorFields = [
  { key: 'primary_color', label: 'Primary' },
  { key: 'secondary_color', label: 'Secondary' },
  { key: 'accent_color', label: 'Accent' },
  { key: 'background_color', label: 'Background' },
  { key: 'text_color', label: 'Text' },
]

const tenants = computed<Record<string, any>[]>(() => (
  Array.isArray(displayRecord.value?.tenants) ? displayRecord.value?.tenants : []
))
const domains = computed<Record<string, any>[]>(() => (
  Array.isArray(displayRecord.value?.domains) ? displayRecord.value?.domains : []
))
const primaryTenant = computed(() => tenants.value[0] || null)
const primaryDomain = computed(() => domains.value.find((domain) => domain?.is_primary) || domains.value[0] || null)
const tenantSettings = computed(() => plainObject(displayRecord.value?.tenant_settings) || {})
const tenantTheme = computed(() => plainObject(displayRecord.value?.tenant_theme) || {})
const ownerAdmin = computed(() => plainObject(displayRecord.value?.owner_admin) || {})
const runtime = computed(() => plainObject(displayRecord.value?.runtime) || {})

const subtitle = computed(() => {
  if (!displayRecord.value) {
    return 'Partner, tenant, domain, and runtime summary.'
  }

  return [displayRecord.value.name, displayRecord.value.code].filter(Boolean).join(' - ')
})

const sections = computed(() => {
  const record = displayRecord.value || {}
  const tenant = primaryTenant.value || {}
  const domain = primaryDomain.value || {}
  const settings = tenantSettings.value
  const theme = tenantTheme.value
  const owner = ownerAdmin.value

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
      title: 'Site and owner',
      items: compactItems([
        item('site_name', 'Site name', settings?.site?.site_name),
        item('display_name', 'Display name', settings?.site?.display_name),
        item('logo_url', 'Logo URL', theme?.brand?.logo_url, true),
        item('owner_email', 'Owner email', owner.email, true),
        item('owner_status', 'Owner status', owner.status, false, 'status'),
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

watch(() => props.record, (record) => {
  displayRecord.value = cloneRecord(record)
  clearErrors()
  resetForms()
}, { deep: true, immediate: true })

async function saveSection(section: SectionKey) {
  if (!displayRecord.value?.id) {
    return
  }

  savingSection.value = section
  sectionErrors[section] = null

  try {
    const response = await api.apiFetch<Record<string, any>>(`/admin/central/partners/${encodeURIComponent(displayRecord.value.id)}/profile`, {
      method: 'PATCH',
      scope: 'central',
      body: buildSectionPayload(section),
      idempotencyKey: api.idempotencyKey(),
    })
    displayRecord.value = response
    emit('saved', response)
    resetForms()
  } catch (err: any) {
    sectionErrors[section] = err
  } finally {
    savingSection.value = null
  }
}

function buildSectionPayload(section: SectionKey) {
  const payloads: Record<SectionKey, Record<string, any>> = {
    partner: {
      code: partnerForm.code,
      name: partnerForm.name,
      type: partnerForm.type,
      status: partnerForm.status,
      stock_percent: partnerForm.stock_percent,
    },
    tenant: {
      code: tenantForm.code,
      name: tenantForm.name,
      status: tenantForm.status,
    },
    domain: {
      host: domainForm.host,
      type: domainForm.type,
      status: domainForm.status,
      is_primary: Boolean(domainForm.is_primary),
    },
    settings: {
      site: {
        site_name: settingsForm.site_name,
        display_name: nullable(settingsForm.display_name),
        locale: settingsForm.locale,
        timezone: settingsForm.timezone,
        support_email: nullable(settingsForm.support_email),
        support_phone: nullable(settingsForm.support_phone),
      },
      seo: {
        default_title: nullable(settingsForm.default_title),
        title_template: nullable(settingsForm.title_template),
        default_description: nullable(settingsForm.default_description),
        default_keywords: linesToArray(settingsForm.default_keywords),
        robots_default: settingsForm.robots_default,
        sitemap_enabled: Boolean(settingsForm.sitemap_enabled),
        robots_enabled: Boolean(settingsForm.robots_enabled),
      },
      maintenance: {
        active: Boolean(settingsForm.maintenance_active),
        mode: nullable(settingsForm.maintenance_mode),
        message: nullable(settingsForm.maintenance_message),
        retry_after_seconds: nullableNumber(settingsForm.maintenance_retry_after_seconds),
      },
      api: {
        base_url: nullable(settingsForm.api_base_url),
        realtime_url: nullable(settingsForm.realtime_url),
        asset_cdn_base_url: nullable(settingsForm.asset_cdn_base_url),
      },
      legal: {
        terms_content: nullable(settingsForm.terms_content),
      },
    },
    theme: {
      brand: {
        logo_url: nullable(themeForm.logo_url),
        favicon_url: nullable(themeForm.favicon_url),
        og_image_url: nullable(themeForm.og_image_url),
      },
      theme: {
        primary_color: themeForm.primary_color,
        secondary_color: themeForm.secondary_color,
        accent_color: themeForm.accent_color,
        background_color: themeForm.background_color,
        text_color: themeForm.text_color,
        font_family: themeForm.font_family,
      },
    },
    owner: compactPayload({
      owner_email: ownerForm.owner_email,
      owner_name: ownerForm.owner_name,
      owner_phone: nullable(ownerForm.owner_phone),
      owner_password: nullable(ownerForm.owner_password),
    }),
  }

  return {
    section,
    [section]: payloads[section],
  }
}

function resetForms() {
  const record = displayRecord.value || {}
  const tenant = primaryTenant.value || {}
  const domain = primaryDomain.value || {}
  const settings = tenantSettings.value
  const theme = tenantTheme.value
  const owner = ownerAdmin.value

  assignForm(partnerForm, {
    code: valueOrEmpty(record.code),
    name: valueOrEmpty(record.name),
    type: valueOrDefault(record.type, 'partner_store'),
    status: valueOrDefault(record.status, 'draft'),
    stock_percent: record.stock_percent ?? 0,
  })
  assignForm(tenantForm, {
    code: valueOrEmpty(tenant.code),
    name: valueOrEmpty(tenant.name),
    status: valueOrDefault(tenant.status, 'active'),
  })
  assignForm(domainForm, {
    host: valueOrEmpty(domain.host),
    type: valueOrDefault(domain.type, 'subdomain'),
    status: valueOrDefault(domain.status, 'active'),
    is_primary: Boolean(domain.is_primary ?? true),
  })
  assignForm(settingsForm, {
    site_name: valueOrDefault(settings?.site?.site_name, tenant.name || record.name || ''),
    display_name: valueOrEmpty(settings?.site?.display_name),
    locale: valueOrDefault(settings?.site?.locale, 'th-TH'),
    timezone: valueOrDefault(settings?.site?.timezone, 'Asia/Bangkok'),
    support_email: valueOrEmpty(settings?.site?.support_email),
    support_phone: valueOrEmpty(settings?.site?.support_phone),
    default_title: valueOrDefault(settings?.seo?.default_title, tenant.name || record.name || ''),
    title_template: valueOrEmpty(settings?.seo?.title_template),
    default_description: valueOrEmpty(settings?.seo?.default_description),
    default_keywords: arrayToLines(settings?.seo?.default_keywords),
    robots_default: valueOrDefault(settings?.seo?.robots_default, 'index,follow'),
    sitemap_enabled: Boolean(settings?.seo?.sitemap_enabled ?? true),
    robots_enabled: Boolean(settings?.seo?.robots_enabled ?? true),
    maintenance_active: Boolean(settings?.maintenance?.active ?? false),
    maintenance_mode: valueOrEmpty(settings?.maintenance?.mode),
    maintenance_message: valueOrEmpty(settings?.maintenance?.message),
    maintenance_retry_after_seconds: settings?.maintenance?.retry_after_seconds ?? '',
    api_base_url: valueOrDefault(settings?.api?.base_url, '/api/v1'),
    realtime_url: valueOrEmpty(settings?.api?.realtime_url),
    asset_cdn_base_url: valueOrEmpty(settings?.api?.asset_cdn_base_url),
    terms_content: valueOrEmpty(settings?.legal?.terms_content),
  })
  assignForm(themeForm, {
    logo_url: valueOrEmpty(theme?.brand?.logo_url),
    favicon_url: valueOrEmpty(theme?.brand?.favicon_url),
    og_image_url: valueOrEmpty(theme?.brand?.og_image_url),
    primary_color: valueOrDefault(theme?.theme?.primary_color, '#0F766E'),
    secondary_color: valueOrDefault(theme?.theme?.secondary_color, '#2563EB'),
    accent_color: valueOrDefault(theme?.theme?.accent_color, '#F59E0B'),
    background_color: valueOrDefault(theme?.theme?.background_color, '#FFFFFF'),
    text_color: valueOrDefault(theme?.theme?.text_color, '#111827'),
    font_family: valueOrDefault(theme?.theme?.font_family, 'Inter, sans-serif'),
  })
  assignForm(ownerForm, {
    owner_email: valueOrEmpty(owner.email),
    owner_name: valueOrEmpty(owner.name),
    owner_phone: valueOrEmpty(owner.phone),
    owner_password: '',
  })
}

function assignForm(target: Record<string, any>, source: Record<string, any>) {
  for (const key of Object.keys(target)) {
    delete target[key]
  }

  Object.assign(target, source)
}

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

function cloneRecord(record?: Record<string, any> | null) {
  return record ? JSON.parse(JSON.stringify(record)) : null
}

function clearErrors() {
  for (const key of Object.keys(sectionErrors)) {
    delete sectionErrors[key]
  }
}

function sectionBusy(_section?: SectionKey) {
  return Boolean(props.loading) || savingSection.value !== null
}

function errorMessage(error: any) {
  const fields = error?.details?.fields || error?.details || {}
  const fieldMessages = Object.values(fields)
    .flatMap((value: any) => Array.isArray(value) ? value : typeof value === 'string' ? [value] : [])
    .filter(Boolean)

  return fieldMessages[0] || error?.message || 'The section could not be saved.'
}

function valueOrEmpty(value: any) {
  return value === undefined || value === null ? '' : value
}

function valueOrDefault(value: any, fallback: any) {
  return value === undefined || value === null || value === '' ? fallback : value
}

function nullable(value: any) {
  return value === undefined || value === null || value === '' ? null : value
}

function nullableNumber(value: any) {
  if (value === undefined || value === null || value === '') {
    return null
  }

  return Number(value)
}

function linesToArray(value: any) {
  if (Array.isArray(value)) {
    return value
  }

  return String(value || '')
    .split('\n')
    .map((entry) => entry.trim())
    .filter(Boolean)
}

function arrayToLines(value: any) {
  return Array.isArray(value) ? value.join('\n') : ''
}

function compactPayload(payload: Record<string, any>) {
  const next: Record<string, any> = {}

  for (const [key, value] of Object.entries(payload)) {
    if (value !== undefined && value !== null && value !== '') {
      next[key] = value
    }
  }

  return next
}
</script>

<style scoped>
.np-partner-color-input {
  max-width: 3.25rem;
  min-width: 3.25rem;
}
</style>

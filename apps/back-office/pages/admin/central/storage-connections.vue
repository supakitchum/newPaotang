<template>
  <div>
    <AdminPageHeader :title="t('storageConnections.title')" :breadcrumbs="breadcrumbs">
      <template #actions>
        <button class="btn btn-primary-light btn-wave" type="button" :disabled="loading" @click="loadConnection">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          {{ t('common.refresh') }}
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" dismissible @dismiss="error = null" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="storage-layout">
      <section class="card custom-card storage-hero-card">
        <div class="card-body storage-hero">
          <div class="storage-hero-icon">
            <i class="ri-database-2-line" />
          </div>
          <div>
            <div class="storage-eyebrow">{{ t('storageConnections.eyebrow') }}</div>
            <h2>{{ t('storageConnections.heroTitle') }}</h2>
            <p>{{ t('storageConnections.heroDescription') }}</p>
          </div>
          <div class="storage-hero-status">
            <AdminStatusBadge :status="connection.status || 'inactive'" :label="statusLabel(connection.status || 'inactive')" />
            <span v-if="connection.last_test_status" class="storage-test-pill" :class="`is-${connection.last_test_status}`">
              {{ t('storageConnections.testStatusPrefix') }} {{ testStatusLabel(connection.last_test_status) }}
            </span>
          </div>
        </div>
      </section>

      <div class="row g-3 align-items-start">
        <div class="col-12 col-xl-8">
          <div class="storage-main-stack">
            <section class="card custom-card">
              <div class="card-header">
                <div>
                  <div class="card-title">{{ t('storageConnections.connectionSettings') }}</div>
                  <div class="text-muted fs-12">{{ t('storageConnections.secretsHelp') }}</div>
                </div>
                <div class="ms-auto d-flex flex-wrap gap-2">
                  <button class="btn btn-sm btn-success-light btn-wave" type="button" :disabled="testing || saving || !connection.configured" @click="testConnection">
                    <span v-if="testing" class="spinner-border spinner-border-sm me-1" />
                    <i v-else class="ri-flask-line me-1" />
                    {{ t('storageConnections.testConnection') }}
                  </button>
                  <button v-if="connection.configured" class="btn btn-sm btn-danger-light btn-wave" type="button" :disabled="disconnecting || saving" @click="disconnectConnection">
                    <span v-if="disconnecting" class="spinner-border spinner-border-sm me-1" />
                    <i v-else class="ri-link-unlink-m me-1" />
                    {{ t('storageConnections.disconnect') }}
                  </button>
                </div>
              </div>
              <div class="card-body">
                <form class="row g-3" @submit.prevent="saveConnection">
                  <div class="col-12 col-md-4">
                    <label class="form-label">{{ t('storageConnections.status') }}</label>
                    <select v-model="form.status" class="form-select">
                      <option value="active">{{ t('storageConnections.active') }}</option>
                      <option value="inactive">{{ t('storageConnections.inactive') }}</option>
                    </select>
                  </div>
                  <div class="col-12 col-md-4">
                    <label class="form-label">{{ t('storageConnections.bucket') }}</label>
                    <input v-model.trim="form.bucket" class="form-control" autocomplete="off" placeholder="my-production-bucket">
                  </div>
                  <div class="col-12 col-md-4">
                    <label class="form-label">{{ t('storageConnections.region') }}</label>
                    <input v-model.trim="form.region" class="form-control" autocomplete="off" placeholder="ap-southeast-1">
                  </div>

                  <div class="col-12 col-md-6">
                    <label class="form-label">{{ t('storageConnections.accessKeyId') }}</label>
                    <input v-model.trim="form.access_key_id" class="form-control" type="password" autocomplete="off" :placeholder="connection.access_key_id_masked || 'AKIA...'">
                    <div v-if="connection.access_key_id_masked" class="form-text">{{ t('storageConnections.current') }}: {{ connection.access_key_id_masked }}</div>
                  </div>
                  <div class="col-12 col-md-6">
                    <label class="form-label">{{ t('storageConnections.secretAccessKey') }}</label>
                    <input v-model.trim="form.secret_access_key" class="form-control" type="password" autocomplete="off" :placeholder="connection.secret_access_key_configured ? t('storageConnections.keepCurrentPlaceholder') : t('storageConnections.required')">
                  </div>

                  <div class="col-12 col-md-6">
                    <label class="form-label">{{ t('storageConnections.endpoint') }}</label>
                    <input v-model.trim="form.endpoint" class="form-control" autocomplete="off" placeholder="https://s3.ap-southeast-1.amazonaws.com">
                  </div>
                  <div class="col-12 col-md-6">
                    <label class="form-label">{{ t('storageConnections.publicUrl') }}</label>
                    <input v-model.trim="form.url" class="form-control" autocomplete="off" placeholder="https://cdn.example.com">
                  </div>

                  <div class="col-12 col-md-4">
                    <label class="form-label">{{ t('storageConnections.rootPrefix') }}</label>
                    <input v-model.trim="form.root_prefix" class="form-control" autocomplete="off" placeholder="lotteries">
                  </div>
                  <div class="col-12 col-md-4">
                    <label class="form-label">{{ t('storageConnections.visibility') }}</label>
                    <select v-model="form.visibility" class="form-select">
                      <option value="private">{{ t('storageConnections.private') }}</option>
                      <option value="public">{{ t('storageConnections.public') }}</option>
                    </select>
                  </div>
                  <div class="col-12 col-md-4">
                    <label class="form-label">{{ t('storageConnections.sessionToken') }}</label>
                    <input v-model.trim="form.session_token" class="form-control" type="password" autocomplete="off" :placeholder="connection.session_token_configured ? t('storageConnections.keepCurrentPlaceholder') : t('storageConnections.optional')">
                  </div>

                  <div class="col-12">
                    <div class="form-check form-switch">
                      <input id="usePathStyle" v-model="form.use_path_style_endpoint" class="form-check-input" type="checkbox">
                      <label class="form-check-label" for="usePathStyle">{{ t('storageConnections.usePathStyleEndpoint') }}</label>
                    </div>
                  </div>

                  <div class="col-12 d-flex justify-content-end">
                    <button class="btn btn-primary btn-wave" type="submit" :disabled="saving || testing || disconnecting">
                      <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                      {{ t('storageConnections.saveConnection') }}
                    </button>
                  </div>
                </form>
              </div>
            </section>

            <section class="card custom-card">
              <div class="card-header">
                <div>
                  <div class="card-title">{{ t('storageConnections.uploadRouting') }}</div>
                  <div class="text-muted fs-12">{{ t('storageConnections.uploadRoutingHelp') }}</div>
                </div>
                <span class="storage-route-count ms-auto">{{ routes.length }} {{ t('storageConnections.categories') }}</span>
              </div>
              <div class="card-body">
                <form class="storage-route-panel" @submit.prevent="saveUploadRouting">
                  <div class="storage-route-list">
                    <div v-for="route in routes" :key="route.route_key" class="storage-route-row">
                      <div class="storage-route-copy">
                        <strong>{{ routeLabel(route) }}</strong>
                        <span>{{ routeDescription(route) }}</span>
                        <code>{{ route.path_hint || '-' }}</code>
                      </div>
                      <div class="storage-route-controls">
                        <label>
                          <span>{{ t('storageConnections.driver') }}</span>
                          <select v-model="route.driver" class="form-select form-select-sm">
                            <option value="local">{{ t('storageConnections.localStorage') }}</option>
                            <option value="aws_s3">{{ t('storageConnections.awsS3') }}</option>
                          </select>
                        </label>
                        <label>
                          <span>{{ t('storageConnections.categoryPrefix') }}</span>
                          <input v-model.trim="route.root_prefix" class="form-control form-control-sm" autocomplete="off" placeholder="optional/folder">
                        </label>
                      </div>
                    </div>
                  </div>

                  <div class="storage-route-note">
                    <i class="ri-folder-shield-2-line" />
                    {{ t('storageConnections.partnerFolderNote') }}
                  </div>

                  <div class="storage-route-actions">
                    <button class="btn btn-primary btn-wave" type="submit" :disabled="savingRoutes || loading || routes.length === 0">
                      <span v-if="savingRoutes" class="spinner-border spinner-border-sm me-2" />
                      {{ t('storageConnections.saveUploadRouting') }}
                    </button>
                  </div>
                </form>
              </div>
            </section>
          </div>
        </div>

        <div class="col-12 col-xl-4">
          <aside class="card custom-card h-100">
            <div class="card-header">
              <div class="card-title">{{ t('storageConnections.runtimeReadiness') }}</div>
            </div>
            <div class="card-body">
              <div class="storage-readiness">
                <div class="storage-readiness-row">
                  <span>{{ t('storageConnections.s3Adapter') }}</span>
                  <AdminStatusBadge :status="requirements.adapter_installed ? 'active' : 'inactive'" :label="requirements.adapter_installed ? t('storageConnections.installed') : t('storageConnections.missing')" />
                </div>
                <div class="storage-readiness-row">
                  <span>{{ t('storageConnections.runtimeDisk') }}</span>
                  <strong>{{ requirements.runtime_disk || 's3' }}</strong>
                </div>
                <div class="storage-readiness-row">
                  <span>{{ t('storageConnections.assetDiskHint') }}</span>
                  <strong>{{ requirements.asset_disk_hint || '-' }}</strong>
                </div>
                <div class="storage-readiness-row">
                  <span>{{ t('storageConnections.lastTested') }}</span>
                  <strong>{{ formatDateTime(connection.last_tested_at) || '-' }}</strong>
                </div>
              </div>

              <div v-if="!requirements.adapter_installed" class="alert alert-warning mt-3 mb-0">
                {{ t('storageConnections.installPackageBeforeProbe') }}
                <code>{{ requirements.required_package || 'league/flysystem-aws-s3-v3' }}</code>
              </div>

              <div v-if="connection.last_test_message" class="storage-last-message mt-3">
                <div class="text-muted fs-12">{{ t('storageConnections.lastTestMessage') }}</div>
                <p>{{ translatedLastTestMessage }}</p>
              </div>

              <ul class="storage-notes">
                <li v-for="note in requirementNotes" :key="note">{{ translateNote(note) }}</li>
              </ul>
            </div>
          </aside>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
type AnyRecord = Record<string, any>

definePageMeta({ layout: 'admin' })

const api = useAdminApi()
const { t } = useAdminLocale()

const loading = ref(false)
const saving = ref(false)
const savingRoutes = ref(false)
const testing = ref(false)
const disconnecting = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const connection = ref<AnyRecord>({})
const requirements = ref<AnyRecord>({})
const routes = ref<AnyRecord[]>([])

const form = reactive({
  status: 'inactive',
  bucket: '',
  region: 'ap-southeast-1',
  endpoint: '',
  url: '',
  root_prefix: 'lotteries',
  visibility: 'private',
  use_path_style_endpoint: false,
  access_key_id: '',
  secret_access_key: '',
  session_token: '',
})

const requirementNotes = computed(() => Array.isArray(requirements.value.notes) ? requirements.value.notes : [])
const breadcrumbs = computed(() => [
  t('common.admin'),
  t('common.central'),
  t('menus.categories.administration'),
  t('storageConnections.title'),
])
const translatedLastTestMessage = computed(() => translateLastTestMessage(connection.value.last_test_message))

onMounted(() => {
  void loadConnection()
})

async function loadConnection() {
  loading.value = true
  error.value = null
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/storage-connections/aws-s3', { scope: 'central' })
    applyResponse(response)
  } catch (err: any) {
    error.value = err
  } finally {
    loading.value = false
  }
}

async function saveConnection() {
  saving.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/storage-connections/aws-s3', {
      method: 'PUT',
      scope: 'central',
      body: { ...form },
      successMessage: false,
    })
    applyResponse(response)
    clearSecrets()
    successMessage.value = t('storageConnections.saved')
  } catch (err: any) {
    error.value = err
  } finally {
    saving.value = false
  }
}

async function saveUploadRouting() {
  savingRoutes.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/storage-connections/upload-routes', {
      method: 'PUT',
      scope: 'central',
      body: { routes: storageRoutesPayload() },
      successMessage: false,
    })
    applyResponse(response)
    successMessage.value = t('storageConnections.routesSaved')
  } catch (err: any) {
    error.value = err
  } finally {
    savingRoutes.value = false
  }
}

async function testConnection() {
  testing.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/storage-connections/aws-s3/test', {
      method: 'POST',
      scope: 'central',
      body: {},
      successMessage: false,
    })
    applyResponse(response)
    successMessage.value = t('storageConnections.testPassed')
  } catch (err: any) {
    error.value = err
    await loadConnection()
  } finally {
    testing.value = false
  }
}

async function disconnectConnection() {
  const confirmed = !import.meta.client || window.confirm(t('storageConnections.disconnectConfirm'))
  if (!confirmed) return

  disconnecting.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/storage-connections/aws-s3', {
      method: 'DELETE',
      scope: 'central',
      successMessage: false,
    })
    applyResponse(response)
    clearSecrets()
    successMessage.value = t('storageConnections.disconnected')
  } catch (err: any) {
    error.value = err
  } finally {
    disconnecting.value = false
  }
}

function applyResponse(response: AnyRecord) {
  connection.value = response.connection || {}
  requirements.value = response.requirements || {}
  routes.value = Array.isArray(response.routes)
    ? response.routes.map((route: AnyRecord) => ({
        route_key: String(route.route_key || ''),
        label: String(route.label || ''),
        description: String(route.description || ''),
        driver: route.driver === 'aws_s3' ? 'aws_s3' : 'local',
        root_prefix: String(route.root_prefix || ''),
        tenant_scoped: Boolean(route.tenant_scoped),
        sort_order: Number(route.sort_order || 0),
        path_hint: String(route.path_hint || ''),
      }))
    : []
  Object.assign(form, {
    status: connection.value.status === 'active' ? 'active' : 'inactive',
    bucket: connection.value.bucket || '',
    region: connection.value.region || 'ap-southeast-1',
    endpoint: connection.value.endpoint || '',
    url: connection.value.url || '',
    root_prefix: connection.value.root_prefix || 'lotteries',
    visibility: connection.value.visibility === 'public' ? 'public' : 'private',
    use_path_style_endpoint: Boolean(connection.value.use_path_style_endpoint),
    access_key_id: '',
    secret_access_key: '',
    session_token: '',
  })
}

function clearSecrets() {
  form.access_key_id = ''
  form.secret_access_key = ''
  form.session_token = ''
}

function storageRoutesPayload() {
  return routes.value.map((route) => ({
    route_key: route.route_key,
    driver: route.driver === 'aws_s3' ? 'aws_s3' : 'local',
    root_prefix: route.root_prefix || '',
  }))
}

function routeLabel(route: AnyRecord) {
  const key = `storageConnections.routes.${route.route_key}.label`
  const translated = t(key)

  return translated === key ? route.label : translated
}

function routeDescription(route: AnyRecord) {
  const key = `storageConnections.routes.${route.route_key}.description`
  const translated = t(key)

  return translated === key ? route.description : translated
}

function titleize(value: string) {
  return String(value || '')
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())
}

function statusLabel(value: string) {
  const key = String(value || '').toLowerCase() === 'active' ? 'active' : 'inactive'
  return t(`storageConnections.${key}`)
}

function testStatusLabel(value: string) {
  const normalized = String(value || '').toLowerCase()
  if (normalized === 'passed') return t('storageConnections.passed')
  if (normalized === 'failed') return t('storageConnections.failed')

  return titleize(value)
}

function translateNote(value: unknown) {
  const text = String(value || '')
  const noteMap: Record<string, string> = {
    'Credentials are encrypted and never returned by API.': 'storageConnections.noteEncrypted',
    'Test connection writes, reads, and deletes one probe object.': 'storageConnections.noteProbe',
    'Set LOTTERY_IMAGE_DISK=s3 when the runtime should use this S3 bucket for lottery assets.': 'storageConnections.noteRuntimeDisk',
    'Choose AWS S3 per upload category below when the runtime should use this bucket.': 'storageConnections.noteRuntimeDisk',
  }
  const key = noteMap[text]

  return key ? t(key) : text
}

function translateLastTestMessage(value: unknown) {
  const text = String(value || '')
  const messageMap: Record<string, string> = {
    'AWS S3 write/read/delete probe passed.': 'storageConnections.probePassedMessage',
  }
  const key = messageMap[text]

  return key ? t(key) : text
}

function formatDateTime(value: string | null | undefined) {
  if (!value) return ''
  try {
    return new Intl.DateTimeFormat('th-TH', {
      dateStyle: 'medium',
      timeStyle: 'short',
      timeZone: 'Asia/Bangkok',
    }).format(new Date(value))
  } catch {
    return String(value)
  }
}

const alertType = (err: any) => ([403, 404, 422, 503].includes(Number(err?.status)) ? 'warning' : 'danger')
</script>

<style scoped>
.storage-layout {
  display: grid;
  gap: 16px;
}

.storage-hero-card {
  margin-bottom: 0;
}

.storage-main-stack {
  display: grid;
  gap: 16px;
}

.storage-hero {
  display: flex;
  align-items: center;
  gap: 16px;
  min-height: 118px;
}

.storage-hero-icon {
  width: 52px;
  height: 52px;
  display: grid;
  place-items: center;
  border-radius: 8px;
  background: rgba(var(--primary-rgb), .1);
  color: var(--primary-color);
  font-size: 26px;
  flex: 0 0 auto;
}

.storage-hero h2 {
  margin: 0;
  font-size: 22px;
  font-weight: 700;
}

.storage-hero p {
  margin: 4px 0 0;
  color: var(--text-muted);
}

.storage-eyebrow {
  color: var(--primary-color);
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
}

.storage-hero-status {
  margin-left: auto;
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px;
}

.storage-test-pill {
  border-radius: 999px;
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 700;
  background: var(--light);
  color: var(--text-muted);
}

.storage-test-pill.is-passed {
  background: rgba(var(--success-rgb), .12);
  color: rgb(var(--success-rgb));
}

.storage-test-pill.is-failed {
  background: rgba(var(--danger-rgb), .12);
  color: rgb(var(--danger-rgb));
}

.storage-readiness {
  display: grid;
  gap: 10px;
}

.storage-readiness-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--default-border);
}

.storage-readiness-row span {
  color: var(--text-muted);
}

.storage-readiness-row strong {
  min-width: 0;
  text-align: end;
  word-break: break-word;
}

.storage-last-message {
  padding: 12px;
  border-radius: 8px;
  background: var(--light);
}

.storage-last-message p {
  margin: 2px 0 0;
  word-break: break-word;
}

.storage-notes {
  margin: 14px 0 0;
  padding-left: 18px;
  color: var(--text-muted);
  display: grid;
  gap: 6px;
}

.storage-route-panel {
  border: 1px solid var(--default-border);
  border-radius: 8px;
  padding: 14px;
  background: var(--custom-white);
}

.storage-route-heading {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 12px;
}

.storage-route-title {
  font-weight: 700;
}

.storage-route-count {
  flex: 0 0 auto;
  border-radius: 999px;
  padding: 4px 10px;
  background: rgba(var(--primary-rgb), .08);
  color: var(--primary-color);
  font-size: 12px;
  font-weight: 700;
}

.storage-route-list {
  display: grid;
  gap: 10px;
}

.storage-route-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(320px, 420px);
  gap: 14px;
  align-items: center;
  padding: 12px;
  border: 1px solid var(--default-border);
  border-radius: 8px;
  background: var(--light);
}

.storage-route-copy {
  min-width: 0;
  display: grid;
  gap: 4px;
}

.storage-route-copy strong {
  color: var(--default-text-color);
}

.storage-route-copy span {
  color: var(--text-muted);
  font-size: 12px;
}

.storage-route-copy code {
  width: fit-content;
  max-width: 100%;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.storage-route-controls {
  display: grid;
  grid-template-columns: 150px minmax(0, 1fr);
  gap: 10px;
}

.storage-route-controls label {
  display: grid;
  gap: 4px;
  margin: 0;
}

.storage-route-controls label span {
  color: var(--text-muted);
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
}

.storage-route-note {
  margin-top: 12px;
  display: flex;
  align-items: flex-start;
  gap: 8px;
  color: var(--text-muted);
  font-size: 12px;
}

.storage-route-note i {
  color: var(--primary-color);
  font-size: 16px;
}

.storage-route-actions {
  margin-top: 14px;
  display: flex;
  justify-content: flex-end;
}

@media (max-width: 991.98px) {
  .storage-hero {
    align-items: flex-start;
    flex-direction: column;
    min-height: 0;
  }

  .storage-hero-status {
    margin-left: 0;
    justify-content: flex-start;
  }

  .storage-route-row {
    grid-template-columns: 1fr;
  }

  .storage-route-controls {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 575.98px) {
  .storage-layout > .row {
    margin-left: 0;
    margin-right: 0;
  }

  .storage-layout > .row > [class*="col-"] {
    padding-left: 0;
    padding-right: 0;
  }
}
</style>

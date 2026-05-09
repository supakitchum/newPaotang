<template>
  <div>
    <AdminOperationHeader
      v-if="resource"
      :scope="scope"
      :group="resource.group"
      :title="pageTitle"
    >
      <template #actions>
        <NuxtLink v-if="mode === 'detail'" :to="listPath" class="btn btn-light btn-wave">
          <i class="ri-arrow-left-line me-1" />
          Back
        </NuxtLink>
        <button v-if="canReload" class="btn btn-outline-primary btn-wave" type="button" :disabled="loading" @click="load()">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminOperationHeader>

    <AdminPageHeader v-else title="Page not found" :breadcrumbs="['Admin', scopeLabel, 'Not found']" />

    <AdminApiState v-if="!resource" message="This back-office route is not registered in the operations catalog." />
    <AdminApiState v-else-if="resource.apiGap" :message="resource.apiGap" />

    <template v-else-if="mode === 'report-index'">
      <div class="row">
        <div v-for="key in resource.reportKeys || []" :key="key" class="col-sm-6 col-xl-3">
          <NuxtLink class="card custom-card np-admin-link-card" :to="`${scopeBasePath}/reports/${key}`">
            <div class="card-body">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <p class="text-muted mb-1">Report</p>
                  <h6 class="mb-0">{{ titleize(key) }}</h6>
                </div>
                <i class="ri-bar-chart-box-line fs-24 text-primary" />
              </div>
            </div>
          </NuxtLink>
        </div>
      </div>
    </template>

    <template v-else-if="mode === 'settings'">
      <AdminApiState :error="error" />
      <div class="card custom-card">
        <div class="card-header">
          <div class="card-title">Configuration JSON</div>
        </div>
        <div class="card-body">
          <AdminLoader v-if="loading" />
          <textarea v-else v-model="settingsDraft" class="form-control np-admin-json-editor" spellcheck="false" />
        </div>
        <div class="card-footer d-flex justify-content-end gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="loading" @click="resetSettings">Reset</button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="saving" @click="saveSettings">
            <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
            Save
          </button>
        </div>
      </div>
    </template>

    <template v-else-if="mode === 'report-detail'">
      <AdminFilterBar :filters="reportFilters" :model-value="filters" @apply="applyFilters" />
      <AdminExportPanel :actions="resource.collectionActions || []" @run="openCollectionAction" />
      <AdminApiState :error="error" />
      <AdminReportPanel :data="detail" :loading="loading" />
    </template>

    <template v-else-if="mode === 'summary'">
      <AdminFilterBar v-if="resource.filters?.length" :filters="resource.filters" :model-value="filters" @apply="applyFilters" />
      <AdminApiState :error="error" />
      <AdminDetailSection :title="resource.title" :record="detail" :loading="loading" />
    </template>

    <template v-else-if="mode === 'detail'">
      <AdminApiState v-if="detailGap" :message="detailGap" />
      <AdminApiState :error="error" />
      <AdminDetailSection :title="`${resource.title} detail`" :record="detail" :loading="loading && !detailGap" />
      <div v-if="resource.detailJsonEditor && resource.updateEndpoint && !detailGap" class="card custom-card">
        <div class="card-header">
          <div class="card-title">Update JSON</div>
        </div>
        <div class="card-body">
          <AdminLoader v-if="loading" />
          <textarea v-else v-model="detailDraft" class="form-control np-admin-json-editor" spellcheck="false" />
        </div>
        <div class="card-footer d-flex justify-content-end gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="loading || saving" @click="resetDetailDraft">Reset</button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="loading || saving" @click="saveDetailDraft">
            <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
            Save
          </button>
        </div>
      </div>
      <AdminExportPanel :actions="detailActions" @run="openDetailAction" />
    </template>

    <template v-else>
      <AdminFilterBar v-if="resource.filters?.length" :filters="resource.filters" :model-value="filters" @apply="applyFilters" />
      <AdminExportPanel :actions="resource.collectionActions || []" @run="openCollectionAction" />
      <AdminApiState :error="error" />
      <AdminDataTable
        :title="resource.title"
        :columns="resource.columns || []"
        :rows="rows"
        :loading="loading"
        :empty-title="`No ${resource.title.toLowerCase()}`"
        empty-message="No records were returned from the approved back-office API."
      >
        <template v-for="column in resource.columns || []" #[`cell-${column.key}`]="{ row }">
          <AdminStatusBadge v-if="column.type === 'status'" :status="row[column.key]" />
          <span v-else>{{ row[column.key] ?? '-' }}</span>
        </template>
        <template #rowActions="{ row }">
          <div class="d-flex justify-content-end gap-1">
            <NuxtLink
              v-if="hasDetailRoute"
              :to="`${scopeBasePath}/${resource.slug}/${row.__id}`"
              class="btn btn-sm btn-primary btn-wave"
            >
              Detail
            </NuxtLink>
            <button
              v-for="action in resource.actions || []"
              :key="action.key"
              type="button"
              :class="`btn btn-sm btn-${action.variant || 'outline-primary'} btn-wave`"
              @click="openRowAction(action, row)"
            >
              {{ action.label }}
            </button>
          </div>
        </template>
      </AdminDataTable>
      <AdminPagination :next-cursor="meta.next_cursor" :loading="loading" @next="load(meta.next_cursor)" />
    </template>

    <AdminConfirmAction
      v-model="confirm.open"
      :title="confirm.title"
      :message="confirm.message"
      :requires-reason="confirm.action?.reason"
      :requires-payload="Boolean(confirm.action?.payloadTemplate)"
      :payload-template="confirm.action?.payloadTemplate"
      :loading="saving"
      :error="actionError"
      @confirm="runConfirmedAction"
    />
  </div>
</template>

<script setup lang="ts">
import type { OperationAction, OperationResource } from '~/composables/useAdminOperationsCatalog'
import { formatDateTime, titleize } from '~/utils/format'

const props = defineProps<{
  scope: 'tenant' | 'central'
}>()

const route = useRoute()
const api = useAdminApi()
const session = useAdminSession()
const catalog = useAdminOperationsCatalog()

const loading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const actionError = ref<any>(null)
const rows = ref<any[]>([])
const detail = ref<any>(null)
const settingsDraft = ref('')
const detailDraft = ref('')
const filters = ref<Record<string, any>>({})
const meta = reactive({ next_cursor: null as string | null, has_more: false })
const confirm = reactive<{
  open: boolean
  title: string
  message: string
  action: OperationAction | null
  row: any
}>({
  open: false,
  title: '',
  message: '',
  action: null,
  row: null,
})

const slugParts = computed(() => normalizeSlug(route.params.slug))
const resolved = computed(() => catalog.resolve(props.scope, slugParts.value))
const resource = computed(() => resolved.value.resource)
const mode = computed(() => resolved.value.mode)
const recordId = computed(() => resolved.value.id)
const scopeLabel = computed(() => props.scope === 'tenant' ? 'Tenant' : 'Central')
const scopeBasePath = computed(() => `/admin/${props.scope}`)
const pageTitle = computed(() => mode.value === 'detail' ? `${resource.value?.title || 'Detail'} detail` : resource.value?.title || 'Operations')
const listPath = computed(() => resource.value ? `${scopeBasePath.value}/${resource.value.slug}` : scopeBasePath.value)
const canReload = computed(() => Boolean(resource.value && mode.value !== 'report-index' && !resource.value.apiGap && !detailGap.value))
const hasDetailRoute = computed(() => Boolean(resource.value?.detailEndpoint || resource.value?.detailApiGap))
const detailGap = computed(() => mode.value === 'detail' && !resource.value?.detailEndpoint ? resource.value?.detailApiGap || 'No documented detail GET endpoint is available for this route.' : '')
const detailActions = computed(() => resource.value?.actions || [])
const reportFilters = computed(() => resource.value?.filters?.length ? resource.value.filters : [
  { key: 'date_from', label: 'From', type: 'date' as const },
  { key: 'date_to', label: 'To', type: 'date' as const },
  { key: 'group_by', label: 'Group by' },
  { key: 'cursor', label: 'Cursor' },
  { key: 'limit', label: 'Limit', type: 'number' as const },
])

watch(() => route.fullPath, () => {
  if (!import.meta.client) {
    return
  }
  resetFilters()
  load()
})

onMounted(() => {
  resetFilters()
  load()
})

const resetFilters = () => {
  const next: Record<string, any> = {}
  for (const filter of resource.value?.filters || []) {
    next[filter.key] = filter.key === 'limit' ? 20 : ''
  }
  filters.value = next
}

const applyFilters = (next: Record<string, any>) => {
  filters.value = { ...next }
  load()
}

async function load(cursor?: string | null) {
  if (!session.isAuthenticated.value) {
    return
  }

  if (!resource.value || resource.value.apiGap || mode.value === 'report-index' || detailGap.value) {
    return
  }

  loading.value = true
  error.value = null
  try {
    if (mode.value === 'detail') {
      const response = await api.apiFetch(interpolate(resource.value.detailEndpoint || '', recordId.value), apiOptions())
      detail.value = extractData(response)
      detailDraft.value = JSON.stringify(detail.value || {}, null, 2)
      return
    }

    if (mode.value === 'settings') {
      const response = await api.apiFetch(resource.value.listEndpoint || '', apiOptions())
      detail.value = extractData(response)
      settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
      return
    }

    if (mode.value === 'report-detail') {
      const response = await api.apiFetch(resource.value.listEndpoint || '', apiOptions({ query: queryWithCursor(cursor) }))
      detail.value = response
      return
    }

    if (mode.value === 'summary') {
      const response = await api.apiFetch(resource.value.listEndpoint || '', apiOptions({ query: cleanQuery(filters.value) }))
      detail.value = extractData(response)
      return
    }

    const response = await api.apiFetch(resource.value.listEndpoint || '', apiOptions({ query: queryWithCursor(cursor) }))
    const nextRows = normalizeRows(response, resource.value)
    rows.value = cursor ? [...rows.value, ...nextRows] : nextRows
    const nextMeta = extractMeta(response)
    meta.next_cursor = nextMeta.next_cursor || null
    meta.has_more = Boolean(nextMeta.has_more || nextMeta.next_cursor)
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const saveSettings = async () => {
  if (!resource.value?.updateEndpoint) return
  saving.value = true
  error.value = null
  try {
    const payload = JSON.parse(settingsDraft.value || '{}')
    const response = await api.apiFetch(resource.value.updateEndpoint, apiOptions({
      method: resource.value.updateMethod || 'PATCH',
      body: payload,
      idempotencyKey: api.idempotencyKey(),
    }))
    detail.value = extractData(response)
    settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
  } catch (err: any) {
    error.value = err?.message ? err : { message: 'Settings JSON is invalid or could not be saved.', details: err }
  } finally {
    saving.value = false
  }
}

const resetSettings = () => {
  settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
}

const saveDetailDraft = async () => {
  if (!resource.value?.updateEndpoint || !recordId.value) return
  saving.value = true
  error.value = null
  try {
    const payload = JSON.parse(detailDraft.value || '{}')
    const response = await api.apiFetch(interpolate(resource.value.updateEndpoint, recordId.value), apiOptions({
      method: resource.value.updateMethod || 'PATCH',
      body: payload,
      idempotencyKey: api.idempotencyKey(),
    }))
    detail.value = extractData(response)
    detailDraft.value = JSON.stringify(detail.value || {}, null, 2)
  } catch (err: any) {
    error.value = err?.message ? err : { message: 'Detail JSON is invalid or could not be saved.', details: err }
  } finally {
    saving.value = false
  }
}

const resetDetailDraft = () => {
  detailDraft.value = JSON.stringify(detail.value || {}, null, 2)
}

const openRowAction = (action: OperationAction, row: any) => {
  confirm.open = true
  confirm.action = action
  confirm.row = row
  confirm.title = action.label
  confirm.message = `Confirm ${action.label.toLowerCase()} for ${row.__id || 'selected record'}.`
  actionError.value = null
}

const openDetailAction = (action: OperationAction) => {
  openRowAction(action, { ...(detail.value || {}), __id: recordId.value })
}

const openCollectionAction = (action: OperationAction) => {
  confirm.open = true
  confirm.action = action
  confirm.row = null
  confirm.title = action.label
  confirm.message = `Confirm ${action.label.toLowerCase()} for ${resource.value?.title || 'this page'}.`
  actionError.value = null
}

const runConfirmedAction = async (reason: string, payloadJson = '') => {
  if (!confirm.action || !resource.value) return
  saving.value = true
  actionError.value = null
  try {
    const id = confirm.row?.__id || recordId.value
    const endpoint = interpolate(confirm.action.endpoint, id)
    const body = buildActionBody(confirm.action, reason, payloadJson)
    await api.apiFetch(endpoint, apiOptions({
      method: confirm.action.method || 'POST',
      body,
      idempotencyKey: api.idempotencyKey(),
    }))
    confirm.open = false
    await load()
  } catch (err) {
    actionError.value = err
  } finally {
    saving.value = false
  }
}

const buildActionBody = (action: OperationAction, reason: string, payloadJson: string) => {
  if (action.payloadTemplate) {
    const payload = JSON.parse(payloadJson || '{}')
    return action.reason ? { ...payload, reason } : payload
  }

  return action.reason ? { reason } : undefined
}

const apiOptions = (extra: Record<string, any> = {}) => ({
  scope: props.scope,
  tenantId: props.scope === 'tenant' ? session.currentTenantId.value : undefined,
  ...extra,
})

const queryWithCursor = (cursor?: string | null) => ({
  ...cleanQuery(filters.value),
  cursor: cursor || filters.value.cursor || undefined,
})

const cleanQuery = (value: Record<string, any>) => Object.fromEntries(Object.entries(value)
  .filter(([, entry]) => entry !== '' && entry !== undefined && entry !== null))

const interpolate = (endpoint: string, id?: string | null) => endpoint.replace(/\{[^}]+\}/g, encodeURIComponent(id || ''))

const normalizeSlug = (value: unknown): string[] => {
  if (Array.isArray(value)) return value.map(String)
  if (typeof value === 'string') return [value]
  return []
}

const extractData = (response: any) => response?.data ?? response

const extractItems = (response: any) => {
  if (Array.isArray(response)) return response
  if (Array.isArray(response?.data)) return response.data
  if (Array.isArray(response?.data?.items)) return response.data.items
  if (Array.isArray(response?.items)) return response.items
  return []
}

const extractMeta = (response: any) => response?.meta || response?.data?.meta || {}

const normalizeRows = (response: any, item: OperationResource) => extractItems(response).map((row: any) => {
  const id = row?.[item.idKey || 'id'] || row?.id || row?.uuid
  const display: Record<string, any> = { ...row, __raw: row, __id: id }
  for (const column of item.columns || []) {
    display[column.key] = formatValue(getPath(row, column.key), column.type)
  }
  return display
})

const getPath = (value: any, path: string) => path.split('.').reduce((current, key) => current?.[key], value)

const formatValue = (value: any, type?: string) => {
  if (value === undefined || value === null || value === '') return '-'
  if (type === 'datetime') return formatDateTime(String(value))
  if (type === 'money') return new Intl.NumberFormat('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(value || 0))
  if (type === 'json' || typeof value === 'object') return JSON.stringify(value)
  return value
}
</script>

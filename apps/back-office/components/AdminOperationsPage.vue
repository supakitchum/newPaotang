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
      <AdminMenuTreeEditor
        v-if="isMenuManagement"
        :scope="scope"
        :model-value="detail"
        :loading="loading"
        :saving="saving"
        :error="error"
        @save="saveMenuTree"
      />
      <div v-else-if="hasSettingsForm" class="card custom-card">
        <div class="card-header">
          <div class="card-title">Configuration</div>
        </div>
        <div class="card-body">
          <AdminLoader v-if="loading" />
          <div v-else class="row g-3">
            <div v-for="field in resource.settingsFields || []" :key="field.key" :class="field.type === 'textarea' || field.type === 'json' || field.type === 'lines' ? 'col-12' : 'col-md-6'">
              <div v-if="field.type === 'checkbox'" class="form-check form-switch mt-4">
                <input :id="fieldId(`settings-${field.key}`)" v-model="settingsForm[field.key]" class="form-check-input" type="checkbox">
                <label class="form-check-label" :for="fieldId(`settings-${field.key}`)">{{ field.label }}</label>
                <div v-if="field.help" class="form-text">{{ field.help }}</div>
              </div>
              <template v-else>
                <label class="form-label" :for="fieldId(`settings-${field.key}`)">{{ field.label }}</label>
                <select v-if="field.type === 'select'" :id="fieldId(`settings-${field.key}`)" v-model="settingsForm[field.key]" class="form-select">
                  <option value="">Select</option>
                  <option v-for="option in field.options || []" :key="option" :value="option">{{ option }}</option>
                </select>
                <textarea
                  v-else-if="field.type === 'textarea' || field.type === 'json' || field.type === 'lines'"
                  :id="fieldId(`settings-${field.key}`)"
                  v-model="settingsForm[field.key]"
                  class="form-control"
                  rows="4"
                  :placeholder="field.placeholder"
                />
                <input
                  v-else
                  :id="fieldId(`settings-${field.key}`)"
                  v-model="settingsForm[field.key]"
                  class="form-control"
                  :type="inputType(field)"
                  :min="field.min"
                  :step="field.step"
                  :placeholder="field.placeholder"
                >
                <div v-if="field.help" class="form-text">{{ field.help }}</div>
              </template>
            </div>
          </div>
        </div>
        <div class="card-footer d-flex justify-content-end gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="loading" @click="resetSettingsForm">Reset</button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="saving" @click="saveSettingsForm">
            <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
            Save
          </button>
        </div>
      </div>
      <div v-else class="card custom-card">
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

      <div
        v-for="panel in resource.secondarySettings || []"
        :key="panel.key"
        class="card custom-card"
      >
        <div class="card-header">
          <div class="card-title">{{ panel.title }}</div>
        </div>
        <div class="card-body">
          <AdminApiState :error="secondaryErrors[panel.key]" />
          <AdminLoader v-if="secondaryLoading[panel.key]" />
          <div v-else-if="secondaryForms[panel.key]" class="row g-3">
            <div v-for="field in panel.settingsFields || []" :key="field.key" :class="field.type === 'textarea' || field.type === 'json' || field.type === 'lines' ? 'col-12' : 'col-md-6'">
              <div v-if="field.type === 'checkbox'" class="form-check form-switch mt-4">
                <input :id="fieldId(`secondary-${panel.key}-${field.key}`)" v-model="secondaryForms[panel.key][field.key]" class="form-check-input" type="checkbox">
                <label class="form-check-label" :for="fieldId(`secondary-${panel.key}-${field.key}`)">{{ field.label }}</label>
                <div v-if="field.help" class="form-text">{{ field.help }}</div>
              </div>
              <template v-else>
                <label class="form-label" :for="fieldId(`secondary-${panel.key}-${field.key}`)">{{ field.label }}</label>
                <select v-if="field.type === 'select'" :id="fieldId(`secondary-${panel.key}-${field.key}`)" v-model="secondaryForms[panel.key][field.key]" class="form-select">
                  <option value="">Select</option>
                  <option v-for="option in field.options || []" :key="option" :value="option">{{ option }}</option>
                </select>
                <textarea
                  v-else-if="field.type === 'textarea' || field.type === 'json' || field.type === 'lines'"
                  :id="fieldId(`secondary-${panel.key}-${field.key}`)"
                  v-model="secondaryForms[panel.key][field.key]"
                  class="form-control"
                  rows="4"
                  :placeholder="field.placeholder"
                />
                <input
                  v-else
                  :id="fieldId(`secondary-${panel.key}-${field.key}`)"
                  v-model="secondaryForms[panel.key][field.key]"
                  class="form-control"
                  :type="inputType(field)"
                  :min="field.min"
                  :step="field.step"
                  :placeholder="field.placeholder"
                >
                <div v-if="field.help" class="form-text">{{ field.help }}</div>
              </template>
            </div>
          </div>
        </div>
        <div class="card-footer d-flex justify-content-end gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="secondaryLoading[panel.key] || secondarySaving[panel.key]" @click="resetSecondarySettingsForm(panel)">Reset</button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="secondarySaving[panel.key]" @click="saveSecondarySettingsForm(panel)">
            <span v-if="secondarySaving[panel.key]" class="spinner-border spinner-border-sm me-2" />
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

    <template v-if="showRelatedLists">
      <div v-for="related in resource.relatedLists || []" :key="related.key">
        <AdminFilterBar
          v-if="related.filters?.length"
          :filters="related.filters"
          :model-value="relatedFilters[related.key] || {}"
          @apply="applyRelatedFilters(related, $event)"
        />
        <AdminExportPanel :actions="related.collectionActions || []" @run="openRelatedCollectionAction(related, $event)" />
        <AdminApiState :error="relatedErrors[related.key]" />
        <AdminDataTable
          :title="related.title"
          :columns="related.columns || []"
          :rows="relatedRows[related.key] || []"
          :loading="relatedLoading[related.key]"
          :empty-title="related.emptyTitle || `No ${related.title.toLowerCase()}`"
          :empty-message="related.emptyMessage || 'No related records were returned from the approved back-office API.'"
        >
          <template v-for="column in related.columns || []" #[`cell-${column.key}`]="{ row }">
            <AdminStatusBadge v-if="column.type === 'status'" :status="row[column.key]" />
            <span v-else>{{ row[column.key] ?? '-' }}</span>
          </template>
          <template #rowActions="{ row }">
            <div class="d-flex justify-content-end gap-1">
              <button
                v-if="related.detailEndpoint"
                type="button"
                class="btn btn-sm btn-primary btn-wave"
                @click="openRelatedDetail(related, row)"
              >
                Detail
              </button>
              <button
                v-for="action in related.actions || []"
                :key="action.key"
                type="button"
                :class="`btn btn-sm btn-${action.variant || 'outline-primary'} btn-wave`"
                @click="openRelatedRowAction(related, action, row)"
              >
                {{ action.label }}
              </button>
            </div>
          </template>
        </AdminDataTable>
        <AdminPagination
          v-if="related.filters?.length"
          :next-cursor="relatedMeta[related.key]?.next_cursor || null"
          :loading="relatedLoading[related.key]"
          @next="loadRelatedList(related, relatedMeta[related.key]?.next_cursor || null)"
        />
      </div>
    </template>

    <AdminConfirmAction
      v-model="confirm.open"
      :title="confirm.title"
      :message="confirm.message"
      :requires-reason="confirm.action?.reason"
      :requires-payload="Boolean(confirm.action?.payloadTemplate) && !confirm.action?.formFields?.length"
      :payload-template="confirm.action?.payloadTemplate"
      :form-fields="confirm.action?.formFields || []"
      :record-context="confirm.row"
      :context-fields="confirm.action?.contextFields || resource?.confirmContextFields || []"
      :loading="saving"
      :error="actionError"
      @confirm="runConfirmedAction"
    />

    <AdminModal v-model="relatedDetail.open" :title="relatedDetail.title">
      <AdminApiState :error="relatedDetail.error" />
      <AdminDetailSection title="Detail" :record="relatedDetail.record" :loading="relatedDetail.loading" />
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" @click="relatedDetail.open = false">Close</button>
      </template>
    </AdminModal>
  </div>
</template>

<script setup lang="ts">
import type { OperationAction, OperationFilter, OperationFormField, OperationRelatedList, OperationResource, OperationSettingsPanel } from '~/composables/useAdminOperationsCatalog'
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
const settingsForm = reactive<Record<string, any>>({})
const secondaryDetails = reactive<Record<string, any>>({})
const secondaryForms = reactive<Record<string, Record<string, any>>>({})
const secondaryLoading = reactive<Record<string, boolean>>({})
const secondarySaving = reactive<Record<string, boolean>>({})
const secondaryErrors = reactive<Record<string, any>>({})
const detailDraft = ref('')
const filters = ref<Record<string, any>>({})
const meta = reactive({ next_cursor: null as string | null, has_more: false })
const relatedFilters = reactive<Record<string, Record<string, any>>>({})
const relatedRows = reactive<Record<string, any[]>>({})
const relatedLoading = reactive<Record<string, boolean>>({})
const relatedErrors = reactive<Record<string, any>>({})
const relatedMeta = reactive<Record<string, { next_cursor: string | null, has_more: boolean }>>({})
const confirm = reactive<{
  open: boolean
  title: string
  message: string
  action: OperationAction | null
  row: any
  related: OperationRelatedList | null
}>({
  open: false,
  title: '',
  message: '',
  action: null,
  row: null,
  related: null,
})
const relatedDetail = reactive<{
  open: boolean
  title: string
  loading: boolean
  error: any
  record: any
}>({
  open: false,
  title: '',
  loading: false,
  error: null,
  record: null,
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
const hasSettingsForm = computed(() => Boolean(resource.value?.settingsFields?.length))
const isMenuManagement = computed(() => resource.value?.slug === 'menu-management')
const showRelatedLists = computed(() => Boolean(
  resource.value?.relatedLists?.length
  && (mode.value === 'detail' || mode.value === 'settings')
  && !resource.value.apiGap
  && !detailGap.value,
))
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
  filters.value = defaultFilterValues(resource.value?.filters || [])
  resetRelatedFilters()
}

const applyFilters = (next: Record<string, any>) => {
  filters.value = { ...next }
  load()
}

const applyRelatedFilters = (related: OperationRelatedList, next: Record<string, any>) => {
  relatedFilters[related.key] = { ...defaultFilterValues(related.filters || []), ...next }
  loadRelatedList(related)
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
      await loadRelatedLists()
      return
    }

    if (mode.value === 'settings') {
      const response = await api.apiFetch(resource.value.listEndpoint || '', apiOptions())
      detail.value = extractData(response)
      settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
      resetSettingsForm()
      await Promise.all([loadRelatedLists(), loadSecondarySettings()])
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

const resetSettingsForm = () => {
  for (const key of Object.keys(settingsForm)) {
    delete settingsForm[key]
  }

  for (const field of resource.value?.settingsFields || []) {
    const value = getPath(detail.value || {}, field.sourceKey || field.key)
    settingsForm[field.key] = value !== undefined && value !== null
      ? normalizeInitialFieldValue(field, value)
      : field.defaultValue !== undefined ? field.defaultValue : normalizeInitialFieldValue(field, value)
  }
}

const saveSettingsForm = async () => {
  if (!resource.value?.updateEndpoint || !resource.value.settingsFields?.length) return
  saving.value = true
  error.value = null
  try {
    const payload = buildPayloadFromFields(resource.value.settingsFields, settingsForm)
    const response = await api.apiFetch(resource.value.updateEndpoint, apiOptions({
      method: resource.value.updateMethod || 'PATCH',
      body: payload,
      idempotencyKey: api.idempotencyKey(),
    }))
    detail.value = extractData(response)
    settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
    resetSettingsForm()
  } catch (err: any) {
    error.value = err
  } finally {
    saving.value = false
  }
}

const saveMenuTree = async (reason: string, items: any[]) => {
  if (!resource.value?.updateEndpoint) return
  saving.value = true
  error.value = null
  try {
    const response = await api.apiFetch(resource.value.updateEndpoint, apiOptions({
      method: resource.value.updateMethod || 'PUT',
      body: { items, reason },
      idempotencyKey: api.idempotencyKey(),
    }))
    detail.value = extractData(response)
    settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
  } catch (err: any) {
    error.value = err
  } finally {
    saving.value = false
  }
}

const loadSecondarySettings = async () => {
  const panels = resource.value?.secondarySettings || []
  if (!panels.length) return

  await Promise.all(panels.map(async (panel) => {
    secondaryLoading[panel.key] = true
    secondaryErrors[panel.key] = null
    secondaryForms[panel.key] = secondaryForms[panel.key] || {}
    try {
      const response = await api.apiFetch(panel.listEndpoint, apiOptions())
      secondaryDetails[panel.key] = extractData(response)
      resetSecondarySettingsForm(panel)
    } catch (err) {
      secondaryErrors[panel.key] = err
    } finally {
      secondaryLoading[panel.key] = false
    }
  }))
}

const resetSecondarySettingsForm = (panel: OperationSettingsPanel) => {
  const form = secondaryForms[panel.key] || {}
  for (const key of Object.keys(form)) {
    delete form[key]
  }

  for (const field of panel.settingsFields || []) {
    const value = getPath(secondaryDetails[panel.key] || {}, field.sourceKey || field.key)
    form[field.key] = value !== undefined && value !== null
      ? normalizeInitialFieldValue(field, value)
      : field.defaultValue !== undefined ? field.defaultValue : normalizeInitialFieldValue(field, value)
  }

  secondaryForms[panel.key] = form
}

const saveSecondarySettingsForm = async (panel: OperationSettingsPanel) => {
  secondarySaving[panel.key] = true
  secondaryErrors[panel.key] = null
  try {
    const payload = buildPayloadFromFields(panel.settingsFields, secondaryForms[panel.key] || {})
    const response = await api.apiFetch(panel.updateEndpoint, apiOptions({
      method: panel.updateMethod || 'PATCH',
      body: payload,
      idempotencyKey: api.idempotencyKey(),
    }))
    secondaryDetails[panel.key] = extractData(response)
    resetSecondarySettingsForm(panel)
  } catch (err: any) {
    secondaryErrors[panel.key] = err
  } finally {
    secondarySaving[panel.key] = false
  }
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
  confirm.related = null
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
  confirm.row = buildCollectionContext()
  confirm.related = null
  confirm.title = action.label
  confirm.message = `Confirm ${action.label.toLowerCase()} for ${resource.value?.title || 'this page'}.`
  actionError.value = null
}

const openRelatedCollectionAction = (related: OperationRelatedList, action: OperationAction) => {
  confirm.open = true
  confirm.action = action
  confirm.row = null
  confirm.related = related
  confirm.title = action.label
  confirm.message = `Confirm ${action.label.toLowerCase()} for ${related.title}.`
  actionError.value = null
}

const openRelatedRowAction = (related: OperationRelatedList, action: OperationAction, row: any) => {
  confirm.open = true
  confirm.action = action
  confirm.row = row
  confirm.related = related
  confirm.title = action.label
  confirm.message = `Confirm ${action.label.toLowerCase()} for ${row.__id || 'selected related record'}.`
  actionError.value = null
}

const openRelatedDetail = async (related: OperationRelatedList, row: any) => {
  if (!related.detailEndpoint) return
  relatedDetail.open = true
  relatedDetail.title = `${related.title} detail`
  relatedDetail.loading = true
  relatedDetail.error = null
  relatedDetail.record = null
  try {
    const response = await api.apiFetch(interpolate(related.detailEndpoint, row.__id), apiOptions())
    relatedDetail.record = extractData(response)
  } catch (err) {
    relatedDetail.error = err
  } finally {
    relatedDetail.loading = false
  }
}

const runConfirmedAction = async (reason: string, payloadJson = '', formValues: Record<string, any> = {}) => {
  if (!confirm.action || !resource.value) return
  saving.value = true
  actionError.value = null
  try {
    const id = confirm.row?.__id || recordId.value
    const endpoint = interpolate(confirm.action.endpoint, id)
    const body = buildActionBody(confirm.action, reason, payloadJson, formValues)
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

const loadRelatedLists = async () => {
  const lists = resource.value?.relatedLists || []
  if (!lists.length) return

  await Promise.all(lists.map((related) => loadRelatedList(related)))
}

const loadRelatedList = async (related: OperationRelatedList, cursor?: string | null) => {
  relatedLoading[related.key] = true
  relatedErrors[related.key] = null
  try {
    const endpoint = interpolate(related.listEndpoint, recordId.value)
    const relatedQuery = cleanQuery({
      ...ensureRelatedFilters(related),
      cursor: cursor || relatedFilters[related.key]?.cursor || undefined,
    })

    if (!relatedQuery.limit) {
      relatedQuery.limit = 20
    }

    const response = await api.apiFetch(endpoint, apiOptions({ query: relatedQuery }))
    const nextRows = normalizeRows(response, {
      scope: resource.value?.scope || props.scope,
      slug: related.key,
      title: related.title,
      group: resource.value?.group || '',
      idParam: related.idParam,
      idKey: related.idKey || 'id',
      columns: related.columns,
    })
    relatedRows[related.key] = cursor ? [...(relatedRows[related.key] || []), ...nextRows] : nextRows
    const nextMeta = extractMeta(response)
    relatedMeta[related.key] = {
      next_cursor: nextMeta.next_cursor || null,
      has_more: Boolean(nextMeta.has_more || nextMeta.next_cursor),
    }
  } catch (err) {
    relatedErrors[related.key] = err
    relatedRows[related.key] = []
    relatedMeta[related.key] = { next_cursor: null, has_more: false }
  } finally {
    relatedLoading[related.key] = false
  }
}

const buildActionBody = (action: OperationAction, reason: string, payloadJson: string, formValues: Record<string, any>) => {
  let payload: Record<string, any> = {}

  if (action.formFields?.length) {
    payload = buildPayloadFromFields(action.formFields, formValues)
  } else if (action.payloadTemplate) {
    const payload = JSON.parse(payloadJson || '{}')
    return action.reason ? compactPayload({ ...payload, reason }) : compactPayload(payload)
  }

  if (action.reason) {
    payload.reason = reason
  }

  const compacted = compactPayload(payload)
  return Object.keys(compacted).length ? compacted : undefined
}

const buildPayloadFromFields = (fields: OperationFormField[], values: Record<string, any>) => {
  const payload: Record<string, any> = {}

  for (const field of fields) {
    const value = normalizePayloadField(field, values[field.key])
    if (value === undefined) continue
    setPath(payload, field.key, value)
  }

  return compactPayload(payload)
}

const normalizePayloadField = (field: OperationFormField, value: any) => {
  if (field.type === 'checkbox') {
    return Boolean(value)
  }

  if (field.type === 'number') {
    if (value === '' || value === undefined || value === null) return undefined
    return Number(value)
  }

  if (field.type === 'json') {
    if (value === '' || value === undefined || value === null) return undefined

    const parsed = typeof value === 'string' ? JSON.parse(value) : value
    if (parsed !== null && typeof parsed === 'object') {
      return parsed
    }

    throw new Error(`${field.label} must be a JSON object or array.`)
  }

  if (field.type === 'lines') {
    const lines = String(value || '')
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean)
    if (!lines.length) return field.emptyValue === 'array' ? [] : undefined
    return field.itemKey ? lines.map((line) => ({ [field.itemKey || 'value']: line })) : lines
  }

  if (field.type === 'prize-lines') {
    const prizes = normalizePrizeLines(value)
    return prizes.length ? prizes : undefined
  }

  if (value === '' || value === undefined || value === null) {
    return undefined
  }

  return value
}

const normalizeInitialFieldValue = (field: OperationFormField, value: any) => {
  if (field.type === 'checkbox') {
    return Boolean(value)
  }

  if (field.type === 'datetime-local') {
    return formatDateTimeLocalValue(value)
  }

  if (field.type === 'json') {
    return formatJsonFieldValue(value)
  }

  if (field.type === 'lines') {
    return formatLines(value, field.valueKey || field.itemKey)
  }

  if (field.type === 'prize-lines') {
    return formatPrizeLines(value)
  }

  if (value === undefined || value === null || typeof value === 'object') {
    return ''
  }

  return value
}

const setPath = (target: Record<string, any>, path: string, value: any) => {
  const keys = path.split('.')
  let current = target
  keys.forEach((key, index) => {
    if (index === keys.length - 1) {
      current[key] = value
      return
    }

    current[key] = typeof current[key] === 'object' && current[key] !== null ? current[key] : {}
    current = current[key]
  })
}

const compactPayload = (value: any): any => {
  if (Array.isArray(value)) {
    return value
      .map((entry) => compactPayload(entry))
      .filter((entry) => entry !== undefined)
  }

  if (value && typeof value === 'object') {
    const compacted = Object.fromEntries(Object.entries(value)
      .map(([key, entry]) => [key, compactPayload(entry)])
      .filter(([, entry]) => entry !== undefined && entry !== null && entry !== ''))

    if ('currency' in compacted && !('amount' in compacted) && Object.keys(compacted).length === 1) {
      return undefined
    }

    return compacted
  }

  return value
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

const defaultFilterValues = (filterList: OperationFilter[] = []) => {
  const next: Record<string, any> = {}
  for (const filter of filterList) {
    next[filter.key] = filter.key === 'limit' ? 20 : ''
  }
  return next
}

const resetRelatedFilters = () => {
  for (const key of Object.keys(relatedFilters)) {
    delete relatedFilters[key]
  }
  for (const key of Object.keys(relatedMeta)) {
    delete relatedMeta[key]
  }
}

const ensureRelatedFilters = (related: OperationRelatedList) => {
  if (!relatedFilters[related.key]) {
    relatedFilters[related.key] = defaultFilterValues(related.filters || [])
  }

  return relatedFilters[related.key]
}

const cleanQuery = (value: Record<string, any>) => Object.fromEntries(Object.entries(value)
  .filter(([, entry]) => entry !== '' && entry !== undefined && entry !== null))

const buildCollectionContext = () => {
  const currentFilters = cleanQuery(filters.value)
  const reportKey = mode.value === 'report-detail' ? recordId.value : null
  return {
    __raw: {
      scope: props.scope,
      resource: resource.value?.title,
      report_key: reportKey,
      tenant_id: currentFilters.tenant_id || (props.scope === 'tenant' ? session.currentTenantId.value : undefined),
      date_from: currentFilters.date_from,
      date_to: currentFilters.date_to,
      group_by: currentFilters.group_by,
      filters: currentFilters,
    },
  }
}

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
    display[column.key] = formatValue(getFirstPath(row, [column.key, ...(column.fallbackKeys || [])]), column.type)
  }
  return display
})

const getPath = (value: any, path: string) => path.split('.').reduce((current, key) => current?.[key], value)

const getFirstPath = (value: any, paths: string[]) => {
  for (const path of paths) {
    const entry = getPath(value, path)
    if (entry !== undefined && entry !== null && entry !== '') {
      return entry
    }
  }
  return undefined
}

const fieldId = (key: string) => `admin-operation-${key.replace(/[^a-z0-9_-]/gi, '-')}`

const inputType = (field: OperationFormField) => {
  if (field.type === 'number') return 'number'
  if (field.type === 'datetime-local') return 'datetime-local'
  if (field.type === 'date') return 'date'
  if (field.type === 'password') return 'password'
  if (field.type === 'color') return 'color'
  return 'text'
}

const formatValue = (value: any, type?: string) => {
  if (value === undefined || value === null || value === '') return '-'
  if (type === 'customer') return formatCustomerValue(value)
  if (type === 'datetime') return formatDateTime(String(value))
  if (type === 'money') {
    const amount = typeof value === 'object' && value !== null ? value.amount : value
    return amount === undefined || amount === null ? '-' : new Intl.NumberFormat('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(amount || 0))
  }
  if (type === 'json' || typeof value === 'object') return JSON.stringify(value)
  return value
}

const formatCustomerValue = (value: any) => {
  if (value === undefined || value === null || value === '') return '-'
  if (typeof value !== 'object') return String(value)

  const id = value.id || value.customer_id || value.member_id || value.member_no
  const name = value.display_name || value.name || value.full_name
  const contact = value.phone || value.email
  const parts = [name, contact, id].filter((part, index, all) => part && all.indexOf(part) === index)

  return parts.length ? parts.join(' | ') : JSON.stringify(value)
}

const formatDateTimeLocalValue = (value: any) => {
  if (value === undefined || value === null || value === '') return ''

  const raw = String(value)
  const localMatch = raw.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/)
  if (localMatch) {
    return `${localMatch[1]}T${localMatch[2]}`
  }

  const date = new Date(raw)
  if (Number.isNaN(date.getTime())) {
    return raw
  }

  const pad = (entry: number) => String(entry).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

const formatJsonFieldValue = (value: any) => {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  if (typeof value === 'string') {
    return value
  }

  return JSON.stringify(value, null, 2)
}

const normalizePrizeLines = (value: any) => String(value || '')
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean)
  .map((line) => {
    const [prizeType = '', prizeNumber = '', amount = '', currency = 'THB'] = line.split(',').map((part) => part.trim())
    return {
      prize_type: prizeType,
      prize_number: prizeNumber,
      amount: {
        amount: Number(amount || 0),
        currency: currency || 'THB',
      },
    }
  })
  .filter((prize) => prize.prize_type && prize.prize_number && Number.isFinite(prize.amount.amount))

const formatPrizeLines = (value: any) => {
  if (!Array.isArray(value)) {
    return ''
  }

  return value.map((prize) => [
    prize?.prize_type,
    prize?.prize_number,
    prize?.amount?.amount,
    prize?.amount?.currency || 'THB',
  ].filter((entry) => entry !== undefined && entry !== null && entry !== '').join(',')).join('\n')
}

const formatLines = (value: any, valueKey?: string) => {
  if (!Array.isArray(value)) {
    return value === undefined || value === null ? '' : String(value)
  }

  return value
    .map((entry) => {
      if (valueKey && entry && typeof entry === 'object') {
        return getPath(entry, valueKey)
      }

      if (entry && typeof entry === 'object') {
        return JSON.stringify(entry)
      }

      return entry
    })
    .filter((entry) => entry !== undefined && entry !== null && entry !== '')
    .join('\n')
}
</script>

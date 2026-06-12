<template>
  <div>
    <AdminPageHeader title="Announcements" :breadcrumbs="['Admin', 'Tenant', 'Announcements']">
      <template #actions>
        <button class="btn btn-light btn-wave" type="button" @click="openCreateModal">
          <i class="ri-add-line me-1" />
          New announcement
        </button>
        <button class="btn btn-primary btn-wave" type="button" @click="loadAnnouncements">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before editing announcements." />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="card custom-card">
      <div class="card-header align-items-center gap-3">
        <div class="card-title">Announcement list</div>
        <div class="ms-auto d-flex flex-wrap gap-2">
          <input v-model="filters.q" class="form-control form-control-sm np-ann-search" placeholder="Search title or slug" @keyup.enter="loadAnnouncements">
          <select v-model="filters.status" class="form-select form-select-sm np-ann-status" @change="loadAnnouncements">
            <option value="">All statuses</option>
            <option v-for="status in statuses" :key="status" :value="status">{{ titleize(status) }}</option>
          </select>
        </div>
      </div>
      <div class="card-body">
        <AdminDataTable
          :columns="columns"
          :rows="announcements"
          :loading="loading"
          empty-title="No announcements"
          empty-message="Create the first customer-facing announcement for this partner."
          sortable
          embedded
          :sort-key="sort.key"
          :sort-direction="sort.direction"
          @sort-change="handleSort"
        >
          <template #cell-title="{ row }">
            <button class="btn btn-link p-0 fw-semibold text-start" type="button" @click="openEditModal(row)">
              {{ row.title }}
            </button>
            <div class="text-muted fs-12">{{ row.slug }}</div>
          </template>
          <template #cell-modal_enabled="{ row }">
            <AdminStatusBadge :status="row.modal_enabled" :label="row.modal_enabled ? 'Modal' : 'Hidden'" />
          </template>
          <template #cell-important="{ row }">
            <span v-if="row.important" class="badge bg-warning-transparent text-warning">Important</span>
            <span v-else class="text-muted">-</span>
          </template>
          <template #cell-display_window="{ row }">
            <div>{{ formatDateTime(row.display_start_at) }}</div>
            <div class="text-muted fs-12">to {{ formatDateTime(row.display_end_at) }}</div>
          </template>
          <template #rowActions="{ row }">
            <button class="btn btn-sm btn-primary-light btn-wave" type="button" @click="openEditModal(row)">
              Edit
            </button>
          </template>
        </AdminDataTable>
        <AdminPagination
          class="mt-3"
          :next-cursor="meta.next_cursor"
          :has-previous="pageState.index > 0"
          :loading="loading"
          @previous="loadPreviousPage"
          @next="loadNextPage"
        />
      </div>
    </div>

    <div v-if="formModalOpen" class="modal fade show np-ann-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-xl modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">{{ form.id ? 'Edit announcement' : 'Create announcement' }}</h5>
              <div class="text-muted fs-12">Customer modal image, schedule, and detail page content</div>
            </div>
            <button class="btn-close" type="button" aria-label="Close" :disabled="saving" @click="closeFormModal" />
          </div>
          <div class="modal-body">
            <form class="row g-3" @submit.prevent="saveAnnouncement">
              <div class="col-12">
                <div class="d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <label class="form-label mb-0">Localized content</label>
                  <div class="btn-group btn-group-sm" role="group" aria-label="Announcement language tabs">
                    <button
                      v-for="option in localeOptions"
                      :key="option.value"
                      class="btn"
                      :class="contentLocale === option.value ? 'btn-primary' : 'btn-outline-primary'"
                      type="button"
                      @click="contentLocale = option.value"
                    >
                      {{ option.label }}
                    </button>
                  </div>
                </div>
                <div class="form-text">The public API returns the matching language and falls back to Thai/default content if blank.</div>
              </div>
              <div class="col-12 col-lg-7">
                <label class="form-label">Title ({{ localeLabel(contentLocale) }})</label>
                <input v-model="form.title_i18n[contentLocale]" class="form-control" :class="invalidClass('title')" placeholder="Customer-facing title">
                <div class="invalid-feedback">{{ fieldError('title') }}</div>
              </div>
              <div class="col-12 col-lg-5">
                <label class="form-label">Slug</label>
                <input v-model="form.slug" class="form-control" :class="invalidClass('slug')" placeholder="Auto-generated from title if blank">
                <div class="invalid-feedback">{{ fieldError('slug') }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Status</label>
                <select v-model="form.status" class="form-select" :class="invalidClass('status')">
                  <option v-for="status in statuses" :key="status" :value="status">{{ titleize(status) }}</option>
                </select>
                <div class="invalid-feedback">{{ fieldError('status') }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Sort order</label>
                <input v-model.number="form.sort_order" type="number" class="form-control" :class="invalidClass('sort_order')">
                <div class="invalid-feedback">{{ fieldError('sort_order') }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Display start</label>
                <input v-model="form.display_start_at" type="datetime-local" class="form-control" :class="invalidClass('display_start_at')">
                <div class="invalid-feedback">{{ fieldError('display_start_at') }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Display end</label>
                <input v-model="form.display_end_at" type="datetime-local" class="form-control" :class="invalidClass('display_end_at')">
                <div class="invalid-feedback">{{ fieldError('display_end_at') }}</div>
              </div>
              <div class="col-12 d-flex flex-wrap gap-3">
                <label class="form-check form-switch mb-0">
                  <input v-model="form.modal_enabled" class="form-check-input" type="checkbox">
                  <span class="form-check-label">Show as modal</span>
                </label>
                <label class="form-check form-switch mb-0">
                  <input v-model="form.important" class="form-check-input" type="checkbox">
                  <span class="form-check-label">Important</span>
                </label>
              </div>
              <div class="col-12">
                <label class="form-label">Summary ({{ localeLabel(contentLocale) }})</label>
                <textarea v-model="form.summary_i18n[contentLocale]" class="form-control" rows="2" :class="invalidClass('summary')" />
                <div class="invalid-feedback">{{ fieldError('summary') }}</div>
              </div>
              <div class="col-12">
                <label class="form-label">Body ({{ localeLabel(contentLocale) }})</label>
                <textarea v-model="form.body_i18n[contentLocale]" class="form-control" rows="6" :class="invalidClass('body')" placeholder="Full detail shown on the customer news page." />
                <div class="invalid-feedback">{{ fieldError('body') }}</div>
              </div>
              <div class="col-12">
                <label class="form-label">Modal image</label>
                <input class="form-control" type="file" accept="image/*" :class="invalidClass('file')" @change="handleImageChange">
                <div class="invalid-feedback">{{ fieldError('file') || imageError }}</div>
                <div class="form-text">The API stores full and thumbnail variants for modal and list/detail pages.</div>
              </div>
              <div v-if="previewUrl || form.image_thumb_url" class="col-12">
                <div class="np-ann-preview">
                  <img :src="previewUrl || form.image_thumb_url" alt="Announcement preview">
                </div>
              </div>
              <div class="col-12">
                <div class="np-ann-behavior">
                  <div>
                    <span class="text-muted fs-12 d-block">Modal pick</span>
                    <span>Important first, otherwise random active news</span>
                  </div>
                  <div>
                    <span class="text-muted fs-12 d-block">Audience</span>
                    <span>Guests and logged-in customers</span>
                  </div>
                  <div>
                    <span class="text-muted fs-12 d-block">Detail path</span>
                    <code>/news/{{ form.slug || 'slug' }}</code>
                  </div>
                </div>
              </div>
              <button class="d-none" type="submit" aria-hidden="true" tabindex="-1" />
            </form>
          </div>
          <div class="modal-footer justify-content-between">
            <button v-if="form.id" class="btn btn-danger-light btn-wave" type="button" :disabled="saving" @click="archiveAnnouncement">
              <i class="ri-archive-line me-1" />
              Archive
            </button>
            <span v-else />
            <div class="d-flex gap-2">
              <button class="btn btn-light btn-wave" type="button" :disabled="saving" @click="resetForm">Reset</button>
              <button class="btn btn-primary btn-wave" type="button" :disabled="saveDisabled" @click="saveAnnouncement">
                <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                Save announcement
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div v-if="formModalOpen" class="modal-backdrop fade show np-ann-modal-backdrop" />
  </div>
</template>

<script setup lang="ts">
definePageMeta({
  layout: 'admin',
})

type Announcement = Record<string, any>

const api = useAdminApi()
const session = useAdminSession()
const tenantId = computed(() => session.currentTenantId.value)
const statuses = ['draft', 'active', 'inactive', 'archived']
const localeOptions = [
  { value: 'th-TH', label: 'TH' },
  { value: 'en-US', label: 'EN' },
] as const
const columns = [
  { key: 'title', label: 'Title' },
  { key: 'status', label: 'Status', type: 'status' },
  { key: 'modal_enabled', label: 'Modal' },
  { key: 'important', label: 'Priority' },
  { key: 'sort_order', label: 'Sort' },
  { key: 'display_window', label: 'Schedule' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]

const loading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const announcements = ref<Announcement[]>([])
const meta = ref<Record<string, any>>({})
const pageState = ref({ index: 0, cursors: [''] })
const formModalOpen = ref(false)
const contentLocale = ref<'th-TH' | 'en-US'>('th-TH')
const sort = reactive({ key: 'created_at', direction: 'desc' as 'asc' | 'desc' })
const filters = reactive({ q: '', status: '' })
const fieldErrors = ref<Record<string, string[]>>({})
const selectedImage = ref<File | null>(null)
const previewUrl = ref('')
const imageError = ref('')
const form = reactive<Record<string, any>>(defaultForm())

const saveDisabled = computed(() => (
  saving.value
  || !tenantId.value
  || !firstLocalizedValue(form.title_i18n, form.title)
  || Boolean(imageError.value)
))

function defaultForm() {
  return {
    id: '',
    title: '',
    title_i18n: localizedDefaults(),
    slug: '',
    summary: '',
    summary_i18n: localizedDefaults(),
    body: '',
    body_i18n: localizedDefaults(),
    status: 'draft',
    modal_enabled: true,
    important: false,
    display_start_at: '',
    display_end_at: '',
    sort_order: 0,
    image_full_url: '',
    image_thumb_url: '',
  }
}

const loadAnnouncements = async (cursor = '') => {
  if (!tenantId.value) return
  loading.value = true
  error.value = null

  try {
    const response: any = await api.apiFetch('/admin/tenant/announcements', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: {
        limit: 25,
        cursor: cursor || undefined,
        q: filters.q || undefined,
        status: filters.status || undefined,
        sort: sort.key,
        direction: sort.direction,
      },
    })

    announcements.value = Array.isArray(response.data) ? response.data : []
    meta.value = response.meta || {}
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const loadNextPage = () => {
  const cursor = String(meta.value.next_cursor || '')
  if (!cursor) return
  pageState.value.cursors[pageState.value.index + 1] = cursor
  pageState.value.index += 1
  void loadAnnouncements(cursor)
}

const loadPreviousPage = () => {
  if (pageState.value.index <= 0) return
  pageState.value.index -= 1
  void loadAnnouncements(pageState.value.cursors[pageState.value.index] || '')
}

const handleSort = (next: { key: string, direction: 'asc' | 'desc' }) => {
  const keyMap: Record<string, string> = {
    display_window: 'display_start_at',
    title: 'title',
    status: 'status',
    modal_enabled: 'modal_enabled',
    important: 'important',
    sort_order: 'sort_order',
    updated_at: 'updated_at',
  }
  sort.key = keyMap[next.key] || next.key
  sort.direction = next.direction
  pageState.value = { index: 0, cursors: [''] }
  void loadAnnouncements()
}

const selectAnnouncement = (row: Announcement) => {
  clearPreview()
  Object.assign(form, defaultForm(), {
    ...row,
    title_i18n: localizedFrom(row.title_i18n, row.title),
    summary_i18n: localizedFrom(row.summary_i18n, row.summary),
    body_i18n: localizedFrom(row.body_i18n, row.body),
    display_start_at: toDateTimeLocal(row.display_start_at),
    display_end_at: toDateTimeLocal(row.display_end_at),
  })
  fieldErrors.value = {}
}

const openCreateModal = () => {
  resetForm()
  formModalOpen.value = true
}

const openEditModal = (row: Announcement) => {
  selectAnnouncement(row)
  formModalOpen.value = true
}

const closeFormModal = () => {
  if (saving.value) return
  formModalOpen.value = false
  resetForm()
}

const resetForm = () => {
  clearPreview()
  Object.assign(form, defaultForm())
  fieldErrors.value = {}
  error.value = null
}

const saveAnnouncement = async () => {
  if (saveDisabled.value || !tenantId.value) return
  saving.value = true
  error.value = null
  fieldErrors.value = {}
  successMessage.value = ''

  try {
    const payload = buildPayload()
    const saved: any = form.id
      ? await api.apiFetch(`/admin/tenant/announcements/${encodeURIComponent(form.id)}`, {
        method: 'PATCH',
        scope: 'tenant',
        tenantId: tenantId.value,
        idempotencyKey: api.idempotencyKey(),
        body: payload,
      })
      : await api.apiFetch('/admin/tenant/announcements', {
        method: 'POST',
        scope: 'tenant',
        tenantId: tenantId.value,
        idempotencyKey: api.idempotencyKey(),
        body: payload,
      })

    if (selectedImage.value) {
      await uploadImage(saved.id)
    } else {
      selectAnnouncement(saved)
    }

    successMessage.value = 'Announcement saved.'
    await loadAnnouncements(pageState.value.cursors[pageState.value.index] || '')
    formModalOpen.value = false
    resetForm()
  } catch (err: any) {
    error.value = err
    fieldErrors.value = normalizeFieldErrors(err)
  } finally {
    saving.value = false
  }
}

const archiveAnnouncement = async () => {
  if (!tenantId.value || !form.id || saving.value) return
  saving.value = true
  error.value = null
  successMessage.value = ''

  try {
    await api.apiFetch(`/admin/tenant/announcements/${encodeURIComponent(form.id)}`, {
      method: 'DELETE',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      body: { reason: 'Archived from announcement manager' },
    })
    successMessage.value = 'Announcement archived.'
    formModalOpen.value = false
    resetForm()
    await loadAnnouncements(pageState.value.cursors[pageState.value.index] || '')
  } catch (err: any) {
    error.value = err
  } finally {
    saving.value = false
  }
}

const uploadImage = async (announcementId: string) => {
  if (!tenantId.value || !selectedImage.value) return
  const body = new FormData()
  body.append('file', selectedImage.value)
  const updated: any = await api.apiFetch(`/admin/tenant/announcements/${encodeURIComponent(announcementId)}/image`, {
    method: 'POST',
    scope: 'tenant',
    tenantId: tenantId.value,
    successMessage: false,
    body,
  })
  selectAnnouncement(updated)
}

const buildPayload = () => ({
  title: firstLocalizedValue(form.title_i18n, form.title),
  title_i18n: normalizedLocalized(form.title_i18n),
  slug: String(form.slug || '').trim() || undefined,
  summary: firstLocalizedValue(form.summary_i18n, form.summary) || null,
  summary_i18n: normalizedLocalized(form.summary_i18n),
  body: firstLocalizedValue(form.body_i18n, form.body) || null,
  body_i18n: normalizedLocalized(form.body_i18n),
  status: form.status || 'draft',
  modal_enabled: Boolean(form.modal_enabled),
  important: Boolean(form.important),
  display_start_at: toApiDateTime(form.display_start_at),
  display_end_at: toApiDateTime(form.display_end_at),
  sort_order: Number.isFinite(Number(form.sort_order)) ? Number(form.sort_order) : 0,
})

const handleImageChange = (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] || null
  clearPreview()
  imageError.value = ''

  if (!file) return

  if (!file.type.startsWith('image/')) {
    imageError.value = 'Only image files are accepted.'
    return
  }

  if (file.size < 1 || file.size > 8 * 1024 * 1024) {
    imageError.value = 'Image size must be between 1 byte and 8 MB.'
    return
  }

  selectedImage.value = file
  previewUrl.value = URL.createObjectURL(file)
}

const clearPreview = () => {
  if (previewUrl.value) {
    URL.revokeObjectURL(previewUrl.value)
  }
  previewUrl.value = ''
  selectedImage.value = null
  imageError.value = ''
}

const fieldError = (field: string) => (fieldErrors.value[field] || [])[0] || ''
const invalidClass = (field: string) => (fieldError(field) || (field === 'file' && imageError.value) ? 'is-invalid' : '')
const normalizeFieldErrors = (err: any) => {
  const details = err?.details?.fields || err?.details || {}
  return Object.fromEntries(Object.entries(details).map(([key, value]) => [key, Array.isArray(value) ? value : [String(value)]]))
}

const toApiDateTime = (value: string) => {
  if (!value) return null
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString()
}

const toDateTimeLocal = (value: string | null | undefined) => {
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  const pad = (next: number) => String(next).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

const formatDateTime = (value: string | null | undefined) => {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '-'
  return new Intl.DateTimeFormat('en-GB', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Bangkok',
  }).format(date)
}

const titleize = (value: string) => String(value || '-').replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase())
const alertType = (err: any) => ([403, 409, 422].includes(Number(err?.status)) ? 'warning' : 'danger')
const localeLabel = (value: 'th-TH' | 'en-US') => localeOptions.find((option) => option.value === value)?.label || value
function localizedDefaults() {
  return { 'th-TH': '', 'en-US': '' }
}
const localizedFrom = (value: any, fallback = '') => {
  const next = localizedDefaults()
  if (value && typeof value === 'object') {
    next['th-TH'] = String(value['th-TH'] || value.th || '')
    next['en-US'] = String(value['en-US'] || value.en || '')
  }
  if (!next['th-TH'] && fallback) {
    next['th-TH'] = String(fallback)
  }
  return next
}
const firstLocalizedValue = (value: any, fallback = '') => String(
  value?.['th-TH']
  || value?.['en-US']
  || fallback
  || '',
).trim()
const normalizedLocalized = (value: any) => ({
  'th-TH': String(value?.['th-TH'] || '').trim(),
  'en-US': String(value?.['en-US'] || '').trim(),
})

watch(tenantId, () => {
  resetForm()
  formModalOpen.value = false
  pageState.value = { index: 0, cursors: [''] }
  void loadAnnouncements()
}, { immediate: true })

onBeforeUnmount(() => {
  clearPreview()
})
</script>

<style scoped>
.np-ann-search {
  min-width: 220px;
}

.np-ann-status {
  min-width: 150px;
}

.np-ann-preview {
  background: #f8fafc;
  border: 1px dashed #d7dde8;
  border-radius: .65rem;
  display: grid;
  min-height: 220px;
  overflow: hidden;
  place-items: center;
}

.np-ann-preview img {
  display: block;
  max-height: 360px;
  max-width: 100%;
  object-fit: contain;
}

.np-ann-modal {
  display: block;
  z-index: 2000;
}

.np-ann-modal-backdrop {
  z-index: 1990;
}

.np-ann-behavior {
  background: #f8fafc;
  border: 1px solid #edf1f7;
  border-radius: .65rem;
  display: grid;
  gap: .85rem;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  padding: .9rem;
}

@media (max-width: 991.98px) {
  .np-ann-behavior {
    grid-template-columns: 1fr;
  }
}
</style>

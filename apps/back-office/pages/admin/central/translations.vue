<template>
  <div>
    <AdminPageHeader :title="t('translations.title')" :breadcrumbs="['Admin', 'Central', t('translations.title')]">
      <template #actions>
        <button class="btn btn-primary-light btn-wave" type="button" :disabled="loading" @click="loadAll">
          <i class="ri-refresh-line me-1" />
          {{ t('common.refresh') }}
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="errorMessage" type="danger" :message="errorMessage" dismissible @dismiss="errorMessage = ''" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="translation-shell">
      <section class="card custom-card translation-toolbar-card">
        <div class="card-body">
          <div>
            <h2 class="translation-title">{{ t('translations.title') }}</h2>
            <p class="translation-subtitle">{{ t('translations.subtitle') }}</p>
          </div>
          <div class="translation-toolbar">
            <label class="translation-control">
              <span>{{ t('translations.language') }}</span>
              <select v-model="selectedLocale" class="form-select" @change="resetAndLoadKeys">
                <option v-for="language in languages" :key="language.locale" :value="language.locale">
                  {{ language.native_name || language.locale }} ({{ language.locale }})
                </option>
              </select>
            </label>
            <label class="translation-control">
              <span>{{ t('translations.surface') }}</span>
              <select v-model="selectedSurface" class="form-select" @change="resetAndLoadKeys">
                <option value="customer">{{ t('common.customer') }}</option>
                <option value="back-office">{{ t('common.backOffice') }}</option>
                <option value="api">{{ t('common.api') }}</option>
              </select>
            </label>
            <label class="translation-control">
              <span>{{ t('translations.category') }}</span>
              <select v-model="selectedCategory" class="form-select" @change="resetAndLoadKeys">
                <option value="">{{ t('translations.allCategories') }}</option>
                <option v-for="category in categories" :key="category.category" :value="category.category">
                  {{ category.category }} ({{ category.total }})
                </option>
              </select>
            </label>
            <label class="translation-control translation-search">
              <span>{{ t('translations.search') }}</span>
              <input v-model="searchQuery" class="form-control" type="search" placeholder="common.language" @keyup.enter="resetAndLoadKeys">
            </label>
          </div>
        </div>
      </section>

      <section class="card custom-card">
        <div class="card-header">
          <div>
            <div class="card-title">{{ t('translations.translationGrid') }}</div>
            <div class="text-muted fs-12">{{ selectedLocale }} / {{ selectedSurface }}{{ selectedCategory ? ` / ${selectedCategory}` : '' }}</div>
          </div>
          <div class="ms-auto d-flex flex-wrap gap-2">
            <div class="translation-page-size">
              <span>{{ t('translations.rowsPerPage') }}</span>
              <select v-model.number="perPage" class="form-select form-select-sm" :disabled="loadingKeys" @change="changePerPage">
                <option v-for="option in pageSizeOptions" :key="option" :value="option">{{ option }}</option>
              </select>
            </div>
            <button class="btn btn-light btn-wave" type="button" :disabled="loadingKeys" @click="resetAndLoadKeys">
              <i class="ri-search-line me-1" />
              {{ t('translations.searchKeys') }}
            </button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="!canRequestDeploy || creatingRequest || !selectedCategory" @click="createDeployRequest">
              <span v-if="creatingRequest" class="spinner-border spinner-border-sm me-2" />
              <i v-else class="ri-upload-cloud-2-line me-1" />
              {{ t('translations.createRequest') }}
            </button>
          </div>
        </div>
        <div class="card-body p-0">
          <div v-if="loadingKeys" class="translation-empty">
            <span class="spinner-border spinner-border-sm me-2" />
            {{ t('translations.loadingTranslations') }}
          </div>
          <div v-else-if="keys.length === 0" class="translation-empty">{{ t('translations.noKeys') }}</div>
          <div v-else class="table-responsive">
            <table class="table translation-table mb-0">
              <thead>
                <tr>
                  <th>{{ t('common.key') }}</th>
                  <th>{{ t('translations.defaultText') }}</th>
                  <th>{{ t('translations.publishedValue') }}</th>
                  <th>{{ t('translations.draftValue') }}</th>
                  <th>{{ t('translations.variables') }}</th>
                  <th class="text-end">{{ t('common.action') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in keys" :key="item.id">
                  <td>
                    <div class="fw-semibold">{{ item.key }}</div>
                    <div class="text-muted fs-12">{{ item.category }}</div>
                  </td>
                  <td class="translation-copy">{{ item.default_text || '-' }}</td>
                  <td class="translation-copy">{{ item.published_value || '-' }}</td>
                  <td>
                    <textarea v-model="draftValues[item.id]" class="form-control translation-textarea" :disabled="!canEdit" rows="3" />
                    <div v-if="validationErrors(item).length" class="translation-validation">
                      <div v-for="message in validationErrors(item)" :key="message">{{ message }}</div>
                    </div>
                  </td>
                  <td>
                    <span v-if="!item.variables?.length" class="text-muted">-</span>
                    <span v-for="variable in item.variables" v-else :key="variable" class="badge bg-info-transparent text-info me-1">
                      {{ formatVariable(variable) }}
                    </span>
                  </td>
                  <td class="text-end">
                    <button class="btn btn-sm btn-primary-light btn-wave" type="button" :disabled="!canEdit || savingDraftId === item.id" @click="saveDraft(item)">
                      <span v-if="savingDraftId === item.id" class="spinner-border spinner-border-sm me-1" />
                      {{ t('translations.saveDraft') }}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-if="!loadingKeys && pagination.total > 0" class="translation-pagination">
            <div class="translation-pagination-summary">
              {{ pagination.from }}-{{ pagination.to }} {{ t('translations.ofRows') }} {{ pagination.total }}
              <span class="text-muted">({{ t('translations.page') }} {{ pagination.page }} {{ t('translations.ofRows') }} {{ pagination.last_page }})</span>
            </div>
            <div class="translation-pagination-actions">
              <button class="btn btn-sm btn-light btn-wave" type="button" :disabled="pagination.page <= 1 || loadingKeys" @click="changePage(pagination.page - 1)">
                <i class="ri-arrow-left-s-line me-1" />
                {{ t('translations.previousPage') }}
              </button>
              <button class="btn btn-sm btn-light btn-wave" type="button" :disabled="pagination.page >= pagination.last_page || loadingKeys" @click="changePage(pagination.page + 1)">
                {{ t('translations.nextPage') }}
                <i class="ri-arrow-right-s-line ms-1" />
              </button>
            </div>
          </div>
        </div>
      </section>

      <div class="row g-3">
        <div class="col-xl-6">
          <section class="card custom-card h-100">
            <div class="card-header">
              <div class="card-title">{{ t('translations.deployRequests') }}</div>
              <button class="btn btn-sm btn-light btn-wave ms-auto" type="button" @click="loadRequests">{{ t('common.refresh') }}</button>
            </div>
            <div class="card-body">
              <div v-if="requests.length === 0" class="translation-empty compact">{{ t('translations.noRequests') }}</div>
              <div v-else class="translation-request-list">
                <article v-for="request in requests" :key="request.id" class="translation-request">
                  <div>
                    <div class="fw-semibold">{{ request.title || request.id }}</div>
                    <div class="text-muted fs-12">{{ request.locale }} / {{ request.surface }} / {{ request.category }}</div>
                  </div>
                  <span class="badge" :class="statusClass(request.status)">{{ titleize(request.status) }}</span>
                  <div class="translation-request-actions">
                    <button v-if="['draft', 'rejected'].includes(request.status)" class="btn btn-sm btn-primary-light" type="button" :disabled="!canRequestDeploy" @click="submitRequest(request)">{{ t('translations.submitRequest') }}</button>
                    <button v-if="['draft', 'rejected'].includes(request.status)" class="btn btn-sm btn-outline-danger" type="button" :disabled="!canRequestDeploy" @click="cancelRequest(request)">{{ t('translations.cancelRequest') }}</button>
                  </div>
                </article>
              </div>
            </div>
          </section>
        </div>

        <div class="col-xl-6">
          <section class="card custom-card h-100">
            <div class="card-header">
              <div>
                <div class="card-title">{{ t('translations.ownerQueue') }}</div>
                <div class="text-muted fs-12">{{ t('translations.submittedOnly') }}</div>
              </div>
            </div>
            <div class="card-body">
              <div v-if="ownerQueue.length === 0" class="translation-empty compact">{{ t('translations.noSubmittedRequests') }}</div>
              <div v-else class="translation-owner-list">
                <article v-for="request in ownerQueue" :key="request.id" class="translation-owner-item">
                  <div class="translation-owner-head">
                    <div>
                      <div class="fw-semibold">{{ request.title || request.id }}</div>
                      <div class="text-muted fs-12">{{ request.locale }} / {{ request.surface }} / {{ request.category }}</div>
                    </div>
                    <span class="badge bg-warning-transparent text-warning">Submitted</span>
                  </div>
                  <div class="translation-diff">
                    <div v-for="item in request.items.slice(0, 4)" :key="item.id" class="translation-diff-row">
                      <div class="translation-diff-key">{{ item.key }}</div>
                      <div class="translation-diff-before">{{ item.current_value || '-' }}</div>
                      <div class="translation-diff-after">{{ item.draft_value || '-' }}</div>
                    </div>
                    <div v-if="request.items.length > 4" class="text-muted fs-12">+{{ request.items.length - 4 }} {{ t('translations.moreKeys') }}</div>
                  </div>
                  <div class="translation-request-actions justify-content-end">
                    <button class="btn btn-sm btn-info-light" type="button" :disabled="!canApproveDeploy" @click="previewRequest(request)">
                      {{ t('translations.previewRequest') }}
                    </button>
                    <button class="btn btn-sm btn-success-light" type="button" :disabled="!canApproveDeploy" @click="approveRequest(request)">
                      {{ t('translations.approveRequest') }}
                    </button>
                    <button class="btn btn-sm btn-danger-light" type="button" :disabled="!canApproveDeploy" @click="openReject(request)">
                      {{ t('translations.rejectRequest') }}
                    </button>
                  </div>
                </article>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>

    <div v-if="rejectingRequest" class="translation-modal-backdrop">
      <div class="translation-modal">
        <div class="translation-modal-header">
          <h3>{{ t('translations.rejectRequest') }}</h3>
          <button class="btn btn-sm btn-icon btn-light" type="button" @click="rejectingRequest = null">
            <i class="ri-close-line" />
          </button>
        </div>
        <label class="form-label">{{ t('translations.rejectReason') }}</label>
        <textarea v-model="rejectReason" class="form-control" rows="4" :placeholder="t('translations.rejectPlaceholder')" />
        <div class="d-flex justify-content-end gap-2 mt-3">
          <button class="btn btn-light" type="button" @click="rejectingRequest = null">{{ t('common.cancel') }}</button>
          <button class="btn btn-danger" type="button" :disabled="!rejectReason.trim() || rejecting" @click="rejectRequest">
            <span v-if="rejecting" class="spinner-border spinner-border-sm me-2" />
            {{ t('common.reject') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

type TranslationKeyRow = {
  id: string
  key: string
  category: string
  default_text: string | null
  published_value: string | null
  draft_value: string | null
  variables: string[]
  validation_errors: string[]
}

type TranslationRequest = {
  id: string
  locale: string
  surface: string
  category: string
  status: string
  title: string
  items: Array<{
    id: string
    key: string
    current_value: string | null
    draft_value: string | null
    validation_errors: string[]
  }>
}

type TranslationPagination = {
  page: number
  per_page: number
  total: number
  last_page: number
  from: number
  to: number
}

const api = useAdminApi()
const session = useAdminSession()
const { t, loadRuntimeBundle } = useAdminLocale()

const loading = ref(false)
const loadingKeys = ref(false)
const creatingRequest = ref(false)
const savingDraftId = ref('')
const rejecting = ref(false)
const errorMessage = ref('')
const successMessage = ref('')

const languages = ref<Array<{ locale: string, name: string, native_name: string }>>([])
const categories = ref<Array<{ category: string, total: number }>>([])
const keys = ref<TranslationKeyRow[]>([])
const requests = ref<TranslationRequest[]>([])
const draftValues = reactive<Record<string, string>>({})
const pageSizeOptions = [25, 50, 100, 200]
const perPage = ref(25)
const pagination = reactive<TranslationPagination>({
  page: 1,
  per_page: 25,
  total: 0,
  last_page: 1,
  from: 0,
  to: 0,
})

const selectedLocale = ref('th-TH')
const selectedSurface = ref('back-office')
const selectedCategory = ref('')
const searchQuery = ref('')
const rejectingRequest = ref<TranslationRequest | null>(null)
const rejectReason = ref('')

const canEdit = computed(() => session.hasPermission('translation.edit'))
const canRequestDeploy = computed(() => session.hasPermission('translation.request_deploy'))
const canApproveDeploy = computed(() => session.hasPermission('translation.approve_deploy'))
const ownerQueue = computed(() => requests.value.filter((request) => request.status === 'submitted'))

onMounted(async () => {
  session.restore()
  await loadAll()
})

const loadAll = async () => {
  loading.value = true
  errorMessage.value = ''
  try {
    await loadLanguages()
    await Promise.all([loadKeys(), loadRequests()])
  } catch (error: any) {
    errorMessage.value = error?.message || t('translations.loadFailed')
  } finally {
    loading.value = false
  }
}

const loadLanguages = async () => {
  const response: any = await api.apiFetch('/admin/central/translations/languages', { successMessage: false })
  languages.value = Array.isArray(response?.languages) ? response.languages : []
  if (!languages.value.some((language) => language.locale === selectedLocale.value)) {
    selectedLocale.value = languages.value[0]?.locale || 'th-TH'
  }
}

const loadKeys = async () => {
  loadingKeys.value = true
  errorMessage.value = ''
  try {
    const response: any = await api.apiFetch('/admin/central/translations/keys', {
      query: {
        locale: selectedLocale.value,
        surface: selectedSurface.value,
        category: selectedCategory.value || undefined,
        q: searchQuery.value || undefined,
        page: pagination.page,
        per_page: perPage.value,
      },
      successMessage: false,
    })
    categories.value = Array.isArray(response?.categories) ? response.categories : []
    keys.value = Array.isArray(response?.data) ? response.data : []
    const responsePagination = response?.pagination && typeof response.pagination === 'object' ? response.pagination : {}
    pagination.page = Number(responsePagination.page || pagination.page || 1)
    pagination.per_page = Number(responsePagination.per_page || perPage.value)
    pagination.total = Number(responsePagination.total || 0)
    pagination.last_page = Number(responsePagination.last_page || 1)
    pagination.from = Number(responsePagination.from || 0)
    pagination.to = Number(responsePagination.to || 0)
    perPage.value = pagination.per_page
    keys.value.forEach((item) => {
      draftValues[item.id] = item.draft_value ?? item.published_value ?? item.default_text ?? ''
    })
  } catch (error: any) {
    errorMessage.value = error?.message || t('translations.loadKeysFailed')
  } finally {
    loadingKeys.value = false
  }
}

const resetAndLoadKeys = () => {
  pagination.page = 1
  void loadKeys()
}

const changePerPage = () => {
  pagination.page = 1
  void loadKeys()
}

const changePage = (page: number) => {
  const nextPage = Math.min(Math.max(1, page), pagination.last_page || 1)
  if (nextPage === pagination.page || loadingKeys.value) {
    return
  }
  pagination.page = nextPage
  void loadKeys()
}

const loadRequests = async () => {
  const response: any = await api.apiFetch('/admin/central/translations/deploy-requests', { successMessage: false })
  requests.value = Array.isArray(response?.data) ? response.data : []
}

const saveDraft = async (item: TranslationKeyRow) => {
  savingDraftId.value = item.id
  errorMessage.value = ''
  try {
    await api.apiFetch(`/admin/central/translations/drafts/${item.id}`, {
      method: 'PATCH',
      body: {
        locale: selectedLocale.value,
        value: draftValues[item.id] ?? '',
      },
      successMessage: false,
    })
    successMessage.value = t('translations.draftSaved')
    await loadKeys()
  } catch (error: any) {
    errorMessage.value = error?.message || t('translations.saveDraftFailed')
  } finally {
    savingDraftId.value = ''
  }
}

const createDeployRequest = async () => {
  if (!selectedCategory.value) {
    errorMessage.value = t('translations.chooseCategory')
    return
  }

  creatingRequest.value = true
  errorMessage.value = ''
  try {
    await api.apiFetch('/admin/central/translations/deploy-requests', {
      method: 'POST',
      body: {
        locale: selectedLocale.value,
        surface: selectedSurface.value,
        category: selectedCategory.value,
      },
      successMessage: false,
    })
    successMessage.value = t('translations.requestCreated')
    await loadRequests()
  } catch (error: any) {
    errorMessage.value = error?.message || t('translations.createRequestFailed')
  } finally {
    creatingRequest.value = false
  }
}

const submitRequest = async (request: TranslationRequest) => {
  await requestAction(`/admin/central/translations/deploy-requests/${request.id}/submit`, t('translations.requestSubmitted'))
}

const cancelRequest = async (request: TranslationRequest) => {
  await requestAction(`/admin/central/translations/deploy-requests/${request.id}/cancel`, t('translations.requestCancelled'))
}

const approveRequest = async (request: TranslationRequest) => {
  await requestAction(`/admin/central/translations/deploy-requests/${request.id}/approve`, t('translations.requestDeployed'))
  await loadRuntimeBundle(selectedLocale.value)
}

const previewRequest = async (request: TranslationRequest) => {
  errorMessage.value = ''
  try {
    const response: any = await api.apiFetch(`/admin/central/translations/deploy-requests/${request.id}/preview-session`, {
      method: 'POST',
      successMessage: false,
    })
    const preview = response?.preview
    const token = preview?.token
    if (!token) {
      throw new Error(t('translations.previewTokenMissing'))
    }

    const query = `translation_preview_token=${encodeURIComponent(token)}&locale=${encodeURIComponent(request.locale)}`
    const path = request.surface === 'customer'
      ? `/?${query}`
      : `/admin/central/translations?${query}`
    window.open(path, '_blank', 'noopener,noreferrer')
  } catch (error: any) {
    errorMessage.value = error?.message || t('translations.previewCreateFailed')
  }
}

const openReject = (request: TranslationRequest) => {
  rejectingRequest.value = request
  rejectReason.value = ''
}

const rejectRequest = async () => {
  if (!rejectingRequest.value) return

  rejecting.value = true
  errorMessage.value = ''
  try {
    await api.apiFetch(`/admin/central/translations/deploy-requests/${rejectingRequest.value.id}/reject`, {
      method: 'POST',
      body: { reason: rejectReason.value },
      successMessage: false,
    })
    successMessage.value = t('translations.requestRejected')
    rejectingRequest.value = null
    rejectReason.value = ''
    await loadRequests()
  } catch (error: any) {
    errorMessage.value = error?.message || t('translations.rejectFailed')
  } finally {
    rejecting.value = false
  }
}

const requestAction = async (path: string, message: string) => {
  errorMessage.value = ''
  try {
    await api.apiFetch(path, { method: 'POST', successMessage: false })
    successMessage.value = message
    await loadRequests()
  } catch (error: any) {
    errorMessage.value = error?.message || t('translations.requestUpdateFailed')
  }
}

const validationErrors = (item: TranslationKeyRow) => {
  const value = draftValues[item.id] || ''
  const errors = [...(item.validation_errors || [])]
  const required = placeholderNames(item.default_text || '')
  const found = placeholderNames(value)
  required.forEach((name) => {
    if (!found.includes(name)) {
      const message = `${t('translations.missingPlaceholder')} {${name}}.`
      if (!errors.includes(message)) {
        errors.push(message)
      }
    }
  })
  return errors
}

const placeholderNames = (text: string) => Array.from(new Set(Array.from(text.matchAll(/\{([a-zA-Z0-9_]+)\}/g)).map((match) => match[1])))
const formatVariable = (variable: string) => `{${variable}}`

const titleize = (value: string) => String(value || '').replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())

const statusClass = (status: string) => ({
  'bg-secondary-transparent text-secondary': ['draft', 'cancelled'].includes(status),
  'bg-warning-transparent text-warning': status === 'submitted',
  'bg-success-transparent text-success': ['approved', 'deployed'].includes(status),
  'bg-danger-transparent text-danger': status === 'rejected',
})
</script>

<style scoped>
.translation-shell {
  display: grid;
  gap: 1rem;
}

.translation-toolbar-card .card-body {
  display: grid;
  gap: 1rem;
}

.translation-title {
  margin: 0;
  color: #172033;
  font-size: 1.25rem;
  font-weight: 700;
}

.translation-subtitle {
  margin: .25rem 0 0;
  color: #70809a;
}

.translation-toolbar {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: .75rem;
}

.translation-control {
  display: grid;
  gap: .35rem;
  color: #53637d;
  font-size: .78rem;
  font-weight: 700;
  text-transform: uppercase;
}

.translation-search {
  min-width: 220px;
}

.translation-page-size {
  display: flex;
  align-items: center;
  gap: .5rem;
  color: #53637d;
  font-size: .78rem;
  font-weight: 700;
}

.translation-page-size .form-select {
  width: 92px;
}

.translation-table th {
  color: #53637d;
  font-size: .75rem;
  text-transform: uppercase;
  white-space: nowrap;
}

.translation-table td {
  vertical-align: top;
}

.translation-copy {
  max-width: 280px;
  color: #26324a;
  white-space: pre-wrap;
}

.translation-textarea {
  min-width: 280px;
  resize: vertical;
}

.translation-validation {
  margin-top: .4rem;
  color: #d63939;
  font-size: .76rem;
}

.translation-empty {
  padding: 2rem;
  color: #70809a;
  text-align: center;
}

.translation-empty.compact {
  padding: 1rem;
}

.translation-pagination {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: .75rem;
  padding: .85rem 1rem;
  border-top: 1px solid #e6ebf2;
  background: #fff;
}

.translation-pagination-summary {
  color: #53637d;
  font-size: .82rem;
}

.translation-pagination-actions {
  display: flex;
  gap: .5rem;
}

.translation-request-list,
.translation-owner-list {
  display: grid;
  gap: .75rem;
}

.translation-request,
.translation-owner-item {
  display: grid;
  gap: .75rem;
  padding: .9rem;
  border: 1px solid #e6ebf2;
  border-radius: .5rem;
  background: #fff;
}

.translation-request {
  grid-template-columns: 1fr auto;
  align-items: start;
}

.translation-request-actions {
  display: flex;
  flex-wrap: wrap;
  gap: .5rem;
  grid-column: 1 / -1;
}

.translation-owner-head {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
}

.translation-diff {
  display: grid;
  gap: .35rem;
}

.translation-diff-row {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: .5rem;
  padding: .5rem;
  border-radius: .4rem;
  background: #f7f9fc;
  font-size: .82rem;
}

.translation-diff-key {
  color: #53637d;
  font-weight: 700;
}

.translation-diff-before {
  color: #8a98ad;
}

.translation-diff-after {
  color: #1c7c54;
  font-weight: 700;
}

.translation-modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 1080;
  display: grid;
  place-items: center;
  padding: 1rem;
  background: rgba(15, 23, 42, .45);
}

.translation-modal {
  width: min(520px, 100%);
  padding: 1rem;
  border-radius: .75rem;
  background: #fff;
  box-shadow: 0 24px 80px rgba(15, 23, 42, .25);
}

.translation-modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.translation-modal-header h3 {
  margin: 0;
  font-size: 1rem;
  font-weight: 700;
}

@media (max-width: 991px) {
  .translation-toolbar {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 575px) {
  .translation-toolbar {
    grid-template-columns: 1fr;
  }

  .translation-request {
    grid-template-columns: 1fr;
  }

  .translation-diff-row {
    grid-template-columns: 1fr;
  }

  .translation-pagination {
    align-items: stretch;
    flex-direction: column;
  }

  .translation-pagination-actions {
    justify-content: space-between;
  }
}
</style>

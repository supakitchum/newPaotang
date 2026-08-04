<template>
  <div>
    <AdminPageHeader :title="phrase('Public Relations')" :breadcrumbs="['Admin', 'Tenant', phrase('Public Relations')]">
      <template #actions>
        <button class="btn btn-primary-light btn-icon btn-wave" type="button" :disabled="loading" :title="phrase('Refresh')" @click="refreshPage">
          <i class="ri-refresh-line" />
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" :message="phrase('Select a tenant scope before managing public relations campaigns.')" />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" dismissible @dismiss="error = null" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="np-pr-tabs mb-4" role="tablist" :aria-label="phrase('Public relations workspace')">
      <button class="np-pr-tab" :class="{ active: activeTab === 'compose' }" type="button" @click="activeTab = 'compose'">
        <i class="ri-megaphone-line" />
        {{ phrase('Create campaign') }}
      </button>
      <button class="np-pr-tab" :class="{ active: activeTab === 'history' }" type="button" @click="activeTab = 'history'">
        <i class="ri-calendar-check-line" />
        {{ phrase('Campaign history') }}
      </button>
    </div>

    <div v-if="activeTab === 'compose'" class="row g-4 align-items-start">
      <div class="col-12 col-xl-7">
        <div class="card custom-card">
          <div class="card-header">
            <div>
              <div class="card-title">{{ phrase('Campaign details') }}</div>
              <div class="text-muted fs-12">{{ phrase('Choose the audience, message, media, and delivery time.') }}</div>
            </div>
          </div>
          <div class="card-body np-pr-editor">
            <section class="np-pr-section">
              <div class="np-pr-section-heading">
                <span class="np-pr-step">1</span>
                <div>
                  <h3>{{ phrase('Audience') }}</h3>
                  <p>{{ phrase('Send to everyone or choose one customer.') }}</p>
                </div>
              </div>

              <label class="form-label" for="campaign-name">{{ phrase('Campaign name') }}</label>
              <input id="campaign-name" v-model="form.name" class="form-control mb-3" :class="invalidClass('name')" maxlength="160" :placeholder="phrase('Used internally to find this campaign later')">
              <div v-if="fieldError('name')" class="text-danger fs-12 mt-n2 mb-3">{{ fieldError('name') }}</div>

              <div class="np-pr-segmented" role="group" :aria-label="phrase('Audience')">
                <button type="button" :class="{ active: form.audience_type === 'all_customers' }" @click="setAudience('all_customers')">
                  <i class="ri-group-line" />
                  <span>
                    <strong>{{ phrase('All customers') }}</strong>
                    <small>{{ activeCustomerCount ? `${formatNumber(activeCustomerCount)} ${phrase('active customers')}` : phrase('Every active customer') }}</small>
                  </span>
                </button>
                <button type="button" :class="{ active: form.audience_type === 'customer' }" @click="setAudience('customer')">
                  <i class="ri-user-line" />
                  <span>
                    <strong>{{ phrase('One customer') }}</strong>
                    <small>{{ phrase('Search and select a recipient') }}</small>
                  </span>
                </button>
              </div>
              <div v-if="fieldError('audience_type')" class="text-danger fs-12 mt-2">{{ fieldError('audience_type') }}</div>

              <div v-if="form.audience_type === 'customer'" class="mt-3">
                <label class="form-label" for="campaign-customer-search">{{ phrase('Customer') }}</label>
                <div class="input-group">
                  <span class="input-group-text"><i class="ri-search-line" /></span>
                  <input
                    id="campaign-customer-search"
                    v-model="customerSearch"
                    class="form-control"
                    :placeholder="phrase('Search name, phone, email, or customer number')"
                    autocomplete="off"
                    @focus="customerResultsOpen = true"
                    @keyup.enter="searchCustomers"
                  >
                  <button class="btn btn-light" type="button" :disabled="loadingCustomers" :title="phrase('Search')" @click="searchCustomers">
                    <span v-if="loadingCustomers" class="spinner-border spinner-border-sm" />
                    <i v-else class="ri-search-line" />
                  </button>
                </div>
                <div v-if="customerResultsOpen && customers.length" class="list-group np-pr-customer-results mt-2">
                  <button v-for="customer in customers" :key="customer.id" class="list-group-item list-group-item-action" type="button" @click="selectCustomer(customer)">
                    <span class="np-pr-avatar"><i class="ri-user-3-line" /></span>
                    <span class="min-w-0 flex-grow-1 text-start">
                      <strong class="d-block text-truncate">{{ customer.name || customer.phone || customer.customer_no }}</strong>
                      <small class="d-block text-muted text-truncate">{{ customerSummary(customer) }}</small>
                    </span>
                    <i class="ri-arrow-right-s-line text-muted" />
                  </button>
                </div>
                <div v-if="selectedCustomer" class="np-pr-selected-customer mt-3">
                  <span class="np-pr-avatar selected"><i class="ri-user-check-line" /></span>
                  <span class="min-w-0 flex-grow-1">
                    <strong class="d-block text-truncate">{{ selectedCustomer.name || selectedCustomer.phone }}</strong>
                    <small class="d-block text-muted text-truncate">{{ customerSummary(selectedCustomer) }}</small>
                  </span>
                  <button class="btn btn-sm btn-icon btn-light" type="button" :title="phrase('Clear customer')" @click="clearCustomer">
                    <i class="ri-close-line" />
                  </button>
                </div>
                <div v-if="fieldError('customer_id')" class="text-danger fs-12 mt-1">{{ fieldError('customer_id') }}</div>
              </div>
            </section>

            <section class="np-pr-section">
              <div class="np-pr-section-heading">
                <span class="np-pr-step">2</span>
                <div>
                  <h3>{{ phrase('Message') }}</h3>
                  <p>{{ phrase('Write the content customers will see in their inbox and push notification.') }}</p>
                </div>
                <div class="btn-group btn-group-sm ms-auto" role="group" :aria-label="phrase('Message language')">
                  <button v-for="locale in localeOptions" :key="locale.value" class="btn" :class="contentLocale === locale.value ? 'btn-primary' : 'btn-outline-primary'" type="button" @click="contentLocale = locale.value">
                    {{ locale.label }}
                  </button>
                </div>
              </div>

              <div class="mb-3">
                <label class="form-label" :for="`campaign-title-${contentLocale}`">{{ phrase('Title') }} ({{ localeLabel(contentLocale) }})</label>
                <input :id="`campaign-title-${contentLocale}`" v-model="form.title[contentLocale]" class="form-control" :class="invalidClass('title')" maxlength="160" :placeholder="phrase('A short headline customers can scan quickly')">
                <div class="d-flex justify-content-between gap-2 mt-1">
                  <span class="text-danger fs-12">{{ fieldError('title') }}</span>
                  <span class="text-muted fs-11">{{ form.title[contentLocale].length }}/160</span>
                </div>
              </div>
              <div>
                <label class="form-label" :for="`campaign-body-${contentLocale}`">{{ phrase('Message') }} ({{ localeLabel(contentLocale) }})</label>
                <textarea :id="`campaign-body-${contentLocale}`" v-model="form.body[contentLocale]" class="form-control" :class="invalidClass('body')" rows="5" maxlength="1000" :placeholder="phrase('Tell customers what is new and what they should do next')" />
                <div class="d-flex justify-content-between gap-2 mt-1">
                  <span class="text-danger fs-12">{{ fieldError('body') }}</span>
                  <span class="text-muted fs-11">{{ form.body[contentLocale].length }}/1000</span>
                </div>
              </div>
            </section>

            <section class="np-pr-section">
              <div class="np-pr-section-heading">
                <span class="np-pr-step">3</span>
                <div>
                  <h3>{{ phrase('Image and destination') }}</h3>
                  <p>{{ phrase('Add an optional image and choose where customers go when they tap.') }}</p>
                </div>
              </div>

              <div class="np-pr-image-picker" :class="{ 'has-image': imagePreviewUrl, 'is-invalid': fieldError('file') }">
                <input ref="imageInput" class="d-none" type="file" accept="image/jpeg,image/png,image/webp" @change="handleImageChange">
                <img v-if="imagePreviewUrl" :src="imagePreviewUrl" alt="">
                <div v-else class="np-pr-image-empty">
                  <i class="ri-image-add-line" />
                  <strong>{{ phrase('Add campaign image') }}</strong>
                  <small>{{ phrase('JPG, PNG or WebP up to 8 MB') }}</small>
                </div>
                <div class="np-pr-image-actions">
                  <button class="btn btn-sm btn-light" type="button" @click="imageInput?.click()">
                    <i class="ri-upload-2-line me-1" />{{ imagePreviewUrl ? phrase('Replace') : phrase('Choose image') }}
                  </button>
                  <button v-if="imagePreviewUrl" class="btn btn-sm btn-light btn-icon" type="button" :title="phrase('Remove image')" @click="clearImage">
                    <i class="ri-delete-bin-line" />
                  </button>
                </div>
              </div>
              <div v-if="fieldError('file')" class="text-danger fs-12 mt-1">{{ fieldError('file') }}</div>

              <div class="row g-3 mt-1">
                <div :class="selectedAction?.entity_required ? 'col-md-6' : 'col-12'">
                  <label class="form-label" for="campaign-destination">{{ phrase('Tap destination') }}</label>
                  <select id="campaign-destination" v-model="form.action_key" class="form-select" :class="invalidClass('action_key')">
                    <option v-for="option in availableActionOptions" :key="option.key" :value="option.key">{{ phrase(option.label) }}</option>
                  </select>
                  <div class="invalid-feedback">{{ fieldError('action_key') }}</div>
                </div>
                <div v-if="selectedAction?.entity_required" class="col-md-6">
                  <label class="form-label" for="campaign-entity-id">{{ phrase('Record ID') }}</label>
                  <input id="campaign-entity-id" v-model="form.action_entity_id" class="form-control" :class="invalidClass('action_entity_id')" maxlength="100">
                  <div class="invalid-feedback">{{ fieldError('action_entity_id') }}</div>
                </div>
              </div>
            </section>

            <section class="np-pr-section mb-0">
              <div class="np-pr-section-heading">
                <span class="np-pr-step">4</span>
                <div>
                  <h3>{{ phrase('Delivery') }}</h3>
                  <p>{{ phrase('Send now or schedule the campaign for later.') }}</p>
                </div>
              </div>
              <div class="np-pr-segmented compact" role="group" :aria-label="phrase('Delivery')">
                <button type="button" :class="{ active: form.delivery_mode === 'now' }" @click="form.delivery_mode = 'now'">
                  <i class="ri-send-plane-2-line" />
                  <span><strong>{{ phrase('Send now') }}</strong><small>{{ phrase('Start delivery after confirmation') }}</small></span>
                </button>
                <button type="button" :class="{ active: form.delivery_mode === 'scheduled' }" @click="form.delivery_mode = 'scheduled'">
                  <i class="ri-calendar-schedule-line" />
                  <span><strong>{{ phrase('Schedule') }}</strong><small>{{ phrase('Choose a future date and time') }}</small></span>
                </button>
              </div>
              <div v-if="form.delivery_mode === 'scheduled'" class="mt-3">
                <label class="form-label" for="campaign-scheduled-at">{{ phrase('Send date and time') }}</label>
                <input id="campaign-scheduled-at" v-model="form.scheduled_at" type="datetime-local" class="form-control" :min="minimumSchedule" :class="invalidClass('scheduled_at')">
                <div class="invalid-feedback">{{ fieldError('scheduled_at') }}</div>
                <div class="form-text">{{ phrase('Time uses your current browser time zone.') }}</div>
              </div>
            </section>
          </div>
        </div>
      </div>

      <div class="col-12 col-xl-5">
        <div class="card custom-card np-pr-preview-card">
          <div class="card-header">
            <div>
              <div class="card-title">{{ phrase('Customer preview') }}</div>
              <div class="text-muted fs-12">{{ phrase('Approximate inbox appearance on the customer app.') }}</div>
            </div>
            <div class="d-flex align-items-center gap-2">
              <div class="btn-group btn-group-sm" role="group" :aria-label="phrase('Preview type')">
                <button class="btn" :class="previewMode === 'inbox' ? 'btn-primary' : 'btn-outline-primary'" type="button" @click="previewMode = 'inbox'">
                  {{ phrase('Inbox') }}
                </button>
                <button class="btn" :class="previewMode === 'push' ? 'btn-primary' : 'btn-outline-primary'" type="button" @click="previewMode = 'push'">
                  {{ phrase('Push notification') }}
                </button>
              </div>
              <span class="badge bg-primary-transparent">{{ localeLabel(contentLocale) }}</span>
            </div>
          </div>
          <div class="card-body">
            <div v-if="previewMode === 'inbox'" class="np-pr-phone-preview">
              <div class="np-pr-phone-bar">
                <i class="ri-arrow-left-s-line" />
                <strong>{{ phrase('Notifications') }}</strong>
                <span />
              </div>
              <div class="np-pr-notification-preview">
                <span class="np-pr-preview-icon"><i class="ri-megaphone-line" /></span>
                <div class="min-w-0 flex-grow-1">
                  <div class="d-flex align-items-start gap-2">
                    <strong class="flex-grow-1">{{ localizedDraft(form.title) || phrase('Campaign title') }}</strong>
                    <span class="np-pr-unread-dot" />
                  </div>
                  <p>{{ localizedDraft(form.body) || phrase('Your campaign message will appear here.') }}</p>
                  <div v-if="imagePreviewUrl" class="np-pr-preview-media"><img :src="imagePreviewUrl" alt=""></div>
                  <small>{{ phrase('Just now') }}</small>
                </div>
                <i v-if="form.action_key !== 'none'" class="ri-arrow-right-s-line text-primary" />
              </div>
            </div>
            <div v-else class="np-pr-push-stage">
              <div class="np-pr-push-preview">
                <div class="np-pr-push-meta">
                  <span class="np-pr-push-app"><i class="ri-megaphone-fill" /></span>
                  <strong>{{ phrase('Customer app') }}</strong>
                  <span>{{ phrase('Now') }}</span>
                </div>
                <div class="np-pr-push-copy">
                  <strong>{{ localizedDraft(form.title) || phrase('Campaign title') }}</strong>
                  <p>{{ localizedDraft(form.body) || phrase('Your campaign message will appear here.') }}</p>
                </div>
                <div v-if="imagePreviewUrl" class="np-pr-push-media"><img :src="imagePreviewUrl" alt=""></div>
              </div>
              <small>{{ phrase('Native push appearance may vary slightly by device settings.') }}</small>
            </div>

            <dl class="np-pr-summary mt-4">
              <div><dt>{{ phrase('Audience') }}</dt><dd>{{ audienceSummary }}</dd></div>
              <div><dt>{{ phrase('Delivery') }}</dt><dd>{{ deliverySummary }}</dd></div>
              <div><dt>{{ phrase('Destination') }}</dt><dd>{{ destinationLabel }}</dd></div>
            </dl>
          </div>
          <div class="card-footer d-flex gap-2">
            <button class="btn btn-light btn-wave" type="button" :disabled="sending" @click="resetForm">{{ phrase('Clear') }}</button>
            <button class="btn btn-primary btn-wave flex-grow-1" type="button" :disabled="!canSubmit" @click="confirmationOpen = true">
              <i :class="form.delivery_mode === 'scheduled' ? 'ri-calendar-check-line' : 'ri-send-plane-2-line'" class="me-1" />
              {{ form.delivery_mode === 'scheduled' ? phrase('Schedule campaign') : phrase('Review and send') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="card custom-card">
      <div class="card-header flex-wrap gap-3">
        <div>
          <div class="card-title">{{ phrase('Campaign history') }}</div>
          <div class="text-muted fs-12">{{ phrase('Track scheduled campaigns, recipients, reads, and push delivery.') }}</div>
        </div>
        <div class="ms-auto d-flex align-items-center gap-2">
          <select v-model="historyStatus" class="form-select form-select-sm" @change="resetHistory">
            <option value="">{{ phrase('All statuses') }}</option>
            <option value="scheduled">{{ phrase('Scheduled') }}</option>
            <option value="published">{{ phrase('Published') }}</option>
            <option value="failed">{{ phrase('Failed') }}</option>
            <option value="cancelled">{{ phrase('Cancelled') }}</option>
          </select>
          <button class="btn btn-sm btn-light btn-icon" type="button" :disabled="loadingCampaigns" :title="phrase('Refresh')" @click="resetHistory">
            <i class="ri-refresh-line" />
          </button>
        </div>
      </div>
      <div class="card-body">
        <AdminDataTable
          :columns="historyColumns"
          :rows="campaigns"
          :loading="loadingCampaigns"
          :empty-title="phrase('No campaigns yet')"
          :empty-message="phrase('Create your first public relations campaign to see it here.')"
          embedded
        >
          <template #cell-campaign="{ row }">
            <div class="np-pr-history-campaign">
              <img v-if="row.image?.thumb_url || row.image?.url" :src="row.image.thumb_url || row.image.url" alt="">
              <span v-else class="np-pr-history-icon"><i class="ri-megaphone-line" /></span>
              <div class="min-w-0">
                <strong class="d-block text-wrap">{{ row.name || localizedText(row.title) }}</strong>
                <small class="d-block text-muted text-wrap">{{ localizedText(row.title) }}</small>
              </div>
            </div>
          </template>
          <template #cell-audience="{ row }">
            <div class="fw-semibold">{{ campaignAudience(row) }}</div>
            <div class="text-muted fs-11">{{ formatNumber(row.stats?.recipient_count || 0) }} {{ phrase('recipients') }}</div>
          </template>
          <template #cell-status="{ row }">
            <AdminStatusBadge :status="row.status" :label="phrase(statusLabel(row.status))" />
            <div class="text-muted fs-11 mt-1">{{ campaignTiming(row) }}</div>
          </template>
          <template #cell-performance="{ row }">
            <div class="np-pr-stat-line"><span>{{ phrase('Read') }}</span><strong>{{ formatNumber(row.stats?.read_count || 0) }}</strong></div>
            <div class="np-pr-stat-line"><span>{{ phrase('Push sent') }}</span><strong>{{ formatNumber(row.stats?.sent_count || 0) }}</strong></div>
            <div v-if="Number(row.stats?.pending_count || 0)" class="np-pr-stat-line text-warning"><span>{{ phrase('Push pending') }}</span><strong>{{ formatNumber(row.stats.pending_count) }}</strong></div>
            <div v-if="Number(row.stats?.failed_count || 0)" class="np-pr-stat-line text-danger"><span>{{ phrase('Failed') }}</span><strong>{{ formatNumber(row.stats.failed_count) }}</strong></div>
          </template>
          <template #cell-actions="{ row }">
            <div class="d-flex justify-content-end gap-1">
              <button v-if="row.status === 'scheduled'" class="btn btn-sm btn-icon btn-primary-light" type="button" :disabled="mutatingCampaignId === row.id" :title="phrase('Send now')" @click="publishNow(row)">
                <i class="ri-send-plane-2-line" />
              </button>
              <button v-if="row.status === 'scheduled' || row.status === 'failed'" class="btn btn-sm btn-icon btn-danger-light" type="button" :disabled="mutatingCampaignId === row.id" :title="phrase('Cancel campaign')" @click="cancelCampaign(row)">
                <i class="ri-close-circle-line" />
              </button>
            </div>
          </template>
        </AdminDataTable>
      </div>
      <div class="card-footer">
        <AdminPagination :next-cursor="historyMeta.next_cursor" :has-previous="historyPage.index > 0" :loading="loadingCampaigns" :current-page="historyPage.index + 1" :page-size="20" @previous="previousHistoryPage" @next="nextHistoryPage" />
      </div>
    </div>

    <AdminModal v-model="confirmationOpen" :title="form.delivery_mode === 'scheduled' ? phrase('Confirm campaign schedule') : phrase('Confirm campaign delivery')" size="md">
      <div class="np-pr-confirmation">
        <div><span>{{ phrase('Campaign') }}</span><strong>{{ form.name || localizedDraft(form.title) }}</strong></div>
        <div><span>{{ phrase('Audience') }}</span><strong>{{ audienceSummary }}</strong></div>
        <div><span>{{ phrase('Delivery') }}</span><strong>{{ deliverySummary }}</strong></div>
        <div><span>{{ phrase('Destination') }}</span><strong>{{ destinationLabel }}</strong></div>
      </div>
      <div class="np-pr-confirm-message mt-3">
        <img v-if="imagePreviewUrl" :src="imagePreviewUrl" alt="">
        <strong>{{ localizedDraft(form.title) }}</strong>
        <p>{{ localizedDraft(form.body) }}</p>
      </div>
      <AdminAlert v-if="form.audience_type === 'all_customers'" type="warning" :message="phrase('This campaign will be queued for every active customer. Delivery cannot be undone after publishing starts.')" />
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" :disabled="sending" @click="confirmationOpen = false">{{ phrase('Back') }}</button>
        <button class="btn btn-primary btn-wave" type="button" :disabled="sending" @click="submitCampaign">
          <span v-if="sending" class="spinner-border spinner-border-sm me-2" />
          <i v-else :class="form.delivery_mode === 'scheduled' ? 'ri-calendar-check-line' : 'ri-send-plane-2-line'" class="me-1" />
          {{ form.delivery_mode === 'scheduled' ? phrase('Confirm schedule') : phrase('Confirm and send') }}
        </button>
      </template>
    </AdminModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

type AnyRecord = Record<string, any>
type LocaleKey = 'th-TH' | 'en-US'
type AudienceType = 'all_customers' | 'customer'
type ActionOption = { key: string, label: string, entity_required: boolean }

const api = useAdminApi()
const route = useRoute()
const session = useAdminSession()
const adminLocale = useAdminLocale()
const phrase = (source: unknown) => adminLocale.phrase(source)
const tenantId = computed(() => session.currentTenantId.value)
const localeOptions: Array<{ value: LocaleKey, label: string }> = [{ value: 'th-TH', label: 'TH' }, { value: 'en-US', label: 'EN' }]
const historyColumns = [
  { key: 'campaign', label: 'Campaign' },
  { key: 'audience', label: 'Audience' },
  { key: 'status', label: 'Status' },
  { key: 'performance', label: 'Performance' },
  { key: 'actions', label: '', align: 'end' },
]

const activeTab = ref<'compose' | 'history'>('compose')
const loadingCustomers = ref(false)
const loadingCampaigns = ref(false)
const sending = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const customerSearch = ref('')
const customers = ref<AnyRecord[]>([])
const selectedCustomer = ref<AnyRecord | null>(null)
const customerResultsOpen = ref(false)
const activeCustomerCount = ref(0)
const contentLocale = ref<LocaleKey>('th-TH')
const previewMode = ref<'inbox' | 'push'>('inbox')
const actionOptions = ref<ActionOption[]>([])
const campaigns = ref<AnyRecord[]>([])
const historyStatus = ref('')
const historyMeta = ref<AnyRecord>({})
const historyPage = ref({ index: 0, cursors: [''] })
const confirmationOpen = ref(false)
const fieldErrors = ref<Record<string, string[]>>({})
const imageInput = ref<HTMLInputElement | null>(null)
const imageFile = ref<File | null>(null)
const imagePreviewUrl = ref('')
const mutatingCampaignId = ref('')
const form = reactive(defaultForm())
let customerSearchTimer: ReturnType<typeof setTimeout> | null = null

const loading = computed(() => loadingCustomers.value || loadingCampaigns.value || sending.value)
const selectedAction = computed(() => actionOptions.value.find(option => option.key === form.action_key) || actionOptions.value[0] || null)
const availableActionOptions = computed(() => actionOptions.value.filter(option => form.audience_type === 'customer' || !option.entity_required || ['activity', 'news'].includes(option.key)))
const minimumSchedule = computed(() => localDateTime(new Date(Date.now() + 60_000)))
const canSubmit = computed(() => Boolean(
  tenantId.value
  && localizedDraft(form.title)
  && localizedDraft(form.body)
  && (form.audience_type === 'all_customers' || selectedCustomer.value?.id)
  && form.action_key
  && (!selectedAction.value?.entity_required || form.action_entity_id.trim())
  && (form.delivery_mode === 'now' || form.scheduled_at)
  && !sending.value,
))
const audienceSummary = computed(() => form.audience_type === 'all_customers'
  ? (activeCustomerCount.value ? `${phrase('All customers')} (${formatNumber(activeCustomerCount.value)})` : phrase('All customers'))
  : (selectedCustomer.value?.name || selectedCustomer.value?.phone || phrase('No customer selected')))
const deliverySummary = computed(() => form.delivery_mode === 'now' ? phrase('Send now') : formatDateTime(form.scheduled_at))
const destinationLabel = computed(() => {
  const label = phrase(selectedAction.value?.label || 'No destination')
  return form.action_entity_id.trim() ? `${label} · ${form.action_entity_id.trim()}` : label
})

watch(customerSearch, () => {
  if (customerSearchTimer) clearTimeout(customerSearchTimer)
  if (form.audience_type !== 'customer' || selectedCustomer.value) return
  customerSearchTimer = setTimeout(() => void loadCustomers({ q: customerSearch.value }), 300)
})
watch(() => form.action_key, () => {
  if (!selectedAction.value?.entity_required) form.action_entity_id = ''
  delete fieldErrors.value.action_key
  delete fieldErrors.value.action_entity_id
})
watch(() => form.audience_type, () => {
  if (!availableActionOptions.value.some(option => option.key === form.action_key)) form.action_key = 'none'
})
watch(tenantId, async () => {
  resetState()
  if (tenantId.value) await initializePage()
})
watch(activeTab, (tab) => {
  if (tab === 'history' && !campaigns.value.length) void loadCampaigns()
})

onMounted(async () => {
  if (tenantId.value) await initializePage()
})
onBeforeUnmount(() => {
  if (customerSearchTimer) clearTimeout(customerSearchTimer)
  revokeImagePreview()
})

async function initializePage() {
  const requestedCustomerId = typeof route.query.customer_id === 'string' ? route.query.customer_id.trim() : ''
  await Promise.all([loadCustomers(requestedCustomerId ? { customer_id: requestedCustomerId } : {}), loadCampaigns()])
  if (requestedCustomerId && customers.value.length) {
    setAudience('customer')
    selectCustomer(customers.value[0])
  }
}

async function loadCustomers(query: AnyRecord = {}) {
  if (!tenantId.value) return
  loadingCustomers.value = true
  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/customer-notifications/customers', {
      scope: 'tenant', tenantId: tenantId.value, query: { limit: 20, ...query },
    })
    customers.value = Array.isArray(response.data) ? response.data : []
    activeCustomerCount.value = Number(response.meta?.active_customer_count || activeCustomerCount.value || 0)
    applyActionOptions(response.meta?.action_options)
    customerResultsOpen.value = Boolean(form.audience_type === 'customer' && customerSearch.value.trim() && !selectedCustomer.value && customers.value.length)
  } catch (err: any) {
    error.value = err
    customers.value = []
  } finally {
    loadingCustomers.value = false
  }
}

async function loadCampaigns(cursor = '') {
  if (!tenantId.value) return
  loadingCampaigns.value = true
  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/customer-notifications/campaigns', {
      scope: 'tenant', tenantId: tenantId.value,
      query: { limit: 20, cursor: cursor || undefined, status: historyStatus.value || undefined },
    })
    campaigns.value = Array.isArray(response.data) ? response.data : []
    historyMeta.value = response.meta || {}
    applyActionOptions(response.meta?.action_options)
  } catch (err: any) {
    error.value = err
    campaigns.value = []
    historyMeta.value = {}
  } finally {
    loadingCampaigns.value = false
  }
}

function applyActionOptions(source: unknown) {
  if (!Array.isArray(source) || !source.length) return
  actionOptions.value = source.map(normalizeActionOption).filter(option => option.key)
  if (!actionOptions.value.some(option => option.key === form.action_key)) form.action_key = actionOptions.value[0]?.key || 'none'
}

function setAudience(value: AudienceType) {
  form.audience_type = value
  delete fieldErrors.value.audience_type
  if (value === 'all_customers') clearCustomer()
}
function searchCustomers() {
  selectedCustomer.value = null
  customerResultsOpen.value = true
  void loadCustomers({ q: customerSearch.value })
}
function selectCustomer(customer: AnyRecord) {
  selectedCustomer.value = customer
  customerSearch.value = customer.name || customer.phone || customer.customer_no || ''
  customerResultsOpen.value = false
  delete fieldErrors.value.customer_id
}
function clearCustomer() {
  selectedCustomer.value = null
  customerSearch.value = ''
  customerResultsOpen.value = false
}

function handleImageChange(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0] || null
  if (!file) return
  if (!file.type.startsWith('image/') || file.size > 8_388_608) {
    fieldErrors.value.file = [phrase('Choose a JPG, PNG, or WebP image up to 8 MB.')]
    if (imageInput.value) imageInput.value.value = ''
    return
  }
  delete fieldErrors.value.file
  revokeImagePreview()
  imageFile.value = file
  imagePreviewUrl.value = URL.createObjectURL(file)
}
function clearImage() {
  revokeImagePreview()
  imageFile.value = null
  if (imageInput.value) imageInput.value.value = ''
  delete fieldErrors.value.file
}
function revokeImagePreview() {
  if (imagePreviewUrl.value.startsWith('blob:')) URL.revokeObjectURL(imagePreviewUrl.value)
  imagePreviewUrl.value = ''
}

async function submitCampaign() {
  if (!canSubmit.value || !tenantId.value) return
  sending.value = true
  error.value = null
  successMessage.value = ''
  fieldErrors.value = {}
  try {
    const payload = {
      name: form.name.trim(),
      audience_type: form.audience_type,
      customer_id: form.audience_type === 'customer' ? selectedCustomer.value?.id : null,
      title: normalizedLocalized(form.title),
      body: normalizedLocalized(form.body),
      action_key: form.action_key,
      action_entity_id: selectedAction.value?.entity_required ? form.action_entity_id.trim() : null,
      delivery_mode: form.delivery_mode,
      scheduled_at: form.delivery_mode === 'scheduled' && form.scheduled_at ? new Date(form.scheduled_at).toISOString() : null,
    }
    const body = new FormData()
    body.append('payload', JSON.stringify(payload))
    if (imageFile.value) body.append('file', imageFile.value)
    await api.apiFetch('/admin/tenant/customer-notifications/campaigns', {
      method: 'POST', scope: 'tenant', tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(), successMessage: false, body,
    })
    confirmationOpen.value = false
    successMessage.value = form.delivery_mode === 'scheduled' ? phrase('Campaign scheduled.') : phrase('Campaign queued for delivery.')
    resetForm()
    await resetHistory()
    activeTab.value = 'history'
  } catch (err: any) {
    confirmationOpen.value = false
    error.value = err
    fieldErrors.value = normalizeFieldErrors(err)
  } finally {
    sending.value = false
  }
}

async function publishNow(campaign: AnyRecord) {
  if (!tenantId.value || !confirm(phrase('Send this campaign now?'))) return
  await mutateCampaign(campaign.id, 'publish', phrase('Campaign queued for delivery.'))
}
async function cancelCampaign(campaign: AnyRecord) {
  if (!tenantId.value || !confirm(phrase('Cancel this campaign?'))) return
  await mutateCampaign(campaign.id, 'cancel', phrase('Campaign cancelled.'))
}
async function mutateCampaign(id: string, action: 'publish' | 'cancel', message: string) {
  mutatingCampaignId.value = id
  error.value = null
  try {
    await api.apiFetch(`/admin/tenant/customer-notifications/campaigns/${encodeURIComponent(id)}/${action}`, {
      method: 'POST', scope: 'tenant', tenantId: tenantId.value, idempotencyKey: api.idempotencyKey(), body: {}, successMessage: false,
    })
    successMessage.value = message
    await resetHistory()
  } catch (err: any) {
    error.value = err
  } finally {
    mutatingCampaignId.value = ''
  }
}

async function refreshPage() {
  await Promise.all([loadCustomers(selectedCustomer.value?.id ? { customer_id: selectedCustomer.value.id } : {}), loadCampaigns(historyPage.value.cursors[historyPage.value.index] || '')])
}
function nextHistoryPage() {
  const cursor = String(historyMeta.value.next_cursor || '')
  if (!cursor) return
  historyPage.value.cursors[historyPage.value.index + 1] = cursor
  historyPage.value.index += 1
  void loadCampaigns(cursor)
}
function previousHistoryPage() {
  if (historyPage.value.index <= 0) return
  historyPage.value.index -= 1
  void loadCampaigns(historyPage.value.cursors[historyPage.value.index] || '')
}
async function resetHistory() {
  historyPage.value = { index: 0, cursors: [''] }
  await loadCampaigns()
}
function resetForm() {
  Object.assign(form, defaultForm())
  clearCustomer()
  clearImage()
  contentLocale.value = 'th-TH'
  fieldErrors.value = {}
}
function resetState() {
  campaigns.value = []
  customers.value = []
  actionOptions.value = []
  historyMeta.value = {}
  historyPage.value = { index: 0, cursors: [''] }
  activeCustomerCount.value = 0
  error.value = null
  successMessage.value = ''
  resetForm()
}

function defaultForm() {
  return {
    name: '', audience_type: 'all_customers' as AudienceType,
    title: localizedDefaults(), body: localizedDefaults(),
    action_key: 'none', action_entity_id: '',
    delivery_mode: 'now' as 'now' | 'scheduled', scheduled_at: defaultSchedule(),
  }
}
function localizedDefaults(): Record<LocaleKey, string> { return { 'th-TH': '', 'en-US': '' } }
function normalizedLocalized(value: Record<LocaleKey, string>) { return Object.fromEntries(Object.entries(value).map(([locale, text]) => [locale, String(text || '').trim()]).filter(([, text]) => text)) }
function localizedDraft(value: Record<LocaleKey, string>) {
  const preferred = String(adminLocale.locale.value).toLowerCase().startsWith('en') ? 'en-US' : 'th-TH'
  return value[preferred] || value['th-TH'] || value['en-US'] || ''
}
function localizedText(value: unknown) { return value && typeof value === 'object' ? localizedDraft(value as Record<LocaleKey, string>) : String(value || '') }
function localeLabel(locale: LocaleKey) { return locale === 'th-TH' ? phrase('Thai') : phrase('English') }
function normalizeActionOption(value: AnyRecord): ActionOption { return { key: String(value?.key || ''), label: String(value?.label || value?.key || ''), entity_required: Boolean(value?.entity_required) } }
function customerSummary(customer: AnyRecord) { return [customer.customer_no, customer.phone, customer.email].filter(Boolean).join(' · ') || '-' }
function campaignAudience(row: AnyRecord) { return row.audience_type === 'all_customers' ? phrase('All customers') : (row.customer?.name || row.customer?.phone || phrase('One customer')) }
function statusLabel(status: unknown) { return ({ scheduled: 'Scheduled', publishing: 'Publishing', published: 'Published', failed: 'Failed', cancelled: 'Cancelled' } as AnyRecord)[String(status)] || String(status || '-') }
function campaignTiming(row: AnyRecord) { return row.status === 'scheduled' ? formatDateTime(row.scheduled_at) : formatDateTime(row.published_at || row.created_at) }
function formatNumber(value: unknown) { return new Intl.NumberFormat(adminLocale.locale.value).format(Number(value || 0)) }
function formatDateTime(value: unknown) {
  if (!value) return '-'
  const date = new Date(String(value))
  if (Number.isNaN(date.getTime())) return String(value)
  return new Intl.DateTimeFormat(adminLocale.locale.value, { dateStyle: 'medium', timeStyle: 'short' }).format(date)
}
function localDateTime(date: Date) {
  const offset = date.getTimezoneOffset()
  return new Date(date.getTime() - offset * 60_000).toISOString().slice(0, 16)
}
function defaultSchedule() { return localDateTime(new Date(Date.now() + 15 * 60_000)) }
function fieldError(key: string) { return fieldErrors.value[key]?.[0] || '' }
function invalidClass(key: string) { return { 'is-invalid': Boolean(fieldError(key)) } }
function normalizeFieldErrors(err: AnyRecord) {
  const source = err?.details?.fields || err?.details || {}
  if (!source || typeof source !== 'object') return {}
  return Object.fromEntries(Object.entries(source).map(([key, value]) => [key, Array.isArray(value) ? value.map(String) : [String(value)]]))
}
function alertType(err: AnyRecord) { return [403, 409, 422].includes(Number(err?.status)) ? 'warning' : 'danger' }
</script>

<style scoped>
.np-pr-tabs { display: inline-flex; gap: .25rem; padding: .25rem; border: 1px solid var(--default-border); background: var(--custom-white); border-radius: 6px; }
.np-pr-tab { display: inline-flex; align-items: center; gap: .45rem; min-height: 38px; padding: .5rem .9rem; border: 0; border-radius: 4px; background: transparent; color: var(--default-text-color); font-weight: 600; }
.np-pr-tab.active { background: rgb(var(--primary-rgb)); color: #fff; }
.np-pr-editor { padding: 0; }
.np-pr-section { padding: 1.5rem; border-bottom: 1px solid var(--default-border); }
.np-pr-section-heading { display: flex; align-items: flex-start; gap: .75rem; margin-bottom: 1.1rem; }
.np-pr-section-heading h3 { margin: 0; font-size: 1rem; font-weight: 700; letter-spacing: 0; }
.np-pr-section-heading p { margin: .15rem 0 0; color: var(--text-muted); font-size: .75rem; }
.np-pr-step { display: grid; place-items: center; flex: 0 0 28px; width: 28px; height: 28px; border-radius: 50%; background: rgba(var(--primary-rgb), .12); color: rgb(var(--primary-rgb)); font-weight: 700; }
.np-pr-segmented { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .65rem; }
.np-pr-segmented button { display: flex; align-items: center; gap: .75rem; min-height: 74px; padding: .8rem; border: 1px solid var(--default-border); border-radius: 6px; background: var(--custom-white); color: var(--default-text-color); text-align: left; }
.np-pr-segmented button > i { font-size: 1.35rem; color: var(--text-muted); }
.np-pr-segmented button span { display: flex; min-width: 0; flex-direction: column; }
.np-pr-segmented button strong { font-size: .84rem; }
.np-pr-segmented button small { color: var(--text-muted); font-size: .7rem; }
.np-pr-segmented button.active { border-color: rgb(var(--primary-rgb)); background: rgba(var(--primary-rgb), .06); box-shadow: 0 0 0 1px rgba(var(--primary-rgb), .16); }
.np-pr-segmented button.active > i, .np-pr-segmented button.active strong { color: rgb(var(--primary-rgb)); }
.np-pr-segmented.compact button { min-height: 66px; }
.np-pr-customer-results { max-height: 260px; overflow-y: auto; }
.np-pr-customer-results button { display: flex; align-items: center; gap: .75rem; }
.np-pr-avatar { display: grid; place-items: center; flex: 0 0 38px; width: 38px; height: 38px; border-radius: 50%; background: var(--light-rgb, #f1f5f9); color: var(--text-muted); }
.np-pr-avatar.selected { background: rgba(var(--success-rgb), .12); color: rgb(var(--success-rgb)); }
.np-pr-selected-customer { display: flex; align-items: center; gap: .75rem; padding: .75rem; border: 1px solid rgba(var(--success-rgb), .3); border-radius: 6px; background: rgba(var(--success-rgb), .05); }
.np-pr-image-picker { position: relative; min-height: 160px; overflow: hidden; border: 1px dashed var(--default-border); border-radius: 6px; background: var(--default-background); }
.np-pr-image-picker.is-invalid { border-color: var(--danger-color); }
.np-pr-image-picker > img { display: block; width: 100%; max-height: 300px; object-fit: cover; }
.np-pr-image-empty { display: flex; min-height: 160px; align-items: center; justify-content: center; flex-direction: column; gap: .25rem; color: var(--text-muted); }
.np-pr-image-empty i { font-size: 2rem; }
.np-pr-image-empty strong { color: var(--default-text-color); }
.np-pr-image-empty small { font-size: .72rem; }
.np-pr-image-actions { position: absolute; right: .75rem; bottom: .75rem; display: flex; gap: .35rem; }
.np-pr-preview-card { position: sticky; top: 5.25rem; }
.np-pr-phone-preview { overflow: hidden; border: 1px solid #dbe2ea; border-radius: 8px; background: #fff; box-shadow: 0 12px 32px rgba(15, 23, 42, .08); }
.np-pr-phone-bar { display: grid; grid-template-columns: 24px 1fr 24px; align-items: center; min-height: 52px; padding: 0 1rem; border-bottom: 1px solid #e7edf3; color: #172033; text-align: center; }
.np-pr-phone-bar i { font-size: 1.25rem; }
.np-pr-notification-preview { display: flex; align-items: flex-start; gap: .75rem; padding: 1rem; background: rgba(var(--primary-rgb), .045); }
.np-pr-preview-icon { display: grid; place-items: center; flex: 0 0 42px; width: 42px; height: 42px; border-radius: 50%; background: rgba(var(--primary-rgb), .12); color: rgb(var(--primary-rgb)); font-size: 1.15rem; }
.np-pr-notification-preview strong { color: #172033; font-size: .9rem; line-height: 1.35; }
.np-pr-notification-preview p { margin: .25rem 0 0; color: #64748b; font-size: .78rem; line-height: 1.45; white-space: pre-wrap; }
.np-pr-notification-preview small { display: block; margin-top: .45rem; color: #94a3b8; font-size: .68rem; }
.np-pr-unread-dot { flex: 0 0 7px; width: 7px; height: 7px; margin-top: .35rem; border-radius: 50%; background: rgb(var(--primary-rgb)); }
.np-pr-preview-media { aspect-ratio: 16 / 7; margin-top: .65rem; overflow: hidden; border-radius: 6px; background: #f1f5f9; }
.np-pr-preview-media img { width: 100%; height: 100%; object-fit: cover; }
.np-pr-push-stage { padding: 1.25rem; border-radius: 8px; background: linear-gradient(145deg, #dcecff, #eef5fb 58%, #d8e4ee); }
.np-pr-push-preview { overflow: hidden; padding: .85rem; border: 1px solid rgba(255, 255, 255, .74); border-radius: 8px; background: rgba(255, 255, 255, .9); box-shadow: 0 10px 24px rgba(15, 23, 42, .12); backdrop-filter: blur(14px); }
.np-pr-push-meta { display: grid; grid-template-columns: 24px 1fr auto; align-items: center; gap: .45rem; color: #64748b; font-size: .68rem; }
.np-pr-push-meta strong { overflow: hidden; color: #475569; font-size: .72rem; font-weight: 600; text-overflow: ellipsis; white-space: nowrap; }
.np-pr-push-app { display: grid; place-items: center; width: 24px; height: 24px; border-radius: 5px; background: rgb(var(--primary-rgb)); color: #fff; }
.np-pr-push-copy { padding-top: .65rem; }
.np-pr-push-copy strong { display: block; color: #172033; font-size: .86rem; line-height: 1.35; }
.np-pr-push-copy p { display: -webkit-box; overflow: hidden; margin: .2rem 0 0; color: #475569; font-size: .76rem; line-height: 1.42; white-space: pre-wrap; -webkit-box-orient: vertical; -webkit-line-clamp: 3; }
.np-pr-push-media { aspect-ratio: 16 / 8; margin-top: .7rem; overflow: hidden; border-radius: 6px; background: #e2e8f0; }
.np-pr-push-media img { width: 100%; height: 100%; object-fit: cover; }
.np-pr-push-stage > small { display: block; margin-top: .75rem; color: #64748b; font-size: .68rem; text-align: center; }
.np-pr-summary { margin: 0; }
.np-pr-summary > div { display: flex; justify-content: space-between; gap: 1rem; padding: .65rem 0; border-bottom: 1px solid var(--default-border); }
.np-pr-summary > div:last-child { border-bottom: 0; }
.np-pr-summary dt { color: var(--text-muted); font-size: .75rem; font-weight: 500; }
.np-pr-summary dd { margin: 0; font-size: .78rem; font-weight: 600; text-align: right; }
.np-pr-history-campaign { display: flex; align-items: center; gap: .75rem; min-width: 220px; }
.np-pr-history-campaign img, .np-pr-history-icon { flex: 0 0 54px; width: 54px; height: 42px; border-radius: 5px; object-fit: cover; }
.np-pr-history-icon { display: grid; place-items: center; background: rgba(var(--primary-rgb), .1); color: rgb(var(--primary-rgb)); font-size: 1.1rem; }
.np-pr-stat-line { display: flex; justify-content: space-between; gap: 1rem; min-width: 120px; font-size: .72rem; }
.np-pr-confirmation > div { display: flex; justify-content: space-between; gap: 1rem; padding: .65rem 0; border-bottom: 1px solid var(--default-border); }
.np-pr-confirmation span { color: var(--text-muted); }
.np-pr-confirmation strong { text-align: right; }
.np-pr-confirm-message { overflow: hidden; border: 1px solid var(--default-border); border-radius: 6px; }
.np-pr-confirm-message img { display: block; width: 100%; max-height: 220px; object-fit: cover; }
.np-pr-confirm-message strong, .np-pr-confirm-message p { display: block; margin: 0; padding: .75rem .9rem 0; }
.np-pr-confirm-message p { padding-top: .25rem; padding-bottom: .9rem; color: var(--text-muted); white-space: pre-wrap; }
@media (max-width: 767.98px) {
  .np-pr-tabs { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); width: 100%; }
  .np-pr-tab { justify-content: center; }
  .np-pr-segmented { grid-template-columns: 1fr; }
  .np-pr-section { padding: 1rem; }
  .np-pr-section-heading { flex-wrap: wrap; }
  .np-pr-section-heading .btn-group { margin-left: 2.5rem !important; }
  .np-pr-preview-card { position: static; }
}
</style>

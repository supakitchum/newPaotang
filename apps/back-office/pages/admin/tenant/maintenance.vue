<template>
  <div>
    <AdminPageHeader title="Tenant Maintenance" :breadcrumbs="['Admin', 'Tenant', 'Maintenance']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" @click="loadAll">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before editing maintenance." />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" />
    <AdminAlert v-if="retryAfter" type="warning" :message="`Maintenance is active. Retry-After: ${retryAfter} seconds.`" />

    <AdminLoader v-if="loading" />
    <div v-else class="row g-4">
      <div class="col-xl-7">
        <AdminFormSection title="Maintenance setting">
          <form class="row g-3" @submit.prevent="save">
            <div class="col-md-6">
              <label class="form-label">Status</label>
              <select v-model="form.status" class="form-select" :class="invalidClass('status')">
                <option v-for="status in statuses" :key="status" :value="status">{{ titleize(status) }}</option>
              </select>
              <div class="invalid-feedback">{{ fieldError('status') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Mode</label>
              <select v-model="form.mode" class="form-select" :class="invalidClass('mode')">
                <option v-for="mode in availableModes" :key="mode" :value="mode">{{ titleize(mode) }}</option>
              </select>
              <div class="invalid-feedback">{{ fieldError('mode') || activeModeError }}</div>
            </div>
            <div class="col-12">
              <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-2">
                <label class="form-label mb-0">Message ({{ localeLabel(contentLocale) }})</label>
                <div class="btn-group btn-group-sm" role="group" aria-label="Maintenance message language tabs">
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
              <textarea v-model="form.message_i18n[contentLocale]" class="form-control" rows="3" :class="invalidClass('message')" />
              <div class="form-text">Customer maintenance responses use the selected language and fall back to Thai/default if blank.</div>
              <div class="invalid-feedback">{{ fieldError('message') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Change reason</label>
              <input v-model="form.reason" class="form-control" :class="invalidClass('reason')" placeholder="Required for audit trail" />
              <div class="invalid-feedback">{{ fieldError('reason') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Ticket ID</label>
              <input v-model="form.ticket_id" class="form-control" :class="invalidClass('ticket_id')" placeholder="Optional support ticket" />
              <div class="invalid-feedback">{{ fieldError('ticket_id') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Scheduled start</label>
              <input v-model="form.scheduled_start_at" type="datetime-local" class="form-control" :class="invalidClass('scheduled_start_at')" />
              <div class="invalid-feedback">{{ fieldError('scheduled_start_at') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Expected end</label>
              <input v-model="form.expected_end_at" type="datetime-local" class="form-control" :class="invalidClass('expected_end_at')" />
              <div class="invalid-feedback">{{ fieldError('expected_end_at') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Retry after seconds</label>
              <input v-model.number="form.retry_after_seconds" type="number" min="0" class="form-control" :class="invalidClass('retry_after_seconds')" />
              <div class="invalid-feedback">{{ fieldError('retry_after_seconds') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Allowed API routes</label>
              <textarea v-model="form.allowed_routes" class="form-control" rows="4" :class="invalidClass('allowed_routes')" placeholder="/api/v1/public/site-config" />
              <div class="invalid-feedback">{{ fieldError('allowed_routes') }}</div>
              <div class="form-text">One route or wildcard pattern per line. These routes stay open while maintenance is active.</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Blocked API route patterns</label>
              <textarea v-model="form.blocked_route_patterns" class="form-control" rows="4" :class="invalidClass('blocked_route_patterns')" placeholder="/api/v1/customer/checkout&#10;/api/v1/customer/reservations*" />
              <div class="invalid-feedback">{{ fieldError('blocked_route_patterns') }}</div>
              <div class="form-text">One route or wildcard pattern per line. These routes are blocked even if the mode is narrower.</div>
            </div>
            <div class="col-12 d-flex justify-content-end">
              <button class="btn btn-primary btn-wave" type="submit" :disabled="saveDisabled">
                <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
                Save maintenance
              </button>
            </div>
          </form>
        </AdminFormSection>

        <AdminFormSection title="Create bypass">
          <form class="row g-3" @submit.prevent="createBypass">
            <div class="col-md-4">
              <label class="form-label">Actor type</label>
              <select v-model="bypass.actor_type" class="form-select" :class="bypassInvalidClass('actor_type')">
                <option value="customer">Customer</option>
                <option value="tenant_admin">Tenant admin</option>
                <option value="support_session">Support session</option>
              </select>
              <div class="invalid-feedback">{{ bypassFieldError('actor_type') }}</div>
            </div>
            <div class="col-md-8">
              <label class="form-label">Actor ID</label>
              <input v-model="bypass.actor_id" class="form-control" :class="bypassInvalidClass('actor_id')" />
              <div class="invalid-feedback">{{ bypassFieldError('actor_id') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Reason</label>
              <input v-model="bypass.reason" class="form-control" :class="bypassInvalidClass('reason')" />
              <div class="invalid-feedback">{{ bypassFieldError('reason') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Ticket ID</label>
              <input v-model="bypass.ticket_id" class="form-control" :class="bypassInvalidClass('ticket_id')" />
              <div class="invalid-feedback">{{ bypassFieldError('ticket_id') }}</div>
              <div class="form-text" :class="bypassTicketMissing ? 'text-danger' : ''">Ticket ID is required before creating a bypass.</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Expires at</label>
              <input v-model="bypass.expires_at" type="datetime-local" class="form-control" />
            </div>
            <div class="col-12">
              <button class="btn btn-outline-primary btn-wave" type="submit" :disabled="bypassSubmitDisabled">
                <i class="ri-shield-check-line me-1" />
                Create bypass
              </button>
            </div>
          </form>
        </AdminFormSection>
      </div>

      <div class="col-xl-5">
        <div class="card custom-card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <div class="card-title">Current state</div>
            <AdminStatusBadge :status="setting?.status" />
          </div>
          <div class="card-body">
            <AdminEmptyState v-if="!setting" title="No setting" message="Backend did not return a maintenance setting." />
            <dl v-else class="row mb-0">
              <dt class="col-5">Active</dt>
              <dd class="col-7"><AdminStatusBadge :status="setting.active" :label="setting.active ? 'Active' : 'Inactive'" /></dd>
              <dt class="col-5">Mode</dt>
              <dd class="col-7">{{ titleize(setting.mode || '-') }}</dd>
              <dt class="col-5">Message</dt>
              <dd class="col-7">{{ setting.message || '-' }}</dd>
              <dt class="col-5">Reason</dt>
              <dd class="col-7">{{ setting.reason || '-' }}</dd>
              <dt class="col-5">Ticket</dt>
              <dd class="col-7">{{ setting.ticket_id || '-' }}</dd>
              <dt class="col-5">Scheduled start</dt>
              <dd class="col-7">{{ formatDateTime(setting.scheduled_start_at) }}</dd>
              <dt class="col-5">Started</dt>
              <dd class="col-7">{{ formatDateTime(setting.started_at) }}</dd>
              <dt class="col-5">Expected end</dt>
              <dd class="col-7">{{ formatDateTime(setting.expected_end_at) }}</dd>
              <dt class="col-5">Ended</dt>
              <dd class="col-7">{{ formatDateTime(setting.ended_at) }}</dd>
              <dt class="col-5">Allowed routes</dt>
              <dd class="col-7">
                <div v-if="stringList(setting.allowed_routes).length" class="d-flex flex-column gap-1">
                  <code v-for="route in stringList(setting.allowed_routes)" :key="route" class="small">{{ route }}</code>
                </div>
                <span v-else>-</span>
              </dd>
              <dt class="col-5">Blocked patterns</dt>
              <dd class="col-7">
                <div v-if="stringList(setting.blocked_route_patterns).length" class="d-flex flex-column gap-1">
                  <code v-for="route in stringList(setting.blocked_route_patterns)" :key="route" class="small">{{ route }}</code>
                </div>
                <span v-else>-</span>
              </dd>
              <dt class="col-5">Updated</dt>
              <dd class="col-7">{{ formatDateTime(setting.updated_at) }}</dd>
            </dl>
          </div>
        </div>

        <div class="card custom-card">
          <div class="card-header">
            <div class="card-title">Events timeline</div>
          </div>
          <div class="card-body">
            <AdminEmptyState v-if="!events.length" title="No events" message="Maintenance audit events will appear after changes." icon="ri-history-line" />
            <ul v-else class="list-unstyled mb-0">
              <li v-for="item in events" :key="item.id || item.created_at" class="d-flex gap-3 pb-3">
                <span class="avatar avatar-sm bg-primary-transparent text-primary rounded-circle flex-shrink-0">
                  <i class="ri-time-line" />
                </span>
                <div class="flex-fill">
                  <div class="d-flex flex-wrap gap-2 align-items-center">
                    <span class="fw-semibold">{{ titleize(item.event_type || 'maintenance event') }}</span>
                    <AdminStatusBadge :status="item.status" />
                    <span class="badge bg-light text-default">{{ titleize(item.mode || '-') }}</span>
                  </div>
                  <div v-if="item.reason" class="text-muted small mt-1">{{ item.reason }}</div>
                  <div v-if="item.ticket_id" class="text-muted fs-12">Ticket: {{ item.ticket_id }}</div>
                  <div class="text-muted fs-12">{{ formatDateTime(item.created_at || item.updated_at) }}</div>
                </div>
              </li>
            </ul>
            <AdminPagination
              class="mt-3"
              :next-cursor="eventMeta.next_cursor"
              :has-previous="eventPageState.index > 0"
              :loading="eventsLoading"
              @previous="loadPreviousEventsPage"
              @next="loadNextEventsPage"
            />
          </div>
        </div>

        <div class="card custom-card">
          <div class="card-header">
            <div class="card-title">Active bypasses</div>
          </div>
          <div class="card-body">
            <AdminEmptyState v-if="!bypasses.length" title="No active bypasses" message="Active tenant maintenance bypasses will appear here." />
            <div v-else class="table-responsive">
              <table class="table table-sm text-nowrap align-middle mb-0">
                <thead>
                  <tr>
                    <th>Actor</th>
                    <th>Status</th>
                    <th>Expires</th>
                    <th class="text-end">Action</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="item in bypasses" :key="item.id">
                    <td>
                      <div class="fw-semibold">{{ titleize(item.actor_type || '-') }}</div>
                      <div class="text-muted fs-12">{{ item.actor_id }}</div>
                    </td>
                    <td><AdminStatusBadge :status="item.effective_status || item.status" /></td>
                    <td>{{ formatDateTime(item.expires_at) }}</td>
                    <td class="text-end">
                      <button
                        class="btn btn-sm btn-danger btn-wave"
                        type="button"
                        :disabled="saving || !item.is_currently_active"
                        @click="prepareRevokeBypass(item)"
                      >
                        Revoke
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <AdminPagination
              class="mt-3"
              :next-cursor="bypassMeta.next_cursor"
              :has-previous="bypassPageState.index > 0"
              :loading="bypassLoading"
              @previous="loadPreviousBypassesPage"
              @next="loadNextBypassesPage"
            />
          </div>
        </div>
      </div>
    </div>

    <AdminConfirmAction
      v-model="revokeConfirm.open"
      title="Revoke bypass"
      message="Confirm revoke for the selected maintenance bypass."
      :requires-reason="true"
      :record-context="revokeConfirm.row"
      :context-fields="['id', 'actor_type', 'actor_id', 'effective_status', 'expires_at', 'ticket_id']"
      :loading="saving"
      :error="error"
      @confirm="confirmRevokeBypass"
    />
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, titleize } from '~/utils/format'

definePageMeta({ layout: 'admin' })

const api = useAdminApi()
const session = useAdminSession()
const tenantId = computed(() => session.currentTenantId.value)
const loading = ref(false)
const saving = ref(false)
const eventsLoading = ref(false)
const bypassLoading = ref(false)
const error = ref<any>(null)
const retryAfter = ref<string | null>(null)
const validation = ref<Record<string, string[]>>({})
const bypassValidation = ref<Record<string, string[]>>({})
const setting = ref<any>(null)
const events = ref<any[]>([])
const bypasses = ref<any[]>([])
const eventMeta = reactive({ next_cursor: null as string | null, has_more: false })
const bypassMeta = reactive({ next_cursor: null as string | null, has_more: false })
const eventPageState = reactive({ cursors: [null] as Array<string | null>, index: 0 })
const bypassPageState = reactive({ cursors: [null] as Array<string | null>, index: 0 })
const lastBypass = ref<any>(null)

const statuses = ['inactive', 'scheduled', 'active', 'ended', 'cancelled']
const modes = ['full_site', 'customer_web_only', 'admin_only', 'checkout_payment_only', 'read_only', 'scheduled']
const localeOptions = [
  { value: 'th-TH', label: 'TH' },
  { value: 'en-US', label: 'EN' },
] as const
const contentLocale = ref<'th-TH' | 'en-US'>('th-TH')
const form = reactive<any>({
  status: 'inactive',
  mode: 'scheduled',
  message: '',
  message_i18n: { 'th-TH': '', 'en-US': '' },
  reason: '',
  ticket_id: '',
  scheduled_start_at: '',
  expected_end_at: '',
  retry_after_seconds: null,
  allowed_routes: '',
  blocked_route_patterns: '',
})
const bypass = reactive<any>({
  actor_type: 'customer',
  actor_id: '',
  reason: '',
  ticket_id: '',
  expires_at: '',
})
const revokeConfirm = reactive<{ open: boolean, row: any }>({
  open: false,
  row: null,
})

const alertType = (err: any) => err?.status === 403 ? 'warning' : err?.status === 503 ? 'warning' : 'danger'
const localeLabel = (value: 'th-TH' | 'en-US') => localeOptions.find((option) => option.value === value)?.label || value
const localizedFrom = (value: any, fallback = '') => {
  const next = { 'th-TH': '', 'en-US': '' }
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
const fieldError = (field: string) => validation.value[field]?.[0] || ''
const bypassFieldError = (field: string) => bypassValidation.value[field]?.[0] || ''
const bypassInvalidClass = (field: string) => bypassFieldError(field) ? 'is-invalid' : ''
const toApiDate = (value: string) => value ? new Date(value).toISOString() : null
const bypassTicketMissing = computed(() => !String(bypass.ticket_id || '').trim())
const activeModeError = computed(() => (
  form.status === 'active' && form.mode === 'scheduled'
    ? 'Active maintenance must use a blocking mode.'
    : ''
))
const invalidClass = (field: string) => fieldError(field) || (field === 'mode' && activeModeError.value) ? 'is-invalid' : ''
const availableModes = computed(() => form.status === 'active' ? modes.filter((mode) => mode !== 'scheduled') : modes)
const saveDisabled = computed(() => Boolean(
  saving.value
  || !tenantId.value
  || !String(form.reason || '').trim()
  || activeModeError.value,
))
const bypassSubmitDisabled = computed(() => Boolean(
  saving.value
  || !tenantId.value
  || !String(bypass.reason || '').trim()
  || bypassTicketMissing.value,
))

const stringList = (value: any) => Array.isArray(value)
  ? value.map((item) => String(item || '').trim()).filter(Boolean)
  : []

const linesToList = (value: string) => String(value || '')
  .split(/\r?\n/g)
  .map((item) => item.trim())
  .filter(Boolean)

const applySetting = (payload: any) => {
  setting.value = payload?.data || payload
  if (!setting.value) return
  form.status = setting.value.status || 'inactive'
  form.mode = setting.value.mode || 'scheduled'
  form.message = setting.value.message || ''
  form.message_i18n = localizedFrom(setting.value.message_i18n, setting.value.message)
  form.reason = setting.value.reason || ''
  form.ticket_id = setting.value.ticket_id || ''
  form.scheduled_start_at = setting.value.scheduled_start_at ? setting.value.scheduled_start_at.slice(0, 16) : ''
  form.expected_end_at = setting.value.expected_end_at ? setting.value.expected_end_at.slice(0, 16) : ''
  form.retry_after_seconds = setting.value.retry_after_seconds
  form.allowed_routes = stringList(setting.value.allowed_routes).join('\n')
  form.blocked_route_patterns = stringList(setting.value.blocked_route_patterns).join('\n')
}

const loadSetting = async () => {
  if (!tenantId.value) return
  const response = await api.apiFetch('/admin/tenant/maintenance', { scope: 'tenant', tenantId: tenantId.value })
  applySetting(response)
}

const loadEvents = async (cursor?: string | null, pageMode: 'reset' | 'next' | 'previous' = 'reset') => {
  if (!tenantId.value) return
  eventsLoading.value = true
  try {
    const pageCursor = cursor || null
    const response: any = await api.apiFetch('/admin/tenant/maintenance/events', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: { cursor: pageCursor || undefined, limit: 20 },
    })
    events.value = response.data || []
    eventMeta.next_cursor = response.meta?.next_cursor || null
    eventMeta.has_more = Boolean(response.meta?.has_more)
    updatePageState(eventPageState, pageCursor, pageMode)
  } finally {
    eventsLoading.value = false
  }
}

const loadBypasses = async (cursor?: string | null, pageMode: 'reset' | 'next' | 'previous' = 'reset') => {
  if (!tenantId.value) return
  bypassLoading.value = true
  try {
    const pageCursor = cursor || null
    const response: any = await api.apiFetch('/admin/tenant/maintenance/bypasses', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: { cursor: pageCursor || undefined, limit: 20, status: 'active' },
    })
    bypasses.value = response.data || []
    bypassMeta.next_cursor = response.meta?.next_cursor || null
    bypassMeta.has_more = Boolean(response.meta?.has_more)
    updatePageState(bypassPageState, pageCursor, pageMode)
  } finally {
    bypassLoading.value = false
  }
}

const loadNextEventsPage = () => {
  if (!eventMeta.next_cursor) return
  loadEvents(eventMeta.next_cursor, 'next')
}

const loadPreviousEventsPage = () => {
  if (eventPageState.index <= 0) return
  loadEvents(eventPageState.cursors[eventPageState.index - 1] || null, 'previous')
}

const loadNextBypassesPage = () => {
  if (!bypassMeta.next_cursor) return
  loadBypasses(bypassMeta.next_cursor, 'next')
}

const loadPreviousBypassesPage = () => {
  if (bypassPageState.index <= 0) return
  loadBypasses(bypassPageState.cursors[bypassPageState.index - 1] || null, 'previous')
}

const updatePageState = (state: { cursors: Array<string | null>, index: number }, cursor: string | null, mode: 'reset' | 'next' | 'previous') => {
  if (mode === 'reset') {
    state.cursors = [cursor]
    state.index = 0
    return
  }

  if (mode === 'next') {
    state.cursors = [...state.cursors.slice(0, state.index + 1), cursor]
    state.index += 1
    return
  }

  state.index = Math.max(0, state.index - 1)
}

const loadAll = async () => {
  loading.value = true
  error.value = null
  retryAfter.value = null
  try {
    await Promise.all([loadSetting(), loadEvents(), loadBypasses()])
  } catch (err: any) {
    error.value = err
    retryAfter.value = err?.retryAfter || null
  } finally {
    loading.value = false
  }
}

const save = async () => {
  if (!tenantId.value) return
  saving.value = true
  error.value = null
  validation.value = {}
  try {
    const response = await api.apiFetch('/admin/tenant/maintenance', {
      method: 'PUT',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      body: {
        status: form.status,
        mode: form.mode,
        message: firstLocalizedValue(form.message_i18n, form.message),
        message_i18n: normalizedLocalized(form.message_i18n),
        reason: form.reason,
        ticket_id: form.ticket_id,
        scheduled_start_at: toApiDate(form.scheduled_start_at),
        expected_end_at: toApiDate(form.expected_end_at),
        retry_after_seconds: form.retry_after_seconds,
        allowed_routes: linesToList(form.allowed_routes),
        blocked_route_patterns: linesToList(form.blocked_route_patterns),
      },
    })
    applySetting(response)
    await loadEvents()
  } catch (err: any) {
    error.value = err
    validation.value = err?.details?.fields || {}
    retryAfter.value = err?.retryAfter || null
  } finally {
    saving.value = false
  }
}

const createBypass = async () => {
  if (!tenantId.value) return
  bypassValidation.value = {}
  if (!String(bypass.reason || '').trim() || !String(bypass.ticket_id || '').trim()) {
    bypassValidation.value = {
      ...(!String(bypass.reason || '').trim() ? { reason: ['Reason is required before creating a bypass.'] } : {}),
      ...(!String(bypass.ticket_id || '').trim() ? { ticket_id: ['Ticket ID is required before creating a bypass.'] } : {}),
    }
    return
  }

  saving.value = true
  error.value = null
  validation.value = {}
  bypassValidation.value = {}
  try {
    lastBypass.value = await api.apiFetch('/admin/tenant/maintenance/bypasses', {
      method: 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      body: {
        actor_type: bypass.actor_type,
        actor_id: bypass.actor_id,
        reason: bypass.reason,
        ticket_id: bypass.ticket_id,
        expires_at: toApiDate(bypass.expires_at),
      },
    })
    bypass.actor_id = ''
    bypass.reason = ''
    bypass.ticket_id = ''
    bypass.expires_at = ''
    await Promise.all([loadBypasses(), loadEvents()])
  } catch (err: any) {
    error.value = err
    bypassValidation.value = err?.details?.fields || {}
  } finally {
    saving.value = false
  }
}

const prepareRevokeBypass = (item: any) => {
  revokeConfirm.row = item
  revokeConfirm.open = true
}

const confirmRevokeBypass = async (reason: string) => {
  if (!tenantId.value) return
  const id = revokeConfirm.row?.id
  if (!id) return
  saving.value = true
  error.value = null
  try {
    await api.apiFetch(`/admin/tenant/maintenance/bypasses/${id}`, {
      method: 'DELETE',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      body: { reason },
    })
    if (lastBypass.value?.id === id) {
      lastBypass.value = { ...lastBypass.value, status: 'revoked', effective_status: 'revoked', is_currently_active: false }
    }
    revokeConfirm.open = false
    await Promise.all([loadBypasses(), loadEvents()])
  } catch (err) {
    error.value = err
  } finally {
    saving.value = false
  }
}

watch(() => form.status, (status) => {
  if (status === 'active' && form.mode === 'scheduled') {
    form.mode = 'full_site'
  }
})

onMounted(loadAll)
</script>

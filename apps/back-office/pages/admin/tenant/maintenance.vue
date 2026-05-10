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
    <div v-else class="row">
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
                <option v-for="mode in modes" :key="mode" :value="mode">{{ titleize(mode) }}</option>
              </select>
              <div class="invalid-feedback">{{ fieldError('mode') }}</div>
            </div>
            <div class="col-12">
              <label class="form-label">Message</label>
              <textarea v-model="form.message" class="form-control" rows="3" :class="invalidClass('message')" />
              <div class="invalid-feedback">{{ fieldError('message') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Reason</label>
              <input v-model="form.reason" class="form-control" :class="invalidClass('reason')" />
              <div class="invalid-feedback">{{ fieldError('reason') }}</div>
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
            <div class="col-md-6 d-flex align-items-end">
              <button class="btn btn-primary btn-wave w-100" type="submit" :disabled="saving || !tenantId || !form.reason.trim()">
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
              <select v-model="bypass.actor_type" class="form-select" :class="invalidClass('actor_type')">
                <option value="customer">Customer</option>
                <option value="tenant_admin">Tenant admin</option>
                <option value="support_session">Support session</option>
              </select>
              <div class="invalid-feedback">{{ fieldError('actor_type') }}</div>
            </div>
            <div class="col-md-8">
              <label class="form-label">Actor ID</label>
              <input v-model="bypass.actor_id" class="form-control" :class="invalidClass('actor_id')" />
              <div class="invalid-feedback">{{ fieldError('actor_id') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Reason</label>
              <input v-model="bypass.reason" class="form-control" :class="invalidClass('reason')" />
            </div>
            <div class="col-md-6">
              <label class="form-label">Ticket ID</label>
              <input v-model="bypass.ticket_id" class="form-control" :class="invalidClass('ticket_id')" />
              <div class="invalid-feedback">{{ fieldError('ticket_id') }}</div>
            </div>
            <div class="col-md-6">
              <label class="form-label">Expires at</label>
              <input v-model="bypass.expires_at" type="datetime-local" class="form-control" />
            </div>
            <div class="col-12">
              <button class="btn btn-outline-primary btn-wave" type="submit" :disabled="saving || !tenantId || !bypass.reason.trim()">
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
              <dt class="col-5">Expected end</dt>
              <dd class="col-7">{{ formatDateTime(setting.expected_end_at) }}</dd>
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
            <AdminTimeline v-else :items="events" />
            <AdminPagination class="mt-3" :next-cursor="eventMeta.next_cursor" :loading="eventsLoading" @next="loadEvents(eventMeta.next_cursor)" />
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
            <AdminPagination class="mt-3" :next-cursor="bypassMeta.next_cursor" :loading="bypassLoading" @next="loadBypasses(bypassMeta.next_cursor)" />
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
const setting = ref<any>(null)
const events = ref<any[]>([])
const bypasses = ref<any[]>([])
const eventMeta = reactive({ next_cursor: null as string | null, has_more: false })
const bypassMeta = reactive({ next_cursor: null as string | null, has_more: false })
const lastBypass = ref<any>(null)

const statuses = ['inactive', 'scheduled', 'active', 'ended', 'cancelled']
const modes = ['full_site', 'customer_web_only', 'admin_only', 'checkout_payment_only', 'read_only', 'scheduled']
const form = reactive<any>({
  status: 'inactive',
  mode: 'scheduled',
  message: '',
  reason: '',
  expected_end_at: '',
  retry_after_seconds: null,
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
const fieldError = (field: string) => validation.value[field]?.[0] || ''
const invalidClass = (field: string) => fieldError(field) ? 'is-invalid' : ''
const toApiDate = (value: string) => value ? new Date(value).toISOString() : null

const applySetting = (payload: any) => {
  setting.value = payload?.data || payload
  if (!setting.value) return
  form.status = setting.value.status || 'inactive'
  form.mode = setting.value.mode || 'scheduled'
  form.message = setting.value.message || ''
  form.reason = setting.value.reason || ''
  form.expected_end_at = setting.value.expected_end_at ? setting.value.expected_end_at.slice(0, 16) : ''
  form.retry_after_seconds = setting.value.retry_after_seconds
}

const loadSetting = async () => {
  if (!tenantId.value) return
  const response = await api.apiFetch('/admin/tenant/maintenance', { scope: 'tenant', tenantId: tenantId.value })
  applySetting(response)
}

const loadEvents = async (cursor?: string | null) => {
  if (!tenantId.value) return
  eventsLoading.value = true
  try {
    const response: any = await api.apiFetch('/admin/tenant/maintenance/events', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: { cursor: cursor || undefined, limit: 20 },
    })
    events.value = cursor ? [...events.value, ...(response.data || [])] : (response.data || [])
    eventMeta.next_cursor = response.meta?.next_cursor || null
    eventMeta.has_more = Boolean(response.meta?.has_more)
  } finally {
    eventsLoading.value = false
  }
}

const loadBypasses = async (cursor?: string | null) => {
  if (!tenantId.value) return
  bypassLoading.value = true
  try {
    const response: any = await api.apiFetch('/admin/tenant/maintenance/bypasses', {
      scope: 'tenant',
      tenantId: tenantId.value,
      query: { cursor: cursor || undefined, limit: 20, status: 'active' },
    })
    bypasses.value = cursor ? [...bypasses.value, ...(response.data || [])] : (response.data || [])
    bypassMeta.next_cursor = response.meta?.next_cursor || null
    bypassMeta.has_more = Boolean(response.meta?.has_more)
  } finally {
    bypassLoading.value = false
  }
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
        message: form.message,
        reason: form.reason,
        expected_end_at: toApiDate(form.expected_end_at),
        retry_after_seconds: form.retry_after_seconds,
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
  saving.value = true
  error.value = null
  validation.value = {}
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
    await Promise.all([loadBypasses(), loadEvents()])
  } catch (err: any) {
    error.value = err
    validation.value = err?.details?.fields || {}
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

onMounted(loadAll)
</script>

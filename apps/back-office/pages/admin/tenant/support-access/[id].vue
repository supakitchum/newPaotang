<template>
  <div>
    <AdminPageHeader title="Support Access Detail" :breadcrumbs="breadcrumbs">
      <template #actions>
        <NuxtLink to="/admin/tenant/support-access" class="btn btn-light btn-wave">
          <i class="ri-arrow-left-line me-1" />
          Back
        </NuxtLink>
        <button class="btn btn-primary btn-wave" type="button" @click="load">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="error" :type="error.status === 403 ? 'warning' : 'danger'" :message="error.message" :details="error.details" />
    <AdminAlert
      v-if="oneTimeToken"
      type="warning"
      message="Support impersonation token is shown once in this browser state. It is not stored and will disappear when you refresh or close this page."
      dismissible
      @dismiss="oneTimeToken = null"
    />

    <AdminLoader v-if="loading" />
    <div v-else-if="!request">
      <AdminEmptyState title="Request not found" message="The backend did not return this support access request." />
    </div>
    <div v-else class="row">
      <div class="col-xl-4">
        <div class="card custom-card">
          <div class="card-header d-flex align-items-center justify-content-between">
            <div class="card-title">Request</div>
            <AdminStatusBadge :status="request.status" />
          </div>
          <div class="card-body">
            <dl class="row mb-0">
              <dt class="col-5">Target</dt>
              <dd class="col-7">{{ request.target_user_type }} · {{ request.target_user_id }}</dd>
              <dt class="col-5">Scope</dt>
              <dd class="col-7">{{ request.scope }}</dd>
              <dt class="col-5">Ticket</dt>
              <dd class="col-7">{{ request.ticket_id }}</dd>
              <dt class="col-5">Reason</dt>
              <dd class="col-7">{{ request.reason }}</dd>
              <dt class="col-5">Expires</dt>
              <dd class="col-7">{{ formatDateTime(request.expires_at) }}</dd>
            </dl>
          </div>
        </div>

        <div v-if="oneTimeToken" class="card custom-card border border-warning">
          <div class="card-header">
            <div class="card-title">Initial token</div>
          </div>
          <div class="card-body">
            <p class="text-muted">Use immediately. This token is held only in a page ref and is not persisted.</p>
            <div class="alert alert-warning np-support-token">{{ oneTimeToken }}</div>
            <button class="btn btn-sm btn-outline-secondary btn-wave" type="button" @click="oneTimeToken = null">
              Hide token
            </button>
          </div>
        </div>

        <div class="card custom-card">
          <div class="card-header">
            <div class="card-title">Active session</div>
          </div>
          <div class="card-body">
            <AdminEmptyState v-if="!request.active_session" title="No session" message="Start impersonation only after approval." icon="ri-login-circle-line" />
            <dl v-else class="row mb-0">
              <dt class="col-5">Session</dt>
              <dd class="col-7">{{ request.active_session.id }}</dd>
              <dt class="col-5">Status</dt>
              <dd class="col-7"><AdminStatusBadge :status="request.active_session.status" /></dd>
              <dt class="col-5">Token last four</dt>
              <dd class="col-7">{{ request.active_session.token_last_four || '-' }}</dd>
              <dt class="col-5">Expires</dt>
              <dd class="col-7">{{ formatDateTime(request.active_session.expires_at) }}</dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="col-xl-8">
        <div class="card custom-card">
          <div class="card-header">
            <div class="card-title">Actions</div>
          </div>
          <div class="card-body">
            <AdminAlert type="danger" message="Sensitive actions such as wallet, payout, role, permission, and user deletion are blocked during support impersonation." />
            <div class="row g-3">
              <div class="col-12">
                <label class="form-label">Reason</label>
                <input v-model="actionReason" class="form-control" :class="invalidClass('reason')" placeholder="Required for write actions" />
                <div class="invalid-feedback">{{ fieldError('reason') }}</div>
              </div>
              <div class="col-md-6 col-lg-4">
                <button class="btn btn-success btn-wave w-100" type="button" :disabled="actionDisabled" @click="writeAction('approve')">
                  <i class="ri-check-line me-1" />
                  Approve
                </button>
              </div>
              <div class="col-md-6 col-lg-4">
                <button class="btn btn-danger btn-wave w-100" type="button" :disabled="actionDisabled" @click="writeAction('revoke')">
                  <i class="ri-close-line me-1" />
                  Revoke
                </button>
              </div>
              <div class="col-md-6 col-lg-4">
                <button class="btn btn-primary btn-wave w-100" type="button" :disabled="actionDisabled" @click="writeAction('impersonate')">
                  <i class="ri-user-shared-line me-1" />
                  Start impersonation
                </button>
              </div>
              <div class="col-md-6">
                <button class="btn btn-outline-primary btn-wave w-100" type="button" :disabled="actionDisabled" @click="writeAction('elevated-actions')">
                  <i class="ri-flashlight-line me-1" />
                  Log elevated action
                </button>
              </div>
              <div class="col-md-6">
                <button class="btn btn-outline-secondary btn-wave w-100" type="button" :disabled="actionDisabled" @click="writeAction('end-session')">
                  <i class="ri-logout-circle-r-line me-1" />
                  End session
                </button>
              </div>
              <div v-if="showElevatedAction" class="col-12">
                <label class="form-label">Elevated action</label>
                <select v-model="elevatedAction" class="form-select" :class="invalidClass('action')">
                  <option value="wallet_adjust">wallet_adjust</option>
                  <option value="topup_approve">topup_approve</option>
                  <option value="payout_approve">payout_approve</option>
                  <option value="permission_change">permission_change</option>
                  <option value="role_change">role_change</option>
                  <option value="delete_user">delete_user</option>
                </select>
                <div class="invalid-feedback">{{ fieldError('action') }}</div>
              </div>
            </div>
          </div>
        </div>

        <div class="row">
          <div class="col-lg-6">
            <div class="card custom-card">
              <div class="card-header">
                <div class="card-title">Approvals</div>
              </div>
              <div class="card-body">
                <AdminEmptyState v-if="!request.approvals?.length" title="No approvals" message="Approval decisions will appear here." />
                <AdminTimeline v-else :items="request.approvals" icon="ri-shield-check-line" />
              </div>
            </div>
          </div>
          <div class="col-lg-6">
            <div class="card custom-card">
              <div class="card-header">
                <div class="card-title">Session timeline</div>
              </div>
              <div class="card-body">
                <AdminEmptyState v-if="!request.events?.length" title="No session events" message="Impersonation events will appear here." />
                <AdminTimeline v-else :items="request.events" icon="ri-user-shared-line" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime } from '~/utils/format'

definePageMeta({ layout: 'admin' })

const route = useRoute()
const api = useAdminApi()
const session = useAdminSession()
const tenantId = computed(() => session.currentTenantId.value)
const request = ref<any>(null)
const loading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const validation = ref<Record<string, string[]>>({})
const actionReason = ref('')
const elevatedAction = ref('wallet_adjust')
const showElevatedAction = ref(false)
const oneTimeToken = ref<string | null>(null)
const breadcrumbs = computed(() => ['Admin', 'Tenant', 'Support Access', String(route.params.id)])
const actionDisabled = computed(() => saving.value || actionReason.value.trim() === '')

const fieldError = (field: string) => validation.value[field]?.[0] || ''
const invalidClass = (field: string) => fieldError(field) ? 'is-invalid' : ''

const load = async () => {
  if (!tenantId.value) return
  loading.value = true
  error.value = null
  try {
    request.value = await api.apiFetch(`/admin/tenant/support-access/${route.params.id}`, {
      scope: 'tenant',
      tenantId: tenantId.value,
    })
    if (request.value?.active_session?.access_token) {
      delete request.value.active_session.access_token
    }
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const writeAction = async (action: string) => {
  if (!tenantId.value) return
  showElevatedAction.value = action === 'elevated-actions'
  saving.value = true
  error.value = null
  validation.value = {}

  try {
    const body: Record<string, string> = { reason: actionReason.value }
    if (action === 'elevated-actions') {
      body.action = elevatedAction.value
    }

    const response: any = await api.apiFetch(`/admin/tenant/support-access/${route.params.id}/${action}`, {
      method: 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      body,
    })

    request.value = response

    const issued = response?.active_session?.access_token
    if (issued) {
      oneTimeToken.value = issued
      delete request.value.active_session.access_token
    } else {
      oneTimeToken.value = null
    }
  } catch (err: any) {
    error.value = err
    validation.value = err?.details?.fields || {}
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

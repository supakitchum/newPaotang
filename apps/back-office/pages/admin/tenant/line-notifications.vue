<template>
  <div>
    <AdminPageHeader title="LINE Notifications" :breadcrumbs="['Admin', 'Tenant', 'LINE Notifications']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading" @click="loadSettings">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="!tenantId" type="warning" message="Select a tenant scope before editing LINE notifications." />
    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="np-line-tabs">
      <button v-for="tab in tabs" :key="tab.key" class="np-line-tab" :class="{ active: activeTab === tab.key }" type="button" @click="activeTab = tab.key">
        <i :class="tab.icon" />
        <span>{{ tab.label }}</span>
      </button>
    </div>

    <div v-if="activeTab === 'connection'" class="card custom-card">
      <div class="card-header">
        <div>
          <div class="card-title">LINE OA connection</div>
          <div class="text-muted fs-12">Messaging API token is verified against LINE before saving.</div>
        </div>
        <div class="ms-auto d-flex flex-wrap align-items-center gap-2">
          <button class="btn btn-sm btn-success-light btn-wave" type="button" :disabled="!connection.configured || !tenantId || testingSend" @click="openTestSend">
            <span v-if="testingSend" class="spinner-border spinner-border-sm me-1" />
            <i v-else class="ri-send-plane-line me-1" />
            Test send
          </button>
          <button class="btn btn-sm btn-primary-light btn-wave" type="button" @click="guideModalOpen = true">
            <i class="ri-question-line me-1" />
            วิธีใช้
          </button>
          <AdminStatusBadge :status="connection.status || 'inactive'" :label="titleize(connection.status || 'inactive')" />
        </div>
      </div>
      <div class="card-body">
        <div class="np-line-bot">
          <img v-if="connection.bot_picture_url" :src="connection.bot_picture_url" alt="" />
          <div v-else class="np-line-bot-icon"><i class="ri-line-line" /></div>
          <div>
            <div class="fw-semibold">{{ connection.bot_display_name || 'No LINE OA verified yet' }}</div>
            <div class="text-muted fs-12">{{ connection.bot_basic_id || 'Enter credentials below and save.' }}</div>
          </div>
          <div class="ms-auto text-end">
            <div class="text-muted fs-12">Messaging API Webhook URL</div>
            <code>{{ connection.webhook_url || '/api/v1/public/line/webhook' }}</code>
          </div>
        </div>

        <form class="row g-3 mt-2" @submit.prevent="saveConnection">
          <div class="col-md-6">
            <label class="form-label">Messaging API Channel Access Token</label>
            <input v-model="connectionForm.messaging_access_token" class="form-control" type="password" autocomplete="off" :placeholder="connection.messaging_access_token_masked || 'Paste token'">
          </div>
          <div class="col-md-6">
            <label class="form-label">Messaging API Channel Secret</label>
            <input v-model="connectionForm.messaging_channel_secret" class="form-control" type="password" autocomplete="off" :placeholder="connection.messaging_channel_secret_masked || 'Paste secret'">
          </div>
          <div class="col-md-6">
            <label class="form-label">Status</label>
            <select v-model="connectionForm.status" class="form-select">
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </select>
          </div>
          <div class="col-12 d-flex flex-wrap justify-content-between gap-2">
            <button v-if="connection.configured" class="btn btn-outline-danger btn-wave" type="button" :disabled="disconnectingConnection || savingConnection || !tenantId" @click="disconnectConnection">
              <span v-if="disconnectingConnection" class="spinner-border spinner-border-sm me-2" />
              <i v-else class="ri-link-unlink-m me-1" />
              ยกเลิกการเชื่อมต่อ
            </button>
            <div v-else />
            <button class="btn btn-primary btn-wave" type="submit" :disabled="savingConnection || disconnectingConnection || !tenantId">
              <span v-if="savingConnection" class="spinner-border spinner-border-sm me-2" />
              Verify and save
            </button>
          </div>
        </form>
      </div>
    </div>

    <div v-else-if="activeTab === 'templates'" class="card custom-card">
      <div class="card-header">
        <div>
          <div class="card-title">Message templates</div>
          <div class="text-muted fs-12">Edit LINE text or Flex bubble templates with placeholders.</div>
        </div>
      </div>
      <div class="card-body">
        <AdminDataTable :columns="templateColumns" :rows="templates" :loading="loading" empty-title="No templates" sortable embedded>
          <template #cell-label="{ row }">
            <button class="btn btn-link p-0 fw-semibold text-start" type="button" @click="openTemplate(row)">
              {{ row.label }}
            </button>
            <div class="text-muted fs-12">{{ row.description }}</div>
          </template>
          <template #cell-enabled="{ row }">
            <AdminStatusBadge :status="row.enabled" :label="row.enabled ? 'Enabled' : 'Disabled'" />
          </template>
          <template #cell-message_type="{ row }">
            <span class="badge bg-info-transparent text-info">{{ row.message_type }}</span>
          </template>
          <template #rowActions="{ row }">
            <button class="btn btn-sm btn-primary-light btn-wave" type="button" @click="openTemplate(row)">Edit</button>
          </template>
        </AdminDataTable>
      </div>
    </div>

    <div v-else-if="activeTab === 'customers'" class="card custom-card">
      <div class="card-header">
        <div class="card-title">Linked customers</div>
      </div>
      <div class="card-body">
        <AdminDataTable :columns="customerColumns" :rows="linkedCustomers" :loading="loadingCustomers" empty-title="No linked customers" sortable embedded>
          <template #cell-display_name="{ row }">
            <div class="d-flex align-items-center gap-2">
              <img v-if="row.picture_url" class="np-line-avatar" :src="row.picture_url" alt="" />
              <span class="fw-semibold">{{ row.display_name || '-' }}</span>
            </div>
          </template>
          <template #cell-notification_enabled="{ row }">
            <AdminStatusBadge :status="row.notification_enabled" :label="row.notification_enabled ? 'Enabled' : 'Off'" />
          </template>
          <template #cell-friend_flag="{ row }">
            <AdminStatusBadge :status="row.friend_flag" :label="row.friend_flag ? 'Friend' : 'Not friend'" />
          </template>
        </AdminDataTable>
      </div>
    </div>

    <div v-else class="card custom-card">
      <div class="card-header">
        <div class="card-title">Delivery logs</div>
        <select v-model="deliveryStatus" class="form-select form-select-sm np-line-status ms-auto" @change="loadDeliveries">
          <option value="">All statuses</option>
          <option value="queued">Queued</option>
          <option value="sent">Sent</option>
          <option value="failed">Failed</option>
          <option value="retryable_failed">Retryable failed</option>
        </select>
      </div>
      <div class="card-body">
        <AdminDataTable :columns="deliveryColumns" :rows="deliveries" :loading="loadingDeliveries" empty-title="No delivery logs" sortable embedded>
          <template #cell-event_key="{ row }">
            <div class="fw-semibold">{{ labelForEvent(row.event_key) }}</div>
            <div class="text-muted fs-12">{{ row.event_key }}</div>
          </template>
          <template #cell-status="{ row }">
            <AdminStatusBadge :status="row.status" :label="titleize(row.status)" />
          </template>
          <template #cell-last_error="{ row }">
            <span class="text-muted">{{ row.last_error || '-' }}</span>
          </template>
        </AdminDataTable>
      </div>
    </div>

    <div v-if="testModalOpen" class="modal fade show d-block np-line-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-md modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">Test LINE Message</h5>
              <div class="text-muted fs-12">ส่งข้อความทดสอบผ่าน LINE OA ของร้านค้านี้</div>
            </div>
            <button class="btn-close" type="button" :disabled="testingSend" @click="testModalOpen = false" />
          </div>
          <div class="modal-body">
            <div class="mb-3">
              <label class="form-label">Linked customer</label>
              <select v-model="lineTestForm.customer_id" class="form-select">
                <option value="">Manual LINE user ID</option>
                <option v-for="customer in linkedCustomers" :key="customer.id" :value="customer.customer_id">
                  {{ customer.display_name || customer.customer_name || customer.customer_phone || customer.line_user_id }}
                </option>
              </select>
              <div class="form-text">เลือกลูกค้าที่เชื่อมต่อ LINE แล้ว หรือเลือก manual เพื่อกรอก LINE user ID เอง</div>
            </div>
            <div class="mb-3">
              <label class="form-label">Manual LINE user ID</label>
              <input v-model="lineTestForm.line_user_id" class="form-control" :disabled="Boolean(lineTestForm.customer_id)" placeholder="Uxxxxxxxxxxxxxxxx">
            </div>
            <div>
              <label class="form-label">Message</label>
              <textarea v-model="lineTestForm.message" class="form-control" rows="4" />
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-light btn-wave" type="button" :disabled="testingSend" @click="testModalOpen = false">Cancel</button>
            <button class="btn btn-success btn-wave" type="button" :disabled="testingSend || (!lineTestForm.customer_id && !lineTestForm.line_user_id)" @click="sendLineTest">
              <span v-if="testingSend" class="spinner-border spinner-border-sm me-2" />
              Send test
            </button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="guideModalOpen" class="modal fade show d-block np-line-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">วิธีเชื่อมต่อ LINE Messaging API</h5>
              <div class="text-muted fs-12">ตั้งค่า LINE OA สำหรับส่งข้อความแจ้งเตือนถึงลูกค้า</div>
            </div>
            <button class="btn-close" type="button" @click="guideModalOpen = false" />
          </div>
          <div class="modal-body">
            <div class="np-line-guide">
              <section class="np-line-guide-step">
                <div class="np-line-guide-number">1</div>
                <div>
                  <h6>เตรียม LINE OA และ Messaging API</h6>
                  <p>เข้า LINE Developers ใน Provider ของร้านค้า สร้างหรือเลือก Messaging API channel ของ LINE OA แล้วนำ <strong>Channel access token</strong> และ <strong>Channel secret</strong> มากรอกในหน้านี้</p>
                </div>
              </section>
              <section class="np-line-guide-step">
                <div class="np-line-guide-number">2</div>
                <div>
                  <h6>Verify and save</h6>
                  <p>กรอกข้อมูลให้ครบ เลือก Active แล้วกด <strong>Verify and save</strong> ระบบจะตรวจสอบ token กับ LINE ก่อนบันทึก หาก API ตอบ error ให้แก้ข้อมูลแล้วกด Save ใหม่ได้</p>
                </div>
              </section>
              <section class="np-line-guide-step">
                <div class="np-line-guide-number">3</div>
                <div>
                  <h6>ให้ลูกค้าเชื่อมต่อ LINE</h6>
                  <p>ลูกค้าไปที่หน้า Profile แล้วเลือกเมนูแจ้งเตือนผ่าน LINE จากนั้นกดเชื่อมต่อ LINE หรือ login ด้วย LINE ถ้ายังไม่เคยผูกบัญชี ระบบจะให้ยืนยันเบอร์ก่อน</p>
                </div>
              </section>
              <section class="np-line-guide-step">
                <div class="np-line-guide-number">4</div>
                <div>
                  <h6>แก้ Template และดู Delivery Logs</h6>
                  <p>แท็บ Templates ใช้แก้ข้อความแบบ Text หรือ Flex bubble พร้อม placeholder เช่น <code>{{ placeholderLabel('customer.name') }}</code> และ <code>{{ placeholderLabel('order.amount_baht') }}</code> ส่วน Delivery logs ใช้ตรวจ sent/failed</p>
                </div>
              </section>
            </div>
            <div class="alert alert-info mt-3 mb-0">
              ลูกค้าต้องผูก LINE กับบัญชี และเพิ่มเพื่อน LINE OA ก่อนจึงจะรับ push message ได้ หากส่งไม่ได้ระบบจะบันทึก delivery log แต่ไม่ทำให้รายการหลัก fail
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-primary btn-wave" type="button" @click="guideModalOpen = false">รับทราบ</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="templateModalOpen" class="modal fade show d-block np-line-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-xl modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">{{ templateForm.label }}</h5>
              <div class="text-muted fs-12">{{ templateForm.event_key }}</div>
            </div>
            <button class="btn-close" type="button" :disabled="savingTemplate" @click="closeTemplate" />
          </div>
          <div class="modal-body">
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Title / Alt text</label>
                <input v-model="templateForm.title" class="form-control">
              </div>
              <div class="col-md-3">
                <label class="form-label">Message type</label>
                <select v-model="templateForm.message_type" class="form-select">
                  <option value="flex">Flex bubble</option>
                  <option value="text">Text</option>
                </select>
              </div>
              <div class="col-md-3 d-flex align-items-end">
                <label class="form-check form-switch mb-2">
                  <input v-model="templateForm.enabled" class="form-check-input" type="checkbox">
                  <span class="form-check-label">Enabled</span>
                </label>
              </div>
              <div class="col-12">
                <label class="form-label">Body text</label>
                <textarea v-model="templateForm.body_text" class="form-control" rows="3" />
              </div>
              <div class="col-lg-7">
                <label class="form-label">Flex JSON</label>
                <textarea v-model="templateForm.flex_json_text" class="form-control np-line-json" rows="15" spellcheck="false" />
                <div v-if="templateJsonError" class="text-danger fs-12 mt-1">{{ templateJsonError }}</div>
              </div>
              <div class="col-lg-5">
                <label class="form-label">Placeholders</label>
                <div class="np-line-vars">
                  <button v-for="variable in templateForm.variables" :key="variable" class="btn btn-sm btn-light" type="button" @click="copyVariable(variable)">
                    {{ placeholderLabel(variable) }}
                  </button>
                </div>
                <div class="np-line-preview mt-3">
                  <div class="text-muted fs-12 mb-2">Saved template preview</div>
                  <pre>{{ previewText }}</pre>
                </div>
              </div>
            </div>
          </div>
          <div class="modal-footer justify-content-between">
            <button class="btn btn-light btn-wave" type="button" :disabled="savingTemplate" @click="loadTemplatePreview">Preview saved</button>
            <div class="d-flex gap-2">
              <button class="btn btn-light btn-wave" type="button" :disabled="savingTemplate" @click="closeTemplate">Cancel</button>
              <button class="btn btn-primary btn-wave" type="button" :disabled="savingTemplate || Boolean(templateJsonError)" @click="saveTemplate">
                <span v-if="savingTemplate" class="spinner-border spinner-border-sm me-2" />
                Save template
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div v-if="guideModalOpen || templateModalOpen || testModalOpen" class="modal-backdrop fade show np-line-modal-backdrop" />
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

type AnyRecord = Record<string, any>

const api = useAdminApi()
const session = useAdminSession()
const tenantId = computed(() => session.currentTenantId.value)
const tabs = [
  { key: 'connection', label: 'Connection', icon: 'ri-plug-line' },
  { key: 'templates', label: 'Templates', icon: 'ri-message-3-line' },
  { key: 'customers', label: 'Customers', icon: 'ri-user-heart-line' },
  { key: 'deliveries', label: 'Delivery logs', icon: 'ri-history-line' },
]
const templateColumns = [
  { key: 'label', label: 'Event' },
  { key: 'enabled', label: 'Enabled' },
  { key: 'message_type', label: 'Type' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]
const customerColumns = [
  { key: 'display_name', label: 'LINE' },
  { key: 'customer_name', label: 'Customer' },
  { key: 'customer_phone', label: 'Phone' },
  { key: 'friend_flag', label: 'Friend' },
  { key: 'notification_enabled', label: 'Notifications' },
  { key: 'linked_at', label: 'Linked', type: 'datetime' },
]
const deliveryColumns = [
  { key: 'event_key', label: 'Event' },
  { key: 'status', label: 'Status' },
  { key: 'attempts', label: 'Attempts' },
  { key: 'source_id', label: 'Source' },
  { key: 'last_error', label: 'Error' },
  { key: 'created_at', label: 'Created', type: 'datetime' },
]
const activeTab = ref('connection')
const loading = ref(false)
const loadingCustomers = ref(false)
const loadingDeliveries = ref(false)
const savingConnection = ref(false)
const disconnectingConnection = ref(false)
const savingTemplate = ref(false)
const testingSend = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const connection = ref<AnyRecord>({})
const templates = ref<AnyRecord[]>([])
const linkedCustomers = ref<AnyRecord[]>([])
const deliveries = ref<AnyRecord[]>([])
const deliveryStatus = ref('')
const templateModalOpen = ref(false)
const guideModalOpen = ref(false)
const testModalOpen = ref(false)
const previewPayload = ref<AnyRecord | null>(null)
const templateForm = reactive<AnyRecord>({
  event_key: '',
  label: '',
  enabled: true,
  message_type: 'flex',
  title: '',
  body_text: '',
  flex_json_text: '',
  variables: [],
})
const connectionForm = reactive({
  messaging_access_token: '',
  messaging_channel_secret: '',
  status: 'active',
})
const lineTestForm = reactive({
  customer_id: '',
  line_user_id: '',
  message: 'ทดสอบแจ้งเตือน LINE จากร้านค้า',
})

const previewText = computed(() => JSON.stringify(previewPayload.value?.messages || [], null, 2))
const templateJsonError = computed(() => {
  if (templateForm.message_type !== 'flex') return ''
  try {
    JSON.parse(templateForm.flex_json_text || '{}')
    return ''
  } catch (err: any) {
    return err?.message || 'Flex JSON is invalid.'
  }
})

watch(activeTab, (tab) => {
  if (tab === 'customers') void loadCustomers()
  if (tab === 'deliveries') void loadDeliveries()
})

onMounted(() => {
  void loadSettings()
})

async function loadSettings() {
  if (!tenantId.value) return
  loading.value = true
  error.value = null
  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/line-notifications', { scope: 'tenant' })
    connection.value = response.connection || {}
    templates.value = Array.isArray(response.templates) ? response.templates : []
    connectionForm.status = connection.value.status === 'active' ? 'active' : 'inactive'
  } catch (err: any) {
    error.value = err
  } finally {
    loading.value = false
  }
}

async function saveConnection() {
  if (!tenantId.value) return
  savingConnection.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/line-notifications/connection', {
      method: 'PUT',
      scope: 'tenant',
      body: { ...connectionForm },
      successMessage: false,
    })
    connection.value = response.connection || {}
    templates.value = Array.isArray(response.templates) ? response.templates : templates.value
    Object.assign(connectionForm, {
      messaging_access_token: '',
      messaging_channel_secret: '',
      status: connection.value.status === 'active' ? 'active' : 'inactive',
    })
    successMessage.value = 'LINE connection verified and saved.'
  } catch (err: any) {
    error.value = lineConnectionSaveError(err)
  } finally {
    savingConnection.value = false
  }
}

async function disconnectConnection() {
  if (!tenantId.value || disconnectingConnection.value) return

  const confirmed = !import.meta.client || window.confirm('ยกเลิกการเชื่อมต่อ LINE OA? ระบบจะหยุดส่งแจ้งเตือนผ่าน LINE จนกว่าจะ Verify and save ใหม่อีกครั้ง')
  if (!confirmed) return

  disconnectingConnection.value = true
  error.value = null
  successMessage.value = ''

  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/line-notifications/connection', {
      method: 'DELETE',
      scope: 'tenant',
      successMessage: false,
    })
    connection.value = response.connection || {}
    templates.value = Array.isArray(response.templates) ? response.templates : templates.value
    Object.assign(connectionForm, {
      messaging_access_token: '',
      messaging_channel_secret: '',
      status: 'inactive',
    })
    successMessage.value = 'ยกเลิกการเชื่อมต่อ LINE แล้ว'
  } catch (err: any) {
    error.value = err
  } finally {
    disconnectingConnection.value = false
  }
}

async function openTestSend() {
  if (linkedCustomers.value.length === 0) await loadCustomers()
  lineTestForm.customer_id = lineTestForm.customer_id || linkedCustomers.value[0]?.customer_id || ''
  testModalOpen.value = true
}

async function sendLineTest() {
  if (!tenantId.value) return
  testingSend.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/line-notifications/test-send', {
      method: 'POST',
      scope: 'tenant',
      body: {
        customer_id: lineTestForm.customer_id || undefined,
        line_user_id: lineTestForm.customer_id ? undefined : lineTestForm.line_user_id,
        message: lineTestForm.message,
      },
      successMessage: false,
    })
    connection.value = response.connection || connection.value
    successMessage.value = 'LINE test message sent.'
    testModalOpen.value = false
  } catch (err: any) {
    error.value = lineTestSendError(err)
  } finally {
    testingSend.value = false
  }
}

function openTemplate(row: AnyRecord) {
  previewPayload.value = null
  Object.assign(templateForm, {
    event_key: row.event_key,
    label: row.label,
    enabled: Boolean(row.enabled),
    message_type: row.message_type || 'flex',
    title: row.title || row.label || '',
    body_text: row.body_text || '',
    flex_json_text: JSON.stringify(row.flex_json || {}, null, 2),
    variables: Array.isArray(row.variables) ? row.variables : [],
  })
  templateModalOpen.value = true
}

function closeTemplate() {
  templateModalOpen.value = false
}

async function saveTemplate() {
  savingTemplate.value = true
  error.value = null
  try {
    const flex = templateForm.message_type === 'flex' ? JSON.parse(templateForm.flex_json_text || '{}') : null
    const saved: AnyRecord = await api.apiFetch(`/admin/tenant/line-notifications/templates/${encodeURIComponent(templateForm.event_key)}`, {
      method: 'PATCH',
      scope: 'tenant',
      body: {
        enabled: templateForm.enabled,
        message_type: templateForm.message_type,
        title: templateForm.title,
        body_text: templateForm.body_text,
        flex_json: flex,
      },
      successMessage: false,
    })
    templates.value = templates.value.map((row) => row.event_key === saved.event_key ? saved : row)
    successMessage.value = 'LINE template saved.'
    closeTemplate()
  } catch (err: any) {
    error.value = err
  } finally {
    savingTemplate.value = false
  }
}

async function loadTemplatePreview() {
  if (!templateForm.event_key) return
  try {
    previewPayload.value = await api.apiFetch(`/admin/tenant/line-notifications/templates/${encodeURIComponent(templateForm.event_key)}/preview`, {
      method: 'POST',
      scope: 'tenant',
      body: {},
      successMessage: false,
    })
  } catch (err: any) {
    error.value = err
  }
}

async function loadCustomers() {
  if (!tenantId.value) return
  loadingCustomers.value = true
  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/line-notifications/customers', { scope: 'tenant' })
    linkedCustomers.value = Array.isArray(response.data) ? response.data : []
  } finally {
    loadingCustomers.value = false
  }
}

async function loadDeliveries() {
  if (!tenantId.value) return
  loadingDeliveries.value = true
  try {
    const response: AnyRecord = await api.apiFetch('/admin/tenant/line-notifications/deliveries', {
      scope: 'tenant',
      query: { status: deliveryStatus.value || undefined },
    })
    deliveries.value = Array.isArray(response.data) ? response.data : []
  } finally {
    loadingDeliveries.value = false
  }
}

async function copyVariable(variable: string) {
  if (import.meta.client && navigator.clipboard) {
    await navigator.clipboard.writeText(`{{ ${variable} }}`)
  }
}

function labelForEvent(eventKey: string) {
  return templates.value.find((template) => template.event_key === eventKey)?.label || titleize(eventKey)
}

function placeholderLabel(variable: string) {
  return `{{ ${variable} }}`
}

function lineConnectionSaveError(err: any) {
  const details = err?.code === 'line_encryption_not_configured' || err?.code === 'line_encryption_failed'
    ? null
    : err?.details

  return {
    ...err,
    message: 'เกิดข้อผิดพลาดในการ Verify ข้อมูล LINE กรุณาตรวจสอบข้อมูลแล้วกด Save ใหม่อีกครั้ง',
    details,
  }
}

function lineTestSendError(err: any) {
  return {
    ...err,
    message: 'เกิดข้อผิดพลาดในการส่งข้อความทดสอบ LINE กรุณาตรวจสอบผู้รับและการเชื่อมต่อ LINE OA แล้วลองใหม่อีกครั้ง',
  }
}

const alertType = (err: any) => ([403, 409, 422, 503].includes(Number(err?.status)) ? 'warning' : 'danger')
</script>

<style scoped>
.np-line-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 16px;
}

.np-line-tab {
  border: 1px solid var(--default-border);
  border-radius: 8px;
  background: var(--custom-white);
  color: var(--text-muted);
  padding: 9px 14px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
}

.np-line-tab.active {
  border-color: var(--primary-color);
  color: var(--primary-color);
  background: rgba(var(--primary-rgb), .08);
}

.np-line-bot {
  border: 1px solid var(--default-border);
  border-radius: 8px;
  padding: 14px;
  display: flex;
  align-items: center;
  gap: 12px;
  background: var(--custom-white);
}

.np-line-bot img,
.np-line-avatar {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  object-fit: cover;
}

.np-line-bot-icon {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: #06c755;
  color: #fff;
  font-size: 22px;
}

.np-line-status {
  width: 180px;
}

.np-line-modal {
  z-index: 12010;
}

.np-line-modal-backdrop {
  z-index: 12000;
}

.np-line-guide {
  display: grid;
  gap: 12px;
}

.np-line-guide-step {
  display: grid;
  grid-template-columns: 34px 1fr;
  gap: 12px;
  padding: 12px;
  border: 1px solid var(--default-border);
  border-radius: 8px;
  background: var(--custom-white);
}

.np-line-guide-step h6 {
  margin-bottom: 4px;
  font-weight: 700;
}

.np-line-guide-step p {
  margin-bottom: 0;
  color: var(--text-muted);
}

.np-line-guide-number {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: rgba(6, 199, 85, .12);
  color: #06c755;
  font-weight: 700;
}

.np-line-json {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
}

.np-line-vars {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.np-line-preview {
  border: 1px solid var(--default-border);
  border-radius: 8px;
  padding: 12px;
  background: #f8f9fa;
}

.np-line-preview pre {
  white-space: pre-wrap;
  margin: 0;
  font-size: 12px;
  color: var(--text-muted);
}
</style>

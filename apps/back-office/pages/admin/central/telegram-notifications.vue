<template>
  <div>
    <AdminPageHeader title="Telegram Notifications" :breadcrumbs="['Admin', 'Central', 'Telegram Notifications']">
      <template #actions>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading" @click="loadAll">
          <i class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="error" :type="alertType(error)" :message="error.message" :details="error.details" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <div class="np-telegram-tabs">
      <button v-for="tab in tabs" :key="tab.key" class="np-telegram-tab" :class="{ active: activeTab === tab.key }" type="button" @click="activeTab = tab.key">
        <i :class="tab.icon" />
        <span>{{ tab.label }}</span>
      </button>
    </div>

    <div v-if="activeTab === 'bot'" class="card custom-card">
      <div class="card-header">
        <div>
          <div class="card-title">Bot connection</div>
          <div class="text-muted fs-12">Central bot token is verified by Telegram before saving.</div>
        </div>
        <div class="ms-auto d-flex flex-wrap align-items-center gap-2">
          <button class="btn btn-sm btn-success-light btn-wave" type="button" :disabled="!bot.configured || testingSend" @click="openTestSend">
            <span v-if="testingSend" class="spinner-border spinner-border-sm me-1" />
            <i v-else class="ri-send-plane-line me-1" />
            Test send
          </button>
          <button class="btn btn-sm btn-primary-light btn-wave" type="button" @click="guideModalOpen = true">
            <i class="ri-question-line me-1" />
            วิธีใช้
          </button>
          <AdminStatusBadge :status="bot.status || 'inactive'" :label="titleize(bot.status || 'inactive')" />
        </div>
      </div>
      <div class="card-body">
        <div class="np-telegram-bot">
          <div class="np-telegram-bot-icon"><i class="ri-telegram-line" /></div>
          <div>
            <div class="fw-semibold">{{ bot.bot_first_name || 'No Telegram bot verified yet' }}</div>
            <div class="text-muted fs-12">{{ bot.bot_username ? `@${bot.bot_username}` : 'Add a bot token and save.' }}</div>
          </div>
          <div class="ms-auto text-end">
            <div class="text-muted fs-12">Last sync</div>
            <span>{{ formatDateTime(bot.last_synced_at) || '-' }}</span>
          </div>
        </div>

        <form class="row g-3 mt-2" @submit.prevent="saveBot">
          <div class="col-md-8">
            <label class="form-label">Telegram Bot Token</label>
            <input v-model="botForm.bot_token" class="form-control" type="password" autocomplete="off" :placeholder="bot.bot_token_masked || 'Paste bot token from BotFather'">
          </div>
          <div class="col-md-4">
            <label class="form-label">Status</label>
            <select v-model="botForm.status" class="form-select">
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </select>
          </div>
          <div class="col-12 d-flex flex-wrap justify-content-between gap-2">
            <button v-if="bot.configured" class="btn btn-outline-danger btn-wave" type="button" :disabled="disconnectingBot || savingBot" @click="disconnectBot">
              <span v-if="disconnectingBot" class="spinner-border spinner-border-sm me-2" />
              <i v-else class="ri-link-unlink-m me-1" />
              Disconnect
            </button>
            <div v-else />
            <button class="btn btn-primary btn-wave" type="submit" :disabled="savingBot || disconnectingBot">
              <span v-if="savingBot" class="spinner-border spinner-border-sm me-2" />
              Verify and save
            </button>
          </div>
        </form>
      </div>
    </div>

    <div v-else-if="activeTab === 'chats'" class="card custom-card">
      <div class="card-header">
        <div>
          <div class="card-title">Chat discovery</div>
          <div class="text-muted fs-12">Add the bot to a chat and send /start or /bind, then sync chats here.</div>
        </div>
        <button class="btn btn-primary btn-wave ms-auto" type="button" :disabled="syncingChats || !bot.configured" @click="syncChats">
          <span v-if="syncingChats" class="spinner-border spinner-border-sm me-2" />
          <i v-else class="ri-refresh-line me-1" />
          Sync chats
        </button>
      </div>
      <div class="card-body">
        <AdminDataTable :columns="chatColumns" :rows="chats" :loading="loadingChats" empty-title="No Telegram chats" sortable embedded>
          <template #cell-label="{ row }">
            <div class="fw-semibold">{{ row.label }}</div>
            <div class="text-muted fs-12">{{ row.chat_id }}</div>
          </template>
          <template #cell-chat_type="{ row }">
            <span class="badge bg-info-transparent text-info">{{ row.chat_type || '-' }}</span>
          </template>
        </AdminDataTable>
      </div>
    </div>

    <div v-else-if="activeTab === 'routes'" class="card custom-card">
      <div class="card-header">
        <div>
          <div class="card-title">Tenant event routes</div>
          <div class="text-muted fs-12">Choose which Telegram chat receives each tenant event.</div>
        </div>
        <button class="btn btn-primary btn-wave ms-auto" type="button" :disabled="savingRoutes" @click="saveRoutes">
          <span v-if="savingRoutes" class="spinner-border spinner-border-sm me-2" />
          Save routes
        </button>
      </div>
      <div class="card-body">
        <div class="np-telegram-toolbar">
          <select v-model="routeFilterTenant" class="form-select">
            <option value="">All tenants</option>
            <option v-for="tenant in tenants" :key="tenant.id" :value="tenant.id">{{ tenant.name }}</option>
          </select>
          <select v-model="routeFilterEvent" class="form-select">
            <option value="">All events</option>
            <option v-for="event in events" :key="event.event_key" :value="event.event_key">{{ event.label }}</option>
          </select>
          <select v-model="bulkChatId" class="form-select">
            <option value="">Bulk chat...</option>
            <option v-for="chat in chats" :key="chat.chat_id" :value="chat.chat_id">{{ chat.label }}</option>
          </select>
          <button class="btn btn-light btn-wave" type="button" :disabled="!bulkChatId" @click="bulkAssignChat">Apply visible</button>
        </div>

        <AdminDataTable :columns="routeColumns" :rows="visibleRoutes" :loading="loadingRoutes" empty-title="No routes" sortable embedded>
          <template #cell-tenant_name="{ row }">
            <div class="fw-semibold">{{ row.tenant_name }}</div>
            <div class="text-muted fs-12">{{ row.tenant_code }}</div>
          </template>
          <template #cell-event_label="{ row }">
            <div class="fw-semibold">{{ row.event_label }}</div>
            <div class="text-muted fs-12">{{ row.event_key }}</div>
          </template>
          <template #cell-chat_id="{ row }">
            <select v-model="routeDraft[routeKey(row)].chat_id" class="form-select form-select-sm">
              <option value="">No chat</option>
              <option v-for="chat in chats" :key="chat.chat_id" :value="chat.chat_id">{{ chat.label }}</option>
            </select>
          </template>
          <template #cell-enabled="{ row }">
            <div class="form-check form-switch">
              <input v-model="routeDraft[routeKey(row)].enabled" class="form-check-input" type="checkbox">
            </div>
          </template>
        </AdminDataTable>
      </div>
    </div>

    <div v-else-if="activeTab === 'templates'" class="card custom-card">
      <div class="card-header">
        <div class="card-title">Message templates</div>
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
          <template #rowActions="{ row }">
            <button class="btn btn-sm btn-primary-light btn-wave" type="button" @click="openTemplate(row)">Edit</button>
          </template>
        </AdminDataTable>
      </div>
    </div>

    <div v-else class="card custom-card">
      <div class="card-header">
        <div class="card-title">Delivery logs</div>
        <select v-model="deliveryStatus" class="form-select form-select-sm np-telegram-status ms-auto" @change="loadDeliveries">
          <option value="">All statuses</option>
          <option value="queued">Queued</option>
          <option value="sent">Sent</option>
          <option value="failed">Failed</option>
          <option value="retryable_failed">Retryable failed</option>
        </select>
      </div>
      <div class="card-body">
        <AdminDataTable :columns="deliveryColumns" :rows="deliveries" :loading="loadingDeliveries" empty-title="No delivery logs" sortable embedded>
          <template #cell-event_label="{ row }">
            <div class="fw-semibold">{{ row.event_label || labelForEvent(row.event_key) }}</div>
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

    <div v-if="testModalOpen" class="modal fade show d-block np-telegram-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-md modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">Test Telegram Message</h5>
              <div class="text-muted fs-12">ส่งข้อความทดสอบไปยัง chat ที่ sync แล้ว</div>
            </div>
            <button class="btn-close" type="button" :disabled="testingSend" @click="testModalOpen = false" />
          </div>
          <div class="modal-body">
            <div class="mb-3">
              <label class="form-label">Telegram chat</label>
              <select v-model="telegramTestForm.chat_id" class="form-select">
                <option value="">Select chat...</option>
                <option v-for="chat in chats" :key="chat.chat_id" :value="chat.chat_id">{{ chat.label }} ({{ chat.chat_id }})</option>
              </select>
              <div class="form-text">ถ้าไม่มี chat ให้เพิ่ม bot เข้า group, ส่ง /bind แล้วกด Sync chats ก่อน</div>
            </div>
            <div>
              <label class="form-label">Message</label>
              <textarea v-model="telegramTestForm.message" class="form-control" rows="4" />
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-light btn-wave" type="button" :disabled="testingSend" @click="testModalOpen = false">Cancel</button>
            <button class="btn btn-success btn-wave" type="button" :disabled="testingSend || !telegramTestForm.chat_id" @click="sendTelegramTest">
              <span v-if="testingSend" class="spinner-border spinner-border-sm me-2" />
              Send test
            </button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="guideModalOpen" class="modal fade show d-block np-telegram-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">วิธีติดตั้งและใช้งาน Telegram Bot</h5>
              <div class="text-muted fs-12">ใช้ bot กลางของ Central เพื่อส่งแจ้งเตือน operation ไปยัง chat ของแต่ละ Partner/Tenant</div>
            </div>
            <button class="btn-close" type="button" @click="guideModalOpen = false" />
          </div>
          <div class="modal-body">
            <div class="np-telegram-guide">
              <section class="np-telegram-guide-step">
                <div class="np-telegram-guide-number">1</div>
                <div>
                  <h6>สร้าง Bot จาก BotFather</h6>
                  <p>เปิด Telegram แล้วคุยกับ <code>@BotFather</code> จากนั้นส่ง <code>/newbot</code>, ตั้งชื่อ bot และเก็บ <strong>Bot Token</strong> ที่ได้รับไว้ใช้ในหน้านี้</p>
                </div>
              </section>
              <section class="np-telegram-guide-step">
                <div class="np-telegram-guide-number">2</div>
                <div>
                  <h6>Verify and save token</h6>
                  <p>วาง Bot Token ในช่อง Telegram Bot Token, เลือกสถานะ Active แล้วกด <strong>Verify and save</strong> ระบบจะตรวจสอบ bot กับ Telegram ก่อนบันทึก</p>
                </div>
              </section>
              <section class="np-telegram-guide-step">
                <div class="np-telegram-guide-number">3</div>
                <div>
                  <h6>เพิ่ม bot เข้า Telegram chat หรือ group</h6>
                  <p>เชิญ bot เข้า group ที่ต้องการรับแจ้งเตือน แล้วพิมพ์ <code>/bind</code> หรือ <code>/start</code> ใน group นั้น ถ้าเป็น group ใหญ่ให้ลองใช้ <code>/bind@ชื่อบอท</code></p>
                </div>
              </section>
              <section class="np-telegram-guide-step">
                <div class="np-telegram-guide-number">4</div>
                <div>
                  <h6>Sync chats</h6>
                  <p>กลับมาที่แท็บ Chat Discovery แล้วกด <strong>Sync chats</strong> เพื่อดึง chat ที่ bot เห็นเข้าระบบ ถ้า chat ไม่ขึ้น ให้ส่ง <code>/bind</code> ใน group อีกครั้งแล้ว Sync ใหม่</p>
                </div>
              </section>
              <section class="np-telegram-guide-step">
                <div class="np-telegram-guide-number">5</div>
                <div>
                  <h6>ตั้ง Route ให้แต่ละ Tenant และ Event</h6>
                  <p>ไปที่แท็บ Tenant Routes เลือก Telegram chat ให้ event ที่ต้องการ เปิด Enabled แล้วกด Save routes เช่น topup.submitted, order.paid, reward_claim.submitted และ activity.entry.created</p>
                </div>
              </section>
              <section class="np-telegram-guide-step">
                <div class="np-telegram-guide-number">6</div>
                <div>
                  <h6>แก้ข้อความและตรวจ Delivery Logs</h6>
                  <p>แท็บ Templates ใช้แก้ข้อความและ placeholder เช่น <code>{{ placeholderLabel('tenant.name') }}</code>, <code>{{ placeholderLabel('customer.name') }}</code> ส่วนแท็บ Delivery Logs ใช้ดูสถานะ sent หรือ failed</p>
                </div>
              </section>
            </div>
            <div class="alert alert-info mt-3 mb-0">
              ถ้ายังไม่ได้ตั้ง route ระบบจะข้ามการส่งแบบเงียบและไม่ทำให้รายการหลัก fail ส่วน order.paid จะส่งเป็น summary เท่านั้น ไม่ส่งเลขสลากทั้งหมด
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-primary btn-wave" type="button" @click="guideModalOpen = false">รับทราบ</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="templateModalOpen" class="modal fade show d-block np-telegram-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
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
              <div class="col-md-8">
                <label class="form-label">Title</label>
                <input v-model="templateForm.title" class="form-control">
              </div>
              <div class="col-md-4 d-flex align-items-end">
                <label class="form-check form-switch mb-2">
                  <input v-model="templateForm.enabled" class="form-check-input" type="checkbox">
                  <span class="form-check-label">Enabled</span>
                </label>
              </div>
              <div class="col-12">
                <label class="form-label">HTML message</label>
                <textarea v-model="templateForm.body_text" class="form-control np-telegram-template" rows="12" />
                <div class="form-text">Dynamic values are escaped automatically. Static tags can use Telegram HTML such as &lt;b&gt;.</div>
              </div>
              <div class="col-12">
                <label class="form-label">Variables</label>
                <div class="np-telegram-vars">
                  <button v-for="variable in templateForm.variables" :key="variable" class="btn btn-sm btn-light" type="button" @click="copyVariable(variable)">
                    {{ placeholderLabel(variable) }}
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-light btn-wave" type="button" :disabled="savingTemplate" @click="closeTemplate">Cancel</button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="savingTemplate" @click="saveTemplate">
              <span v-if="savingTemplate" class="spinner-border spinner-border-sm me-2" />
              Save template
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="guideModalOpen || templateModalOpen || testModalOpen" class="modal-backdrop fade show np-telegram-backdrop" />
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, titleize } from '~/utils/format'

definePageMeta({ layout: 'admin' })

type AnyRecord = Record<string, any>

const api = useAdminApi()

const tabs = [
  { key: 'bot', label: 'Bot Connection', icon: 'ri-telegram-line' },
  { key: 'chats', label: 'Chat Discovery', icon: 'ri-chat-3-line' },
  { key: 'routes', label: 'Tenant Routes', icon: 'ri-route-line' },
  { key: 'templates', label: 'Templates', icon: 'ri-file-text-line' },
  { key: 'deliveries', label: 'Delivery Logs', icon: 'ri-history-line' },
]

const activeTab = ref('bot')
const loading = ref(false)
const loadingChats = ref(false)
const loadingRoutes = ref(false)
const loadingDeliveries = ref(false)
const savingBot = ref(false)
const disconnectingBot = ref(false)
const syncingChats = ref(false)
const savingRoutes = ref(false)
const savingTemplate = ref(false)
const testingSend = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const bot = ref<AnyRecord>({})
const events = ref<AnyRecord[]>([])
const chats = ref<AnyRecord[]>([])
const routes = ref<AnyRecord[]>([])
const routeDraft = reactive<Record<string, { tenant_id: string, event_key: string, chat_id: string, enabled: boolean }>>({})
const templates = ref<AnyRecord[]>([])
const deliveries = ref<AnyRecord[]>([])
const deliveryStatus = ref('')
const routeFilterTenant = ref('')
const routeFilterEvent = ref('')
const bulkChatId = ref('')
const templateModalOpen = ref(false)
const guideModalOpen = ref(false)
const testModalOpen = ref(false)

const botForm = reactive({
  bot_token: '',
  status: 'active',
})

const telegramTestForm = reactive({
  chat_id: '',
  message: 'ทดสอบแจ้งเตือน Telegram จาก Siamblend',
})

const templateForm = reactive({
  event_key: '',
  label: '',
  enabled: true,
  title: '',
  body_text: '',
  variables: [] as string[],
})

const chatColumns = [
  { key: 'label', label: 'Chat' },
  { key: 'chat_type', label: 'Type' },
  { key: 'username', label: 'Username' },
  { key: 'last_seen_at', label: 'Last seen', type: 'datetime' },
]
const routeColumns = [
  { key: 'tenant_name', label: 'Tenant' },
  { key: 'event_label', label: 'Event' },
  { key: 'chat_id', label: 'Telegram chat' },
  { key: 'enabled', label: 'Enabled' },
]
const templateColumns = [
  { key: 'label', label: 'Event' },
  { key: 'enabled', label: 'Enabled' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' },
]
const deliveryColumns = [
  { key: 'event_label', label: 'Event' },
  { key: 'tenant_name', label: 'Tenant' },
  { key: 'source_id', label: 'Source' },
  { key: 'status', label: 'Status' },
  { key: 'attempts', label: 'Attempts' },
  { key: 'sent_at', label: 'Sent', type: 'datetime' },
  { key: 'last_error', label: 'Error' },
]

const tenants = computed(() => {
  const map = new Map<string, AnyRecord>()
  routes.value.forEach((row) => map.set(row.tenant_id, { id: row.tenant_id, name: row.tenant_name, code: row.tenant_code }))
  return Array.from(map.values()).sort((a, b) => String(a.name).localeCompare(String(b.name)))
})

const visibleRoutes = computed(() => {
  return routes.value.filter((row) => {
    return (!routeFilterTenant.value || row.tenant_id === routeFilterTenant.value)
      && (!routeFilterEvent.value || row.event_key === routeFilterEvent.value)
  })
})

watch(activeTab, (tab) => {
  if (tab === 'chats') void loadChats()
  if (tab === 'routes') void loadRoutes()
  if (tab === 'deliveries') void loadDeliveries()
})

onMounted(() => {
  void loadAll()
})

async function loadAll() {
  loading.value = true
  error.value = null
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/telegram-notifications/bot', { scope: 'central' })
    bot.value = response.bot || {}
    events.value = Array.isArray(response.events) ? response.events : []
    templates.value = Array.isArray(response.templates) ? response.templates : []
    botForm.status = bot.value.status === 'active' ? 'active' : 'inactive'
    await Promise.all([loadChats(), loadRoutes()])
    if (activeTab.value === 'deliveries') await loadDeliveries()
  } catch (err: any) {
    error.value = err
  } finally {
    loading.value = false
  }
}

async function saveBot() {
  savingBot.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/telegram-notifications/bot', {
      method: 'PUT',
      scope: 'central',
      body: { ...botForm },
      successMessage: false,
    })
    bot.value = response.bot || {}
    events.value = Array.isArray(response.events) ? response.events : events.value
    templates.value = Array.isArray(response.templates) ? response.templates : templates.value
    botForm.bot_token = ''
    botForm.status = bot.value.status === 'active' ? 'active' : 'inactive'
    successMessage.value = 'Telegram bot verified and saved.'
  } catch (err: any) {
    error.value = err
  } finally {
    savingBot.value = false
  }
}

async function disconnectBot() {
  const confirmed = !import.meta.client || window.confirm('Disconnect Telegram bot? Telegram notifications will stop until a bot is verified again.')
  if (!confirmed) return

  disconnectingBot.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/telegram-notifications/bot', {
      method: 'DELETE',
      scope: 'central',
      successMessage: false,
    })
    bot.value = response.bot || {}
    botForm.bot_token = ''
    botForm.status = 'inactive'
    successMessage.value = 'Telegram bot disconnected.'
  } catch (err: any) {
    error.value = err
  } finally {
    disconnectingBot.value = false
  }
}

async function syncChats() {
  syncingChats.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/telegram-notifications/chats/sync', {
      method: 'POST',
      scope: 'central',
      body: {},
      successMessage: false,
    })
    bot.value = response.bot || bot.value
    chats.value = Array.isArray(response.chats) ? response.chats : chats.value
    successMessage.value = `Synced ${response.synced_count || 0} Telegram chat update(s).`
  } catch (err: any) {
    error.value = err
  } finally {
    syncingChats.value = false
  }
}

async function loadChats() {
  loadingChats.value = true
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/telegram-notifications/chats', { scope: 'central' })
    chats.value = Array.isArray(response.data) ? response.data : []
  } finally {
    loadingChats.value = false
  }
}

async function loadRoutes() {
  loadingRoutes.value = true
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/telegram-notifications/routes', { scope: 'central' })
    routes.value = Array.isArray(response.data) ? response.data : []
    events.value = Array.isArray(response.events) ? response.events : events.value
    chats.value = Array.isArray(response.chats) ? response.chats : chats.value
    resetRouteDraft()
  } finally {
    loadingRoutes.value = false
  }
}

async function saveRoutes() {
  savingRoutes.value = true
  error.value = null
  successMessage.value = ''
  try {
    const payload = Object.values(routeDraft)
    const response: AnyRecord = await api.apiFetch('/admin/central/telegram-notifications/routes', {
      method: 'PUT',
      scope: 'central',
      body: { routes: payload },
      successMessage: false,
    })
    routes.value = Array.isArray(response.data) ? response.data : routes.value
    chats.value = Array.isArray(response.chats) ? response.chats : chats.value
    resetRouteDraft()
    successMessage.value = 'Telegram routes saved.'
  } catch (err: any) {
    error.value = err
  } finally {
    savingRoutes.value = false
  }
}

function resetRouteDraft() {
  Object.keys(routeDraft).forEach((key) => delete routeDraft[key])
  routes.value.forEach((row) => {
    routeDraft[routeKey(row)] = {
      tenant_id: row.tenant_id,
      event_key: row.event_key,
      chat_id: row.chat_id || '',
      enabled: Boolean(row.enabled),
    }
  })
}

function bulkAssignChat() {
  visibleRoutes.value.forEach((row) => {
    routeDraft[routeKey(row)].chat_id = bulkChatId.value
    routeDraft[routeKey(row)].enabled = true
  })
}

async function openTestSend() {
  if (chats.value.length === 0) await loadChats()
  telegramTestForm.chat_id = telegramTestForm.chat_id || chats.value[0]?.chat_id || ''
  testModalOpen.value = true
}

async function sendTelegramTest() {
  testingSend.value = true
  error.value = null
  successMessage.value = ''
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/telegram-notifications/test-send', {
      method: 'POST',
      scope: 'central',
      body: { ...telegramTestForm },
      successMessage: false,
    })
    bot.value = response.bot || bot.value
    successMessage.value = 'Telegram test message sent.'
    testModalOpen.value = false
  } catch (err: any) {
    error.value = err
  } finally {
    testingSend.value = false
  }
}

function openTemplate(row: AnyRecord) {
  Object.assign(templateForm, {
    event_key: row.event_key,
    label: row.label,
    enabled: Boolean(row.enabled),
    title: row.title || row.label || '',
    body_text: row.body_text || '',
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
    const saved: AnyRecord = await api.apiFetch(`/admin/central/telegram-notifications/templates/${encodeURIComponent(templateForm.event_key)}`, {
      method: 'PATCH',
      scope: 'central',
      body: {
        enabled: templateForm.enabled,
        title: templateForm.title,
        body_text: templateForm.body_text,
      },
      successMessage: false,
    })
    templates.value = templates.value.map((row) => row.event_key === saved.event_key ? saved : row)
    successMessage.value = 'Telegram template saved.'
    closeTemplate()
  } catch (err: any) {
    error.value = err
  } finally {
    savingTemplate.value = false
  }
}

async function loadDeliveries() {
  loadingDeliveries.value = true
  try {
    const response: AnyRecord = await api.apiFetch('/admin/central/telegram-notifications/deliveries', {
      scope: 'central',
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

function routeKey(row: AnyRecord) {
  return `${row.tenant_id}:${row.event_key}`
}

function labelForEvent(eventKey: string) {
  return templates.value.find((template) => template.event_key === eventKey)?.label || titleize(eventKey)
}

function placeholderLabel(variable: string) {
  return `{{ ${variable} }}`
}

const alertType = (err: any) => ([403, 409, 422, 503].includes(Number(err?.status)) ? 'warning' : 'danger')
</script>

<style scoped>
.np-telegram-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 16px;
}

.np-telegram-tab {
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

.np-telegram-tab.active {
  border-color: var(--primary-color);
  color: var(--primary-color);
  background: rgba(var(--primary-rgb), .08);
}

.np-telegram-bot {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  border: 1px solid var(--default-border);
  border-radius: 8px;
  background: var(--light);
}

.np-telegram-bot-icon {
  width: 44px;
  height: 44px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: rgba(34, 158, 217, .12);
  color: #229ed9;
  font-size: 24px;
}

.np-telegram-toolbar {
  display: grid;
  grid-template-columns: repeat(3, minmax(160px, 1fr)) auto;
  gap: 10px;
  margin-bottom: 14px;
}

.np-telegram-status {
  max-width: 190px;
}

.np-telegram-template {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 13px;
}

.np-telegram-vars {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.np-telegram-guide {
  display: grid;
  gap: 12px;
}

.np-telegram-guide-step {
  display: grid;
  grid-template-columns: 34px 1fr;
  gap: 12px;
  padding: 12px;
  border: 1px solid var(--default-border);
  border-radius: 8px;
  background: var(--custom-white);
}

.np-telegram-guide-step h6 {
  margin-bottom: 4px;
  font-weight: 700;
}

.np-telegram-guide-step p {
  margin-bottom: 0;
  color: var(--text-muted);
}

.np-telegram-guide-number {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: rgba(34, 158, 217, .12);
  color: #229ed9;
  font-weight: 700;
}

.np-telegram-modal {
  z-index: 2060;
}

.np-telegram-backdrop {
  z-index: 2050;
}

@media (max-width: 768px) {
  .np-telegram-toolbar {
    grid-template-columns: 1fr;
  }

  .np-telegram-bot {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>

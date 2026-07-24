<template>
  <div>
    <AdminPageHeader :title="t('Customer Support')" :breadcrumbs="['Admin', 'Tenant', t('Customer Support')]">
      <template #actions>
        <label v-if="canReply" class="np-support-availability">
          <span>{{ t('Available') }}</span>
          <input v-model="available" type="checkbox" class="form-check-input" @change="saveAvailability">
        </label>
        <button class="btn btn-primary-light btn-wave" type="button" :disabled="loading" @click="refreshCurrent">
          <i class="ri-refresh-line me-1" />
          {{ t('Refresh') }}
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="error" type="danger" :message="error.message || t('Support request failed.')" dismissible @dismiss="error = null" />

    <div class="card custom-card np-support-shell">
      <div class="card-header np-support-tabs">
        <button
          v-for="tab in visibleTabs"
          :key="tab.key"
          type="button"
          class="np-support-tab"
          :class="{ active: activeTab === tab.key }"
          @click="selectTab(tab.key)"
        >
          <i :class="tab.icon" />
          <span>{{ t(tab.label) }}</span>
          <span v-if="countFor(tab.key) > 0" class="badge bg-primary-transparent">{{ countFor(tab.key) }}</span>
        </button>
      </div>

      <div
        v-if="ticketTab"
        class="np-support-workspace"
        :class="{ 'has-selection': Boolean(selectedTicket) }"
      >
        <aside class="np-support-list">
          <div v-if="loading" class="p-4 text-center"><span class="spinner-border spinner-border-sm" /></div>
          <button
            v-for="ticket in tickets"
            v-else
            :key="ticket.id"
            type="button"
            class="np-support-ticket"
            :class="{ active: selectedTicket?.id === ticket.id }"
            @click="openTicket(ticket)"
          >
            <div class="d-flex align-items-center gap-2">
              <strong class="text-truncate">{{ ticket.subject }}</strong>
              <span class="badge ms-auto" :class="statusClass(ticket.status)">{{ statusLabel(ticket.status) }}</span>
            </div>
            <div class="text-muted fs-12 mt-1">{{ ticket.public_no }} · {{ ticket.customer?.name || '-' }}</div>
            <div class="text-muted fs-12 text-truncate mt-2">{{ ticket.last_message_preview || t('No message') }}</div>
          </button>
          <div v-if="!loading && tickets.length === 0" class="p-5 text-center text-muted">
            <i class="ri-chat-off-line fs-2 d-block mb-2" />
            {{ t('No support tickets') }}
          </div>
        </aside>

        <main v-if="selectedTicket" class="np-support-chat">
          <header class="np-support-chat-header">
            <button
              class="btn btn-sm btn-icon btn-light np-support-mobile-back"
              type="button"
              :aria-label="t('Back to tickets')"
              @click="closeMobileConversation"
            >
              <i class="ri-arrow-left-line" />
            </button>
            <div class="min-w-0">
              <h6 class="mb-1 text-truncate">{{ selectedTicket.subject }}</h6>
              <div class="text-muted fs-12">{{ selectedTicket.public_no }} · {{ selectedTicket.customer?.name || '-' }}</div>
            </div>
            <div class="ms-auto d-flex align-items-center gap-2">
              <select v-if="canAssign" v-model="assignedActorId" class="form-select form-select-sm np-support-agent-select" @change="assignTicket">
                <option value="">{{ t('Assign agent') }}</option>
                <option v-for="agent in agents" :key="agent.id" :value="agent.id">{{ agent.name }}</option>
              </select>
              <button v-if="selectedTicket.status !== 'closed' && canReply" class="btn btn-sm btn-light" type="button" @click="markWaiting">
                {{ t('Waiting customer') }}
              </button>
              <button v-if="selectedTicket.status !== 'closed' && canClose" class="btn btn-sm btn-danger-light" type="button" @click="closeTicket">
                {{ t('Close ticket') }}
              </button>
            </div>
          </header>

          <div ref="messageViewport" class="np-support-messages">
            <div
              v-for="message in messages"
              :key="message.id"
              class="np-support-message-row"
              :class="`is-${message.sender_type}`"
            >
              <div v-if="message.sender_type === 'system'" class="np-support-system-message">{{ message.body }}</div>
              <template v-else>
                <div v-if="message.sender_type === 'customer'" class="np-support-customer-avatar" aria-hidden="true">
                  <i class="ri-user-3-line" />
                </div>
                <div class="np-support-bubble" :data-sender="message.sender_type">
                  <div v-if="message.sender_type === 'customer'" class="np-support-customer-label">
                    <span>{{ selectedTicket.customer?.name || t('Customer') }}</span>
                  </div>
                  <div v-if="message.body" class="np-support-message-body">{{ message.body }}</div>
                  <div v-for="attachment in message.attachments || []" :key="attachment.id" class="mt-2">
                    <a :href="attachment.url" target="_blank" rel="noopener">
                      <img :src="attachment.url" alt="" class="np-support-message-image">
                    </a>
                  </div>
                  <div class="np-support-message-time">{{ formatDateTime(message.created_at) }}</div>
                </div>
              </template>
            </div>
          </div>

          <form v-if="selectedTicket.status !== 'closed' && canReply" class="np-support-composer" @submit.prevent="sendMessage">
            <label class="btn btn-icon btn-light mb-0">
              <i class="ri-attachment-2" />
              <input class="d-none" type="file" accept="image/jpeg,image/png,image/webp" multiple @change="pickAttachments">
            </label>
            <div class="min-w-0 flex-grow-1">
              <div v-if="attachments.length" class="np-support-attachment-list">
                <div v-for="(file, index) in attachments" :key="`${file.name}-${file.lastModified}`" class="np-support-attachment-name">
                  <span class="text-truncate">{{ file.name }}</span>
                  <button class="btn btn-sm btn-icon btn-light" type="button" @click="removeAttachment(index)"><i class="ri-close-line" /></button>
                </div>
              </div>
              <textarea
                v-model="draft"
                class="form-control"
                rows="2"
                maxlength="4000"
                :placeholder="t('Type a message')"
                @keydown="handleComposerKeydown"
              />
            </div>
            <button class="btn btn-primary btn-icon" type="submit" :disabled="sending || (!draft.trim() && attachments.length === 0)">
              <span v-if="sending" class="spinner-border spinner-border-sm" />
              <i v-else class="ri-send-plane-2-line" />
            </button>
          </form>
          <div v-else-if="selectedTicket.status === 'closed'" class="np-support-closed-note">{{ t('This ticket is closed.') }}</div>
        </main>

        <main v-else class="np-support-no-selection">
          <i class="ri-customer-service-2-line" />
          <div>{{ t('Select a ticket to open the conversation.') }}</div>
        </main>
      </div>

      <div v-else-if="activeTab === 'agents'" class="card-body">
        <div class="d-flex align-items-center justify-content-between mb-3">
          <div>
            <h6 class="mb-1">{{ t('Support agents') }}</h6>
            <div class="text-muted fs-12">{{ t('Availability, capacity, and active workload') }}</div>
          </div>
        </div>
        <div class="table-responsive">
          <table class="table table-hover align-middle">
            <thead><tr><th>{{ t('Agent') }}</th><th>{{ t('Status') }}</th><th>{{ t('Capacity') }}</th><th>{{ t('Active tickets') }}</th><th>{{ t('Last heartbeat') }}</th><th /></tr></thead>
            <tbody>
              <tr v-for="agent in agents" :key="agent.id">
                <td class="fw-semibold">{{ agent.name || agent.external_id }}</td>
                <td><span class="badge" :class="agent.available ? 'bg-success-transparent' : 'bg-light text-muted'">{{ t(agent.available ? 'Available' : 'Offline') }}</span></td>
                <td>
                  <input v-if="canManage" v-model.number="agentCapacities[agent.id]" class="form-control form-control-sm np-support-capacity-input" type="number" min="1" max="20">
                  <span v-else>{{ agent.capacity || bootstrap?.agent_state?.capacity || 3 }}</span>
                </td>
                <td>{{ agent.active_tickets || 0 }}</td>
                <td>{{ formatDateTime(agent.last_heartbeat_at) }}</td>
                <td class="text-end">
                  <button v-if="canManage" class="btn btn-sm btn-primary-light" type="button" :disabled="savingAgentId === agent.id" @click="saveAgentCapacity(agent)">
                    <span v-if="savingAgentId === agent.id" class="spinner-border spinner-border-sm" />
                    <i v-else class="ri-save-line" />
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-else-if="activeTab === 'faq'" class="card-body">
        <div class="row g-4">
          <div class="col-12 col-xl-4">
            <div class="d-flex align-items-center justify-content-between mb-3">
              <h6 class="mb-0">{{ t('FAQ categories') }}</h6>
              <button v-if="canManageFaq" class="btn btn-primary-light btn-sm" type="button" @click="openCategoryEditor()">
                <i class="ri-add-line me-1" />{{ t('Add category') }}
              </button>
            </div>
            <div class="list-group">
              <button
                v-for="category in categories"
                :key="category.id"
                type="button"
                class="list-group-item list-group-item-action d-flex align-items-center gap-2 text-start"
                :disabled="!canManageFaq"
                @click="openCategoryEditor(category)"
              >
                <span class="flex-grow-1">{{ localized(category.name_json) || category.name }}</span>
                <span class="badge" :class="category.status === 'active' ? 'bg-success-transparent' : 'bg-light text-muted'">{{ category.status }}</span>
              </button>
              <div v-if="categories.length === 0" class="list-group-item text-muted text-center py-4">{{ t('No categories') }}</div>
            </div>
          </div>
          <div class="col-12 col-xl-8">
            <div class="d-flex align-items-center justify-content-between mb-3">
              <h6 class="mb-0">{{ t('Frequently asked questions') }}</h6>
              <button v-if="canManageFaq" class="btn btn-primary btn-sm" type="button" @click="openFaqEditor()"><i class="ri-add-line me-1" />{{ t('Add FAQ') }}</button>
            </div>
            <div class="list-group">
              <button v-for="faq in faqs" :key="faq.id" type="button" class="list-group-item list-group-item-action text-start" :disabled="!canManageFaq" @click="openFaqEditor(faq)">
                <div class="d-flex gap-2">
                  <strong class="flex-grow-1">{{ localized(faq.question_json) }}</strong>
                  <span class="badge" :class="faq.status === 'published' ? 'bg-success-transparent' : 'bg-warning-transparent'">{{ faq.status }}</span>
                </div>
                <div class="text-muted fs-12 text-truncate mt-1">{{ localized(faq.answer_json) }}</div>
              </button>
              <div v-if="faqs.length === 0" class="text-muted text-center p-5">{{ t('No FAQ content') }}</div>
            </div>
          </div>
        </div>
      </div>

      <div v-else-if="activeTab === 'settings'" class="card-body">
        <div class="np-support-settings">
          <div>
            <h6 class="mb-1">{{ t('Support settings') }}</h6>
            <div class="text-muted fs-12">{{ t('Configure service availability and workload limits for this tenant.') }}</div>
          </div>
          <label class="form-check form-switch mt-3">
            <input v-model="settingsForm.enabled" class="form-check-input" type="checkbox">
            <span class="form-check-label">{{ t('Enable customer support') }}</span>
          </label>
          <div class="row g-3 mt-1">
            <div class="col-12 col-md-4">
              <label class="form-label">{{ t('Default agent capacity') }}</label>
              <input v-model.number="settingsForm.default_agent_capacity" class="form-control" type="number" min="1" max="20">
            </div>
            <div class="col-12 col-md-4">
              <label class="form-label">{{ t('Attachments per message') }}</label>
              <input v-model.number="settingsForm.max_attachments_per_message" class="form-control" type="number" min="1" max="4">
            </div>
            <div class="col-12 col-md-4">
              <label class="form-label">{{ t('Maximum image size (MB)') }}</label>
              <input v-model.number="settingsForm.max_attachment_mb" class="form-control" type="number" min="1" max="8">
            </div>
          </div>
          <div class="d-flex justify-content-end mt-4">
            <button class="btn btn-primary" type="button" :disabled="savingSettings" @click="saveSettings">
              <span v-if="savingSettings" class="spinner-border spinner-border-sm me-1" />
              <i v-else class="ri-save-line me-1" />
              {{ t('Save support settings') }}
            </button>
          </div>
        </div>
      </div>

      <div v-else-if="activeTab === 'reports'" class="card-body">
        <div class="np-support-report-toolbar">
          <div>
            <h6 class="mb-1">
              {{ t(reportTitle) }}
              <span v-if="reports.actor?.name && reports.scope === 'agent'" class="text-primary">
                · {{ reports.actor.name }}
              </span>
            </h6>
            <div class="text-muted fs-12">
              {{ t(canViewTeamReports ? 'Review the team overview or select an individual agent.' : 'Your report includes only tickets assigned to you.') }}
            </div>
          </div>
          <div class="np-support-report-filters">
            <select v-if="canViewTeamReports" v-model="reportActorId" class="form-select" @change="loadReports">
              <option value="">{{ t('Team overview') }}</option>
              <option v-for="agent in reportAgents" :key="agent.id" :value="agent.id">{{ agent.name }}</option>
            </select>
            <select v-model.number="reportDays" class="form-select" @change="loadReports">
              <option :value="7">{{ t('Last 7 days') }}</option>
              <option :value="30">{{ t('Last 30 days') }}</option>
              <option :value="90">{{ t('Last 90 days') }}</option>
            </select>
          </div>
        </div>
        <div class="row g-3">
          <div v-for="metric in reportMetrics" :key="metric.label" class="col-12 col-md-6 col-xl-3">
            <div class="np-support-metric">
              <div class="text-muted fs-12">{{ t(metric.label) }}</div>
              <strong>{{ metric.value }}</strong>
            </div>
          </div>
        </div>
        <div v-if="canViewTeamReports && !reportActorId" class="np-support-agent-report mt-4">
          <div class="d-flex align-items-center justify-content-between gap-3 mb-3">
            <div>
              <h6 class="mb-1">{{ t('Agent performance') }}</h6>
              <div class="text-muted fs-12">{{ t('Select an agent to open their individual report.') }}</div>
            </div>
          </div>
          <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
              <thead>
                <tr>
                  <th>{{ t('Agent') }}</th>
                  <th>{{ t('Tickets assigned') }}</th>
                  <th>{{ t('Tickets closed') }}</th>
                  <th>{{ t('Average first response (seconds)') }}</th>
                  <th>{{ t('Average rating') }}</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in agentReportRows" :key="row.actor.id">
                  <td class="fw-semibold">{{ row.actor.name }}</td>
                  <td>{{ row.tickets_assigned || 0 }}</td>
                  <td>{{ row.tickets_closed || 0 }}</td>
                  <td>{{ row.average_first_response_seconds || 0 }}</td>
                  <td>{{ Number(row.average_rating || 0).toFixed(2) }}</td>
                  <td class="text-end">
                    <button class="btn btn-sm btn-primary-light" type="button" @click="openAgentReport(row.actor.id)">
                      {{ t('View report') }}
                    </button>
                  </td>
                </tr>
                <tr v-if="agentReportRows.length === 0">
                  <td colspan="6" class="text-center text-muted py-4">{{ t('No agent report data') }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <AdminModal v-model="faqEditorOpen" :title="t(faqForm.id ? 'Edit FAQ' : 'Add FAQ')" size="lg">
      <div class="row g-3">
        <div class="col-md-6">
          <label class="form-label">{{ t('Category') }}</label>
          <select v-model="faqForm.category_id" class="form-select">
            <option value="">{{ t('No category') }}</option>
            <option v-for="category in categories" :key="category.id" :value="category.id">{{ localized(category.name_json) || category.name }}</option>
          </select>
        </div>
        <div class="col-md-6">
          <label class="form-label">{{ t('Status') }}</label>
          <select v-model="faqForm.status" class="form-select">
            <option value="draft">{{ t('Draft') }}</option>
            <option value="published">{{ t('Published') }}</option>
            <option value="archived">{{ t('Archived') }}</option>
          </select>
        </div>
        <div class="col-md-6">
          <label class="form-label">{{ t('Question (Thai)') }}</label>
          <input v-model="faqForm.question_th" class="form-control" maxlength="500">
        </div>
        <div class="col-md-6">
          <label class="form-label">{{ t('Question (English)') }}</label>
          <input v-model="faqForm.question_en" class="form-control" maxlength="500">
        </div>
        <div class="col-md-6">
          <label class="form-label">{{ t('Answer (Thai)') }}</label>
          <textarea v-model="faqForm.answer_th" class="form-control" rows="6" />
        </div>
        <div class="col-md-6">
          <label class="form-label">{{ t('Answer (English)') }}</label>
          <textarea v-model="faqForm.answer_en" class="form-control" rows="6" />
        </div>
      </div>
      <template #footer>
        <button class="btn btn-light" type="button" @click="faqEditorOpen = false">{{ t('Cancel') }}</button>
        <button class="btn btn-primary" type="button" :disabled="savingFaq || !faqForm.question_th.trim() || !faqForm.answer_th.trim()" @click="saveFaq">
          <span v-if="savingFaq" class="spinner-border spinner-border-sm me-1" />
          {{ t('Save FAQ') }}
        </button>
      </template>
    </AdminModal>

    <AdminModal v-model="categoryEditorOpen" :title="t(categoryForm.id ? 'Edit category' : 'Add category')">
      <div class="row g-3">
        <div class="col-12">
          <label class="form-label">{{ t('Category code') }}</label>
          <input v-model="categoryForm.code" class="form-control" maxlength="80" :disabled="Boolean(categoryForm.id)">
        </div>
        <div class="col-md-6">
          <label class="form-label">{{ t('Name (Thai)') }}</label>
          <input v-model="categoryForm.name_th" class="form-control" maxlength="200">
        </div>
        <div class="col-md-6">
          <label class="form-label">{{ t('Name (English)') }}</label>
          <input v-model="categoryForm.name_en" class="form-control" maxlength="200">
        </div>
        <div class="col-md-6">
          <label class="form-label">{{ t('Status') }}</label>
          <select v-model="categoryForm.status" class="form-select">
            <option value="active">{{ t('Active') }}</option>
            <option value="inactive">{{ t('Inactive') }}</option>
          </select>
        </div>
        <div class="col-md-6">
          <label class="form-label">{{ t('Sort order') }}</label>
          <input v-model.number="categoryForm.sort_order" class="form-control" type="number" min="0">
        </div>
        <div class="col-12">
          <label class="form-check">
            <input v-model="categoryForm.is_fallback" class="form-check-input" type="checkbox">
            <span class="form-check-label">{{ t('Use as Other category') }}</span>
          </label>
        </div>
      </div>
      <template #footer>
        <button class="btn btn-light" type="button" @click="categoryEditorOpen = false">{{ t('Cancel') }}</button>
        <button
          class="btn btn-primary"
          type="button"
          :disabled="savingCategory || !categoryForm.code.trim() || !categoryForm.name_th.trim()"
          @click="saveCategory"
        >
          <span v-if="savingCategory" class="spinner-border spinner-border-sm me-1" />
          {{ t('Save category') }}
        </button>
      </template>
    </AdminModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

type AnyRecord = Record<string, any>
type TabKey = 'mine' | 'queue' | 'all' | 'closed' | 'agents' | 'faq' | 'settings' | 'reports'

const { phrase: t, locale } = useAdminLocale()
const support = useSupportApi()
const activeTab = ref<TabKey>('mine')
const bootstrap = ref<AnyRecord | null>(null)
const tickets = ref<AnyRecord[]>([])
const selectedTicket = ref<AnyRecord | null>(null)
const messages = ref<AnyRecord[]>([])
const agents = ref<AnyRecord[]>([])
const agentCapacities = reactive<Record<string, number>>({})
const categories = ref<AnyRecord[]>([])
const faqs = ref<AnyRecord[]>([])
const reports = ref<AnyRecord>({})
const reportDays = ref(30)
const reportActorId = ref('')
const supportRealtimeConfig = ref<AnyRecord | null>(null)
const available = ref(false)
const assignedActorId = ref('')
const draft = ref('')
const attachments = ref<File[]>([])
const sendIdempotencyKey = ref('')
const loading = ref(false)
const sending = ref(false)
const savingAgentId = ref('')
const error = ref<any>(null)
const messageViewport = ref<HTMLElement | null>(null)
const faqEditorOpen = ref(false)
const savingFaq = ref(false)
const categoryEditorOpen = ref(false)
const savingCategory = ref(false)
const savingSettings = ref(false)
const faqForm = reactive({
  id: '',
  category_id: '',
  status: 'draft',
  question_th: '',
  question_en: '',
  answer_th: '',
  answer_en: '',
})
const categoryForm = reactive({
  id: '',
  code: '',
  name_th: '',
  name_en: '',
  status: 'active',
  sort_order: 0,
  is_fallback: false,
})
const settingsForm = reactive({
  enabled: true,
  default_agent_capacity: 3,
  max_attachments_per_message: 4,
  max_attachment_mb: 8,
  content_json: null as AnyRecord | null,
})

let pollTimer: ReturnType<typeof setInterval> | null = null
let heartbeatTimer: ReturnType<typeof setInterval> | null = null

const permissions = computed<string[]>(() => bootstrap.value?.permissions || [])
const hasPermission = (code: string) => permissions.value.includes(code)
const canReply = computed(() => hasPermission('support_ticket.reply_assigned'))
const canClose = computed(() => hasPermission('support_ticket.close_assigned'))
const canAssign = computed(() => hasPermission('support_ticket.assign'))
const canManage = computed(() => hasPermission('support_agent.manage'))
const canManageFaq = computed(() => hasPermission('support_faq.manage'))
const canReport = computed(() => (
  hasPermission('support_report.view')
  || hasPermission('support_ticket.view_assigned')
))
const canViewTeamReports = computed(() => Boolean(reports.value.can_view_team))
const reportAgents = computed<AnyRecord[]>(() => Array.isArray(reports.value.agents) ? reports.value.agents : [])
const agentReportRows = computed<AnyRecord[]>(() => Array.isArray(reports.value.agent_reports) ? reports.value.agent_reports : [])
const reportTitle = computed(() => {
  if (!canViewTeamReports.value) return 'My performance'
  return reportActorId.value ? 'Individual agent report' : 'Team overview'
})
const ticketTab = computed(() => ['mine', 'queue', 'all', 'closed'].includes(activeTab.value))
const maxAttachments = computed(() => Math.min(4, Math.max(1, Number(
  bootstrap.value?.limits?.attachments_per_message || 4,
))))
const maxAttachmentBytes = computed(() => Math.min(8_388_608, Math.max(1024, Number(
  bootstrap.value?.limits?.attachment_bytes || 8_388_608,
))))
const supportChannelName = computed(() => {
  const prefix = String(supportRealtimeConfig.value?.channel_prefix || '').trim()
  if (selectedTicket.value?.id && prefix) {
    return `${prefix}.ticket.${selectedTicket.value.id}`
  }
  const channels = Array.isArray(supportRealtimeConfig.value?.channels)
    ? supportRealtimeConfig.value.channels.map((channel: any) => String(channel))
    : []
  return channels.find((channel: string) => channel.endsWith('.queue')) || channels[0] || ''
})
const supportRealtime = useAdminRealtimeSubscription({
  channelName: supportChannelName,
  connection: computed(() => supportRealtimeConfig.value
    ? {
        url: supportRealtimeConfig.value.url,
        key: supportRealtimeConfig.value.key,
        client: 'newpaotang-support-bo',
      }
    : null),
  enabled: computed(() => Boolean(supportChannelName.value)),
  eventName: [
    'support.ticket.created',
    'support.ticket.assigned',
    'support.ticket.waiting_customer',
    'support.ticket.closed',
    'support.message.created',
  ],
  authorize: (socketId, channelName) => support.supportFetch('/admin/realtime/auth', {
    method: 'POST',
    body: { socket_id: socketId, channel_name: channelName },
  }),
  onEvent: () => {
    void loadBootstrap()
    if (selectedTicket.value) void refreshMessages()
    else if (ticketTab.value) void loadTickets()
  },
  onReconnect: () => {
    if (selectedTicket.value) void refreshMessages()
    else if (ticketTab.value) void loadTickets()
  },
})

const allTabs: Array<{ key: TabKey, label: string, icon: string, visible: () => boolean }> = [
  { key: 'mine', label: 'My Tickets', icon: 'ri-chat-1-line', visible: () => true },
  { key: 'queue', label: 'Queue', icon: 'ri-timer-line', visible: () => hasPermission('support_ticket.view_all') },
  { key: 'all', label: 'All', icon: 'ri-inbox-archive-line', visible: () => hasPermission('support_ticket.view_all') },
  { key: 'closed', label: 'Closed', icon: 'ri-checkbox-circle-line', visible: () => hasPermission('support_ticket.view_all') },
  { key: 'agents', label: 'Agents', icon: 'ri-team-line', visible: () => canManage.value },
  { key: 'faq', label: 'FAQ', icon: 'ri-question-answer-line', visible: () => hasPermission('support_faq.view') || canManageFaq.value },
  { key: 'settings', label: 'Settings', icon: 'ri-settings-3-line', visible: () => canManage.value },
  { key: 'reports', label: 'Reports', icon: 'ri-bar-chart-box-line', visible: () => canReport.value },
]
const visibleTabs = computed(() => allTabs.filter(tab => tab.visible()))

const reportMetrics = computed(() => [
  {
    label: reports.value.scope === 'overview' ? 'Tickets opened' : 'Tickets assigned',
    value: reports.value.scope === 'overview'
      ? reports.value.tickets_opened || 0
      : reports.value.tickets_assigned || 0,
  },
  { label: 'Tickets closed', value: reports.value.tickets_closed || 0 },
  { label: 'Average first response (seconds)', value: reports.value.average_first_response_seconds || 0 },
  { label: 'Average rating', value: Number(reports.value.average_rating || 0).toFixed(2) },
])

const countFor = (key: TabKey) => {
  const counts = bootstrap.value?.counts || {}
  return key === 'mine' ? counts.mine || 0 : key === 'queue' ? counts.queue || 0 : key === 'all' ? counts.all_open || 0 : key === 'closed' ? counts.closed || 0 : 0
}

const loadBootstrap = async () => {
  bootstrap.value = await support.supportFetch('/admin/bootstrap')
  supportRealtimeConfig.value = (await support.getSession()).realtime || null
  available.value = Boolean(bootstrap.value?.agent_state?.available)
}

const loadTickets = async () => {
  const response: AnyRecord = await support.supportFetch('/admin/tickets', { query: { view: activeTab.value, limit: 80 } })
  tickets.value = Array.isArray(response.data) ? response.data : []
  if (selectedTicket.value) {
    const fresh = tickets.value.find(ticket => ticket.id === selectedTicket.value?.id)
    if (fresh) selectedTicket.value = fresh
  }
}

const loadAgents = async () => {
  if (!canManage.value && !canAssign.value) return
  const response: AnyRecord = await support.supportFetch('/admin/agents')
  agents.value = Array.isArray(response.data) ? response.data : []
  for (const agent of agents.value) {
    agentCapacities[agent.id] = Number(agent.capacity || bootstrap.value?.agent_state?.capacity || 3)
  }
}

const saveAgentCapacity = async (agent: AnyRecord) => {
  if (!canManage.value || savingAgentId.value) return
  savingAgentId.value = agent.id
  try {
    await support.supportFetch(`/admin/agents/${agent.id}/state`, {
      method: 'PUT',
      body: { capacity: agentCapacities[agent.id] },
      idempotencyKey: support.idempotencyKey(),
    })
    await loadAgents()
  } catch (err) {
    error.value = err
  } finally {
    savingAgentId.value = ''
  }
}

const loadFaq = async () => {
  const [categoryResponse, faqResponse]: AnyRecord[] = await Promise.all([
    support.supportFetch('/admin/categories'),
    support.supportFetch('/admin/faqs'),
  ])
  categories.value = Array.isArray(categoryResponse.data) ? categoryResponse.data : []
  faqs.value = Array.isArray(faqResponse.data) ? faqResponse.data : []
}

const loadReports = async () => {
  const response: AnyRecord = await support.supportFetch('/admin/reports', {
    query: {
      days: reportDays.value,
      ...(reportActorId.value ? { actor_id: reportActorId.value } : {}),
    },
  })
  reports.value = response
  if (!response.can_view_team) reportActorId.value = ''
}

const openAgentReport = async (actorId: string) => {
  reportActorId.value = actorId
  await loadReports()
}

const loadSettings = async () => {
  const response: AnyRecord = await support.supportFetch('/admin/settings')
  const value = response.settings || {}
  settingsForm.enabled = value.enabled !== false
  settingsForm.default_agent_capacity = Number(value.default_agent_capacity || 3)
  settingsForm.max_attachments_per_message = Number(value.max_attachments_per_message || 4)
  settingsForm.max_attachment_mb = Math.max(1, Math.round(Number(value.max_attachment_bytes || 8_388_608) / 1_048_576))
  settingsForm.content_json = value.content_json || null
}

const refreshCurrent = async () => {
  loading.value = true
  error.value = null
  try {
    await loadBootstrap()
    if (ticketTab.value) await loadTickets()
    else if (activeTab.value === 'agents') await loadAgents()
    else if (activeTab.value === 'faq') await loadFaq()
    else if (activeTab.value === 'settings') await loadSettings()
    else if (activeTab.value === 'reports') await loadReports()
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const selectTab = async (tab: TabKey) => {
  activeTab.value = tab
  selectedTicket.value = null
  messages.value = []
  await refreshCurrent()
}

const openTicket = async (ticket: AnyRecord) => {
  if (selectedTicket.value?.id !== ticket.id) {
    draft.value = ''
    attachments.value = []
    sendIdempotencyKey.value = ''
  }
  selectedTicket.value = ticket
  assignedActorId.value = ticket.agent?.id || ''
  await refreshMessages()
}

const closeMobileConversation = () => {
  selectedTicket.value = null
  messages.value = []
  draft.value = ''
  attachments.value = []
  sendIdempotencyKey.value = ''
}

const refreshMessages = async () => {
  if (!selectedTicket.value) return
  try {
    const [detail, messagePage]: AnyRecord[] = await Promise.all([
      support.supportFetch(`/admin/tickets/${selectedTicket.value.id}`),
      support.supportFetch(`/admin/tickets/${selectedTicket.value.id}/messages`, { query: { limit: 100 } }),
    ])
    selectedTicket.value = detail.ticket
    messages.value = Array.isArray(messagePage.data) ? messagePage.data : []
    const last = messages.value.at(-1)
    if (last) {
      await support.supportFetch(`/admin/tickets/${selectedTicket.value.id}/read`, {
        method: 'POST',
        body: { sequence: last.sequence },
      })
    }
    await nextTick()
    if (messageViewport.value) messageViewport.value.scrollTop = messageViewport.value.scrollHeight
  } catch (err) {
    error.value = err
  }
}

const sendMessage = async () => {
  if (!selectedTicket.value || sending.value || (!draft.value.trim() && attachments.value.length === 0)) return
  sending.value = true
  try {
    const body = new FormData()
    if (draft.value.trim()) body.append('body', draft.value.trim())
    for (const file of attachments.value) body.append('attachments[]', file)
    sendIdempotencyKey.value ||= support.idempotencyKey()
    await support.supportFetch(`/admin/tickets/${selectedTicket.value.id}/messages`, {
      method: 'POST',
      body,
      idempotencyKey: sendIdempotencyKey.value,
    })
    draft.value = ''
    attachments.value = []
    sendIdempotencyKey.value = ''
    await refreshMessages()
    await loadBootstrap()
  } catch (err) {
    error.value = err
  } finally {
    sending.value = false
  }
}

const handleComposerKeydown = (event: KeyboardEvent) => {
  if (
    event.key !== 'Enter'
    || event.shiftKey
    || event.ctrlKey
    || event.altKey
    || event.metaKey
    || event.isComposing
  ) {
    return
  }

  event.preventDefault()
  void sendMessage()
}

const markWaiting = async () => {
  if (!selectedTicket.value) return
  await support.supportFetch(`/admin/tickets/${selectedTicket.value.id}/waiting-customer`, {
    method: 'POST',
    body: {},
  })
  await refreshMessages()
}

const closeTicket = async () => {
  if (!selectedTicket.value || !window.confirm(t('Close this ticket?'))) return
  await support.supportFetch(`/admin/tickets/${selectedTicket.value.id}/close`, {
    method: 'POST',
    body: {},
    idempotencyKey: support.idempotencyKey(),
  })
  await refreshMessages()
  await loadBootstrap()
}

const assignTicket = async () => {
  if (!selectedTicket.value || !assignedActorId.value) return
  await support.supportFetch(`/admin/tickets/${selectedTicket.value.id}/assign`, {
    method: 'POST',
    body: { admin_actor_id: assignedActorId.value },
    idempotencyKey: support.idempotencyKey(),
  })
  await refreshMessages()
}

const saveAvailability = async () => {
  try {
    await support.supportFetch('/admin/agent-state', {
      method: 'PUT',
      body: {
        available: available.value,
        capacity: bootstrap.value?.agent_state?.capacity || 3,
      },
    })
    startHeartbeat()
    await loadBootstrap()
  } catch (err) {
    available.value = !available.value
    error.value = err
  }
}

const startHeartbeat = () => {
  if (heartbeatTimer) clearInterval(heartbeatTimer)
  if (!available.value) return
  heartbeatTimer = setInterval(() => {
    void support.supportFetch('/admin/agent-state/heartbeat', { method: 'POST', body: {} }).catch(() => {})
  }, 45_000)
}

const pickAttachments = (event: Event) => {
  const input = event.target as HTMLInputElement
  const selected = Array.from(input.files || [])
  const remaining = Math.max(0, maxAttachments.value - attachments.value.length)
  const accepted = selected
    .filter(file => file.size <= maxAttachmentBytes.value)
    .slice(0, remaining)
  attachments.value = [...attachments.value, ...accepted]
  if (accepted.length > 0) sendIdempotencyKey.value = ''
  if (accepted.length < selected.length) {
    error.value = {
      message: t('Some images exceed the tenant attachment limit or the maximum file count.'),
    }
  }
  input.value = ''
}

const removeAttachment = (index: number) => {
  attachments.value = attachments.value.filter((_, itemIndex) => itemIndex !== index)
  sendIdempotencyKey.value = ''
}

watch(draft, () => {
  if (!sending.value) sendIdempotencyKey.value = ''
})

const openFaqEditor = (faq: AnyRecord | null = null) => {
  faqForm.id = faq?.id || ''
  faqForm.category_id = faq?.category_id || ''
  faqForm.status = faq?.status || 'draft'
  faqForm.question_th = faq?.question_json?.['th-TH'] || ''
  faqForm.question_en = faq?.question_json?.['en-US'] || ''
  faqForm.answer_th = faq?.answer_json?.['th-TH'] || ''
  faqForm.answer_en = faq?.answer_json?.['en-US'] || ''
  faqEditorOpen.value = true
}

const saveFaq = async () => {
  savingFaq.value = true
  try {
    await support.supportFetch(faqForm.id ? `/admin/faqs/${faqForm.id}` : '/admin/faqs', {
      method: faqForm.id ? 'PUT' : 'POST',
      body: {
        category_id: faqForm.category_id || null,
        status: faqForm.status,
        sort_order: 0,
        question_json: { 'th-TH': faqForm.question_th, 'en-US': faqForm.question_en },
        answer_json: { 'th-TH': faqForm.answer_th, 'en-US': faqForm.answer_en },
      },
      idempotencyKey: support.idempotencyKey(),
    })
    faqEditorOpen.value = false
    await loadFaq()
  } catch (err) {
    error.value = err
  } finally {
    savingFaq.value = false
  }
}

const openCategoryEditor = (category: AnyRecord | null = null) => {
  categoryForm.id = category?.id || ''
  categoryForm.code = category?.code || ''
  categoryForm.name_th = category?.name_json?.['th-TH'] || ''
  categoryForm.name_en = category?.name_json?.['en-US'] || ''
  categoryForm.status = category?.status || 'active'
  categoryForm.sort_order = Number(category?.sort_order || 0)
  categoryForm.is_fallback = Boolean(category?.is_fallback)
  categoryEditorOpen.value = true
}

const saveCategory = async () => {
  savingCategory.value = true
  try {
    await support.supportFetch(categoryForm.id ? `/admin/categories/${categoryForm.id}` : '/admin/categories', {
      method: categoryForm.id ? 'PUT' : 'POST',
      body: {
        code: categoryForm.code.trim(),
        name_json: { 'th-TH': categoryForm.name_th.trim(), 'en-US': categoryForm.name_en.trim() },
        status: categoryForm.status,
        sort_order: categoryForm.sort_order,
        is_fallback: categoryForm.is_fallback,
      },
      idempotencyKey: support.idempotencyKey(),
    })
    categoryEditorOpen.value = false
    await loadFaq()
  } catch (err) {
    error.value = err
  } finally {
    savingCategory.value = false
  }
}

const saveSettings = async () => {
  savingSettings.value = true
  try {
    await support.supportFetch('/admin/settings', {
      method: 'PUT',
      body: {
        enabled: settingsForm.enabled,
        default_agent_capacity: settingsForm.default_agent_capacity,
        max_attachments_per_message: settingsForm.max_attachments_per_message,
        max_attachment_bytes: settingsForm.max_attachment_mb * 1_048_576,
        content_json: settingsForm.content_json,
      },
      idempotencyKey: support.idempotencyKey(),
    })
    await Promise.all([loadSettings(), loadBootstrap()])
  } catch (err) {
    error.value = err
  } finally {
    savingSettings.value = false
  }
}

const localized = (value: AnyRecord | null | undefined) => value?.[locale.value] || value?.['th-TH'] || value?.['en-US'] || ''
const statusLabel = (status: string) => t({
  queued: 'Queued',
  assigned: 'Assigned',
  in_progress: 'In progress',
  waiting_customer: 'Waiting customer',
  closed: 'Closed',
}[status] || status)
const statusClass = (status: string) => status === 'closed' ? 'bg-light text-muted' : status === 'waiting_customer' ? 'bg-warning-transparent' : status === 'queued' ? 'bg-primary-transparent' : 'bg-success-transparent'
const formatDateTime = (value: string | null | undefined) => value ? new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) : '-'

onMounted(async () => {
  await refreshCurrent()
  if (canAssign.value || canManage.value) await loadAgents()
  startHeartbeat()
  pollTimer = setInterval(() => {
    if (document.visibilityState !== 'visible') return
    if (supportRealtime.status.value === 'connected') return
    if (selectedTicket.value) void refreshMessages()
    else if (ticketTab.value) void loadTickets()
  }, 8_000)
})

onBeforeUnmount(() => {
  if (pollTimer) clearInterval(pollTimer)
  if (heartbeatTimer) clearInterval(heartbeatTimer)
})
</script>

<style scoped>
.np-support-shell { min-height: calc(100vh - 165px); }
.np-support-tabs { display: flex; gap: .35rem; overflow-x: auto; padding: .75rem; }
.np-support-tab { display: inline-flex; align-items: center; gap: .45rem; border: 0; border-radius: 6px; background: transparent; color: var(--default-text-color); padding: .65rem .85rem; white-space: nowrap; }
.np-support-tab.active { color: var(--primary-color); background: rgba(var(--primary-rgb), .1); font-weight: 600; }
.np-support-availability { display: inline-flex; align-items: center; gap: .55rem; margin: 0; }
.np-support-workspace { display: grid; grid-template-columns: minmax(260px, 34%) 1fr; min-height: 680px; border-top: 1px solid var(--default-border); }
.np-support-list { border-right: 1px solid var(--default-border); overflow-y: auto; max-height: calc(100vh - 230px); }
.np-support-ticket { width: 100%; border: 0; border-bottom: 1px solid var(--default-border); background: transparent; padding: 1rem; text-align: left; }
.np-support-ticket:hover, .np-support-ticket.active { background: rgba(var(--primary-rgb), .06); }
.np-support-chat { min-width: 0; display: grid; grid-template-rows: auto minmax(0, 1fr) auto; height: calc(100vh - 230px); min-height: 680px; }
.np-support-chat-header { display: flex; align-items: center; gap: 1rem; padding: .9rem 1rem; border-bottom: 1px solid var(--default-border); }
.np-support-mobile-back { display: none; flex: 0 0 auto; }
.np-support-agent-select { width: 180px; }
.np-support-capacity-input { width: 84px; }
.np-support-messages { overflow-y: auto; padding: 1.1rem; background: rgba(var(--primary-rgb), .028); }
.np-support-message-row { display: flex; align-items: flex-end; gap: .55rem; margin-bottom: .85rem; }
.np-support-message-row.is-admin { justify-content: flex-end; }
.np-support-message-row.is-system { justify-content: center; }
.np-support-bubble { max-width: min(72%, 560px); border: 1px solid var(--default-border); border-radius: 8px; padding: .7rem .85rem; background: var(--custom-white); box-shadow: 0 2px 8px rgba(15, 23, 42, .06); }
.np-support-message-row.is-customer .np-support-bubble {
  border: 2px solid rgba(var(--primary-rgb), .5);
  border-inline-start: 4px solid var(--primary-color);
  background: var(--custom-white);
  color: var(--default-text-color);
  box-shadow: 0 4px 12px rgba(var(--primary-rgb), .1);
}
.np-support-message-row.is-admin .np-support-bubble { border-color: var(--primary-color); background: var(--primary-color); color: #fff; }
.np-support-customer-avatar { display: grid; flex: 0 0 30px; width: 30px; height: 30px; place-items: center; border: 1px solid rgba(var(--primary-rgb), .28); border-radius: 50%; background: rgba(var(--primary-rgb), .1); color: var(--primary-color); }
.np-support-customer-label { display: flex; align-items: center; gap: .35rem; margin-bottom: .35rem; color: var(--primary-color); font-size: .7rem; font-weight: 600; }
.np-support-message-body { line-height: 1.55; overflow-wrap: anywhere; white-space: pre-wrap; }
.np-support-system-message { color: var(--text-muted); font-size: .75rem; text-align: center; }
.np-support-message-time { margin-top: .35rem; opacity: .72; font-size: .68rem; }
.np-support-message-image { display: block; width: min(260px, 100%); max-height: 220px; object-fit: cover; border-radius: 6px; }
.np-support-composer { display: flex; align-items: flex-end; gap: .65rem; padding: .8rem; border-top: 1px solid var(--default-border); }
.np-support-attachment-name { display: flex; align-items: center; gap: .5rem; margin-bottom: .4rem; padding: .35rem .5rem; background: var(--light); border-radius: 5px; }
.np-support-attachment-list { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: .35rem; margin-bottom: .45rem; }
.np-support-attachment-list .np-support-attachment-name { margin-bottom: 0; }
.np-support-closed-note { padding: 1rem; text-align: center; color: var(--text-muted); border-top: 1px solid var(--default-border); }
.np-support-no-selection { display: grid; place-content: center; gap: .75rem; color: var(--text-muted); text-align: center; }
.np-support-no-selection i { font-size: 3rem; color: var(--primary-color); }
.np-support-metric { height: 100%; border: 1px solid var(--default-border); border-radius: 6px; padding: 1rem; }
.np-support-metric strong { display: block; margin-top: .35rem; font-size: 1.6rem; }
.np-support-report-toolbar { display: flex; align-items: flex-end; justify-content: space-between; gap: 1rem; margin-bottom: 1rem; }
.np-support-report-filters { display: flex; gap: .65rem; }
.np-support-report-filters .form-select { min-width: 170px; }
.np-support-agent-report { border-top: 1px solid var(--default-border); padding-top: 1.25rem; }
.np-support-settings { max-width: 860px; }
@media (max-width: 991.98px) {
  .np-support-workspace { grid-template-columns: 1fr; }
  .np-support-list { max-height: none; border-right: 0; }
  .np-support-workspace.has-selection .np-support-list,
  .np-support-workspace.has-selection .np-support-no-selection { display: none; }
  .np-support-chat { min-height: 620px; height: calc(100vh - 230px); border-top: 1px solid var(--default-border); }
  .np-support-mobile-back { display: inline-flex; }
  .np-support-chat-header { align-items: flex-start; flex-wrap: wrap; }
  .np-support-chat-header .ms-auto { width: 100%; margin-left: 0 !important; flex-wrap: wrap; }
  .np-support-agent-select { width: min(100%, 220px); }
  .np-support-report-toolbar { align-items: stretch; flex-direction: column; }
  .np-support-report-filters { flex-wrap: wrap; }
  .np-support-report-filters .form-select { min-width: min(100%, 220px); flex: 1 1 180px; }
  .np-support-bubble { max-width: 88%; }
}
</style>

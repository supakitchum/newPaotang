<template>
  <div class="np-tier-campaign-page">
    <AdminPageHeader
      :title="tr('Affiliate Tier Campaigns', 'แคมเปญระดับผู้แนะนำ')"
      :breadcrumbs="[tr('Admin', 'ผู้ดูแลระบบ'), tr('Tenant', 'ร้านค้า'), tr('Affiliate Tier Campaigns', 'แคมเปญระดับผู้แนะนำ')]"
    >
      <template #actions>
        <button class="btn btn-light btn-wave" type="button" :disabled="loading || !tenantId" @click="loadAll">
          <i class="ri-refresh-line me-1" />
          {{ tr('Refresh', 'รีเฟรช') }}
        </button>
        <button class="btn btn-primary btn-wave" type="button" :disabled="!tenantId" @click="openCreateModal">
          <i class="ri-add-line me-1" />
          {{ tr('New campaign', 'สร้างแคมเปญ') }}
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert
      v-if="!tenantId"
      type="warning"
      :message="tr('Select a tenant scope before managing affiliate tier campaigns.', 'กรุณาเลือกร้านค้าก่อนจัดการแคมเปญระดับผู้แนะนำ')"
    />
    <AdminAlert v-if="error" type="danger" :message="error.message || tr('The operation failed.', 'ทำรายการไม่สำเร็จ')" :details="error.details" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />

    <section class="np-tier-hero mb-4">
      <div>
        <span class="np-tier-hero-kicker">AFFILIATE GROWTH</span>
        <h2>{{ tr('Tier campaign workspace', 'ศูนย์จัดการแคมเปญระดับผู้แนะนำ') }}</h2>
        <p>{{ tr('Create campaign rules, follow participation, and finalize tier results from one screen.', 'สร้างกติกา ติดตามผู้เข้าร่วม และสรุปผลระดับได้จากหน้าจอเดียว') }}</p>
      </div>
      <div class="np-tier-hero-mark" aria-hidden="true">
        <i class="ri-award-line" />
      </div>
    </section>

    <div class="row g-3 mb-4">
      <div v-for="metric in metrics" :key="metric.key" class="col-6 col-xl-3">
        <div class="card custom-card np-tier-metric-card h-100">
          <div class="card-body">
            <div class="np-tier-metric-icon" :class="metric.className">
              <i :class="metric.icon" />
            </div>
            <div>
              <div class="text-muted fs-12">{{ metric.label }}</div>
              <div class="fs-24 fw-bold lh-1 mt-2">{{ metric.value }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="card custom-card mb-4">
      <div class="card-header np-tier-list-header">
        <div>
          <div class="card-title mb-1">{{ tr('Campaign overview', 'ภาพรวมแคมเปญ') }}</div>
          <p class="text-muted fs-12 mb-0">{{ tr('Select a campaign to inspect its rules and live ranking.', 'เลือกแคมเปญเพื่อดูกติกาและอันดับล่าสุด') }}</p>
        </div>
        <div class="np-tier-filters">
          <div class="input-group input-group-sm np-tier-search">
            <span class="input-group-text"><i class="ri-search-line" /></span>
            <input v-model="filters.q" class="form-control" :placeholder="tr('Search campaign', 'ค้นหาแคมเปญ')">
          </div>
          <select v-model="filters.type" class="form-select form-select-sm">
            <option value="">{{ tr('All campaign types', 'ทุกประเภทแคมเปญ') }}</option>
            <option value="fixed_threshold">{{ campaignTypeLabel('fixed_threshold') }}</option>
            <option value="ranking">{{ campaignTypeLabel('ranking') }}</option>
          </select>
          <select v-model="filters.status" class="form-select form-select-sm">
            <option value="">{{ tr('All statuses', 'ทุกสถานะ') }}</option>
            <option v-for="status in campaignStatuses" :key="status" :value="status">{{ statusLabel(status) }}</option>
          </select>
        </div>
      </div>
      <div class="card-body">
        <AdminDataTable
          :columns="campaignColumns"
          :rows="filteredCampaigns"
          :loading="loading"
          :empty-title="tr('No tier campaigns', 'ยังไม่มีแคมเปญระดับ')"
          :empty-message="tr('Create the first campaign to start managing affiliate tiers.', 'สร้างแคมเปญแรกเพื่อเริ่มจัดการระดับผู้แนะนำ')"
          embedded
        >
          <template #cell-name="{ row }">
            <button class="btn btn-link np-tier-name-link" type="button" @click="selectCampaign(row)">
              {{ row.name }}
            </button>
            <div class="text-muted fs-11">{{ row.id }}</div>
          </template>
          <template #cell-campaign_type="{ row }">
            <span class="np-tier-type-chip" :class="row.campaign_type === 'ranking' ? 'is-ranking' : 'is-fixed'">
              <i :class="row.campaign_type === 'ranking' ? 'ri-trophy-line' : 'ri-equalizer-2-line'" />
              {{ campaignTypeLabel(row.campaign_type) }}
            </span>
          </template>
          <template #cell-period="{ row }">
            <div class="fw-semibold">{{ formatDateTime(row.starts_at) }}</div>
            <div class="text-muted fs-11">{{ tr('to', 'ถึง') }} {{ formatDateTime(row.ends_at) }}</div>
          </template>
          <template #cell-rule_count="{ row }">
            {{ formatNumber(row.rules?.length || 0) }} {{ tr('rules', 'กติกา') }}
          </template>
          <template #cell-status="{ row }">
            <AdminStatusBadge :status="row.status" :label="statusLabel(row.status)" />
          </template>
          <template #rowActions="{ row }">
            <div class="d-flex justify-content-end gap-2">
              <button class="btn btn-sm btn-primary-light btn-wave" type="button" @click="selectCampaign(row)">
                {{ tr('View', 'ดูรายละเอียด') }}
              </button>
              <button v-if="canEdit(row)" class="btn btn-sm btn-light btn-wave" type="button" @click="openEditModal(row)">
                {{ tr('Edit', 'แก้ไข') }}
              </button>
            </div>
          </template>
        </AdminDataTable>
      </div>
    </div>

    <div v-if="selectedCampaign" class="card custom-card np-tier-detail-card">
      <div class="card-header np-tier-detail-header">
        <div>
          <div class="d-flex flex-wrap align-items-center gap-2 mb-1">
            <div class="card-title mb-0">{{ selectedCampaign.name }}</div>
            <AdminStatusBadge :status="selectedCampaign.status" :label="statusLabel(selectedCampaign.status)" />
          </div>
          <div class="text-muted fs-12">{{ selectedCampaign.id }}</div>
        </div>
        <div class="d-flex flex-wrap gap-2">
          <button v-if="canEdit(selectedCampaign)" class="btn btn-sm btn-light btn-wave" type="button" @click="openEditModal(selectedCampaign)">
            <i class="ri-edit-line me-1" />{{ tr('Edit campaign', 'แก้ไขแคมเปญ') }}
          </button>
          <button
            v-if="canRequestFinalize(selectedCampaign)"
            class="btn btn-sm btn-success btn-wave"
            type="button"
            :disabled="!isFinalizeDue(selectedCampaign)"
            :title="!isFinalizeDue(selectedCampaign) ? tr('The campaign can be finalized after its end time.', 'สรุปผลได้หลังสิ้นสุดแคมเปญ') : ''"
            @click="openActionModal('finalize', selectedCampaign)"
          >
            <i class="ri-check-double-line me-1" />{{ tr('Finalize results', 'สรุปผล') }}
          </button>
          <button v-if="canCancel(selectedCampaign)" class="btn btn-sm btn-danger-light btn-wave" type="button" @click="openActionModal('cancel', selectedCampaign)">
            <i class="ri-close-circle-line me-1" />{{ tr('Cancel campaign', 'ยกเลิกแคมเปญ') }}
          </button>
        </div>
      </div>
      <div class="card-body">
        <div v-if="detailLoading" class="np-tier-detail-loading">
          <span class="spinner-border spinner-border-sm" />
          {{ tr('Loading campaign details...', 'กำลังโหลดรายละเอียดแคมเปญ...') }}
        </div>
        <template v-else>
          <div class="np-tier-summary-grid mb-4">
            <div class="np-tier-summary-item">
              <span>{{ tr('Campaign type', 'ประเภทแคมเปญ') }}</span>
              <strong>{{ campaignTypeLabel(selectedCampaign.campaign_type) }}</strong>
            </div>
            <div class="np-tier-summary-item">
              <span>{{ tr('Campaign period', 'ช่วงเวลาแคมเปญ') }}</span>
              <strong>{{ formatDateTime(selectedCampaign.starts_at) }} - {{ formatDateTime(selectedCampaign.ends_at) }}</strong>
            </div>
            <div class="np-tier-summary-item">
              <span>{{ tr('Tier reduction', 'การลดระดับ') }}</span>
              <strong>{{ selectedCampaign.can_reduce_tier ? tr('Allowed', 'อนุญาต') : tr('Not allowed', 'ไม่อนุญาต') }}</strong>
            </div>
            <div class="np-tier-summary-item">
              <span>{{ tr('Finalized at', 'สรุปผลเมื่อ') }}</span>
              <strong>{{ selectedCampaign.finalized_at ? formatDateTime(selectedCampaign.finalized_at) : '-' }}</strong>
            </div>
          </div>

          <div class="row g-4">
            <div class="col-12 col-xl-5">
              <div class="np-tier-section-heading">
                <div>
                  <h5>{{ tr('Campaign rules', 'กติกาแคมเปญ') }}</h5>
                  <p>{{ ruleSectionDescription(selectedCampaign.campaign_type) }}</p>
                </div>
                <span>{{ formatNumber(selectedCampaign.rules?.length || 0) }}</span>
              </div>
              <div v-if="selectedCampaign.rules?.length" class="np-tier-rule-stack">
                <div v-for="(rule, index) in selectedCampaign.rules" :key="rule.id || index" class="np-tier-rule-card">
                  <div class="np-tier-rule-order">{{ index + 1 }}</div>
                  <div>
                    <div class="fw-semibold">{{ ruleConditionLabel(rule, selectedCampaign.campaign_type) }}</div>
                    <div class="text-muted fs-12">{{ tr('Target tier', 'ระดับเป้าหมาย') }}: {{ tierLabel(rule.target_tier) }}</div>
                  </div>
                </div>
              </div>
              <div v-else class="np-tier-empty-panel">{{ tr('No campaign rules', 'ยังไม่มีกติกาแคมเปญ') }}</div>
            </div>

            <div class="col-12 col-xl-7">
              <div class="np-tier-section-heading">
                <div>
                  <h5>{{ tr('Campaign results', 'ผลและอันดับแคมเปญ') }}</h5>
                  <p>{{ tr('Ranking is calculated from paid tickets attributed during the campaign period.', 'อันดับคำนวณจากสลากที่ชำระแล้วและมาจากการแนะนำในช่วงแคมเปญ') }}</p>
                </div>
                <span>{{ formatNumber(selectedCampaign.leaderboard?.length || 0) }}</span>
              </div>
              <div v-if="selectedCampaign.leaderboard?.length" class="table-responsive np-tier-leaderboard">
                <table class="table table-hover align-middle mb-0">
                  <thead>
                    <tr>
                      <th>{{ tr('Rank', 'อันดับ') }}</th>
                      <th>{{ tr('Affiliate code', 'รหัสผู้แนะนำ') }}</th>
                      <th class="text-end">{{ tr('Tickets', 'จำนวนสลาก') }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="entry in selectedCampaign.leaderboard" :key="`${entry.rank}-${entry.affiliate_code}`">
                      <td><span class="np-tier-rank">{{ entry.rank || '-' }}</span></td>
                      <td class="fw-semibold">{{ entry.affiliate_code || '-' }}</td>
                      <td class="text-end">{{ formatNumber(entry.ticket_count || 0) }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <div v-else class="np-tier-empty-panel">
                <i class="ri-bar-chart-grouped-line" />
                <span>{{ tr('No participants yet', 'ยังไม่มีผู้เข้าร่วมแคมเปญ') }}</span>
              </div>
            </div>
          </div>
        </template>
      </div>
    </div>

    <div v-else class="card custom-card np-tier-empty-detail">
      <div class="card-body">
        <i class="ri-cursor-line" />
        <h5>{{ tr('No campaign selected', 'ยังไม่ได้เลือกแคมเปญ') }}</h5>
        <p>{{ tr('Choose a campaign from the overview to inspect its rules and results.', 'เลือกแคมเปญจากตารางด้านบนเพื่อดูกติกาและผลลัพธ์') }}</p>
      </div>
    </div>

    <Teleport to="body">
    <div v-if="formModalOpen || actionModal.open" class="np-tier-overlay-host">
    <div v-if="formModalOpen" class="modal fade show np-tier-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-xl modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title">{{ form.id ? tr('Edit tier campaign', 'แก้ไขแคมเปญระดับ') : tr('Create tier campaign', 'สร้างแคมเปญระดับ') }}</h5>
              <div class="text-muted fs-12">{{ tr('Set the campaign period and tier evaluation rules.', 'กำหนดช่วงเวลาและกติกาประเมินระดับผู้แนะนำ') }}</div>
            </div>
            <button class="btn-close" type="button" :aria-label="tr('Close', 'ปิด')" :disabled="saving" @click="closeFormModal" />
          </div>
          <div class="modal-body">
            <form class="row g-3" @submit.prevent="saveCampaign">
              <div class="col-12 col-lg-8">
                <label class="form-label">{{ tr('Campaign name', 'ชื่อแคมเปญ') }}</label>
                <input v-model.trim="form.name" class="form-control" :placeholder="tr('Example: Mid-year sales challenge', 'ตัวอย่าง: แคมเปญยอดขายกลางปี')">
              </div>
              <div class="col-12 col-lg-4">
                <label class="form-label">{{ tr('Initial status', 'สถานะเริ่มต้น') }}</label>
                <select v-model="form.status" class="form-select">
                  <option value="draft">{{ statusLabel('draft') }}</option>
                  <option value="scheduled">{{ statusLabel('scheduled') }}</option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label">{{ tr('Evaluation type', 'รูปแบบการประเมิน') }}</label>
                <div class="np-tier-type-picker">
                  <button
                    class="np-tier-type-option"
                    :class="{ active: form.campaign_type === 'fixed_threshold' }"
                    type="button"
                    @click="changeCampaignType('fixed_threshold')"
                  >
                    <i class="ri-equalizer-2-line" />
                    <span>
                      <strong>{{ campaignTypeLabel('fixed_threshold') }}</strong>
                      <small>{{ tr('Assign tiers when ticket totals reach each threshold.', 'กำหนดระดับเมื่อยอดสลากถึงเกณฑ์ที่ตั้งไว้') }}</small>
                    </span>
                  </button>
                  <button
                    class="np-tier-type-option"
                    :class="{ active: form.campaign_type === 'ranking' }"
                    type="button"
                    @click="changeCampaignType('ranking')"
                  >
                    <i class="ri-trophy-line" />
                    <span>
                      <strong>{{ campaignTypeLabel('ranking') }}</strong>
                      <small>{{ tr('Assign tiers from the final competition ranking.', 'กำหนดระดับจากอันดับการแข่งขันเมื่อจบแคมเปญ') }}</small>
                    </span>
                  </button>
                </div>
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">{{ tr('Starts at', 'วันเวลาเริ่มต้น') }}</label>
                <input v-model="form.starts_at" class="form-control" type="datetime-local">
              </div>
              <div class="col-12 col-md-6">
                <label class="form-label">{{ tr('Ends at', 'วันเวลาสิ้นสุด') }}</label>
                <input v-model="form.ends_at" class="form-control" type="datetime-local">
              </div>

              <div class="col-12">
                <div class="np-tier-form-rule-heading">
                  <div>
                    <label class="form-label mb-1">{{ tr('Tier rules', 'กติกาการจัดระดับ') }}</label>
                    <div class="text-muted fs-12">{{ ruleSectionDescription(form.campaign_type) }}</div>
                  </div>
                  <button class="btn btn-sm btn-light btn-wave" type="button" @click="addRule">
                    <i class="ri-add-line me-1" />{{ tr('Add rule', 'เพิ่มกติกา') }}
                  </button>
                </div>
                <div class="np-tier-form-rules">
                  <div v-for="(rule, index) in form.rules" :key="index" class="np-tier-form-rule">
                    <span class="np-tier-rule-order">{{ index + 1 }}</span>
                    <template v-if="form.campaign_type === 'fixed_threshold'">
                      <div>
                        <label class="form-label fs-12">{{ tr('Minimum tickets', 'จำนวนสลากขั้นต่ำ') }}</label>
                        <input v-model.number="rule.minimum_ticket_count" class="form-control" type="number" min="0" step="1">
                      </div>
                    </template>
                    <template v-else>
                      <div>
                        <label class="form-label fs-12">{{ tr('Rank from', 'อันดับเริ่มต้น') }}</label>
                        <input v-model.number="rule.rank_from" class="form-control" type="number" min="1" step="1">
                      </div>
                      <div>
                        <label class="form-label fs-12">{{ tr('Rank to', 'อันดับสิ้นสุด') }}</label>
                        <input v-model.number="rule.rank_to" class="form-control" type="number" min="1" step="1">
                      </div>
                    </template>
                    <div>
                      <label class="form-label fs-12">{{ tr('Target tier', 'ระดับเป้าหมาย') }}</label>
                      <select v-model="rule.target_tier_code" class="form-select">
                        <option v-for="tier in orderedTiers" :key="tier.code" :value="tier.code">{{ tierLabel(tier) }}</option>
                      </select>
                    </div>
                    <button class="btn btn-icon btn-light" type="button" :title="tr('Remove rule', 'ลบกติกา')" :disabled="form.rules.length <= 1" @click="removeRule(index)">
                      <i class="ri-delete-bin-line" />
                    </button>
                  </div>
                </div>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button class="btn btn-light btn-wave" type="button" :disabled="saving" @click="closeFormModal">{{ tr('Cancel', 'ยกเลิก') }}</button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="saveDisabled" @click="saveCampaign">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
              {{ form.id ? tr('Save changes', 'บันทึกการแก้ไข') : tr('Create campaign', 'สร้างแคมเปญ') }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="formModalOpen" class="np-tier-backdrop" />

    <div v-if="actionModal.open" class="modal fade show np-tier-modal" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ actionModal.type === 'finalize' ? tr('Finalize campaign results', 'ยืนยันสรุปผลแคมเปญ') : tr('Cancel campaign', 'ยืนยันยกเลิกแคมเปญ') }}</h5>
            <button class="btn-close" type="button" :disabled="saving" @click="closeActionModal" />
          </div>
          <div class="modal-body">
            <p class="mb-3">
              {{ actionModal.type === 'finalize'
                ? tr('The system will calculate the final ranking and apply tier changes. This action cannot be edited afterward.', 'ระบบจะคำนวณอันดับสุดท้ายและปรับระดับผู้แนะนำ หลังสรุปผลแล้วจะไม่สามารถแก้ไขแคมเปญได้')
                : tr('This campaign will stop and no tier results will be applied.', 'แคมเปญนี้จะหยุดทำงานและไม่มีการนำผลระดับไปใช้') }}
            </p>
            <div class="np-tier-action-target">{{ actionModal.campaign?.name }}</div>
            <div class="mt-3">
              <label class="form-label">{{ tr('Reason / note', 'เหตุผล / หมายเหตุ') }}</label>
              <textarea v-model.trim="actionModal.reason" class="form-control" rows="3" :placeholder="actionModal.type === 'cancel' ? tr('Enter a cancellation reason', 'ระบุเหตุผลที่ยกเลิก') : tr('Optional note', 'หมายเหตุเพิ่มเติม (ไม่บังคับ)')" />
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-light btn-wave" type="button" :disabled="saving" @click="closeActionModal">{{ tr('Back', 'กลับ') }}</button>
            <button
              class="btn btn-wave"
              :class="actionModal.type === 'finalize' ? 'btn-success' : 'btn-danger'"
              type="button"
              :disabled="saving || (actionModal.type === 'cancel' && !actionModal.reason)"
              @click="runCampaignAction"
            >
              <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
              {{ actionModal.type === 'finalize' ? tr('Finalize results', 'สรุปผล') : tr('Cancel campaign', 'ยกเลิกแคมเปญ') }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="actionModal.open" class="np-tier-backdrop" />
    </div>
    </Teleport>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime } from '~/utils/format'

definePageMeta({
  layout: 'admin',
})

type AnyRecord = Record<string, any>
type CampaignType = 'fixed_threshold' | 'ranking'
type CampaignAction = 'finalize' | 'cancel'
type RuleForm = {
  minimum_ticket_count: number | null
  rank_from: number | null
  rank_to: number | null
  target_tier_code: string
}

const api = useAdminApi()
const session = useAdminSession()
const adminLocale = useAdminLocale()
const tenantId = computed(() => session.currentTenantId.value)
const isThai = computed(() => String(adminLocale.locale.value).toLowerCase().startsWith('th'))
const tr = (english: string, thai: string) => isThai.value ? thai : english

const loading = ref(false)
const detailLoading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const successMessage = ref('')
const campaigns = ref<AnyRecord[]>([])
const tiers = ref<AnyRecord[]>([])
const selectedCampaign = ref<AnyRecord | null>(null)
const filters = reactive({ q: '', type: '', status: '' })
const formModalOpen = ref(false)
const campaignStatuses = ['draft', 'scheduled', 'active', 'processing', 'completed', 'cancelled']

const emptyForm = () => ({
  id: '',
  name: '',
  campaign_type: 'fixed_threshold' as CampaignType,
  status: 'scheduled',
  starts_at: '',
  ends_at: '',
  rules: defaultFixedRules(),
})

const form = reactive(emptyForm())
const actionModal = reactive<{
  open: boolean
  type: CampaignAction
  campaign: AnyRecord | null
  reason: string
}>({ open: false, type: 'finalize', campaign: null, reason: '' })

const campaignColumns = computed(() => [
  { key: 'name', label: tr('Campaign', 'แคมเปญ') },
  { key: 'campaign_type', label: tr('Evaluation type', 'รูปแบบการประเมิน') },
  { key: 'period', label: tr('Campaign period', 'ช่วงเวลาแคมเปญ') },
  { key: 'rule_count', label: tr('Rules', 'กติกา') },
  { key: 'status', label: tr('Status', 'สถานะ') },
])

const filteredCampaigns = computed(() => {
  const query = filters.q.trim().toLowerCase()
  return campaigns.value.filter((campaign) => {
    if (filters.type && campaign.campaign_type !== filters.type) return false
    if (filters.status && campaign.status !== filters.status) return false
    if (query && ![campaign.name, campaign.id].some(value => String(value || '').toLowerCase().includes(query))) return false
    return true
  })
})

const metrics = computed(() => [
  {
    key: 'all',
    label: tr('All campaigns', 'แคมเปญทั้งหมด'),
    value: formatNumber(campaigns.value.length),
    icon: 'ri-stack-line',
    className: 'is-total',
  },
  {
    key: 'active',
    label: tr('Active', 'กำลังทำงาน'),
    value: formatNumber(campaigns.value.filter(row => row.status === 'active').length),
    icon: 'ri-pulse-line',
    className: 'is-active',
  },
  {
    key: 'scheduled',
    label: tr('Scheduled', 'ตั้งเวลาแล้ว'),
    value: formatNumber(campaigns.value.filter(row => row.status === 'scheduled').length),
    icon: 'ri-calendar-event-line',
    className: 'is-scheduled',
  },
  {
    key: 'completed',
    label: tr('Completed', 'สรุปผลแล้ว'),
    value: formatNumber(campaigns.value.filter(row => row.status === 'completed').length),
    icon: 'ri-medal-line',
    className: 'is-completed',
  },
])

const orderedTiers = computed(() => [...tiers.value].sort((left, right) => Number(left.rank || 0) - Number(right.rank || 0)))

const saveDisabled = computed(() => {
  if (saving.value || !tenantId.value || !form.name || !form.starts_at || !form.ends_at || form.rules.length === 0) return true
  if (new Date(form.ends_at).getTime() <= new Date(form.starts_at).getTime()) return true

  return form.rules.some((rule) => {
    if (!rule.target_tier_code) return true
    if (form.campaign_type === 'fixed_threshold') return rule.minimum_ticket_count === null || Number(rule.minimum_ticket_count) < 0
    return rule.rank_from === null || rule.rank_to === null || Number(rule.rank_from) < 1 || Number(rule.rank_to) < Number(rule.rank_from)
  })
})

function defaultFixedRules(): RuleForm[] {
  return [
    [0, 'bronze'],
    [200, 'silver'],
    [300, 'gold'],
    [400, 'platinum'],
    [500, 'diamond'],
  ].map(([minimum, tier]) => ({
    minimum_ticket_count: Number(minimum),
    rank_from: null,
    rank_to: null,
    target_tier_code: String(tier),
  }))
}

function defaultRankingRules(): RuleForm[] {
  return [
    { minimum_ticket_count: null, rank_from: 1, rank_to: 10, target_tier_code: 'diamond' },
    { minimum_ticket_count: null, rank_from: 11, rank_to: 20, target_tier_code: 'platinum' },
  ]
}

async function loadAll() {
  if (!tenantId.value) return
  loading.value = true
  error.value = null

  try {
    const [campaignResponse, tierResponse]: any[] = await Promise.all([
      api.apiFetch('/admin/tenant/affiliate-tier-campaigns', {
        scope: 'tenant',
        tenantId: tenantId.value,
        query: { limit: 100 },
        successMessage: false,
      }),
      api.apiFetch('/admin/tenant/affiliate-tiers', {
        scope: 'tenant',
        tenantId: tenantId.value,
        successMessage: false,
      }),
    ])
    campaigns.value = Array.isArray(campaignResponse?.data) ? campaignResponse.data : []
    tiers.value = Array.isArray(tierResponse?.data) ? tierResponse.data : []

    if (selectedCampaign.value) {
      const current = campaigns.value.find(row => row.id === selectedCampaign.value?.id)
      if (current) await loadCampaignDetail(current.id)
      else selectedCampaign.value = null
    }
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

async function selectCampaign(campaign: AnyRecord) {
  selectedCampaign.value = campaign
  await loadCampaignDetail(campaign.id)
}

async function loadCampaignDetail(campaignId: string) {
  if (!tenantId.value || !campaignId) return
  detailLoading.value = true
  error.value = null

  try {
    selectedCampaign.value = await api.apiFetch(`/admin/tenant/affiliate-tier-campaigns/${encodeURIComponent(campaignId)}`, {
      scope: 'tenant',
      tenantId: tenantId.value,
      successMessage: false,
    }) as AnyRecord
  } catch (err) {
    error.value = err
  } finally {
    detailLoading.value = false
  }
}

function openCreateModal() {
  Object.assign(form, emptyForm())
  setDefaultDates()
  error.value = null
  formModalOpen.value = true
}

async function openEditModal(campaign: AnyRecord) {
  let source = campaign
  if (!campaign.leaderboard) {
    await loadCampaignDetail(campaign.id)
    source = selectedCampaign.value || campaign
  }

  Object.assign(form, {
    id: source.id,
    name: source.name || '',
    campaign_type: source.campaign_type || 'fixed_threshold',
    status: ['draft', 'scheduled'].includes(source.status) ? source.status : 'draft',
    starts_at: toDateTimeInput(source.starts_at),
    ends_at: toDateTimeInput(source.ends_at),
    rules: Array.isArray(source.rules) ? source.rules.map((rule: AnyRecord) => ({
      minimum_ticket_count: rule.minimum_ticket_count ?? null,
      rank_from: rule.rank_from ?? null,
      rank_to: rule.rank_to ?? null,
      target_tier_code: rule.target_tier?.code || rule.target_tier_code || '',
    })) : [],
  })
  error.value = null
  formModalOpen.value = true
}

function closeFormModal() {
  if (saving.value) return
  formModalOpen.value = false
}

function setDefaultDates() {
  const start = new Date()
  start.setMinutes(start.getMinutes() + 60, 0, 0)
  const end = new Date(start)
  end.setDate(end.getDate() + 30)
  form.starts_at = toDateTimeInput(start)
  form.ends_at = toDateTimeInput(end)
}

function changeCampaignType(type: CampaignType) {
  if (form.campaign_type === type) return
  form.campaign_type = type
  form.rules = type === 'fixed_threshold' ? defaultFixedRules() : defaultRankingRules()
}

function addRule() {
  const last = form.rules[form.rules.length - 1]
  const fallbackTier = orderedTiers.value[0]?.code || 'bronze'
  if (form.campaign_type === 'fixed_threshold') {
    form.rules.push({
      minimum_ticket_count: Number(last?.minimum_ticket_count || 0) + 100,
      rank_from: null,
      rank_to: null,
      target_tier_code: fallbackTier,
    })
    return
  }

  const nextFrom = Number(last?.rank_to || 0) + 1
  form.rules.push({
    minimum_ticket_count: null,
    rank_from: nextFrom,
    rank_to: nextFrom + 9,
    target_tier_code: fallbackTier,
  })
}

function removeRule(index: number) {
  if (form.rules.length <= 1) return
  form.rules.splice(index, 1)
}

async function saveCampaign() {
  if (saveDisabled.value || !tenantId.value) return
  saving.value = true
  error.value = null
  successMessage.value = ''

  try {
    const payload = {
      name: form.name,
      campaign_type: form.campaign_type,
      status: form.status,
      starts_at: form.starts_at,
      ends_at: form.ends_at,
      rules: form.rules.map(rule => form.campaign_type === 'fixed_threshold'
        ? { minimum_ticket_count: Number(rule.minimum_ticket_count), target_tier_code: rule.target_tier_code }
        : { rank_from: Number(rule.rank_from), rank_to: Number(rule.rank_to), target_tier_code: rule.target_tier_code }),
    }
    const endpoint = form.id
      ? `/admin/tenant/affiliate-tier-campaigns/${encodeURIComponent(form.id)}`
      : '/admin/tenant/affiliate-tier-campaigns'
    const saved: AnyRecord = await api.apiFetch(endpoint, {
      method: form.id ? 'PATCH' : 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      successMessage: false,
      body: payload,
    }) as AnyRecord

    formModalOpen.value = false
    selectedCampaign.value = saved
    successMessage.value = form.id ? tr('Campaign updated.', 'แก้ไขแคมเปญแล้ว') : tr('Campaign created.', 'สร้างแคมเปญแล้ว')
    await loadAll()
  } catch (err) {
    error.value = err
  } finally {
    saving.value = false
  }
}

function openActionModal(type: CampaignAction, campaign: AnyRecord) {
  actionModal.open = true
  actionModal.type = type
  actionModal.campaign = campaign
  actionModal.reason = ''
  error.value = null
}

function closeActionModal() {
  if (saving.value) return
  actionModal.open = false
  actionModal.campaign = null
  actionModal.reason = ''
}

async function runCampaignAction() {
  if (!tenantId.value || !actionModal.campaign || saving.value) return
  saving.value = true
  error.value = null
  successMessage.value = ''

  try {
    const campaignId = actionModal.campaign.id
    const result: AnyRecord = await api.apiFetch(`/admin/tenant/affiliate-tier-campaigns/${encodeURIComponent(campaignId)}/${actionModal.type}`, {
      method: 'POST',
      scope: 'tenant',
      tenantId: tenantId.value,
      idempotencyKey: api.idempotencyKey(),
      successMessage: false,
      body: actionModal.reason ? { reason: actionModal.reason } : {},
    }) as AnyRecord
    selectedCampaign.value = result
    successMessage.value = actionModal.type === 'finalize'
      ? tr('Campaign results finalized.', 'สรุปผลแคมเปญแล้ว')
      : tr('Campaign cancelled.', 'ยกเลิกแคมเปญแล้ว')
    closeActionModal()
    await loadAll()
  } catch (err) {
    error.value = err
  } finally {
    saving.value = false
  }
}

function canEdit(campaign: AnyRecord) {
  return ['draft', 'scheduled'].includes(String(campaign.status || '')) && new Date(campaign.starts_at).getTime() > Date.now()
}

function canCancel(campaign: AnyRecord) {
  return ['draft', 'scheduled', 'active'].includes(String(campaign.status || ''))
}

function canRequestFinalize(campaign: AnyRecord) {
  return ['scheduled', 'active'].includes(String(campaign.status || ''))
}

function isFinalizeDue(campaign: AnyRecord) {
  return new Date(campaign.ends_at).getTime() <= Date.now()
}

function campaignTypeLabel(type: unknown) {
  return String(type) === 'ranking'
    ? tr('Ranking competition', 'จัดอันดับการแข่งขัน')
    : tr('Fixed ticket thresholds', 'เกณฑ์จำนวนสลาก')
}

function statusLabel(status: unknown) {
  const value = String(status || '')
  const labels: Record<string, [string, string]> = {
    draft: ['Draft', 'ฉบับร่าง'],
    scheduled: ['Scheduled', 'ตั้งเวลาแล้ว'],
    active: ['Active', 'กำลังทำงาน'],
    processing: ['Processing', 'กำลังประมวลผล'],
    completed: ['Completed', 'สรุปผลแล้ว'],
    cancelled: ['Cancelled', 'ยกเลิกแล้ว'],
  }
  const label = labels[value] || [value, value]
  return tr(label[0], label[1])
}

function tierLabel(tier: AnyRecord | null | undefined) {
  if (!tier) return '-'
  const code = String(tier.code || '')
  const thaiNames: Record<string, string> = {
    bronze: 'บรอนซ์',
    silver: 'ซิลเวอร์',
    gold: 'โกลด์',
    platinum: 'แพลทินัม',
    diamond: 'ไดมอนด์',
  }
  const name = isThai.value ? (thaiNames[code] || tier.name || code) : (tier.name || code)
  return `${name} (${code})`
}

function ruleSectionDescription(type: unknown) {
  return String(type) === 'ranking'
    ? tr('Set a rank range and the tier awarded to that range.', 'กำหนดช่วงอันดับและระดับที่จะได้รับในแต่ละช่วง')
    : tr('Set the minimum paid ticket count required for each tier.', 'กำหนดจำนวนสลากที่ชำระแล้วขั้นต่ำสำหรับแต่ละระดับ')
}

function ruleConditionLabel(rule: AnyRecord, type: unknown) {
  if (String(type) === 'ranking') {
    return `${tr('Rank', 'อันดับ')} ${formatNumber(rule.rank_from)} - ${formatNumber(rule.rank_to)}`
  }
  return `${tr('At least', 'อย่างน้อย')} ${formatNumber(rule.minimum_ticket_count)} ${tr('tickets', 'ใบ')}`
}

function formatNumber(value: unknown) {
  return Number(value || 0).toLocaleString(isThai.value ? 'th-TH' : 'en-US')
}

function toDateTimeInput(value: unknown) {
  const date = value instanceof Date ? value : new Date(String(value || ''))
  if (Number.isNaN(date.getTime())) return ''
  const pad = (part: number) => String(part).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

watch(tenantId, () => {
  selectedCampaign.value = null
  campaigns.value = []
  tiers.value = []
  if (tenantId.value) void loadAll()
}, { immediate: true })
</script>

<style scoped>
.np-tier-campaign-page {
  --tier-ink: #173a3a;
  --tier-teal: #087f73;
  --tier-mint: #dff5ef;
  --tier-gold: #d59a23;
  --tier-sand: #fff7e5;
}

.np-tier-hero {
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 178px;
  padding: 32px 38px;
  color: #fff;
  border-radius: 18px;
  background:
    radial-gradient(circle at 80% 20%, rgba(255, 213, 122, .28), transparent 30%),
    linear-gradient(120deg, #0d4f4b 0%, #087f73 64%, #23a88c 100%);
  box-shadow: 0 18px 40px rgba(8, 79, 73, .16);
}

.np-tier-hero::after {
  position: absolute;
  right: 110px;
  bottom: -70px;
  width: 220px;
  height: 220px;
  border: 28px solid rgba(255, 255, 255, .07);
  border-radius: 50%;
  content: '';
}

.np-tier-hero h2 {
  margin: 7px 0 8px;
  color: #fff;
  font-size: clamp(1.45rem, 2.5vw, 2.15rem);
  font-weight: 750;
}

.np-tier-hero p {
  max-width: 700px;
  margin: 0;
  color: rgba(255, 255, 255, .78);
}

.np-tier-hero-kicker {
  color: #ffda8a;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: .17em;
}

.np-tier-hero-mark {
  position: relative;
  z-index: 1;
  display: grid;
  flex: 0 0 92px;
  height: 92px;
  place-items: center;
  border: 1px solid rgba(255, 255, 255, .22);
  border-radius: 28px;
  background: rgba(255, 255, 255, .1);
  backdrop-filter: blur(8px);
}

.np-tier-hero-mark i {
  color: #ffda8a;
  font-size: 46px;
}

.np-tier-metric-card .card-body {
  display: flex;
  align-items: center;
  gap: 15px;
}

.np-tier-metric-icon {
  display: grid;
  flex: 0 0 46px;
  height: 46px;
  place-items: center;
  border-radius: 14px;
  font-size: 21px;
}

.np-tier-metric-icon.is-total { color: #087f73; background: #dff5ef; }
.np-tier-metric-icon.is-active { color: #18794e; background: #e3f7ea; }
.np-tier-metric-icon.is-scheduled { color: #a2690e; background: #fff2cf; }
.np-tier-metric-icon.is-completed { color: #2468a9; background: #e5f0fa; }

.np-tier-list-header,
.np-tier-detail-header,
.np-tier-form-rule-heading,
.np-tier-section-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
}

.np-tier-filters {
  display: flex;
  gap: 8px;
}

.np-tier-filters .form-select { width: 185px; }
.np-tier-search { width: 230px; }

.np-tier-name-link {
  padding: 0;
  color: var(--tier-ink);
  font-weight: 700;
  text-align: left;
  text-decoration: none;
}

.np-tier-name-link:hover { color: var(--tier-teal); }

.np-tier-type-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 9px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
}

.np-tier-type-chip.is-fixed { color: #087f73; background: #dff5ef; }
.np-tier-type-chip.is-ranking { color: #9a650d; background: #fff2cf; }

.np-tier-detail-card {
  border-top: 3px solid var(--tier-teal);
}

.np-tier-detail-loading {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 240px;
  gap: 10px;
  color: #687b7a;
}

.np-tier-summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}

.np-tier-summary-item {
  padding: 15px 16px;
  border: 1px solid #e8eeee;
  border-radius: 12px;
  background: #fbfdfd;
}

.np-tier-summary-item span {
  display: block;
  margin-bottom: 5px;
  color: #778887;
  font-size: 11px;
}

.np-tier-summary-item strong {
  color: var(--tier-ink);
  font-size: 13px;
}

.np-tier-section-heading {
  align-items: flex-start;
  margin-bottom: 14px;
}

.np-tier-section-heading h5 { margin: 0 0 3px; font-size: 15px; }
.np-tier-section-heading p { margin: 0; color: #7a8988; font-size: 11px; }
.np-tier-section-heading > span {
  min-width: 30px;
  padding: 5px 8px;
  color: var(--tier-teal);
  border-radius: 9px;
  background: var(--tier-mint);
  font-size: 12px;
  font-weight: 800;
  text-align: center;
}

.np-tier-rule-stack { display: grid; gap: 9px; }

.np-tier-rule-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 1px solid #e7eeee;
  border-radius: 12px;
  background: linear-gradient(90deg, #fbfdfd, #fff);
}

.np-tier-rule-order {
  display: grid;
  flex: 0 0 30px;
  height: 30px;
  place-items: center;
  color: #fff;
  border-radius: 9px;
  background: var(--tier-teal);
  font-size: 12px;
  font-weight: 800;
}

.np-tier-leaderboard {
  max-height: 385px;
  border: 1px solid #e7eeee;
  border-radius: 12px;
}

.np-tier-leaderboard thead { position: sticky; z-index: 1; top: 0; background: #f7faf9; }
.np-tier-rank {
  display: inline-grid;
  width: 30px;
  height: 30px;
  place-items: center;
  color: #8d5b08;
  border-radius: 50%;
  background: var(--tier-sand);
  font-weight: 800;
}

.np-tier-empty-panel,
.np-tier-empty-detail .card-body {
  display: flex;
  min-height: 150px;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 7px;
  color: #81908f;
  border: 1px dashed #d8e3e1;
  border-radius: 12px;
  background: #fbfdfd;
}

.np-tier-empty-panel i,
.np-tier-empty-detail i { color: #9eb8b4; font-size: 30px; }
.np-tier-empty-detail h5 { margin: 4px 0 0; color: var(--tier-ink); }
.np-tier-empty-detail p { margin: 0; }

.np-tier-overlay-host {
  position: fixed;
  z-index: 2000;
  inset: 0;
  isolation: isolate;
  pointer-events: none;
}

.np-tier-modal {
  position: absolute;
  z-index: 2;
  inset: 0;
  display: block;
  pointer-events: auto;
}

.np-tier-backdrop {
  position: absolute;
  z-index: 1;
  background: rgba(9, 24, 23, .56);
  inset: 0;
  pointer-events: auto;
}

.np-tier-type-picker {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.np-tier-type-option {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 15px;
  color: #4d6260;
  border: 1px solid #dce6e4;
  border-radius: 13px;
  background: #fff;
  text-align: left;
  transition: border-color .18s ease, background .18s ease, transform .18s ease;
}

.np-tier-type-option:hover { transform: translateY(-1px); border-color: #9fc9c3; }
.np-tier-type-option.active { color: var(--tier-ink); border-color: var(--tier-teal); background: #f0faf7; box-shadow: 0 0 0 3px rgba(8, 127, 115, .08); }
.np-tier-type-option > i { color: var(--tier-teal); font-size: 25px; }
.np-tier-type-option span { display: flex; flex-direction: column; }
.np-tier-type-option small { margin-top: 2px; color: #7b8b8a; }

.np-tier-form-rule-heading { margin: 7px 0 12px; }
.np-tier-form-rules { display: grid; gap: 10px; }
.np-tier-form-rule {
  display: grid;
  grid-template-columns: 34px repeat(3, minmax(0, 1fr)) 38px;
  align-items: end;
  gap: 10px;
  padding: 13px;
  border: 1px solid #e1e9e8;
  border-radius: 12px;
  background: #f9fbfb;
}

.np-tier-form-rule:has(> div:nth-of-type(2):last-of-type) {
  grid-template-columns: 34px minmax(0, 1fr) minmax(0, 1fr) 38px;
}

.np-tier-action-target {
  padding: 12px 14px;
  color: var(--tier-ink);
  border-left: 3px solid var(--tier-gold);
  border-radius: 0 9px 9px 0;
  background: var(--tier-sand);
  font-weight: 700;
}

@media (max-width: 991.98px) {
  .np-tier-list-header,
  .np-tier-detail-header { align-items: flex-start; flex-direction: column; }
  .np-tier-filters { width: 100%; flex-wrap: wrap; }
  .np-tier-search { flex: 1 1 100%; width: 100%; }
  .np-tier-filters .form-select { flex: 1 1 180px; width: auto; }
  .np-tier-summary-grid { grid-template-columns: 1fr 1fr; }
}

@media (max-width: 767.98px) {
  .np-tier-hero { min-height: 150px; padding: 24px; }
  .np-tier-hero-mark { display: none; }
  .np-tier-type-picker { grid-template-columns: 1fr; }
  .np-tier-form-rule,
  .np-tier-form-rule:has(> div:nth-of-type(2):last-of-type) { grid-template-columns: 30px 1fr; }
  .np-tier-form-rule > div { grid-column: 2; }
  .np-tier-form-rule > button { grid-column: 2; justify-self: end; }
}

@media (max-width: 575.98px) {
  .np-tier-summary-grid { grid-template-columns: 1fr; }
  .np-tier-hero p { font-size: 12px; }
}
</style>

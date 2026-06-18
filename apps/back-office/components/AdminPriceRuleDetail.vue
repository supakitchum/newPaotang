<template>
  <div class="card custom-card">
    <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
      <div>
        <div class="card-title mb-1">Reward Payout Rule detail</div>
        <p class="text-muted fs-12 mb-0">{{ subtitle }}</p>
      </div>
      <AdminStatusBadge v-if="record?.status" :status="record.status" />
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!record" title="No detail data" message="This payout rule has no data to display yet." />
      <div v-else class="row g-3">
        <div v-for="section in sections" :key="section.title" class="col-12 col-xl-6">
          <div class="border rounded p-3 h-100">
            <h6 class="mb-3">{{ section.title }}</h6>
            <dl class="row mb-0 gy-2">
              <template v-for="item in section.items" :key="item.key">
                <dt class="col-sm-5 text-muted fw-semibold">{{ item.label }}</dt>
                <dd class="col-sm-7 mb-0">
                  <AdminStatusBadge v-if="item.type === 'status'" :status="item.value" />
                  <code v-else-if="item.mono" class="np-admin-code">{{ item.value || '-' }}</code>
                  <span v-else>{{ item.value || '-' }}</span>
                </dd>
              </template>
            </dl>
          </div>
        </div>

        <div v-if="previewPrizes.length" class="col-12">
          <div class="border rounded p-3">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
              <h6 class="mb-0">Matched prizes</h6>
              <span class="badge bg-light text-default">{{ previewPrizeCountLabel }}</span>
            </div>
            <div class="table-responsive">
              <table class="table table-sm text-nowrap mb-0">
                <thead>
                  <tr>
                    <th>Reward</th>
                    <th>Number</th>
                    <th class="text-end">Central payout</th>
                    <th class="text-end">Delta</th>
                    <th class="text-end">Partner payout</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="prize in previewPrizes" :key="prize.key">
                    <td>{{ prize.prizeType }}</td>
                    <td><code class="np-admin-code">{{ prize.prizeNumber }}</code></td>
                    <td class="text-end">{{ prize.baseAmount }}</td>
                    <td class="text-end">{{ prize.adjustmentAmount }}</td>
                    <td class="text-end">{{ prize.effectiveAmount }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, formatRewardMoney, titleize } from '~/utils/format'

type DetailItem = {
  key: string
  label: string
  value: string
  mono?: boolean
  type?: string | null
}

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
}>()

const ruleSnapshot = computed(() => plainObject(props.record?.price_rule_snapshot))
const rewardPreview = computed(() => plainObject(props.record?.reward_preview))
const previewSummary = computed(() => plainObject(rewardPreview.value?.summary))
const reporting = computed(() => plainObject(props.record?.reporting))
const adjustment = computed(() => plainObject(props.record?.adjustment))
const conditions = computed(() => (
  plainObject(props.record?.conditions)
    || plainObject(ruleSnapshot.value?.conditions)
    || plainObject(props.record?.conditions_json)
))

const subtitle = computed(() => {
  if (!props.record) {
    return 'Reward payout detail'
  }

  return [
    props.record.prize_label || props.record.name || props.record.code,
    props.record.game_id,
  ].filter(Boolean).join(' - ')
})

const sections = computed(() => {
  const record = props.record || {}
  const snapshot = ruleSnapshot.value || {}
  const summary = previewSummary.value || {}
  const report = reporting.value || {}
  const recordId = String(record.id || '')
  const isSyntheticRow = recordId.startsWith('game:')

  return [
    {
      title: 'Reward',
      items: compactItems([
        item('prize_label', 'Reward', record.prize_label || record.name),
        item('prize_type', 'Prize type', record.prize_type || conditions.value?.prize_type),
        item('prize_count', 'Prize count', record.prize_count ?? summary.matched_prize_count),
        item('digits', 'Digits', record.digits),
        item('game_id', 'Game', record.game_id || snapshot.game_id, true),
        item('source', 'Source', record.source || report.base_source || record.base_source),
      ]),
    },
    {
      title: 'Payout',
      items: compactItems([
        item('central_reward_amount', 'Central payout', moneyValue(record.central_reward_amount || summary.base_total)),
        item('partner_payout_amount', 'Partner payout', moneyValue(record.partner_payout_amount || summary.effective_total)),
        item('adjustment_amount', 'Delta', moneyValue(record.adjustment_amount || adjustment.value || summary.adjustment_total)),
        item('adjustment_bps', 'Delta percent', percentValue(adjustment.value?.bps ?? snapshot.adjustment_bps)),
        item('currency', 'Currency', moneyCurrency(record.partner_payout_amount || record.central_reward_amount || summary.effective_total || summary.base_total || record.price)),
      ]),
    },
    {
      title: 'Rule',
      items: compactItems([
        item('row_id', 'Row', isSyntheticRow ? recordId : '', true),
        item('tenant_price_rule_id', 'Stored rule', record.tenant_price_rule_id || snapshot.id || (!isSyntheticRow ? recordId : ''), true),
        item('code', 'Code', record.code || snapshot.code, true),
        item('rule_type', 'Type', titleValue(record.rule_type || snapshot.rule_type)),
        item('base_source', 'Base source', titleValue(record.base_source || snapshot.base_source || report.base_source)),
        item('conditions', 'Conditions', conditionsText.value),
      ]),
    },
    {
      title: 'Reporting',
      items: compactItems([
        item('reward_result_id', 'Reward result', record.reward_result_id || summary.reward_result_id, true),
        item('matched_prize_count', 'Matched prizes', summary.matched_prize_count),
        item('snapshot_fields', 'Snapshot fields', Array.isArray(report.snapshot_fields) ? report.snapshot_fields.join(', ') : ''),
        item('created_at', 'Created', formatMaybeDate(record.created_at)),
        item('updated_at', 'Updated', formatMaybeDate(record.updated_at)),
      ]),
    },
  ]
})

const previewPrizes = computed(() => {
  const prizes = Array.isArray(rewardPreview.value?.prizes) ? rewardPreview.value.prizes : []

  return prizes.slice(0, 20).map((prize: Record<string, any>, index: number) => ({
    key: String(prize.reward_prize_id || `${prize.prize_type}-${prize.prize_number}-${index}`),
    prizeType: titleValue(prize.prize_type),
    prizeNumber: String(prize.prize_number || '-'),
    baseAmount: moneyValue(prize.base_amount),
    adjustmentAmount: moneyValue(prize.adjustment_amount),
    effectiveAmount: moneyValue(prize.effective_amount),
  }))
})

const previewPrizeCountLabel = computed(() => {
  const total = Array.isArray(rewardPreview.value?.prizes) ? rewardPreview.value.prizes.length : previewPrizes.value.length

  return total > previewPrizes.value.length ? `${previewPrizes.value.length} of ${total}` : `${total}`
})

const conditionsText = computed(() => formatCompact(conditions.value))

function item(key: string, label: string, value: any, mono = false, type: string | null = null): DetailItem {
  return {
    key,
    label,
    value: normalizeValue(value),
    mono,
    type,
  }
}

function compactItems(items: DetailItem[]) {
  return items.filter((entry) => entry.value !== '')
}

function normalizeValue(value: any) {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  if (typeof value === 'number') {
    return new Intl.NumberFormat('th-TH', { maximumFractionDigits: 0 }).format(value)
  }

  return String(value)
}

function moneyValue(value: any) {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  return formatRewardMoney(value, moneyCurrency(value) || 'THB')
}

function moneyCurrency(value: any) {
  if (typeof value === 'object' && value !== null && value.currency) {
    return String(value.currency)
  }

  return ''
}

function percentValue(value: any) {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  return `${new Intl.NumberFormat('th-TH', { maximumFractionDigits: 2 }).format(Number(value || 0) / 100)}%`
}

function titleValue(value: any) {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  return titleize(String(value))
}

function formatMaybeDate(value: any) {
  if (!value) {
    return ''
  }

  return formatDateTime(String(value))
}

function plainObject(value: any): Record<string, any> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : null
}

function formatCompact(value: any): string {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  if (Array.isArray(value)) {
    return value.map((entry) => formatCompact(entry)).filter(Boolean).join(', ')
  }

  if (typeof value === 'object') {
    return Object.entries(value)
      .map(([key, entry]) => {
        const formatted = formatCompact(entry)
        return formatted ? `${titleValue(key)}: ${formatted}` : ''
      })
      .filter(Boolean)
      .join('; ')
  }

  return String(value)
}
</script>

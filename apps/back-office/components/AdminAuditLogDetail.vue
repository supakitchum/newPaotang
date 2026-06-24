<template>
  <div class="np-audit-detail">
    <AdminLoader v-if="loading" />
    <template v-else>
      <div class="card custom-card">
        <div class="card-body">
          <div class="d-flex flex-column flex-lg-row align-items-lg-center justify-content-between gap-3">
            <div class="d-flex align-items-start gap-3">
              <span class="avatar avatar-lg bg-primary-transparent text-primary">
                <i class="ri-shield-check-line fs-4" />
              </span>
              <div>
                <div class="d-flex flex-wrap align-items-center gap-2 mb-2">
                  <span class="badge bg-primary-transparent text-primary">{{ recordValue('action_label') }}</span>
                  <span class="badge bg-light text-default">{{ recordValue('scope') }}</span>
                </div>
                <h5 class="mb-1">{{ recordValue('summary') }}</h5>
                <p class="text-muted mb-0">{{ formatDateTime(record?.created_at) }}</p>
              </div>
            </div>
            <div class="text-lg-end">
              <div class="text-muted fs-12">Request ID</div>
              <div class="fw-semibold text-break">{{ recordValue('request_id') }}</div>
            </div>
          </div>
        </div>
      </div>

      <div class="row g-3">
        <div class="col-xl-5">
          <div class="card custom-card h-100">
            <div class="card-header">
              <div class="card-title">Event context</div>
            </div>
            <div class="card-body">
              <dl class="np-audit-context">
                <template v-for="item in contextItems" :key="item.label">
                  <dt>{{ item.label }}</dt>
                  <dd>{{ item.value }}</dd>
                </template>
              </dl>
            </div>
          </div>
        </div>

        <div class="col-xl-7">
          <div class="card custom-card h-100">
            <div class="card-header">
              <div>
                <div class="card-title">Changes / Payload</div>
                <p class="text-muted mb-0 fs-12">{{ recordValue('payload_summary') }}</p>
              </div>
            </div>
            <div class="card-body p-0">
              <div v-if="payloadEntries.length" class="table-responsive">
                <table class="table table-sm table-hover mb-0">
                  <thead>
                    <tr>
                      <th style="width: 36%;">Field</th>
                      <th>Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="entry in payloadEntries" :key="entry.key">
                      <td>
                        <div class="fw-semibold">{{ entry.label || entry.key }}</div>
                        <div class="text-muted fs-11">{{ entry.key }}</div>
                      </td>
                      <td class="text-break">{{ entry.value || '-' }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <div v-else class="p-4 text-center text-muted">
                <i class="ri-file-shield-2-line fs-2 d-block mb-2" />
                No additional audit payload was recorded.
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime } from '~/utils/format'

const props = defineProps<{
  record?: Record<string, any> | null
  loading?: boolean
}>()

const record = computed(() => props.record || {})

const recordValue = (key: string) => {
  const value = record.value?.[key]
  return value === undefined || value === null || value === '' ? '-' : String(value)
}

const payloadEntries = computed(() => Array.isArray(record.value?.payload_entries) ? record.value.payload_entries : [])

const contextItems = computed(() => [
  { label: 'Actor', value: recordValue('actor_label') },
  { label: 'Actor type', value: recordValue('actor_type') },
  { label: 'Action code', value: recordValue('action') },
  { label: 'Target', value: recordValue('target_label') },
  { label: 'Target ID', value: recordValue('target_id') },
  { label: 'Tenant', value: recordValue('tenant_label') },
  { label: 'Partner', value: recordValue('partner_label') },
  { label: 'IP address', value: recordValue('ip_address') },
  { label: 'User agent', value: recordValue('user_agent') },
])
</script>

<style scoped>
.np-audit-context {
  display: grid;
  grid-template-columns: minmax(7rem, 10rem) minmax(0, 1fr);
  gap: .8rem 1rem;
  margin-bottom: 0;
}

.np-audit-context dt {
  color: var(--text-muted);
  font-weight: 600;
}

.np-audit-context dd {
  margin-bottom: 0;
  min-width: 0;
  overflow-wrap: anywhere;
}

@media (max-width: 575.98px) {
  .np-audit-context {
    grid-template-columns: 1fr;
    gap: .25rem;
  }

  .np-audit-context dd {
    margin-bottom: .65rem;
  }
}
</style>

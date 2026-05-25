<template>
  <dl class="row mb-0">
    <template v-for="item in items" :key="item.key">
      <dt class="col-md-4 text-muted fw-semibold">{{ item.label }}</dt>
      <dd class="col-md-8">
        <slot :name="`value-${item.key}`" :item="item">
          <AdminImagePreview v-if="item.type === 'image'" :image="item.value" :label="item.label" />
          <div v-else-if="item.type === 'permission-list'" class="np-permission-checklist">
            <div class="d-flex flex-wrap align-items-center gap-2 mb-2">
              <span class="badge bg-primary-transparent text-primary">{{ assignedPermissionCount(item) }} selected</span>
              <span class="text-muted small">{{ permissionRows(item).length }} available</span>
            </div>
            <div class="np-permission-checklist__grid">
              <label
                v-for="permission in permissionRows(item)"
                :key="permission.code"
                class="np-permission-checklist__row"
                :class="{ 'np-permission-checklist__row--unchecked': !permission.checked }"
              >
                <input
                  class="form-check-input"
                  type="checkbox"
                  :checked="permission.checked"
                  disabled
                >
                <span class="np-permission-checklist__body">
                  <span class="np-permission-checklist__label">{{ permission.label }}</span>
                  <code class="np-admin-code">{{ permission.code }}</code>
                </span>
              </label>
            </div>
          </div>
          <code v-else-if="isMonoItem(item)" class="np-admin-code">{{ displayValue(item) }}</code>
          <span v-else>{{ displayValue(item) }}</span>
        </slot>
      </dd>
    </template>
  </dl>
</template>

<script setup lang="ts">
import type { OperationOption } from '~/composables/useAdminOperationsCatalog'
import { formatAdminValue, labelize, type AdminDisplayType } from '~/utils/format'

type DefinitionItem = {
  key: string
  label: string
  value: unknown
  mono?: boolean
  type?: AdminDisplayType
  options?: OperationOption[]
}

type PermissionRow = {
  code: string
  label: string
  checked: boolean
}

defineProps<{
  items: DefinitionItem[]
}>()

const isIdOrCodeKey = (key: string) => /(^id$|_id$|Id$|(^|_)(code|ref|uuid|token|slug)$)/.test(key)
const isMonoItem = (item: DefinitionItem) => Boolean(item.mono ?? (isIdOrCodeKey(item.key) && typeof item.value !== 'object'))
const displayValue = (item: DefinitionItem) => formatAdminValue(item.value, item.type, item.key)
const optionValue = (option: OperationOption) => typeof option === 'object' && option !== null ? option.value : option
const optionLabel = (option: OperationOption) => typeof option === 'object' && option !== null ? option.label : labelize(String(option))
const optionCode = (option: OperationOption) => {
  if (typeof option === 'object' && option !== null) {
    return String(option.code || option.value || '')
  }

  return String(option)
}
const permissionCodes = (value: unknown) => {
  const entries = Array.isArray(value)
    ? value
    : value === undefined || value === null || value === ''
      ? []
      : [value]

  return entries
    .map((entry) => {
      if (entry && typeof entry === 'object') {
        const source = entry as Record<string, unknown>
        return source.code || source.value || source.id
      }

      return entry
    })
    .filter((entry) => entry !== undefined && entry !== null && entry !== '')
    .map((entry) => String(entry))
}
const permissionRows = (item: DefinitionItem): PermissionRow[] => {
  const assigned = new Set(permissionCodes(item.value))
  const options = item.options?.length
    ? item.options
    : permissionCodes(item.value).map((code) => ({ value: code, label: labelize(code), code }))

  return options
    .map((option) => {
      const code = optionCode(option)
      return {
        code,
        label: optionLabel(option),
        checked: assigned.has(String(optionValue(option))) || assigned.has(code),
      }
    })
    .filter((permission) => permission.code)
}
const assignedPermissionCount = (item: DefinitionItem) => permissionRows(item)
  .filter((permission) => permission.checked)
  .length
</script>

<style scoped>
.np-permission-checklist {
  display: grid;
  gap: .5rem;
}

.np-permission-checklist__grid {
  display: grid;
  gap: .5rem;
  grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
}

.np-permission-checklist__row {
  align-items: flex-start;
  border: 1px solid var(--default-border);
  border-radius: 6px;
  display: flex;
  gap: .6rem;
  margin: 0;
  min-height: 3rem;
  padding: .6rem .7rem;
}

.np-permission-checklist__row--unchecked {
  background: var(--custom-white);
  opacity: .68;
}

.np-permission-checklist__row .form-check-input {
  margin-left: 0;
  margin-top: .15rem;
  pointer-events: none;
}

.np-permission-checklist__body {
  display: grid;
  gap: .2rem;
  min-width: 0;
}

.np-permission-checklist__label {
  font-weight: 600;
  line-height: 1.25;
}
</style>

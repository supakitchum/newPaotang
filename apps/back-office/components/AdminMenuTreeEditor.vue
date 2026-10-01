<template>
  <div class="card custom-card">
    <div class="card-header d-flex align-items-center justify-content-between gap-2 flex-wrap">
      <div>
        <div class="card-title mb-0">Menu Tree</div>
        <p class="text-muted mb-0 fs-12">{{ scopeLabel }} scope - {{ flatItems.length }} menu items</p>
      </div>
      <button class="btn btn-light btn-wave" type="button" :disabled="loading || saving" @click="reset">
        <i class="ri-refresh-line me-1" />
        Reset
      </button>
    </div>
    <div class="card-body">
      <AdminApiState :error="error" />
      <AdminLoader v-if="loading" />
      <AdminEmptyState
        v-else-if="!localItems.length"
        title="No menu items"
        message="The backend did not return manageable menu items for this scope."
        icon="ri-menu-search-line"
      />
      <div v-else class="table-responsive">
        <table class="table align-middle text-nowrap">
          <thead>
            <tr>
              <th>Label</th>
              <th>Route</th>
              <th>Permission</th>
              <th>Status</th>
              <th>Order</th>
              <th>Role IDs</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in flatItems" :key="row.item.id || row.item.key">
              <td>
                <div class="d-flex align-items-center gap-2" :style="{ paddingLeft: `${row.depth * 1.25}rem` }">
                  <i class="ri-arrow-right-s-line text-muted" />
                  <input v-model="row.item.label" class="form-control form-control-sm np-menu-editor-label" />
                </div>
                <div class="text-muted fs-12 font-monospace ms-4">{{ row.item.key || row.item.code || row.item.id }}</div>
              </td>
              <td><input v-model="row.item.route" class="form-control form-control-sm np-menu-editor-route" /></td>
              <td><input v-model="row.item.required_permission_code" class="form-control form-control-sm np-menu-editor-permission" /></td>
              <td>
                <select v-model="row.item.status" class="form-select form-select-sm np-menu-editor-status">
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                  <option value="archived">Archived</option>
                </select>
              </td>
              <td><input v-model.number="row.item.sort_order" class="form-control form-control-sm np-menu-editor-order" type="number" step="1" /></td>
              <td>
                <textarea
                  v-model="row.item.role_ids_text"
                  class="form-control form-control-sm np-menu-editor-roles"
                  rows="2"
                  placeholder="rol_example_one"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="row g-3 mt-2">
        <div class="col-12">
          <label class="form-label">Reason</label>
          <textarea v-model="reason" class="form-control" rows="3" />
        </div>
      </div>
    </div>
    <div class="card-footer d-flex justify-content-end">
      <button class="btn btn-primary btn-wave" type="button" :disabled="saving || loading || !reason.trim() || !localItems.length" @click="openConfirm">
        <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
        Save menu
      </button>
    </div>
  </div>

  <AdminModal v-model="confirmOpen" title="Confirm menu save" size="lg">
    <AdminApiState :error="error" />
    <p class="text-muted mb-3">Review the scope and changed menu items before saving this full menu tree.</p>

    <div class="border rounded-2 bg-light p-3 mb-3">
      <dl class="row small mb-0">
        <dt class="col-sm-4 text-muted">Scope</dt>
        <dd class="col-sm-8 mb-2 font-monospace">{{ scopeLabel }}</dd>
        <dt class="col-sm-4 text-muted">Menu items</dt>
        <dd class="col-sm-8 mb-2 font-monospace">{{ pendingItemCount }}</dd>
        <dt class="col-sm-4 text-muted">Changed items</dt>
        <dd class="col-sm-8 mb-2 font-monospace">{{ pendingChanges.length }}</dd>
        <dt class="col-sm-4 text-muted">Reason</dt>
        <dd class="col-sm-8 mb-0 text-break">{{ reason.trim() }}</dd>
      </dl>
    </div>

    <div v-if="pendingChanges.length" class="table-responsive">
      <table class="table table-sm align-middle">
        <thead>
          <tr>
            <th>Item</th>
            <th>Changed context</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="change in pendingChangesPreview" :key="change.identity">
            <td>
              <div class="fw-semibold">{{ change.label }}</div>
              <div class="text-muted fs-12 font-monospace">{{ change.identity }}</div>
            </td>
            <td>
              <ul class="mb-0 ps-3">
                <li v-for="field in change.fields" :key="`${change.identity}-${field.field}`">
                  <span class="fw-semibold">{{ field.label }}:</span>
                  <span class="font-monospace text-break">{{ field.before }}</span>
                  <i class="ri-arrow-right-line mx-1 text-muted" />
                  <span class="font-monospace text-break">{{ field.after }}</span>
                </li>
              </ul>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="pendingChanges.length > pendingChangesPreview.length" class="text-muted fs-12 mb-0">
        Showing {{ pendingChangesPreview.length }} of {{ pendingChanges.length }} changed items.
      </p>
    </div>
    <AdminEmptyState
      v-else
      title="No field changes detected"
      message="Confirmation will resubmit the current menu tree for this scope."
      icon="ri-information-line"
    />

    <template #footer>
      <button class="btn btn-light btn-wave" type="button" :disabled="saving" @click="cancelConfirm">Cancel</button>
      <button class="btn btn-primary btn-wave" type="button" :disabled="saving || !pendingItems.length || !reason.trim()" @click="confirmSave">
        <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
        Confirm save
      </button>
    </template>
  </AdminModal>
</template>

<script setup lang="ts">
import { titleize } from '~/utils/format'

type EditableMenuItem = {
  id?: string
  key?: string
  code?: string
  label?: string
  route?: string | null
  category?: string | null
  icon?: string | null
  required_permission_code?: string | null
  status?: string
  sort_order?: number
  role_ids?: string[]
  role_ids_text?: string
  children?: EditableMenuItem[]
}

type CleanMenuItem = {
  id?: string
  key?: string
  code?: string
  label?: string
  route?: string | null
  category?: string | null
  icon?: string | null
  required_permission_code?: string | null
  status?: string
  sort_order?: number
  role_ids?: string[]
  children?: CleanMenuItem[]
}

type MenuFieldChange = {
  field: string
  label: string
  before: string
  after: string
}

type MenuItemChange = {
  identity: string
  label: string
  fields: MenuFieldChange[]
}

const props = defineProps<{
  scope: 'tenant' | 'central'
  modelValue: any
  loading?: boolean
  saving?: boolean
  error?: any
}>()

const emit = defineEmits<{
  save: [reason: string, items: any[]]
}>()

const localItems = ref<EditableMenuItem[]>([])
const baselineItems = ref<CleanMenuItem[]>([])
const pendingItems = ref<CleanMenuItem[]>([])
const pendingChanges = ref<MenuItemChange[]>([])
const confirmOpen = ref(false)
const reason = ref('')
const scopeLabel = computed(() => titleize(props.scope))

const flatItems = computed(() => flatten(localItems.value))
const pendingItemCount = computed(() => flattenClean(pendingItems.value).length)
const pendingChangesPreview = computed(() => pendingChanges.value.slice(0, 8))

const reset = () => {
  const normalized = normalizeMenuItems(props.modelValue)
  localItems.value = normalized
  baselineItems.value = cleanMenuItems(normalized)
  pendingItems.value = []
  pendingChanges.value = []
  confirmOpen.value = false
  reason.value = ''
}

const openConfirm = () => {
  pendingItems.value = cleanMenuItems(localItems.value)
  pendingChanges.value = diffMenuItems(baselineItems.value, pendingItems.value)
  confirmOpen.value = true
}

const cancelConfirm = () => {
  confirmOpen.value = false
}

const confirmSave = () => {
  const items = pendingItems.value.length ? pendingItems.value : cleanMenuItems(localItems.value)
  confirmOpen.value = false
  emit('save', reason.value.trim(), items)
}

const normalizeMenuItems = (value: any): EditableMenuItem[] => {
  const source = Array.isArray(value) ? value : []
  return source.map((item) => normalizeMenuItem(item))
}

const normalizeMenuItem = (item: any): EditableMenuItem => ({
  id: item?.id,
  key: item?.key || item?.code,
  code: item?.code || item?.key,
  label: item?.label || '',
  route: item?.route || '',
  category: item?.category || null,
  icon: item?.icon || null,
  required_permission_code: item?.required_permission_code || '',
  status: item?.status || 'active',
  sort_order: Number(item?.sort_order || 0),
  role_ids: Array.isArray(item?.role_ids) ? item.role_ids : [],
  role_ids_text: Array.isArray(item?.role_ids) ? item.role_ids.join('\n') : '',
  children: normalizeMenuItems(item?.children),
})

const cleanMenuItems = (items: EditableMenuItem[]): CleanMenuItem[] => items.map((item, index) => ({
  id: item.id,
  key: item.key || item.code,
  code: item.code || item.key,
  label: String(item.label || '').trim(),
  route: item.route ? String(item.route).trim() : null,
  category: item.category ? String(item.category).trim() : null,
  icon: item.icon ? String(item.icon).trim() : null,
  required_permission_code: item.required_permission_code ? String(item.required_permission_code).trim() : null,
  status: item.status || 'active',
  sort_order: Number(item.sort_order || ((index + 1) * 10)),
  role_ids: String(item.role_ids_text || '')
    .split(/\r?\n/)
    .map((roleId) => roleId.trim())
    .filter(Boolean),
  children: cleanMenuItems(item.children || []),
}))

const flatten = (items: EditableMenuItem[], depth = 0): Array<{ item: EditableMenuItem, depth: number }> => items.flatMap((item) => [
  { item, depth },
  ...flatten(item.children || [], depth + 1),
])

const flattenClean = (items: CleanMenuItem[], depth = 0): Array<{ item: CleanMenuItem, depth: number }> => items.flatMap((item) => [
  { item, depth },
  ...flattenClean(item.children || [], depth + 1),
])

const diffMenuItems = (beforeItems: CleanMenuItem[], afterItems: CleanMenuItem[]): MenuItemChange[] => {
  const beforeMap = new Map(flattenClean(beforeItems).map(({ item }) => [menuIdentity(item), item]))

  return flattenClean(afterItems)
    .map(({ item }) => {
      const before = beforeMap.get(menuIdentity(item))
      const fields = before ? changedFields(before, item) : [{
        field: 'item',
        label: 'Item',
        before: '-',
        after: 'Added to submitted tree',
      }]

      return {
        identity: menuIdentity(item),
        label: menuLabel(item),
        fields,
      }
    })
    .filter((change) => change.fields.length)
}

const changedFields = (before: CleanMenuItem, after: CleanMenuItem): MenuFieldChange[] => ([
  ['label', 'Label'],
  ['route', 'Route'],
  ['required_permission_code', 'Permission'],
  ['status', 'Status'],
  ['sort_order', 'Order'],
  ['role_ids', 'Role IDs'],
] as const).flatMap(([field, label]) => {
  const beforeValue = menuFieldValue(before, field)
  const afterValue = menuFieldValue(after, field)

  return beforeValue === afterValue ? [] : [{
    field,
    label,
    before: beforeValue || '-',
    after: afterValue || '-',
  }]
})

const menuFieldValue = (item: CleanMenuItem, field: keyof CleanMenuItem) => {
  const value = item[field]
  if (Array.isArray(value)) return value.join(', ')
  if (value === undefined || value === null || value === '') return ''
  return String(value)
}

const menuIdentity = (item: CleanMenuItem | EditableMenuItem) => String(item.id || item.key || item.code || item.label || 'menu-item')
const menuLabel = (item: CleanMenuItem | EditableMenuItem) => String(item.label || item.key || item.code || item.id || 'Menu item')

watch(() => props.modelValue, reset, { immediate: true, deep: true })
</script>

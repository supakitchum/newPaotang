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
      <button class="btn btn-primary btn-wave" type="button" :disabled="saving || loading || !reason.trim() || !localItems.length" @click="save">
        <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
        Save menu
      </button>
    </div>
  </div>
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
const reason = ref('')
const scopeLabel = computed(() => titleize(props.scope))

const flatItems = computed(() => flatten(localItems.value))

const reset = () => {
  localItems.value = normalizeMenuItems(props.modelValue)
  reason.value = ''
}

const save = () => {
  emit('save', reason.value.trim(), cleanMenuItems(localItems.value))
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

const cleanMenuItems = (items: EditableMenuItem[]): any[] => items.map((item, index) => ({
  id: item.id,
  key: item.key || item.code,
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

watch(() => props.modelValue, reset, { immediate: true, deep: true })
</script>

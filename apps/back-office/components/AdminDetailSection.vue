<template>
  <div class="card custom-card">
    <div class="card-header">
      <div class="card-title">{{ title }}</div>
    </div>
    <div class="card-body">
      <AdminLoader v-if="loading" />
      <AdminEmptyState v-else-if="!record" title="No detail data" message="This record has no data to display yet." />
      <div v-else class="np-detail-section">
        <AdminDefinitionList v-if="items.length" :items="items" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, defineComponent, h, resolveComponent, type PropType } from 'vue'
import type { OperationColumn } from '~/composables/useAdminOperationsCatalog'
import { formatAdminValue, labelize } from '~/utils/format'

const props = defineProps<{
  title: string
  record?: Record<string, any> | null
  loading?: boolean
  fields?: OperationColumn[]
}>()

type DetailItem = {
  key: string
  label: string
  value: unknown
  mono?: boolean
  type?: OperationColumn['type']
  options?: OperationColumn['options']
}

const isPlainObject = (value: unknown): value is Record<string, unknown> => (
  typeof value === 'object'
  && value !== null
  && !Array.isArray(value)
)

const getPath = (value: any, path: string) => path.split('.').reduce((current, key) => current?.[key], value)
const getFirstPath = (value: any, paths: string[]) => {
  for (const path of paths) {
    const entry = getPath(value, path)
    if (entry !== undefined && entry !== null && entry !== '') {
      return entry
    }
  }
  return undefined
}
const isComplexValue = (value: unknown) => isPlainObject(value) || Array.isArray(value)
const isInlineDisplayType = (type?: OperationColumn['type']) => Boolean(type && type !== 'array')
const isInlineItem = (item: DetailItem) => (
  isInlineDisplayType(item.type)
  || !isComplexValue(item.value)
)
const entryItems = computed<DetailItem[]>(() => {
  const record = props.record || {}
  const fields = props.fields || []

  if (fields.length) {
    return fields.map((field) => ({
      key: field.key,
      label: field.label,
      value: getFirstPath(record, [field.key, ...(field.fallbackKeys || [])]),
      mono: field.key.endsWith('_id') || field.key === 'id',
      type: field.type,
      options: field.options,
    }))
  }

  return Object.entries(record).map(([key, value]) => ({
    key,
    label: labelize(key),
    value,
    mono: key.endsWith('_id') || key === 'id',
  }))
})

const items = computed(() => entryItems.value.filter(isInlineItem))

const complexItems = computed(() => entryItems.value.filter((item) => !isInlineItem(item)))

const AdminReadableValue = defineComponent({
  name: 'AdminReadableValue',
  props: {
    value: {
      type: null as unknown as PropType<unknown>,
      required: true,
    },
    fieldKey: {
      type: String,
      default: '',
    },
  },
  setup(componentProps) {
    const renderPrimitive = (value: unknown, key = componentProps.fieldKey) => h('span', { class: 'text-break' }, formatAdminValue(value, undefined, key))

    const renderObject = (value: Record<string, unknown>) => {
      const entries = Object.entries(value)
      if (!entries.length) {
        return renderPrimitive(null)
      }

      return h('div', { class: 'np-readable-object' }, entries.map(([key, entryValue]) => {
        const label = h('div', { class: 'text-muted fw-semibold small' }, labelize(key))
        const body = isComplexValue(entryValue)
          ? h(AdminReadableValue, { value: entryValue, fieldKey: key })
          : renderPrimitive(entryValue, key)

        return h('div', { class: 'np-readable-field', key }, [label, body])
      }))
    }

    const renderArray = (value: unknown[]) => {
      if (!value.length) {
        return renderPrimitive(null)
      }

      const allObjects = value.every(isPlainObject)
      if (allObjects) {
        const columns = Array.from(new Set(value.flatMap((row) => Object.keys(row as Record<string, unknown>))))
          .map((key) => ({ key, label: labelize(key) }))
        const AdminDataTable = resolveComponent('AdminDataTable')

        return h(AdminDataTable, {
          title: `${formatAdminValue(value.length, 'number')} records`,
          columns,
          rows: value,
          embedded: true,
          emptyTitle: 'No records',
          emptyMessage: 'This list is empty.',
        })
      }

      return h('ol', { class: 'np-readable-list mb-0' }, value.map((item, index) => h('li', { key: index }, [
        isComplexValue(item)
          ? h(AdminReadableValue, { value: item, fieldKey: `${componentProps.fieldKey}.${index}` })
          : renderPrimitive(item, componentProps.fieldKey),
      ])))
    }

    return () => {
      if (Array.isArray(componentProps.value)) {
        return renderArray(componentProps.value)
      }

      if (isPlainObject(componentProps.value)) {
        return renderObject(componentProps.value)
      }

      return renderPrimitive(componentProps.value)
    }
  },
})
</script>

<style scoped>
.np-detail-section {
  display: grid;
  gap: 1rem;
}

.np-detail-groups {
  display: grid;
  gap: 1rem;
}

.np-detail-group {
  border-top: 1px solid var(--default-border);
  padding-top: 1rem;
}

.np-readable-object {
  display: grid;
  gap: .75rem;
}

.np-readable-field {
  display: grid;
  gap: .2rem;
}

.np-readable-list {
  display: grid;
  gap: .5rem;
  padding-inline-start: 1.25rem;
}
</style>

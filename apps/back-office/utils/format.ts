export type AdminDisplayType =
  | 'array'
  | 'boolean'
  | 'datetime'
  | 'image'
  | 'money'
  | 'number'
  | 'object-summary'
  | 'percent'
  | 'permission-list'
  | string

type MoneyValue = {
  amount?: number | string | null
  currency?: string | null
}

const numberFormatter = new Intl.NumberFormat('th-TH')
const moneyFormatter = new Intl.NumberFormat('th-TH', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})
const adminTimeZone = 'Asia/Bangkok'

export const formatDateTime = (value?: string | null) => {
  if (!value) {
    return '-'
  }

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return value
  }

  return new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: adminTimeZone,
  }).format(date)
}

export const titleize = (value: string) => value
  .replace(/[_-]/g, ' ')
  .replace(/\b\w/g, (char) => char.toUpperCase())

export const labelize = (value: string) => titleize(String(value || '-')
  .replace(/[._-]/g, ' '))

const permissionLabel = (value: unknown) => {
  const code = String(value || '').trim()
  if (!code) {
    return '-'
  }

  return `${labelize(code)} (${code})`
}

export const isEmptyAdminValue = (value: unknown) => value === undefined || value === null || value === ''

export const isMoneyValue = (value: unknown): value is MoneyValue => (
  typeof value === 'object'
  && value !== null
  && 'amount' in value
)

const isPlainObject = (value: unknown): value is Record<string, unknown> => (
  typeof value === 'object'
  && value !== null
  && !Array.isArray(value)
)

const isDateTimeKey = (key?: string) => Boolean(key && /(^|_)(at|date|time)$/.test(key))

const formatNumber = (value: unknown) => {
  const number = Number(value)
  return Number.isFinite(number) ? numberFormatter.format(number) : String(value)
}

export const formatMoney = (value: MoneyValue | number | string | null | undefined, currency = 'THB') => {
  if (isEmptyAdminValue(value)) {
    return '-'
  }

  const amount = isMoneyValue(value) ? value.amount : value
  const resolvedCurrency = String((isMoneyValue(value) ? value.currency : currency) || 'THB').toUpperCase()
  const numericAmount = Number(amount)

  if (!Number.isFinite(numericAmount)) {
    return String(amount)
  }

  const displayAmount = isMoneyValue(value) ? numericAmount / 100 : numericAmount
  const currencyLabel = resolvedCurrency === 'THB' ? 'บาท' : resolvedCurrency
  return `${moneyFormatter.format(displayAmount)} ${currencyLabel}`
}

export const summarizeObject = (value: Record<string, unknown> | null | undefined) => {
  if (!value || !Object.keys(value).length) {
    return '-'
  }

  const entries = Object.entries(value)
  const preview = entries
    .slice(0, 4)
    .map(([key, entryValue]) => {
      const label = labelize(key)
      if (isEmptyAdminValue(entryValue)) return `${label}: -`
      if (isMoneyValue(entryValue)) return `${label}: ${formatMoney(entryValue)}`
      if (Array.isArray(entryValue)) return `${label}: ${summarizeArray(entryValue)}`
      if (isPlainObject(entryValue)) return `${label}: ${Object.keys(entryValue).length} fields`
      if (typeof entryValue === 'boolean') return `${label}: ${entryValue ? 'Yes' : 'No'}`
      return `${label}: ${String(entryValue)}`
    })

  const extra = entries.length > preview.length ? `, +${entries.length - preview.length} fields` : ''
  return `${preview.join(', ')}${extra}`
}

export const summarizeArray = (value: unknown[] | null | undefined) => {
  if (!value?.length) {
    return '-'
  }

  const objectCount = value.filter(isPlainObject).length
  const label = objectCount === value.length ? 'records' : 'items'
  const preview = value
    .slice(0, 3)
    .map((item) => {
      if (isMoneyValue(item)) return formatMoney(item)
      if (Array.isArray(item)) return `${item.length} items`
      if (isPlainObject(item)) return summarizeObject(item)
      if (typeof item === 'boolean') return item ? 'Yes' : 'No'
      return String(item)
    })

  const extra = value.length > preview.length ? `, +${value.length - preview.length} more` : ''
  return `${numberFormatter.format(value.length)} ${label}: ${preview.join(', ')}${extra}`
}

export const formatAdminValue = (value: unknown, type?: AdminDisplayType, key?: string): string => {
  if (isEmptyAdminValue(value)) {
    return '-'
  }

  if (type === 'money' || isMoneyValue(value)) {
    return formatMoney(value as MoneyValue | number | string)
  }

  if (type === 'datetime') {
    return formatDateTime(String(value))
  }

  if (type === 'number') {
    return formatNumber(value)
  }

  if (type === 'boolean') {
    return Boolean(value) ? 'Yes' : 'No'
  }

  if (type === 'percent') {
    return `${formatNumber(value)}%`
  }

  if (type === 'permission-list') {
    if (!Array.isArray(value)) {
      return permissionLabel(value)
    }

    const labels = value.map(permissionLabel).filter((item) => item !== '-')
    if (!labels.length) {
      return '-'
    }

    const count = numberFormatter.format(labels.length)
    return `${count} permission${labels.length === 1 ? '' : 's'}: ${labels.join(', ')}`
  }

  if (type === 'image') {
    if (typeof value === 'string') return value
    if (isPlainObject(value)) {
      const url = value.thumb_url || value.full_url || value.url
      return url ? String(url) : 'Image available'
    }
    return 'Image available'
  }

  if (Array.isArray(value) || type === 'array') {
    return summarizeArray(Array.isArray(value) ? value : [value])
  }

  if (isPlainObject(value) || type === 'object-summary') {
    return summarizeObject(value as Record<string, unknown>)
  }

  if (typeof value === 'boolean') {
    return value ? 'Yes' : 'No'
  }

  if (typeof value === 'number') {
    return formatNumber(value)
  }

  if (isDateTimeKey(key) && typeof value === 'string') {
    return formatDateTime(value)
  }

  return String(value)
}

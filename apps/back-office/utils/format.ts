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
  }).format(date)
}

export const titleize = (value: string) => value
  .replace(/[_-]/g, ' ')
  .replace(/\b\w/g, (char) => char.toUpperCase())

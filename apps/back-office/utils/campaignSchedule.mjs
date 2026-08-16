export function dateTimeLocalToIso(value) {
  const date = new Date(String(value || ''))
  if (Number.isNaN(date.getTime())) {
    throw new RangeError('Enter a valid local campaign date and time.')
  }

  return date.toISOString()
}

export function dateToLocalInputValue(date) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    throw new RangeError('Enter a valid campaign date.')
  }

  const offset = date.getTimezoneOffset()
  return new Date(date.getTime() - offset * 60_000).toISOString().slice(0, 16)
}

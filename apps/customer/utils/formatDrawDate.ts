const thaiMonthShortNames: Record<string, string> = {
  มกราคม: 'ม.ค.',
  กุมภาพันธ์: 'ก.พ.',
  มีนาคม: 'มี.ค.',
  เมษายน: 'เม.ย.',
  พฤษภาคม: 'พ.ค.',
  มิถุนายน: 'มิ.ย.',
  กรกฎาคม: 'ก.ค.',
  สิงหาคม: 'ส.ค.',
  กันยายน: 'ก.ย.',
  ตุลาคม: 'ต.ค.',
  พฤศจิกายน: 'พ.ย.',
  ธันวาคม: 'ธ.ค.'
}

const drawDatePrefixPattern = /^(งวดประจำวันที่|งวดวันที่)\s*/u
const fullThaiMonthPattern = new RegExp(Object.keys(thaiMonthShortNames).join('|'), 'gu')
const isoLikeDatePattern = /^\d{4}-\d{2}-\d{2}(?:[T\s].*)?$/u
const thaiShortDateFormatter = new Intl.DateTimeFormat('th-TH', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  timeZone: 'Asia/Bangkok'
})

export const formatDrawDateText = (value: unknown) => {
  if (typeof value !== 'string') {
    return '-'
  }

  const normalizedValue = value.trim().replace(/\s+/g, ' ')

  if (!normalizedValue) {
    return '-'
  }

  if (isoLikeDatePattern.test(normalizedValue)) {
    const parsedDate = new Date(normalizedValue)

    if (!Number.isNaN(parsedDate.getTime())) {
      return thaiShortDateFormatter.format(parsedDate)
    }
  }

  return normalizedValue
    .replace(drawDatePrefixPattern, '')
    .replace(fullThaiMonthPattern, (month) => thaiMonthShortNames[month] || month)
}

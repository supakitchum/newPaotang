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

export const formatDrawDateText = (value: unknown) => {
  if (typeof value !== 'string') {
    return '-'
  }

  const normalizedValue = value.trim().replace(/\s+/g, ' ')

  if (!normalizedValue) {
    return '-'
  }

  return normalizedValue
    .replace(drawDatePrefixPattern, '')
    .replace(fullThaiMonthPattern, (month) => thaiMonthShortNames[month] || month)
}

export interface DepositHistory {
  id?: number | string
  amount?: number | string
  bonus_amount?: number | string
  status?: number | string
  transfer_at?: string
  created_at?: string
  verified_at?: string
  slip?: string
}

export interface WebsiteBank {
  bank_deposit_name?: string
  bank_deposit_number?: string
  bank?: {
    name?: string
  }
}

export const useTopup = () => {
  const toNumber = (value: unknown, fallback = 0) => {
    const number = Number(value)

    return Number.isFinite(number) ? number : fallback
  }

  const formatMoney = (value: number) => new Intl.NumberFormat('th-TH', {
    minimumFractionDigits: value % 1 === 0 ? 0 : 2,
    maximumFractionDigits: 2
  }).format(value)

  const formatDate = (value?: string) => {
    if (!value) {
      return '-'
    }

    const date = new Date(value)

    if (Number.isNaN(date.getTime())) {
      return '-'
    }

    return new Intl.DateTimeFormat('th-TH', {
      dateStyle: 'medium',
      timeStyle: 'short'
    }).format(date)
  }

  const getStatusValue = (status?: number | string) => {
    const value = Number(status)

    return Number.isFinite(value) ? value : -1
  }

  const getStatusText = (status?: number | string) => {
    const value = getStatusValue(status)

    if (value === 1) {
      return 'อนุมัติแล้ว'
    }

    if (value === 2) {
      return 'รอตรวจสอบ'
    }

    return 'ไม่อนุมัติ'
  }

  const getStatusClass = (status?: number | string) => {
    const value = getStatusValue(status)

    if (value === 1 || value === 2 || value === 0) {
      return `status-${value}`
    }

    return 'status-unknown'
  }

  return {
    toNumber,
    formatMoney,
    formatDate,
    getStatusText,
    getStatusClass
  }
}

const normalizeIdentityValue = (value) => {
  const text = String(value ?? '').trim()

  return text && text !== 'null' && text !== 'undefined' ? text : ''
}

export const normalizeStockSearchNumber = (value) => String(value ?? '').replace(/\D/g, '').slice(0, 6)

export const normalizeStockSearchDigit = (value) => String(value ?? '').replace(/\D/g, '').slice(0, 1)

export const normalizeStockSearchDigits = (digits = []) => {
  const values = Array.isArray(digits) ? digits : []

  return Array.from({ length: 6 }, (_, index) => normalizeStockSearchDigit(values[index]))
}

export const isExactSixDigitSearch = (value) => {
  if (Array.isArray(value)) {
    return normalizeStockSearchDigits(value).every(Boolean)
  }

  return normalizeStockSearchNumber(value).length === 6
}

export const buildLegacyStockSearchParams = (input = {}, gameId = '') => {
  const numberFromInput = normalizeStockSearchNumber(input.number)
  const digits = normalizeStockSearchDigits(input.digits)
  const exactDigitNumber = digits.every(Boolean) ? digits.join('') : ''
  const number = numberFromInput || exactDigitNumber
  const digitParams = number
    ? {}
    : digits.reduce((params, digit, index) => {
        if (digit) {
          params[`d${index + 1}`] = digit
        }

        return params
      }, {})
  const hasSearchSignal = Boolean(number) || Object.keys(digitParams).length > 0
  const mode = input.mode || (hasSearchSignal ? 'search' : (input.storeId ? 'browse' : 'random'))

  return {
    game_id: gameId,
    ...(number ? { number } : {}),
    ...digitParams,
    ...(input.storeId ? { store_id: input.storeId } : {}),
    mode,
    ...(input.cursor ? { cursor: input.cursor } : {}),
    ...(input.randomSeed ? { random_seed: input.randomSeed } : {}),
    limit: input.limit || 20
  }
}

export const getStockSearchTicketNumber = (ticket = {}) => {
  const value = ticket.number || ticket.full_number || ticket.lottery_number || ''

  return String(value)
}

export const getStockSearchTicketNumberKey = (ticket = {}) => normalizeStockSearchNumber(getStockSearchTicketNumber(ticket))

export const getStockSearchTicketIdentity = (ticket = {}) => [
  ticket.token,
  ticket.local_stock_item_id,
  ticket.stock_ref,
  ticket.id
].map(normalizeIdentityValue).find(Boolean) || ''

export const mergeStockSearchTickets = (tickets = [], options = {}) => {
  const preserveDuplicateFullNumbers = Boolean(options.preserveDuplicateFullNumbers)
  const seen = new Set()

  return tickets.filter((ticket, index) => {
    const identity = getStockSearchTicketIdentity(ticket)

    if (preserveDuplicateFullNumbers) {
      const key = identity || `row:${getStockSearchTicketNumberKey(ticket)}:${index}`

      if (seen.has(key)) {
        return false
      }

      seen.add(key)

      return true
    }

    const number = getStockSearchTicketNumberKey(ticket)

    if (!number || seen.has(number)) {
      return false
    }

    seen.add(number)

    return true
  })
}

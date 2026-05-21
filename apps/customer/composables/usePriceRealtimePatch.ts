import type { Ref } from 'vue'

type PricePatchTicket = {
  price?: number | string
  priceTrend?: 'up' | 'down' | null
  priceFlashKey?: number | null
  game_id?: number | string | null
}

type PricePatchOptions = {
  gameId?: string | { value: string }
}

const priceDisplayFromPayload = (payload: any) => {
  const rawAmount = Number(payload?.price?.amount ?? payload?.price_amount ?? payload?.amount)

  if (!Number.isFinite(rawAmount) || rawAmount <= 0) {
    return 0
  }

  return rawAmount >= 1000 ? rawAmount / 100 : rawAmount
}

export const usePriceRealtimePatch = () => {
  const applyPriceUpdateToTickets = <T extends PricePatchTicket>(tickets: Ref<T[]>, payload: any, options: PricePatchOptions = {}) => {
    if (Number(payload?.set_size ?? 1) !== 1) {
      return
    }

    const payloadGameId = String(payload?.game_id || '').trim()
    const currentGameId = String(readPricePatchValue(options.gameId) || '').trim()
    if (payloadGameId && currentGameId && payloadGameId !== currentGameId) {
      return
    }

    const nextPrice = priceDisplayFromPayload(payload)

    if (nextPrice <= 0) {
      return
    }

    const flashKey = Date.now()
    let changed = false

    tickets.value = tickets.value.map((ticket) => {
      const ticketGameId = String(ticket.game_id || '').trim()
      if (payloadGameId && ticketGameId && ticketGameId !== payloadGameId) {
        return ticket
      }

      const currentPrice = Number(ticket.price)

      if (!Number.isFinite(currentPrice) || currentPrice <= 0 || currentPrice === nextPrice) {
        return currentPrice === nextPrice ? ticket : { ...ticket, price: nextPrice }
      }

      changed = true

      return {
        ...ticket,
        price: nextPrice,
        priceTrend: nextPrice > currentPrice ? 'up' : 'down',
        priceFlashKey: flashKey
      }
    })

    if (!changed || !import.meta.client) {
      return
    }

    window.setTimeout(() => {
      tickets.value = tickets.value.map((ticket) => (
        ticket.priceFlashKey === flashKey
          ? { ...ticket, priceTrend: null, priceFlashKey: null }
          : ticket
      ))
    }, 2000)
  }

  return {
    applyPriceUpdateToTickets
  }
}

const readPricePatchValue = <T>(source: T | { value: T } | undefined) => (
  source && typeof source === 'object' && 'value' in source ? source.value : source
)

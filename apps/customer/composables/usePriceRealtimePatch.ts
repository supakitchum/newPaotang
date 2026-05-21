import type { Ref } from 'vue'

type PricePatchTicket = {
  price?: number | string
  priceTrend?: 'up' | 'down' | null
  priceFlashKey?: number | null
}

const priceDisplayFromPayload = (payload: any) => {
  const rawAmount = Number(payload?.price?.amount ?? payload?.price_amount ?? payload?.amount)

  if (!Number.isFinite(rawAmount) || rawAmount <= 0) {
    return 0
  }

  return rawAmount >= 1000 ? rawAmount / 100 : rawAmount
}

export const usePriceRealtimePatch = () => {
  const applyPriceUpdateToTickets = <T extends PricePatchTicket>(tickets: Ref<T[]>, payload: any) => {
    if (Number(payload?.set_size ?? 1) !== 1) {
      return
    }

    const nextPrice = priceDisplayFromPayload(payload)

    if (nextPrice <= 0) {
      return
    }

    const flashKey = Date.now()
    let changed = false

    tickets.value = tickets.value.map((ticket) => {
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

export const useCustomerPresence = () => {
  const onlineCount = useState<number>('customer_presence_online_count', () => 0)
  const lastUpdatedAt = useState<string>('customer_presence_updated_at', () => '')

  const setOnlineCount = (value: unknown) => {
    const count = Number(value)

    onlineCount.value = Number.isFinite(count) && count > 0 ? Math.floor(count) : 0
    lastUpdatedAt.value = new Date().toISOString()
  }

  const clearOnlineCount = () => {
    onlineCount.value = 0
    lastUpdatedAt.value = ''
  }

  return {
    onlineCount,
    lastUpdatedAt,
    setOnlineCount,
    clearOnlineCount
  }
}

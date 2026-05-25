type CustomerRealtimeStatus = 'idle' | 'unavailable' | 'connecting' | 'authenticating' | 'connected' | 'reconnecting' | 'error'

type RealtimeValue<T> = T | { value: T }

type CustomerStockRealtimeOptions = {
  gameId?: RealtimeValue<string>
  enabled?: RealtimeValue<boolean>
  onAvailability?: (payload: any) => void
  onPrice?: (payload: any) => void
  onTopup?: (payload: any) => void
  includePresence?: RealtimeValue<boolean>
  onReconnect?: () => void
}

export const useCustomerStockRealtime = (options: CustomerStockRealtimeOptions) => {
  const config = useRuntimeConfig()
  const { config: siteConfig } = useSiteConfig()
  const axios = useAxios()
  const { user, isAuthenticated } = useAuth()
  const { setOnlineCount } = useCustomerPresence()
  const status = ref<CustomerRealtimeStatus>('idle')
  const error = ref('')
  const lastEventAt = ref('')
  const realtimeUrl = computed(() => String(config.public.customerRealtimeUrl || '').trim())
  const realtimeKey = computed(() => String(config.public.customerRealtimeKey || 'newpaotang-customer').trim() || 'newpaotang-customer')
  const isConfigured = computed(() => Boolean(realtimeUrl.value))
  const gameId = computed(() => (options.gameId === undefined ? '' : readRealtimeValue(options.gameId)).trim())
  const enabled = computed(() => options.enabled === undefined ? true : Boolean(readRealtimeValue(options.enabled)))
  const includePresence = computed(() => options.includePresence === undefined ? false : Boolean(readRealtimeValue(options.includePresence)))
  const tenantId = computed(() => tenantIdFromSiteConfig(siteConfig.value) || tenantIdFromUser(user.value))
  const customerId = computed(() => customerIdFromUser(user.value))
  const stockChannelName = computed(() => {
    if (!options.onAvailability || !gameId.value || !tenantId.value) {
      return ''
    }

    return `customer.tenant.${tenantId.value}.stock.game.${gameId.value}`
  })
  const salePriceChannelName = computed(() => {
    if (!options.onPrice || !tenantId.value) {
      return ''
    }

    return `customer.tenant.${tenantId.value}.sale-price`
  })
  const topupChannelName = computed(() => {
    if (!options.onTopup || !tenantId.value || !customerId.value || !isAuthenticated.value) {
      return ''
    }

    return `private-customer.tenant.${tenantId.value}.customer.${customerId.value}.topups`
  })
  const presenceChannelName = computed(() => {
    if (!includePresence.value || !tenantId.value || !isAuthenticated.value) {
      return ''
    }

    return `presence-customer.tenant.${tenantId.value}.customers`
  })
  const channelNames = computed(() => [stockChannelName.value, salePriceChannelName.value, topupChannelName.value, presenceChannelName.value].filter(Boolean))
  const shouldSubscribe = computed(() => Boolean(import.meta.client && enabled.value && tenantId.value && channelNames.value.length))

  let socket: WebSocket | null = null
  let socketId = ''
  let currentSocketUrl = ''
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let hasConnectedOnce = false
  let socketConnectionMarked = false
  let presenceMemberIds = new Set<string>()
  const subscribedChannels = new Set<string>()
  const subscribingChannels = new Set<string>()

  watch(
    () => [shouldSubscribe.value, isConfigured.value, realtimeUrl.value, realtimeKey.value],
    () => {
      if (!shouldSubscribe.value) {
        disconnect('idle')
        return
      }

      if (!isConfigured.value) {
        disconnect('unavailable')
        return
      }

      connect()
    },
    { immediate: true },
  )

  watch(
    () => channelNames.value.join('|'),
    () => syncPublicChannels(socket),
  )

  onBeforeUnmount(() => disconnect('idle'))

  function connect(reconnecting = false) {
    if (!import.meta.client || !shouldSubscribe.value || !isConfigured.value) {
      disconnect(shouldSubscribe.value ? 'unavailable' : 'idle')
      return
    }

    const nextSocketUrl = buildRealtimeSocketUrl(realtimeUrl.value, realtimeKey.value)
    if (socket && currentSocketUrl === nextSocketUrl && [WebSocket.CONNECTING, WebSocket.OPEN].includes(socket.readyState)) {
      syncPublicChannels(socket)
      return
    }

    stopReconnectTimer()
    cleanupSocket(true)
    error.value = ''
    status.value = reconnecting ? 'reconnecting' : 'connecting'

    try {
      currentSocketUrl = nextSocketUrl
      socket = new WebSocket(nextSocketUrl)
    } catch (err: any) {
      currentSocketUrl = ''
      error.value = err?.message || 'Realtime connection failed.'
      status.value = 'error'
      scheduleReconnect()
      return
    }

    const activeSocket = socket
    socketConnectionMarked = false
    activeSocket.addEventListener('message', (event) => {
      if (activeSocket === socket) {
        void handleMessage(activeSocket, event.data)
      }
    })
    activeSocket.addEventListener('error', () => {
      if (activeSocket === socket) {
        status.value = 'error'
        error.value = 'Realtime connection failed.'
      }
    })
    activeSocket.addEventListener('close', () => {
      if (activeSocket !== socket) {
        return
      }

      socket = null
      socketId = ''
      currentSocketUrl = ''
      socketConnectionMarked = false
      subscribedChannels.clear()
      if (shouldSubscribe.value && isConfigured.value) {
        scheduleReconnect()
      } else {
        status.value = shouldSubscribe.value ? 'unavailable' : 'idle'
      }
    })
  }

  async function handleMessage(activeSocket: WebSocket, raw: any) {
    const message = parseRealtimeMessage(raw)

    if (message.event === 'pusher:connection_established') {
      const data = parseRealtimeData(message.data)
      socketId = String(data?.socket_id || '').trim()
      syncPublicChannels(activeSocket)
      return
    }

    if (message.event === 'pusher:ping') {
      sendRealtime(activeSocket, { event: 'pusher:pong', data: {} })
      return
    }

    if (message.event === 'pusher_internal:subscription_succeeded') {
      if (String(message.channel || '') === presenceChannelName.value) {
        updatePresenceFromSubscription(parseRealtimeData(message.data))
      }

      markConnected()
      return
    }

    const normalizedEvent = normalizeEventName(message.event)
    const channel = String(message.channel || '')

    if (channel === presenceChannelName.value && normalizedEvent === 'pusher_internal:member_added') {
      updatePresenceMember(parseRealtimeData(message.data), true)
      return
    }

    if (channel === presenceChannelName.value && normalizedEvent === 'pusher_internal:member_removed') {
      updatePresenceMember(parseRealtimeData(message.data), false)
      return
    }

    if (normalizedEvent === 'stock.availability.updated') {
      lastEventAt.value = new Date().toISOString()
      options.onAvailability?.(parseRealtimeData(message.data))
    }

    if (normalizedEvent === 'stock.price.updated') {
      lastEventAt.value = new Date().toISOString()
      options.onPrice?.(parseRealtimeData(message.data))
    }

    if (normalizedEvent === 'topup.updated') {
      lastEventAt.value = new Date().toISOString()
      options.onTopup?.(parseRealtimeData(message.data))
    }
  }

  function syncPublicChannels(activeSocket: WebSocket | null) {
    if (activeSocket !== socket || !activeSocket || activeSocket.readyState !== WebSocket.OPEN || !socketId) {
      return
    }

    const desiredChannels = new Set(channelNames.value)

    for (const channel of [...subscribedChannels]) {
      if (desiredChannels.has(channel)) {
        continue
      }

      sendRealtime(activeSocket, {
        event: 'pusher:unsubscribe',
        data: {
          channel,
        },
      })
      subscribedChannels.delete(channel)
      subscribingChannels.delete(channel)
      if (channel === presenceChannelName.value) {
        presenceMemberIds.clear()
      }
    }

    if (!shouldSubscribe.value) {
      return
    }

    for (const channel of desiredChannels) {
      if (subscribedChannels.has(channel) || subscribingChannels.has(channel)) {
        continue
      }

      void subscribeChannel(activeSocket, channel)
    }
  }

  async function subscribeChannel(activeSocket: WebSocket, channel: string) {
    if (activeSocket !== socket || activeSocket.readyState !== WebSocket.OPEN || !socketId) {
      return
    }

    subscribingChannels.add(channel)

    try {
      const subscriptionData: Record<string, any> = { channel }

      if (isAuthorizedChannel(channel)) {
        status.value = 'authenticating'
        const authorization = await authorizeRealtimeChannel(channel)
        subscriptionData.auth = authorization.auth

        if (authorization.channel_data) {
          subscriptionData.channel_data = authorization.channel_data
        }
      }

      if (activeSocket !== socket || activeSocket.readyState !== WebSocket.OPEN) {
        return
      }

      sendRealtime(activeSocket, {
        event: 'pusher:subscribe',
        data: subscriptionData,
      })
      subscribedChannels.add(channel)
    } catch (err: any) {
      error.value = err?.response?.data?.message || err?.message || 'Realtime channel authorization failed.'
      status.value = 'error'
    } finally {
      subscribingChannels.delete(channel)
    }
  }

  async function authorizeRealtimeChannel(channel: string) {
    const response = await axios.post('/customer/realtime/auth', {
      socket_id: socketId,
      channel_name: channel,
    })

    return response?.data?.data || response?.data || {}
  }

  function markConnected() {
    if (socketConnectionMarked) {
      return
    }

    socketConnectionMarked = true
    const wasReconnect = hasConnectedOnce
    hasConnectedOnce = true
    status.value = 'connected'

    if (wasReconnect) {
      options.onReconnect?.()
    }
  }

  function scheduleReconnect() {
    if (!import.meta.client || reconnectTimer !== null || !shouldSubscribe.value || !isConfigured.value) {
      return
    }

    status.value = 'reconnecting'
    reconnectTimer = window.setTimeout(() => {
      reconnectTimer = null
      connect(true)
    }, 10000)
  }

  function disconnect(finalStatus: CustomerRealtimeStatus = 'idle') {
    stopReconnectTimer()
    cleanupSocket(true)
    socketId = ''
    currentSocketUrl = ''
    socketConnectionMarked = false
    status.value = finalStatus
  }

  function cleanupSocket(sendUnsubscribe = false) {
    const activeSocket = socket
    socket = null
    socketId = ''
    currentSocketUrl = ''
    socketConnectionMarked = false
    if (!activeSocket) {
      return
    }

    if (sendUnsubscribe && activeSocket.readyState === WebSocket.OPEN) {
      for (const channel of subscribedChannels) {
        sendRealtime(activeSocket, { event: 'pusher:unsubscribe', data: { channel } })
      }
    }

    subscribedChannels.clear()
    subscribingChannels.clear()
    presenceMemberIds.clear()
    activeSocket.close()
  }

  function updatePresenceFromSubscription(data: any) {
    const presence = data?.presence || data || {}
    const ids = Array.isArray(presence.ids)
      ? presence.ids.map((id: unknown) => String(id)).filter(Boolean)
      : Object.keys(presence.hash || {})
    const count = Number(presence.count)

    presenceMemberIds = new Set(ids)
    setOnlineCount(Number.isFinite(count) ? count : presenceMemberIds.size)
  }

  function updatePresenceMember(data: any, isOnline: boolean) {
    const userId = String(data?.user_id || data?.member?.user_id || data?.id || '').trim()

    if (!userId) {
      return
    }

    if (isOnline) {
      presenceMemberIds.add(userId)
    } else {
      presenceMemberIds.delete(userId)
    }

    setOnlineCount(presenceMemberIds.size)
  }

  function stopReconnectTimer() {
    if (reconnectTimer !== null && import.meta.client) {
      window.clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
  }

  return {
    status,
    error,
    isConfigured,
    lastEventAt,
    connect,
    disconnect,
  }
}

const readRealtimeValue = <T>(source: RealtimeValue<T>) => (
  source && typeof source === 'object' && 'value' in source ? source.value : source
)

const normalizeEventName = (eventName: string) => String(eventName || '').replace(/^\./, '')

const isAuthorizedChannel = (channel: string) => channel.startsWith('private-') || channel.startsWith('presence-')

const sendRealtime = (socket: WebSocket, payload: any) => {
  socket.send(JSON.stringify(payload))
}

const parseRealtimeMessage = (raw: any) => {
  try {
    return typeof raw === 'string' ? JSON.parse(raw) : raw
  } catch {
    return {}
  }
}

const parseRealtimeData = (raw: any) => {
  if (raw === null || raw === undefined || raw === '') {
    return {}
  }

  if (typeof raw !== 'string') {
    return raw
  }

  try {
    return JSON.parse(raw)
  } catch {
    return { value: raw }
  }
}

const buildRealtimeSocketUrl = (baseUrl: string, key: string) => {
  let url = baseUrl.trim().replace(/^http:/, 'ws:').replace(/^https:/, 'wss:')
  if (!url.includes('/app/')) {
    url = `${url.replace(/\/$/, '')}/app/${encodeURIComponent(key)}`
  }

  const separator = url.includes('?') ? '&' : '?'
  if (url.includes('protocol=')) {
    return url
  }

  return `${url}${separator}protocol=7&client=newpaotang-customer&version=1.0&flash=false`
}

const tenantIdFromUser = (user: Record<string, unknown> | null | undefined) => {
  if (!user) {
    return ''
  }

  return String(user.tenant_id || user.tenantId || '')
}

const customerIdFromUser = (user: Record<string, unknown> | null | undefined) => {
  if (!user) {
    return ''
  }

  return String(user.id || user.customer_id || user.customerId || '')
}

const tenantIdFromSiteConfig = (siteConfig: Record<string, unknown> | null | undefined) => {
  if (!siteConfig) {
    return ''
  }

  const tenant = siteConfig.tenant

  if (tenant && typeof tenant === 'object' && !Array.isArray(tenant)) {
    return String((tenant as Record<string, unknown>).id || '')
  }

  return String(siteConfig.tenant_id || siteConfig.tenantId || '')
}

type CustomerRealtimeStatus = 'idle' | 'unavailable' | 'connecting' | 'authenticating' | 'connected' | 'reconnecting' | 'error'

type RealtimeValue<T> = T | { value: T }

type CustomerStockRealtimeOptions = {
  gameId: RealtimeValue<string>
  enabled?: RealtimeValue<boolean>
  onAvailability: (payload: any) => void
  onPrice?: (payload: any) => void
  onReconnect?: () => void
}

export const useCustomerStockRealtime = (options: CustomerStockRealtimeOptions) => {
  const config = useRuntimeConfig()
  const axios = useAxios()
  const { token, user } = useAuth()
  const status = ref<CustomerRealtimeStatus>('idle')
  const error = ref('')
  const lastEventAt = ref('')
  const realtimeUrl = computed(() => String(config.public.customerRealtimeUrl || '').trim())
  const realtimeKey = computed(() => String(config.public.customerRealtimeKey || 'newpaotang-customer').trim() || 'newpaotang-customer')
  const isConfigured = computed(() => Boolean(realtimeUrl.value))
  const gameId = computed(() => readRealtimeValue(options.gameId).trim())
  const enabled = computed(() => options.enabled === undefined ? true : Boolean(readRealtimeValue(options.enabled)))
  const tenantId = computed(() => tenantIdFromUser(user.value) || tenantIdFromToken(token.value))
  const channelName = computed(() => gameId.value ? `private-customer.tenant.${tenantId.value}.stock.game.${gameId.value}` : '')
  const shouldSubscribe = computed(() => Boolean(import.meta.client && enabled.value && token.value && gameId.value && tenantId.value))

  let socket: WebSocket | null = null
  let socketId = ''
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let hasConnectedOnce = false

  watch(
    () => [shouldSubscribe.value, isConfigured.value, gameId.value, token.value, tenantId.value],
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

  onBeforeUnmount(() => disconnect('idle'))

  function connect(reconnecting = false) {
    if (!import.meta.client || !shouldSubscribe.value || !isConfigured.value) {
      disconnect(shouldSubscribe.value ? 'unavailable' : 'idle')
      return
    }

    stopReconnectTimer()
    cleanupSocket()
    error.value = ''
    status.value = reconnecting ? 'reconnecting' : 'connecting'

    try {
      socket = new WebSocket(buildRealtimeSocketUrl(realtimeUrl.value, realtimeKey.value))
    } catch (err: any) {
      error.value = err?.message || 'Realtime connection failed.'
      status.value = 'error'
      scheduleReconnect()
      return
    }

    const activeSocket = socket
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
      await authenticateChannel(activeSocket)
      return
    }

    if (message.event === 'pusher:ping') {
      sendRealtime(activeSocket, { event: 'pusher:pong', data: {} })
      return
    }

    if (message.event === 'pusher_internal:subscription_succeeded') {
      markConnected()
      return
    }

    if (normalizeEventName(message.event) === 'stock.availability.updated') {
      lastEventAt.value = new Date().toISOString()
      options.onAvailability(parseRealtimeData(message.data))
    }

    if (normalizeEventName(message.event) === 'stock.price.updated') {
      lastEventAt.value = new Date().toISOString()
      options.onPrice?.(parseRealtimeData(message.data))
    }
  }

  async function authenticateChannel(activeSocket: WebSocket) {
    if (!socketId || activeSocket !== socket || activeSocket.readyState !== WebSocket.OPEN) {
      return
    }

    status.value = 'authenticating'

    try {
      const response = await axios.post('/customer/realtime/auth', {
        socket_id: socketId,
        channel_name: channelName.value,
      })
      const authorization = response?.data?.data ?? response?.data

      if (activeSocket !== socket || activeSocket.readyState !== WebSocket.OPEN) {
        return
      }

      sendRealtime(activeSocket, {
        event: 'pusher:subscribe',
        data: {
          channel: channelName.value,
          auth: authorization?.auth,
          channel_data: authorization?.channel_data || undefined,
        },
      })
    } catch (err: any) {
      error.value = err?.message || 'Realtime channel authorization failed.'
      status.value = 'error'
      cleanupSocket()
      if (![401, 403].includes(Number(err?.response?.status))) {
        scheduleReconnect()
      }
    }
  }

  function markConnected() {
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
    status.value = finalStatus
  }

  function cleanupSocket(sendUnsubscribe = false) {
    const activeSocket = socket
    socket = null
    if (!activeSocket) {
      return
    }

    if (sendUnsubscribe && activeSocket.readyState === WebSocket.OPEN && channelName.value) {
      sendRealtime(activeSocket, { event: 'pusher:unsubscribe', data: { channel: channelName.value } })
    }

    activeSocket.close()
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

const tenantIdFromToken = (token: string | null | undefined) => {
  if (!token || !token.includes('.')) {
    return ''
  }

  try {
    const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')))

    return String(payload?.tenant_id || payload?.tenantId || '')
  } catch {
    return ''
  }
}

const tenantIdFromUser = (user: Record<string, unknown> | null | undefined) => {
  if (!user) {
    return ''
  }

  return String(user.tenant_id || user.tenantId || '')
}

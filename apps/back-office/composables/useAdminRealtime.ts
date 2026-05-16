type AdminRealtimeStatus = 'idle' | 'unavailable' | 'connecting' | 'authenticating' | 'connected' | 'reconnecting' | 'error'

type RealtimeValue<T> = T | { value: T }

type AdminRealtimeSubscriptionOptions = {
  channelName: RealtimeValue<string>
  eventName: string
  enabled?: RealtimeValue<boolean>
  onEvent: (payload: any) => void
  onReconnect?: () => void
  reconnectDelayMs?: number
}

export const useAdminRealtimeSubscription = (options: AdminRealtimeSubscriptionOptions) => {
  const config = useRuntimeConfig()
  const api = useAdminApi()
  const session = useAdminSession()
  const status = ref<AdminRealtimeStatus>('idle')
  const error = ref('')
  const lastConnectedAt = ref('')
  const lastEventAt = ref('')
  const realtimeUrl = computed(() => String(config.public.adminRealtimeUrl || '').trim())
  const realtimeKey = computed(() => String(config.public.adminRealtimeKey || 'newpaotang-admin').trim() || 'newpaotang-admin')
  const isConfigured = computed(() => Boolean(realtimeUrl.value))
  const channelName = computed(() => readRealtimeValue(options.channelName).trim())
  const enabled = computed(() => options.enabled === undefined ? true : Boolean(readRealtimeValue(options.enabled)))
  const shouldSubscribe = computed(() => Boolean(import.meta.client && enabled.value && channelName.value && session.session.value.accessToken))

  let socket: WebSocket | null = null
  let socketId = ''
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let hasConnectedOnce = false

  watch(
    () => [shouldSubscribe.value, isConfigured.value, channelName.value, session.session.value.accessToken],
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

  onBeforeUnmount(() => {
    disconnect('idle')
  })

  function connect(reconnecting = false) {
    if (!import.meta.client || !shouldSubscribe.value) {
      disconnect('idle')
      return
    }

    if (!isConfigured.value) {
      disconnect('unavailable')
      return
    }

    stopReconnectTimer()
    cleanupSocket()
    error.value = ''
    status.value = reconnecting ? 'reconnecting' : 'connecting'

    try {
      socket = new WebSocket(buildRealtimeSocketUrl(realtimeUrl.value, realtimeKey.value))
    } catch (err: any) {
      error.value = readableRealtimeError(err)
      status.value = 'error'
      scheduleReconnect()
      return
    }

    const activeSocket = socket
    activeSocket.addEventListener('message', (event) => {
      if (activeSocket !== socket) {
        return
      }

      void handleMessage(activeSocket, event.data)
    })
    activeSocket.addEventListener('error', () => {
      if (activeSocket !== socket) {
        return
      }

      error.value = 'Realtime connection failed.'
      status.value = 'error'
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
    if (!message.event) {
      return
    }

    if (message.event === 'pusher:connection_established') {
      const data = parseRealtimeData(message.data)
      socketId = String(data?.socket_id || '').trim()
      if (!socketId) {
        error.value = 'Realtime connection did not return a socket id.'
        status.value = 'error'
        cleanupSocket()
        scheduleReconnect()
        return
      }

      await authenticateChannel(activeSocket)
      return
    }

    if (message.event === 'pusher:ping') {
      sendRealtime(activeSocket, { event: 'pusher:pong', data: {} })
      return
    }

    if (message.event === 'pusher:error') {
      const data = parseRealtimeData(message.data)
      error.value = String(data?.message || 'Realtime subscription failed.')
      status.value = 'error'
      return
    }

    if (message.event === 'pusher_internal:subscription_succeeded') {
      markConnected()
      return
    }

    if (normalizeEventName(message.event) === normalizeEventName(options.eventName)) {
      lastEventAt.value = new Date().toISOString()
      options.onEvent(parseRealtimeData(message.data))
    }
  }

  async function authenticateChannel(activeSocket: WebSocket) {
    if (!socketId || activeSocket !== socket || activeSocket.readyState !== WebSocket.OPEN) {
      return
    }

    status.value = 'authenticating'
    try {
      const authorization = await api.apiFetch('/admin/central/realtime/auth', {
        method: 'POST',
        scope: 'central',
        body: {
          socket_id: socketId,
          channel_name: channelName.value,
        },
        successMessage: false,
      })
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
      if (err?.status === 401 || err?.status === 403) {
        return
      }
      scheduleReconnect()
    }
  }

  function markConnected() {
    if (status.value === 'connected') {
      return
    }

    const wasReconnect = hasConnectedOnce
    hasConnectedOnce = true
    status.value = 'connected'
    lastConnectedAt.value = new Date().toISOString()
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
    }, Math.max(3000, options.reconnectDelayMs || 10000))
  }

  function disconnect(finalStatus: AdminRealtimeStatus = 'idle') {
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
      sendRealtime(activeSocket, {
        event: 'pusher:unsubscribe',
        data: { channel: channelName.value },
      })
    }

    activeSocket.close()
  }

  function stopReconnectTimer() {
    if (reconnectTimer === null || !import.meta.client) {
      return
    }

    window.clearTimeout(reconnectTimer)
    reconnectTimer = null
  }

  return {
    status,
    error,
    isConfigured,
    lastConnectedAt,
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

  return `${url}${separator}protocol=7&client=newpaotang-bo&version=1.0&flash=false`
}

const readableRealtimeError = (err: any) => (
  err?.message ? String(err.message) : 'Realtime connection failed.'
)

type RewardLiveRealtimeStatus = 'idle' | 'unavailable' | 'connecting' | 'connected' | 'reconnecting' | 'error'

type RealtimeValue<T> = T | { value: T }

type RewardLiveRealtimeOptions = {
  gameId?: RealtimeValue<string>
  enabled?: RealtimeValue<boolean>
  onResult?: (payload: any) => void
  onReconnect?: () => void
}

export const useRewardLivePublicRealtime = (options: RewardLiveRealtimeOptions = {}) => {
  const config = useRuntimeConfig()
  const status = ref<RewardLiveRealtimeStatus>('idle')
  const error = ref('')
  const lastEventAt = ref('')
  const realtimeUrl = computed(() => String(config.public.adminRealtimeUrl || '').trim())
  const realtimeKey = computed(() => String(config.public.adminRealtimeKey || 'newpaotang-admin').trim() || 'newpaotang-admin')
  const enabled = computed(() => options.enabled === undefined ? true : Boolean(readRealtimeValue(options.enabled)))
  const gameId = computed(() => String(options.gameId === undefined ? '' : readRealtimeValue(options.gameId)).trim())
  const isConfigured = computed(() => Boolean(realtimeUrl.value))
  const channelNames = computed(() => [
    'public.results.latest',
    gameId.value ? `public.results.game.${gameId.value}` : '',
  ].filter(Boolean))
  const shouldSubscribe = computed(() => Boolean(import.meta.client && enabled.value && channelNames.value.length))

  let socket: WebSocket | null = null
  let socketId = ''
  let currentSocketUrl = ''
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let currentConnectionMarked = false
  let currentConnectionIsReconnect = false
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
    () => syncChannels(socket),
  )

  onBeforeUnmount(() => disconnect('idle'))

  function connect(reconnecting = false) {
    if (!import.meta.client || !shouldSubscribe.value || !isConfigured.value) {
      disconnect(shouldSubscribe.value ? 'unavailable' : 'idle')
      return
    }

    const nextSocketUrl = buildRealtimeSocketUrl(realtimeUrl.value, realtimeKey.value)
    if (socket && currentSocketUrl === nextSocketUrl && [WebSocket.CONNECTING, WebSocket.OPEN].includes(socket.readyState)) {
      syncChannels(socket)
      return
    }

    stopReconnectTimer()
    cleanupSocket(true)
    error.value = ''
    status.value = reconnecting ? 'reconnecting' : 'connecting'
    currentSocketUrl = nextSocketUrl
    currentConnectionMarked = false
    currentConnectionIsReconnect = reconnecting
    socket = new WebSocket(nextSocketUrl)

    const activeSocket = socket
    activeSocket.addEventListener('message', (event) => {
      if (activeSocket === socket) {
        handleMessage(activeSocket, event.data)
      }
    })
    activeSocket.addEventListener('error', () => {
      if (activeSocket === socket) {
        status.value = 'error'
        error.value = 'Reward realtime connection failed.'
      }
    })
    activeSocket.addEventListener('close', () => {
      if (activeSocket !== socket) {
        return
      }

      socket = null
      socketId = ''
      currentSocketUrl = ''
      currentConnectionMarked = false
      currentConnectionIsReconnect = false
      subscribedChannels.clear()
      subscribingChannels.clear()
      if (shouldSubscribe.value && isConfigured.value) {
        scheduleReconnect()
      } else {
        status.value = shouldSubscribe.value ? 'unavailable' : 'idle'
      }
    })
  }

  function handleMessage(activeSocket: WebSocket, raw: any) {
    const message = parseRealtimeMessage(raw)

    if (message.event === 'pusher:connection_established') {
      const data = parseRealtimeData(message.data)
      socketId = String(data?.socket_id || '').trim()
      syncChannels(activeSocket)
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

    if (normalizeEventName(message.event) === 'reward.result.live.updated') {
      lastEventAt.value = new Date().toISOString()
      options.onResult?.(parseRealtimeData(message.data))
    }
  }

  function syncChannels(activeSocket: WebSocket | null) {
    if (activeSocket !== socket || !activeSocket || activeSocket.readyState !== WebSocket.OPEN || !socketId) {
      return
    }

    const desiredChannels = new Set(channelNames.value)

    for (const channel of [...subscribedChannels]) {
      if (desiredChannels.has(channel)) {
        continue
      }

      sendRealtime(activeSocket, { event: 'pusher:unsubscribe', data: { channel } })
      subscribedChannels.delete(channel)
      subscribingChannels.delete(channel)
    }

    for (const channel of desiredChannels) {
      if (subscribedChannels.has(channel) || subscribingChannels.has(channel)) {
        continue
      }

      subscribingChannels.add(channel)
      sendRealtime(activeSocket, {
        event: 'pusher:subscribe',
        data: { channel },
      })
      subscribedChannels.add(channel)
      subscribingChannels.delete(channel)
    }
  }

  function markConnected() {
    if (currentConnectionMarked) {
      status.value = 'connected'
      return
    }

    const wasReconnect = currentConnectionIsReconnect
    currentConnectionMarked = true
    currentConnectionIsReconnect = false
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

  function disconnect(finalStatus: RewardLiveRealtimeStatus = 'idle') {
    stopReconnectTimer()
    cleanupSocket(true)
    socketId = ''
    currentSocketUrl = ''
    currentConnectionMarked = false
    currentConnectionIsReconnect = false
    status.value = finalStatus
  }

  function cleanupSocket(sendUnsubscribe = false) {
    const activeSocket = socket
    socket = null
    socketId = ''
    currentSocketUrl = ''
    currentConnectionMarked = false
    currentConnectionIsReconnect = false

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

  return `${url}${separator}protocol=7&client=newpaotang-bo-reward-live&version=1.0&flash=false`
}

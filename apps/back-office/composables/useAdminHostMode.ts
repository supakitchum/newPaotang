const partnerBoPrefix = 'bo.'

export const useAdminHostMode = () => {
  const config = useRuntimeConfig()
  const requestHeaders = import.meta.server ? useRequestHeaders(['host']) : {}

  const host = computed(() => {
    const currentHost = import.meta.client ? window.location.hostname : requestHeaders.host
    return normalizeAdminHost(currentHost)
  })
  const isPartnerBoHost = computed(() => host.value.startsWith(partnerBoPrefix) && host.value.length > partnerBoPrefix.length)
  const storefrontHost = computed(() => isPartnerBoHost.value ? host.value.slice(partnerBoPrefix.length) : '')
  const adminApiBase = computed(() => (
    isPartnerBoHost.value
      ? '/api/v1'
      : String(config.public.adminApiBase || '').replace(/\/$/, '')
  ))

  return {
    host,
    isPartnerBoHost,
    storefrontHost,
    adminApiBase,
  }
}

const normalizeAdminHost = (host: unknown) => {
  const value = String(host || '').trim().toLowerCase()

  try {
    return new URL(`http://${value}`).hostname.toLowerCase()
  } catch {
    return value.replace(/:\d+$/, '')
  }
}

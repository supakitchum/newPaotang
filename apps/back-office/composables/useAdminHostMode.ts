const partnerBoPrefix = 'bo.'

export const useAdminHostMode = () => {
  const config = useRuntimeConfig()
  const requestUrl = useRequestURL()

  const host = computed(() => {
    const currentHost = import.meta.client ? window.location.hostname : requestUrl.hostname
    return String(currentHost || '').toLowerCase()
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

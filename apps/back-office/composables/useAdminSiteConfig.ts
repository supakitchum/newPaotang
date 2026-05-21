type AdminSiteConfigParty = {
  id?: string | null
  code?: string | null
  name?: string | null
}

type AdminSiteConfigDomain = {
  storefront_host?: string | null
  bo_host?: string | null
}

type AdminSiteConfigBrand = {
  logo_url?: string | null
  favicon_url?: string | null
}

type AdminSiteConfigSite = {
  display_name?: string | null
}

type AdminSiteConfig = {
  mode?: 'central' | 'partner'
  partner?: AdminSiteConfigParty | null
  tenant?: AdminSiteConfigParty | null
  domain?: AdminSiteConfigDomain | null
  brand?: AdminSiteConfigBrand | null
  site?: AdminSiteConfigSite | null
}

export const useAdminSiteConfig = () => {
  const hostMode = useAdminHostMode()
  const config = useState<AdminSiteConfig | null>('admin-site-config', () => null)
  const loadedHost = useState('admin-site-config-host', () => '')
  const loading = useState('admin-site-config-loading', () => false)
  const error = useState<any | null>('admin-site-config-error', () => null)

  const clear = () => {
    config.value = null
    loadedHost.value = ''
    error.value = null
  }

  const load = async () => {
    if (!hostMode.isPartnerBoHost.value) {
      clear()
      return null
    }

    if (config.value && loadedHost.value === hostMode.host.value) {
      return config.value
    }

    if (loading.value) {
      return config.value
    }

    loading.value = true
    error.value = null

    try {
      const response = await $fetch<AdminSiteConfig>(`${hostMode.adminApiBase.value}/public/admin-site-config`, {
        headers: {
          Accept: 'application/json',
        },
      })

      config.value = response?.mode === 'partner' ? response : null
      loadedHost.value = hostMode.host.value
      return config.value
    } catch (err) {
      error.value = err
      return null
    } finally {
      loading.value = false
    }
  }

  const displayName = computed(() => (
    cleanText(config.value?.site?.display_name)
    || cleanText(config.value?.tenant?.name)
    || cleanText(config.value?.partner?.name)
    || ''
  ))
  const logoUrl = computed(() => cleanText(config.value?.brand?.logo_url))

  return {
    config,
    loading,
    error,
    displayName,
    logoUrl,
    load,
    clear,
  }
}

const cleanText = (value?: string | null) => {
  const text = typeof value === 'string' ? value.trim() : ''
  return text || ''
}

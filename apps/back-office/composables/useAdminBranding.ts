const siamblendSystemName = 'Siamblend'
const siamblendCentralLogoUrl = '/brand/siamblend-bo-logo.png'
const siamblendCentralMarkUrl = '/brand/siamblend-bo-mark.png'

export const useAdminBranding = () => {
  const hostMode = useAdminHostMode()
  const siteConfig = useAdminSiteConfig()
  const isPartnerMode = computed(() => hostMode.isPartnerBoHost.value)
  const displayName = computed(() => (
    isPartnerMode.value
      ? siteConfig.displayName.value || siamblendSystemName
      : siamblendSystemName
  ))
  const logoUrl = computed(() => (
    isPartnerMode.value
      ? siteConfig.logoUrl.value || siamblendCentralLogoUrl
      : siamblendCentralLogoUrl
  ))
  const compactLogoUrl = computed(() => (
    isPartnerMode.value
      ? siteConfig.faviconUrl.value || siteConfig.logoUrl.value || siamblendCentralMarkUrl
      : siamblendCentralMarkUrl
  ))

  const load = async () => {
    if (isPartnerMode.value) {
      await siteConfig.load()
    }
  }

  return {
    isPartnerMode,
    systemName: siamblendSystemName,
    displayName,
    logoUrl,
    compactLogoUrl,
    centralLogoUrl: siamblendCentralLogoUrl,
    centralMarkUrl: siamblendCentralMarkUrl,
    load,
  }
}

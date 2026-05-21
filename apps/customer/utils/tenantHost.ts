export const normalizeTenantHost = (host: unknown) => {
  const value = String(host || '').trim().toLowerCase()

  return value.replace(/:\d+$/, '')
}

export const tenantHostScope = (host: unknown) => {
  const normalized = normalizeTenantHost(host)

  return normalized.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'default'
}

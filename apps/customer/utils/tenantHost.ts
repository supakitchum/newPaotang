export const normalizeTenantHost = (host: unknown) => {
  const value = String(host || '').trim().toLowerCase()
  const withoutPort = value.replace(/:\d+$/, '')

  try {
    return new URL(`http://${withoutPort}`).hostname.toLowerCase()
  } catch {
    return withoutPort
  }
}

export const tenantHostScope = (host: unknown) => {
  const normalized = normalizeTenantHost(host)

  return normalized.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'default'
}

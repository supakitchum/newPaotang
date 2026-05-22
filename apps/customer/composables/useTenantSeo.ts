export interface TenantSeoInput {
  path?: string
  title?: string
  description?: string
  imageUrl?: string
  robots?: string
  canonicalPath?: string
  privatePage?: boolean
}

const privateRoutePatterns = ['/cart', '/checkout', '/success', '/topup', '/tickets', '/profile', '/affiliate', '/login', '/register', '/line/callback']

const isPrivatePath = (path: string) => privateRoutePatterns.some((privatePath) => path === privatePath || path.startsWith(`${privatePath}/`))

const applyTitleTemplate = (title: string, template?: string) => {
  if (!template || !title) {
    return title
  }

  return template.includes('%s') ? template.replace('%s', title) : `${title} | ${template}`
}

export const useTenantSeo = (input: TenantSeoInput = {}) => {
  const route = useRoute()
  const { config, canonicalBase } = useSiteConfig()
  const path = input.path || route.path || '/'
  const site = config.value
  const defaultTitle = site?.seo?.default_title || site?.site?.display_name || site?.site?.site_name || 'สลากหกหลัก'
  const rawTitle = input.title || defaultTitle
  const title = input.title ? applyTitleTemplate(rawTitle, site?.seo?.title_template) : rawTitle
  const description = input.description || site?.seo?.default_description || ''
  const privatePage = input.privatePage === true || isPrivatePath(path)
  const robots = privatePage ? 'noindex,nofollow' : (input.robots || site?.seo?.robots_default || 'index,follow')
  const canonicalPath = input.canonicalPath || path
  const canonicalUrl = canonicalBase.value
    ? `${canonicalBase.value}${canonicalPath === '/' ? '' : canonicalPath}`
    : undefined
  const imageUrl = input.imageUrl || site?.brand?.og_image_url || site?.brand?.logo_url || ''

  useHead({
    title,
    meta: [
      { name: 'description', content: description },
      { name: 'robots', content: robots },
      { property: 'og:type', content: 'website' },
      { property: 'og:title', content: title },
      { property: 'og:description', content: description },
      ...(canonicalUrl ? [{ property: 'og:url', content: canonicalUrl }] : []),
      ...(imageUrl ? [{ property: 'og:image', content: imageUrl }] : []),
      { property: 'og:site_name', content: defaultTitle },
      { name: 'twitter:card', content: imageUrl ? 'summary_large_image' : 'summary' },
      { name: 'twitter:title', content: title },
      { name: 'twitter:description', content: description },
      ...(imageUrl ? [{ name: 'twitter:image', content: imageUrl }] : [])
    ],
    link: [
      ...(canonicalUrl ? [{ rel: 'canonical', href: canonicalUrl }] : []),
      ...(site?.brand?.favicon_url ? [{ rel: 'icon', href: site.brand.favicon_url }] : [])
    ]
  })

  return {
    title,
    description,
    robots,
    canonicalUrl,
    imageUrl
  }
}

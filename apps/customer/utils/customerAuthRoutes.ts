const publicCustomerRoutes = new Set([
  '/',
  '/login',
  '/register',
  '/line/callback',
  '/line/link-phone',
  '/maintenance',
  '/news',
  '/terms',
  '/lottery-knowledge',
  '/activities',
  '/countdown',
  '/result',
  '/result/full',
  '/wait-result',
  '/waiting-result',
])

const publicCustomerRoutePrefixes = [
  '/news/',
  '/activities/',
]

const inlinePinCustomerRoutes = new Set([
  '/affiliate',
])

export const isPublicCustomerRoute = (path: string) => (
  publicCustomerRoutes.has(path)
  || publicCustomerRoutePrefixes.some((prefix) => path.startsWith(prefix))
)

export const handlesCustomerPinInline = (path: string) => inlinePinCustomerRoutes.has(path)

export const requiresCustomerAuth = (path: string) => !isPublicCustomerRoute(path)

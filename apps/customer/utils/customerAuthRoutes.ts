const publicCustomerRoutes = new Set([
  '/',
  '/login',
  '/register',
  '/line/callback',
  '/maintenance',
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

export const isPublicCustomerRoute = (path: string) => (
  publicCustomerRoutes.has(path)
  || publicCustomerRoutePrefixes.some((prefix) => path.startsWith(prefix))
)

export const requiresCustomerAuth = (path: string) => !isPublicCustomerRoute(path)

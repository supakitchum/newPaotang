const publicCustomerRoutes = new Set([
  '/',
  '/login',
  '/register',
  '/line/callback',
  '/maintenance',
  '/countdown',
  '/result',
  '/result/full',
  '/wait-result',
  '/waiting-result',
])

export const isPublicCustomerRoute = (path: string) => publicCustomerRoutes.has(path)

export const requiresCustomerAuth = (path: string) => !isPublicCustomerRoute(path)

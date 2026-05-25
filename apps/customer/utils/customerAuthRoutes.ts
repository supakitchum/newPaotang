const publicCustomerRoutes = new Set([
  '/',
  '/login',
  '/register',
  '/line/callback',
  '/maintenance',
])

export const isPublicCustomerRoute = (path: string) => publicCustomerRoutes.has(path)

export const requiresCustomerAuth = (path: string) => !isPublicCustomerRoute(path)

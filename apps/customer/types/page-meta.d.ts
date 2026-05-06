declare module '#app' {
  interface PageMeta {
    requiresAuth?: boolean
    guestOnly?: boolean
  }
}

export {}

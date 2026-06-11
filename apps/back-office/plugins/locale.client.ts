export default defineNuxtPlugin(() => {
  const adminLocale = useAdminLocale()
  const route = useRoute()

  adminLocale.restore()
  const previewToken = typeof route.query.translation_preview_token === 'string' ? route.query.translation_preview_token : null
  void adminLocale.loadRuntimeBundle(adminLocale.locale.value, previewToken)

  watch(adminLocale.locale, (nextLocale) => {
    document.documentElement.lang = nextLocale
    void adminLocale.loadRuntimeBundle(nextLocale, previewToken)
  })
})

export default defineNuxtPlugin(() => {
  const { locale, loadRuntimeBundle } = useLocale()
  const route = useRoute()
  const previewToken = typeof route.query.translation_preview_token === 'string' ? route.query.translation_preview_token : null

  document.documentElement.lang = locale.value
  void loadRuntimeBundle(locale.value, previewToken)

  watch(locale, (nextLocale) => {
    document.documentElement.lang = nextLocale
    void loadRuntimeBundle(nextLocale, previewToken)
  })
})

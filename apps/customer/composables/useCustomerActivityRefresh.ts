export const useCustomerActivityRefresh = (reload: () => Promise<void>) => {
  let timer: ReturnType<typeof setTimeout> | null = null
  const refresh = () => {
    if (document.hidden) return
    if (timer !== null) clearTimeout(timer)
    timer = setTimeout(() => {
      timer = null
      void reload()
    }, 50)
  }

  onMounted(() => {
    window.addEventListener('focus', refresh)
    window.addEventListener('customer:purchase-settled', refresh)
    document.addEventListener('visibilitychange', refresh)
  })
  onBeforeUnmount(() => {
    window.removeEventListener('focus', refresh)
    window.removeEventListener('customer:purchase-settled', refresh)
    document.removeEventListener('visibilitychange', refresh)
    if (timer !== null) clearTimeout(timer)
  })
}

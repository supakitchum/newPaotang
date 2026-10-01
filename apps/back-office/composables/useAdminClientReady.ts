export const useAdminClientReady = () => {
  const ready = useState('admin-client-ready', () => false)

  const markReady = () => {
    ready.value = true
  }

  return {
    ready,
    markReady,
  }
}

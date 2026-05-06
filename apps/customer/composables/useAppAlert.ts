export type AppAlertVariant = 'info' | 'warning' | 'error'

export interface AppAlertState {
  visible: boolean
  title: string
  message: string
  button: string
  variant: AppAlertVariant
}

type AppAlertOptions = Partial<Omit<AppAlertState, 'visible'>>

const defaultAlertState = (): AppAlertState => ({
  visible: false,
  title: '',
  message: '',
  button: 'รับทราบ',
  variant: 'info'
})

export const useAppAlert = () => {
  const alertState = useState<AppAlertState>('app_alert', defaultAlertState)

  const showAlert = (options: AppAlertOptions | string) => {
    const nextOptions = typeof options === 'string'
      ? { message: options }
      : options

    alertState.value = {
      ...defaultAlertState(),
      ...nextOptions,
      visible: true
    }
  }

  const closeAlert = () => {
    alertState.value = {
      ...alertState.value,
      visible: false
    }
  }

  return {
    alertState,
    showAlert,
    closeAlert
  }
}

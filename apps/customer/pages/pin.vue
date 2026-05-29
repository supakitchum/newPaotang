<template>
  <PinKeypadScreen
    :title="pinTitle"
    :subtitle="pinSubtitle"
    :digits="activeDigits"
    :error="errorMessage"
    :helper="helperMessage"
    :disabled="isSubmitting"
    @append="appendDigit"
    @remove="removeDigit"
    @back="handleBack"
  />
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: true
})

type SetupStep = 'pin' | 'confirmation'

const route = useRoute()
const platformApi = usePlatformApi()
const { token, user, hasPin, setAuthUser, setPinVerified, restoreAuthState, clearAuthToken, logout } = useAuth()
const { refreshAppInit } = useAppInit()

const pin = ref('')
const pinConfirmation = ref('')
const setupStep = ref<SetupStep>('pin')
const isSubmitting = ref(false)
const errorMessage = ref('')

const mode = computed(() => hasPin.value ? 'verify' : 'setup')
const activeDigits = computed(() => mode.value === 'setup' && setupStep.value === 'confirmation' ? pinConfirmation.value : pin.value)
const pinTitle = computed(() => {
  if (mode.value === 'verify') {
    return 'ใส่รหัส PIN 6 หลัก'
  }

  return setupStep.value === 'confirmation' ? 'ยืนยันรหัส PIN 6 หลัก' : 'ตั้งรหัส PIN 6 หลัก'
})
const pinSubtitle = computed(() => {
  if (isSubmitting.value) {
    return mode.value === 'setup' ? 'กำลังตั้งรหัสเข้าใช้งาน' : 'กำลังตรวจสอบ'
  }

  if (mode.value === 'verify') {
    return 'เพื่อทำรายการต่อ'
  }

  return setupStep.value === 'confirmation' ? 'กรอกรหัสเดิมอีกครั้ง' : 'เพื่อใช้เข้าใช้งานต่อ'
})
const helperMessage = computed(() => {
  if (mode.value === 'setup' && setupStep.value === 'confirmation' && !errorMessage.value) {
    return 'ยืนยัน PIN ที่ตั้งไว้'
  }

  return ''
})
const canSubmit = computed(() => {
  if (!/^\d{6}$/.test(pin.value)) {
    return false
  }

  return mode.value === 'verify' || pinConfirmation.value === pin.value
})

const safeRedirect = () => {
  if (typeof route.query.redirect !== 'string') {
    return '/'
  }

  if (!route.query.redirect.startsWith('/') || route.query.redirect.startsWith('//') || route.query.redirect === '/pin') {
    return '/'
  }

  return route.query.redirect
}

const setActiveDigits = (value: string) => {
  if (mode.value === 'setup' && setupStep.value === 'confirmation') {
    pinConfirmation.value = value
    return
  }

  pin.value = value
}

const resetPinEntry = () => {
  pin.value = ''
  pinConfirmation.value = ''
  setupStep.value = 'pin'
}

const applyPinResponse = async (response: Record<string, any>) => {
  setAuthUser(response.user || {
    ...(user.value || {}),
    has_pin: response.has_pin,
    pin_verified: response.pin_verified,
    pin_setup_required: response.pin_setup_required,
    pin_required: response.pin_required
  })
  setPinVerified(Boolean(response.pin_verified))
  await refreshAppInit()
  await navigateTo(safeRedirect())
}

const submitPin = async () => {
  if (isSubmitting.value || !canSubmit.value) {
    return
  }

  isSubmitting.value = true
  errorMessage.value = ''

  try {
    const response = mode.value === 'setup'
      ? await platformApi.setupPin({
          pin: pin.value,
          pin_confirmation: pinConfirmation.value
        })
      : await platformApi.verifyPin({
          pin: pin.value
        })

    await applyPinResponse(response)
  } catch (error: any) {
    const code = error?.response?.data?.error?.code || error?.response?.data?.code

    if (code === 'pin_locked') {
      errorMessage.value = 'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่แล้วลองใหม่'
    } else if (code === 'pin_invalid') {
      errorMessage.value = 'PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง'
    } else {
      errorMessage.value = error?.response?.data?.message || 'ไม่สามารถยืนยัน PIN ได้ กรุณาลองใหม่อีกครั้ง'
    }

    resetPinEntry()
  } finally {
    isSubmitting.value = false
  }
}

const appendDigit = async (digit: string) => {
  if (!/^\d$/.test(digit) || activeDigits.value.length >= 6 || isSubmitting.value) {
    return
  }

  errorMessage.value = ''
  const nextDigits = `${activeDigits.value}${digit}`
  setActiveDigits(nextDigits)

  if (nextDigits.length !== 6) {
    return
  }

  if (mode.value === 'setup' && setupStep.value === 'pin') {
    setupStep.value = 'confirmation'
    return
  }

  if (mode.value === 'setup' && pinConfirmation.value !== pin.value) {
    errorMessage.value = 'PIN ไม่ตรงกัน กรุณาตั้งใหม่อีกครั้ง'
    resetPinEntry()
    return
  }

  await submitPin()
}

const removeDigit = () => {
  if (isSubmitting.value || activeDigits.value.length === 0) {
    return
  }

  errorMessage.value = ''
  setActiveDigits(activeDigits.value.slice(0, -1))
}

const handleBack = async () => {
  if (mode.value === 'setup' && setupStep.value === 'confirmation') {
    pinConfirmation.value = ''
    setupStep.value = 'pin'
    errorMessage.value = ''
    return
  }

  await logout()
  await navigateTo('/login')
}

const handleKeydown = (event: KeyboardEvent) => {
  if (/^\d$/.test(event.key)) {
    event.preventDefault()
    void appendDigit(event.key)
    return
  }

  if (event.key === 'Backspace') {
    event.preventDefault()
    removeDigit()
  }
}

watch(mode, () => {
  resetPinEntry()
})

onMounted(async () => {
  try {
    if (!token.value) {
      throw new Error('missing_auth_token')
    }

    await restoreAuthState(true)
  } catch {
    clearAuthToken()
    await navigateTo({
      path: '/login',
      query: {
        redirect: safeRedirect()
      }
    })
    return
  }

  window.addEventListener('keydown', handleKeydown)
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleKeydown)
})
</script>

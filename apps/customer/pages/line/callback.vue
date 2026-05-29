<template>
  <section class="login-hero min-vh-100">
    <div class="login-hero-inner">
      <div class="login-hero-copy">
        <div class="login-badge">
          <i class="bi bi-line"/>
          LINE Login
        </div>
        <h1>กำลังเข้าสู่ระบบ</h1>
        <p>{{ statusText }}</p>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import {onMounted, ref} from 'vue'
import type {AuthUser} from '~/composables/useAuth'

interface LineCallbackResponse {
  code: number
  token: string
  refresh_token?: string
  user: AuthUser
  pin_required?: boolean
  pin_setup_required?: boolean
  order_id?: string
  message?: string
}

definePageMeta({
  requiresAuth: false
})

const route = useRoute()
const platformApi = usePlatformApi()
const {lineRedirect, isAuthenticated, pinSetupRequired, pinRequired, setAuthSession, clearLineRedirect} = useAuth()
const { applyStoredRef } = useAffiliateReferral()
const {refreshAppInit} = useAppInit()
const statusText = ref('กรุณารอสักครู่ ระบบกำลังยืนยันข้อมูลจาก LINE')

const getSafeRedirect = (value: unknown) => {
  if (typeof value !== 'string') {
    return '/'
  }

  if (!value.startsWith('/') || value.startsWith('//')) {
    return '/'
  }

  return value
}

const navigateToPin = async (redirectTo: string) => {
  clearLineRedirect()
  await navigateTo({
    path: '/pin',
    query: {
      redirect: redirectTo
    }
  })
}

const needsPinUnlock = (response: LineCallbackResponse) => Boolean(
  response?.pin_setup_required ||
  response?.pin_required ||
  response?.user?.pin_setup_required ||
  response?.user?.pin_required
)

onMounted(async () => {
  if (isAuthenticated.value) {
    const redirectTo = getSafeRedirect(lineRedirect.value)

    if (pinSetupRequired.value || pinRequired.value) {
      await navigateToPin(redirectTo)
      return
    }

    clearLineRedirect()
    await applyStoredRef()
    await refreshAppInit()
    await navigateTo(redirectTo)
    return
  }

  try {
    const response = await platformApi.lineCallback(route.query) as LineCallbackResponse

    if (response.code === 0) {
      setAuthSession(response)
      await applyStoredRef()

      if (needsPinUnlock(response)) {
        await navigateToPin(getSafeRedirect(lineRedirect.value))
        return
      }

      await refreshAppInit(response.token)

      if (response?.order_id) {
        await navigateTo(`payment?id=${response?.order_id}`);
      }else{
        const redirectTo = getSafeRedirect(lineRedirect.value)
        clearLineRedirect()
        await navigateTo(redirectTo)
      }

      return
    }

    statusText.value = response.message || 'ไม่สามารถเข้าสู่ระบบด้วย LINE ได้'
  } catch {
    statusText.value = 'ไม่สามารถเชื่อมต่อเพื่อเข้าสู่ระบบด้วย LINE ได้'
  }
})
</script>

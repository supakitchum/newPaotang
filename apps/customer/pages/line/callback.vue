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
  user: AuthUser
  order_id?: string
  message?: string
}

definePageMeta({
  requiresAuth: false
})

const route = useRoute()
const platformApi = usePlatformApi()
const {lineRedirect, isAuthenticated, setAuthToken, setAuthUser, clearLineRedirect} = useAuth()
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

onMounted(async () => {
  if (isAuthenticated.value) {
    const redirectTo = getSafeRedirect(lineRedirect.value)
    clearLineRedirect()
    await refreshAppInit()
    await navigateTo(redirectTo)
    return
  }

  try {
    const response = await platformApi.lineCallback(route.query) as LineCallbackResponse

    if (response.code === 0) {
      setAuthToken(response.token)
      setAuthUser(response.user)
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

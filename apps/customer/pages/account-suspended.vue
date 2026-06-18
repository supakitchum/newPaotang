<template>
  <MobileShell>
    <section class="account-suspended-page">
      <BrandLogo />
      <div class="account-suspended-card">
        <div class="account-suspended-icon">
          <i class="bi bi-shield-lock" />
        </div>
        <p class="account-suspended-kicker">บัญชีถูกระงับการใช้งาน</p>
        <h1>ไม่สามารถเข้าใช้งานระบบได้</h1>
        <p class="account-suspended-message">
          บัญชีสมาชิกนี้ถูกระงับโดยร้านค้า กรุณาตรวจสอบเหตุผลด้านล่างหรือติดต่อฝ่ายบริการ
        </p>

        <div class="account-suspended-detail">
          <span>เหตุผล</span>
          <strong>{{ reasonText }}</strong>
        </div>
        <div class="account-suspended-detail">
          <span>ระยะเวลาระงับ</span>
          <strong>{{ durationText }}</strong>
        </div>

        <button class="account-suspended-action" type="button" @click="goLogin">
          กลับไปหน้าเข้าสู่ระบบ
        </button>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: false
})

const { accountSuspension, clearAccountSuspension } = useAuth()

useTenantSeo({
  path: '/account-suspended',
  title: 'บัญชีถูกระงับการใช้งาน',
  description: 'บัญชีสมาชิกนี้ถูกระงับการใช้งาน',
  robots: 'noindex,nofollow',
  canonicalPath: '/account-suspended'
})

const reasonText = computed(() => {
  const reason = String(accountSuspension.value?.reason || '').trim()

  return reason || 'ไม่ได้ระบุเหตุผล'
})

const durationText = computed(() => {
  if (accountSuspension.value?.is_permanent) {
    return 'ระงับถาวร'
  }

  const until = accountSuspension.value?.suspended_until

  if (!until) {
    return 'ระงับถาวร'
  }

  const date = new Date(until)

  if (Number.isNaN(date.getTime())) {
    return 'ระงับชั่วคราว'
  }

  return `ถึง ${new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(date)}`
})

const goLogin = async () => {
  clearAccountSuspension()
  await navigateTo('/login', { replace: true })
}
</script>

<style scoped>
.account-suspended-page {
  min-height: 100dvh;
  display: grid;
  align-content: center;
  justify-items: center;
  gap: 18px;
  padding: 32px 20px;
  background:
    radial-gradient(circle at 82% 16%, rgba(255, 214, 10, .86) 0 54px, transparent 55px),
    linear-gradient(155deg, #0d8fff 0%, #0c69d8 44%, #0aa58f 100%);
}

.account-suspended-card {
  width: min(100%, 440px);
  display: grid;
  gap: 14px;
  padding: 26px 22px 24px;
  border-radius: 28px;
  background: #fff;
  color: #17345f;
  text-align: center;
  box-shadow: 0 22px 50px rgba(9, 51, 99, .2);
}

.account-suspended-icon {
  width: 74px;
  height: 74px;
  display: grid;
  place-items: center;
  justify-self: center;
  border-radius: 24px;
  background: #fff1f1;
  color: #dc3545;
  font-size: 32px;
}

.account-suspended-kicker {
  margin: 0;
  color: #dc3545;
  font-size: 14px;
  font-weight: 800;
}

.account-suspended-card h1 {
  margin: 0;
  font-size: 25px;
  font-weight: 900;
}

.account-suspended-message {
  margin: 0;
  color: #60708a;
  font-size: 15px;
  line-height: 1.55;
}

.account-suspended-detail {
  display: grid;
  gap: 6px;
  padding: 14px 16px;
  border-radius: 18px;
  background: #f4f8ff;
  text-align: left;
}

.account-suspended-detail span {
  color: #7a8aa2;
  font-size: 13px;
  font-weight: 700;
}

.account-suspended-detail strong {
  color: #17345f;
  font-size: 16px;
  line-height: 1.45;
}

.account-suspended-action {
  width: 100%;
  min-height: 52px;
  margin-top: 4px;
  border: 0;
  border-radius: 999px;
  background: linear-gradient(135deg, #168cf2, #0a64d8);
  color: #fff;
  font-size: 16px;
  font-weight: 900;
  box-shadow: 0 14px 24px rgba(15, 112, 221, .25);
}
</style>

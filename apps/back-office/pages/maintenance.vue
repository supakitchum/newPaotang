<template>
  <div class="authentication np-partner-maintenance-page">
    <div class="container">
      <div class="row align-items-center justify-content-center min-vh-100 py-4">
        <div class="col-xl-7 col-lg-8">
          <div class="card custom-card overflow-hidden">
            <div class="card-body p-4 p-lg-5 text-center">
              <div class="np-maintenance-icon mx-auto mb-4">
                <i class="ri-tools-line" />
              </div>
              <img :src="logoUrl" :alt="displayName" class="np-maintenance-logo mb-3" />
              <h1 class="h4 fw-semibold mb-2">Partner Back Office is under maintenance</h1>
              <p class="text-muted mb-4">
                Central has temporarily closed {{ displayName || 'this Partner Back Office' }} for maintenance.
              </p>

              <div class="np-maintenance-message text-start mb-4">
                <div class="fw-semibold mb-2">Message</div>
                <p class="mb-0">{{ maintenanceMessage }}</p>
              </div>

              <div v-if="expectedEndLabel" class="alert alert-primary text-start mb-4">
                <i class="ri-time-line me-2" />
                Expected end: {{ expectedEndLabel }}
              </div>

              <AdminAlert v-if="error" type="warning" :message="error.message || 'Unable to refresh maintenance status.'" dismissible @dismiss="error = null" />

              <div class="d-flex flex-wrap justify-content-center gap-2">
                <button class="btn btn-primary btn-wave" type="button" :disabled="loading" @click="refreshStatus">
                  <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
                  <i v-else class="ri-refresh-line me-1" />
                  Check again
                </button>
                <NuxtLink v-if="!maintenanceActive" class="btn btn-light btn-wave" to="/login">Back to sign in</NuxtLink>
              </div>
            </div>
          </div>
          <p class="text-center text-muted fs-12 mt-3 mb-0">
            Central maintenance only affects this Partner Back Office. Central admin remains available.
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime } from '~/utils/format'

definePageMeta({ layout: false })

const hostMode = useAdminHostMode()
const session = useAdminSession()
const adminSiteConfig = useAdminSiteConfig()
const adminBranding = useAdminBranding()
const loading = ref(false)
const error = ref<any>(null)

const displayName = computed(() => adminSiteConfig.displayName.value || 'Partner Back Office')
const logoUrl = computed(() => adminSiteConfig.logoUrl.value || adminBranding.centralLogoUrl)
const maintenanceActive = computed(() => adminSiteConfig.maintenanceActive.value)
const maintenanceMessage = computed(() => adminSiteConfig.maintenanceMessage.value)
const expectedEndLabel = computed(() => {
  const value = adminSiteConfig.maintenanceExpectedEndAt.value
  return value ? formatDateTime(value) : ''
})

const refreshStatus = async () => {
  loading.value = true
  error.value = null

  try {
    adminSiteConfig.clear()
    await adminSiteConfig.load()

    if (!hostMode.isPartnerBoHost.value) {
      await navigateTo('/login')
      return
    }

    if (!adminSiteConfig.maintenanceActive.value) {
      await navigateTo('/login')
    }
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  session.clear()
  await refreshStatus()
})
</script>

<style scoped>
.np-partner-maintenance-page {
  background:
    radial-gradient(circle at 20% 18%, rgba(13, 110, 253, .14), transparent 34%),
    linear-gradient(135deg, rgba(248, 250, 252, 1), rgba(239, 246, 255, 1));
}

.np-maintenance-icon {
  align-items: center;
  background: rgba(13, 110, 253, .1);
  border-radius: 50%;
  color: var(--primary-color, #0d6efd);
  display: inline-flex;
  font-size: 2rem;
  height: 4.5rem;
  justify-content: center;
  width: 4.5rem;
}

.np-maintenance-logo {
  height: auto;
  max-height: 5rem;
  max-width: min(100%, 15rem);
  object-fit: contain;
}

.np-maintenance-message {
  background: rgba(13, 110, 253, .06);
  border: 1px solid rgba(13, 110, 253, .14);
  border-radius: .75rem;
  padding: 1rem;
}
</style>

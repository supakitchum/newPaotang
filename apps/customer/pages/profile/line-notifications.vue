<template>
  <MobileShell time="13:09" active-nav="menu" show-bottom-nav>
    <BlueHeader class="line-notify-hero" title="แจ้งเตือนผ่าน LINE" back-to="/profile" min-height="226px">
      <div class="line-hero-content">
        <div class="line-brand-mark">
          <i class="bi bi-line" />
        </div>
        <div class="line-hero-copy">
          <h2>รับแจ้งเตือนทุกการทำรายการ</h2>
          <p>เติมเงิน ซื้อสลาก เข้าร่วมกิจกรรม และสถานะการขึ้นเงินรางวัลจากร้านค้านี้</p>
        </div>
      </div>
    </BlueHeader>

    <section class="content-sheet flush line-notify-sheet">
      <template v-if="loading">
        <section class="line-skeleton-card">
          <span class="placeholder-line placeholder-line-md" />
          <span class="placeholder-line" />
          <span class="placeholder-line placeholder-line-sm" />
        </section>
        <section class="line-skeleton-card">
          <span class="placeholder-line placeholder-line-md" />
          <span class="placeholder-line" />
        </section>
      </template>

      <template v-else>
        <section class="line-connect-card">
          <div class="line-connect-top">
            <div class="line-avatar" :class="{ connected: Boolean(identity) }">
              <img v-if="identity?.picture_url" :src="identity.picture_url" alt="" />
              <i v-else class="bi bi-line" />
            </div>
            <div class="line-connect-copy">
              <span class="line-kicker">{{ settings?.bot_display_name || 'LINE OA' }}</span>
              <h2>{{ identity ? 'เชื่อมต่อ LINE แล้ว' : 'ยังไม่ได้เชื่อมต่อ LINE' }}</h2>
              <p>{{ identity ? (identity.display_name || 'บัญชี LINE ของคุณ') : 'เชื่อมต่อครั้งเดียว แล้วรับแจ้งเตือนผ่าน LINE ได้ทันที' }}</p>
            </div>
            <span class="line-connection-badge" :class="identity ? 'success' : 'pending'">
              {{ identity ? 'พร้อมใช้' : 'ยังไม่เชื่อม' }}
            </span>
          </div>

          <div class="line-status-grid">
            <div class="line-status-tile">
              <i class="bi bi-bell-fill" />
              <span>แจ้งเตือน</span>
              <strong>{{ identity?.notification_enabled ? 'เปิดอยู่' : 'ยังไม่เปิด' }}</strong>
            </div>
            <div class="line-status-tile">
              <i class="bi bi-person-check-fill" />
              <span>เพิ่มเพื่อน OA</span>
              <strong>{{ identity?.friend_flag ? 'เพิ่มแล้ว' : 'ยังไม่เพิ่ม' }}</strong>
            </div>
          </div>
        </section>

        <section v-if="identity" class="line-setting-card">
          <div>
            <h3>รับแจ้งเตือนผ่าน LINE</h3>
            <p>เปิดไว้เพื่อรับสถานะรายการสำคัญแบบอัตโนมัติ</p>
          </div>
          <label class="line-switch" aria-label="รับแจ้งเตือนผ่าน LINE">
            <input v-model="notificationEnabled" type="checkbox" :disabled="saving" @change="saveToggle">
            <span />
          </label>
        </section>

        <section class="line-events-card">
          <div class="line-card-heading">
            <div class="line-card-icon">
              <i class="bi bi-chat-dots-fill" />
            </div>
            <div>
              <h3>รายการที่จะส่งแจ้งเตือน</h3>
              <p>ข้อความจะส่งจาก LINE OA ของร้านค้า</p>
            </div>
          </div>
          <div class="line-event-list">
            <div v-for="event in notificationEvents" :key="event.label" class="line-event-row">
              <i :class="event.icon" />
              <span>{{ event.label }}</span>
            </div>
          </div>
        </section>

        <section v-if="!settings?.line_available" class="line-warning-card">
          <i class="bi bi-exclamation-triangle-fill" />
          <div>
            <strong>ร้านค้านี้ยังไม่ได้เปิดใช้งาน LINE OA</strong>
            <span>เมื่อร้านค้าตั้งค่าเรียบร้อย คุณจะเชื่อมต่อและเปิดรับแจ้งเตือนได้ทันที</span>
          </div>
        </section>
      </template>
    </section>

    <footer v-if="!loading" class="line-action-footer">
      <button
        v-if="!identity"
        class="primary-pill line-main-action"
        type="button"
        :disabled="connecting || !settings?.line_available"
        @click="connectLine"
      >
        <span v-if="connecting" class="line-spinner" />
        {{ connecting ? 'กำลังไป LINE' : connectButtonLabel }}
      </button>
      <button v-else class="primary-pill line-main-action" type="button" :disabled="connecting" @click="connectLine">
        <span v-if="connecting" class="line-spinner" />
        เชื่อมต่อ LINE ใหม่
      </button>
      <button v-if="addFriendUrl && !identity?.friend_flag" class="line-secondary-action" type="button" @click="openAddFriend">
        <i class="bi bi-person-plus-fill" />
        เพิ่มเพื่อน LINE OA
      </button>
      <button v-if="identity" class="line-text-action" type="button" :disabled="saving" @click="disconnectLine">
        ยกเลิกการเชื่อมต่อ
      </button>
    </footer>
  </MobileShell>
</template>

<script setup lang="ts">
definePageMeta({
  requiresAuth: true
})

const platformApi = usePlatformApi()
const { setLineRedirect } = useAuth()
const { showAlert } = useAppAlert()
const lineLiff = useLineLiff()
const settings = ref<Record<string, any> | null>(null)
const loading = ref(true)
const saving = ref(false)
const connecting = ref(false)

const identity = computed(() => settings.value?.identity || null)
const addFriendUrl = computed(() => settings.value?.add_friend_url || '')
const notificationEnabled = ref(false)
const connectButtonLabel = computed(() => lineLiff.isLineInApp.value ? 'เชื่อมต่อด้วย LINE' : 'เชื่อมต่อ LINE')
const notificationEvents = [
  { icon: 'bi bi-wallet2', label: 'เติมเงินและอัปเดตสถานะเติมเงิน' },
  { icon: 'bi bi-ticket-perforated-fill', label: 'ซื้อสลากและยืนยันคำสั่งซื้อ' },
  { icon: 'bi bi-stars', label: 'เข้าร่วมกิจกรรมของร้านค้า' },
  { icon: 'bi bi-trophy-fill', label: 'ขึ้นเงินรางวัลและสถานะการจ่ายเงิน' },
]

watch(identity, (value) => {
  notificationEnabled.value = Boolean(value?.notification_enabled)
}, { immediate: true })

onMounted(async () => {
  lineLiff.detectLineClient()
  void lineLiff.initialize()
  await loadSettings()
})

async function loadSettings() {
  loading.value = true
  try {
    settings.value = await platformApi.lineNotificationSettings()
    notificationEnabled.value = Boolean(settings.value?.identity?.notification_enabled)
  } catch (error: any) {
    showAlert({
      title: 'โหลดข้อมูล LINE ไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    loading.value = false
  }
}

async function connectLine() {
  connecting.value = true
  try {
    setLineRedirect('/profile/line-notifications')
    const response = await platformApi.lineLogin({ store_id: null })
    const url = typeof response?.url === 'string' ? response.url : ''

    if (response.code === 0 && isSafeLineLoginUrl(url)) {
      await lineLiff.redirectToLineLogin(url)
      return
    }

    throw new Error('missing_line_redirect_url')
  } catch (error: any) {
    showAlert({
      title: 'เชื่อมต่อ LINE ไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    connecting.value = false
  }
}

function isSafeLineLoginUrl(value: string) {
  try {
    const url = new URL(value)
    return url.protocol === 'https:' && url.hostname === 'access.line.me'
  } catch {
    return false
  }
}

async function saveToggle() {
  saving.value = true
  try {
    settings.value = await platformApi.updateLineNotificationSettings({
      notification_enabled: notificationEnabled.value
    })
  } catch (error: any) {
    notificationEnabled.value = !notificationEnabled.value
    showAlert({
      title: 'บันทึกการแจ้งเตือนไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    saving.value = false
  }
}

async function disconnectLine() {
  saving.value = true
  try {
    settings.value = await platformApi.disconnectLineNotifications()
    notificationEnabled.value = false
  } catch (error: any) {
    showAlert({
      title: 'ยกเลิกการเชื่อมต่อไม่สำเร็จ',
      message: error?.response?.data?.message || 'กรุณาลองใหม่อีกครั้ง',
      variant: 'error'
    })
  } finally {
    saving.value = false
  }
}

function openAddFriend() {
  const url = addFriendUrl.value
  if (!url) return

  lineLiff.openExternal(url)
}
</script>

<style scoped>
.line-notify-hero :deep(.hero-title) {
  font-size: 20px;
  font-weight: 900;
}

.line-hero-content {
  align-items: center;
  color: #fff;
  display: flex;
  gap: 14px;
  margin-top: 22px;
}

.line-brand-mark {
  background: #06c755;
  border: 3px solid rgba(255, 255, 255, .78);
  border-radius: 8px;
  box-shadow: 0 12px 22px rgba(0, 49, 92, .18);
  display: grid;
  flex: 0 0 62px;
  height: 62px;
  place-items: center;
  width: 62px;
}

.line-brand-mark i {
  font-size: 34px;
}

.line-hero-copy {
  min-width: 0;
}

.line-hero-copy h2 {
  font-size: 22px;
  font-weight: 900;
  line-height: 1.18;
  margin: 0 0 6px;
}

.line-hero-copy p {
  font-size: 13px;
  font-weight: 800;
  line-height: 1.45;
  margin: 0;
  opacity: .92;
}

.line-notify-sheet {
  display: grid;
  gap: 12px;
  margin-top: 0;
  padding: 16px 14px 296px;
}

.line-skeleton-card,
.line-connect-card,
.line-setting-card,
.line-events-card,
.line-warning-card {
  background: #fff;
  border: 1px solid #e7edf5;
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(18, 55, 103, .07);
  padding: 14px;
}

.line-connect-top {
  align-items: center;
  display: grid;
  gap: 12px;
  grid-template-columns: 56px minmax(0, 1fr) auto;
}

.line-avatar {
  background: #eef3f8;
  border-radius: 8px;
  color: #8390a0;
  display: grid;
  height: 56px;
  overflow: hidden;
  place-items: center;
  width: 56px;
}

.line-avatar.connected {
  background: #e8fbef;
  color: #06c755;
}

.line-avatar i {
  font-size: 31px;
}

.line-avatar img {
  height: 100%;
  object-fit: cover;
  width: 100%;
}

.line-connect-copy {
  min-width: 0;
}

.line-kicker {
  color: #06a847;
  display: block;
  font-size: 12px;
  font-weight: 900;
  line-height: 1.2;
  margin-bottom: 4px;
}

.line-connect-copy h2,
.line-setting-card h3,
.line-card-heading h3 {
  color: #172235;
  font-size: 17px;
  font-weight: 900;
  line-height: 1.25;
  margin: 0 0 4px;
}

.line-connect-copy p,
.line-setting-card p,
.line-card-heading p,
.line-warning-card span {
  color: #778397;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.45;
  margin: 0;
}

.line-connection-badge {
  border-radius: 999px;
  font-size: 11px;
  font-weight: 900;
  line-height: 1;
  padding: 7px 9px;
  white-space: nowrap;
}

.line-connection-badge.success {
  background: #e5f9ed;
  color: #058a3b;
}

.line-connection-badge.pending {
  background: #fff3dc;
  color: #b46500;
}

.line-status-grid {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  margin-top: 14px;
}

.line-status-tile {
  background: #f7faff;
  border: 1px solid #e6edf6;
  border-radius: 8px;
  padding: 11px;
}

.line-status-tile i {
  color: #0879e6;
  font-size: 18px;
}

.line-status-tile span {
  color: #7b8797;
  display: block;
  font-size: 12px;
  font-weight: 900;
  margin-top: 7px;
}

.line-status-tile strong {
  color: #172235;
  display: block;
  font-size: 14px;
  font-weight: 900;
  margin-top: 2px;
}

.line-setting-card {
  align-items: center;
  display: flex;
  gap: 14px;
  justify-content: space-between;
}

.line-switch {
  flex: 0 0 auto;
}

.line-switch input {
  display: none;
}

.line-switch span {
  background: #d8e1eb;
  border-radius: 999px;
  display: block;
  height: 32px;
  position: relative;
  transition: .2s ease;
  width: 56px;
}

.line-switch span::after {
  background: #fff;
  border-radius: 50%;
  box-shadow: 0 2px 7px rgba(0, 0, 0, .18);
  content: '';
  height: 26px;
  left: 3px;
  position: absolute;
  top: 3px;
  transition: .2s ease;
  width: 26px;
}

.line-switch input:checked + span {
  background: #06c755;
}

.line-switch input:checked + span::after {
  transform: translateX(24px);
}

.line-card-heading {
  align-items: center;
  display: flex;
  gap: 11px;
}

.line-card-icon {
  background: #edf6ff;
  border-radius: 8px;
  color: #0879e6;
  display: grid;
  flex: 0 0 42px;
  height: 42px;
  place-items: center;
  width: 42px;
}

.line-event-row {
  align-items: center;
  background: #f8fbff;
  border-radius: 8px;
  color: #263349;
  display: flex;
  font-size: 13px;
  font-weight: 900;
  gap: 9px;
  min-height: 40px;
  padding: 9px 10px;
}

.line-event-list {
  display: grid;
  gap: 8px;
  margin-top: 13px;
}

.line-event-row i {
  color: #0879e6;
  font-size: 17px;
}

.line-warning-card {
  align-items: flex-start;
  background: #fff7e8;
  border-color: #ffe4b4;
  display: flex;
  gap: 10px;
}

.line-warning-card i {
  color: #d17a00;
  flex: 0 0 auto;
  font-size: 20px;
  margin-top: 1px;
}

.line-warning-card strong {
  color: #8d5100;
  display: block;
  font-size: 14px;
  font-weight: 900;
  line-height: 1.35;
  margin-bottom: 2px;
}

.line-action-footer {
  background: rgba(255, 255, 255, .96);
  border-top: 1px solid #e7edf5;
  bottom: calc(112px + env(safe-area-inset-bottom));
  box-shadow: 0 -12px 28px rgba(22, 48, 86, .1);
  display: grid;
  gap: 8px;
  left: 50%;
  max-width: 430px;
  padding: 12px 16px;
  position: fixed;
  transform: translateX(-50%);
  width: 100%;
  z-index: 30;
}

.line-main-action {
  align-items: center;
  display: inline-flex;
  justify-content: center;
  width: 100%;
}

.line-secondary-action,
.line-text-action {
  align-items: center;
  background: #eefaf3;
  border: 0;
  border-radius: 999px;
  color: #057a35;
  display: inline-flex;
  font-size: 14px;
  font-weight: 900;
  gap: 7px;
  justify-content: center;
  min-height: 42px;
  width: 100%;
}

.line-text-action {
  background: transparent;
  color: #738094;
  min-height: 34px;
}

.line-spinner {
  border: 2px solid rgba(255, 255, 255, .42);
  border-radius: 50%;
  border-top-color: #fff;
  display: inline-block;
  height: 16px;
  margin-right: 8px;
  width: 16px;
  animation: line-spin .8s linear infinite;
}

@keyframes line-spin {
  to {
    transform: rotate(360deg);
  }
}
</style>

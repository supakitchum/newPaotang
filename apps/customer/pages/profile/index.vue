<template>
  <MobileShell time="13:09" active-nav="menu" show-bottom-nav>
    <BlueHeader class="profile-hero" min-height="268px">
      <div class="profile-identity">
        <span class="avatar"><i class="bi bi-person-fill" /></span>
        <div>
          <h1>{{ displayName }}</h1>
          <div class="profile-member-row">
            <span class="profile-member-code">{{ customerNoText }}</span>
            <button
              v-if="rawCustomerNo"
              class="profile-copy-button"
              type="button"
              :aria-label="t('profile.copyMemberCode')"
              :title="t('profile.copyMemberCode')"
              @click="copyCustomerNo"
            >
              <i :class="copiedCustomerNo ? 'bi bi-check2' : 'bi bi-copy'" />
            </button>
          </div>
        </div>
      </div>
    </BlueHeader>
    <section class="content-sheet profile-sheet">
      <section class="profile-language-card mb-4">
        <div>
          <h2>{{ t('profile.languageTitle') }}</h2>
          <p>{{ t('profile.languageSubtitle') }}</p>
        </div>
        <LanguageSwitcher />
      </section>
      <section v-for="section in menuSections" :key="section.title" class="mb-4">
        <h2 class="fs-6 fw-medium muted-text mb-3">{{ section.title }}</h2>
        <template v-for="item in section.items" :key="menuItemKey(item)">
          <NuxtLink v-if="menuItemTo(item)" class="menu-row menu-row-link" :to="menuItemTo(item)">
            <span class="menu-row-main">
              <span class="fw-semibold fs-6">{{ menuItemLabel(item) }}</span>
              <span v-if="menuItemBadge(item)" class="menu-row-badge">{{ menuItemBadge(item) }}</span>
            </span>
            <i class="bi bi-chevron-right fs-3 text-secondary" />
          </NuxtLink>
          <div v-else class="menu-row">
            <span class="menu-row-main">
              <span class="fw-semibold fs-6">{{ menuItemLabel(item) }}</span>
              <span v-if="menuItemBadge(item)" class="menu-row-badge">{{ menuItemBadge(item) }}</span>
            </span>
            <i class="bi bi-chevron-right fs-3 text-secondary" />
          </div>
        </template>
      </section>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { menuSections } from '~/data/lottery'

definePageMeta({
  requiresAuth: true
})

const { user, restoreAuthState } = useAuth()
const { showAlert } = useAppAlert()
const { t } = useLocale()
const profile = ref<Record<string, any> | null>(user.value)
const copiedCustomerNo = ref(false)

const displayName = computed(() => profile.value?.name || profile.value?.full_name || t('profile.fallbackName'))
const rawCustomerNo = computed(() => `${profile.value?.customer_no || profile.value?.member_no || profile.value?.id || ''}`.trim())
const customerNoText = computed(() => {
  const customerNo = rawCustomerNo.value

  return t('profile.memberCode', { code: customerNo || '-' })
})
type ProfileMenuItem = string | { label: string, to?: string, badge?: string }
const menuItemLabel = (item: ProfileMenuItem) => typeof item === 'string' ? item : item.label
const menuItemTo = (item: ProfileMenuItem) => typeof item === 'string' ? '' : item.to || ''
const menuItemBadge = (item: ProfileMenuItem) => typeof item === 'string' ? '' : item.badge || ''
const menuItemKey = (item: ProfileMenuItem) => `${menuItemLabel(item)}:${menuItemTo(item)}:${menuItemBadge(item)}`

const writeToClipboard = async (value: string) => {
  if (!process.client) {
    return false
  }

  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(value)
      return true
    } catch {
      // Fall through to the textarea fallback for embedded browsers.
    }
  }

  const textarea = document.createElement('textarea')
  textarea.value = value
  textarea.setAttribute('readonly', 'readonly')
  textarea.style.position = 'fixed'
  textarea.style.opacity = '0'
  textarea.style.pointerEvents = 'none'
  document.body.appendChild(textarea)
  textarea.select()
  textarea.setSelectionRange(0, value.length)

  try {
    return document.execCommand('copy')
  } finally {
    document.body.removeChild(textarea)
  }
}

const copyCustomerNo = async () => {
  const value = rawCustomerNo.value

  if (!value) {
    return
  }

  const copied = await writeToClipboard(value)

  if (!copied) {
    showAlert({
      title: t('profile.copyMemberCodeFailedTitle'),
      message: t('profile.copyMemberCodeFailedMessage'),
      variant: 'error'
    })
    return
  }

  copiedCustomerNo.value = true
  window.setTimeout(() => {
    copiedCustomerNo.value = false
  }, 1600)
}

onMounted(async () => {
  try {
    profile.value = await restoreAuthState(true)
  } catch (error: any) {
    showAlert({
      title: t('profile.loadFailedTitle'),
      message: error?.response?.data?.message || t('profile.loadFailedMessage'),
      variant: 'error'
    })
  }
})
</script>

<style scoped>
.profile-identity {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-top: 42px;
  padding-bottom: 34px;
  color: #fff;
}

.profile-identity h1 {
  margin: 0 0 4px;
  font-size: 24px;
  font-weight: 900;
  line-height: 1.25;
}

.profile-member-row {
  align-items: center;
  display: flex;
  gap: 8px;
  min-width: 0;
}

.profile-member-code {
  font-size: 16px;
  font-weight: 800;
  min-width: 0;
  opacity: .92;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.profile-copy-button {
  align-items: center;
  appearance: none;
  background: rgba(255, 255, 255, .18);
  border: 1px solid rgba(255, 255, 255, .28);
  border-radius: 999px;
  color: #fff;
  display: inline-flex;
  flex: 0 0 auto;
  height: 30px;
  justify-content: center;
  line-height: 1;
  padding: 0;
  transition: background .2s ease, transform .2s ease;
  width: 30px;
}

.profile-copy-button:active {
  transform: scale(.95);
}

.profile-copy-button i {
  font-size: 14px;
}

.profile-sheet {
  margin-top: 0;
  padding-top: 24px;
}

.profile-language-card {
  align-items: center;
  background: #fff;
  border: 1px solid #dbe7f5;
  border-radius: 16px;
  box-shadow: 0 12px 28px rgba(33, 55, 85, .08);
  display: flex;
  gap: 16px;
  justify-content: space-between;
  padding: 16px;
}

.profile-language-card h2 {
  color: #17335f;
  font-size: 16px;
  font-weight: 900;
  margin: 0 0 4px;
}

.profile-language-card p {
  color: #6d7f98;
  font-size: 13px;
  font-weight: 700;
  line-height: 1.45;
  margin: 0;
}

@media (max-width: 360px) {
  .profile-language-card {
    align-items: flex-start;
    flex-direction: column;
  }
}

.menu-row-main {
  align-items: center;
  display: flex;
  flex: 1 1 auto;
  gap: 8px;
  min-width: 0;
}

.menu-row-main > span:first-child {
  min-width: 0;
}

.menu-row-badge {
  background: #e8f6ff;
  border-radius: 999px;
  color: #0b74d9;
  flex: 0 0 auto;
  font-size: 11px;
  font-weight: 900;
  line-height: 1;
  padding: 4px 8px;
}
</style>

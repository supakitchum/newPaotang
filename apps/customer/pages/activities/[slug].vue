<template>
  <MobileShell active-nav="home" show-bottom-nav>
    <BlueHeader title="รายละเอียดกิจกรรม" back-to="/activities" min-height="214px" />

    <section class="content-sheet flush activity-detail-sheet">
      <article v-if="activity" class="activity-detail-card">
        <img v-if="activity.image" class="activity-detail-image" :src="activity.image" :alt="activity.name">
        <div class="activity-detail-content">
          <span class="activity-type">{{ activity.type === 'cashback' ? 'กิจกรรมรับเงินคืน' : 'กิจกรรมแผงเลขนำโชค' }}</span>
          <h1>{{ activity.name }}</h1>
          <p>{{ activity.description }}</p>
          <div class="activity-game">
            <i class="bi bi-calendar2-check" />
            <span>{{ activity.game?.name || 'งวดกิจกรรม' }}</span>
          </div>
        </div>
      </article>

      <section v-if="activity?.type === 'lucky_board'" class="activity-panel">
        <div class="panel-heading">
          <h2>เลือกเลขนำโชค</h2>
          <span>{{ rights.remaining_count || 0 }} สิทธิ์คงเหลือ</span>
        </div>

        <div class="rights-box">
          <div>
            <strong>{{ rights.earned_count || 0 }}</strong>
            <span>สิทธิ์ทั้งหมด</span>
          </div>
          <div>
            <strong>{{ rights.used_count || 0 }}</strong>
            <span>ใช้ไปแล้ว</span>
          </div>
          <div>
            <strong>{{ rights.ticket_count || 0 }}</strong>
            <span>สลากที่ซื้อ</span>
          </div>
        </div>

        <div class="prediction-tabs">
          <button
            v-for="type in enabledPredictionTypes"
            :key="type"
            type="button"
            :class="{ active: predictionType === type }"
            @click="predictionType = type"
          >
            {{ predictionLabel(type) }}
          </button>
        </div>

        <div class="number-entry">
          <input
            v-model="selectedNumber"
            inputmode="numeric"
            :maxlength="predictionDigits"
            :placeholder="`${predictionDigits} หลัก`"
            @input="selectedNumber = selectedNumber.replace(/\\D/g, '').slice(0, predictionDigits)"
          >
          <button class="primary-pill" type="button" :disabled="!canSubmitEntry || isSubmitting" @click="submitEntry">
            ส่งเลข
          </button>
        </div>

        <div v-if="entries.length" class="entry-list">
          <div v-for="entry in entries" :key="entry.id" class="entry-row">
            <span class="entry-number">{{ entry.selected_number }}</span>
            <div>
              <strong>{{ predictionLabel(entry.prediction_type) }}</strong>
              <small>{{ statusText(entry.status) }}</small>
            </div>
          </div>
        </div>
      </section>

      <section v-else-if="activity" class="activity-panel">
        <div class="panel-heading">
          <h2>สิทธิ์รับเงินคืน</h2>
          <span>{{ cashbackProgressText }}</span>
        </div>

        <div class="cashback-grid">
          <div>
            <span>ยอดซื้อในงวด</span>
            <strong>{{ formatBaht(activity.cashback_progress?.purchase_amount || 0) }}</strong>
          </div>
          <div>
            <span>จำนวนสลาก</span>
            <strong>{{ activity.cashback_progress?.ticket_count || 0 }} ใบ</strong>
          </div>
          <div>
            <span>เงื่อนไขขั้นต่ำ</span>
            <strong>{{ minConditionText }}</strong>
          </div>
        </div>
      </section>

      <section v-if="activityAwards.length" class="activity-panel">
        <div class="panel-heading">
          <h2>รางวัลกิจกรรม</h2>
          <span>{{ activityAwards.length }} รายการ</span>
        </div>
        <div class="award-list">
          <div v-for="award in activityAwards" :key="award.id" class="award-row">
            <div>
              <strong>{{ award.type === 'cashback' ? 'เงินคืนกิจกรรม' : predictionLabel(award.prediction_type) }}</strong>
              <small>{{ statusText(award.status) }}</small>
            </div>
            <div class="award-amount">{{ formatBaht(award.amount) }}</div>
            <button v-if="award.status === 'claimable'" class="outline-pill" type="button" @click="startClaim(award)">
              รับเงิน
            </button>
          </div>
        </div>
      </section>

      <section v-if="claimAward" class="activity-panel claim-panel">
        <div class="panel-heading">
          <h2>รับเงินรางวัลกิจกรรม</h2>
          <span>{{ formatBaht(claimAward.amount) }}</span>
        </div>
        <div class="claim-methods">
          <button type="button" :class="{ active: payoutMethod === 'wallet_credit' }" @click="payoutMethod = 'wallet_credit'">
            <i class="bi bi-wallet2" />
            Wallet
          </button>
          <button type="button" :class="{ active: payoutMethod === 'bank_transfer' }" @click="payoutMethod = 'bank_transfer'">
            <i class="bi bi-bank" />
            บัญชีธนาคาร
          </button>
        </div>
        <div v-if="payoutMethod === 'bank_transfer'" class="bank-form">
          <select v-model="bankAccount.bank_name">
            <option value="">เลือกธนาคาร</option>
            <option v-for="bank in thaiBankOptions" :key="bank" :value="bank">{{ bank }}</option>
          </select>
          <input v-model="bankAccount.account_name" placeholder="ชื่อบัญชี">
          <input v-model="bankAccount.account_number" inputmode="numeric" placeholder="เลขที่บัญชี">
        </div>
        <input v-model="claimPin" class="pin-input" inputmode="numeric" maxlength="6" placeholder="กรอก PIN 6 หลัก" type="password">
        <p v-if="claimError" class="claim-error">{{ claimError }}</p>
        <button class="primary-pill" type="button" :disabled="!canSubmitClaim || isSubmitting" @click="submitClaim">
          ส่งคำขอรับเงิน
        </button>
      </section>

      <section v-if="!activity && !isLoading" class="activity-detail-empty">
        <h1>ไม่พบกิจกรรม</h1>
        <p>กิจกรรมนี้อาจถูกปิดใช้งานหรือหมดช่วงแสดงผลแล้ว</p>
        <NuxtLink class="primary-pill" to="/activities">กลับหน้ากิจกรรม</NuxtLink>
      </section>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { thaiBankOptions } from '~/data/lottery'

definePageMeta({
  requiresAuth: false
})

const route = useRoute()
const platformApi = usePlatformApi()
const { token } = useAuth()
const { showAlert } = useAppAlert()
const activity = ref<Record<string, any> | null>(null)
const rights = ref<Record<string, any>>({})
const entries = ref<Record<string, any>[]>([])
const awards = ref<Record<string, any>[]>([])
const isLoading = ref(true)
const isSubmitting = ref(false)
const predictionType = ref('first_prize_last2')
const selectedNumber = ref('')
const claimAward = ref<Record<string, any> | null>(null)
const payoutMethod = ref<'wallet_credit' | 'bank_transfer'>('wallet_credit')
const claimPin = ref('')
const claimError = ref('')
const bankAccount = reactive({ bank_name: '', account_name: '', account_number: '' })

const enabledPredictionTypes = computed(() => {
  const predictions = activity.value?.config?.prediction_types || {}
  const types = ['first_prize_last2', 'first_prize_last3', 'last2'].filter((type) => predictions[type] !== false)
  return types.length > 0 ? types : ['first_prize_last2']
})
const predictionDigits = computed(() => predictionType.value === 'first_prize_last3' ? 3 : 2)
const canSubmitEntry = computed(() => Boolean(token.value && activity.value?.id && selectedNumber.value.length === predictionDigits.value && Number(rights.value.remaining_count || 0) > 0))
const activityAwards = computed(() => awards.value.filter((award) => String(award.activity_id || '') === String(activity.value?.id || '')))
const canSubmitClaim = computed(() => {
  if (!claimAward.value || claimPin.value.length !== 6) return false
  if (payoutMethod.value === 'wallet_credit') return true
  return Boolean(bankAccount.bank_name && bankAccount.account_name && bankAccount.account_number)
})
const cashbackProgressText = computed(() => activity.value?.cashback_progress?.eligible_by_purchase ? 'เข้าเงื่อนไขยอดซื้อ' : 'รอเข้าเงื่อนไข')
const minConditionText = computed(() => {
  const progress = activity.value?.cashback_progress || {}
  const minimumType = String(progress.minimum_type || 'tickets')
  const tickets = Number(progress.min_ticket_count || 0)
  const purchase = Number(progress.min_purchase_amount || 0)

  if (minimumType === 'amount') {
    return purchase > 0 ? formatBaht(purchase) : 'ไม่มีขั้นต่ำ'
  }

  return tickets > 0 ? `${tickets} ใบ` : 'ไม่มีขั้นต่ำ'
})

watch(enabledPredictionTypes, (types) => {
  if (!types.includes(predictionType.value)) {
    predictionType.value = types[0]
  }
}, { immediate: true })

const loadActivity = async () => {
  isLoading.value = true
  try {
    const publicActivity = await platformApi.activityPublic(String(route.params.slug || ''))
    activity.value = publicActivity

    if (token.value && publicActivity?.id) {
      try {
        activity.value = await platformApi.customerActivity(publicActivity.id)
        rights.value = activity.value?.rights || {}
        entries.value = Array.isArray(activity.value?.entries) ? activity.value.entries : []
        const awardResponse = await platformApi.activityAwards({ limit: 100 })
        awards.value = Array.isArray(awardResponse.data) ? awardResponse.data : []
      } catch (error) {
        console.log(error)
        rights.value = {}
        entries.value = []
        awards.value = []
      }
    }
  } catch (error) {
    console.log(error)
    activity.value = null
  } finally {
    isLoading.value = false
  }
}

const submitEntry = async () => {
  if (!token.value) {
    await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
    return
  }

  if (!activity.value?.id || !canSubmitEntry.value) return
  isSubmitting.value = true
  try {
    await platformApi.createActivityEntry(activity.value.id, {
      prediction_type: predictionType.value,
      selected_number: selectedNumber.value
    })
    selectedNumber.value = ''
    await loadActivity()
    showAlert({ title: 'ส่งเลขสำเร็จ', message: 'ระบบบันทึกเลขนำโชคของคุณแล้ว', variant: 'success' })
  } catch (error: any) {
    showAlert({ title: 'ส่งเลขไม่สำเร็จ', message: error?.response?.data?.error?.message || 'กรุณาตรวจสอบสิทธิ์และลองใหม่อีกครั้ง', variant: 'error' })
  } finally {
    isSubmitting.value = false
  }
}

const startClaim = async (award: Record<string, any>) => {
  if (!token.value) {
    await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
    return
  }
  claimAward.value = award
  payoutMethod.value = 'wallet_credit'
  claimPin.value = ''
  claimError.value = ''
}

const submitClaim = async () => {
  if (!claimAward.value || !canSubmitClaim.value) return
  isSubmitting.value = true
  claimError.value = ''
  try {
    await platformApi.createActivityClaim({
      award_id: claimAward.value.id,
      payout_method: payoutMethod.value,
      pin: claimPin.value,
      bank_account: payoutMethod.value === 'bank_transfer' ? { ...bankAccount } : null
    })
    claimAward.value = null
    claimPin.value = ''
    await loadActivity()
    showAlert({ title: 'ส่งคำขอสำเร็จ', message: 'Partner จะตรวจสอบและอนุมัติรายการของคุณ', variant: 'success' })
  } catch (error: any) {
    const code = error?.response?.data?.error?.code || error?.data?.error?.code || ''
    claimPin.value = ''
    claimError.value = code === 'pin_invalid'
      ? 'PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง'
      : code === 'pin_locked'
        ? 'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่แล้วลองใหม่'
        : 'ไม่สามารถส่งคำขอได้ กรุณาตรวจสอบข้อมูล'
  } finally {
    isSubmitting.value = false
  }
}

const predictionLabel = (type: string) => ({
  first_prize_last2: '2 ตัวรางวัลที่ 1',
  first_prize_last3: '3 ตัวรางวัลที่ 1',
  last2: '2 ตัวท้าย'
}[type] || type)
const statusText = (status: string) => ({
  submitted: 'ส่งเลขแล้ว',
  won: 'ถูกรางวัล',
  lost: 'ไม่ถูกรางวัล',
  claimable: 'รับเงินได้',
  claimed: 'ส่งคำขอแล้ว',
  paid: 'จ่ายแล้ว',
  rejected: 'ไม่อนุมัติ'
}[status] || status)
const formatBaht = (value: unknown) => Number(value || 0).toLocaleString('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' บาท'

watch(() => route.params.slug, () => {
  void loadActivity()
}, { immediate: true })

useTenantSeo({
  title: 'รายละเอียดกิจกรรม',
  description: 'กิจกรรมและสิทธิพิเศษจากร้านค้า',
  canonicalPath: `/activities/${String(route.params.slug || '')}`
})
</script>

<style scoped>
.activity-detail-sheet {
  margin-top: -54px;
  padding: 0 14px calc(38px + env(safe-area-inset-bottom));
}

.activity-detail-card,
.activity-panel,
.activity-detail-empty {
  background: #fff;
  border-radius: 18px;
  box-shadow: 0 14px 30px rgba(8, 48, 104, .1);
  overflow: hidden;
}

.activity-detail-image {
  display: block;
  max-height: 420px;
  object-fit: cover;
  width: 100%;
}

.activity-detail-content {
  display: grid;
  gap: 10px;
  padding: 18px;
}

.activity-type {
  background: #e8f4ff;
  border-radius: 999px;
  color: #0875df;
  font-size: 12px;
  font-weight: 900;
  justify-self: start;
  padding: 5px 10px;
}

.activity-detail-content h1,
.panel-heading h2 {
  color: #1f2937;
  font-size: 23px;
  font-weight: 900;
  line-height: 1.25;
  margin: 0;
}

.activity-detail-content p {
  color: #667085;
  font-size: 15px;
  line-height: 1.55;
  margin: 0;
}

.activity-game {
  align-items: center;
  color: #0b74d9;
  display: flex;
  font-size: 14px;
  font-weight: 800;
  gap: 8px;
}

.activity-panel {
  display: grid;
  gap: 14px;
  margin-top: 14px;
  padding: 18px;
}

.panel-heading {
  align-items: center;
  display: flex;
  gap: 12px;
  justify-content: space-between;
}

.panel-heading span {
  color: #0b74d9;
  font-size: 13px;
  font-weight: 900;
}

.rights-box,
.cashback-grid {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.rights-box div,
.cashback-grid div {
  background: #f6f9ff;
  border-radius: 14px;
  display: grid;
  gap: 3px;
  padding: 12px;
}

.rights-box strong,
.cashback-grid strong {
  color: #111827;
  font-size: 19px;
  font-weight: 900;
}

.rights-box span,
.cashback-grid span {
  color: #667085;
  font-size: 12px;
  font-weight: 700;
}

.prediction-tabs,
.claim-methods {
  display: grid;
  gap: 8px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.prediction-tabs button,
.claim-methods button {
  background: #f7f9fc;
  border: 1px solid #e5ebf3;
  border-radius: 14px;
  color: #516070;
  font-size: 13px;
  font-weight: 900;
  min-height: 44px;
}

.prediction-tabs button.active,
.claim-methods button.active {
  background: #e8f4ff;
  border-color: #0b7fe8;
  color: #0875df;
}

.number-entry {
  display: grid;
  gap: 10px;
  grid-template-columns: minmax(0, 1fr) 126px;
}

.number-entry input,
.bank-form input,
.bank-form select,
.pin-input {
  background: #f8fafc;
  border: 1px solid #d9e2ef;
  border-radius: 14px;
  font-size: 18px;
  font-weight: 900;
  min-height: 48px;
  padding: 0 14px;
}

.entry-list,
.award-list,
.bank-form {
  display: grid;
  gap: 10px;
}

.entry-row,
.award-row {
  align-items: center;
  background: #f8fafc;
  border-radius: 14px;
  display: grid;
  gap: 10px;
  grid-template-columns: auto minmax(0, 1fr) auto;
  padding: 12px;
}

.entry-number {
  background: #fff;
  border-radius: 10px;
  color: #0b74d9;
  font-size: 22px;
  font-weight: 900;
  letter-spacing: .08em;
  padding: 6px 10px;
}

.entry-row strong,
.award-row strong {
  color: #1f2937;
  display: block;
  font-size: 14px;
  font-weight: 900;
}

.entry-row small,
.award-row small {
  color: #7a8797;
  font-size: 12px;
  font-weight: 700;
}

.award-amount {
  color: #111827;
  font-size: 16px;
  font-weight: 900;
}

.claim-methods {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.claim-error {
  background: #fee2e2;
  border-radius: 12px;
  color: #b42318;
  font-size: 13px;
  font-weight: 800;
  margin: 0;
  padding: 10px 12px;
}

.activity-detail-empty {
  display: grid;
  gap: 12px;
  justify-items: center;
  padding: 34px 24px;
  text-align: center;
}

.activity-detail-empty h1 {
  color: #1f2937;
  font-size: 24px;
  font-weight: 900;
  margin: 0;
}

@media (max-width: 380px) {
  .rights-box,
  .cashback-grid,
  .prediction-tabs {
    grid-template-columns: 1fr;
  }

  .number-entry {
    grid-template-columns: 1fr;
  }
}
</style>

<template>
  <MobileShell time="12:38">
    <BlueHeader
      :title="headerTitle"
      back-to="/result"
      min-height="121px"
      class="result-full-hero"
    />

    <section class="content-sheet result-full-sheet">
      <div v-if="!isLoading && !errorMessage" class="result-draw-date">
        งวดวันที่ {{ drawDate }}
      </div>

      <div v-if="isLoading" class="result-detail-state">
        <i class="bi bi-arrow-repeat" />
        <h2>กำลังโหลดผลรางวัล</h2>
        <p>กรุณารอสักครู่</p>
      </div>

      <div v-else-if="errorMessage" class="result-detail-state">
        <i class="bi bi-exclamation-circle text-danger" />
        <h2>โหลดผลรางวัลไม่สำเร็จ</h2>
        <p>{{ errorMessage }}</p>
        <button class="outline-pill result-detail-retry" type="button" @click="fetchReward">
          ลองใหม่
        </button>
      </div>

      <div v-else-if="isWaitingResult" class="result-detail-state">
        <i class="bi bi-hourglass-split text-primary" />
        <h2>กำลังรอออกผล</h2>
        <p>{{ drawDate }}</p>
      </div>

      <template v-else>
        <div class="result-highlight-grid result-detail-highlight">
          <div>
            <div class="result-label">รางวัลที่ 1</div>
            <div class="result-subtitle">รางวัลละ {{ getRewardAmount(selectedGame, 'reward_1') }} บาท</div>
            <div class="result-number result-first">{{ firstReward }}</div>
          </div>
          <div>
            <div class="result-label">เลขท้าย 2 ตัว</div>
            <div class="result-subtitle">รางวัลละ {{ getRewardAmount(selectedGame, 'reward_two_digit') }} บาท</div>
            <div class="result-number result-first">{{ twoDigitReward }}</div>
          </div>
          <div>
            <div class="result-label">เลขหน้า 3 ตัว</div>
            <div class="result-subtitle">รางวัลละ {{ getRewardAmount(selectedGame, 'reward_three_digit_1') }} บาท</div>
            <div class="result-highlight-number-grid">
              <div v-for="number in frontThreeRewards" :key="`front-${number}`" class="result-number small">
                {{ number }}
              </div>
            </div>
          </div>
          <div>
            <div class="result-label">เลขท้าย 3 ตัว</div>
            <div class="result-subtitle">รางวัลละ {{ getRewardAmount(selectedGame, 'reward_three_digit_2') }} บาท</div>
            <div class="result-highlight-number-grid">
              <div v-for="number in backThreeRewards" :key="`back-${number}`" class="result-number small">
                {{ number }}
              </div>
            </div>
          </div>
        </div>

        <section
          v-for="group in detailGroups"
          :key="group.key"
          class="prize-group"
        >
          <div class="result-bar">
            <span>{{ group.title }}</span>
            <span class="muted-text">รางวัลละ {{ group.amount }} บาท</span>
          </div>
          <div
            class="result-number-grid result-detail-number-grid"
            :class="numberGridClass(group.numbers.length)"
          >
            <div v-for="number in group.numbers" :key="`${group.key}-${number}`" class="result-number small">
              {{ number }}
            </div>
          </div>
        </section>

        <div v-if="!detailGroups.length" class="result-detail-state result-detail-state-compact">
          <h2>ยังไม่มีข้อมูลเลขรางวัลเพิ่มเติม</h2>
          <p>ระบบยังไม่พบเลขรางวัลของงวดนี้</p>
        </div>

        <div class="payment-dock text-center muted-text">
          คุณสามารถขึ้นเงินรางวัลได้ที่ ธนาคารกรุงไทย ธ.ก.ส. ออมสิน ทุกสาขา หรือสำนักงานสลากกินแบ่งรัฐบาล
        </div>
      </template>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { LotteryRewardGame } from '~/composables/useLotteryReward'
import { formatDrawDateText } from '~/utils/formatDrawDate'

definePageMeta({
  requiresAuth: false
})

const route = useRoute()
const platformApi = usePlatformApi()
const game = ref<LotteryRewardGame | null>(null)
const historyGames = ref<LotteryRewardGame[]>([])
const isLoading = ref(true)
const errorMessage = ref('')
const {
  getRewardAmount,
  getRewardGroups,
  getRewardNumbers
} = useLotteryReward()

const requestedGameId = computed(() => Number(route.query.game_id || route.query.id || 0))
const allGames = computed(() => [
  ...(game.value ? [game.value] : []),
  ...historyGames.value
])
const selectedGame = computed(() => {
  if (!requestedGameId.value) {
    return game.value
  }

  return allGames.value.find((item) => Number(item.id) === requestedGameId.value) || game.value
})
const drawDate = computed(() => formatDrawDateText(selectedGame.value?.name))
const headerTitle = computed(() => 'ผลรางวัลสลากฯ')
const isWaitingResult = computed(() => Number(selectedGame.value?.status) === 1)
const firstReward = computed(() => getRewardNumbers(selectedGame.value, 'reward_1')[0] || '-')
const twoDigitReward = computed(() => getRewardNumbers(selectedGame.value, 'reward_two_digit')[0] || '-')
const frontThreeRewards = computed(() => {
  const numbers = getRewardNumbers(selectedGame.value, 'reward_three_digit_1')
  return numbers.length ? numbers : ['-']
})
const backThreeRewards = computed(() => {
  const numbers = getRewardNumbers(selectedGame.value, 'reward_three_digit_2')
  return numbers.length ? numbers : ['-']
})
const detailGroups = computed(() => getRewardGroups(selectedGame.value).filter((group) => ![
  'reward_1',
  'reward_two_digit',
  'reward_three_digit_1',
  'reward_three_digit_2'
].includes(group.key)))

const numberGridClass = (count: number) => {
  if (count <= 2) {
    return 'is-pair'
  }

  if (count <= 5) {
    return 'is-compact'
  }

  return 'is-dense'
}

const fetchReward = async () => {
  isLoading.value = true
  errorMessage.value = ''

  try {
    const response = await platformApi.rewardLegacy(requestedGameId.value || undefined)

    if (response.data?.code === 0) {
      game.value = response.data.result || null
      historyGames.value = response.data.history || response.data.histories || []
      return
    }

    errorMessage.value = response.data?.message || 'ไม่พบข้อมูลผลรางวัล'
  } catch (error) {
    errorMessage.value = (error as { response?: { data?: { message?: string } } }).response?.data?.message || 'กรุณาลองใหม่อีกครั้ง'
  } finally {
    isLoading.value = false
  }
}

onMounted(fetchReward)
</script>

<style scoped>
.result-detail-state {
  min-height: 420px;
  display: grid;
  align-content: center;
  justify-items: center;
  padding: 36px 18px;
  color: #20385f;
  text-align: center;
}

.result-detail-state-compact {
  min-height: 180px;
}

.result-detail-state i {
  margin-bottom: 16px;
  font-size: 42px;
}

.result-detail-state h2 {
  margin: 0 0 8px;
  font-size: 22px;
  font-weight: 800;
}

.result-detail-state p {
  margin: 0;
  color: #6b6e74;
  font-size: 16px;
  line-height: 1.45;
}

.result-detail-retry {
  margin-top: 22px;
}

.result-draw-date {
  margin: 0 0 20px;
  color: #20385f;
  font-size: 18px;
  font-weight: 800;
  text-align: center;
}

.result-detail-highlight {
  grid-template-columns: minmax(0, 1.25fr) minmax(0, .9fr);
  column-gap: 33px;
  row-gap: 26px;
  margin-bottom: 20px;
}

.result-highlight-number-grid {
  margin-top: 14px;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  column-gap: 18px;
  row-gap: 8px;
  text-align: left;
}

.result-detail-number-grid {
  column-gap: 18px;
  row-gap: 14px;
  padding: 14px 0 22px;
}

.result-detail-number-grid.is-pair {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.result-detail-number-grid.is-compact {
  grid-template-columns: repeat(5, minmax(0, 1fr));
}

.result-detail-number-grid.is-dense {
  grid-template-columns: repeat(5, minmax(0, 1fr));
}

.result-detail-number-grid .result-number.small {
  font-size: 17px;
  font-weight: 500;
  text-align: left;
  font-variant-numeric: tabular-nums;
}

.result-full-sheet .result-bar {
  align-items: center;
  flex-wrap: wrap;
  row-gap: 4px;
}

@media (max-width: 390px) {
  .result-detail-highlight {
    column-gap: 22px;
    row-gap: 24px;
  }

  .result-highlight-number-grid {
    column-gap: 12px;
  }

  .result-detail-number-grid {
    column-gap: 12px;
    row-gap: 12px;
  }

  .result-detail-number-grid.is-pair {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .result-detail-number-grid.is-compact,
  .result-detail-number-grid.is-dense {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .result-detail-number-grid .result-number.small {
    font-size: 16px;
  }
}
</style>

<template>
  <MobileShell time="12:53">
    <BlueHeader title="ซื้อสลากดิจิทัล" back-to="/buy" min-height="252px">
      <div class="mt-4">
        <SegmentTabs :tabs="tabs" />
      </div>
    </BlueHeader>
    <section class="content-sheet">
      <form class="search-box mb-5" @submit.prevent="searchStores">
        <i class="bi bi-search fs-5" />
        <input
          v-model="searchText"
          type="search"
          placeholder="ค้นหาร้านค้า"
        >
      </form>

      <h2 class="section-title mb-4">ร้านสลากฯ แนะนำ</h2>
      <FilterPills />
      <div class="mt-4">
        <div v-for="store in stores" :key="store.id" class="store-row">
          <span class="store-icon"><i class="bi bi-shop" /></span>
          <span class="store-name fw-bold flex-grow-1 fs-5">{{ store.name }}</span>
          <NuxtLink
            class="outline-pill store-view-button py-2"
            :to="{ path: '/stores/lotteries', query: { store_id: store.id } }"
          >
            ดูร้านค้า
          </NuxtLink>
        </div>
        <div v-if="showEmptyState" class="empty-lottery-state">
          ไม่พบร้านค้า
        </div>
        <template v-if="showSkeletonStores">
          <div v-for="item in skeletonStores" :key="`store-loading-${item}`" class="store-row store-row-placeholder">
            <span class="store-icon store-icon-placeholder" />
            <span class="store-name-placeholder" />
            <span class="store-button-placeholder" />
          </div>
        </template>
        <template v-if="isLoadingMore">
          <div v-for="item in skeletonStores" :key="`store-loading-more-${item}`" class="store-row store-row-placeholder">
            <span class="store-icon store-icon-placeholder" />
            <span class="store-name-placeholder" />
            <span class="store-button-placeholder" />
          </div>
        </template>
      </div>
    </section>
  </MobileShell>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

interface StoreItem {
  id: number | string
  name: string
  status?: number
}

interface StorePagination {
  current_page?: number
  from?: number
  last_page?: number
  per_page?: number
  to?: number
  total?: number
  seed?: number | string
}

definePageMeta({
  requiresAuth: false
})

const axios = useAxios()
const searchText = ref('')
const stores = ref<StoreItem[]>([])
const pagination = ref<StorePagination | null>(null)
const seed = ref<string | number>('')
const page = ref(1)
const isLoadingInitial = ref(false)
const isLoadingMore = ref(false)
let scrollContainer: HTMLElement | null = null

const tabs = [
  { label: 'สลากฯ ทั้งหมด', to: '/buy' },
  { label: 'ร้านค้า', to: '/stores', active: true }
]
const skeletonStores = [1, 2, 3, 4, 5, 6]
const showEmptyState = computed(() => !isLoadingInitial.value && !isLoadingMore.value && stores.value.length === 0)
const showSkeletonStores = computed(() => isLoadingInitial.value && stores.value.length === 0)
const hasNextPage = computed(() => {
  const currentPage = pagination.value?.current_page ?? page.value
  const lastPage = pagination.value?.last_page ?? 1

  return currentPage < lastPage
})

const getPostData = () => ({
  seed: seed.value || null,
  page: page.value || null,
  p: searchText.value || null
})

const getStores = async (append = false) => {
  const response = await axios.post('/stock-store', getPostData())

  if (response.data.code !== 0) {
    return
  }

  const result = response.data.result || {}
  const nextStores = result.data || []

  stores.value = append ? [...stores.value, ...nextStores] : nextStores
  pagination.value = result
  seed.value = result.seed || seed.value || ''
  page.value = result.current_page || page.value
}

const searchStores = async () => {
  isLoadingInitial.value = true
  page.value = 1
  seed.value = ''
  stores.value = []
  pagination.value = null

  try {
    await getStores()
  } catch (e) {
    console.log(e)
  } finally {
    isLoadingInitial.value = false
  }
}

const loadNextPage = async () => {
  if (isLoadingInitial.value || isLoadingMore.value || !hasNextPage.value) {
    return
  }

  isLoadingMore.value = true
  page.value = (pagination.value?.current_page ?? page.value) + 1

  try {
    await getStores(true)
  } catch (e) {
    page.value -= 1
    console.log(e)
  } finally {
    isLoadingMore.value = false
  }
}

const handleScroll = () => {
  if (!scrollContainer) {
    return
  }

  const distanceFromBottom = scrollContainer.scrollHeight - scrollContainer.scrollTop - scrollContainer.clientHeight

  if (distanceFromBottom <= 180) {
    loadNextPage()
  }
}

onMounted(async () => {
  await searchStores()
  scrollContainer = document.querySelector('.app-scroll')
  scrollContainer?.addEventListener('scroll', handleScroll, { passive: true })
})

onBeforeUnmount(() => {
  scrollContainer?.removeEventListener('scroll', handleScroll)
})
</script>

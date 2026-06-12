<template>
  <div>
    <AdminPageHeader title="Partner Lottery Branding" :breadcrumbs="['Admin', 'Central', 'Partners', partnerId, 'Lottery Branding']">
      <template #actions>
        <NuxtLink to="/admin/central/partners" class="btn btn-light btn-wave">
          <i class="ri-arrow-left-line me-1" />
          Partners
        </NuxtLink>
        <button class="btn btn-outline-primary btn-wave" type="button" :disabled="loading" @click="load">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
        <button class="btn btn-primary btn-wave" type="button" :disabled="!canSave" @click="save">
          <span v-if="saving || anyUploading" class="spinner-border spinner-border-sm me-2" />
          Save all assets
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="error" :type="alertType(error)" :message="errorMessage(error)" :details="error.details" />
    <AdminAlert v-if="saveMessage" type="success" :message="saveMessage" dismissible @dismiss="saveMessage = ''" />
    <AdminAlert
      v-if="branding?.locked"
      type="warning"
      message="This partner is locked because partner-branded images already exist."
      :details="{ fields: { generated_image_count: [String(branding.generated_image_count || 0)], lock_reason: [branding.lock_reason || 'partner_images_already_generated'] } }"
    />

    <AdminLoader v-if="loading && !branding" />

    <template v-else>
      <div class="row">
        <div class="col-sm-6 col-xl-3">
          <AdminKpiCard
            label="Status"
            :value="titleize(branding?.status || 'missing')"
            icon="ri-shield-check-line"
            :color-class="branding?.locked ? 'bg-warning-transparent text-warning' : 'bg-primary-transparent text-primary'"
          />
        </div>
        <div class="col-sm-6 col-xl-3">
          <AdminKpiCard label="Generated images" :value="branding?.generated_image_count || 0" icon="ri-image-2-line" color-class="bg-info-transparent text-info" />
        </div>
        <div class="col-sm-6 col-xl-3">
          <AdminKpiCard label="Version" :value="version" icon="ri-git-branch-line" color-class="bg-success-transparent text-success" />
        </div>
        <div class="col-sm-6 col-xl-3">
          <AdminKpiCard label="Asset set" :value="branding?.asset_set_id || 'Not set'" icon="ri-folder-image-line" color-class="bg-secondary-transparent text-secondary" />
        </div>
      </div>

      <div class="card custom-card">
        <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
          <div>
            <div class="card-title mb-1">Route-Locked Preview</div>
            <p class="text-muted mb-0 fs-12">Preview always uses partner {{ partnerId }} from this route.</p>
          </div>
          <button class="btn btn-outline-primary btn-wave" type="button" :disabled="gamesLoading" @click="loadGames">
            <span v-if="gamesLoading" class="spinner-border spinner-border-sm me-1" />
            <i v-else class="ri-list-check-2 me-1" />
            Reload games
          </button>
        </div>
        <div class="card-body">
          <AdminAlert v-if="gamesError" :type="alertType(gamesError)" :message="errorMessage(gamesError)" :details="gamesError.details" dismissible @dismiss="gamesError = null" />
          <AdminAlert v-if="previewError" :type="alertType(previewError)" :message="errorMessage(previewError)" :details="previewError.details" dismissible @dismiss="previewError = null" />

          <div class="row g-3">
            <div class="col-md-4 col-xl-3">
              <label class="form-label" for="branding-preview-game-id">Game</label>
              <select id="branding-preview-game-id" v-model="previewForm.game_id" class="form-select" :disabled="gamesLoading">
                <option value="">{{ gamesLoading ? 'Loading games...' : 'Select game' }}</option>
                <option v-if="unknownPreviewGame" :value="previewForm.game_id">{{ unknownGameLabel(previewForm.game_id) }}</option>
                <option v-for="game in gameOptions" :key="game.id" :value="game.id">{{ game.label }}</option>
              </select>
              <div class="form-text">{{ selectedGameText }}</div>
            </div>
            <div class="col-md-4 col-xl-2">
              <label class="form-label" for="branding-preview-version">Version</label>
              <input id="branding-preview-version" v-model.trim="previewForm.version" class="form-control" placeholder="v1">
            </div>
            <div class="col-md-4 col-xl-2">
              <label class="form-label" for="branding-preview-set-type">Set Type</label>
              <select id="branding-preview-set-type" v-model="previewForm.set_type" class="form-select">
                <option v-for="setType in setTypes" :key="setType" :value="setType">{{ titleize(setType) }}</option>
              </select>
            </div>
            <div class="col-md-4 col-xl-2">
              <label class="form-label" for="branding-preview-number">Lottery Number</label>
              <input id="branding-preview-number" v-model.trim="previewForm.lottery_number" class="form-control" inputmode="numeric" maxlength="6" placeholder="123456">
            </div>
            <div class="col-md-4 col-xl-1">
              <label class="form-label" for="branding-preview-variant">Variant</label>
              <select id="branding-preview-variant" v-model="previewForm.variant" class="form-select">
                <option value="full">Full</option>
                <option value="thumb">Thumb</option>
              </select>
            </div>
            <div class="col-md-4 col-xl-2 d-flex align-items-end">
              <button class="btn btn-primary btn-wave w-100" type="button" :disabled="!canPreview" @click="renderPreview">
                <span v-if="previewLoading" class="spinner-border spinner-border-sm me-2" />
                Preview
              </button>
            </div>
          </div>

          <AdminAlert v-if="selectedGameWarning" class="mt-3" type="warning" :message="selectedGameWarning" />

          <div v-if="previewResult" class="row g-3 mt-1">
            <div class="col-lg-5">
              <div class="border rounded d-flex align-items-center justify-content-center bg-light overflow-hidden p-2" style="min-height: 260px;">
                <img v-if="previewResult.data_url" :src="previewResult.data_url" alt="Partner lottery branding preview" class="img-fluid" style="max-height: 360px; object-fit: contain;">
                <AdminEmptyState v-else title="No image returned" message="The preview response did not include a data URL." icon="ri-image-line" />
              </div>
            </div>
            <div class="col-lg-7">
              <div class="border rounded p-3 h-100">
                <div class="d-flex flex-wrap gap-2 mb-3">
                  <AdminStatusBadge :status="previewResult.mode" :label="titleize(previewResult.mode || '-')" />
                  <AdminStatusBadge v-if="previewResult.fallback_mode" status="warning" :label="`Fallback: ${titleize(previewResult.fallback_mode)}`" />
                </div>
                <div class="row g-2 small">
                  <div v-for="item in previewDetails" :key="item.key" class="col-md-6">
                    <div class="border rounded p-2 h-100">
                      <div class="text-muted fs-12">{{ item.label }}</div>
                      <div class="text-break">{{ item.value }}</div>
                    </div>
                  </div>
                </div>
                <div class="mt-3">
                  <div class="fw-semibold mb-2">Warnings</div>
                  <AdminEmptyState v-if="!previewWarnings.length" title="No warnings" message="Backend returned no fallback warnings for this preview." icon="ri-checkbox-circle-line" />
                  <div v-else class="d-flex flex-wrap gap-2">
                    <span v-for="warning in previewWarnings" :key="warning" class="badge bg-warning-transparent text-warning">{{ warning }}</span>
                  </div>
                </div>
                <div class="mt-3">
                  <div class="fw-semibold mb-2">Side effects</div>
                  <div class="d-flex flex-wrap gap-2">
                    <span class="badge bg-success-transparent text-success">Stock rows {{ previewResult.side_effects?.stock_rows_created ?? 0 }}</span>
                    <span class="badge bg-success-transparent text-success">Permanent images {{ previewResult.side_effects?.permanent_image_rows_created ?? 0 }}</span>
                    <span class="badge bg-success-transparent text-success">Branding locked {{ yesNo(Boolean(previewResult.side_effects?.branding_locked)) }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="card custom-card">
        <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-3">
          <div>
            <div class="card-title mb-1">Branding Assets</div>
            <p class="text-muted mb-0 fs-12">Central scope only</p>
          </div>
          <div class="d-flex align-items-center gap-2">
            <label class="form-label mb-0" for="lottery-branding-version">Version</label>
            <input
              id="lottery-branding-version"
              v-model="version"
              class="form-control form-control-sm"
              type="text"
              :disabled="isLocked || saving || anyUploading"
              style="max-width: 160px;"
            >
          </div>
        </div>
      </div>

      <div class="row g-3">
        <div v-for="slot in slots" :key="slot.key" class="col-xl-4">
          <div class="card custom-card h-100">
            <div class="card-header d-flex align-items-center justify-content-between">
              <div class="card-title mb-0">
                <i :class="[slot.icon, 'me-2']" />
                {{ slot.label }}
              </div>
              <AdminStatusBadge v-if="assetForSlot(slot.key)?.status" :status="assetForSlot(slot.key)?.status" />
              <AdminStatusBadge v-else status="missing" />
            </div>
            <div class="card-body d-flex flex-column gap-3">
              <div class="border rounded d-flex align-items-center justify-content-center bg-light overflow-hidden" style="min-height: 184px;">
                <img
                  v-if="previewUrlFor(slot.key)"
                  :src="previewUrlFor(slot.key)"
                  :alt="`${slot.label} preview`"
                  class="img-fluid"
                  style="max-height: 180px; object-fit: contain;"
                >
                <div v-else class="text-center text-muted py-4">
                  <i :class="[slot.icon, 'fs-1', 'd-block', 'mb-2']" />
                  <span>No preview</span>
                </div>
              </div>

              <div>
                <label class="form-label" :for="`branding-file-${slot.key}`">Replace asset</label>
                <input
                  :id="`branding-file-${slot.key}`"
                  class="form-control"
                  type="file"
                  accept="image/*"
                  :disabled="isLocked || saving || slotState[slot.key].uploading"
                  @change="onFileChange(slot.key, $event)"
                >
                <div class="form-text">Image file, up to 5 MB.</div>
              </div>

              <AdminAlert v-if="slotState[slot.key].error" type="danger" :message="slotState[slot.key].error" />

              <div v-if="slotState[slot.key].file" class="border rounded p-3">
                <div class="fw-semibold mb-2">Selected file</div>
                <div class="d-flex flex-column gap-1 small">
                  <div class="d-flex justify-content-between gap-2">
                    <span class="text-muted">Name</span>
                    <span class="text-end text-break">{{ slotState[slot.key].file?.name }}</span>
                  </div>
                  <div class="d-flex justify-content-between gap-2">
                    <span class="text-muted">Size</span>
                    <span>{{ formatBytes(slotState[slot.key].file?.size || 0) }}</span>
                  </div>
                  <div class="d-flex justify-content-between gap-2">
                    <span class="text-muted">Dimensions</span>
                    <span>{{ slotState[slot.key].dimensions || 'Pending' }}</span>
                  </div>
                </div>
              </div>

              <div class="border rounded p-3 h-100">
                <div class="fw-semibold mb-2">Current asset</div>
                <div class="d-flex flex-column gap-1 small">
                  <div v-for="item in assetMetadata(slot.key)" :key="item.key" class="d-flex justify-content-between gap-2">
                    <span class="text-muted">{{ item.label }}</span>
                    <code v-if="item.mono" class="np-admin-code text-break text-end">{{ item.value }}</code>
                    <span v-else class="text-break text-end">{{ item.value }}</span>
                  </div>
                </div>
              </div>
            </div>
            <div class="card-footer d-flex justify-content-end gap-2">
              <button class="btn btn-light btn-wave" type="button" :disabled="!slotState[slot.key].file || slotState[slot.key].uploading || saving" @click="clearSlot(slot.key)">
                Clear
              </button>
              <button class="btn btn-outline-primary btn-wave" type="button" :disabled="!canUploadSlot(slot.key)" @click="uploadSlot(slot.key)">
                <span v-if="slotState[slot.key].uploading" class="spinner-border spinner-border-sm me-2" />
                Upload & save
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="card custom-card mt-3">
        <div class="card-body d-flex flex-wrap align-items-center justify-content-between gap-3">
          <div class="d-flex align-items-center gap-2">
            <AdminStatusBadge :status="isLocked" :label="isLocked ? 'Locked' : 'Editable'" />
            <span class="text-muted">Updated {{ formatDateTime(branding?.updated_at) }}</span>
          </div>
          <button class="btn btn-primary btn-wave" type="button" :disabled="!canSave" @click="save">
            <span v-if="saving || anyUploading" class="spinner-border spinner-border-sm me-2" />
            Save all assets
          </button>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, titleize } from '~/utils/format'

type BrandingSlot = 'logo_qr' | 'right_sidebar' | 'logo_bottom'
type SetType = 'odd' | 'even' | 'charity'
type PreviewVariant = 'full' | 'thumb'

type GameOption = {
  id: string
  code?: string | null
  name: string
  status?: string | null
  label: string
}

type BrandingAsset = {
  asset_id?: string
  id?: string
  file_name?: string | null
  content_type?: string | null
  size_bytes?: number | null
  storage_path?: string | null
  storage_key?: string | null
  url?: string | null
  status?: string | null
  updated_at?: string | null
}

type BrandingResponse = {
  partner_id: string
  asset_set_id?: string | null
  version?: string | null
  status?: string | null
  locked?: boolean
  lock_reason?: string | null
  generated_image_count?: number
  assets?: Record<BrandingSlot, BrandingAsset | null>
  updated_at?: string | null
}

type LotteryPreviewResponse = {
  mode?: string
  requested_mode?: string
  fallback_mode?: string | null
  warnings?: string[]
  game_id?: string
  version?: string
  set_type?: SetType
  partner_id?: string | null
  lottery_number?: string
  variant?: PreviewVariant
  content_type?: string
  width?: number
  height?: number
  data_url?: string
  side_effects?: {
    stock_rows_created?: number
    permanent_image_rows_created?: number
    branding_locked?: boolean
  }
}

type SlotState = {
  file: File | null
  previewUrl: string
  dimensions: string
  error: string
  committedAsset: BrandingAsset | null
  uploading: boolean
}

const props = defineProps<{
  partnerId: string
}>()

const api = useAdminApi()
const session = useAdminSession()
const loading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const saveMessage = ref('')
const branding = ref<BrandingResponse | null>(null)
const version = ref('v1')
const games = ref<GameOption[]>([])
const gamesLoading = ref(false)
const gamesLoaded = ref(false)
const gamesError = ref<any>(null)
const previewLoading = ref(false)
const previewError = ref<any>(null)
const previewResult = ref<LotteryPreviewResponse | null>(null)

const slots: Array<{ key: BrandingSlot, label: string, icon: string }> = [
  { key: 'logo_qr', label: 'Logo QR', icon: 'ri-qr-code-line' },
  { key: 'right_sidebar', label: 'Right Sidebar', icon: 'ri-layout-right-line' },
  { key: 'logo_bottom', label: 'Logo Bottom', icon: 'ri-layout-bottom-line' },
]
const setTypes: SetType[] = ['odd', 'even', 'charity']

const slotState = reactive<Record<BrandingSlot, SlotState>>({
  logo_qr: emptySlotState(),
  right_sidebar: emptySlotState(),
  logo_bottom: emptySlotState(),
})
const previewForm = reactive({
  game_id: '',
  version: 'v1',
  set_type: 'odd' as SetType,
  lottery_number: '123456',
  variant: 'full' as PreviewVariant,
})

const isLocked = computed(() => Boolean(branding.value?.locked))
const anyUploading = computed(() => Object.values(slotState).some((state) => state.uploading))
const gameOptions = computed(() => games.value)
const selectedGame = computed(() => gameById(previewForm.game_id))
const unknownPreviewGame = computed(() => Boolean(previewForm.game_id && gamesLoaded.value && !selectedGame.value))
const selectedGameText = computed(() => selectedGame.value ? `${selectedGame.value.name} (${selectedGame.value.status || 'unknown'})` : 'Select a central game to render this partner composition.')
const selectedGameWarning = computed(() => {
  if (!previewForm.game_id || gamesLoading.value || !gamesLoaded.value) return ''
  if (!selectedGame.value) return `Game ${previewForm.game_id} was not returned by the central games API. It may be missing or archived; preview can still send the ID.`
  if (selectedGame.value.status === 'archived') return `${selectedGame.value.name} is archived. Review before previewing branded composition.`
  return ''
})
const canPreview = computed(() => Boolean(
  props.partnerId
  && previewForm.game_id.trim()
  && previewForm.version.trim()
  && previewForm.set_type
  && /^[0-9]{1,6}$/.test(previewForm.lottery_number)
  && !previewLoading.value,
))
const previewWarnings = computed(() => previewResult.value?.warnings || [])
const previewDetails = computed(() => {
  const result = previewResult.value
  if (!result) return []

  return [
    { key: 'game', label: 'Game', value: `${gameName(result.game_id)} (${result.game_id || '-'})` },
    { key: 'partner', label: 'Partner', value: result.partner_id || props.partnerId },
    { key: 'number', label: 'Lottery number', value: result.lottery_number || '-' },
    { key: 'set', label: 'Set / version', value: `${titleize(result.set_type || '-')} / ${result.version || '-'}` },
    { key: 'variant', label: 'Variant', value: titleize(result.variant || '-') },
    { key: 'size', label: 'Image size', value: result.width && result.height ? `${result.width} x ${result.height}` : '-' },
  ]
})
const canSave = computed(() => {
  if (isLocked.value || loading.value || saving.value || anyUploading.value) {
    return false
  }

  return slots.every((slot) => Boolean(assetIdForSlot(slot.key) || slotState[slot.key].file))
})

const load = async () => {
  if (!props.partnerId) return

  loading.value = true
  error.value = null
  saveMessage.value = ''

  try {
    const response = await api.apiFetch<BrandingResponse>(`/admin/central/partners/${encodeURIComponent(props.partnerId)}/lottery-branding-assets`, {
      scope: 'central',
    })
    branding.value = response
    version.value = response.version || 'v1'
    previewForm.version = version.value
  } catch (err) {
    error.value = err
  } finally {
    loading.value = false
  }
}

const loadGames = async () => {
  gamesLoading.value = true
  gamesError.value = null

  try {
    const response = await api.apiFetch('/admin/central/games', { scope: 'central' })
    games.value = extractItems(response).map(normalizeGame).filter((game) => game.id)
    gamesLoaded.value = true
  } catch (err) {
    gamesError.value = err
    games.value = []
    gamesLoaded.value = true
  } finally {
    gamesLoading.value = false
  }
}

const renderPreview = async () => {
  if (!canPreview.value) return

  previewLoading.value = true
  previewError.value = null
  previewResult.value = null

  try {
    previewResult.value = await api.apiFetch<LotteryPreviewResponse>(`/admin/central/partners/${encodeURIComponent(props.partnerId)}/lottery-branding/preview`, {
      method: 'POST',
      scope: 'central',
      body: {
        game_id: previewForm.game_id,
        version: previewForm.version || 'v1',
        set_type: previewForm.set_type,
        lottery_number: previewForm.lottery_number,
        variant: previewForm.variant,
      },
    })
  } catch (err) {
    previewError.value = err
  } finally {
    previewLoading.value = false
  }
}

const onFileChange = async (slot: BrandingSlot, event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] || null
  const state = slotState[slot]

  clearSlot(slot)

  if (!file) {
    return
  }

  state.file = file
  const validationError = validateFile(file)

  if (validationError) {
    state.error = validationError
    input.value = ''
    return
  }

  state.previewUrl = URL.createObjectURL(file)

  try {
    state.dimensions = await imageDimensions(state.previewUrl)
  } catch {
    state.error = 'The selected image could not be read.'
  }
}

const clearSlot = (slot: BrandingSlot) => {
  const state = slotState[slot]

  if (state.previewUrl && import.meta.client) {
    URL.revokeObjectURL(state.previewUrl)
  }

  state.file = null
  state.previewUrl = ''
  state.dimensions = ''
  state.error = ''
  state.committedAsset = null
  state.uploading = false
}

const canUploadSlot = (slot: BrandingSlot) => {
  const state = slotState[slot]

  return Boolean(state.file && !state.error && !state.uploading && !saving.value && !isLocked.value)
}

const uploadSlot = async (slot: BrandingSlot, options: { persist?: boolean } = { persist: true }): Promise<string | null> => {
  const state = slotState[slot]

  if (state.committedAsset?.asset_id) {
    if (options.persist !== false) {
      await persistAssetSet(`Partner branding ${slotLabel(slot)} saved.`)
    }
    return state.committedAsset.asset_id
  }

  if (!state.file || state.error) {
    return assetIdForSlot(slot)
  }

  state.uploading = true
  state.error = ''

  try {
    const file = state.file
    const checksum = await sha256Hex(file)
    const intent: any = await api.apiFetch('/admin/central/assets/uploads', {
      method: 'POST',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        purpose: 'partner_lottery_branding',
        file_name: file.name,
        content_type: file.type || 'image/webp',
        size_bytes: file.size,
        checksum_sha256: checksum,
        metadata: {
          partner_id: props.partnerId,
          branding_slot: slot,
          version: version.value || 'v1',
        },
      },
    })

    await uploadToStorage(intent, file)

    const committed: any = await api.apiFetch(`/admin/central/assets/${encodeURIComponent(intent.asset_id)}/commit`, {
      method: 'POST',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        checksum_sha256: checksum,
        metadata: {
          partner_id: props.partnerId,
          branding_slot: slot,
          version: version.value || 'v1',
          source_file_name: file.name,
        },
      },
    })

    state.committedAsset = normalizeAsset(committed)
    if (options.persist !== false) {
      await persistAssetSet(`Partner branding ${slotLabel(slot)} saved.`)
    } else {
      saveMessage.value = `${slotLabel(slot)} uploaded.`
    }
    return state.committedAsset.asset_id || null
  } catch (err: any) {
    state.error = errorMessage(err)
    throw err
  } finally {
    state.uploading = false
  }
}

const collectAssetIds = () => {
  const assetIds: Record<BrandingSlot, string> = {
    logo_qr: '',
    right_sidebar: '',
    logo_bottom: '',
  }
  const missing: BrandingSlot[] = []

  for (const slot of slots) {
    const assetId = assetIdForSlot(slot.key)
    if (!assetId) {
      missing.push(slot.key)
    }
    assetIds[slot.key] = assetId
  }

  return { assetIds, missing }
}

const persistAssetSet = async (successMessage = 'Partner branding assets saved.') => {
  const { assetIds, missing } = collectAssetIds()

  if (missing.length) {
    saveMessage.value = `Uploaded. Add ${missing.map(slotLabel).join(', ')} to activate branding.`
    return null
  }

  const response = await api.apiFetch<BrandingResponse>(`/admin/central/partners/${encodeURIComponent(props.partnerId)}/lottery-branding-assets`, {
    method: 'PUT',
    scope: 'central',
    idempotencyKey: api.idempotencyKey(),
    body: {
      version: version.value || 'v1',
      assets: {
        logo_qr: { asset_id: assetIds.logo_qr },
        right_sidebar: { asset_id: assetIds.right_sidebar },
        logo_bottom: { asset_id: assetIds.logo_bottom },
      },
    },
  })

  branding.value = response
  version.value = response.version || version.value || 'v1'
  previewForm.version = version.value
  clearPersistedUploads(response)
  saveMessage.value = successMessage

  return response
}

const save = async () => {
  if (!canSave.value) return

  saving.value = true
  error.value = null
  saveMessage.value = ''

  try {
    for (const slot of slots) {
      const assetId = await uploadSlot(slot.key, { persist: false })
      if (!assetId) {
        slotState[slot.key].error = `${slot.label} is required.`
        throw new Error(`${slot.label} is required.`)
      }
    }

    await persistAssetSet()
  } catch (err: any) {
    if (!err?.message?.includes?.('is required')) {
      error.value = err
    }
  } finally {
    saving.value = false
  }
}

const assetForSlot = (slot: BrandingSlot): BrandingAsset | null => {
  return slotState[slot].committedAsset || branding.value?.assets?.[slot] || null
}

const assetIdForSlot = (slot: BrandingSlot): string => {
  const asset = assetForSlot(slot)
  return String(asset?.asset_id || asset?.id || '')
}

const previewUrlFor = (slot: BrandingSlot) => {
  const asset = assetForSlot(slot)
  return slotState[slot].previewUrl || cacheBustedAssetUrl(asset)
}

const assetMetadata = (slot: BrandingSlot) => {
  const asset = assetForSlot(slot)

  return [
    { key: 'asset_id', label: 'Asset ID', value: assetIdForSlot(slot) || '-', mono: true },
    { key: 'file_name', label: 'File', value: asset?.file_name || '-' },
    { key: 'content_type', label: 'Type', value: asset?.content_type || '-' },
    { key: 'size_bytes', label: 'Size', value: asset?.size_bytes ? formatBytes(asset.size_bytes) : '-' },
    { key: 'storage_path', label: 'Storage', value: asset?.storage_path || asset?.storage_key || '-', mono: true },
  ]
}

const allowedImageExtensions = new Set(['png', 'jpg', 'jpeg', 'webp', 'gif'])

const validateFile = (file: File) => {
  const extension = file.name.split('.').pop()?.toLowerCase() || ''

  if (!allowedImageExtensions.has(extension)) {
    return 'Only image files are accepted.'
  }

  if (file.size < 1 || file.size > 5 * 1024 * 1024) {
    return 'Image size must be between 1 byte and 5 MB.'
  }

  return ''
}

const imageDimensions = (url: string): Promise<string> => new Promise((resolve, reject) => {
  const image = new Image()
  image.onload = () => resolve(`${image.naturalWidth} x ${image.naturalHeight}`)
  image.onerror = reject
  image.src = url
})

const sha256Hex = async (file: File) => {
  if (!import.meta.client || !window.crypto?.subtle) {
    return null
  }

  const hash = await window.crypto.subtle.digest('SHA-256', await file.arrayBuffer())
  return Array.from(new Uint8Array(hash)).map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

const uploadToStorage = async (intent: any, file: File) => {
  if (!intent?.upload_url || intent.production_storage_ready === false || intent.storage_mode === 'local_dev_metadata_only') {
    if (intent?.asset_id && intent.storage_mode === 'local_dev_metadata_only') {
      const body = new FormData()
      body.append('file', file)
      await api.apiFetch(`/admin/central/assets/${encodeURIComponent(intent.asset_id)}/local-upload`, {
        method: 'POST',
        scope: 'central',
        successMessage: false,
        body,
      })
    }

    return
  }

  const method = String(intent.method || 'PUT').toUpperCase()

  if (method === 'POST' && intent.form_fields && typeof intent.form_fields === 'object') {
    const formData = new FormData()
    Object.entries(intent.form_fields).forEach(([key, value]) => formData.append(key, String(value)))
    formData.append('file', file)
    await $fetch(intent.upload_url, { method: 'POST', body: formData })
    return
  }

  await $fetch(intent.upload_url, {
    method,
    headers: intent.headers || {},
    body: file,
  })
}

const normalizeAsset = (asset: any): BrandingAsset => ({
  asset_id: asset?.asset_id || asset?.id,
  id: asset?.id || asset?.asset_id,
  file_name: asset?.file_name || null,
  content_type: asset?.content_type || null,
  size_bytes: asset?.size_bytes ?? null,
  storage_path: asset?.storage_path || asset?.storage_key || null,
  storage_key: asset?.storage_key || asset?.storage_path || null,
  url: asset?.url || asset?.public_url || null,
  status: asset?.status || null,
  updated_at: asset?.updated_at || null,
})

const cacheBustedAssetUrl = (asset: BrandingAsset | null) => {
  const url = assetPreviewUrl(asset)
  if (!url) return ''

  const token = String(asset?.asset_id || asset?.id || asset?.updated_at || branding.value?.updated_at || '').trim()
  if (!token) return url

  const separator = url.includes('?') ? '&' : '?'
  return `${url}${separator}v=${encodeURIComponent(token)}`
}

const assetPreviewUrl = (asset: BrandingAsset | null) => {
  return publicAssetUrl(asset?.storage_path || asset?.storage_key) || asset?.url || ''
}

const publicAssetUrl = (path?: string | null) => {
  const cleaned = String(path || '').trim().replace(/^\/+/, '')
  if (!cleaned) return ''

  const encodedPath = cleaned.split('/').map((segment) => encodeURIComponent(segment)).join('/')
  return `${api.apiBase.value}/public/assets/${encodedPath}`
}

const clearPersistedUploads = (response: BrandingResponse) => {
  for (const slot of slots) {
    const persistedAssetId = response.assets?.[slot.key]?.asset_id || response.assets?.[slot.key]?.id
    const pendingAssetId = slotState[slot.key].committedAsset?.asset_id || slotState[slot.key].committedAsset?.id

    if (persistedAssetId && pendingAssetId && String(persistedAssetId) === String(pendingAssetId)) {
      clearSlot(slot.key)
    }
  }
}

const alertType = (err: any) => {
  if ([403, 409, 422].includes(Number(err?.status))) {
    return 'warning'
  }

  return 'danger'
}

const errorMessage = (err: any) => {
  if (Number(err?.status) === 403) {
    return 'You do not have permission to manage partner branding assets.'
  }

  if (Number(err?.status) === 409 || err?.code === 'resource_conflict') {
    return 'Partner branding assets are locked or the request conflicts with the current asset state.'
  }

  if (Number(err?.status) === 422 || err?.code === 'validation_failed') {
    return err?.message || 'The backend rejected the preview request.'
  }

  return err?.message || 'The request failed.'
}

const slotLabel = (slot: BrandingSlot) => slots.find((item) => item.key === slot)?.label || titleize(slot)
const yesNo = (value: boolean) => value ? 'Yes' : 'No'
const gameById = (gameId?: string | null) => games.value.find((game) => game.id === gameId) || null
const gameName = (gameId?: string | null) => gameById(gameId)?.name || gameId || '-'
const unknownGameLabel = (gameId: string) => `Unknown or archived game (${gameId})`

const normalizeGame = (game: any): GameOption => {
  const id = String(game?.id || game?.game_id || game?.uuid || game?.code || '')
  const name = String(game?.name || game?.game_name || game?.title || game?.code || id)
  const code = game?.code && game.code !== name ? ` (${game.code})` : ''
  const status = game?.status || null
  return {
    id,
    name,
    code: game?.code || null,
    status,
    label: `${name}${code}${status ? ` - ${titleize(status)}` : ''}`,
  }
}

const extractItems = (response: any) => {
  if (Array.isArray(response?.data)) return response.data
  if (Array.isArray(response?.data?.data)) return response.data.data
  if (Array.isArray(response?.items)) return response.items
  if (Array.isArray(response)) return response
  return []
}

const formatBytes = (bytes: number) => {
  if (!bytes) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB']
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  return `${(bytes / (1024 ** index)).toFixed(index === 0 ? 0 : 1)} ${units[index]}`
}

function emptySlotState(): SlotState {
  return {
    file: null,
    previewUrl: '',
    dimensions: '',
    error: '',
    committedAsset: null,
    uploading: false,
  }
}

watch(version, (value, oldValue) => {
  if (!previewForm.version || previewForm.version === oldValue || previewForm.version === 'v1') {
    previewForm.version = value || 'v1'
  }
})

onMounted(async () => {
  session.setScope('central')
  await Promise.all([load(), loadGames()])
})
</script>

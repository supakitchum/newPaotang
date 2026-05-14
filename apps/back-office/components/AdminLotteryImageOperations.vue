<template>
  <div>
    <AdminPageHeader title="Lottery Image Operations" :breadcrumbs="['Admin', 'Central', 'Lottery Images']">
      <template #actions>
        <button class="btn btn-outline-primary btn-wave" type="button" :disabled="loadingAny" @click="loadAll">
          <span v-if="loadingAny" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="pageError" :type="alertType(pageError)" :message="errorMessage(pageError)" :details="pageError.details" dismissible @dismiss="pageError = null" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />
    <AdminAlert v-if="contextError" type="warning" :message="contextError" dismissible @dismiss="contextError = ''" />

    <div class="card custom-card">
      <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-3">
        <div>
          <div class="card-title mb-1">Game Context</div>
          <p class="text-muted mb-0 fs-12">Central scope only. Writes include idempotency keys.</p>
        </div>
        <div class="d-flex flex-wrap gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="loadingAny" @click="resetContext">
            Reset
          </button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="!canLoadContext || loadingAny" @click="loadAll">
            <span v-if="loadingAny" class="spinner-border spinner-border-sm me-2" />
            Load operations
          </button>
        </div>
      </div>
      <div class="card-body">
        <div class="row g-3">
          <div class="col-lg-4">
            <label class="form-label" for="lottery-images-game-id">Game ID <span class="text-danger">*</span></label>
            <input id="lottery-images-game-id" v-model.trim="context.game_id" class="form-control" placeholder="gam_lottery">
          </div>
          <div class="col-lg-4">
            <label class="form-label" for="lottery-images-batch-id">Batch ID</label>
            <input id="lottery-images-batch-id" v-model.trim="context.batch_id" class="form-control" placeholder="Optional batch filter">
          </div>
          <div class="col-lg-4">
            <label class="form-label" for="lottery-images-version">Background Version</label>
            <input id="lottery-images-version" v-model.trim="context.version" class="form-control" placeholder="v1">
          </div>
        </div>
      </div>
    </div>

    <div class="row">
      <div v-for="card in readinessCards" :key="card.key" class="col-sm-6 col-xl-3">
        <AdminKpiCard :label="card.label" :value="card.value" :icon="card.icon" :color-class="card.color" />
      </div>
    </div>

    <div class="row g-3">
      <div class="col-xl-8">
        <div class="card custom-card h-100">
          <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
            <div>
              <div class="card-title mb-1">Readiness Dashboard</div>
              <p class="text-muted mb-0 fs-12">Missing background sets, pending assets, failed generation, and last backend errors.</p>
            </div>
            <AdminStatusBadge v-if="readiness" :status="readiness.missing_set_types?.length ? 'pending_assets' : 'ready'" :label="readiness.missing_set_types?.length ? 'Needs assets' : 'Ready'" />
          </div>
          <div class="card-body">
            <AdminLoader v-if="readinessLoading" />
            <AdminEmptyState v-else-if="!readiness" title="No readiness loaded" message="Enter a game ID and load operations." icon="ri-image-2-line" />
            <template v-else>
              <div class="row g-3 mb-3">
                <div class="col-md-4">
                  <div class="border rounded p-3 h-100">
                    <div class="text-muted fs-12 mb-1">Game</div>
                    <code class="np-admin-code text-break">{{ readiness.game_id || '-' }}</code>
                  </div>
                </div>
                <div class="col-md-4">
                  <div class="border rounded p-3 h-100">
                    <div class="text-muted fs-12 mb-1">Batch</div>
                    <code class="np-admin-code text-break">{{ readiness.batch_id || '-' }}</code>
                  </div>
                </div>
                <div class="col-md-4">
                  <div class="border rounded p-3 h-100">
                    <div class="text-muted fs-12 mb-1">Version</div>
                    <code class="np-admin-code text-break">{{ readiness.version || '-' }}</code>
                  </div>
                </div>
              </div>

              <div class="d-flex flex-wrap gap-2 mb-3">
                <span v-for="setType in setTypes" :key="setType" :class="missingSetTypes.includes(setType) ? 'badge bg-warning-transparent text-warning' : 'badge bg-success-transparent text-success'">
                  {{ titleize(setType) }} {{ missingSetTypes.includes(setType) ? 'missing' : 'ready' }}
                </span>
              </div>

              <div class="table-responsive">
                <table class="table table-hover text-nowrap mb-0">
                  <thead>
                    <tr>
                      <th>Set Type</th>
                      <th>Status</th>
                      <th>Generation</th>
                      <th>Missing Slots</th>
                      <th>Updated</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="item in readinessBackgrounds" :key="`${item.id || item.set_type}-${item.version}`">
                      <td>{{ titleize(item.set_type || '-') }}</td>
                      <td><AdminStatusBadge :status="item.status || (item.ready ? 'ready' : 'missing')" /></td>
                      <td>
                        <AdminStatusBadge :status="item.generation_ready ? 'ready' : 'pending_assets'" :label="item.generation_ready ? 'Ready' : 'Blocked'" />
                      </td>
                      <td>{{ arrayText(item.missing_assets) }}</td>
                      <td>{{ formatDateTime(item.updated_at) }}</td>
                    </tr>
                    <tr v-if="!readinessBackgrounds.length">
                      <td colspan="5">
                        <AdminEmptyState title="No background readiness" message="The backend did not return background readiness rows for this filter." icon="ri-folder-image-line" />
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <div class="mt-3">
                <div class="fw-semibold mb-2">Last Errors</div>
                <AdminEmptyState v-if="!lastErrors.length" title="No recent errors" message="Backend did not return lottery image generation error samples." icon="ri-checkbox-circle-line" />
                <div v-else class="list-group">
                  <div v-for="(item, index) in lastErrors" :key="index" class="list-group-item">
                    <div class="d-flex flex-wrap justify-content-between gap-2">
                      <span class="fw-semibold">{{ item.stock_item_id || item.local_stock_item_id || item.id || `Error ${index + 1}` }}</span>
                      <AdminStatusBadge :status="item.status || 'failed'" />
                    </div>
                    <div class="text-muted text-break">{{ item.image_generation_error || item.error || item.message || '-' }}</div>
                  </div>
                </div>
              </div>
            </template>
          </div>
        </div>
      </div>

      <div class="col-xl-4">
        <div class="card custom-card h-100">
          <div class="card-header">
            <div class="card-title">Production Readiness</div>
          </div>
          <div class="card-body">
            <AdminLoader v-if="productionLoading" />
            <AdminEmptyState v-else-if="!productionReadiness" title="No production readiness loaded" message="Load operations to inspect storage, queue, and runtime state." icon="ri-server-line" />
            <template v-else>
              <div class="d-flex align-items-center justify-content-between mb-3">
                <span class="text-muted">Production</span>
                <AdminStatusBadge :status="productionReadiness.production_ready ? 'ready' : 'blocked'" :label="productionReadiness.production_ready ? 'Ready' : 'Blocked'" />
              </div>
              <div class="d-flex flex-column gap-2 small">
                <div v-for="item in productionItems" :key="item.key" class="d-flex justify-content-between gap-2">
                  <span class="text-muted">{{ item.label }}</span>
                  <span class="text-end text-break">{{ item.value }}</span>
                </div>
              </div>
              <hr>
              <div class="fw-semibold mb-2">Queues</div>
              <div class="d-flex flex-column gap-2 small">
                <div v-for="item in queueItems" :key="item.key" class="d-flex justify-content-between gap-2">
                  <span class="text-muted">{{ item.label }}</span>
                  <span class="text-end text-break">{{ item.value }}</span>
                </div>
              </div>
              <hr>
              <div class="fw-semibold mb-2">Blocking Reasons</div>
              <AdminEmptyState v-if="!blockingReasons.length" title="No blockers" message="Production readiness did not return blocking reasons." icon="ri-checkbox-circle-line" />
              <div v-else class="d-flex flex-wrap gap-2">
                <span v-for="reason in blockingReasons" :key="reason" class="badge bg-warning-transparent text-warning">{{ reason }}</span>
              </div>
            </template>
          </div>
        </div>
      </div>
    </div>

    <div class="row g-3 mt-0">
      <div class="col-xl-7">
        <div class="card custom-card h-100">
          <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
            <div>
              <div class="card-title mb-1">Background Asset Sets</div>
              <p class="text-muted mb-0 fs-12">Grouped by game, version, and set type.</p>
            </div>
            <button class="btn btn-outline-primary btn-wave" type="button" :disabled="assetSetsLoading || !canLoadContext" @click="loadBackgroundSets">
              <span v-if="assetSetsLoading" class="spinner-border spinner-border-sm me-1" />
              <i v-else class="ri-refresh-line me-1" />
              Refresh sets
            </button>
          </div>
          <div class="card-body">
            <AdminLoader v-if="assetSetsLoading" />
            <AdminEmptyState v-else-if="!assetSets.length" title="No background asset sets" message="Create a source/full/thumb set for odd, even, or charity." icon="ri-folder-image-line" />
            <div v-else class="table-responsive">
              <table class="table table-hover text-nowrap mb-0">
                <thead>
                  <tr>
                    <th>Game / Version</th>
                    <th>Set</th>
                    <th>Status</th>
                    <th>Assets</th>
                    <th>Updated</th>
                    <th class="text-end">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="set in assetSets" :key="set.id">
                    <td>
                      <div class="fw-semibold">{{ set.game_id }}</div>
                      <code class="np-admin-code">{{ set.version }}</code>
                    </td>
                    <td>{{ titleize(set.set_type || '-') }}</td>
                    <td>
                      <div class="d-flex flex-column gap-1">
                        <AdminStatusBadge :status="set.status" />
                        <AdminStatusBadge :status="set.generation_ready ? 'ready' : 'pending_assets'" :label="set.generation_ready ? 'Generation ready' : 'Storage blocked'" />
                      </div>
                    </td>
                    <td>
                      <div class="d-flex flex-column gap-1 small">
                        <span v-for="slot in slots" :key="slot.key">
                          {{ slot.label }}:
                          <code class="np-admin-code">{{ assetId(set, slot.key) || '-' }}</code>
                        </span>
                      </div>
                    </td>
                    <td>{{ formatDateTime(set.updated_at) }}</td>
                    <td>
                      <div class="d-flex flex-wrap justify-content-end gap-1">
                        <button class="btn btn-sm btn-light btn-wave" type="button" @click="fillAssetForm(set)">
                          Use
                        </button>
                        <button class="btn btn-sm btn-outline-success btn-wave" type="button" :disabled="statusUpdating" @click="openStatusConfirm(set, 'ready')">
                          Reactivate
                        </button>
                        <button class="btn btn-sm btn-outline-warning btn-wave" type="button" :disabled="statusUpdating" @click="openStatusConfirm(set, 'inactive')">
                          Inactive
                        </button>
                        <button class="btn btn-sm btn-outline-danger btn-wave" type="button" :disabled="statusUpdating" @click="openStatusConfirm(set, 'retired')">
                          Retire
                        </button>
                        <button class="btn btn-sm btn-primary btn-wave" type="button" :disabled="statusUpdating" @click="openStatusConfirm(set, 'ready', true)">
                          Supersede
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <div class="col-xl-5">
        <div class="card custom-card h-100">
          <div class="card-header">
            <div class="card-title">Create / Update Background Set</div>
          </div>
          <div class="card-body">
            <AdminAlert v-if="assetFormError" :type="alertType(assetFormError)" :message="errorMessage(assetFormError)" :details="assetFormError.details" dismissible @dismiss="assetFormError = null" />
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label" for="asset-set-game-id">Game ID</label>
                <input id="asset-set-game-id" v-model.trim="assetForm.game_id" class="form-control" placeholder="gam_lottery">
              </div>
              <div class="col-md-6">
                <label class="form-label" for="asset-set-version">Version</label>
                <input id="asset-set-version" v-model.trim="assetForm.version" class="form-control" placeholder="v1">
              </div>
              <div class="col-md-6">
                <label class="form-label" for="asset-set-type">Set Type</label>
                <select id="asset-set-type" v-model="assetForm.set_type" class="form-select">
                  <option v-for="setType in setTypes" :key="setType" :value="setType">{{ titleize(setType) }}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label" for="asset-set-status">Status</label>
                <select id="asset-set-status" v-model="assetForm.status" class="form-select">
                  <option value="ready">Ready</option>
                  <option value="inactive">Inactive</option>
                  <option value="retired">Retired</option>
                </select>
              </div>
              <div class="col-12">
                <div class="form-check form-switch">
                  <input id="asset-set-supersede" v-model="assetForm.supersede_existing" class="form-check-input" type="checkbox">
                  <label class="form-check-label" for="asset-set-supersede">Supersede existing active set for this game/version/type</label>
                </div>
              </div>
            </div>

            <div class="row g-3 mt-1">
              <div v-for="slot in slots" :key="slot.key" class="col-12">
                <div class="border rounded p-3">
                  <div class="d-flex flex-wrap justify-content-between gap-2 mb-2">
                    <div>
                      <div class="fw-semibold">
                        <i :class="[slot.icon, 'me-1']" />
                        {{ slot.label }}
                      </div>
                      <div class="text-muted fs-12">{{ slot.help }}</div>
                    </div>
                    <AdminStatusBadge :status="assetSlotReady(slot.key) ? 'ready' : 'missing'" :label="assetSlotReady(slot.key) ? 'Asset ready' : 'Missing'" />
                  </div>
                  <div class="row g-2">
                    <div class="col-md-7">
                      <label class="form-label" :for="`asset-id-${slot.key}`">Asset ID</label>
                      <input :id="`asset-id-${slot.key}`" v-model.trim="assetForm.assets[slot.key].asset_id" class="form-control" placeholder="ast_...">
                    </div>
                    <div class="col-md-5">
                      <label class="form-label" :for="`asset-file-${slot.key}`">Upload</label>
                      <input
                        :id="`asset-file-${slot.key}`"
                        class="form-control"
                        type="file"
                        :accept="slot.accept"
                        :disabled="assetForm.assets[slot.key].uploading || assetSubmitting"
                        @change="onAssetFileChange(slot.key, $event)"
                      >
                    </div>
                  </div>
                  <AdminAlert v-if="assetForm.assets[slot.key].error" type="danger" :message="assetForm.assets[slot.key].error" />
                  <div v-if="assetForm.assets[slot.key].previewUrl" class="border rounded bg-light d-flex align-items-center justify-content-center mt-3 overflow-hidden" style="min-height: 144px;">
                    <img :src="assetForm.assets[slot.key].previewUrl" :alt="`${slot.label} preview`" class="img-fluid" style="max-height: 140px; object-fit: contain;">
                  </div>
                  <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3">
                    <div class="small text-muted">
                      <span v-if="assetForm.assets[slot.key].file">{{ assetForm.assets[slot.key].file?.name }} · {{ formatBytes(assetForm.assets[slot.key].file?.size || 0) }}</span>
                      <span v-else>No new file selected</span>
                    </div>
                    <div class="d-flex gap-2">
                      <button class="btn btn-sm btn-light btn-wave" type="button" :disabled="assetForm.assets[slot.key].uploading || assetSubmitting" @click="clearAssetSlot(slot.key)">
                        Clear
                      </button>
                      <button class="btn btn-sm btn-outline-primary btn-wave" type="button" :disabled="!canUploadAssetSlot(slot.key)" @click="uploadAssetSlot(slot.key)">
                        <span v-if="assetForm.assets[slot.key].uploading" class="spinner-border spinner-border-sm me-1" />
                        Upload & commit
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="card-footer d-flex flex-wrap justify-content-end gap-2">
            <button class="btn btn-light btn-wave" type="button" :disabled="assetSubmitting" @click="resetAssetForm">
              Reset form
            </button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="!canSubmitAssetSet" @click="saveBackgroundSet">
              <span v-if="assetSubmitting" class="spinner-border spinner-border-sm me-2" />
              Register set
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="row g-3 mt-0">
      <div class="col-xl-5">
        <div class="card custom-card h-100">
          <div class="card-header">
            <div class="card-title">Mix Settings</div>
          </div>
          <div class="card-body">
            <AdminAlert v-if="mixError" :type="alertType(mixError)" :message="errorMessage(mixError)" :details="mixError.details" dismissible @dismiss="mixError = null" />
            <AdminLoader v-if="mixLoading" />
            <div v-else class="row g-3">
              <div class="col-12">
                <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 border rounded p-3">
                  <div>
                    <div class="fw-semibold">Current Source</div>
                    <div class="text-muted fs-12">{{ mix?.source ? titleize(mix.source) : 'Not loaded' }}</div>
                  </div>
                  <AdminStatusBadge :status="mixTotal === 100 ? 'ready' : 'validation_failed'" :label="`${mixTotal}% total`" />
                </div>
              </div>
              <div v-for="setType in setTypes" :key="setType" class="col-md-4">
                <label class="form-label" :for="`mix-${setType}`">{{ titleize(setType) }}</label>
                <input :id="`mix-${setType}`" v-model.number="mixForm[setType]" class="form-control" type="number" min="0" max="100" step="1">
              </div>
              <div class="col-12">
                <AdminAlert v-if="mixTotal !== 100" type="warning" message="Odd, even, and charity percentages must sum to 100 before saving." />
              </div>
            </div>
          </div>
          <div class="card-footer d-flex justify-content-end gap-2">
            <button class="btn btn-light btn-wave" type="button" :disabled="mixSubmitting" @click="resetMixForm">
              Reset
            </button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="!canSaveMix" @click="saveMix">
              <span v-if="mixSubmitting" class="spinner-border spinner-border-sm me-2" />
              Save mix
            </button>
          </div>
        </div>
      </div>

      <div class="col-xl-7">
        <div class="card custom-card h-100">
          <div class="card-header">
            <div class="card-title">Retry Pending Images</div>
          </div>
          <div class="card-body">
            <AdminAlert v-if="retryError" :type="alertType(retryError)" :message="errorMessage(retryError)" :details="retryError.details" dismissible @dismiss="retryError = null" />
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label" for="retry-game-id">Game ID</label>
                <input id="retry-game-id" v-model.trim="retryForm.game_id" class="form-control" placeholder="Optional">
              </div>
              <div class="col-md-6">
                <label class="form-label" for="retry-batch-id">Batch ID</label>
                <input id="retry-batch-id" v-model.trim="retryForm.batch_id" class="form-control" placeholder="Optional">
              </div>
              <div class="col-md-6">
                <label class="form-label" for="retry-version">Version</label>
                <input id="retry-version" v-model.trim="retryForm.version" class="form-control" placeholder="Optional">
              </div>
              <div class="col-md-6">
                <label class="form-label" for="retry-limit">Limit</label>
                <input id="retry-limit" v-model.number="retryForm.limit" class="form-control" type="number" min="1" max="1000" step="1">
              </div>
              <div class="col-12">
                <div class="d-flex flex-wrap gap-3">
                  <div v-for="setType in setTypes" :key="setType" class="form-check">
                    <input :id="`retry-set-${setType}`" v-model="retryForm.set_types" class="form-check-input" type="checkbox" :value="setType">
                    <label class="form-check-label" :for="`retry-set-${setType}`">{{ titleize(setType) }}</label>
                  </div>
                </div>
              </div>
            </div>

            <div v-if="retryResult" class="border rounded p-3 mt-3">
              <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-2">
                <div class="fw-semibold">{{ retryResult.dry_run ? 'Dry-run preview' : 'Execute result' }}</div>
                <AdminStatusBadge :status="retryResult.dry_run ? 'preview' : 'completed'" :label="retryResult.dry_run ? 'Preview' : 'Executed'" />
              </div>
              <div class="row g-3">
                <div class="col-md-6">
                  <div class="border rounded p-3 h-100">
                    <div class="text-muted fs-12">Central</div>
                    <div class="fs-5 fw-semibold">{{ retryResult.central?.ready_count ?? 0 }} ready / {{ retryResult.central?.dispatched_count ?? 0 }} dispatched</div>
                    <code class="np-admin-code">{{ retryResult.central?.queue || '-' }}</code>
                  </div>
                </div>
                <div class="col-md-6">
                  <div class="border rounded p-3 h-100">
                    <div class="text-muted fs-12">Partner</div>
                    <div class="fs-5 fw-semibold">{{ retryResult.partner?.ready_count ?? 0 }} ready / {{ retryResult.partner?.dispatched_count ?? 0 }} dispatched</div>
                    <code class="np-admin-code">{{ retryResult.partner?.queue || '-' }}</code>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="card-footer d-flex flex-wrap justify-content-end gap-2">
            <button class="btn btn-outline-primary btn-wave" type="button" :disabled="retrySubmitting" @click="runRetry(true)">
              <span v-if="retrySubmitting && retryMode === 'dry-run'" class="spinner-border spinner-border-sm me-2" />
              Dry-run preview
            </button>
            <button class="btn btn-danger btn-wave" type="button" :disabled="retrySubmitting" @click="confirmExecuteRetry">
              <span v-if="retrySubmitting && retryMode === 'execute'" class="spinner-border spinner-border-sm me-2" />
              Execute retry
            </button>
          </div>
        </div>
      </div>
    </div>

    <AdminModal v-model="statusConfirm.open" title="Confirm Background Status" size="md">
      <AdminApiState :error="statusError" />
      <p class="text-muted mb-3">{{ statusConfirmMessage }}</p>
      <div class="border rounded bg-light p-3">
        <dl class="row small mb-0">
          <dt class="col-4 text-muted">Asset Set</dt>
          <dd class="col-8 text-break">{{ statusConfirm.set?.id || '-' }}</dd>
          <dt class="col-4 text-muted">Set Type</dt>
          <dd class="col-8">{{ titleize(statusConfirm.set?.set_type || '-') }}</dd>
          <dt class="col-4 text-muted">Version</dt>
          <dd class="col-8">{{ statusConfirm.set?.version || '-' }}</dd>
        </dl>
      </div>
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" @click="statusConfirm.open = false">Cancel</button>
        <button class="btn btn-primary btn-wave" type="button" :disabled="statusUpdating" @click="submitStatusUpdate">
          <span v-if="statusUpdating" class="spinner-border spinner-border-sm me-2" />
          Confirm
        </button>
      </template>
    </AdminModal>

    <AdminModal v-model="retryConfirmOpen" title="Execute Pending Retry" size="md">
      <AdminApiState :error="retryError" />
      <p class="text-muted mb-3">This will dispatch ready pending central and partner lottery image jobs using the selected filters.</p>
      <div class="alert alert-warning d-flex align-items-start gap-2">
        <i class="ri-error-warning-line fs-18" />
        <div>Run a dry-run preview first when working against production data.</div>
      </div>
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" @click="retryConfirmOpen = false">Cancel</button>
        <button class="btn btn-danger btn-wave" type="button" :disabled="retrySubmitting" @click="runRetry(false)">
          <span v-if="retrySubmitting" class="spinner-border spinner-border-sm me-2" />
          Execute retry
        </button>
      </template>
    </AdminModal>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, titleize } from '~/utils/format'

type SetType = 'odd' | 'even' | 'charity'
type AssetSlot = 'source' | 'full' | 'thumb'
type BackgroundStatus = 'ready' | 'inactive' | 'retired'

type BackgroundAsset = {
  asset_id?: string | null
  id?: string | null
  storage_path?: string | null
  storage_key?: string | null
  content_type?: string | null
  width?: number | null
  height?: number | null
  size_bytes?: number | null
  storage_available?: boolean
  url?: string | null
  public_url?: string | null
}

type BackgroundSet = {
  id: string
  game_id: string
  version: string
  set_type: SetType
  status: BackgroundStatus
  ready?: boolean
  generation_ready?: boolean
  missing_assets?: AssetSlot[]
  assets?: Record<AssetSlot, BackgroundAsset | null>
  activated_at?: string | null
  retired_at?: string | null
  updated_at?: string | null
  updated_by?: string | null
}

type MixResponse = {
  game_id: string
  source: string
  mix: Record<SetType, number>
  updated_at?: string | null
  updated_by?: string | null
}

type ProductionReadiness = {
  configured: boolean
  disk: string
  disk_driver?: string | null
  bucket_present: boolean
  region_present: boolean
  endpoint_present: boolean
  cdn_base_url_present: boolean
  queue_configured: boolean
  runtime_webp_ready: boolean
  secrets_redacted: boolean
  production_ready: boolean
  blocking_reasons?: string[]
  queues?: {
    queue_configured?: boolean
    jobs_can_run?: boolean
    connection?: string
    required_queue_names?: string[]
    central_queue?: string
    partner_queue?: string
    worker_commands?: string[]
  }
}

type ReadinessResponse = {
  game_id: string
  batch_id?: string | null
  version: string
  backgrounds?: BackgroundSet[]
  missing_set_types?: SetType[]
  pending_assets?: { central: number, partner: number, total: number }
  failed_generation?: { central: number, partner: number, total: number }
  last_error_samples?: any[]
  mix?: MixResponse
  storage_readiness?: ProductionReadiness
  queue_readiness?: ProductionReadiness['queues']
}

type AssetSlotState = {
  asset_id: string
  file: File | null
  previewUrl: string
  error: string
  uploading: boolean
  committedAsset: BackgroundAsset | null
}

const api = useAdminApi()
const session = useAdminSession()

const setTypes: SetType[] = ['odd', 'even', 'charity']
const slots: Array<{ key: AssetSlot, label: string, icon: string, accept: string, help: string, maxSize: number, allowedTypes: string[] }> = [
  {
    key: 'source',
    label: 'Source',
    icon: 'ri-image-line',
    accept: 'image/png,image/jpeg,image/webp',
    help: 'PNG, JPEG, or WebP. Maximum 10 MB.',
    maxSize: 10 * 1024 * 1024,
    allowedTypes: ['image/png', 'image/jpeg', 'image/webp'],
  },
  {
    key: 'full',
    label: 'Full',
    icon: 'ri-image-2-line',
    accept: 'image/webp',
    help: 'WebP variant, expected 500 x 280. Maximum 5 MB.',
    maxSize: 5 * 1024 * 1024,
    allowedTypes: ['image/webp'],
  },
  {
    key: 'thumb',
    label: 'Thumb',
    icon: 'ri-gallery-line',
    accept: 'image/webp',
    help: 'WebP thumbnail, expected 280 x 157. Maximum 1 MB.',
    maxSize: 1024 * 1024,
    allowedTypes: ['image/webp'],
  },
]

const context = reactive({
  game_id: '',
  batch_id: '',
  version: 'v1',
})

const pageError = ref<any>(null)
const contextError = ref('')
const successMessage = ref('')
const readinessLoading = ref(false)
const assetSetsLoading = ref(false)
const productionLoading = ref(false)
const mixLoading = ref(false)
const readiness = ref<ReadinessResponse | null>(null)
const assetSets = ref<BackgroundSet[]>([])
const productionReadiness = ref<ProductionReadiness | null>(null)
const mix = ref<MixResponse | null>(null)

const mixForm = reactive<Record<SetType, number>>({
  odd: 45,
  even: 45,
  charity: 10,
})
const mixError = ref<any>(null)
const mixSubmitting = ref(false)

const assetForm = reactive({
  game_id: '',
  version: 'v1',
  set_type: 'odd' as SetType,
  status: 'ready' as BackgroundStatus,
  supersede_existing: true,
  assets: emptyAssetSlots(),
})
const assetFormError = ref<any>(null)
const assetSubmitting = ref(false)

const statusConfirm = reactive<{
  open: boolean
  set: BackgroundSet | null
  status: BackgroundStatus
  supersede: boolean
}>({
  open: false,
  set: null,
  status: 'ready',
  supersede: false,
})
const statusError = ref<any>(null)
const statusUpdating = ref(false)

const retryForm = reactive({
  game_id: '',
  batch_id: '',
  version: '',
  set_types: [...setTypes] as SetType[],
  limit: 500,
})
const retryError = ref<any>(null)
const retrySubmitting = ref(false)
const retryMode = ref<'dry-run' | 'execute'>('dry-run')
const retryResult = ref<any>(null)
const retryConfirmOpen = ref(false)

const canLoadContext = computed(() => context.game_id.trim() !== '')
const loadingAny = computed(() => readinessLoading.value || assetSetsLoading.value || productionLoading.value || mixLoading.value)
const missingSetTypes = computed(() => readiness.value?.missing_set_types || [])
const readinessBackgrounds = computed(() => readiness.value?.backgrounds || [])
const lastErrors = computed(() => readiness.value?.last_error_samples || [])
const blockingReasons = computed(() => productionReadiness.value?.blocking_reasons || [])
const mixTotal = computed(() => setTypes.reduce((sum, key) => sum + normalizedPercent(mixForm[key]), 0))
const canSaveMix = computed(() => Boolean(canLoadContext.value && mixTotal.value === 100 && !mixSubmitting.value && !mixLoading.value))
const canSubmitAssetSet = computed(() => {
  if (assetSubmitting.value) return false
  if (!assetForm.game_id.trim() || !assetForm.version.trim() || !assetForm.set_type) return false
  return slots.every((slot) => assetSlotReady(slot.key))
})

const readinessCards = computed(() => [
  {
    key: 'missing',
    label: 'Missing Sets',
    value: missingSetTypes.value.length,
    icon: 'ri-folder-warning-line',
    color: missingSetTypes.value.length ? 'bg-warning-transparent text-warning' : 'bg-success-transparent text-success',
  },
  {
    key: 'pending',
    label: 'Pending Assets',
    value: readiness.value?.pending_assets?.total ?? 0,
    icon: 'ri-time-line',
    color: 'bg-info-transparent text-info',
  },
  {
    key: 'failed',
    label: 'Failed Generation',
    value: readiness.value?.failed_generation?.total ?? 0,
    icon: 'ri-error-warning-line',
    color: (readiness.value?.failed_generation?.total ?? 0) > 0 ? 'bg-danger-transparent text-danger' : 'bg-secondary-transparent text-secondary',
  },
  {
    key: 'production',
    label: 'Production Ready',
    value: productionReadiness.value?.production_ready ? 'Yes' : 'No',
    icon: 'ri-server-line',
    color: productionReadiness.value?.production_ready ? 'bg-success-transparent text-success' : 'bg-warning-transparent text-warning',
  },
])

const productionItems = computed(() => {
  const item = productionReadiness.value
  if (!item) return []

  return [
    { key: 'configured', label: 'Configured', value: yesNo(item.configured) },
    { key: 'disk', label: 'Disk', value: item.disk || '-' },
    { key: 'driver', label: 'Driver', value: item.disk_driver || '-' },
    { key: 'bucket', label: 'Bucket', value: yesNo(item.bucket_present) },
    { key: 'region', label: 'Region', value: yesNo(item.region_present) },
    { key: 'endpoint', label: 'Endpoint', value: yesNo(item.endpoint_present) },
    { key: 'cdn', label: 'CDN / Base URL', value: yesNo(item.cdn_base_url_present) },
    { key: 'runtime', label: 'WebP Runtime', value: yesNo(item.runtime_webp_ready) },
    { key: 'redacted', label: 'Secrets Redacted', value: yesNo(item.secrets_redacted) },
  ]
})

const queueItems = computed(() => {
  const queue = productionReadiness.value?.queues || readiness.value?.queue_readiness
  if (!queue) return []

  return [
    { key: 'configured', label: 'Configured', value: yesNo(Boolean(queue.queue_configured)) },
    { key: 'jobs', label: 'Jobs Can Run', value: yesNo(Boolean(queue.jobs_can_run)) },
    { key: 'connection', label: 'Connection', value: queue.connection || '-' },
    { key: 'central', label: 'Central Queue', value: queue.central_queue || '-' },
    { key: 'partner', label: 'Partner Queue', value: queue.partner_queue || '-' },
    { key: 'required', label: 'Required Queues', value: arrayText(queue.required_queue_names) },
  ]
})

const statusConfirmMessage = computed(() => {
  const action = statusConfirm.supersede ? 'supersede and mark ready' : `set status to ${statusConfirm.status}`
  return `Confirm ${action} for this background asset set.`
})

watch(() => context.game_id, (value) => {
  if (!assetForm.game_id) {
    assetForm.game_id = value
  }
  if (!retryForm.game_id) {
    retryForm.game_id = value
  }
})

watch(() => context.version, (value) => {
  if (!assetForm.version || assetForm.version === 'v1') {
    assetForm.version = value || 'v1'
  }
  if (!retryForm.version) {
    retryForm.version = value
  }
})

const loadAll = async () => {
  contextError.value = ''

  if (!canLoadContext.value) {
    contextError.value = 'Game ID is required before loading lottery image operations.'
    return
  }

  await Promise.all([
    loadReadiness(),
    loadBackgroundSets(),
    loadMix(),
    loadProductionReadiness(),
  ])
}

const loadReadiness = async () => {
  if (!canLoadContext.value) return

  readinessLoading.value = true
  pageError.value = null

  try {
    const response = await api.apiFetch<ReadinessResponse>('/admin/central/lottery-images/readiness', {
      scope: 'central',
      query: queryContext(),
    })
    readiness.value = response
    if (response.storage_readiness) {
      productionReadiness.value = response.storage_readiness
    }
    if (response.mix) {
      mix.value = response.mix
      applyMix(response.mix)
    }
  } catch (err) {
    pageError.value = err
  } finally {
    readinessLoading.value = false
  }
}

const loadBackgroundSets = async () => {
  if (!canLoadContext.value) return

  assetSetsLoading.value = true
  pageError.value = null

  try {
    const response: any = await api.apiFetch('/admin/central/lottery-images/background-asset-sets', {
      scope: 'central',
      query: {
        game_id: context.game_id,
        ...(context.version ? { version: context.version } : {}),
      },
    })
    assetSets.value = Array.isArray(response?.data) ? response.data : []
  } catch (err) {
    pageError.value = err
  } finally {
    assetSetsLoading.value = false
  }
}

const loadMix = async () => {
  if (!canLoadContext.value) return

  mixLoading.value = true
  mixError.value = null

  try {
    const response = await api.apiFetch<MixResponse>('/admin/central/lottery-images/mix', {
      scope: 'central',
      query: { game_id: context.game_id },
    })
    mix.value = response
    applyMix(response)
  } catch (err) {
    mixError.value = err
  } finally {
    mixLoading.value = false
  }
}

const loadProductionReadiness = async () => {
  productionLoading.value = true
  pageError.value = null

  try {
    productionReadiness.value = await api.apiFetch<ProductionReadiness>('/admin/central/lottery-images/production-readiness', {
      scope: 'central',
    })
  } catch (err) {
    pageError.value = err
  } finally {
    productionLoading.value = false
  }
}

const saveMix = async () => {
  if (!canSaveMix.value) return

  mixSubmitting.value = true
  mixError.value = null
  successMessage.value = ''

  try {
    const response = await api.apiFetch<MixResponse>('/admin/central/lottery-images/mix', {
      method: 'PUT',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        game_id: context.game_id,
        mix: {
          odd: normalizedPercent(mixForm.odd),
          even: normalizedPercent(mixForm.even),
          charity: normalizedPercent(mixForm.charity),
        },
      },
    })
    mix.value = response
    applyMix(response)
    successMessage.value = 'Lottery image mix saved.'
    await loadReadiness()
  } catch (err) {
    mixError.value = err
  } finally {
    mixSubmitting.value = false
  }
}

const saveBackgroundSet = async () => {
  if (!canSubmitAssetSet.value) return

  assetSubmitting.value = true
  assetFormError.value = null
  successMessage.value = ''

  try {
    for (const slot of slots) {
      if (assetForm.assets[slot.key].file && !assetForm.assets[slot.key].asset_id) {
        await uploadAssetSlot(slot.key)
      }
    }

    const response = await api.apiFetch<BackgroundSet>('/admin/central/lottery-images/background-asset-sets', {
      method: 'PUT',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        game_id: assetForm.game_id,
        version: assetForm.version,
        set_type: assetForm.set_type,
        status: assetForm.status,
        supersede_existing: Boolean(assetForm.supersede_existing),
        assets: {
          source: { asset_id: assetForm.assets.source.asset_id },
          full: { asset_id: assetForm.assets.full.asset_id },
          thumb: { asset_id: assetForm.assets.thumb.asset_id },
        },
      },
    })

    successMessage.value = `${titleize(response.set_type)} background set registered.`
    context.game_id = response.game_id || context.game_id
    context.version = response.version || context.version
    await Promise.all([loadBackgroundSets(), loadReadiness()])
  } catch (err) {
    assetFormError.value = err
  } finally {
    assetSubmitting.value = false
  }
}

const onAssetFileChange = (slot: AssetSlot, event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] || null
  clearAssetSlot(slot)

  if (!file) {
    return
  }

  const state = assetForm.assets[slot]
  const validationError = validateAssetFile(slot, file)
  state.file = file

  if (validationError) {
    state.error = validationError
    input.value = ''
    return
  }

  state.previewUrl = URL.createObjectURL(file)
}

const uploadAssetSlot = async (slot: AssetSlot) => {
  const state = assetForm.assets[slot]

  if (state.asset_id && !state.file) {
    return state.asset_id
  }

  if (!state.file || state.error) {
    return state.asset_id
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
        purpose: 'ticket_image',
        file_name: file.name,
        content_type: file.type || (slot === 'source' ? 'image/png' : 'image/webp'),
        size_bytes: file.size,
        checksum_sha256: checksum,
        metadata: {
          lottery_image_operation: 'background_asset_set',
          game_id: assetForm.game_id || context.game_id,
          version: assetForm.version || context.version || 'v1',
          set_type: assetForm.set_type,
          slot,
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
          lottery_image_operation: 'background_asset_set',
          game_id: assetForm.game_id || context.game_id,
          version: assetForm.version || context.version || 'v1',
          set_type: assetForm.set_type,
          slot,
          file_name: file.name,
        },
      },
    })

    const normalized = normalizeAsset(committed)
    state.committedAsset = normalized
    state.asset_id = String(normalized.asset_id || normalized.id || intent.asset_id || '')
    successMessage.value = `${slotLabel(slot)} uploaded and committed.`
    return state.asset_id
  } catch (err: any) {
    state.error = errorMessage(err)
    throw err
  } finally {
    state.uploading = false
  }
}

const fillAssetForm = (set: BackgroundSet) => {
  assetForm.game_id = set.game_id
  assetForm.version = set.version
  assetForm.set_type = set.set_type
  assetForm.status = set.status || 'ready'
  assetForm.supersede_existing = false

  for (const slot of slots) {
    clearAssetSlot(slot.key)
    const asset = set.assets?.[slot.key] || null
    assetForm.assets[slot.key].asset_id = String(asset?.asset_id || asset?.id || '')
    assetForm.assets[slot.key].committedAsset = asset
    assetForm.assets[slot.key].previewUrl = asset?.url || asset?.public_url || ''
  }
}

const openStatusConfirm = (set: BackgroundSet, status: BackgroundStatus, supersede = false) => {
  statusError.value = null
  statusConfirm.set = set
  statusConfirm.status = status
  statusConfirm.supersede = supersede
  statusConfirm.open = true
}

const submitStatusUpdate = async () => {
  if (!statusConfirm.set) return

  statusUpdating.value = true
  statusError.value = null
  successMessage.value = ''

  try {
    const response = await api.apiFetch<BackgroundSet>(`/admin/central/lottery-images/background-asset-sets/${encodeURIComponent(statusConfirm.set.id)}`, {
      method: 'PATCH',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        status: statusConfirm.status,
        supersede_existing: statusConfirm.supersede,
      },
    })
    successMessage.value = `${titleize(response.set_type)} set status updated.`
    statusConfirm.open = false
    await Promise.all([loadBackgroundSets(), loadReadiness()])
  } catch (err) {
    statusError.value = err
  } finally {
    statusUpdating.value = false
  }
}

const confirmExecuteRetry = () => {
  retryError.value = null
  retryConfirmOpen.value = true
}

const runRetry = async (dryRun: boolean) => {
  retrySubmitting.value = true
  retryMode.value = dryRun ? 'dry-run' : 'execute'
  retryError.value = null
  successMessage.value = ''

  try {
    retryResult.value = await api.apiFetch('/admin/central/lottery-images/retry-pending', {
      method: 'POST',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: retryPayload(dryRun),
    })
    retryConfirmOpen.value = false
    successMessage.value = dryRun ? 'Pending retry dry-run completed.' : 'Pending retry dispatched.'

    if (!dryRun && canLoadContext.value) {
      await loadReadiness()
    }
  } catch (err) {
    retryError.value = err
  } finally {
    retrySubmitting.value = false
  }
}

const resetContext = () => {
  context.game_id = ''
  context.batch_id = ''
  context.version = 'v1'
  readiness.value = null
  assetSets.value = []
  mix.value = null
  productionReadiness.value = null
  contextError.value = ''
}

const resetAssetForm = () => {
  assetForm.game_id = context.game_id
  assetForm.version = context.version || 'v1'
  assetForm.set_type = 'odd'
  assetForm.status = 'ready'
  assetForm.supersede_existing = true

  for (const slot of slots) {
    clearAssetSlot(slot.key)
  }
}

const resetMixForm = () => {
  if (mix.value) {
    applyMix(mix.value)
    return
  }

  mixForm.odd = 45
  mixForm.even = 45
  mixForm.charity = 10
}

const clearAssetSlot = (slot: AssetSlot) => {
  const state = assetForm.assets[slot]

  if (state.previewUrl && import.meta.client && state.file) {
    URL.revokeObjectURL(state.previewUrl)
  }

  state.asset_id = ''
  state.file = null
  state.previewUrl = ''
  state.error = ''
  state.uploading = false
  state.committedAsset = null
}

const canUploadAssetSlot = (slot: AssetSlot) => {
  const state = assetForm.assets[slot]
  return Boolean(state.file && !state.error && !state.uploading && !assetSubmitting.value)
}

const assetSlotReady = (slot: AssetSlot) => Boolean(assetForm.assets[slot].asset_id || assetForm.assets[slot].file)

const assetId = (set: BackgroundSet, slot: AssetSlot) => String(set.assets?.[slot]?.asset_id || set.assets?.[slot]?.id || '')

const queryContext = () => ({
  game_id: context.game_id,
  ...(context.batch_id ? { batch_id: context.batch_id } : {}),
  ...(context.version ? { version: context.version } : {}),
})

const retryPayload = (dryRun: boolean) => ({
  ...(retryForm.game_id ? { game_id: retryForm.game_id } : {}),
  ...(retryForm.batch_id ? { batch_id: retryForm.batch_id } : {}),
  ...(retryForm.version ? { version: retryForm.version } : {}),
  ...(retryForm.set_types.length ? { set_types: retryForm.set_types } : {}),
  dry_run: dryRun,
  limit: Math.max(1, Math.min(1000, Number(retryForm.limit) || 500)),
})

const applyMix = (response: MixResponse) => {
  mixForm.odd = normalizedPercent(response.mix?.odd)
  mixForm.even = normalizedPercent(response.mix?.even)
  mixForm.charity = normalizedPercent(response.mix?.charity)
}

const validateAssetFile = (slot: AssetSlot, file: File) => {
  const config = slots.find((item) => item.key === slot)
  if (!config) return 'Unknown asset slot.'

  if (!config.allowedTypes.includes(file.type)) {
    return `${config.label} must be ${config.allowedTypes.join(', ')}.`
  }

  if (file.size < 1 || file.size > config.maxSize) {
    return `${config.label} must be between 1 byte and ${formatBytes(config.maxSize)}.`
  }

  return ''
}

const uploadToStorage = async (intent: any, file: File) => {
  if (!intent?.upload_url || intent.production_storage_ready === false || intent.storage_mode === 'local_dev_metadata_only') {
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

const sha256Hex = async (file: File) => {
  if (!import.meta.client || !window.crypto?.subtle) {
    return null
  }

  const hash = await window.crypto.subtle.digest('SHA-256', await file.arrayBuffer())
  return Array.from(new Uint8Array(hash)).map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

const normalizeAsset = (asset: any): BackgroundAsset => ({
  asset_id: asset?.asset_id || asset?.id,
  id: asset?.id || asset?.asset_id,
  storage_path: asset?.storage_path || asset?.storage_key || null,
  storage_key: asset?.storage_key || asset?.storage_path || null,
  content_type: asset?.content_type || null,
  width: asset?.width ?? null,
  height: asset?.height ?? null,
  size_bytes: asset?.size_bytes ?? null,
  storage_available: asset?.storage_available ?? true,
  url: asset?.url || asset?.public_url || null,
  public_url: asset?.public_url || asset?.url || null,
})

const alertType = (err: any) => {
  if ([403, 409, 422].includes(Number(err?.status)) || ['resource_conflict', 'idempotency_conflict', 'validation_failed'].includes(String(err?.code))) {
    return 'warning'
  }

  return 'danger'
}

const errorMessage = (err: any) => {
  if (Number(err?.status) === 403 || err?.code === 'permission_denied') {
    return 'You do not have permission to manage central lottery image operations.'
  }

  if (Number(err?.status) === 409 || err?.code === 'resource_conflict' || err?.code === 'idempotency_conflict') {
    return 'The request conflicts with current data or a previous idempotent write.'
  }

  if (Number(err?.status) === 422 || err?.code === 'validation_failed') {
    return 'The backend rejected the request payload.'
  }

  return err?.message || 'The lottery image operation failed.'
}

const arrayText = (value?: any[] | null) => Array.isArray(value) && value.length ? value.join(', ') : '-'
const yesNo = (value: boolean) => value ? 'Yes' : 'No'
const normalizedPercent = (value: any) => Math.max(0, Math.min(100, Number.isFinite(Number(value)) ? Number(value) : 0))
const slotLabel = (slot: AssetSlot) => slots.find((item) => item.key === slot)?.label || titleize(slot)

const formatBytes = (bytes: number) => {
  if (!bytes) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB']
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  return `${(bytes / (1024 ** index)).toFixed(index === 0 ? 0 : 1)} ${units[index]}`
}

function emptyAssetSlots(): Record<AssetSlot, AssetSlotState> {
  return {
    source: emptyAssetSlot(),
    full: emptyAssetSlot(),
    thumb: emptyAssetSlot(),
  }
}

function emptyAssetSlot(): AssetSlotState {
  return {
    asset_id: '',
    file: null,
    previewUrl: '',
    error: '',
    uploading: false,
    committedAsset: null,
  }
}

onMounted(() => {
  session.setScope('central')
  assetForm.game_id = context.game_id
  assetForm.version = context.version
  retryForm.game_id = context.game_id
  retryForm.version = context.version
  void loadProductionReadiness()
})

onBeforeUnmount(() => {
  for (const slot of slots) {
    const state = assetForm.assets[slot.key]
    if (state.previewUrl && state.file) {
      URL.revokeObjectURL(state.previewUrl)
    }
  }
})
</script>

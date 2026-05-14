<template>
  <div>
    <AdminPageHeader title="Lottery Image Operations" :breadcrumbs="['Admin', 'Central', 'Lottery Images']">
      <template #actions>
        <NuxtLink to="/admin/central/games" class="btn btn-light btn-wave">
          <i class="ri-gamepad-line me-1" />
          Games
        </NuxtLink>
        <button class="btn btn-outline-primary btn-wave" type="button" :disabled="loadingAny" @click="loadAll">
          <span v-if="loadingAny" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="pageError" :type="alertType(pageError)" :message="errorMessage(pageError)" :details="pageError.details" dismissible @dismiss="pageError = null" />
    <AdminAlert v-if="gamesError" :type="alertType(gamesError)" :message="errorMessage(gamesError)" :details="gamesError.details" dismissible @dismiss="gamesError = null" />
    <AdminAlert v-if="successMessage" type="success" :message="successMessage" dismissible @dismiss="successMessage = ''" />
    <AdminAlert v-if="contextError" type="warning" :message="contextError" dismissible @dismiss="contextError = ''" />

    <div class="card custom-card">
      <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-3">
        <div>
          <div class="card-title mb-1">Game Context</div>
          <p class="text-muted mb-0 fs-12">Central scope only. Deep links can preselect a game by query string.</p>
        </div>
        <div class="d-flex flex-wrap gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="gamesLoading || loadingAny" @click="loadGames">
            <span v-if="gamesLoading" class="spinner-border spinner-border-sm me-1" />
            <i v-else class="ri-list-check-2 me-1" />
            Reload games
          </button>
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
            <label class="form-label" for="lottery-images-game-id">Game <span class="text-danger">*</span></label>
            <select id="lottery-images-game-id" v-model="context.game_id" class="form-select" :disabled="gamesLoading">
              <option value="">{{ gamesLoading ? 'Loading games...' : 'Select game' }}</option>
              <option v-if="unknownContextGame" :value="context.game_id">{{ unknownGameLabel(context.game_id) }}</option>
              <option v-for="game in gameOptions" :key="game.id" :value="game.id">{{ game.label }}</option>
            </select>
            <div class="form-text">{{ selectedGameText }}</div>
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
        <AdminAlert v-if="selectedGameWarning" class="mt-3" type="warning" :message="selectedGameWarning" />
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
            <AdminEmptyState v-else-if="!readiness" title="No readiness loaded" message="Select a game and load operations." icon="ri-image-2-line" />
            <template v-else>
              <div class="row g-3 mb-3">
                <div class="col-md-4">
                  <div class="border rounded p-3 h-100">
                    <div class="text-muted fs-12 mb-1">Game</div>
                    <div class="fw-semibold text-break">{{ gameName(readiness.game_id) }}</div>
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
                    <tr v-for="item in readinessBackgrounds" :key="`${item.id || item.set_type}-${item.version}-${item.position || 1}`">
                      <td>
                        <div>{{ titleize(item.set_type || '-') }}</div>
                        <span v-if="item.position" class="text-muted fs-12">Position {{ item.position }}</span>
                      </td>
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
              <p class="text-muted mb-0 fs-12">Generated source/full/thumb rows from the image zip import.</p>
            </div>
            <button class="btn btn-outline-primary btn-wave" type="button" :disabled="assetSetsLoading || !canLoadContext" @click="loadBackgroundSets">
              <span v-if="assetSetsLoading" class="spinner-border spinner-border-sm me-1" />
              <i v-else class="ri-refresh-line me-1" />
              Refresh sets
            </button>
          </div>
          <div class="card-body">
            <AdminLoader v-if="assetSetsLoading" />
            <AdminEmptyState v-else-if="!assetSets.length" title="No background asset sets" message="Import an image zip for odd, even, or charity backgrounds." icon="ri-folder-image-line" />
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
                      <div class="fw-semibold">{{ gameName(set.game_id) }}</div>
                      <code class="np-admin-code">{{ set.game_id }}</code>
                      <div><code class="np-admin-code">{{ set.version }}</code></div>
                    </td>
                    <td>
                      <div>{{ titleize(set.set_type || '-') }}</div>
                      <span v-if="set.position" class="text-muted fs-12">Position {{ set.position }}</span>
                    </td>
                    <td>
                      <div class="d-flex flex-column gap-1">
                        <AdminStatusBadge :status="set.status" />
                        <AdminStatusBadge :status="set.generation_ready ? 'ready' : 'pending_assets'" :label="set.generation_ready ? 'Generation ready' : 'Storage blocked'" />
                      </div>
                    </td>
                    <td>
                      <div class="d-flex flex-column gap-1 small">
                        <span v-for="slot in assetSlots" :key="slot.key">
                          {{ slot.label }}:
                          <code class="np-admin-code">{{ assetId(set, slot.key) || '-' }}</code>
                        </span>
                      </div>
                    </td>
                    <td>{{ formatDateTime(set.updated_at) }}</td>
                    <td>
                      <div class="d-flex flex-wrap justify-content-end gap-1">
                        <button class="btn btn-sm btn-light btn-wave" type="button" @click="fillZipForm(set)">
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
            <div class="card-title">Image Zip Import</div>
          </div>
          <div class="card-body">
            <AdminAlert v-if="zipFormError" :type="alertType(zipFormError)" :message="errorMessage(zipFormError)" :details="zipFormError.details" dismissible @dismiss="zipFormError = null" />
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label" for="zip-game-id">Game</label>
                <select id="zip-game-id" v-model="zipForm.game_id" class="form-select" :disabled="gamesLoading">
                  <option value="">{{ gamesLoading ? 'Loading games...' : 'Select game' }}</option>
                  <option v-if="unknownZipGame" :value="zipForm.game_id">{{ unknownGameLabel(zipForm.game_id) }}</option>
                  <option v-for="game in gameOptions" :key="game.id" :value="game.id">{{ game.label }}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label" for="zip-version">Version</label>
                <input id="zip-version" v-model.trim="zipForm.version" class="form-control" placeholder="v1">
              </div>
              <div class="col-md-6">
                <label class="form-label" for="zip-set-type">Set Type</label>
                <select id="zip-set-type" v-model="zipForm.set_type" class="form-select">
                  <option v-for="setType in setTypes" :key="setType" :value="setType">{{ titleize(setType) }}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label" for="zip-status">Status</label>
                <select id="zip-status" v-model="zipForm.status" class="form-select">
                  <option value="ready">Ready</option>
                  <option value="inactive">Inactive</option>
                  <option value="retired">Retired</option>
                </select>
              </div>
              <div class="col-md-6 d-flex align-items-end">
                <div class="form-check form-switch mb-2">
                  <input id="zip-supersede" v-model="zipForm.supersede_existing" class="form-check-input" type="checkbox">
                  <label class="form-check-label" for="zip-supersede">Supersede existing ready rows</label>
                </div>
              </div>
              <div class="col-12">
                <label class="form-label" for="zip-file">Background Image Zip</label>
                <input
                  :key="zipInputKey"
                  id="zip-file"
                  class="form-control"
                  type="file"
                  accept=".zip,application/zip,application/x-zip-compressed"
                  :disabled="zipImporting"
                  @change="onZipFileChange"
                >
                <div class="form-text">Root-level image files only. Names are sorted automatically and saved as 001.png, 002.jpg, or 003.webp.</div>
              </div>
            </div>

            <AdminAlert v-if="zipForm.error" class="mt-3" type="danger" :message="zipForm.error" />

            <div v-if="zipForm.file" class="border rounded p-3 mt-3">
              <div class="fw-semibold mb-2">Selected zip</div>
              <div class="d-flex flex-column gap-1 small">
                <div class="d-flex justify-content-between gap-2">
                  <span class="text-muted">Name</span>
                  <span class="text-end text-break">{{ zipForm.file.name }}</span>
                </div>
                <div class="d-flex justify-content-between gap-2">
                  <span class="text-muted">Size</span>
                  <span>{{ formatBytes(zipForm.file.size) }}</span>
                </div>
              </div>
              <div v-if="zipForm.progress > 0" class="progress progress-xs mt-3" role="progressbar" :aria-valuenow="zipForm.progress" aria-valuemin="0" aria-valuemax="100">
                <div class="progress-bar" :style="{ width: `${zipForm.progress}%` }" />
              </div>
            </div>

            <div v-if="zipResult" class="border rounded p-3 mt-3">
              <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-2">
                <div class="fw-semibold">Import result</div>
                <AdminStatusBadge status="ready" :label="`${zipResult.meta?.imported_count || 0} imported`" />
              </div>
              <div class="d-flex flex-column gap-1 small">
                <div class="d-flex justify-content-between gap-2">
                  <span class="text-muted">Game</span>
                  <span class="text-end text-break">{{ gameName(zipResult.meta?.game_id) }}</span>
                </div>
                <div class="d-flex justify-content-between gap-2">
                  <span class="text-muted">Set</span>
                  <span>{{ titleize(zipResult.meta?.set_type || '-') }}</span>
                </div>
                <div class="d-flex justify-content-between gap-2">
                  <span class="text-muted">Detected Images</span>
                  <span>{{ zipResult.meta?.expected_count ?? '-' }}</span>
                </div>
              </div>
            </div>
          </div>
          <div class="card-footer d-flex flex-wrap justify-content-end gap-2">
            <button class="btn btn-light btn-wave" type="button" :disabled="zipImporting" @click="resetZipForm">
              Reset form
            </button>
            <button class="btn btn-primary btn-wave" type="button" :disabled="!canImportZip" @click="importZip">
              <span v-if="zipImporting" class="spinner-border spinner-border-sm me-2" />
              Import image zip
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="card custom-card mt-3">
      <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
        <div>
          <div class="card-title mb-1">Manual Number Preview</div>
          <p class="text-muted mb-0 fs-12">Default preview is central unbranded. Partner branding renders only when partner mode is selected.</p>
        </div>
        <AdminStatusBadge :status="previewForm.mode === 'partner_branded' ? 'partner_branded' : 'central_unbranded'" :label="previewForm.mode === 'partner_branded' ? 'Partner branded' : 'Central unbranded'" />
      </div>
      <div class="card-body">
        <AdminAlert v-if="previewError" :type="alertType(previewError)" :message="errorMessage(previewError)" :details="previewError.details" dismissible @dismiss="previewError = null" />
        <AdminAlert v-if="partnersError" type="warning" :message="errorMessage(partnersError)" :details="partnersError.details" dismissible @dismiss="partnersError = null" />
        <AdminAlert v-if="layoutError" :type="alertType(layoutError)" :message="errorMessage(layoutError)" :details="layoutError.details" dismissible @dismiss="layoutError = null" />

        <div class="row g-3">
          <div class="col-md-4 col-xl-3">
            <label class="form-label" for="preview-game-id">Game</label>
            <select id="preview-game-id" v-model="previewForm.game_id" class="form-select" :disabled="gamesLoading">
              <option value="">{{ gamesLoading ? 'Loading games...' : 'Select game' }}</option>
              <option v-if="unknownPreviewGame" :value="previewForm.game_id">{{ unknownGameLabel(previewForm.game_id) }}</option>
              <option v-for="game in gameOptions" :key="game.id" :value="game.id">{{ game.label }}</option>
            </select>
          </div>
          <div class="col-md-4 col-xl-2">
            <label class="form-label" for="preview-version">Version</label>
            <input id="preview-version" v-model.trim="previewForm.version" class="form-control" placeholder="v1">
          </div>
          <div class="col-md-4 col-xl-2">
            <label class="form-label" for="preview-set-type">Set Type</label>
            <select id="preview-set-type" v-model="previewForm.set_type" class="form-select">
              <option v-for="setType in setTypes" :key="setType" :value="setType">{{ titleize(setType) }}</option>
            </select>
          </div>
          <div class="col-md-4 col-xl-2">
            <label class="form-label" for="preview-lottery-number">Lottery Number</label>
            <input id="preview-lottery-number" v-model.trim="previewForm.lottery_number" class="form-control" inputmode="numeric" maxlength="6" placeholder="123456">
          </div>
          <div class="col-md-4 col-xl-3">
            <label class="form-label" for="preview-partner-id">Partner</label>
            <select id="preview-partner-id" v-model="previewForm.partner_id" class="form-select" :disabled="partnersLoading">
              <option value="">{{ partnersLoading ? 'Loading partners...' : 'No partner' }}</option>
              <option v-for="partner in partnerOptions" :key="partner.id" :value="partner.id">{{ partner.label }}</option>
            </select>
            <div class="form-text">Selecting a partner does not brand the image unless partner mode is active.</div>
          </div>
          <div class="col-md-4 col-xl-3">
            <label class="form-label" for="preview-mode">Mode</label>
            <select id="preview-mode" v-model="previewForm.mode" class="form-select">
              <option value="central_unbranded">Central unbranded</option>
              <option value="partner_branded">Partner branded</option>
            </select>
          </div>
          <div class="col-md-4 col-xl-2">
            <label class="form-label" for="preview-variant">Variant</label>
            <select id="preview-variant" v-model="previewForm.variant" class="form-select">
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

        <div class="border rounded mt-3">
          <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 p-3 border-bottom">
            <div>
              <div class="fw-semibold">Composition Layout</div>
              <div class="text-muted fs-12">Global positions used by preview and generated lottery images. Background stays fixed as the base layer.</div>
            </div>
            <div class="d-flex flex-wrap align-items-center gap-2">
              <span class="text-muted fs-12">{{ layoutUpdatedText }}</span>
              <button class="btn btn-light btn-sm btn-wave" type="button" :disabled="layoutLoading || layoutSaving" @click="resetLayoutForm">
                Reset
              </button>
              <button class="btn btn-primary btn-sm btn-wave" type="button" :disabled="!canSaveLayout" @click="saveLayout">
                <span v-if="layoutSaving" class="spinner-border spinner-border-sm me-1" />
                Save layout
              </button>
            </div>
          </div>
          <AdminLoader v-if="layoutLoading" />
          <div v-else class="table-responsive">
            <table class="table table-sm align-middle mb-0">
              <thead>
                <tr>
                  <th style="min-width: 190px;">Element</th>
                  <th v-for="field in layoutFieldOrder" :key="field" class="text-center" style="min-width: 96px;">{{ layoutFieldLabel(field) }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="slotKey in layoutSlotKeys" :key="slotKey">
                  <td>
                    <div class="fw-semibold">{{ layoutSlotLabel(slotKey) }}</div>
                    <code class="np-admin-code">{{ slotKey }}</code>
                  </td>
                  <td v-for="field in layoutFieldOrder" :key="field">
                    <input
                      v-if="slotFields(layoutForm[slotKey]).includes(field)"
                      v-model.number="layoutForm[slotKey][field]"
                      class="form-control form-control-sm"
                      type="number"
                      step="1"
                    >
                    <span v-else class="text-muted d-block text-center">-</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <AdminAlert v-if="previewModeWarning" class="mt-3" type="warning" :message="previewModeWarning" />

        <div v-if="previewResult" class="row g-3 mt-1">
          <div class="col-lg-5">
            <div class="border rounded d-flex align-items-center justify-content-center bg-light overflow-hidden p-2" style="min-height: 260px;">
              <img v-if="previewResult.data_url" :src="previewResult.data_url" alt="Lottery image preview" class="img-fluid" style="max-height: 360px; object-fit: contain;">
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
                <label class="form-label" for="retry-game-id">Game</label>
                <select id="retry-game-id" v-model="retryForm.game_id" class="form-select" :disabled="gamesLoading">
                  <option value="">All games</option>
                  <option v-if="unknownRetryGame" :value="retryForm.game_id">{{ unknownGameLabel(retryForm.game_id) }}</option>
                  <option v-for="game in gameOptions" :key="game.id" :value="game.id">{{ game.label }}</option>
                </select>
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
type PreviewMode = 'central_unbranded' | 'partner_branded'
type PreviewVariant = 'full' | 'thumb'
type LayoutField = 'x' | 'y' | 'width' | 'height' | 'gap' | 'size' | 'angle' | 'rotate'
type LayoutSlot = Partial<Record<LayoutField, number | null>>
type LayoutMap = Record<string, LayoutSlot>

type GameOption = {
  id: string
  code?: string | null
  name: string
  status?: string | null
  label: string
}

type PartnerOption = {
  id: string
  code?: string | null
  name: string
  status?: string | null
  label: string
}

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
  position?: number | null
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

type ZipImportResponse = {
  data?: BackgroundSet[]
  meta?: {
    game_id?: string
    version?: string
    set_type?: SetType
    imported_count?: number
    expected_count?: number
  }
}

type LotteryPreviewResponse = {
  mode?: PreviewMode
  requested_mode?: PreviewMode
  fallback_mode?: PreviewMode | null
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
  layout?: LayoutMap
  data_url?: string
  side_effects?: {
    stock_rows_created?: number
    permanent_image_rows_created?: number
    branding_locked?: boolean
  }
}

type LayoutResponse = {
  key: string
  scope: string
  layout: LayoutMap
  default_layout?: LayoutMap
  updated_at?: string | null
  updated_by?: string | null
}

const route = useRoute()
const api = useAdminApi()
const session = useAdminSession()

const zipUploadMaxBytes = 500 * 1024 * 1024
const zipUploadMaxLabel = '500 MB'
const setTypes: SetType[] = ['odd', 'even', 'charity']
const assetSlots: Array<{ key: AssetSlot, label: string }> = [
  { key: 'source', label: 'Source Image' },
  { key: 'full', label: 'Full WebP' },
  { key: 'thumb', label: 'Thumb WebP' },
]
const layoutFieldOrder: LayoutField[] = ['x', 'y', 'width', 'height', 'gap', 'size', 'angle', 'rotate']
const layoutSlotLabels: Record<string, string> = {
  beside: 'Beside Strip',
  emoji_1: 'Emoji 1',
  emoji_2: 'Emoji 2',
  emoji_3: 'Emoji 3',
  emoji_4: 'Emoji 4',
  number_digits: 'Number Digits',
  text_eng: 'English Text Digits',
  thai_text: 'Thai Text',
  num_set_center_left: 'Num Set Center Left',
  num_set_center_right: 'Num Set Center Right',
  num_set_right_left: 'Num Set Right Left',
  num_set_right_right: 'Num Set Right Right',
  num_set_bottom_left: 'Num Set Bottom Left',
  num_set_bottom_right: 'Num Set Bottom Right',
  logo_bottom: 'Logo Bottom',
  logo_qr: 'Logo QR',
  right_sidebar: 'Right Sidebar',
}

const context = reactive({
  game_id: '',
  batch_id: '',
  version: 'v1',
})

const games = ref<GameOption[]>([])
const gamesLoading = ref(false)
const gamesLoaded = ref(false)
const gamesError = ref<any>(null)
const partners = ref<PartnerOption[]>([])
const partnersLoading = ref(false)
const partnersError = ref<any>(null)

const pageError = ref<any>(null)
const contextError = ref('')
const successMessage = ref('')
const readinessLoading = ref(false)
const assetSetsLoading = ref(false)
const productionLoading = ref(false)
const mixLoading = ref(false)
const layoutLoading = ref(false)
const readiness = ref<ReadinessResponse | null>(null)
const assetSets = ref<BackgroundSet[]>([])
const productionReadiness = ref<ProductionReadiness | null>(null)
const mix = ref<MixResponse | null>(null)
const layout = ref<LayoutResponse | null>(null)
const layoutForm = reactive<LayoutMap>({})
const layoutError = ref<any>(null)
const layoutSaving = ref(false)

const zipForm = reactive({
  game_id: '',
  version: 'v1',
  set_type: 'odd' as SetType,
  status: 'ready' as BackgroundStatus,
  supersede_existing: true,
  file: null as File | null,
  error: '',
  progress: 0,
})
const zipFormError = ref<any>(null)
const zipImporting = ref(false)
const zipResult = ref<ZipImportResponse | null>(null)
const zipInputKey = ref(0)

const previewForm = reactive({
  game_id: '',
  version: 'v1',
  set_type: 'odd' as SetType,
  lottery_number: '123456',
  partner_id: '',
  mode: 'central_unbranded' as PreviewMode,
  variant: 'full' as PreviewVariant,
})
const previewLoading = ref(false)
const previewError = ref<any>(null)
const previewResult = ref<LotteryPreviewResponse | null>(null)

const mixForm = reactive<Record<SetType, number>>({
  odd: 45,
  even: 45,
  charity: 10,
})
const mixError = ref<any>(null)
const mixSubmitting = ref(false)

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

const gameOptions = computed(() => games.value)
const partnerOptions = computed(() => partners.value)
const selectedGame = computed(() => gameById(context.game_id))
const unknownContextGame = computed(() => isUnknownGame(context.game_id))
const unknownZipGame = computed(() => isUnknownGame(zipForm.game_id))
const unknownPreviewGame = computed(() => isUnknownGame(previewForm.game_id))
const unknownRetryGame = computed(() => isUnknownGame(retryForm.game_id))
const selectedGameText = computed(() => selectedGame.value ? `${selectedGame.value.name} (${selectedGame.value.status || 'unknown'})` : 'Select a central game to load readiness, import backgrounds, and preview images.')
const selectedGameWarning = computed(() => {
  if (!context.game_id || gamesLoading.value || !gamesLoaded.value) return ''
  if (!selectedGame.value) return `Game ${context.game_id} was not returned by the central games API. It may be missing or archived; existing filters can still be loaded by ID.`
  if (selectedGame.value.status === 'archived') return `${selectedGame.value.name} is archived. Review before importing or retrying assets.`
  return ''
})

const canLoadContext = computed(() => context.game_id.trim() !== '')
const loadingAny = computed(() => readinessLoading.value || assetSetsLoading.value || productionLoading.value || mixLoading.value || layoutLoading.value || gamesLoading.value)
const missingSetTypes = computed(() => readiness.value?.missing_set_types || [])
const readinessBackgrounds = computed(() => readiness.value?.backgrounds || [])
const lastErrors = computed(() => readiness.value?.last_error_samples || [])
const blockingReasons = computed(() => productionReadiness.value?.blocking_reasons || [])
const mixTotal = computed(() => setTypes.reduce((sum, key) => sum + normalizedPercent(mixForm[key]), 0))
const canSaveMix = computed(() => Boolean(canLoadContext.value && mixTotal.value === 100 && !mixSubmitting.value && !mixLoading.value))
const canImportZip = computed(() => Boolean(
  zipForm.game_id.trim()
  && zipForm.version.trim()
  && zipForm.set_type
  && zipForm.file
  && !zipForm.error
  && !zipImporting.value,
))
const canPreview = computed(() => Boolean(
  previewForm.game_id.trim()
  && previewForm.version.trim()
  && previewForm.set_type
  && /^[0-9]{1,6}$/.test(previewForm.lottery_number)
  && (previewForm.mode !== 'partner_branded' || previewForm.partner_id)
  && !previewLoading.value,
))
const previewModeWarning = computed(() => {
  if (previewForm.mode === 'central_unbranded' && previewForm.partner_id) {
    return 'A partner is selected, but the preview will remain central unbranded until partner branded mode is selected.'
  }
  if (previewForm.mode === 'partner_branded' && !previewForm.partner_id) {
    return 'Select a partner before rendering partner branded preview.'
  }
  return ''
})
const previewWarnings = computed(() => previewResult.value?.warnings || [])
const previewDetails = computed(() => {
  const result = previewResult.value
  if (!result) return []

  return [
    { key: 'game', label: 'Game', value: `${gameName(result.game_id)} (${result.game_id || '-'})` },
    { key: 'number', label: 'Lottery number', value: result.lottery_number || '-' },
    { key: 'set', label: 'Set / version', value: `${titleize(result.set_type || '-')} / ${result.version || '-'}` },
    { key: 'partner', label: 'Partner', value: result.partner_id ? partnerName(result.partner_id) : 'Central unbranded' },
    { key: 'variant', label: 'Variant', value: titleize(result.variant || '-') },
    { key: 'size', label: 'Image size', value: result.width && result.height ? `${result.width} x ${result.height}` : '-' },
  ]
})
const layoutSlotKeys = computed(() => Object.keys(layoutForm))
const layoutUpdatedText = computed(() => layout.value?.updated_at ? formatDateTime(layout.value.updated_at) : 'Default layout')
const canSaveLayout = computed(() => Boolean(!layoutSaving.value && !layoutLoading.value && layoutSlotKeys.value.length))

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

watch(() => context.game_id, (value, oldValue) => {
  syncGameToForms(value, oldValue)
})

watch(() => context.version, (value, oldValue) => {
  syncVersionToForms(value || 'v1', oldValue)
})

watch(() => route.query.game_id, (value) => {
  const next = normalizeQueryValue(value)
  if (!next || next === context.game_id) return
  context.game_id = next
  void loadAll()
})

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

const loadPartners = async () => {
  partnersLoading.value = true
  partnersError.value = null

  try {
    const response = await api.apiFetch('/admin/central/partners', {
      scope: 'central',
      query: { limit: 100 },
    })
    partners.value = extractItems(response).map(normalizePartner).filter((partner) => partner.id)
  } catch (err) {
    partnersError.value = err
    partners.value = []
  } finally {
    partnersLoading.value = false
  }
}

const loadAll = async () => {
  contextError.value = ''

  if (!canLoadContext.value) {
    contextError.value = 'Game selection is required before loading lottery image operations.'
    return
  }

  await Promise.all([
    loadReadiness(),
    loadBackgroundSets(),
    loadMix(),
    loadProductionReadiness(),
    loadLayout(),
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

const loadLayout = async () => {
  layoutLoading.value = true
  layoutError.value = null

  try {
    const response = await api.apiFetch<LayoutResponse>('/admin/central/lottery-images/layout', {
      scope: 'central',
    })
    layout.value = response
    applyLayout(response.layout || response.default_layout || {})
  } catch (err) {
    layoutError.value = err
  } finally {
    layoutLoading.value = false
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

const importZip = async () => {
  if (!canImportZip.value || !zipForm.file) return

  zipImporting.value = true
  zipFormError.value = null
  successMessage.value = ''
  zipResult.value = null
  zipForm.progress = 15

  try {
    const body = new FormData()
    body.append('game_id', zipForm.game_id)
    body.append('version', zipForm.version || 'v1')
    body.append('set_type', zipForm.set_type)
    body.append('status', zipForm.status)
    body.append('supersede_existing', zipForm.supersede_existing ? '1' : '0')
    body.append('zip', zipForm.file)

    zipForm.progress = 45
    const response = await api.apiFetch<ZipImportResponse>('/admin/central/lottery-images/background-asset-sets/import-zip', {
      method: 'POST',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body,
    })

    zipForm.progress = 100
    zipResult.value = response
    context.game_id = response.meta?.game_id || zipForm.game_id
    context.version = response.meta?.version || zipForm.version || context.version
    successMessage.value = `${response.meta?.imported_count || response.data?.length || 0} background rows imported from image zip.`
    zipForm.file = null
    zipInputKey.value += 1
    await Promise.all([loadBackgroundSets(), loadReadiness()])
  } catch (err) {
    zipForm.progress = 0
    zipFormError.value = err
  } finally {
    zipImporting.value = false
  }
}

const renderPreview = async () => {
  if (!canPreview.value) return

  previewLoading.value = true
  previewError.value = null
  previewResult.value = null

  try {
    previewResult.value = await api.apiFetch<LotteryPreviewResponse>('/admin/central/lottery-images/preview', {
      method: 'POST',
      scope: 'central',
      body: {
        game_id: previewForm.game_id,
        version: previewForm.version || 'v1',
        set_type: previewForm.set_type,
        lottery_number: previewForm.lottery_number,
        mode: previewForm.mode,
        variant: previewForm.variant,
        layout: serializeLayoutForm(),
        ...(previewForm.partner_id ? { partner_id: previewForm.partner_id } : {}),
      },
    })
  } catch (err) {
    previewError.value = err
  } finally {
    previewLoading.value = false
  }
}

const saveLayout = async () => {
  if (!canSaveLayout.value) return

  layoutSaving.value = true
  layoutError.value = null
  successMessage.value = ''

  try {
    const response = await api.apiFetch<LayoutResponse>('/admin/central/lottery-images/layout', {
      method: 'PUT',
      scope: 'central',
      idempotencyKey: api.idempotencyKey(),
      body: {
        layout: serializeLayoutForm(),
      },
    })
    layout.value = response
    applyLayout(response.layout || {})
    successMessage.value = 'Lottery image layout saved.'
  } catch (err) {
    layoutError.value = err
  } finally {
    layoutSaving.value = false
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

const onZipFileChange = (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] || null
  zipForm.file = file
  zipForm.error = ''
  zipForm.progress = file ? 5 : 0
  zipResult.value = null

  if (!file) return

  zipForm.error = validateZipFile(file)
  if (zipForm.error) {
    input.value = ''
  }
}

const fillZipForm = (set: BackgroundSet) => {
  context.game_id = set.game_id
  context.version = set.version
  zipForm.game_id = set.game_id
  zipForm.version = set.version
  zipForm.set_type = set.set_type
  zipForm.status = set.status || 'ready'
  zipForm.supersede_existing = false
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
  previewResult.value = null
}

const resetZipForm = () => {
  zipForm.game_id = context.game_id
  zipForm.version = context.version || 'v1'
  zipForm.set_type = 'odd'
  zipForm.status = 'ready'
  zipForm.supersede_existing = true
  zipForm.file = null
  zipForm.error = ''
  zipForm.progress = 0
  zipResult.value = null
  zipInputKey.value += 1
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

const resetLayoutForm = () => {
  applyLayout(layout.value?.default_layout || layout.value?.layout || {})
}

const syncGameToForms = (value: string, oldValue?: string) => {
  if (!zipForm.game_id || zipForm.game_id === oldValue) zipForm.game_id = value
  if (!previewForm.game_id || previewForm.game_id === oldValue) previewForm.game_id = value
  if (!retryForm.game_id || retryForm.game_id === oldValue) retryForm.game_id = value
}

const syncVersionToForms = (value: string, oldValue?: string) => {
  if (!zipForm.version || zipForm.version === oldValue || zipForm.version === 'v1') zipForm.version = value
  if (!previewForm.version || previewForm.version === oldValue || previewForm.version === 'v1') previewForm.version = value
  if (!retryForm.version || retryForm.version === oldValue) retryForm.version = value
}

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

const applyLayout = (next: LayoutMap) => {
  Object.keys(layoutForm).forEach((key) => delete layoutForm[key])

  Object.entries(next || {}).forEach(([slotKey, slot]) => {
    layoutForm[slotKey] = {}
    layoutFieldOrder.forEach((field) => {
      if (Object.prototype.hasOwnProperty.call(slot, field)) {
        layoutForm[slotKey][field] = slot[field] ?? null
      }
    })
  })
}

const serializeLayoutForm = (): LayoutMap => {
  const output: LayoutMap = {}

  Object.entries(layoutForm).forEach(([slotKey, slot]) => {
    output[slotKey] = {}
    layoutFieldOrder.forEach((field) => {
      if (!Object.prototype.hasOwnProperty.call(slot, field)) return
      const value = slot[field]
      output[slotKey][field] = value === null || value === undefined || String(value) === '' ? null : Number(value)
    })
  })

  return output
}

const slotFields = (slot: LayoutSlot): LayoutField[] => layoutFieldOrder.filter((field) => Object.prototype.hasOwnProperty.call(slot, field))
const layoutSlotLabel = (slotKey: string) => layoutSlotLabels[slotKey] || titleize(slotKey)
const layoutFieldLabel = (field: LayoutField) => field === 'width' ? 'W' : field === 'height' ? 'H' : titleize(field)

const validateZipFile = (file: File) => {
  const name = file.name.toLowerCase()
  const acceptedTypes = ['', 'application/zip', 'application/x-zip-compressed', 'multipart/x-zip']

  if (!name.endsWith('.zip') || !acceptedTypes.includes(file.type || '')) {
    return 'Upload must be a .zip file containing image files only.'
  }

  if (file.size < 1 || file.size > zipUploadMaxBytes) {
    return `Zip size must be between 1 byte and ${zipUploadMaxLabel}.`
  }

  return ''
}

const isUnknownGame = (gameId: string) => Boolean(gameId && gamesLoaded.value && !gameById(gameId))
const gameById = (gameId?: string | null) => games.value.find((game) => game.id === gameId) || null
const partnerById = (partnerId?: string | null) => partners.value.find((partner) => partner.id === partnerId) || null
const gameName = (gameId?: string | null) => gameById(gameId)?.name || gameId || '-'
const partnerName = (partnerId?: string | null) => {
  const partner = partnerById(partnerId)
  return partner ? `${partner.name} (${partner.id})` : partnerId || '-'
}
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

const normalizePartner = (partner: any): PartnerOption => {
  const id = String(partner?.id || partner?.partner_id || partner?.uuid || partner?.code || '')
  const name = String(partner?.name || partner?.display_name || partner?.code || id)
  const code = partner?.code && partner.code !== name ? ` (${partner.code})` : ''
  const status = partner?.status || null
  return {
    id,
    name,
    code: partner?.code || null,
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

const normalizeQueryValue = (value: any) => Array.isArray(value) ? String(value[0] || '') : String(value || '')

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
    return err?.message || 'The backend rejected the request payload.'
  }

  return err?.message || 'The lottery image operation failed.'
}

const arrayText = (value?: any[] | null) => Array.isArray(value) && value.length ? value.join(', ') : '-'
const yesNo = (value: boolean) => value ? 'Yes' : 'No'
const normalizedPercent = (value: any) => Math.max(0, Math.min(100, Number.isFinite(Number(value)) ? Number(value) : 0))

const formatBytes = (bytes: number) => {
  if (!bytes) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB']
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  return `${(bytes / (1024 ** index)).toFixed(index === 0 ? 0 : 1)} ${units[index]}`
}

onMounted(async () => {
  session.setScope('central')
  const initialGameId = normalizeQueryValue(route.query.game_id)
  if (initialGameId) {
    context.game_id = initialGameId
    syncGameToForms(initialGameId)
  }
  zipForm.version = context.version
  previewForm.version = context.version
  retryForm.version = context.version

  await Promise.all([loadGames(), loadPartners(), loadLayout()])

  if (initialGameId) {
    await loadAll()
  } else {
    await loadProductionReadiness()
  }
})
</script>

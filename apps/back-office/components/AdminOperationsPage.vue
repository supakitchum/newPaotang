<template>
  <div>
    <AdminOperationHeader
      v-if="resource"
      :scope="scope"
      :group="resource.group"
      :title="pageTitle"
    >
      <template #actions>
        <NuxtLink v-if="mode === 'detail'" :to="listPath" class="btn btn-light btn-wave">
          <i class="ri-arrow-left-line me-1" />
          Back
        </NuxtLink>
        <button v-if="canReload" class="btn btn-outline-primary btn-wave" type="button" :disabled="loading" @click="load()">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminOperationHeader>

    <AdminPageHeader v-else title="Page not found" :breadcrumbs="['Admin', scopeLabel, 'Not found']" />

    <AdminApiState v-if="!resource" message="This back-office route is not registered in the operations catalog." />
    <AdminApiState v-else-if="resource.apiGap" :message="resource.apiGap" />

    <template v-else-if="mode === 'report-index'">
      <div class="row">
        <div v-for="key in resource.reportKeys || []" :key="key" class="col-sm-6 col-xl-3">
          <NuxtLink class="card custom-card np-admin-link-card" :to="`${scopeBasePath}/reports/${key}`">
            <div class="card-body">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <p class="text-muted mb-1">Report</p>
                  <h6 class="mb-0">{{ titleize(key) }}</h6>
                </div>
                <i class="ri-bar-chart-box-line fs-24 text-primary" />
              </div>
            </div>
          </NuxtLink>
        </div>
      </div>
    </template>

    <template v-else-if="mode === 'settings'">
      <AdminApiState :error="error" />
      <AdminMenuTreeEditor
        v-if="isMenuManagement"
        :scope="scope"
        :model-value="detail"
        :loading="loading"
        :saving="saving"
        :error="error"
        @save="saveMenuTree"
      />
      <AdminStockCoverageSettings
        v-else-if="isStockSettingsRoute"
        @saved="handleStockCoverageSettingsSaved"
      />
      <div v-else-if="hasSettingsForm" class="card custom-card">
        <div class="card-header">
          <div class="card-title">Configuration</div>
        </div>
        <div class="card-body">
          <AdminLoader v-if="loading" />
          <div v-else class="row g-3">
            <div v-for="field in resource.settingsFields || []" :key="field.key" :class="field.type === 'textarea' || field.type === 'json' || field.type === 'lines' ? 'col-12' : 'col-md-6'">
              <div v-if="field.type === 'checkbox'" class="form-check form-switch mt-4">
                <input :id="fieldId(`settings-${field.key}`)" v-model="settingsForm[field.key]" class="form-check-input" type="checkbox">
                <label class="form-check-label" :for="fieldId(`settings-${field.key}`)">{{ field.label }}</label>
                <div v-if="field.help" class="form-text">{{ field.help }}</div>
              </div>
              <template v-else>
                <label class="form-label" :for="fieldId(`settings-${field.key}`)">{{ field.label }}</label>
                <select v-if="field.type === 'select'" :id="fieldId(`settings-${field.key}`)" v-model="settingsForm[field.key]" class="form-select">
                  <option value="">Select</option>
                  <option v-for="option in field.options || []" :key="optionValue(option)" :value="optionValue(option)">{{ optionLabel(option) }}</option>
                </select>
                <div v-else-if="field.type === 'stock-set-distribution'" class="border rounded p-3">
                  <div class="d-grid gap-2">
                    <div class="d-none d-md-grid text-muted fw-semibold fs-12" style="grid-template-columns: minmax(7rem, 10rem) minmax(9rem, 14rem) 2.5rem; gap: .75rem;">
                      <span>Set size</span>
                      <span>Percent</span>
                      <span />
                    </div>
                    <div
                      v-for="(row, index) in settingsForm[field.key] || []"
                      :key="row.__key || index"
                      class="d-grid align-items-center"
                      style="grid-template-columns: minmax(7rem, 10rem) minmax(9rem, 14rem) 2.5rem; gap: .75rem;"
                    >
                      <input
                        v-model.number="row.set_size"
                        class="form-control"
                        type="number"
                        min="1"
                        max="99"
                        step="1"
                        placeholder="2"
                      >
                      <div class="input-group">
                        <input
                          v-model.number="row.percent"
                          class="form-control"
                          type="number"
                          min="0"
                          max="100"
                          step="0.01"
                          placeholder="10"
                        >
                        <span class="input-group-text">%</span>
                      </div>
                      <button class="btn btn-light btn-icon" type="button" title="Remove set" @click="removeStockSetDistributionRow(field, index)">
                        <i class="ri-delete-bin-line" />
                      </button>
                    </div>
                  </div>
                  <button class="btn btn-outline-primary btn-sm btn-wave mt-3" type="button" @click="addStockSetDistributionRow(field)">
                    <i class="ri-add-line me-1" /> Add set
                  </button>
                </div>
                <textarea
                  v-else-if="field.type === 'textarea' || field.type === 'json' || field.type === 'lines'"
                  :id="fieldId(`settings-${field.key}`)"
                  v-model="settingsForm[field.key]"
                  class="form-control"
                  rows="4"
                  :placeholder="field.placeholder"
                />
                <input
                  v-else
                  :id="fieldId(`settings-${field.key}`)"
                  v-model="settingsForm[field.key]"
                  class="form-control"
                  :type="inputType(field)"
                  :min="field.min"
                  :step="field.step"
                  :placeholder="field.placeholder"
                >
                <div v-if="field.help" class="form-text">{{ field.help }}</div>
              </template>
            </div>
          </div>
        </div>
        <div class="card-footer d-flex justify-content-end gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="loading" @click="resetSettingsForm">Reset</button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="saving" @click="saveSettingsForm">
            <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
            Save
          </button>
        </div>
      </div>
      <div v-else class="card custom-card">
        <div class="card-header">
          <div class="card-title">Configuration JSON</div>
        </div>
        <div class="card-body">
          <AdminLoader v-if="loading" />
          <textarea v-else v-model="settingsDraft" class="form-control np-admin-json-editor" spellcheck="false" />
        </div>
        <div class="card-footer d-flex justify-content-end gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="loading" @click="resetSettings">Reset</button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="saving" @click="saveSettings">
            <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
            Save
          </button>
        </div>
      </div>

      <div
        v-for="panel in resource.secondarySettings || []"
        :key="panel.key"
        class="card custom-card"
      >
        <div class="card-header">
          <div class="card-title">{{ panel.title }}</div>
        </div>
        <div class="card-body">
          <AdminApiState :error="secondaryErrors[panel.key]" />
          <AdminLoader v-if="secondaryLoading[panel.key]" />
          <div v-else-if="secondaryForms[panel.key]" class="row g-3">
            <div v-for="field in panel.settingsFields || []" :key="field.key" :class="field.type === 'textarea' || field.type === 'json' || field.type === 'lines' ? 'col-12' : 'col-md-6'">
              <div v-if="field.type === 'checkbox'" class="form-check form-switch mt-4">
                <input :id="fieldId(`secondary-${panel.key}-${field.key}`)" v-model="secondaryForms[panel.key][field.key]" class="form-check-input" type="checkbox">
                <label class="form-check-label" :for="fieldId(`secondary-${panel.key}-${field.key}`)">{{ field.label }}</label>
                <div v-if="field.help" class="form-text">{{ field.help }}</div>
              </div>
              <template v-else>
                <label class="form-label" :for="fieldId(`secondary-${panel.key}-${field.key}`)">{{ field.label }}</label>
                <select v-if="field.type === 'select'" :id="fieldId(`secondary-${panel.key}-${field.key}`)" v-model="secondaryForms[panel.key][field.key]" class="form-select">
                  <option value="">Select</option>
                  <option v-for="option in field.options || []" :key="optionValue(option)" :value="optionValue(option)">{{ optionLabel(option) }}</option>
                </select>
                <textarea
                  v-else-if="field.type === 'textarea' || field.type === 'json' || field.type === 'lines'"
                  :id="fieldId(`secondary-${panel.key}-${field.key}`)"
                  v-model="secondaryForms[panel.key][field.key]"
                  class="form-control"
                  rows="4"
                  :placeholder="field.placeholder"
                />
                <input
                  v-else
                  :id="fieldId(`secondary-${panel.key}-${field.key}`)"
                  v-model="secondaryForms[panel.key][field.key]"
                  class="form-control"
                  :type="inputType(field)"
                  :min="field.min"
                  :step="field.step"
                  :placeholder="field.placeholder"
                >
                <div v-if="field.help" class="form-text">{{ field.help }}</div>
              </template>
            </div>
          </div>
        </div>
        <div class="card-footer d-flex justify-content-end gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="secondaryLoading[panel.key] || secondarySaving[panel.key]" @click="resetSecondarySettingsForm(panel)">Reset</button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="secondarySaving[panel.key]" @click="saveSecondarySettingsForm(panel)">
            <span v-if="secondarySaving[panel.key]" class="spinner-border spinner-border-sm me-2" />
            Save
          </button>
        </div>
      </div>
    </template>

    <template v-else-if="mode === 'report-detail'">
      <AdminFilterBar :filters="hydratedReportFilters" :model-value="filters" @apply="applyFilters" />
      <AdminExportPanel :actions="hydratedCollectionActions" @run="openCollectionAction" />
      <AdminApiState :error="error" />
      <AdminReportPanel :data="detail" :loading="loading" />
    </template>

    <template v-else-if="isStockPatternCoverageRoute">
      <AdminStockPatternCoverage />
    </template>

    <template v-else-if="mode === 'summary'">
      <AdminFilterBar v-if="resource.filters?.length" :filters="hydratedFilters" :model-value="filters" @apply="applyFilters" />
      <AdminApiState :error="error" />
      <AdminDetailSection :title="resource.title" :record="detail" :loading="loading" />
    </template>

    <template v-else-if="mode === 'detail'">
      <AdminApiState v-if="detailGap" :message="detailGap" />
      <AdminApiState :error="error" />
      <AdminTenantStockDetail
        v-if="isTenantStockRoute"
        :record="detailDisplayRecord"
        :loading="loading && !detailGap"
      />
      <AdminPriceRuleDetail
        v-else-if="resource.detailRenderer === 'price-rule'"
        :record="detailDisplayRecord"
        :loading="loading && !detailGap"
      />
      <AdminPartnerDetail
        v-else-if="resource.detailRenderer === 'partner'"
        :record="detailDisplayRecord"
        :loading="loading && !detailGap"
        @saved="handlePartnerDetailSaved"
      />
      <AdminCustomerDetail
        v-else-if="resource.detailRenderer === 'customer'"
        :record="detailDisplayRecord"
        :loading="loading && !detailGap"
      />
      <AdminWalletDetail
        v-else-if="resource.detailRenderer === 'wallet'"
        :record="detailDisplayRecord"
        :loading="loading && !detailGap"
      />
      <AdminOrderDetail
        v-else-if="resource.detailRenderer === 'order'"
        :record="detailDisplayRecord"
        :loading="loading && !detailGap"
      />
      <AdminTopupDetail
        v-else-if="resource.detailRenderer === 'topup'"
        :record="detailDisplayRecord"
        :loading="loading && !detailGap"
      />
      <AdminDetailSection
        v-else
        :title="`${resource.title} detail`"
        :record="detailSectionRecord"
        :fields="resource.detailFields || []"
        :loading="loading && !detailGap"
      />
      <AdminRewardPrizes
        v-if="resource.detailRenderer === 'reward' && !detailGap && detail"
        :prizes="detail?.prizes || []"
      />
      <div v-if="resource.detailJsonEditor && resource.updateEndpoint && !detailGap" class="card custom-card">
        <div class="card-header">
          <div class="card-title">Update JSON</div>
        </div>
        <div class="card-body">
          <AdminLoader v-if="loading" />
          <textarea v-else v-model="detailDraft" class="form-control np-admin-json-editor" spellcheck="false" />
        </div>
        <div class="card-footer d-flex justify-content-end gap-2">
          <button class="btn btn-light btn-wave" type="button" :disabled="loading || saving" @click="resetDetailDraft">Reset</button>
          <button class="btn btn-primary btn-wave" type="button" :disabled="loading || saving" @click="saveDetailDraft">
            <span v-if="saving" class="spinner-border spinner-border-sm me-2" />
            Save
          </button>
        </div>
      </div>
      <AdminExportPanel :actions="detailActions" @run="openDetailAction" />
    </template>

    <template v-else>
      <AdminFilterBar v-if="!showListSections && resource.filters?.length" :filters="hydratedFilters" :model-value="filters" @apply="applyFilters" />
      <AdminApiState v-if="stockGenerateCurrentGameMessage" :message="stockGenerateCurrentGameMessage" />
      <AdminStockSummaryWidgets
        v-if="showStockSummaryWidgets"
        :endpoint="stockSummaryEndpoint"
        :game-id="stockSummaryGameId"
        :batch-id="stockSummaryBatchId"
        :refresh-key="stockSummaryRefreshKey"
      />
      <div v-if="showAllocationSummaryWidgets" class="row g-3 mb-3">
        <div v-for="card in allocationSummaryCards" :key="card.key" class="col-12 col-md-4">
          <div class="card custom-card np-allocation-summary-card">
            <div class="card-body">
              <div class="d-flex align-items-start justify-content-between gap-3">
                <div>
                  <p class="text-muted mb-1">{{ card.label }}</p>
                  <h4 class="mb-1">{{ card.value }}</h4>
                  <span class="text-muted fs-12">{{ card.hint }}</span>
                </div>
                <span :class="['avatar', card.colorClass]">
                  <i :class="[card.icon, 'fs-4']" />
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
      <AdminStockGenerationBatches
        v-if="showStockGenerationProgress"
        :game-id="stockSummaryGameId"
        :submitted-batch="stockGenerationSubmittedBatch"
        :refresh-key="stockGenerationProgressRefreshKey"
        @active-change="handleStockGenerationActiveChange"
        @progress="handleStockGenerationProgress"
      />
      <AdminExportPanel :actions="hydratedCollectionActions" @run="openCollectionAction" />
      <AdminApiState :error="error" />
      <AdminDataTable
        v-if="!showListSections"
        :title="resource.title"
        :columns="tableColumns"
        :rows="tableRows"
        :loading="loading"
        :sort-key="sortState.key"
        :sort-direction="sortState.direction"
        :sortable="Boolean(resource.apiSort || resource.clientSort)"
        :empty-title="`No ${resource.title.toLowerCase()}`"
        empty-message="No records were returned from the approved back-office API."
        @sort-change="applySort"
      >
        <template #beforeTable>
          <div v-if="showStockTableRealtimePanel" class="np-stock-realtime-panel border rounded p-3 mb-3">
            <div class="d-flex flex-column flex-xl-row align-items-xl-center justify-content-between gap-3">
              <div class="d-flex align-items-start gap-3">
                <span class="avatar bg-info-transparent text-info">
                  <i class="ri-broadcast-line fs-4" />
                </span>
                <div>
                  <div class="d-flex flex-wrap align-items-center gap-2 mb-1">
                    <h6 class="mb-0">Stock table realtime</h6>
                    <span :class="['badge', stockTableRealtimeStatusBadgeClass]">{{ stockTableRealtimeStatusLabel }}</span>
                  </div>
                  <p class="text-muted mb-0">{{ stockTableRealtimePanelMessage }}</p>
                </div>
              </div>
              <div class="d-flex flex-wrap align-items-center gap-2">
                <span v-if="selectedStockTableGameId" class="badge bg-light text-default">Game {{ selectedStockTableGameId }}</span>
                <span v-if="stockTableRealtimeLastEventLabel" class="badge bg-success-transparent text-success">{{ stockTableRealtimeLastEventLabel }}</span>
              </div>
            </div>
            <div v-if="!selectedStockTableGameId" class="alert alert-info d-flex align-items-start gap-2 mt-3 mb-0">
              <i class="ri-information-line fs-18" />
              <div>Select a game to show stock summary widgets and enable live table updates.</div>
            </div>
            <div v-else-if="stockTableRealtimeError" class="alert alert-warning d-flex align-items-start gap-2 mt-3 mb-0">
              <i class="ri-alert-line fs-18" />
              <div>{{ stockTableRealtimeError }}</div>
            </div>
          </div>
          <div v-if="showTenantStockRealtimePanel" class="np-stock-realtime-panel border rounded p-3 mb-3">
            <div class="d-flex flex-column flex-xl-row align-items-xl-center justify-content-between gap-3">
              <div class="d-flex align-items-start gap-3">
                <span class="avatar bg-info-transparent text-info">
                  <i class="ri-broadcast-line fs-4" />
                </span>
                <div>
                  <div class="d-flex flex-wrap align-items-center gap-2 mb-1">
                    <h6 class="mb-0">Tenant stock realtime</h6>
                    <span :class="['badge', tenantStockRealtimeStatusBadgeClass]">{{ tenantStockRealtimeStatusLabel }}</span>
                  </div>
                  <p class="text-muted mb-0">{{ tenantStockRealtimePanelMessage }}</p>
                </div>
              </div>
              <div class="d-flex flex-wrap align-items-center gap-2">
                <span v-if="selectedTenantStockGameId" class="badge bg-light text-default">Game {{ selectedTenantStockGameId }}</span>
                <span v-if="tenantStockRealtimeLastEventLabel" class="badge bg-success-transparent text-success">{{ tenantStockRealtimeLastEventLabel }}</span>
              </div>
            </div>
            <div v-if="!selectedTenantStockGameId" class="alert alert-info d-flex align-items-start gap-2 mt-3 mb-0">
              <i class="ri-information-line fs-18" />
              <div>Select a game to enable live tenant stock updates.</div>
            </div>
            <div v-else-if="tenantStockRealtimeError" class="alert alert-warning d-flex align-items-start gap-2 mt-3 mb-0">
              <i class="ri-alert-line fs-18" />
              <div>{{ tenantStockRealtimeError }}</div>
            </div>
          </div>
        </template>
        <template v-for="column in tableColumns" #[`cell-${column.key}`]="{ row }">
          <AdminStatusBadge v-if="column.type === 'status'" :status="row[column.key]" />
          <AdminImagePreview v-else-if="column.type === 'image'" :image="row[column.key]" :label="column.label" />
          <span v-else>{{ formattedCellValue(row, column) }}</span>
        </template>
        <template #rowActions="{ row }">
          <div class="d-flex justify-content-end gap-1">
            <NuxtLink
              v-if="hasDetailRoute"
              v-show="!isStockGrouped"
              :to="`${scopeBasePath}/${resource.slug}/${row.__id}`"
              class="btn btn-sm btn-primary btn-wave"
            >
              Detail
            </NuxtLink>
            <button
              v-if="isStockGrouped"
              type="button"
              class="btn btn-sm btn-primary btn-wave"
              @click="openStockNumberDetail(row)"
            >
              View number
            </button>
            <template v-for="action in isStockGrouped ? [] : rowActionsForRow(row)" :key="action.key">
              <NuxtLink
                v-if="action.route"
                :to="actionRoute(action, row)"
                :target="action.target"
                :class="`btn btn-sm btn-${action.variant || 'outline-primary'} btn-wave`"
              >
                {{ action.label }}
              </NuxtLink>
              <button
                v-else
                type="button"
                :class="`btn btn-sm btn-${action.variant || 'outline-primary'} btn-wave`"
                :disabled="isActionDisabled(action, row)"
                :title="actionDisabledReason(action, row)"
                @click="openRowAction(action, row)"
              >
                {{ action.label }}
              </button>
            </template>
          </div>
        </template>
      </AdminDataTable>
      <AdminPagination
        v-if="!showListSections"
        :next-cursor="meta.next_cursor"
        :has-previous="pageState.index > 0"
        :loading="loading"
        :current-page="pageState.index + 1"
        :page-size="filters.limit || 20"
        @previous="loadPreviousPage"
        @next="loadNextPage"
      />
      <AdminTenantStockCoverage
        v-if="showTenantStockCoverage"
        :game-id="selectedTenantStockGameId"
        :refresh-key="tenantStockCoverageRefreshKey"
      />
    </template>

    <template v-if="showRelatedLists">
      <div v-for="related in activeRelatedLists" :key="related.key">
        <AdminFilterBar
          v-if="related.filters?.length"
          :filters="hydrateFilters(related.filters || [])"
          :model-value="relatedFilters[related.key] || {}"
          @apply="applyRelatedFilters(related, $event)"
        />
        <AdminExportPanel :actions="related.collectionActions || []" @run="openRelatedCollectionAction(related, $event)" />
        <AdminApiState :error="relatedErrors[related.key]" />
        <AdminDataTable
          :title="related.title"
          :columns="related.columns || []"
          :rows="relatedRows[related.key] || []"
          :loading="relatedLoading[related.key]"
          :sort-key="relatedSortState[related.key]?.key || ''"
          :sort-direction="relatedSortState[related.key]?.direction || 'asc'"
          :sortable="Boolean(related.apiSort)"
          :empty-title="related.emptyTitle || `No ${related.title.toLowerCase()}`"
          :empty-message="related.emptyMessage || 'No related records were returned from the approved back-office API.'"
          @sort-change="applyRelatedSort(related, $event)"
        >
          <template v-for="column in related.columns || []" #[`cell-${column.key}`]="{ row }">
            <AdminStatusBadge v-if="column.type === 'status'" :status="row[column.key]" />
            <AdminImagePreview v-else-if="column.type === 'image'" :image="row[column.key]" :label="column.label" />
            <span v-else>{{ formattedCellValue(row, column) }}</span>
          </template>
          <template v-if="hasRelatedRowActions(related)" #rowActions="{ row }">
            <div class="d-flex justify-content-end gap-1">
              <button
                v-if="related.detailEndpoint"
                type="button"
                class="btn btn-sm btn-primary btn-wave"
                @click="openRelatedDetail(related, row)"
              >
                Detail
              </button>
              <button
                v-for="action in relatedRowActionsForRow(related, row)"
                :key="action.key"
                type="button"
                :class="`btn btn-sm btn-${action.variant || 'outline-primary'} btn-wave`"
                :disabled="isActionDisabled(action, row)"
                :title="actionDisabledReason(action, row)"
                @click="openRelatedRowAction(related, action, row)"
              >
                {{ action.label }}
              </button>
            </div>
          </template>
        </AdminDataTable>
        <AdminPagination
          v-if="related.filters?.length"
          :next-cursor="relatedMeta[related.key]?.next_cursor || null"
          :has-previous="(relatedPageState[related.key]?.index || 0) > 0"
          :loading="relatedLoading[related.key]"
          :current-page="(relatedPageState[related.key]?.index || 0) + 1"
          :page-size="relatedFilters[related.key]?.limit || 20"
          @previous="loadPreviousRelatedPage(related)"
          @next="loadNextRelatedPage(related)"
        />
      </div>
    </template>

    <AdminModal v-model="stockNumberDetail.open" :title="stockNumberDetail.title" size="xl">
      <div class="row g-2 mb-3">
        <div class="col-md-3">
          <label class="form-label" for="stock-number-scope-type">Scope</label>
          <select id="stock-number-scope-type" v-model="stockNumberDetail.scopeType" class="form-select" @change="handleStockNumberScopeChange">
            <option value="central">Central</option>
            <option value="partner">Partner</option>
          </select>
        </div>
        <div class="col-md-6">
          <label class="form-label" for="stock-number-scope-id">Scope ID</label>
          <input
            id="stock-number-scope-id"
            v-model="stockNumberDetail.scopeId"
            class="form-control"
            :disabled="stockNumberDetail.scopeType === 'central'"
            placeholder="Partner ID"
            @keyup.enter="loadStockNumberDetail()"
          >
        </div>
        <div class="col-md-3 d-flex align-items-end">
          <button
            class="btn btn-primary btn-wave w-100"
            type="button"
            :disabled="stockNumberDetail.loading || !stockNumberDetail.gameId || !stockNumberDetail.fullNumber || (stockNumberDetail.scopeType === 'partner' && !stockNumberDetail.scopeId)"
            @click="loadStockNumberDetail()"
          >
            <span v-if="stockNumberDetail.loading" class="spinner-border spinner-border-sm me-2" />
            Apply scope
          </button>
        </div>
      </div>
      <AdminStockNumberDetail
        :record="stockNumberDetail.record"
        :loading="stockNumberDetail.loading"
        :error="stockNumberDetail.error"
      />
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" @click="stockNumberDetail.open = false">Close</button>
      </template>
    </AdminModal>

    <AdminModal v-model="stockTickets.open" :title="stockTickets.title">
      <AdminApiState :error="stockTickets.error" />
      <AdminDataTable
        title="Ticket rows"
        :columns="stockTicketColumns"
        :rows="stockTickets.rows"
        :loading="stockTickets.loading"
        :sort-key="stockTickets.sortKey"
        :sort-direction="stockTickets.sortDirection"
        sortable
        empty-title="No tickets"
        empty-message="No stock item rows matched this number."
        @sort-change="applyStockTicketSort"
      >
        <template #cell-status="{ row }">
          <AdminStatusBadge :status="row.status" />
        </template>
        <template #rowActions="{ row }">
          <button
            v-for="action in hydratedActions"
            :key="action.key"
            type="button"
            :class="`btn btn-sm btn-${action.variant || 'outline-primary'} btn-wave`"
            @click="openStockTicketAction(action, row)"
          >
            {{ action.label }}
          </button>
        </template>
      </AdminDataTable>
      <AdminPagination
        :next-cursor="stockTickets.meta.next_cursor"
        :has-previous="stockTickets.pageState.index > 0"
        :loading="stockTickets.loading"
        :current-page="stockTickets.pageState.index + 1"
        :page-size="stockTickets.limit"
        @previous="loadPreviousStockTicketPage"
        @next="loadNextStockTicketPage"
      />
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" @click="stockTickets.open = false">Close</button>
      </template>
    </AdminModal>

    <AdminConfirmAction
      v-model="confirm.open"
      :title="confirm.title"
      :message="confirm.message"
      :requires-reason="confirm.action?.reason"
      :optional-reason="confirm.action?.optionalReason"
      :requires-payload="Boolean(confirm.action?.payloadTemplate) && !confirm.action?.formFields?.length"
      :payload-template="confirm.action?.payloadTemplate"
      :form-fields="confirm.action?.formFields || []"
      :record-context="confirm.row"
      :context-fields="confirm.action?.contextFields || resource?.confirmContextFields || []"
      :loading="saving"
      :error="actionError"
      @confirm="runConfirmedAction"
    />

    <AdminModal v-model="relatedDetail.open" :title="relatedDetail.title">
      <AdminApiState :error="relatedDetail.error" />
      <AdminTopupDetail
        v-if="relatedDetail.renderer === 'topup'"
        :record="relatedDetail.record"
        :loading="relatedDetail.loading"
      />
      <AdminOrderDetail
        v-else-if="relatedDetail.renderer === 'order'"
        :record="relatedDetail.record"
        :loading="relatedDetail.loading"
      />
      <AdminDetailSection
        v-else
        title="Detail"
        :record="relatedDetailSectionRecord"
        :fields="relatedDetail.detailFields"
        :loading="relatedDetail.loading"
      />
      <template #footer>
        <button class="btn btn-light btn-wave" type="button" @click="relatedDetail.open = false">Close</button>
      </template>
    </AdminModal>
  </div>
</template>

<script setup lang="ts">
import type { OperationAction, OperationColumn, OperationFilter, OperationFormField, OperationOption, OperationOptionSource, OperationRelatedList, OperationResource, OperationSettingsPanel } from '~/composables/useAdminOperationsCatalog'
import AdminCustomerDetail from '~/components/AdminCustomerDetail.vue'
import AdminOrderDetail from '~/components/AdminOrderDetail.vue'
import AdminPartnerDetail from '~/components/AdminPartnerDetail.vue'
import AdminTenantStockCoverage from '~/components/AdminTenantStockCoverage.vue'
import AdminTenantStockDetail from '~/components/AdminTenantStockDetail.vue'
import AdminTopupDetail from '~/components/AdminTopupDetail.vue'
import AdminWalletDetail from '~/components/AdminWalletDetail.vue'
import { formatAdminValue, formatDateTime, formatMoney, titleize } from '~/utils/format'

const props = defineProps<{
  scope: 'tenant' | 'central'
}>()

const route = useRoute()
const api = useAdminApi()
const session = useAdminSession()
const catalog = useAdminOperationsCatalog()

const loading = ref(false)
const saving = ref(false)
const error = ref<any>(null)
const actionError = ref<any>(null)
const rows = ref<any[]>([])
const detail = ref<any>(null)
const settingsDraft = ref('')
const settingsForm = reactive<Record<string, any>>({})
const secondaryDetails = reactive<Record<string, any>>({})
const secondaryForms = reactive<Record<string, Record<string, any>>>({})
const secondaryLoading = reactive<Record<string, boolean>>({})
const secondarySaving = reactive<Record<string, boolean>>({})
const secondaryErrors = reactive<Record<string, any>>({})
const detailDraft = ref('')
const filters = ref<Record<string, any>>({})
const stockSummaryRefreshKey = ref(0)
const stockTableRealtimeReloading = ref(false)
const tenantStockRealtimeReloading = ref(false)
const tenantStockCoverageRefreshKey = ref(0)
const stockGenerationProgressRefreshKey = ref(0)
const stockGenerationSubmittedBatch = ref<any>(null)
const stockGenerationHasActiveBatch = ref(false)
const sortState = reactive<{ key: string, direction: 'asc' | 'desc' }>({ key: '', direction: 'asc' })
const meta = reactive({ next_cursor: null as string | null, has_more: false })
const listMeta = ref<Record<string, any>>({})
const pageState = reactive({ cursors: [null] as Array<string | null>, index: 0 })
const relatedFilters = reactive<Record<string, Record<string, any>>>({})
const relatedRows = reactive<Record<string, any[]>>({})
const relatedLoading = reactive<Record<string, boolean>>({})
const relatedErrors = reactive<Record<string, any>>({})
const relatedMeta = reactive<Record<string, { next_cursor: string | null, has_more: boolean }>>({})
const relatedPageState = reactive<Record<string, { cursors: Array<string | null>, index: number }>>({})
const relatedSortState = reactive<Record<string, { key: string, direction: 'asc' | 'desc' }>>({})
const confirm = reactive<{
  open: boolean
  title: string
  message: string
  action: OperationAction | null
  row: any
  related: OperationRelatedList | null
}>({
  open: false,
  title: '',
  message: '',
  action: null,
  row: null,
  related: null,
})
const relatedDetail = reactive<{
  open: boolean
  title: string
  loading: boolean
  error: any
  record: any
  renderer: string
  detailFields: OperationColumn[]
}>({
  open: false,
  title: '',
  loading: false,
  error: null,
  record: null,
  renderer: '',
  detailFields: [],
})
const stockNumberDetail = reactive<{
  open: boolean
  title: string
  loading: boolean
  error: any
  record: any
  gameId: string
  fullNumber: string
  scopeType: 'central' | 'partner'
  scopeId: string
}>({
  open: false,
  title: '',
  loading: false,
  error: null,
  record: null,
  gameId: '',
  fullNumber: '',
  scopeType: 'central',
  scopeId: 'central',
})
const stockTickets = reactive<{
  open: boolean
  title: string
  loading: boolean
  error: any
  rows: any[]
  gameId: string
  fullNumber: string
  status: string
  limit: number
  sortKey: string
  sortDirection: 'asc' | 'desc'
  meta: { next_cursor: string | null, has_more: boolean }
  pageState: { cursors: Array<string | null>, index: number }
}>({
  open: false,
  title: '',
  loading: false,
  error: null,
  rows: [],
  gameId: '',
  fullNumber: '',
  status: '',
  limit: 20,
  sortKey: '',
  sortDirection: 'asc',
  meta: { next_cursor: null, has_more: false },
  pageState: { cursors: [null], index: 0 },
})
const optionSourceOptions = reactive<Record<OperationOptionSource, OperationOption[]>>({
  'central-games': [],
  'central-winner-games': [],
  'central-sale-price-games': [],
  'central-partners': [],
  'central-billing-plans': [],
  'central-admin-roles': [],
  'tenant-admin-roles': [],
  'allocation-partners': [],
  'allocation-tenants': [],
  'allocation-games': [],
  'tenant-stock-games': [],
  'tenant-price-rule-games': [],
  'tenant-sale-price-games': [],
  'tenant-customers': [],
  'tenant-affiliates': [],
  'tenant-affiliate-programs': [],
})
const optionSourceLoading = reactive<Record<OperationOptionSource, boolean>>({
  'central-games': false,
  'central-winner-games': false,
  'central-sale-price-games': false,
  'central-partners': false,
  'central-billing-plans': false,
  'central-admin-roles': false,
  'tenant-admin-roles': false,
  'allocation-partners': false,
  'allocation-tenants': false,
  'allocation-games': false,
  'tenant-stock-games': false,
  'tenant-price-rule-games': false,
  'tenant-sale-price-games': false,
  'tenant-customers': false,
  'tenant-affiliates': false,
  'tenant-affiliate-programs': false,
})
const stockSettingsDefaults = ref<any[]>([])
const stockSettingsLoading = ref(false)

const slugParts = computed(() => normalizeSlug(route.params.slug))
const resolved = computed(() => catalog.resolve(props.scope, slugParts.value))
const resource = computed(() => resolved.value.resource)
const tableRows = computed(() => (
  resource.value?.clientSort
    ? sortRows(rows.value, sortState.key, sortState.direction)
    : rows.value
))
const mode = computed(() => resolved.value.mode)
const recordId = computed(() => resolved.value.id)
const scopeLabel = computed(() => props.scope === 'tenant' ? 'Tenant' : 'Central')
const scopeBasePath = computed(() => `/admin/${props.scope}`)
const pageTitle = computed(() => mode.value === 'detail' ? `${resource.value?.title || 'Detail'} detail` : resource.value?.title || 'Operations')
const listPath = computed(() => resource.value ? `${scopeBasePath.value}/${resource.value.slug}` : scopeBasePath.value)
const canReload = computed(() => Boolean(resource.value && mode.value !== 'report-index' && !resource.value.apiGap && !detailGap.value && !isStockPatternCoverageRoute.value))
const hasDetailRoute = computed(() => Boolean(resource.value?.detailEndpoint || resource.value?.detailFromList || resource.value?.detailApiGap))
const detailGap = computed(() => mode.value === 'detail' && !resource.value?.detailEndpoint && !resource.value?.detailFromList ? resource.value?.detailApiGap || 'No documented detail GET endpoint is available for this route.' : '')
const isStockGrouped = computed(() => Boolean(resource.value?.stockGrouped))
const isStockGenerationRoute = computed(() => props.scope === 'central' && slugParts.value.join('/') === 'stock-generation')
const isStockSettingsRoute = computed(() => props.scope === 'central' && slugParts.value.join('/') === 'stock-settings')
const isStockPatternCoverageRoute = computed(() => props.scope === 'central' && slugParts.value.join('/') === 'stock-pattern-coverage')
const isAllocationsRoute = computed(() => props.scope === 'central' && slugParts.value.join('/') === 'allocations')
const isWinnersRoute = computed(() => props.scope === 'central' && slugParts.value.join('/') === 'winners')
const isTenantStockRoute = computed(() => props.scope === 'tenant' && resource.value?.slug === 'stock')
const isTenantTopupsRoute = computed(() => props.scope === 'tenant' && resource.value?.slug === 'topups')
const isPriceRulesRoute = computed(() => props.scope === 'tenant' && resource.value?.slug === 'price-rules')
const isSalePriceRulesRoute = computed(() => resource.value?.slug === 'sale-price-rules')
const showListSections = computed(() => Boolean(resource.value?.listSections?.length && mode.value === 'list'))
const activeRelatedLists = computed(() => showListSections.value ? (resource.value?.listSections || []) : (resource.value?.relatedLists || []))
const showStockSummaryWidgets = computed(() => Boolean(resource.value?.stockSummaryEndpoint && mode.value === 'list'))
const showAllocationSummaryWidgets = computed(() => Boolean(isAllocationsRoute.value && mode.value === 'list'))
const showStockGenerationProgress = computed(() => Boolean(isStockGenerationRoute.value && mode.value === 'list'))
const showTenantStockCoverage = computed(() => Boolean(isTenantStockRoute.value && mode.value === 'list' && selectedTenantStockGameId.value))
const stockSummaryEndpoint = computed(() => resource.value?.stockSummaryEndpoint || '')
const stockSummaryGameId = computed(() => filters.value.game_id || '')
const stockSummaryBatchId = computed(() => filters.value.batch_id || '')
const selectedStockTableGameId = computed(() => String(filters.value.game_id || '').trim())
const selectedTenantStockGameId = computed(() => isTenantStockRoute.value ? String(filters.value.game_id || '').trim() : '')
const isCentralGroupedStockRoute = computed(() => Boolean(
  props.scope === 'central'
  && mode.value === 'list'
  && resource.value?.stockGrouped,
))
const showStockTableRealtimePanel = computed(() => isCentralGroupedStockRoute.value)
const isCentralGroupedStockTable = computed(() => Boolean(
  isCentralGroupedStockRoute.value
  && selectedStockTableGameId.value,
))
const stockTableRealtimeChannelName = computed(() => (
  isCentralGroupedStockTable.value
    ? `private-admin.central.stock.table.game.${selectedStockTableGameId.value}`
    : ''
))
const stockTableRealtimeEnabled = computed(() => Boolean(
  isCentralGroupedStockTable.value
  && session.isAuthenticated.value,
))
const stockTableRealtime = useAdminRealtimeSubscription({
  channelName: stockTableRealtimeChannelName,
  eventName: 'stock.table.updated',
  enabled: stockTableRealtimeEnabled,
  onEvent: handleStockTableRealtimeEvent,
  onReconnect: handleStockTableRealtimeReconnect,
})
const stockTableRealtimeStatus = computed(() => stockTableRealtime.status.value)
const stockTableRealtimeError = computed(() => stockTableRealtime.error.value)
const stockTableRealtimeConfigured = computed(() => stockTableRealtime.isConfigured.value)
const stockTableRealtimeLastEventLabel = computed(() => (
  stockTableRealtime.lastEventAt.value
    ? `Last event ${formatDateTime(stockTableRealtime.lastEventAt.value)}`
    : ''
))
const stockTableRealtimeStatusLabel = computed(() => {
  if (!selectedStockTableGameId.value) {
    return 'Game required'
  }
  if (!stockTableRealtimeConfigured.value) {
    return 'Fallback HTTP'
  }
  if (stockTableRealtimeReloading.value) {
    return 'Refreshing'
  }

  const labels: Record<string, string> = {
    idle: 'Idle',
    unavailable: 'Unavailable',
    connecting: 'Connecting',
    authenticating: 'Authenticating',
    connected: 'Live',
    reconnecting: 'Reconnecting',
    error: 'Attention',
  }
  return labels[stockTableRealtimeStatus.value] || 'Realtime'
})
const stockTableRealtimeStatusBadgeClass = computed(() => {
  if (!selectedStockTableGameId.value) {
    return 'bg-info-transparent text-info'
  }
  if (!stockTableRealtimeConfigured.value) {
    return 'bg-secondary-transparent text-secondary'
  }
  if (stockTableRealtimeReloading.value || stockTableRealtimeStatus.value === 'connecting' || stockTableRealtimeStatus.value === 'authenticating' || stockTableRealtimeStatus.value === 'reconnecting') {
    return 'bg-warning-transparent text-warning'
  }
  if (stockTableRealtimeStatus.value === 'connected') {
    return 'bg-success-transparent text-success'
  }
  if (stockTableRealtimeStatus.value === 'error') {
    return 'bg-danger-transparent text-danger'
  }
  return 'bg-light text-default'
})
const stockTableRealtimePanelMessage = computed(() => {
  if (!selectedStockTableGameId.value) {
    return 'Choose a game filter to load the stock summary panel and subscribe this grouped table to live count updates.'
  }
  if (!session.isAuthenticated.value) {
    return 'Sign in to enable live stock table updates.'
  }
  if (!stockTableRealtimeConfigured.value) {
    return 'Realtime is not configured in this environment. The table and summary remain available through HTTP refresh.'
  }
  if (stockTableRealtimeReloading.value) {
    return 'Applying a realtime stock update by refreshing the current table page and summary widgets.'
  }
  if (stockTableRealtimeStatus.value === 'connected') {
    return 'Listening for stock.table.updated events. Safe visible rows update in place; uncertain changes refresh this table and summary.'
  }
  if (stockTableRealtimeStatus.value === 'reconnecting') {
    return 'Reconnecting to stock table realtime. The table will refresh after the subscription is restored.'
  }
  if (stockTableRealtimeStatus.value === 'error') {
    return 'Realtime needs attention. Manual refresh still loads the latest table and summary data.'
  }
  return 'Preparing stock table realtime for this game.'
})
const showTenantStockRealtimePanel = computed(() => Boolean(isTenantStockRoute.value && mode.value === 'list'))
const tenantStockRealtimeChannelName = computed(() => (
  selectedTenantStockGameId.value && session.currentTenantId.value
    ? `private-admin.tenant.${session.currentTenantId.value}.stock.game.${selectedTenantStockGameId.value}`
    : ''
))
const tenantStockRealtimeEnabled = computed(() => Boolean(
  showTenantStockRealtimePanel.value
  && selectedTenantStockGameId.value
  && session.isAuthenticated.value,
))
const tenantStockRealtime = useAdminRealtimeSubscription({
  channelName: tenantStockRealtimeChannelName,
  eventName: 'stock.availability.updated',
  enabled: tenantStockRealtimeEnabled,
  onEvent: handleTenantStockRealtimeEvent,
  onReconnect: handleTenantStockRealtimeReconnect,
})
const tenantStockRealtimeStatus = computed(() => tenantStockRealtime.status.value)
const tenantStockRealtimeError = computed(() => tenantStockRealtime.error.value)
const tenantStockRealtimeConfigured = computed(() => tenantStockRealtime.isConfigured.value)
const tenantStockRealtimeLastEventLabel = computed(() => (
  tenantStockRealtime.lastEventAt.value
    ? `Last event ${formatDateTime(tenantStockRealtime.lastEventAt.value)}`
    : ''
))
const tenantStockRealtimeStatusLabel = computed(() => {
  if (!selectedTenantStockGameId.value) {
    return 'Game required'
  }
  if (!tenantStockRealtimeConfigured.value) {
    return 'Fallback HTTP'
  }
  if (tenantStockRealtimeReloading.value) {
    return 'Refreshing'
  }

  const labels: Record<string, string> = {
    idle: 'Idle',
    unavailable: 'Unavailable',
    connecting: 'Connecting',
    authenticating: 'Authenticating',
    connected: 'Live',
    reconnecting: 'Reconnecting',
    error: 'Attention',
  }
  return labels[tenantStockRealtimeStatus.value] || 'Realtime'
})
const tenantStockRealtimeStatusBadgeClass = computed(() => {
  if (!selectedTenantStockGameId.value) {
    return 'bg-info-transparent text-info'
  }
  if (!tenantStockRealtimeConfigured.value) {
    return 'bg-secondary-transparent text-secondary'
  }
  if (tenantStockRealtimeReloading.value || tenantStockRealtimeStatus.value === 'connecting' || tenantStockRealtimeStatus.value === 'authenticating' || tenantStockRealtimeStatus.value === 'reconnecting') {
    return 'bg-warning-transparent text-warning'
  }
  if (tenantStockRealtimeStatus.value === 'connected') {
    return 'bg-success-transparent text-success'
  }
  if (tenantStockRealtimeStatus.value === 'error') {
    return 'bg-danger-transparent text-danger'
  }
  return 'bg-light text-default'
})
const tenantStockRealtimePanelMessage = computed(() => {
  if (!selectedTenantStockGameId.value) {
    return 'Choose a game filter to subscribe this tenant stock table to live availability updates.'
  }
  if (!session.isAuthenticated.value) {
    return 'Sign in to enable live tenant stock updates.'
  }
  if (!tenantStockRealtimeConfigured.value) {
    return 'Realtime is not configured in this environment. The table and coverage still load through HTTP refresh.'
  }
  if (tenantStockRealtimeReloading.value) {
    return 'Applying a realtime availability update by refreshing this tenant stock page.'
  }
  if (tenantStockRealtimeStatus.value === 'connected') {
    return 'Listening for stock.availability.updated events for this tenant game.'
  }
  if (tenantStockRealtimeStatus.value === 'reconnecting') {
    return 'Reconnecting to tenant stock realtime. The table refreshes after the subscription is restored.'
  }
  if (tenantStockRealtimeStatus.value === 'error') {
    return 'Realtime needs attention. Manual refresh still loads the latest tenant stock.'
  }
  return 'Preparing tenant stock realtime for this game.'
})
const tenantTopupsRealtimeChannelName = computed(() => (
  isTenantTopupsRoute.value && session.currentTenantId.value
    ? `private-admin.tenant.${session.currentTenantId.value}.topups`
    : ''
))
const tenantTopupsRealtimeEnabled = computed(() => Boolean(
  isTenantTopupsRoute.value
  && showListSections.value
  && session.isAuthenticated.value,
))
useAdminRealtimeSubscription({
  channelName: tenantTopupsRealtimeChannelName,
  eventName: 'topup.updated',
  enabled: tenantTopupsRealtimeEnabled,
  onEvent: handleTenantTopupRealtimeEvent,
})
const currentCentralGameOption = computed(() => singleCurrentGameOption(optionSourceOptions['central-games'] || []))
const currentCentralWinnerGameOption = computed(() => latestDefaultOrCurrentGameOption(optionSourceOptions['central-winner-games'] || []))
const currentCentralSalePriceGameOption = computed(() => latestDefaultOrCurrentGameOption(optionSourceOptions['central-sale-price-games'] || []))
const currentAllocationGameOption = computed(() => latestCurrentGameOption(optionSourceOptions['allocation-games'] || []))
const currentTenantStockGameOption = computed(() => latestTenantStockGameOption(optionSourceOptions['tenant-stock-games'] || []))
const currentTenantPriceRuleGameOption = computed(() => latestTenantPriceRuleGameOption(optionSourceOptions['tenant-price-rule-games'] || []))
const currentTenantSalePriceGameOption = computed(() => latestDefaultOrCurrentGameOption(optionSourceOptions['tenant-sale-price-games'] || []))
const allocationSummaryCards = computed(() => {
  const game = currentAllocationGameOption.value
  const isLoading = optionSourceLoading['allocation-games']
  const gameHint = game ? `Game ${optionLabel(game)}` : 'No latest open game'

  return [
    {
      key: 'generated',
      label: 'Generated supply',
      value: summaryNumberValue(optionNumber(game, 'generatedSupplyCount'), isLoading),
      hint: gameHint,
      icon: 'ri-ticket-2-line',
      colorClass: 'bg-primary-transparent text-primary',
    },
    {
      key: 'remaining',
      label: 'Existing remaining',
      value: summaryNumberValue(optionNumber(game, 'existingGameRemainingCount'), isLoading),
      hint: gameHint,
      icon: 'ri-inbox-archive-line',
      colorClass: 'bg-success-transparent text-success',
    },
    {
      key: 'percent',
      label: 'Existing partner %',
      value: summaryPercentValue(optionNumber(game, 'existingGameAllocationPercent'), isLoading),
      hint: gameHint,
      icon: 'ri-pie-chart-2-line',
      colorClass: 'bg-info-transparent text-info',
    },
  ]
})
const stockSetDistributionDefault = computed(() => (
  stockSettingsDefaults.value.length
    ? stockSettingsDefaults.value
    : [
        { set_size: 2, percent: 10 },
        { set_size: 3, percent: 15 },
      ]
))
const shouldDefaultStockGenerationGame = computed(() => Boolean(isStockGenerationRoute.value && mode.value === 'list'))
const stockGenerationGenerateBlocked = computed(() => Boolean(
  showStockGenerationProgress.value
  && (stockGenerationHasActiveBatch.value || !currentCentralGameOption.value),
))
const stockGenerationGenerateDisabledReason = computed(() => {
  if (!showStockGenerationProgress.value) {
    return ''
  }
  if (stockGenerationHasActiveBatch.value) {
    return 'A stock generation batch is already queued or processing for this game.'
  }
  if (!currentCentralGameOption.value) {
    return 'No single current game is available for stock generation.'
  }
  return ''
})
const stockGenerateCurrentGameMessage = computed(() => {
  if (!shouldDefaultStockGenerationGame.value || optionSourceLoading['central-games'] || currentCentralGameOption.value) {
    return ''
  }

  return 'No single current draw/current game is available. Open exactly one game with status open before generating stock.'
})
const hydratedFilters = computed(() => hydrateFilters(resource.value?.filters || []))
const hydratedCollectionActions = computed(() => hydrateActions(resource.value?.collectionActions || []))
const hydratedActions = computed(() => hydrateActions(resource.value?.actions || []))
const detailActions = computed(() => {
  const row = detail.value ? { ...detail.value, __id: recordId.value } : null
  if (!row) {
    return hydratedActions.value
  }

  return hydratedActions.value
    .map((action) => rowSpecificAction(action, row))
    .filter((action) => !(action.hideWhenDisabled && isActionDisabled(action, row)))
})
const tableColumns = computed(() => {
  const columns = resource.value?.columns || []
  if (!isStockGenerationRoute.value) {
    return columns
  }

  return columns.filter((column) => column.key !== 'game_id')
})
const detailDisplayRecord = computed(() => {
  if (resource.value?.detailRenderer !== 'reward' || !detail.value) {
    return detail.value
  }

  const { prizes, ...record } = detail.value
  return record
})
const detailSectionRecord = computed(() => {
  return detailDisplayRecord.value
})
const relatedDetailSectionRecord = computed(() => {
  return relatedDetail.record
})
const hasSettingsForm = computed(() => Boolean(resource.value?.settingsFields?.length))
const isMenuManagement = computed(() => resource.value?.slug === 'menu-management')
const showRelatedLists = computed(() => Boolean(
  activeRelatedLists.value.length
  && (showListSections.value || mode.value === 'detail' || mode.value === 'settings')
  && !resource.value.apiGap
  && !detailGap.value,
))
const reportFilters = computed(() => resource.value?.filters?.length ? resource.value.filters : [
  { key: 'date_from', label: 'From', type: 'date' as const },
  { key: 'date_to', label: 'To', type: 'date' as const },
  { key: 'group_by', label: 'Group by' },
  { key: 'cursor', label: 'Cursor' },
  { key: 'limit', label: 'Limit', type: 'number' as const },
])
const hydratedReportFilters = computed(() => hydrateFilters(reportFilters.value))
const stockTicketColumns = [
  { key: 'id', label: 'Ticket' },
  { key: 'full_number', label: 'Number' },
  { key: 'status', label: 'Status', type: 'status' as const },
  { key: 'partner_id', label: 'Partner' },
  { key: 'tenant_id', label: 'Tenant' },
  { key: 'allocation_id', label: 'Allocation' },
  { key: 'batch_id', label: 'Batch' },
  { key: 'updated_at', label: 'Updated', type: 'datetime' as const },
]

type StockTableRealtimePayload = {
  game_id?: string | number
  refresh_required?: boolean
  reason?: string
  updated_at?: string
  row?: Record<string, any>
}

type LoadOptions = {
  silent?: boolean
}

const stockTableRealtimeCountKeys = [
  'available_count',
  'allocated_count',
  'sold_count',
  'recalled_count',
  'total_count',
]

const stockTableRealtimeMergeFields = [
  'game_id',
  'full_number',
  'front3',
  'back3',
  'back2',
  'available_count',
  'allocated_count',
  'sold_count',
  'recalled_count',
  'total_count',
  'status',
  'updated_at',
  'last_updated_at',
]

const stockTableRealtimeFilterKeysAllowedForMerge = new Set(['game_id', 'limit', 'cursor'])

watch(() => route.fullPath, () => {
  if (!import.meta.client) {
    return
  }
  void initializePage()
})

onMounted(() => {
  void initializePage()
})

const initializePage = async () => {
  resetFilters()
  await loadOptionSourcesForResource()
  applyCurrentGameFilterDefault()
  await load()
}

const resetFilters = () => {
  filters.value = {
    ...defaultFilterValues(resource.value?.filters || []),
    ...routeFilterValues(resource.value?.filters || []),
  }
  applyResourceDefaultSort()
  resetRelatedFilters()
}

function applyResourceDefaultSort() {
  const next = (resource.value?.apiSort || resource.value?.clientSort) ? resource.value.defaultSort : null
  sortState.key = next?.key || ''
  sortState.direction = next?.direction || 'asc'
}

const applyFilters = (next: Record<string, any>) => {
  filters.value = routeFiltersWithCurrentGame({ ...next })
  stockGenerationSubmittedBatch.value = null
  stockGenerationHasActiveBatch.value = false
  load()
}

const applySort = (next: { key: string, direction: 'asc' | 'desc' }) => {
  if (!resource.value?.apiSort && !resource.value?.clientSort) {
    return
  }

  sortState.key = next.key
  sortState.direction = next.direction
  if (resource.value.apiSort) {
    load(null, 'reset')
  }
}

const applyRelatedFilters = (related: OperationRelatedList, next: Record<string, any>) => {
  relatedFilters[related.key] = { ...defaultFilterValues(related.filters || []), ...next }
  loadRelatedList(related)
}

const applyRelatedSort = (related: OperationRelatedList, next: { key: string, direction: 'asc' | 'desc' }) => {
  if (!related.apiSort) {
    return
  }

  relatedSortState[related.key] = { key: next.key, direction: next.direction }
  loadRelatedList(related)
}

async function load(cursor?: string | null, pageMode: 'reset' | 'next' | 'previous' | 'current' = 'reset', options: LoadOptions = {}) {
  if (!session.isAuthenticated.value) {
    return
  }

  if (!resource.value || resource.value.apiGap || mode.value === 'report-index' || detailGap.value) {
    return
  }

  if (isStockPatternCoverageRoute.value) {
    return
  }

  const shouldShowLoading = !options.silent
  if (shouldShowLoading) {
    loading.value = true
  }
  error.value = null
  try {
    if (mode.value === 'detail') {
      if (resource.value.detailFromList) {
        detail.value = await loadDetailFromList()
      } else {
        const response = await api.apiFetch(interpolate(resource.value.detailEndpoint || '', recordId.value), apiOptions())
        detail.value = extractData(response)
      }
      detailDraft.value = JSON.stringify(detail.value || {}, null, 2)
      await loadRelatedLists()
      return
    }

    if (mode.value === 'settings') {
      const response = await api.apiFetch(resource.value.listEndpoint || '', apiOptions())
      detail.value = extractData(response)
      settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
      resetSettingsForm()
      await Promise.all([loadRelatedLists(), loadSecondarySettings()])
      return
    }

    if (mode.value === 'report-detail') {
      const response = await api.apiFetch(resource.value.listEndpoint || '', apiOptions({ query: queryWithCursor(cursor) }))
      detail.value = response
      return
    }

    if (mode.value === 'summary') {
      const response = await api.apiFetch(resource.value.listEndpoint || '', apiOptions({ query: cleanQuery(filters.value) }))
      detail.value = extractData(response)
      return
    }

    if (showListSections.value) {
      rows.value = []
      meta.next_cursor = null
      meta.has_more = false
      listMeta.value = {}
      pageState.cursors = [null]
      pageState.index = 0
      await loadRelatedLists()
      return
    }

    const pageCursor = cursor || null
    const response = await api.apiFetch(resource.value.listEndpoint || '', apiOptions({ query: queryWithCursor(pageCursor) }))
    const nextRows = normalizeRows(response, resource.value)
    rows.value = nextRows
    const nextMeta = extractMeta(response)
    listMeta.value = nextMeta
    meta.next_cursor = nextMeta.next_cursor || null
    meta.has_more = Boolean(nextMeta.has_more || nextMeta.next_cursor)
    updatePageState(pageState, pageCursor, pageMode)
  } catch (err) {
    error.value = err
  } finally {
    if (shouldShowLoading) {
      loading.value = false
    }
  }
}

async function loadDetailFromList() {
  if (!resource.value?.listEndpoint || !recordId.value) {
    return null
  }

  const response = await api.apiFetch(resource.value.listEndpoint, apiOptions({ query: { limit: 500 } }))
  const idKey = resource.value.idKey || 'id'
  const targetId = String(recordId.value)
  const match = extractItems(response).find((row: any) => String(row?.[idKey] || row?.id || row?.uuid || '') === targetId)

  if (!match) {
    throw new Error('Record was not found in the current list response.')
  }

  return match
}

const loadNextPage = () => {
  if (!meta.next_cursor) return
  load(meta.next_cursor, 'next')
}

const loadPreviousPage = () => {
  if (pageState.index <= 0) return
  load(pageState.cursors[pageState.index - 1] || null, 'previous')
}

const hydrateFilters = (items: OperationFilter[]) => items.map((item) => {
  const options = item.optionSource ? hydratedOptions(item.optionSource, item.options) : item.options

  if (shouldDefaultStockGenerationGame.value && item.key === 'game_id' && item.optionSource === 'central-games') {
    const currentGame = currentCentralGameOption.value
    return {
      ...item,
      options: currentGame ? [currentGame] : [],
      hideEmptyOption: Boolean(currentGame),
      emptyOptionLabel: currentGame ? item.emptyOptionLabel : 'No current game',
    }
  }

  if (isAllocationsRoute.value && item.key === 'game_id' && item.optionSource === 'allocation-games') {
    const currentGame = currentAllocationGameOption.value
    return {
      ...item,
      options: currentGame ? [currentGame] : [],
      hideEmptyOption: Boolean(currentGame),
      emptyOptionLabel: currentGame ? item.emptyOptionLabel : 'No open game',
    }
  }

  return {
    ...item,
    options,
  }
})

const hydrateFields = (fields: OperationFormField[] = []) => fields.map((field) => {
  const sourceOptions = field.optionSource ? hydratedOptions(field.optionSource, field.options) : field.options
  const currentGame = currentGameOptionForSource(field.optionSource)
  const options = field.currentOnly && (field.optionSource === 'central-games' || field.optionSource === 'allocation-games')
    ? currentGame ? [currentGame] : []
    : sourceOptions
  const currentGameValue = currentGame ? optionValue(currentGame) : ''

  return {
    ...field,
    options,
    defaultValue: field.defaultValueSource === 'current-game'
      ? currentGameValue
      : field.defaultValueSource === 'stock-set-distribution-default'
        ? stockSetDistributionDefault.value
        : field.defaultValue,
  }
})

const currentGameOptionForSource = (source?: OperationOptionSource) => {
  if (source === 'allocation-games') {
    return currentAllocationGameOption.value
  }
  if (source === 'central-sale-price-games') {
    return currentCentralSalePriceGameOption.value
  }
  if (source === 'central-winner-games') {
    return currentCentralWinnerGameOption.value
  }
  if (source === 'tenant-sale-price-games') {
    return currentTenantSalePriceGameOption.value
  }
  if (source === 'tenant-price-rule-games') {
    return currentTenantPriceRuleGameOption.value
  }

  return currentCentralGameOption.value
}

const hydrateActions = (actions: OperationAction[] = []) => actions.map((action) => {
  const hydrated = {
    ...action,
    formFields: hydrateFields(action.formFields || []),
  }

  if (isStockGenerateAction(hydrated)) {
    return {
      ...hydrated,
      disabled: stockGenerationGenerateBlocked.value,
      disabledReason: stockGenerationGenerateDisabledReason.value,
    }
  }

  return hydrated
})

const hydratedOptions = (source: OperationOptionSource, fallback: OperationOption[] = []) => {
  const options = optionSourceOptions[source] || []
  if (options.length) {
    return options
  }

  if (optionSourceLoading[source]) {
    return [{ value: '', label: 'Loading options...' }]
  }

  return fallback
}

const loadOptionSourcesForResource = async () => {
  if (!session.isAuthenticated.value || !resource.value) {
    return
  }

  const sources = collectOptionSources(resource.value)
  await Promise.all([
    ...[...sources].map((source) => loadOptionSource(source)),
    isStockGenerationRoute.value ? loadStockSettingsDefaults() : Promise.resolve(),
  ])
}

const loadStockSettingsDefaults = async () => {
  if (stockSettingsLoading.value) {
    return
  }

  stockSettingsLoading.value = true
  try {
    const response = await api.apiFetch('/admin/central/stock/settings', apiOptions())
    const data = extractData(response)
    const distribution = data?.settings?.stock_set_distribution_default || data?.stock_set_distribution_default || []
    stockSettingsDefaults.value = normalizeStockSetDistribution(distribution, {
      key: 'stock_set_distribution_default',
      label: 'Default set distribution',
      type: 'stock-set-distribution',
    } as OperationFormField)
      .map((row: any) => ({ set_size: row.set_size, percent: row.percent }))
  } catch {
    stockSettingsDefaults.value = []
  } finally {
    stockSettingsLoading.value = false
  }
}

const refreshAllocationGameOptions = async () => {
  optionSourceOptions['allocation-games'] = []
  await loadOptionSource('allocation-games')
  filters.value = allocationFiltersWithCurrentGame(filters.value)
}

const collectOptionSources = (item: OperationResource) => {
  const sources = new Set<OperationOptionSource>()
  const collectFields = (fields: OperationFormField[] = []) => {
    for (const field of fields) {
      if (field.optionSource) {
        sources.add(field.optionSource)
      }
    }
  }
  const collectFilters = (filters: OperationFilter[] = []) => {
    for (const filter of filters) {
      if (filter.optionSource) {
        sources.add(filter.optionSource)
      }
    }
  }
  const collectActions = (actions: OperationAction[] = []) => {
    for (const action of actions) {
      collectFields(action.formFields || [])
    }
  }

  collectFilters(item.filters || [])
  collectFields(item.settingsFields || [])
  collectActions(item.actions || [])
  collectActions(item.collectionActions || [])
  for (const related of item.relatedLists || []) {
    collectFilters(related.filters || [])
    collectActions(related.actions || [])
    collectActions(related.collectionActions || [])
  }
  for (const panel of item.secondarySettings || []) {
    collectFields(panel.settingsFields || [])
  }

  return sources
}

const loadOptionSource = async (source: OperationOptionSource) => {
  if (optionSourceLoading[source]) {
    return
  }

  if (optionSourceOptions[source]?.length && (source !== 'central-games' || singleCurrentGameOption(optionSourceOptions[source]))) {
    return
  }

  optionSourceLoading[source] = true
  try {
    if (source === 'central-games') {
      const response = await api.apiFetch('/admin/central/games', {
        scope: 'central',
        query: { limit: 100 },
      })
      let options = normalizeGameOptions(extractItems(response))
      if (!singleCurrentGameOption(options)) {
        try {
          const currentResponse = await api.apiFetch('/admin/central/games', {
            scope: 'central',
            query: { status: 'open', limit: 10 },
          })
          options = mergeOptions(options, normalizeGameOptions(extractItems(currentResponse)))
        } catch {
          // Keep the general game list if the focused current-game lookup is unavailable.
        }
      }
      optionSourceOptions[source] = options
    } else if (source === 'central-winner-games') {
      const response = await api.apiFetch('/admin/central/winners/games', {
        scope: 'central',
      })
      optionSourceOptions[source] = normalizeGameOptions(extractItems(response))
    } else if (source === 'central-sale-price-games') {
      const response = await api.apiFetch('/admin/central/sale-price-games', {
        scope: 'central',
      })
      optionSourceOptions[source] = normalizeGameOptions(extractItems(response))
    } else if (source === 'central-partners') {
      const response = await api.apiFetch('/admin/central/partners', {
        scope: 'central',
        query: { limit: 100 },
      })
      optionSourceOptions[source] = normalizePartnerOptions(extractItems(response))
    } else if (source === 'central-billing-plans') {
      const response = await api.apiFetch('/admin/central/billing-plans', {
        scope: 'central',
        query: { status: 'active', limit: 100 },
      })
      optionSourceOptions[source] = normalizeBillingPlanOptions(extractItems(response))
    } else if (source === 'central-admin-roles') {
      const response = await api.apiFetch('/admin/central/roles', {
        scope: 'central',
        query: { limit: 500 },
      })
      optionSourceOptions[source] = normalizeRoleOptions(extractItems(response))
    } else if (source === 'tenant-admin-roles') {
      const response = await api.apiFetch('/admin/tenant/roles', {
        scope: 'tenant',
        tenantId: session.currentTenantId.value,
        query: { limit: 500 },
      })
      optionSourceOptions[source] = normalizeRoleOptions(extractItems(response))
    } else if (source === 'allocation-partners') {
      const response = await api.apiFetch('/admin/central/allocation-options/partners', {
        scope: 'central',
        query: { limit: 500 },
      })
      optionSourceOptions[source] = normalizeAllocationPartnerOptions(extractItems(response))
    } else if (source === 'allocation-tenants') {
      const response = await api.apiFetch('/admin/central/allocation-options/tenants', {
        scope: 'central',
        query: { limit: 500 },
      })
      optionSourceOptions[source] = normalizeAllocationTenantOptions(extractItems(response))
    } else if (source === 'allocation-games') {
      const response = await api.apiFetch('/admin/central/allocation-options/games', {
        scope: 'central',
        query: { limit: 1 },
      })
      optionSourceOptions[source] = normalizeAllocationGameOptions(extractItems(response))
    } else if (source === 'tenant-stock-games') {
      const response = await api.apiFetch('/admin/tenant/stock/games', {
        scope: 'tenant',
        tenantId: session.currentTenantId.value,
      })
      optionSourceOptions[source] = normalizeTenantStockGameOptions(extractItems(response))
    } else if (source === 'tenant-price-rule-games') {
      const response = await api.apiFetch('/admin/tenant/price-rule-games', {
        scope: 'tenant',
        tenantId: session.currentTenantId.value,
      })
      optionSourceOptions[source] = normalizeTenantPriceRuleGameOptions(extractItems(response))
    } else if (source === 'tenant-sale-price-games') {
      const response = await api.apiFetch('/admin/tenant/sale-price-games', {
        scope: 'tenant',
        tenantId: session.currentTenantId.value,
      })
      optionSourceOptions[source] = normalizeGameOptions(extractItems(response))
    } else if (source === 'tenant-customers') {
      const response = await api.apiFetch('/admin/tenant/members', {
        scope: 'tenant',
        tenantId: session.currentTenantId.value,
        query: { limit: 500 },
      })
      optionSourceOptions[source] = normalizeCustomerOptions(extractItems(response))
    } else if (source === 'tenant-affiliates') {
      const response = await api.apiFetch('/admin/tenant/affiliates', {
        scope: 'tenant',
        tenantId: session.currentTenantId.value,
        query: { status: 'active', limit: 500 },
      })
      optionSourceOptions[source] = normalizeAffiliateOptions(extractItems(response))
    } else if (source === 'tenant-affiliate-programs') {
      const response = await api.apiFetch('/admin/tenant/affiliate-programs', {
        scope: 'tenant',
        tenantId: session.currentTenantId.value,
        query: { status: 'active', limit: 500 },
      })
      optionSourceOptions[source] = normalizeAffiliateProgramOptions(extractItems(response))
    }
  } catch {
    optionSourceOptions[source] = []
  } finally {
    optionSourceLoading[source] = false
  }
}

const gameOption = (game: any): OperationOption => {
  const id = game?.id || game?.game_id || game?.uuid || game?.code
  const name = game?.name || game?.game_name || game?.title || game?.code || id
  const code = game?.code && game.code !== name ? ` (${game.code})` : ''
  const status = String(game?.status || '').toLowerCase()
  const currentLabel = status === 'open' ? ' (Current)' : ''
  return {
    value: id,
    label: `${name}${code}${currentLabel}`,
    status,
    isCurrent: status === 'open',
    isDefault: Boolean(game?.is_default),
    sale_start_at: game?.sale_start_at,
    draw_at: game?.draw_at,
    close_at: game?.close_at,
    server_time: game?.server_time,
  }
}

const normalizeGameOptions = (items: any[]) => items
  .map(gameOption)
  .filter((option) => !isBlank(optionValue(option)))

const partnerOption = (partner: any): OperationOption => {
  const id = partner?.id || partner?.partner_id || partner?.uuid || partner?.code
  const name = partner?.name || partner?.display_name || partner?.code || id
  const code = partner?.code && partner.code !== name ? ` (${partner.code})` : ''
  return {
    value: id,
    label: `${name}${code}`,
    status: String(partner?.status || '').toLowerCase(),
  }
}

const normalizePartnerOptions = (items: any[]) => items
  .map(partnerOption)
  .filter((option) => !isBlank(optionValue(option)))

const billingPlanOption = (plan: any): OperationOption => {
  const code = plan?.code || plan?.billing_plan_code || plan?.id
  const name = plan?.name || code
  const suffix = code && code !== name ? ` (${code})` : ''

  return {
    value: code,
    label: `${name}${suffix}`,
    code,
    name,
    status: String(plan?.status || '').toLowerCase(),
    disabled: String(plan?.status || '').toLowerCase() !== 'active',
  }
}

const normalizeBillingPlanOptions = (items: any[]) => items
  .map(billingPlanOption)
  .filter((option) => !isBlank(optionValue(option)))

const roleOption = (role: any): OperationOption => {
  const id = role?.id || role?.role_id || role?.uuid || role?.code
  const code = role?.code || ''
  const name = role?.name || code || id
  const status = String(role?.status || '').toLowerCase()
  const suffix = code && code !== name ? ` (${code})` : ''

  return {
    value: id,
    label: `${name}${suffix}`,
    code,
    name,
    status,
    disabled: status !== '' && status !== 'active',
  }
}

const normalizeRoleOptions = (items: any[]) => items
  .map(roleOption)
  .filter((option) => !isBlank(optionValue(option)))

const customerOption = (customer: any): OperationOption => {
  const id = customer?.id || customer?.customer_id || customer?.member_id || customer?.uuid
  const customerNo = customer?.customer_no || customer?.member_no || customer?.member_code || ''
  const name = customer?.name || customer?.display_name || customer?.phone || id
  const phone = customer?.phone ? ` - ${customer.phone}` : ''
  const customerLabel = customerNo ? `${customerNo} - ` : ''

  return {
    value: id,
    label: `${customerLabel}${name}${phone}`,
    status: String(customer?.status || '').toLowerCase(),
  }
}

const normalizeCustomerOptions = (items: any[]) => items
  .map(customerOption)
  .filter((option) => !isBlank(optionValue(option)))

const affiliateOption = (affiliate: any): OperationOption => {
  const id = affiliate?.id || affiliate?.affiliate_id || affiliate?.affiliate_account_id || affiliate?.uuid
  const code = affiliate?.code || ''
  const name = affiliate?.name || affiliate?.email || affiliate?.phone || id
  const suffix = code && code !== name ? ` (${code})` : ''

  return {
    value: id,
    label: `${name}${suffix}`,
    code,
    name,
    status: String(affiliate?.status || '').toLowerCase(),
    disabled: String(affiliate?.status || '').toLowerCase() === 'archived',
  }
}

const normalizeAffiliateOptions = (items: any[]) => items
  .map(affiliateOption)
  .filter((option) => !isBlank(optionValue(option)))

const affiliateProgramOption = (program: any): OperationOption => {
  const id = program?.id || program?.affiliate_program_id || program?.uuid || program?.code
  const code = program?.code || ''
  const name = program?.name || code || id
  const suffix = code && code !== name ? ` (${code})` : ''

  return {
    value: id,
    label: `${name}${suffix}`,
    code,
    name,
    status: String(program?.status || '').toLowerCase(),
    disabled: String(program?.status || '').toLowerCase() === 'archived',
  }
}

const normalizeAffiliateProgramOptions = (items: any[]) => items
  .map(affiliateProgramOption)
  .filter((option) => !isBlank(optionValue(option)))

const allocationPartnerOption = (partner: any): OperationOption => {
  const id = partner?.partner_id || partner?.id || partner?.uuid || partner?.code
  const code = partner?.code || partner?.partner_code || ''
  const name = partner?.name || partner?.partner_name || partner?.display_name || id
  const singleTenantId = partner?.single_tenant_id || ''
  const singleTenantLabel = [partner?.single_tenant_code, partner?.single_tenant_name]
    .filter(Boolean)
    .join(' - ')
  return {
    value: id,
    label: partner?.label || [code, name].filter(Boolean).join(' - ') || String(id || ''),
    code,
    name,
    partnerId: id,
    activeTenantCount: Number(partner?.active_tenant_count || 0),
    singleTenantId,
    singleTenantLabel: singleTenantLabel || singleTenantId,
    allocationPercent: numberOrNull(partner?.allocation_percent),
    allocationPercentBasisPoints: numberOrNull(partner?.allocation_percent_basis_points),
    stockPercent: numberOrNull(partner?.stock_percent),
    stockPercentBasisPoints: numberOrNull(partner?.stock_percent_basis_points),
    defaultAllocationPercent: numberOrNull(partner?.default_allocation_percent),
    defaultAllocationPercentBasisPoints: numberOrNull(partner?.default_allocation_percent_basis_points),
    remainingCount: numberOrNull(partner?.remaining_count),
    existingAllocationPercent: numberOrNull(partner?.existing_allocation_percent),
    existingAllocationPercentBasisPoints: numberOrNull(partner?.existing_allocation_percent_basis_points),
    existingAllocatedCount: numberOrNull(partner?.existing_allocated_count),
    existingRemainingCount: numberOrNull(partner?.existing_remaining_count),
    status: String(partner?.status || '').toLowerCase(),
  }
}

const allocationTenantOption = (tenant: any): OperationOption => {
  const id = tenant?.tenant_id || tenant?.id || tenant?.uuid || tenant?.code
  const code = tenant?.code || tenant?.tenant_code || ''
  const name = tenant?.name || tenant?.tenant_name || id
  const partnerCode = tenant?.partner_code || ''
  return {
    value: id,
    label: tenant?.label || [code, name].filter(Boolean).join(' - ') || String(id || ''),
    code,
    name,
    tenantId: id,
    partnerId: tenant?.partner_id || '',
    status: String(tenant?.status || '').toLowerCase(),
    disabled: String(tenant?.status || '').toLowerCase() !== 'active',
    singleTenantLabel: partnerCode ? `${partnerCode} / ${name}` : name,
  }
}

const allocationGameOption = (game: any): OperationOption => {
  const id = game?.game_id || game?.id || game?.uuid || game?.code
  const code = game?.code || game?.game_code || ''
  const name = game?.name || game?.game_name || game?.title || id
  const status = String(game?.status || '').toLowerCase()
  return {
    value: id,
    label: game?.label || [code, name].filter(Boolean).join(' - ') || String(id || ''),
    code,
    name,
    status,
    isCurrent: status === 'open',
    generatedSupplyCount: numberOrNull(game?.generated_supply_count),
    existingGameAllocationPercent: numberOrNull(game?.existing_allocation_percent),
    existingGameAllocationPercentBasisPoints: numberOrNull(game?.existing_allocation_percent_basis_points),
    existingGameAllocatedCount: numberOrNull(game?.existing_allocated_count),
    existingGameRemainingCount: numberOrNull(game?.existing_remaining_count),
    sale_start_at: game?.sale_start_at,
    draw_at: game?.draw_at,
    close_at: game?.close_at,
  }
}

const tenantStockGameOption = (game: any): OperationOption => {
  const id = game?.game_id || game?.id || game?.uuid || game?.code
  const code = game?.code || game?.game_code || ''
  const name = game?.name || game?.game_name || game?.title || id
  const status = String(game?.status || '').toLowerCase()
  const allocatedCount = numberOrNull(game?.allocated_count)
  const countLabel = allocatedCount === null ? '' : ` · ${formatNumberOrDash(allocatedCount)} stock`
  return {
    value: id,
    label: game?.label || `${[code, name].filter(Boolean).join(' - ') || String(id || '')}${status === 'open' ? ' (Current)' : ''}${countLabel}`,
    code,
    name,
    status,
    isCurrent: status === 'open' || Boolean(game?.is_current),
    isDefault: Boolean(game?.is_default),
    allocatedCount,
    stockModes: Array.isArray(game?.stock_modes) ? game.stock_modes.map(String) : [],
    sale_start_at: game?.sale_start_at,
    draw_at: game?.draw_at,
    close_at: game?.close_at,
  }
}

const normalizeAllocationPartnerOptions = (items: any[]) => items
  .map(allocationPartnerOption)
  .filter((option) => !isBlank(optionValue(option)))

const normalizeAllocationTenantOptions = (items: any[]) => items
  .map(allocationTenantOption)
  .filter((option) => !isBlank(optionValue(option)))

const normalizeAllocationGameOptions = (items: any[]) => items
  .map(allocationGameOption)
  .filter((option) => !isBlank(optionValue(option)))

const normalizeTenantStockGameOptions = (items: any[]) => items
  .map(tenantStockGameOption)
  .filter((option) => !isBlank(optionValue(option)))

const normalizeTenantPriceRuleGameOptions = (items: any[]) => items
  .map(tenantStockGameOption)
  .filter((option) => !isBlank(optionValue(option)))

const optionValue = (option: OperationOption | null | undefined) => typeof option === 'object' && option !== null ? option.value : option
const optionLabel = (option: OperationOption | null | undefined) => typeof option === 'object' && option !== null ? option.label : String(option || '')

const optionNumber = (option: OperationOption | null | undefined, key: string) => {
  if (typeof option !== 'object' || option === null) {
    return null
  }

  const value = (option as Record<string, any>)[key]
  if (value === undefined || value === null || value === '') {
    return null
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

const summaryNumberValue = (value: number | null, loading: boolean) => {
  if (loading) {
    return 'Loading'
  }

  return formatNumberOrDash(value)
}

const summaryPercentValue = (value: number | null, loading: boolean) => {
  if (loading) {
    return 'Loading'
  }

  return value === null ? '-' : `${formatNumberOrDash(value)}%`
}

const formatNumberOrDash = (value: number | null | undefined) => {
  if (value === undefined || value === null || Number.isNaN(Number(value))) {
    return '-'
  }

  return new Intl.NumberFormat('en-US', {
    maximumFractionDigits: Number.isInteger(Number(value)) ? 0 : 2,
  }).format(Number(value))
}

const mergeOptions = (base: OperationOption[], next: OperationOption[]) => {
  const seen = new Set(base.map((option) => String(optionValue(option))))
  const merged = [...base]
  for (const option of next) {
    const value = String(optionValue(option))
    if (!seen.has(value)) {
      seen.add(value)
      merged.push(option)
    }
  }
  return merged
}

const singleCurrentGameOption = (options: OperationOption[]) => {
  const currentOptions = options.filter((option) => (
    typeof option === 'object'
    && option !== null
    && (option.isCurrent || String(option.status || '').toLowerCase() === 'open')
  ))

  return currentOptions.length === 1 ? currentOptions[0] : null
}

const latestCurrentGameOption = (options: OperationOption[]) => options.find((option) => (
  typeof option === 'object'
  && option !== null
  && (option.isCurrent || String(option.status || '').toLowerCase() === 'open')
)) || null

const latestTenantStockGameOption = (options: OperationOption[]) => options.find((option) => (
  typeof option === 'object'
  && option !== null
  && option.isDefault
)) || latestCurrentGameOption(options) || options[0] || null

const latestTenantPriceRuleGameOption = (options: OperationOption[]) => options.find((option) => (
  typeof option === 'object'
  && option !== null
  && option.isDefault
)) || latestCurrentGameOption(options) || options[0] || null

const latestDefaultOrCurrentGameOption = (options: OperationOption[]) => options.find((option) => (
  typeof option === 'object'
  && option !== null
  && option.isDefault
)) || latestCurrentGameOption(options) || options[0] || null

const applyCurrentGameFilterDefault = () => {
  filters.value = routeFiltersWithCurrentGame(filters.value)
}

const routeFiltersWithCurrentGame = (next: Record<string, any>) => (
  winnerFiltersWithDefaultGame(salePriceRuleFiltersWithCurrentGame(priceRuleFiltersWithCurrentGame(tenantStockFiltersWithCurrentGame(allocationFiltersWithCurrentGame(stockGenerationFiltersWithCurrentGame(next))))))
)

const stockGenerationFiltersWithCurrentGame = (next: Record<string, any>) => {
  if (!shouldDefaultStockGenerationGame.value || !isBlank(next.game_id)) {
    return next
  }

  const currentGame = currentCentralGameOption.value
  if (!currentGame) {
    return next
  }

  return {
    ...next,
    game_id: optionValue(currentGame),
  }
}

const allocationFiltersWithCurrentGame = (next: Record<string, any>) => {
  if (!isAllocationsRoute.value) {
    return next
  }

  const currentGame = currentAllocationGameOption.value
  return {
    ...next,
    game_id: currentGame ? optionValue(currentGame) : '',
  }
}

const winnerFiltersWithDefaultGame = (next: Record<string, any>) => {
  if (!isWinnersRoute.value || !isBlank(next.game_id)) {
    return next
  }

  const currentGame = currentCentralWinnerGameOption.value
  return {
    ...next,
    game_id: currentGame ? optionValue(currentGame) : '',
  }
}

const tenantStockFiltersWithCurrentGame = (next: Record<string, any>) => {
  if (!isTenantStockRoute.value || !isBlank(next.game_id)) {
    return next
  }

  const currentGame = currentTenantStockGameOption.value
  return {
    ...next,
    game_id: currentGame ? optionValue(currentGame) : '',
  }
}

const priceRuleFiltersWithCurrentGame = (next: Record<string, any>) => {
  if (!isPriceRulesRoute.value || !isBlank(next.game_id)) {
    return next
  }

  const currentGame = currentTenantPriceRuleGameOption.value
  return {
    ...next,
    game_id: currentGame ? optionValue(currentGame) : '',
  }
}

const salePriceRuleFiltersWithCurrentGame = (next: Record<string, any>) => {
  if (!isSalePriceRulesRoute.value || !isBlank(next.game_id)) {
    return next
  }

  const currentGame = props.scope === 'central'
    ? currentCentralSalePriceGameOption.value
    : currentTenantSalePriceGameOption.value
  return {
    ...next,
    game_id: currentGame ? optionValue(currentGame) : '',
  }
}

const isStockGenerateAction = (action: OperationAction | null | undefined) => (
  Boolean(action && isStockGenerationRoute.value && action.key === 'generate' && action.endpoint === '/admin/central/stock/generate')
)

const stockGenerationBatchFromResponse = (response: any) => {
  const data = extractData(response)
  return data?.batch || data
}

const isActiveStockGenerationBatch = (batch: any) => (
  ['queued', 'pending', 'processing'].includes(String(batch?.status || '').toLowerCase())
)

const saveSettings = async () => {
  if (!resource.value?.updateEndpoint) return
  saving.value = true
  error.value = null
  try {
    const payload = JSON.parse(settingsDraft.value || '{}')
    const response = await api.apiFetch(resource.value.updateEndpoint, apiOptions({
      method: resource.value.updateMethod || 'PATCH',
      body: payload,
      idempotencyKey: api.idempotencyKey(),
    }))
    detail.value = extractData(response)
    settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
  } catch (err: any) {
    error.value = err?.message ? err : { message: 'Settings JSON is invalid or could not be saved.', details: err }
  } finally {
    saving.value = false
  }
}

const resetSettings = () => {
  settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
}

const resetSettingsForm = () => {
  for (const key of Object.keys(settingsForm)) {
    delete settingsForm[key]
  }

  for (const field of resource.value?.settingsFields || []) {
    const value = getPath(detail.value || {}, field.sourceKey || field.key)
    settingsForm[field.key] = value !== undefined && value !== null
      ? normalizeInitialFieldValue(field, value)
      : field.defaultValue !== undefined ? field.defaultValue : normalizeInitialFieldValue(field, value)
  }
}

const saveSettingsForm = async () => {
  if (!resource.value?.updateEndpoint || !resource.value.settingsFields?.length) return
  saving.value = true
  error.value = null
  try {
    const payload = buildPayloadFromFields(resource.value.settingsFields, settingsForm)
    const response = await api.apiFetch(resource.value.updateEndpoint, apiOptions({
      method: resource.value.updateMethod || 'PATCH',
      body: payload,
      idempotencyKey: api.idempotencyKey(),
    }))
    detail.value = extractData(response)
    settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
    resetSettingsForm()
  } catch (err: any) {
    error.value = err
  } finally {
    saving.value = false
  }
}

const saveMenuTree = async (reason: string, items: any[]) => {
  if (!resource.value?.updateEndpoint) return
  saving.value = true
  error.value = null
  try {
    const response = await api.apiFetch(resource.value.updateEndpoint, apiOptions({
      method: resource.value.updateMethod || 'PUT',
      body: { items, reason },
      idempotencyKey: api.idempotencyKey(),
    }))
    detail.value = extractData(response)
    settingsDraft.value = JSON.stringify(detail.value || {}, null, 2)
  } catch (err: any) {
    error.value = err
  } finally {
    saving.value = false
  }
}

const loadSecondarySettings = async () => {
  const panels = resource.value?.secondarySettings || []
  if (!panels.length) return

  await Promise.all(panels.map(async (panel) => {
    secondaryLoading[panel.key] = true
    secondaryErrors[panel.key] = null
    secondaryForms[panel.key] = secondaryForms[panel.key] || {}
    try {
      const response = await api.apiFetch(panel.listEndpoint, apiOptions())
      secondaryDetails[panel.key] = extractData(response)
      resetSecondarySettingsForm(panel)
    } catch (err) {
      secondaryErrors[panel.key] = err
    } finally {
      secondaryLoading[panel.key] = false
    }
  }))
}

const resetSecondarySettingsForm = (panel: OperationSettingsPanel) => {
  const form = secondaryForms[panel.key] || {}
  for (const key of Object.keys(form)) {
    delete form[key]
  }

  for (const field of panel.settingsFields || []) {
    const value = getPath(secondaryDetails[panel.key] || {}, field.sourceKey || field.key)
    form[field.key] = value !== undefined && value !== null
      ? normalizeInitialFieldValue(field, value)
      : field.defaultValue !== undefined ? field.defaultValue : normalizeInitialFieldValue(field, value)
  }

  secondaryForms[panel.key] = form
}

const saveSecondarySettingsForm = async (panel: OperationSettingsPanel) => {
  secondarySaving[panel.key] = true
  secondaryErrors[panel.key] = null
  try {
    const payload = buildPayloadFromFields(panel.settingsFields, secondaryForms[panel.key] || {})
    const response = await api.apiFetch(panel.updateEndpoint, apiOptions({
      method: panel.updateMethod || 'PATCH',
      body: payload,
      idempotencyKey: api.idempotencyKey(),
    }))
    secondaryDetails[panel.key] = extractData(response)
    resetSecondarySettingsForm(panel)
  } catch (err: any) {
    secondaryErrors[panel.key] = err
  } finally {
    secondarySaving[panel.key] = false
  }
}

const saveDetailDraft = async () => {
  if (!resource.value?.updateEndpoint || !recordId.value) return
  saving.value = true
  error.value = null
  try {
    const payload = JSON.parse(detailDraft.value || '{}')
    const response = await api.apiFetch(interpolate(resource.value.updateEndpoint, recordId.value), apiOptions({
      method: resource.value.updateMethod || 'PATCH',
      body: payload,
      idempotencyKey: api.idempotencyKey(),
    }))
    detail.value = extractData(response)
    detailDraft.value = JSON.stringify(detail.value || {}, null, 2)
  } catch (err: any) {
    error.value = err?.message ? err : { message: 'Detail JSON is invalid or could not be saved.', details: err }
  } finally {
    saving.value = false
  }
}

const resetDetailDraft = () => {
  detailDraft.value = JSON.stringify(detail.value || {}, null, 2)
}

const openRowAction = (action: OperationAction, row: any) => {
  if (action.route) return
  if (isActionDisabled(action, row)) return

  confirm.open = true
  confirm.action = action
  confirm.row = row
  confirm.related = null
  confirm.title = action.label
  confirm.message = `Confirm ${action.label.toLowerCase()} for ${row.__id || 'selected record'}.`
  actionError.value = null
}

const actionRoute = (action: OperationAction, row: any) => interpolate(action.route || '', row)

const openDetailAction = (action: OperationAction) => {
  const row = { ...(detail.value || {}), __id: recordId.value }
  const nextAction = rowSpecificAction(action, row)

  if (nextAction.route) {
    if (nextAction.target === '_blank' && import.meta.client) {
      window.open(actionRoute(nextAction, row), '_blank', 'noopener')
      return
    }

    navigateTo(actionRoute(nextAction, row))
    return
  }

  openRowAction(nextAction, row)
}

const openCollectionAction = (action: OperationAction) => {
  if (action.disabled) {
    return
  }

  if (action.route) {
    const route = actionRoute(action, buildCollectionContext())
    if (action.target === '_blank' && import.meta.client) {
      window.open(route, '_blank', 'noopener')
      return
    }

    navigateTo(route)
    return
  }

  confirm.open = true
  confirm.action = action
  confirm.row = buildCollectionContext()
  confirm.related = null
  confirm.title = action.label
  confirm.message = `Confirm ${action.label.toLowerCase()} for ${resource.value?.title || 'this page'}.`
  actionError.value = null
}

const openRelatedCollectionAction = (related: OperationRelatedList, action: OperationAction) => {
  confirm.open = true
  confirm.action = action
  confirm.row = null
  confirm.related = related
  confirm.title = action.label
  confirm.message = `Confirm ${action.label.toLowerCase()} for ${related.title}.`
  actionError.value = null
}

const openRelatedRowAction = (related: OperationRelatedList, action: OperationAction, row: any) => {
  confirm.open = true
  confirm.action = action
  confirm.row = row
  confirm.related = related
  confirm.title = action.label
  confirm.message = `Confirm ${action.label.toLowerCase()} for ${row.__id || 'selected related record'}.`
  actionError.value = null
}

const openStockNumberDetail = (row: any) => {
  const source = row.__raw || row
  const partnerScopeId = String(source.partner_id || filters.value.scope_id || filters.value.partner_id || '')
  stockNumberDetail.open = true
  stockNumberDetail.title = `Number ${source.full_number || row.full_number || '-'}`
  stockNumberDetail.error = null
  stockNumberDetail.record = null
  stockNumberDetail.gameId = String(source.game_id || row.game_id || '')
  stockNumberDetail.fullNumber = String(source.full_number || row.full_number || source.number || row.number || '')
  stockNumberDetail.scopeType = partnerScopeId ? 'partner' : 'central'
  stockNumberDetail.scopeId = partnerScopeId || 'central'
  void loadStockNumberDetail()
}

const openStockTickets = (row: any) => {
  openStockNumberDetail(row)
}

const handleStockNumberScopeChange = () => {
  stockNumberDetail.scopeId = stockNumberDetail.scopeType === 'partner' ? '' : 'central'
  stockNumberDetail.record = null
  stockNumberDetail.error = null
  if (stockNumberDetail.scopeType === 'central') {
    void loadStockNumberDetail()
  }
}

const loadStockNumberDetail = async () => {
  if (!stockNumberDetail.gameId || !stockNumberDetail.fullNumber) {
    return
  }

  if (stockNumberDetail.scopeType === 'partner' && !stockNumberDetail.scopeId) {
    stockNumberDetail.error = {
      status: 422,
      message: 'The request payload is invalid.',
      details: { fields: { scope_id: ['Enter a partner ID to load partner effective limits.'] } },
    }
    return
  }

  stockNumberDetail.loading = true
  stockNumberDetail.error = null
  try {
    const endpoint = `/admin/central/stock/${encodeURIComponent(stockNumberDetail.gameId)}/numbers/${encodeURIComponent(stockNumberDetail.fullNumber)}`
    const response = await api.apiFetch(endpoint, apiOptions({
      query: cleanQuery({
        scope_type: stockNumberDetail.scopeType,
        scope_id: stockNumberDetail.scopeType === 'partner' ? stockNumberDetail.scopeId : undefined,
      }),
    }))
    stockNumberDetail.record = extractData(response)
  } catch (err) {
    stockNumberDetail.error = err
  } finally {
    stockNumberDetail.loading = false
  }
}

const handleStockCoverageSettingsSaved = (record: Record<string, any>) => {
  detail.value = record
  settingsDraft.value = JSON.stringify(record || {}, null, 2)
}

const handlePartnerDetailSaved = (record: Record<string, any>) => {
  detail.value = record
  detailDraft.value = JSON.stringify(record || {}, null, 2)
}

const openStockTicketAction = (action: OperationAction, row: any) => {
  stockTickets.open = false
  openRowAction(action, row)
}

const loadStockTickets = async (cursor?: string | null, pageMode: 'reset' | 'next' | 'previous' | 'current' = 'reset') => {
  if (!resource.value?.listEndpoint || !stockTickets.gameId || !stockTickets.fullNumber) {
    return
  }

  stockTickets.loading = true
  stockTickets.error = null
  try {
    const response = await api.apiFetch(resource.value.listEndpoint, apiOptions({
      query: cleanQuery({
        game_id: stockTickets.gameId,
        full_number: stockTickets.fullNumber,
        status: stockTickets.status,
        grouped: false,
        cursor: cursor || undefined,
        limit: stockTickets.limit,
        sort_by: stockTickets.sortKey || undefined,
        sort_dir: stockTickets.sortKey ? stockTickets.sortDirection : undefined,
      }),
    }))
    stockTickets.rows = normalizeRows(response, {
      ...resource.value,
      columns: stockTicketColumns,
      idKey: 'id',
    })
    const nextMeta = extractMeta(response)
    stockTickets.meta.next_cursor = nextMeta.next_cursor || null
    stockTickets.meta.has_more = Boolean(nextMeta.has_more || nextMeta.next_cursor)
    updatePageState(stockTickets.pageState, cursor || null, pageMode)
  } catch (err) {
    stockTickets.error = err
  } finally {
    stockTickets.loading = false
  }
}

const loadNextStockTicketPage = () => {
  if (!stockTickets.meta.next_cursor) return
  loadStockTickets(stockTickets.meta.next_cursor, 'next')
}

const loadPreviousStockTicketPage = () => {
  if (stockTickets.pageState.index <= 0) return
  loadStockTickets(stockTickets.pageState.cursors[stockTickets.pageState.index - 1] || null, 'previous')
}

const applyStockTicketSort = (next: { key: string, direction: 'asc' | 'desc' }) => {
  stockTickets.sortKey = next.key
  stockTickets.sortDirection = next.direction
  loadStockTickets(null, 'reset')
}

const openRelatedDetail = async (related: OperationRelatedList, row: any) => {
  if (!related.detailEndpoint) return
  relatedDetail.open = true
  relatedDetail.title = `${related.title} detail`
  relatedDetail.loading = true
  relatedDetail.error = null
  relatedDetail.record = null
  relatedDetail.renderer = related.detailRenderer || ''
  relatedDetail.detailFields = related.detailFields || []
  try {
    const response = await api.apiFetch(interpolate(related.detailEndpoint, row.__id), apiOptions())
    relatedDetail.record = extractData(response)
  } catch (err) {
    relatedDetail.error = err
  } finally {
    relatedDetail.loading = false
  }
}

const runConfirmedAction = async (reason: string, payloadJson = '', formValues: Record<string, any> = {}) => {
  if (!confirm.action?.endpoint || !resource.value) return
  saving.value = true
  actionError.value = null
  try {
    const action = confirm.action
    const id = confirm.row?.__id || recordId.value
    const endpoint = interpolate(action.endpoint, id)
    const body = buildActionBody(action, reason, payloadJson, formValues)
    const response = await api.apiFetch(endpoint, apiOptions({
      method: action.method || 'POST',
      body,
      idempotencyKey: api.idempotencyKey(),
    }))
    if (isStockGenerateAction(action)) {
      const batch = stockGenerationBatchFromResponse(response)
      stockGenerationSubmittedBatch.value = batch
      stockGenerationHasActiveBatch.value = isActiveStockGenerationBatch(batch)
      stockGenerationProgressRefreshKey.value += 1
    }
    confirm.open = false
    await load()
    if (showAllocationSummaryWidgets.value) {
      await refreshAllocationGameOptions()
    }
    refreshStockSummaryWidgets()
  } catch (err) {
    actionError.value = err
  } finally {
    saving.value = false
  }
}

const handleStockGenerationActiveChange = (active: boolean) => {
  stockGenerationHasActiveBatch.value = active
}

const handleStockGenerationProgress = (batch: any) => {
  if (!batch) {
    return
  }

  stockGenerationHasActiveBatch.value = isActiveStockGenerationBatch(batch)
  refreshStockSummaryWidgets()
}

function handleStockTableRealtimeEvent(payload: StockTableRealtimePayload) {
  if (!stockTableRealtimeEnabled.value || !payload || typeof payload !== 'object') {
    return
  }

  const payloadGameId = String(payload.game_id || payload.row?.game_id || '').trim()
  if (payloadGameId !== selectedStockTableGameId.value) {
    return
  }

  if (payload.refresh_required) {
    void reloadStockTableFromRealtime()
    return
  }

  const row = payload.row
  if (!isSafeStockTableRealtimeRow(row) || stockTableRealtimeRowRequiresReload(row)) {
    void reloadStockTableFromRealtime()
    return
  }

  if (!mergeStockTableRealtimeRow(row, payload)) {
    void reloadStockTableFromRealtime()
    return
  }

  refreshStockSummaryWidgets()
}

function handleStockTableRealtimeReconnect() {
  if (!stockTableRealtimeEnabled.value) {
    return
  }

  void reloadStockTableFromRealtime()
}

function handleTenantStockRealtimeEvent(payload: any) {
  if (!tenantStockRealtimeEnabled.value || !payload || typeof payload !== 'object') {
    return
  }

  const payloadGameId = String(payload.game_id || '').trim()
  const payloadTenantId = String(payload.tenant_id || '').trim()
  if (payloadGameId !== selectedTenantStockGameId.value || (payloadTenantId && payloadTenantId !== String(session.currentTenantId.value || ''))) {
    return
  }

  void reloadTenantStockFromRealtime()
}

function handleTenantStockRealtimeReconnect() {
  if (!tenantStockRealtimeEnabled.value) {
    return
  }

  void reloadTenantStockFromRealtime()
}

function handleTenantTopupRealtimeEvent(payload: any) {
  if (!tenantTopupsRealtimeEnabled.value || !payload || typeof payload !== 'object') {
    return
  }

  const row = payload.topup || payload.row || payload
  const payloadTenantId = String(payload.tenant_id || row?.tenant_id || '').trim()
  if (payloadTenantId && payloadTenantId !== String(session.currentTenantId.value || '')) {
    return
  }

  const topupId = String(row?.id || payload.topup_id || '').trim()
  if (!topupId) {
    return
  }

  for (const section of activeRelatedLists.value) {
    if (!String(section.listEndpoint || '').includes('/topups')) {
      continue
    }

    if (topupBelongsToSection(section, row) && topupMatchesSectionFilters(section, row)) {
      upsertRelatedRow(section, row)
    } else {
      removeRelatedRow(section.key, topupId)
    }
  }
}

async function reloadStockTableFromRealtime() {
  if (!stockTableRealtimeEnabled.value || stockTableRealtimeReloading.value) {
    return
  }

  stockTableRealtimeReloading.value = true
  try {
    await load(pageState.cursors[pageState.index] || null, 'current')
    refreshStockSummaryWidgets()
  } finally {
    stockTableRealtimeReloading.value = false
  }
}

async function reloadTenantStockFromRealtime() {
  if (!tenantStockRealtimeEnabled.value || tenantStockRealtimeReloading.value) {
    return
  }

  tenantStockRealtimeReloading.value = true
  try {
    await load(pageState.cursors[pageState.index] || null, 'current', { silent: true })
    tenantStockCoverageRefreshKey.value += 1
  } finally {
    tenantStockRealtimeReloading.value = false
  }
}

function refreshStockSummaryWidgets() {
  if (showStockSummaryWidgets.value) {
    stockSummaryRefreshKey.value += 1
  }
}

function isSafeStockTableRealtimeRow(row: any) {
  return Boolean(
    row
    && typeof row === 'object'
    && !isBlank(row.game_id)
    && !isBlank(row.full_number)
    && stockTableRealtimeCountKeys.every((key) => Number.isFinite(Number(row[key]))),
  )
}

function stockTableRealtimeRowRequiresReload(row: Record<string, any>) {
  const rowGameId = String(row.game_id || '').trim()
  return Boolean(
    rowGameId !== selectedStockTableGameId.value
    || stockTableRealtimeHasUncertainFilters()
    || stockTableRealtimeHasUncertainSort()
    || stockTableRealtimeHasUncertainPage(),
  )
}

function stockTableRealtimeHasUncertainFilters() {
  return Object.keys(cleanQuery(filters.value))
    .some((key) => !stockTableRealtimeFilterKeysAllowedForMerge.has(key))
}

function stockTableRealtimeHasUncertainSort() {
  return Boolean(sortState.key)
}

function stockTableRealtimeHasUncertainPage() {
  return pageState.index > 0 || !isBlank(filters.value.cursor)
}

function mergeStockTableRealtimeRow(row: Record<string, any>, payload: StockTableRealtimePayload) {
  if (!resource.value) {
    return false
  }

  const fullNumber = String(row.full_number || '').trim()
  const rowGameId = String(row.game_id || payload.game_id || '').trim()
  const index = rows.value.findIndex((entry) => {
    const source = entry.__raw || entry
    const sourceFullNumber = String(source.full_number || entry.full_number || '').trim()
    const sourceGameId = String(source.game_id || entry.game_id || '').trim()
    return sourceFullNumber === fullNumber && sourceGameId === rowGameId
  })

  if (index < 0) {
    return false
  }

  const currentDisplay = rows.value[index]
  const currentRaw = currentDisplay.__raw || currentDisplay
  const nextRaw = {
    ...currentRaw,
    game_id: row.game_id ?? payload.game_id ?? currentRaw.game_id,
    full_number: row.full_number ?? currentRaw.full_number,
  }

  for (const key of stockTableRealtimeMergeFields) {
    if (row[key] !== undefined) {
      nextRaw[key] = row[key]
    }
  }

  if (row.updated_at === undefined && payload.updated_at) {
    nextRaw.updated_at = payload.updated_at
  }
  if (row.last_updated_at === undefined && row.updated_at !== undefined) {
    nextRaw.last_updated_at = row.updated_at
  }
  if (row.last_updated_at === undefined && row.updated_at === undefined && payload.updated_at) {
    nextRaw.last_updated_at = payload.updated_at
  }

  const normalized = normalizeRows([nextRaw], resource.value)[0] || {}
  const nextDisplay = {
    ...currentDisplay,
    ...normalized,
    __raw: nextRaw,
    __id: currentDisplay.__id || normalized.__id,
  }
  rows.value = rows.value.map((entry, rowIndex) => rowIndex === index ? nextDisplay : entry)
  return true
}

const loadRelatedLists = async () => {
  const lists = activeRelatedLists.value
  if (!lists.length) return

  await Promise.all(lists.map((related) => loadRelatedList(related)))
}

const loadRelatedList = async (related: OperationRelatedList, cursor?: string | null, pageMode: 'reset' | 'next' | 'previous' | 'current' = 'reset') => {
  relatedLoading[related.key] = true
  relatedErrors[related.key] = null
  try {
    const pageCursor = cursor || null
    const endpoint = interpolate(related.listEndpoint, recordId.value)
    const relatedQuery = cleanQuery({
      ...interpolateQuery(related.defaultQuery || {}, recordId.value),
      ...ensureRelatedFilters(related),
      cursor: pageCursor || relatedFilters[related.key]?.cursor || undefined,
      sort_by: related.apiSort && relatedSortState[related.key]?.key ? relatedSortState[related.key].key : undefined,
      sort_dir: related.apiSort && relatedSortState[related.key]?.key ? relatedSortState[related.key].direction : undefined,
    })

    if (!relatedQuery.limit) {
      relatedQuery.limit = 20
    }

    const response = await api.apiFetch(endpoint, apiOptions({ query: relatedQuery }))
    const nextRows = normalizeRows(response, {
      scope: resource.value?.scope || props.scope,
      slug: related.key,
      title: related.title,
      group: resource.value?.group || '',
      idParam: related.idParam,
      idKey: related.idKey || 'id',
      columns: related.columns,
    })
    relatedRows[related.key] = nextRows
    const nextMeta = extractMeta(response)
    relatedMeta[related.key] = {
      next_cursor: nextMeta.next_cursor || null,
      has_more: Boolean(nextMeta.has_more || nextMeta.next_cursor),
    }
    updatePageState(ensureRelatedPageState(related.key), pageCursor, pageMode)
  } catch (err) {
    relatedErrors[related.key] = err
    relatedRows[related.key] = []
    relatedMeta[related.key] = { next_cursor: null, has_more: false }
  } finally {
    relatedLoading[related.key] = false
  }
}

function topupBelongsToSection(section: OperationRelatedList, row: any) {
  const status = String((row?.__raw || row)?.status || '').toLowerCase()
  const pending = ['pending', 'processing', 'pending_review', 'pending_payment'].includes(status)
  const sectionName = String(section.defaultQuery?.section || '').toLowerCase()

  if (sectionName === 'pending') {
    return pending
  }

  if (sectionName === 'history') {
    return !pending
  }

  return true
}

function topupMatchesSectionFilters(section: OperationRelatedList, row: any) {
  const filtersForSection = cleanQuery(relatedFilters[section.key] || {})
  const source = row?.__raw || row || {}
  const status = String(source.status || '').toLowerCase()
  const channel = String(source.channel || '').toLowerCase()
  const customerNo = String(getPath(source, 'customer.customer_no') || source.customer_no || source.member_no || '').toUpperCase()

  if (filtersForSection.status && status !== String(filtersForSection.status).toLowerCase()) {
    return false
  }

  if (filtersForSection.channel && channel !== String(filtersForSection.channel).toLowerCase()) {
    return false
  }

  if (filtersForSection.customer_no && !customerNo.includes(String(filtersForSection.customer_no).toUpperCase())) {
    return false
  }

  return true
}

function upsertRelatedRow(section: OperationRelatedList, row: any) {
  const normalized = normalizeRows({ data: [row] }, relatedResource(section))[0]
  if (!normalized?.__id) {
    return
  }

  const currentRows = relatedRows[section.key] || []
  const existingIndex = currentRows.findIndex((entry) => String(entry.__id) === String(normalized.__id))
  if (existingIndex < 0 && ((relatedPageState[section.key]?.index || 0) > 0 || !isBlank(relatedFilters[section.key]?.cursor))) {
    return
  }

  const nextRows = [...currentRows]
  if (existingIndex >= 0) {
    nextRows[existingIndex] = { ...nextRows[existingIndex], ...normalized }
  } else {
    nextRows.unshift(normalized)
  }

  const limit = Number(relatedFilters[section.key]?.limit || 20)
  relatedRows[section.key] = sortRelatedRows(section, nextRows).slice(0, Number.isFinite(limit) && limit > 0 ? limit : 20)
}

function removeRelatedRow(sectionKey: string, rowId: string) {
  relatedRows[sectionKey] = (relatedRows[sectionKey] || []).filter((entry) => String(entry.__id) !== rowId)
}

function sortRelatedRows(section: OperationRelatedList, nextRows: any[]) {
  const sortKey = relatedSortState[section.key]?.key || section.defaultSort?.key || ''
  if (!sortKey) {
    return nextRows
  }

  const direction = relatedSortState[section.key]?.direction || section.defaultSort?.direction || 'asc'
  return sortRows(nextRows, sortKey, direction)
}

function sortRows(nextRows: any[], sortKey: string, direction: 'asc' | 'desc' = 'asc') {
  if (!sortKey) {
    return nextRows
  }

  const multiplier = direction === 'desc' ? -1 : 1

  return [...nextRows].sort((left, right) => compareSortValues(sortValue(left, sortKey), sortValue(right, sortKey)) * multiplier)
}

function sortValue(row: any, key: string) {
  const source = row?.__raw || row || {}
  const value = getFirstPath(source, [key, `${key}.amount`])

  if (value && typeof value === 'object' && 'amount' in value) {
    return Number(value.amount)
  }

  return value
}

function compareSortValues(left: any, right: any) {
  const leftDate = Date.parse(String(left || ''))
  const rightDate = Date.parse(String(right || ''))
  if (!Number.isNaN(leftDate) && !Number.isNaN(rightDate)) {
    return leftDate - rightDate
  }

  const leftNumber = Number(left)
  const rightNumber = Number(right)
  if (Number.isFinite(leftNumber) && Number.isFinite(rightNumber)) {
    return leftNumber - rightNumber
  }

  return String(left ?? '').localeCompare(String(right ?? ''), 'th')
}

function relatedResource(related: OperationRelatedList): OperationResource {
  return {
    scope: resource.value?.scope || props.scope,
    slug: related.key,
    title: related.title,
    group: resource.value?.group || '',
    idParam: related.idParam,
    idKey: related.idKey || 'id',
    columns: related.columns,
  }
}

const hasRelatedRowActions = (related: OperationRelatedList) => Boolean(
  related.detailEndpoint || related.actions?.length
)

const relatedRowActionsForRow = (related: OperationRelatedList, row: any) => hydrateActions(related.actions || [])
  .map((action) => rowSpecificAction(action, row))
  .filter((action) => !action.hideWhenDisabled || !isActionDisabled(action, row))

const loadNextRelatedPage = (related: OperationRelatedList) => {
  const nextCursor = relatedMeta[related.key]?.next_cursor || null
  if (!nextCursor) return
  loadRelatedList(related, nextCursor, 'next')
}

const loadPreviousRelatedPage = (related: OperationRelatedList) => {
  const state = ensureRelatedPageState(related.key)
  if (state.index <= 0) return
  loadRelatedList(related, state.cursors[state.index - 1] || null, 'previous')
}

const buildActionBody = (action: OperationAction, reason: string, payloadJson: string, formValues: Record<string, any>) => {
  let payload: Record<string, any> = {}

  if (action.formFields?.length) {
    payload = buildPayloadFromFields(action.formFields, formValues)
    if (isStockGenerateAction(action)) {
      payload = normalizeStockGenerationPayload(payload)
    }
  } else if (action.payloadTemplate) {
    const payload = JSON.parse(payloadJson || '{}')
    return action.reason ? compactPayload({ ...payload, reason }) : compactPayload(payload)
  }

  if (action.reason) {
    payload.reason = reason
  }

  const compacted = compactPayload(payload)
  return Object.keys(compacted).length ? compacted : undefined
}

const buildPayloadFromFields = (fields: OperationFormField[], values: Record<string, any>) => {
  const payload: Record<string, any> = {}

  for (const field of fields) {
    if (field.type === 'datetime-range') {
      const rangeValue = values[field.key]
      const startValue = normalizePayloadField(
        { ...field, type: 'datetime-local' },
        values[rangeStartFormKey(field)] ?? rangeValue?.start,
      )
      const endValue = normalizePayloadField(
        { ...field, type: 'datetime-local' },
        values[rangeEndFormKey(field)] ?? rangeValue?.end,
      )

      if (startValue !== undefined) {
        setPath(payload, field.rangeStartKey || `${field.key}.start`, startValue)
      }
      if (endValue !== undefined) {
        setPath(payload, field.rangeEndKey || `${field.key}.end`, endValue)
      }
      continue
    }

    const value = normalizePayloadField(field, values[field.key])
    if (value === undefined) continue
    setPath(payload, field.key, value)
  }

  return compactPayload(payload)
}

const normalizeStockGenerationPayload = (payload: Record<string, any>) => {
  const next = { ...payload, generation_mode: 'virtual_profile' }
  delete next.seed
  delete next.total_count
  delete next.back2_count_per_number
  delete next.back3_count_per_number
  delete next.front3_count_per_number
  delete next.start_number
  delete next.count
  delete next.number_digits
  delete next.central_limits
  delete next.partner_limits

  return next
}

const normalizePayloadField = (field: OperationFormField, value: any) => {
  if (field.type === 'checkbox') {
    return Boolean(value)
  }

  if (field.submitAsArray) {
    if (value === '' || value === undefined || value === null) {
      return field.emptyValue === 'array' ? [] : undefined
    }

    const values = Array.isArray(value) ? value : [value]
    const normalized = values
      .map((entry) => String(entry || '').trim())
      .filter(Boolean)

    if (!normalized.length) {
      return field.emptyValue === 'array' ? [] : undefined
    }

    return normalized
  }

  if (field.type === 'checkbox-group') {
    const values = Array.isArray(value) ? value : []
    const normalized = values
      .map((entry) => String(entry || '').trim())
      .filter(Boolean)

    return normalized.length || field.emptyValue === 'array' ? normalized : undefined
  }

  if (field.type === 'money') {
    if (value === '' || value === undefined || value === null) return undefined
    return Math.round(Number(value) * 100)
  }

  if (field.type === 'number') {
    if (value === '' || value === undefined || value === null) return undefined
    return Number(value)
  }

  if (field.type === 'json') {
    if (value === '' || value === undefined || value === null) return undefined

    const parsed = typeof value === 'string' ? JSON.parse(value) : value
    if (parsed !== null && typeof parsed === 'object') {
      return parsed
    }

    throw new Error(`${field.label} must be a JSON object or array.`)
  }

  if (field.type === 'stock-set-distribution') {
    const rows = Array.isArray(value) ? value : []
    return rows
      .map((row) => ({
        set_size: Number(row?.set_size),
        percent: Number(row?.percent),
      }))
      .filter((row) => Number.isFinite(row.set_size) && Number.isFinite(row.percent) && row.percent > 0)
  }

  if (field.type === 'stock-sale-limits') {
    return compactPayload({
      back2_limit: normalizeOptionalNumber(value?.back2_limit),
      back3_limit: normalizeOptionalNumber(value?.back3_limit),
      front3_limit: normalizeOptionalNumber(value?.front3_limit),
    })
  }

  if (field.type === 'stock-partner-distribution') {
    const rows = Array.isArray(value) ? value : []
    return rows
      .map((row) => ({
        partner_id: String(row?.partner_id || '').trim(),
        percent: Number(row?.percent),
      }))
      .filter((row) => row.partner_id && Number.isFinite(row.percent) && row.percent > 0)
  }

  if (field.type === 'stock-partner-limits') {
    const rows = Array.isArray(value) ? value : []
    return rows
      .map((row) => compactPayload({
        partner_id: String(row?.partner_id || '').trim(),
        back2_limit: normalizeOptionalNumber(row?.back2_limit),
        back3_limit: normalizeOptionalNumber(row?.back3_limit),
        front3_limit: normalizeOptionalNumber(row?.front3_limit),
      }))
      .filter((row) => row.partner_id && (
        row.back2_limit !== undefined
        || row.back3_limit !== undefined
        || row.front3_limit !== undefined
      ))
  }

  if (field.type === 'lines') {
    const lines = String(value || '')
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean)
    if (!lines.length) return field.emptyValue === 'array' ? [] : undefined
    return field.itemKey ? lines.map((line) => ({ [field.itemKey || 'value']: line })) : lines
  }

  if (field.type === 'prize-lines') {
    const prizes = normalizePrizeLines(value)
    return prizes.length ? prizes : undefined
  }

  if (field.type === 'reward-prize-number-grid') {
    if (field.key === 'prizes') {
      const prizes = rewardPrizeGroupsToPayload(value || [])
      return prizes.length ? prizes : undefined
    }

    const updates = rewardPrizeGroupsToNumberUpdates(value || [])
    return updates.length ? updates : undefined
  }

  if (field.type === 'reward-prize-amount-grid') {
    const updates = rewardPrizeGroupsToPayoutUpdates(value || [])
    return updates.length ? updates : undefined
  }

  if (field.type === 'reward-prize-grid') {
    const prizes = rewardPrizeGroupsToPayload(value || [])
    return prizes.length ? prizes : undefined
  }

  if (value === '' || value === undefined || value === null) {
    if (field.emptyValue === 'string') {
      return ''
    }
    return undefined
  }

  return value
}

const normalizeOptionalNumber = (value: any) => {
  if (value === '' || value === undefined || value === null) {
    return undefined
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : undefined
}

const addStockSetDistributionRow = (field: OperationFormField) => {
  const rows = Array.isArray(settingsForm[field.key]) ? settingsForm[field.key] : []
  rows.push({
    __key: stockSetRowKey(1, rows.length),
    set_size: 1,
    percent: '',
  })
  settingsForm[field.key] = rows
}

const removeStockSetDistributionRow = (field: OperationFormField, index: number) => {
  const rows = Array.isArray(settingsForm[field.key]) ? settingsForm[field.key] : []
  rows.splice(index, 1)
  settingsForm[field.key] = rows.length ? rows : [{
    __key: stockSetRowKey(2, 0),
    set_size: 2,
    percent: '',
  }]
}

const normalizeStockSetDistribution = (value: any, field: OperationFormField) => {
  const source = Array.isArray(value) && value.length ? value : Array.isArray(field.defaultValue) ? field.defaultValue : []
  const rows = source
    .map((row: any, index: number) => ({
      __key: row?.__key || stockSetRowKey(row?.set_size ?? row?.size ?? 1, index),
      set_size: Number(row?.set_size ?? row?.size ?? 1),
      percent: numberOrBlank(row?.percent ?? basisPointsToPercent(row?.percent_basis_points)),
    }))
    .filter((row: any) => Number.isFinite(row.set_size))

  return rows.length ? rows : [
    { __key: stockSetRowKey(2, 0), set_size: 2, percent: 10 },
    { __key: stockSetRowKey(3, 1), set_size: 3, percent: 15 },
  ]
}

const stockSetRowKey = (setSize: any, index: number) => `set-${Number(setSize) || 1}-${index}-${Date.now()}`

const basisPointsToPercent = (value: any) => {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed / 100 : ''
}

const numberOrBlank = (value: any) => {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : ''
}

const normalizeInitialFieldValue = (field: OperationFormField, value: any) => {
  if (field.type === 'checkbox') {
    return Boolean(value)
  }

  if (field.type === 'datetime-local') {
    return formatDateTimeLocalValue(value)
  }

  if (field.type === 'json') {
    return formatJsonFieldValue(value)
  }

  if (field.type === 'money') {
    return minorUnitToMajor(value)
  }

  if (field.type === 'stock-set-distribution') {
    return normalizeStockSetDistribution(value, field)
  }

  if (field.type === 'lines') {
    return formatLines(value, field.valueKey || field.itemKey)
  }

  if (field.type === 'prize-lines') {
    return formatPrizeLines(value)
  }

  if (
    field.type === 'reward-prize-grid'
    || field.type === 'reward-prize-number-grid'
    || field.type === 'reward-prize-amount-grid'
  ) {
    return normalizeRewardPrizeGroups(value)
  }

  if (value === undefined || value === null || typeof value === 'object') {
    return ''
  }

  return value
}

const rangeStartFormKey = (field: OperationFormField) => `${field.key}.__start`
const rangeEndFormKey = (field: OperationFormField) => `${field.key}.__end`

const setPath = (target: Record<string, any>, path: string, value: any) => {
  const keys = path.split('.')
  let current = target
  keys.forEach((key, index) => {
    if (index === keys.length - 1) {
      current[key] = value
      return
    }

    current[key] = typeof current[key] === 'object' && current[key] !== null ? current[key] : {}
    current = current[key]
  })
}

const compactPayload = (value: any): any => {
  if (Array.isArray(value)) {
    return value
      .map((entry) => compactPayload(entry))
      .filter((entry) => entry !== undefined)
  }

  if (value && typeof value === 'object') {
    const compacted = Object.fromEntries(Object.entries(value)
      .map(([key, entry]) => [key, compactPayload(entry)])
      .filter(([, entry]) => entry !== undefined && entry !== null && entry !== ''))

    if ('currency' in compacted && !('amount' in compacted) && Object.keys(compacted).length === 1) {
      return undefined
    }

    return compacted
  }

  return value
}

const apiOptions = (extra: Record<string, any> = {}) => ({
  scope: props.scope,
  tenantId: props.scope === 'tenant' ? session.currentTenantId.value : undefined,
  ...extra,
})

const queryWithCursor = (cursor?: string | null) => ({
  ...(resource.value?.defaultQuery || {}),
  ...cleanQuery(filters.value),
  cursor: cursor || filters.value.cursor || undefined,
  sort_by: resource.value?.apiSort && sortState.key ? sortState.key : undefined,
  sort_dir: resource.value?.apiSort && sortState.key ? sortState.direction : undefined,
})

const defaultFilterValues = (filterList: OperationFilter[] = []) => {
  const next: Record<string, any> = {}
  for (const filter of filterList) {
    next[filter.key] = filter.key === 'limit' ? 20 : ''
  }
  return next
}

const routeFilterValues = (filterList: OperationFilter[] = []) => {
  const filterKeys = new Set(filterList.map((filter) => filter.key))
  const next: Record<string, any> = {}
  for (const key of filterKeys) {
    const value = route.query[key]
    if (Array.isArray(value)) {
      next[key] = value[0] ?? ''
    } else if (value !== undefined && value !== null) {
      next[key] = String(value)
    }
  }
  return next
}

const resetRelatedFilters = () => {
  for (const key of Object.keys(relatedFilters)) {
    delete relatedFilters[key]
  }
  for (const key of Object.keys(relatedMeta)) {
    delete relatedMeta[key]
  }
  for (const key of Object.keys(relatedPageState)) {
    delete relatedPageState[key]
  }
  for (const key of Object.keys(relatedSortState)) {
    delete relatedSortState[key]
  }
  for (const related of activeRelatedLists.value) {
    const next = related.apiSort ? related.defaultSort : null
    if (next) {
      relatedSortState[related.key] = { key: next.key, direction: next.direction }
    }
  }
}

const ensureRelatedFilters = (related: OperationRelatedList) => {
  if (!relatedFilters[related.key]) {
    relatedFilters[related.key] = defaultFilterValues(related.filters || [])
  }

  return relatedFilters[related.key]
}

const cleanQuery = (value: Record<string, any>) => Object.fromEntries(Object.entries(value)
  .filter(([, entry]) => entry !== '' && entry !== undefined && entry !== null))
const isBlank = (value: any) => value === undefined || value === null || String(value).trim() === ''

const buildCollectionContext = () => {
  const currentFilters = cleanQuery(filters.value)
  const reportKey = mode.value === 'report-detail' ? recordId.value : null
  return {
    __raw: {
      scope: props.scope,
      resource: resource.value?.title,
      report_key: reportKey,
      tenant_id: currentFilters.tenant_id || (props.scope === 'tenant' ? session.currentTenantId.value : undefined),
      date_from: currentFilters.date_from,
      date_to: currentFilters.date_to,
      group_by: currentFilters.group_by,
      filters: currentFilters,
      live_settings: listMeta.value.live_settings,
    },
  }
}

const interpolate = (endpoint: string, idOrRecord?: string | null | Record<string, any>) => endpoint.replace(/\{([^}]+)\}/g, (_match, key) => {
  if (typeof idOrRecord === 'object' && idOrRecord !== null) {
    const source = idOrRecord.__raw || idOrRecord
    const value = key === 'id' ? (idOrRecord.__id || source.id) : getPath(source, key) ?? idOrRecord[key]
    return encodeURIComponent(value === undefined || value === null ? '' : String(value))
  }

  return encodeURIComponent(idOrRecord || '')
})

const interpolateQuery = (query: Record<string, any>, idOrRecord?: string | null | Record<string, any>) => {
  const next: Record<string, any> = {}

  for (const [key, value] of Object.entries(query)) {
    next[key] = typeof value === 'string' ? interpolate(value, idOrRecord) : value
  }

  return next
}

function normalizeSlug(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String)
  if (typeof value === 'string') return [value]
  return []
}

const extractData = (response: any) => response?.data ?? response

const extractItems = (response: any) => {
  if (Array.isArray(response)) return response
  if (Array.isArray(response?.data)) return response.data
  if (Array.isArray(response?.data?.items)) return response.data.items
  if (Array.isArray(response?.items)) return response.items
  return []
}

const extractMeta = (response: any) => response?.meta || response?.data?.meta || {}

const updatePageState = (state: { cursors: Array<string | null>, index: number }, cursor: string | null, mode: 'reset' | 'next' | 'previous' | 'current') => {
  if (mode === 'reset') {
    state.cursors = [cursor]
    state.index = 0
    return
  }

  if (mode === 'next') {
    state.cursors = [...state.cursors.slice(0, state.index + 1), cursor]
    state.index += 1
    return
  }

  if (mode === 'previous') {
    state.index = Math.max(0, state.index - 1)
  }
}

const ensureRelatedPageState = (key: string) => {
  if (!relatedPageState[key]) {
    relatedPageState[key] = { cursors: [null], index: 0 }
  }

  return relatedPageState[key]
}

const normalizeRows = (response: any, item: OperationResource) => extractItems(response).map((row: any) => {
  const id = row?.[item.idKey || 'id'] || row?.id || row?.uuid
  const display: Record<string, any> = { ...row, __raw: row, __id: id }
  for (const column of item.columns || []) {
    display[column.key] = formatValue(getFirstPath(row, [column.key, ...(column.fallbackKeys || [])]), column.type)
  }
  return display
})

const getPath = (value: any, path: string) => path.split('.').reduce((current, key) => current?.[key], value)

const getFirstPath = (value: any, paths: string[]) => {
  for (const path of paths) {
    const entry = getPath(value, path)
    if (entry !== undefined && entry !== null && entry !== '') {
      return entry
    }
  }
  return undefined
}

const fieldId = (key: string) => `admin-operation-${key.replace(/[^a-z0-9_-]/gi, '-')}`

const inputType = (field: OperationFormField) => {
  if (field.type === 'number' || field.type === 'money') return 'number'
  if (field.type === 'datetime-local') return 'datetime-local'
  if (field.type === 'date') return 'date'
  if (field.type === 'password') return 'password'
  if (field.type === 'color') return 'color'
  return 'text'
}

const formatValue = (value: any, type?: string) => {
  if (type === 'image') return value || null
  if (value === undefined || value === null || value === '') return '-'
  if (type === 'customer') return formatCustomerValue(value)
  if (type === 'customer_name') return formatCustomerNameValue(value)
  if (type === 'money') return formatMoney(value)
  return formatAdminValue(value, type, '')
}

const formattedCellValue = (row: Record<string, any>, column: OperationColumn) => {
  const value = row[column.key]
  return value === undefined || value === null || value === '' ? '-' : String(value)
}

const isActionDisabled = (action: OperationAction, row: any) => {
  if (action.disabled) {
    return true
  }

  if (!action.enabledStatuses?.length) {
    return false
  }

  const status = String((row?.__raw || row)?.status || row?.status || '').toLowerCase()
  return !action.enabledStatuses.map((entry) => entry.toLowerCase()).includes(status)
}

const actionDisabledReason = (action: OperationAction, row: any) => (
  isActionDisabled(action, row) ? action.disabledReason || 'This action is not available for the current row state.' : undefined
)

const rowActionsForRow = (row: any) => hydratedActions.value
  .map((action) => rowSpecificAction(action, row))
  .filter((action) => !action.hideWhenDisabled || !isActionDisabled(action, row))

const rowSpecificAction = (action: OperationAction, row: any): OperationAction => {
  if (resource.value?.scope === 'central' && resource.value.slug === 'partners' && action.key === 'provision' && partnerHasTenant(row)) {
    return {
      ...action,
      key: 'edit-tenant',
      label: 'Edit tenant info',
      route: '/admin/central/partners/{id}',
      endpoint: undefined,
      reason: false,
      optionalReason: false,
      formFields: [],
      variant: 'primary',
    }
  }

  return action
}

const partnerHasTenant = (row: any) => {
  const source = row?.__raw || row || {}
  return Boolean(source.tenant_id || source.primary_tenant_id || (Array.isArray(source.tenants) && source.tenants.length > 0))
}

const numberOrNull = (value: any) => {
  if (value === undefined || value === null || value === '') {
    return null
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

const formatCustomerValue = (value: any) => {
  if (value === undefined || value === null || value === '') return '-'
  if (typeof value !== 'object') return String(value)

  const id = value.customer_no || value.member_no || value.id || value.customer_id || value.member_id
  const name = value.display_name || value.name || value.full_name
  const contact = value.phone || value.email
  const parts = [name, contact, id].filter((part, index, all) => part && all.indexOf(part) === index)

  return parts.length ? parts.join(' | ') : formatAdminValue(value, 'object-summary')
}

const formatCustomerNameValue = (value: any) => {
  if (value === undefined || value === null || value === '') return '-'
  if (typeof value !== 'object') return String(value)

  return String(value.display_name || value.name || value.full_name || value.phone || value.email || value.id || '-')
}

const formatMoneyValue = (value: any) => {
  const amount = typeof value === 'object' && value !== null ? value.amount : value
  if (amount === undefined || amount === null || amount === '') return '-'

  const currency = typeof value === 'object' && value !== null && value.currency
    ? String(value.currency)
    : 'THB'
  const formatted = new Intl.NumberFormat('th-TH', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(amount || 0) / 100)

  return `${formatted} ${currency === 'THB' ? 'บาท' : currency}`
}

const minorUnitToMajor = (value: any) => {
  const amount = typeof value === 'object' && value !== null ? value.amount : value
  if (amount === undefined || amount === null || amount === '') {
    return ''
  }

  const parsed = Number(amount)
  return Number.isFinite(parsed) ? parsed / 100 : ''
}

const formatDateTimeLocalValue = (value: any) => {
  if (value === undefined || value === null || value === '') return ''

  const raw = String(value)
  const localMatch = raw.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/)
  if (localMatch) {
    return `${localMatch[1]}T${localMatch[2]}`
  }

  const date = new Date(raw)
  if (Number.isNaN(date.getTime())) {
    return raw
  }

  const pad = (entry: number) => String(entry).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

const formatJsonFieldValue = (value: any) => {
  if (value === undefined || value === null || value === '') {
    return ''
  }

  if (typeof value === 'string') {
    return value
  }

  return JSON.stringify(value, null, 2)
}

const normalizePrizeLines = (value: any) => String(value || '')
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean)
  .map((line) => {
    const [prizeType = '', prizeNumber = '', amount = '', currency = 'THB'] = line.split(',').map((part) => part.trim())
    return {
      prize_type: prizeType,
      prize_number: prizeNumber,
      amount: {
        amount: Number(amount || 0),
        currency: currency || 'THB',
      },
    }
  })
  .filter((prize) => prize.prize_type && prize.prize_number && Number.isFinite(prize.amount.amount))

const formatPrizeLines = (value: any) => {
  if (!Array.isArray(value)) {
    return ''
  }

  return value.map((prize) => [
    prize?.prize_type,
    prize?.prize_number,
    prize?.amount?.amount,
    prize?.amount?.currency || 'THB',
  ].filter((entry) => entry !== undefined && entry !== null && entry !== '').join(',')).join('\n')
}

const formatLines = (value: any, valueKey?: string) => {
  if (!Array.isArray(value)) {
    return value === undefined || value === null ? '' : String(value)
  }

  return value
    .map((entry) => {
      if (valueKey && entry && typeof entry === 'object') {
        return getPath(entry, valueKey)
      }

      if (entry && typeof entry === 'object') {
        return JSON.stringify(entry)
      }

      return entry
    })
    .filter((entry) => entry !== undefined && entry !== null && entry !== '')
    .join('\n')
}
</script>

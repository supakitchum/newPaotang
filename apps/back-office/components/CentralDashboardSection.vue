<template>
  <div>
    <AdminPageHeader :title="dashboardTitle" :breadcrumbs="['Admin', 'Central', 'Dashboard', sectionLabel]">
      <template #actions>
        <NuxtLink to="/admin/central/lottery-images" class="btn btn-light btn-wave">
          <i class="ri-image-2-line me-1" />
          Lottery Images
        </NuxtLink>
        <button class="btn btn-primary btn-wave" type="button" :disabled="loading" @click="load">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="ri-refresh-line me-1" />
          Refresh
        </button>
      </template>
    </AdminPageHeader>

    <AdminAlert v-if="error" :type="error.status === 403 ? 'warning' : 'danger'" :message="error.message" :details="error.details" />
    <AdminLoader v-if="loading && !summary" />

    <template v-else>
      <div class="np-dashboard-toolbar">
        <div class="np-dashboard-tabs">
          <NuxtLink
            v-for="item in dashboardSections"
            :key="item.key"
            :to="{ path: item.route, query: { period } }"
            :class="['np-dashboard-tab', { active: item.key === section }]"
          >
            <i :class="item.icon" />
            <span>{{ item.label }}</span>
          </NuxtLink>
        </div>
        <div class="np-dashboard-periods">
          <button
            v-for="option in periodOptions"
            :key="option.key"
            type="button"
            :class="['np-dashboard-period', { active: option.key === period }]"
            @click="setPeriod(option.key)"
          >
            {{ option.label }}
          </button>
        </div>
      </div>

      <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
        <div class="text-muted fs-12">
          {{ filterCaption }} · {{ dashboardPhrase('Generated') }} {{ formatDateTime(summary?.generated_at) }}
        </div>
        <div v-if="summary?.notes?.guest_sessions" class="text-muted fs-12">
          {{ summary.notes.guest_sessions }}
        </div>
      </div>

      <template v-if="section === 'sales'">
        <div class="np-sales-dashboard">
          <div class="row g-3">
            <div v-for="metric in salesKpis" :key="metric.key" class="col-xl-3 col-md-6">
              <div class="card custom-card overflow-hidden np-sales-kpi-card">
                <div class="card-body">
                  <div class="d-flex gap-3">
                    <span :class="['np-sales-kpi-avatar', toneClass(metric.tone)]">
                      <i :class="metric.icon" />
                    </span>
                    <div class="flex-fill min-w-0">
                      <div class="fw-medium fs-13 mb-1 text-dark np-sales-card-label">{{ salesMetricLabel(metric) }}</div>
                      <div :class="['fs-22 fw-semibold mb-1', salesMetricTextClass(metric.tone)]">
                        {{ salesMetricValue(metric) }}
                      </div>
                      <div class="d-flex align-items-center fs-11">
                        <span :class="['fw-semibold me-1', directionClass(metric.delta?.direction)]">
                          <i :class="metric.delta?.direction === 'down' ? 'ti ti-trending-down' : 'ti ti-trending-up'" class="me-1 fw-medium align-middle" />
                          {{ deltaPercentLabel(metric.delta) }}
                        </span>
                        <span class="text-default op-6">{{ periodLabel }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="col-12">
              <div class="card custom-card np-sales-chart-card">
                <div class="card-header">
                  <div class="card-title">Sales Revenue</div>
                </div>
                <div class="card-body">
                  <div v-if="!salesRevenueChartSeries.length" class="np-dashboard-empty">No trend data yet.</div>
                  <AdminApexChart
                    v-else
                    type="area"
                    :height="360"
                    :series="salesRevenueChartSeries"
                    :options="salesRevenueChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xl-6">
              <div class="card custom-card np-sales-donut-card h-100">
                <div class="card-header">
                  <div class="card-title mb-0 pb-0">Payment Method Mix</div>
                </div>
                <div class="card-body pb-0">
                  <div v-if="!salesBreakdownRows.length" class="np-dashboard-empty">No payment data yet.</div>
                  <AdminApexChart
                    v-else
                    type="donut"
                    :height="280"
                    :series="salesPaymentChartSeries"
                    :options="salesPaymentChartOptions"
                  />
                </div>
                <div v-if="salesBreakdownRows.length" class="card-footer mt-0">
                  <div class="row gy-3">
                    <div v-for="row in salesBreakdownRows" :key="row.label" class="col-xl-12">
                      <div class="d-flex align-items-center justify-content-between gap-2 py-1">
                        <span class="d-flex align-items-center min-w-0">
                          <i class="ri-checkbox-blank-circle-fill align-middle me-2 d-inline-block" :style="{ color: row.color }" />
                          <span class="d-block flex-fill text-truncate">{{ row.label }}</span>
                        </span>
                        <span class="d-block fw-semibold h6 mb-0 text-end">
                          <span class="me-2 text-success fs-13 d-inline-flex align-items-center">
                            <i class="ti ti-arrow-narrow-up align-middle" />{{ formatNumber(row.share) }}%
                          </span>
                          {{ formatAnyValue(row.value, row.type) }}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div class="col-xl-6">
              <div class="card custom-card overflow-hidden h-100">
                <div class="card-header justify-content-between py-3">
                  <div class="card-title">Payment Channels</div>
                  <span class="fs-12 text-muted">By paid amount</span>
                </div>
                <div class="card-body">
                  <ul v-if="salesBreakdownRows.length" class="list-unstyled transactions-list mb-0">
                    <li v-for="row in salesBreakdownRows" :key="row.label">
                      <div class="d-flex align-items-center justify-content-between py-2">
                        <div class="d-flex align-items-start flex-wrap gap-2">
                          <span :class="['avatar avatar-sm', toneClass(row.tone)]">
                            <i class="ri-wallet-3-line fs-18" />
                          </span>
                          <div>
                            <span class="d-block fw-medium mb-1">{{ row.label }}</span>
                            <span class="d-block fs-11 text-muted">{{ formatNumber(row.share) }}% {{ dashboardPhrase('of sales') }}</span>
                          </div>
                        </div>
                        <div class="text-end">
                          <span class="d-block fw-medium">{{ formatAnyValue(row.value, row.type) }}</span>
                          <span class="text-success fs-12">Paid</span>
                        </div>
                      </div>
                    </li>
                  </ul>
                  <div v-else class="np-dashboard-empty">No payment channels yet.</div>
                </div>
              </div>
            </div>

            <div class="col-xl-5">
              <div class="card custom-card h-100">
                <div class="card-header justify-content-between">
                  <div class="card-title">Top Stores</div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">By sales</span>
                </div>
                <div class="card-body p-0">
                  <div v-if="!salesTopStores.length" class="p-3 text-muted">No store sales yet.</div>
                  <div v-else class="np-sales-country-list">
                    <div v-for="row in salesTopStores" :key="row.id || row.name" class="np-sales-country-row">
                      <span class="np-sales-dot" />
                      <div class="min-w-0">
                        <div class="fw-semibold text-truncate">{{ row.name }}</div>
                        <div class="text-muted fs-12 text-truncate">{{ row.partner_name || row.code || '-' }}</div>
                      </div>
                      <span class="text-success fw-semibold">{{ formatNumber(row.share) }}%</span>
                      <strong>{{ formatNumber(row.order_count || row.customer_count || 0) }}</strong>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div class="col-xl-7">
              <div class="card custom-card h-100">
                <div class="card-header pb-0">
                  <div class="card-title">Sales By Store</div>
                </div>
                <div class="card-body">
                  <div v-if="!salesStoreBars.length" class="np-dashboard-empty">No store sales yet.</div>
                  <AdminApexChart
                    v-else
                    type="bar"
                    :height="300"
                    :series="salesStoreChartSeries"
                    :options="salesStoreChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xl-8">
              <div class="card custom-card h-100">
                <div class="card-header justify-content-between">
                  <div class="card-title">Top Lottery Numbers</div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">Top 10 by tickets</span>
                </div>
                <div class="card-body">
                  <div class="row gy-3">
                    <div v-for="group in popularNumberGroups" :key="group.key" class="col-lg-4">
                      <div class="np-sales-popular-group">
                        <div class="d-flex align-items-center justify-content-between mb-2">
                          <strong>{{ group.label }}</strong>
                          <span class="text-muted fs-12">{{ group.rows.length }} items</span>
                        </div>
                        <div v-if="!group.rows.length" class="np-dashboard-empty py-4">No numbers yet.</div>
                        <div v-else class="np-sales-popular-list">
                          <div v-for="(row, index) in group.rows" :key="`${group.key}-${row.number}`" class="np-sales-popular-row">
                            <span class="np-sales-popular-rank">{{ index + 1 }}</span>
                            <strong>{{ row.number }}</strong>
                          <span class="np-sales-popular-count">{{ formatNumber(row.ticket_count || row.value || 0) }} {{ dashboardPhrase('tickets_unit') }}</span>
                            <span
                              :class="['np-sales-popular-delta', popularNumberDeltaClass(row)]"
                              :title="popularNumberDeltaTitle(row)"
                            >
                              {{ popularNumberDeltaLabel(row) }}
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div class="col-xl-4">
              <div class="card custom-card h-100 overflow-hidden">
                <div class="card-header justify-content-between">
                  <div class="card-title">Default Set Distribution</div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">Sold by filter</span>
                </div>
                <div class="card-body p-0">
                  <div v-if="!setDistributionRows.length" class="p-3 text-muted">No default set distribution yet.</div>
                  <div v-else class="table-responsive">
                    <table class="table table-hover mb-0">
                      <thead>
                        <tr>
                          <th>Set</th>
                          <th class="text-end">Share</th>
                          <th class="text-end">Sets</th>
                          <th class="text-end">Tickets</th>
                          <th class="text-end">Change</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in setDistributionRows" :key="row.set_size">
                          <td class="fw-semibold">{{ row.label || setSizeLabel(row.set_size) }}</td>
                          <td class="text-end">{{ formatNumber(row.percent || 0) }}%</td>
                          <td class="text-end">{{ formatNumber(row.set_count || row.value || 0) }}</td>
                          <td class="text-end">{{ formatNumber(row.ticket_capacity || 0) }}</td>
                          <td class="text-end">
                            <span
                              :class="['np-sales-set-delta', setDistributionDeltaClass(row)]"
                              :title="setDistributionDeltaTitle(row)"
                            >
                              {{ setDistributionDeltaLabel(row) }}
                            </span>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>

            <div class="col-12">
              <div class="card custom-card overflow-hidden">
                <div class="card-header justify-content-between">
                  <div class="card-title">Recent Orders</div>
                  <div class="d-flex flex-wrap gap-2">
                    <span class="form-control form-control-sm np-sales-search-like">Latest paid orders</span>
                    <span class="btn btn-primary btn-sm btn-wave">Sortable table</span>
                  </div>
                </div>
                <div class="card-body p-0">
                  <div v-if="!salesSortedOrderRows.length" class="p-3 text-muted">No recent paid orders yet.</div>
                  <div v-else class="table-responsive">
                    <table class="table text-nowrap table-hover mb-0">
                      <thead>
                        <tr>
                          <th v-for="header in salesOrderHeaders" :key="header.key" :class="{ 'text-end': header.align === 'end' }">
                            <button
                              type="button"
                              :class="['np-sales-sort-button', { active: salesOrderSort.key === header.key }]"
                              @click="setSalesOrderSort(header.key)"
                            >
                              <span>{{ header.label }}</span>
                              <i :class="salesOrderSortIcon(header.key)" />
                            </button>
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in salesSortedOrderRows" :key="row.id || row.title">
                          <td>
                            <div class="d-flex align-items-center gap-2">
                              <span class="avatar avatar-md bg-primary-transparent">{{ initials(salesOrderCustomer(row)) }}</span>
                              <div>
                                <span class="fw-semibold d-block">{{ salesOrderCustomer(row) }}</span>
                                <span class="text-muted fs-12">{{ row.title || row.id }}</span>
                              </div>
                            </div>
                          </td>
                          <td>
                            <div class="fw-semibold">{{ salesOrderStore(row) }}</div>
                            <span class="fs-12 text-muted">Lottery order</span>
                          </td>
                          <td>
                            <span class="fw-semibold d-block">{{ formatSalesDate(row.created_at) }}</span>
                            <span class="fs-12 text-muted">{{ formatSalesTime(row.created_at) }}</span>
                          </td>
                          <td>
                            <AdminStatusBadge :status="row.status || 'paid'" />
                          </td>
                          <td class="text-end">{{ row.amount ? formatDashboardMoney(row.amount) : '-' }}</td>
                          <td>
                            <div>
                              <i class="ri-bank-card-line me-1 fs-14" />{{ row.meta || 'Payment' }}
                            </div>
                            <div class="fs-12 text-muted">Central dashboard</div>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
                <div class="card-footer py-2">
                  <div class="d-flex align-items-center">
                    <div>{{ dashboardPhrase('Showing') }} {{ salesSortedOrderRows.length }} {{ dashboardPhrase('Entries') }} <i class="bi bi-arrow-right ms-2 fw-semibold" /></div>
                    <div class="ms-auto text-muted fs-12">{{ filterCaption }}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>

      <template v-else-if="section === 'partner'">
        <div :key="partnerDashboardKey" class="np-partner-dashboard">
          <div class="row g-3">
            <div v-for="metric in partnerKpis" :key="metric.key" class="col-xxl col-xl-4 col-md-6">
              <div class="card custom-card overflow-hidden np-sales-kpi-card h-100">
                <div class="card-body">
                  <div class="d-flex gap-3">
                    <span :class="['np-sales-kpi-avatar', toneClass(metric.tone)]">
                      <i :class="metric.icon" />
                    </span>
                    <div class="flex-fill min-w-0">
                      <div class="fw-medium fs-13 mb-1 text-dark np-sales-card-label">{{ partnerMetricLabel(metric) }}</div>
                      <div :class="['fs-22 fw-semibold mb-1', salesMetricTextClass(metric.tone)]">
                        {{ partnerMetricValue(metric) }}
                      </div>
                      <div class="d-flex align-items-center fs-11">
                        <span :class="['fw-semibold me-1', directionClass(metric.delta?.direction)]">
                          <i :class="metric.delta?.direction === 'down' ? 'ti ti-trending-down' : 'ti ti-trending-up'" class="me-1 fw-medium align-middle" />
                          {{ deltaPercentLabel(metric.delta) }}
                        </span>
                        <span class="text-default op-6">{{ periodLabel }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="col-12">
              <div class="card custom-card h-100">
                <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <div>
                    <div class="card-title mb-1">{{ dashboardPhrase('Partner Sales Comparison') }}</div>
                    <p class="text-muted fs-12 mb-0">{{ dashboardPhrase('Partner sales amount by partner for the selected filter.') }}</p>
                  </div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ partnerSalesChartScopeLabel }}</span>
                </div>
                <div class="card-body">
                  <div v-if="!partnerSalesChartRows.length" class="np-dashboard-empty">{{ dashboardPhrase('No partner sales yet.') }}</div>
                  <AdminApexChart
                    v-else
                    :key="partnerSalesChartKey"
                    type="bar"
                    :height="380"
                    :series="partnerSalesChartSeries"
                    :options="partnerSalesChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xl-6">
              <div class="card custom-card h-100">
                <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <div>
                    <div class="card-title mb-1">{{ dashboardPhrase('New Members By Partner') }}</div>
                    <p class="text-muted fs-12 mb-0">{{ dashboardPhrase('New members by partner for the selected filter.') }}</p>
                  </div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ partnerMembersChartScopeLabel }}</span>
                </div>
                <div class="card-body">
                  <div v-if="!partnerMemberChartRows.length" class="np-dashboard-empty">{{ dashboardPhrase('No new members yet.') }}</div>
                  <AdminApexChart
                    v-else
                    :key="partnerMembersChartKey"
                    type="bar"
                    :height="320"
                    :series="partnerMembersChartSeries"
                    :options="partnerMembersChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xl-6">
              <div class="card custom-card h-100">
                <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <div>
                    <div class="card-title mb-1">{{ dashboardPhrase('Affiliate Accounts By Partner') }}</div>
                    <p class="text-muted fs-12 mb-0">{{ dashboardPhrase('Affiliate accounts by partner for the selected filter.') }}</p>
                  </div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ partnerAffiliateChartScopeLabel }}</span>
                </div>
                <div class="card-body">
                  <div v-if="!partnerAffiliateChartRows.length" class="np-dashboard-empty">{{ dashboardPhrase('No affiliate accounts yet.') }}</div>
                  <AdminApexChart
                    v-else
                    :key="partnerAffiliateChartKey"
                    type="bar"
                    :height="320"
                    :series="partnerAffiliateChartSeries"
                    :options="partnerAffiliateChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xl-7">
              <div class="card custom-card h-100 overflow-hidden">
                <div class="card-header justify-content-between">
                  <div class="card-title">{{ dashboardPhrase('Partner Performance') }}</div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ dashboardPhrase('Sales + tickets') }}</span>
                </div>
                <div class="card-body p-0">
                  <div v-if="!partnerSalesRows.length" class="p-3 text-muted">{{ dashboardPhrase('No partner performance yet.') }}</div>
                  <div v-else class="table-responsive">
                    <table class="table table-hover mb-0">
                      <thead>
                        <tr>
                          <th>{{ dashboardPhrase('Partner') }}</th>
                          <th class="text-end">{{ dashboardPhrase('Sales') }}</th>
                          <th class="text-end">{{ dashboardPhrase('Tickets') }}</th>
                          <th class="text-end">{{ dashboardPhrase('Orders') }}</th>
                          <th class="text-end">{{ dashboardPhrase('Customers') }}</th>
                          <th class="text-end">{{ dashboardPhrase('Change') }}</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in partnerSalesRows" :key="row.id || row.name">
                          <td>
                            <div class="fw-semibold text-truncate">{{ row.name }}</div>
                            <div class="text-muted fs-12 text-truncate">{{ row.code || row.status || '-' }}</div>
                          </td>
                          <td class="text-end fw-semibold">{{ formatDashboardMoney(row.sales_amount) }}</td>
                          <td class="text-end">{{ formatNumber(row.ticket_count || 0) }}</td>
                          <td class="text-end">{{ formatNumber(row.order_count || 0) }}</td>
                          <td class="text-end">{{ formatNumber(row.customer_count || 0) }}</td>
                          <td class="text-end">
                            <span :class="['np-sales-set-delta', partnerRowDeltaClass(row, 'sales')]">
                              {{ partnerRowDeltaLabel(row, 'sales') }}
                            </span>
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
                  <div class="card-title mb-0">{{ dashboardPhrase('Recent Partner Activity') }}</div>
                </div>
                <div class="card-body">
                  <div v-if="!recentRows.length" class="np-dashboard-empty">{{ dashboardPhrase('No recent partners yet.') }}</div>
                  <div v-else class="list-group list-group-flush np-dashboard-list">
                    <div v-for="row in recentRows" :key="row.id || row.title" class="list-group-item px-0">
                      <div class="d-flex align-items-start justify-content-between gap-3">
                        <div class="min-w-0">
                          <div class="fw-semibold text-truncate">{{ row.title || row.name || row.label }}</div>
                          <div class="text-muted fs-12 text-truncate">{{ row.subtitle || row.meta || '-' }}</div>
                          <div class="text-muted fs-12">{{ formatDateTime(row.created_at || row.last_seen_at) }}</div>
                        </div>
                        <div class="text-end">
                          <div v-if="row.amount" class="fw-semibold">{{ formatDashboardMoney(row.amount) }}</div>
                          <AdminStatusBadge v-if="row.status" :status="row.status" />
                          <div v-else-if="row.value !== undefined" class="fw-semibold">{{ formatNumber(row.value) }}</div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>

      <template v-else-if="section === 'wallet'">
        <div class="np-wallet-dashboard">
          <div class="row g-3">
            <div class="col-xxl-4">
              <div class="card custom-card np-dashboard-hero h-100">
                <div class="card-body">
                  <div class="d-flex align-items-start justify-content-between gap-3 mb-4">
                    <div>
                      <p class="text-muted fw-medium mb-1">{{ hero.label }}</p>
                      <h2 class="mb-1">{{ formatMetricValue(hero.value, heroType) }}</h2>
                      <span class="text-muted fs-12">{{ hero.caption }}</span>
                    </div>
                    <span :class="['np-dashboard-hero-icon', toneClass(primaryTone)]">
                      <i :class="primaryIcon" />
                    </span>
                  </div>
                  <div class="np-dashboard-compare">
                    <div>
                      <span>{{ dashboardPhrase('Previous') }}</span>
                      <strong>{{ formatMetricValue(hero.previous, heroType) }}</strong>
                    </div>
                    <div>
                      <span>{{ dashboardPhrase('Change') }}</span>
                      <strong :class="directionClass(hero.delta?.direction)">{{ deltaLabel(hero.delta, heroType) }}</strong>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div v-for="metric in metrics" :key="metric.key" class="col-xxl col-xl-4 col-md-6">
              <div class="card custom-card np-dashboard-kpi h-100">
                <div class="card-body">
                  <div class="d-flex align-items-start justify-content-between gap-2 mb-3">
                    <span :class="['np-dashboard-kpi-icon', toneClass(metric.tone)]">
                      <i :class="metric.icon" />
                    </span>
                    <span :class="['np-dashboard-delta', directionClass(metric.delta?.direction)]">
                      {{ deltaLabel(metric.delta, metric.type, true) }}
                    </span>
                  </div>
                  <p class="text-muted mb-1">{{ metric.label }}</p>
                  <h5 class="mb-0">{{ formatMetricValue(metric.current, metric.type) }}</h5>
                  <small class="text-muted">{{ dashboardPhrase('Previous') }} {{ formatMetricValue(metric.previous, metric.type) }}</small>
                </div>
              </div>
            </div>

            <div class="col-xxl-8">
              <div class="card custom-card h-100">
                <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <div>
                    <div class="card-title mb-1">{{ primaryChartTitle }}</div>
                    <p class="text-muted fs-12 mb-0">{{ primaryChartSubtitle }}</p>
                  </div>
                  <div class="d-flex flex-wrap gap-2">
                    <span v-for="series in primarySeries" :key="series.key" class="badge bg-primary-transparent text-primary">
                      {{ series.label }}
                    </span>
                  </div>
                </div>
                <div class="card-body">
                  <div v-if="!genericTrendChartSeries.length" class="np-dashboard-empty">{{ dashboardPhrase('No trend data yet.') }}</div>
                  <AdminApexChart
                    v-else
                    type="bar"
                    :height="320"
                    :series="genericTrendChartSeries"
                    :options="genericTrendChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xxl-4">
              <div class="card custom-card h-100">
                <div class="card-header">
                  <div class="card-title mb-0">{{ breakdownTitle }}</div>
                </div>
                <div class="card-body">
                  <div v-if="!breakdownRows.length" class="np-dashboard-empty">{{ dashboardPhrase('No breakdown data yet.') }}</div>
                  <AdminApexChart
                    v-else
                    type="donut"
                    :height="320"
                    :series="breakdownChartSeries"
                    :options="breakdownChartOptions"
                  />
                </div>
              </div>
            </div>

            <div v-if="entityChartRows.length" class="col-12">
              <div class="card custom-card">
                <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <div>
                    <div class="card-title mb-1">{{ entityChartTitle }}</div>
                    <p class="text-muted fs-12 mb-0">{{ entityChartSubtitle }}</p>
                  </div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ primaryValueHeader }}</span>
                </div>
                <div class="card-body">
                  <AdminApexChart
                    type="bar"
                    :height="300"
                    :series="entityChartSeries"
                    :options="entityChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xxl-7">
              <div class="card custom-card h-100">
                <div class="card-header">
                  <div class="card-title mb-0">{{ primaryTableTitle }}</div>
                </div>
                <div class="card-body p-0">
                  <div v-if="!primaryRows.length" class="p-3 text-muted">{{ dashboardPhrase('No data yet.') }}</div>
                  <div v-else class="table-responsive">
                    <table class="table table-hover mb-0">
                      <thead>
                        <tr>
                          <th>{{ dashboardPhrase('Name') }}</th>
                          <th>{{ dashboardPhrase('Detail') }}</th>
                          <th class="text-end">{{ primaryValueHeader }}</th>
                          <th class="text-end">{{ dashboardPhrase('Count') }}</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in primaryRows" :key="row.id || row.label || row.name">
                          <td>
                            <div class="fw-semibold">{{ row.name || row.label || row.title }}</div>
                            <div class="text-muted fs-12">{{ row.code || row.id || '-' }}</div>
                          </td>
                          <td>{{ row.partner_name || row.subtitle || row.status || '-' }}</td>
                          <td class="text-end fw-semibold">{{ rowMoney(row) }}</td>
                          <td class="text-end">{{ formatNumber(row.order_count || row.customer_count || row.transaction_count || row.claim_count || row.value || 0) }}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>

            <div class="col-xxl-5">
              <div class="card custom-card h-100">
                <div class="card-header">
                  <div class="card-title mb-0">{{ recentTableTitle }}</div>
                </div>
                <div class="card-body">
                  <div v-if="!recentRows.length" class="np-dashboard-empty">{{ dashboardPhrase('No recent rows yet.') }}</div>
                  <div v-else class="list-group list-group-flush np-dashboard-list">
                    <div v-for="row in recentRows" :key="row.id || row.title" class="list-group-item px-0">
                      <div class="d-flex align-items-start justify-content-between gap-3">
                        <div>
                          <div class="fw-semibold">{{ row.title || row.name || row.label }}</div>
                          <div class="text-muted fs-12">{{ row.subtitle || row.meta || '-' }}</div>
                          <div class="text-muted fs-12">{{ formatDateTime(row.created_at || row.last_seen_at) }}</div>
                        </div>
                        <div class="text-end">
                          <div v-if="row.amount" class="fw-semibold">{{ formatDashboardMoney(row.amount) }}</div>
                          <AdminStatusBadge v-if="row.status" :status="row.status" />
                          <div v-else-if="row.value !== undefined" class="fw-semibold">{{ formatNumber(row.value) }}</div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>

      <template v-else-if="section === 'payout'">
        <div class="np-payout-dashboard">
          <div class="row g-3">
            <div class="col-12">
              <div class="np-dashboard-section-title">{{ dashboardPhrase('Payout Reward section') }}</div>
            </div>

            <div v-for="metric in payoutRewardKpis" :key="metric.key" class="col-xl-3 col-md-6">
              <div class="card custom-card np-dashboard-kpi h-100">
                <div class="card-body">
                  <div class="d-flex align-items-start justify-content-between gap-2 mb-3">
                    <span :class="['np-dashboard-kpi-icon', toneClass(metric.tone)]">
                      <i :class="metric.icon" />
                    </span>
                    <span :class="['np-dashboard-delta', directionClass(metric.delta?.direction)]">
                      {{ deltaLabel(metric.delta, metric.type, true) }}
                    </span>
                  </div>
                  <p class="text-muted mb-1">{{ metric.label }}</p>
                  <h5 class="mb-0">{{ formatMetricValue(metric.current, metric.type) }}</h5>
                  <small class="text-muted">{{ dashboardPhrase('Previous') }} {{ formatMetricValue(metric.previous, metric.type) }}</small>
                </div>
              </div>
            </div>

            <div class="col-xl-8">
              <div class="card custom-card h-100">
                <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <div>
                    <div class="card-title mb-1">{{ dashboardPhrase('Reward payout by partner') }}</div>
                    <p class="text-muted fs-12 mb-0">{{ dashboardPhrase('Partner payout ranking for the selected payout filter.') }}</p>
                  </div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ payoutPartnerChartScopeLabel }}</span>
                </div>
                <div class="card-body">
                  <div v-if="!payoutPartnerChartRows.length" class="np-dashboard-empty">{{ dashboardPhrase('No reward payout data yet.') }}</div>
                  <AdminApexChart
                    v-else
                    :key="payoutPartnerChartKey"
                    type="bar"
                    :height="340"
                    :series="payoutPartnerChartSeries"
                    :options="payoutPartnerChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xl-4">
              <div class="card custom-card h-100">
                <div class="card-header">
                  <div class="card-title mb-0">{{ dashboardPhrase('Winning prize type mix') }}</div>
                </div>
                <div class="card-body">
                  <div v-if="!winningTypeRows.length" class="np-dashboard-empty">{{ dashboardPhrase('No winning ticket data yet.') }}</div>
                  <AdminApexChart
                    v-else
                    type="bar"
                    :height="340"
                    :series="winningTypeChartSeries"
                    :options="winningTypeChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-12">
              <div class="card custom-card overflow-hidden">
                <div class="card-header justify-content-between">
                  <div class="card-title">{{ dashboardPhrase('Top partners by payout') }}</div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ dashboardPhrase('Sortable datatable') }}</span>
                </div>
                <div class="card-body p-0">
                  <div v-if="!sortedPayoutPartnerRows.length" class="p-3 text-muted">{{ dashboardPhrase('No partner payout data yet.') }}</div>
                  <div v-else class="table-responsive">
                    <table class="table table-hover mb-0">
                      <thead>
                        <tr>
                          <th v-for="header in payoutPartnerHeaders" :key="header.key" :class="{ 'text-end': header.align === 'end' }">
                            <button
                              type="button"
                              :class="['np-sales-sort-button', { active: payoutPartnerSort.key === header.key }]"
                              @click="setPayoutPartnerSort(header.key)"
                            >
                              <span>{{ dashboardPhrase(header.label) }}</span>
                              <i :class="payoutPartnerSortIcon(header.key)" />
                            </button>
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in sortedPayoutPartnerRows" :key="row.id || row.name">
                          <td>
                            <div class="fw-semibold text-truncate">{{ row.name }}</div>
                            <div class="text-muted fs-12 text-truncate">{{ row.code || '-' }}</div>
                          </td>
                          <td class="text-end fw-semibold">{{ formatDashboardMoney(row.payout_amount) }}</td>
                          <td class="text-end">{{ formatNumber(row.claim_count || 0) }}</td>
                          <td class="text-end text-success fw-semibold">{{ formatNumber(row.approved_count || 0) }}</td>
                          <td class="text-end text-danger fw-semibold">{{ formatNumber(row.rejected_count || 0) }}</td>
                          <td class="text-end">{{ formatNumber(row.other_status_count || 0) }}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>

            <div class="col-12">
              <div class="np-dashboard-section-title mt-2">{{ dashboardPhrase('Payout Commission section') }}</div>
            </div>

            <div v-for="metric in payoutCommissionKpis" :key="metric.key" class="col-xl-4 col-md-6">
              <div class="card custom-card np-dashboard-kpi h-100">
                <div class="card-body">
                  <div class="d-flex align-items-start justify-content-between gap-2 mb-3">
                    <span :class="['np-dashboard-kpi-icon', toneClass(metric.tone)]">
                      <i :class="metric.icon" />
                    </span>
                    <span :class="['np-dashboard-delta', directionClass(metric.delta?.direction)]">
                      {{ deltaLabel(metric.delta, metric.type, true) }}
                    </span>
                  </div>
                  <p class="text-muted mb-1">{{ metric.label }}</p>
                  <h5 class="mb-0">{{ formatMetricValue(metric.current, metric.type) }}</h5>
                  <small class="text-muted">{{ dashboardPhrase('Previous') }} {{ formatMetricValue(metric.previous, metric.type) }}</small>
                </div>
              </div>
            </div>

            <div class="col-xl-7">
              <div class="card custom-card h-100">
                <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <div>
                    <div class="card-title mb-1">{{ dashboardPhrase('Commission by partner') }}</div>
                    <p class="text-muted fs-12 mb-0">{{ dashboardPhrase('Affiliate commission movement by partner.') }}</p>
                  </div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ payoutCommissionChartScopeLabel }}</span>
                </div>
                <div class="card-body">
                  <div v-if="!payoutCommissionChartRows.length" class="np-dashboard-empty">{{ dashboardPhrase('No commission data yet.') }}</div>
                  <AdminApexChart
                    v-else
                    :key="payoutCommissionChartKey"
                    type="bar"
                    :height="320"
                    :series="payoutCommissionChartSeries"
                    :options="payoutCommissionChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xl-5">
              <div class="card custom-card h-100 overflow-hidden">
                <div class="card-header">
                  <div class="card-title mb-0">{{ dashboardPhrase('Commission partners') }}</div>
                </div>
                <div class="card-body p-0">
                  <div v-if="!payoutCommissionRows.length" class="p-3 text-muted">{{ dashboardPhrase('No commission partner data yet.') }}</div>
                  <div v-else class="table-responsive">
                    <table class="table table-hover mb-0">
                      <thead>
                        <tr>
                          <th>{{ dashboardPhrase('Partner') }}</th>
                          <th class="text-end">{{ dashboardPhrase('Commission') }}</th>
                          <th class="text-end">{{ dashboardPhrase('Txns') }}</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in payoutCommissionRows.slice(0, 8)" :key="row.id || row.name">
                          <td>
                            <div class="fw-semibold text-truncate">{{ row.name }}</div>
                            <div class="text-muted fs-12 text-truncate">{{ row.code || '-' }}</div>
                          </td>
                          <td class="text-end fw-semibold">{{ formatDashboardMoney(row.commission_amount) }}</td>
                          <td class="text-end">{{ formatNumber(row.transaction_count || 0) }}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>

      <template v-else-if="section === 'monitor'">
        <div class="np-monitor-dashboard">
          <div class="row g-3">
            <div class="col-xxl-4">
              <div class="card custom-card np-dashboard-hero h-100">
                <div class="card-body">
                  <div class="d-flex align-items-start justify-content-between gap-3 mb-4">
                    <div>
                      <p class="text-muted fw-medium mb-1">{{ hero.label }}</p>
                      <h2 class="mb-1">{{ formatMetricValue(hero.value, heroType) }}</h2>
                      <span class="text-muted fs-12">{{ hero.caption }}</span>
                    </div>
                    <span :class="['np-dashboard-hero-icon', toneClass(primaryTone)]">
                      <i :class="primaryIcon" />
                    </span>
                  </div>
                  <div class="np-dashboard-compare">
                    <div>
                      <span>Previous</span>
                      <strong>{{ formatMetricValue(hero.previous, heroType) }}</strong>
                    </div>
                    <div>
                      <span>Change</span>
                      <strong :class="directionClass(hero.delta?.direction)">{{ deltaLabel(hero.delta, heroType) }}</strong>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div v-for="metric in metrics" :key="metric.key" class="col-xxl col-xl-4 col-md-6">
              <div class="card custom-card np-dashboard-kpi h-100">
                <div class="card-body">
                  <div class="d-flex align-items-start justify-content-between gap-2 mb-3">
                    <span :class="['np-dashboard-kpi-icon', toneClass(metric.tone)]">
                      <i :class="metric.icon" />
                    </span>
                    <span :class="['np-dashboard-delta', directionClass(metric.delta?.direction)]">
                      {{ deltaLabel(metric.delta, metric.type, true) }}
                    </span>
                  </div>
                  <p class="text-muted mb-1">{{ metric.label }}</p>
                  <h5 class="mb-0">{{ formatMetricValue(metric.current, metric.type) }}</h5>
                  <small class="text-muted">Previous {{ formatMetricValue(metric.previous, metric.type) }}</small>
                </div>
              </div>
            </div>

            <div class="col-xxl-8">
              <div class="card custom-card h-100">
                <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <div>
                    <div class="card-title mb-1">{{ primaryChartTitle }}</div>
                    <p class="text-muted fs-12 mb-0">{{ primaryChartSubtitle }}</p>
                  </div>
                  <div class="d-flex flex-wrap gap-2">
                    <span v-for="series in primarySeries" :key="series.key" class="badge bg-primary-transparent text-primary">
                      {{ series.label }}
                    </span>
                  </div>
                </div>
                <div class="card-body">
                  <div v-if="!genericTrendChartSeries.length" class="np-dashboard-empty">No trend data yet.</div>
                  <AdminApexChart
                    v-else
                    type="bar"
                    :height="320"
                    :series="genericTrendChartSeries"
                    :options="genericTrendChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xxl-4">
              <div class="card custom-card h-100">
                <div class="card-header">
                  <div class="card-title mb-0">{{ breakdownTitle }}</div>
                </div>
                <div class="card-body">
                  <div v-if="!breakdownRows.length" class="np-dashboard-empty">No source data yet.</div>
                  <AdminApexChart
                    v-else
                    type="donut"
                    :height="320"
                    :series="breakdownChartSeries"
                    :options="breakdownChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-12">
              <div class="card custom-card h-100">
                <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
                  <div>
                    <div class="card-title mb-1">{{ entityChartTitle }}</div>
                    <p class="text-muted fs-12 mb-0">{{ entityChartSubtitle }}</p>
                  </div>
                  <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ primaryValueHeader }}</span>
                </div>
                <div class="card-body">
                  <div v-if="!entityChartRows.length" class="np-dashboard-empty">No active store data yet.</div>
                  <AdminApexChart
                    v-else
                    type="bar"
                    :height="300"
                    :series="entityChartSeries"
                    :options="entityChartOptions"
                  />
                </div>
              </div>
            </div>

            <div class="col-xxl-7">
              <div class="card custom-card h-100 overflow-hidden">
                <div class="card-header">
                  <div class="card-title mb-0">{{ primaryTableTitle }}</div>
                </div>
                <div class="card-body p-0">
                  <div v-if="!primaryRows.length" class="p-3 text-muted">No active partner stores yet.</div>
                  <div v-else class="table-responsive">
                    <table class="table table-hover mb-0">
                      <thead>
                        <tr>
                          <th>Store</th>
                          <th>Partner</th>
                          <th class="text-end">Members</th>
                          <th class="text-end">Guests</th>
                          <th class="text-end">Total</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in primaryRows" :key="row.id || row.name">
                          <td>
                            <div class="fw-semibold text-truncate">{{ row.name }}</div>
                            <div class="text-muted fs-12 text-truncate">{{ row.code || '-' }}</div>
                          </td>
                          <td>{{ row.partner_name || '-' }}</td>
                          <td class="text-end">{{ formatNumber(row.member_sessions || 0) }}</td>
                          <td class="text-end">{{ formatNumber(row.guest_sessions || 0) }}</td>
                          <td class="text-end fw-semibold">{{ formatNumber(row.value || 0) }}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>

            <div class="col-xxl-5">
              <div class="card custom-card h-100 overflow-hidden">
                <div class="card-header">
                  <div class="card-title mb-0">Top visitor IPs</div>
                </div>
                <div class="card-body p-0">
                  <div v-if="!topTenantRows.length" class="p-3 text-muted">No visitor IP data yet.</div>
                  <div v-else class="table-responsive">
                    <table class="table table-hover mb-0">
                      <thead>
                        <tr>
                          <th>IP</th>
                          <th class="text-end">Visits</th>
                          <th class="text-end">Last seen</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in topTenantRows" :key="row.label || row.id">
                          <td class="fw-semibold">{{ row.label || '-' }}</td>
                          <td class="text-end">{{ formatNumber(row.value || 0) }}</td>
                          <td class="text-end">{{ formatDateTime(row.last_seen_at) }}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>

            <div class="col-xxl-4">
              <div class="card custom-card h-100">
                <div class="card-header">
                  <div class="card-title mb-0">{{ recentTableTitle }}</div>
                </div>
                <div class="card-body">
                  <div v-if="!recentRows.length" class="np-dashboard-empty">No admin sessions yet.</div>
                  <div v-else class="list-group list-group-flush np-dashboard-list">
                    <div v-for="row in recentRows" :key="row.id || row.title" class="list-group-item px-0">
                      <div class="d-flex align-items-start justify-content-between gap-3">
                        <div class="min-w-0">
                          <div class="fw-semibold text-truncate">{{ row.title }}</div>
                          <div class="text-muted fs-12 text-truncate">{{ row.subtitle || '-' }}</div>
                          <div class="text-muted fs-12">{{ formatDateTime(row.created_at) }}</div>
                        </div>
                        <AdminStatusBadge :status="row.status || 'admin'" />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="col-xxl-4">
              <div class="card custom-card h-100 overflow-hidden">
                <div class="card-header">
                  <div class="card-title mb-0">Online members</div>
                </div>
                <div class="card-body p-0">
                  <div v-if="!memberRows.length" class="p-3 text-muted">No member sessions in this period.</div>
                  <div v-else class="table-responsive">
                    <table class="table table-hover mb-0">
                      <thead>
                        <tr>
                          <th>Member</th>
                          <th>Store</th>
                          <th class="text-end">Last seen</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in memberRows" :key="row.id">
                          <td class="fw-semibold">{{ row.title }}</td>
                          <td>{{ row.subtitle }}</td>
                          <td class="text-end">{{ formatDateTime(row.created_at) }}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>

            <div class="col-xxl-4">
              <div class="card custom-card h-100 overflow-hidden">
                <div class="card-header">
                  <div class="card-title mb-0">Public visitors</div>
                </div>
                <div class="card-body p-0">
                  <div v-if="!visitorRows.length" class="p-3 text-muted">No public visitors in this period.</div>
                  <div v-else class="table-responsive">
                    <table class="table table-hover mb-0">
                      <thead>
                        <tr>
                          <th>Visitor</th>
                          <th>Store / IP</th>
                          <th class="text-end">Last seen</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in visitorRows" :key="row.id">
                          <td>
                            <div class="fw-semibold text-truncate">{{ row.title }}</div>
                            <div class="text-muted fs-12 text-truncate">{{ row.meta || row.status || '-' }}</div>
                          </td>
                          <td>{{ row.subtitle }}</td>
                          <td class="text-end">{{ formatDateTime(row.created_at) }}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>

      <template v-else>
      <div class="row g-3">
        <div class="col-xxl-4">
          <div class="card custom-card np-dashboard-hero h-100">
            <div class="card-body">
              <div class="d-flex align-items-start justify-content-between gap-3 mb-4">
                <div>
                  <p class="text-muted fw-medium mb-1">{{ hero.label }}</p>
                  <h2 class="mb-1">{{ formatMetricValue(hero.value, heroType) }}</h2>
                  <span class="text-muted fs-12">{{ hero.caption }}</span>
                </div>
                <span :class="['np-dashboard-hero-icon', toneClass(primaryTone)]">
                  <i :class="primaryIcon" />
                </span>
              </div>
              <div class="np-dashboard-compare">
                <div>
                  <span>Previous</span>
                  <strong>{{ formatMetricValue(hero.previous, heroType) }}</strong>
                </div>
                <div>
                  <span>Change</span>
                  <strong :class="directionClass(hero.delta?.direction)">{{ deltaLabel(hero.delta, heroType) }}</strong>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div v-for="metric in metrics" :key="metric.key" class="col-xxl-2 col-xl-4 col-md-6">
          <div class="card custom-card np-dashboard-kpi h-100">
            <div class="card-body">
              <div class="d-flex align-items-start justify-content-between gap-2 mb-3">
                <span :class="['np-dashboard-kpi-icon', toneClass(metric.tone)]">
                  <i :class="metric.icon" />
                </span>
                <span :class="['np-dashboard-delta', directionClass(metric.delta?.direction)]">
                  {{ deltaLabel(metric.delta, metric.type, true) }}
                </span>
              </div>
              <p class="text-muted mb-1">{{ metric.label }}</p>
              <h5 class="mb-0">{{ formatMetricValue(metric.current, metric.type) }}</h5>
              <small class="text-muted">Previous {{ formatMetricValue(metric.previous, metric.type) }}</small>
            </div>
          </div>
        </div>
      </div>

      <div class="row">
        <div class="col-xxl-8">
          <div class="card custom-card h-100">
            <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
              <div>
                <div class="card-title mb-1">{{ primaryChartTitle }}</div>
                <p class="text-muted fs-12 mb-0">{{ primaryChartSubtitle }}</p>
              </div>
              <div class="d-flex flex-wrap gap-2">
                <span v-for="series in primarySeries" :key="series.key" class="badge bg-primary-transparent text-primary">
                  {{ series.label }}
                </span>
              </div>
            </div>
            <div class="card-body">
              <div v-if="!genericTrendChartSeries.length" class="np-dashboard-empty">No trend data yet.</div>
              <AdminApexChart
                v-else
                type="bar"
                :height="320"
                :series="genericTrendChartSeries"
                :options="genericTrendChartOptions"
              />
            </div>
          </div>
        </div>

        <div class="col-xxl-4">
          <div class="card custom-card h-100">
            <div class="card-header">
              <div class="card-title mb-0">{{ breakdownTitle }}</div>
            </div>
            <div class="card-body">
              <div v-if="!breakdownRows.length" class="np-dashboard-empty">No breakdown data yet.</div>
              <AdminApexChart
                v-else
                type="donut"
                :height="320"
                :series="breakdownChartSeries"
                :options="breakdownChartOptions"
              />
            </div>
          </div>
        </div>
      </div>

      <div v-if="entityChartRows.length" class="row">
        <div class="col-xxl-12">
          <div class="card custom-card">
            <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
              <div>
                <div class="card-title mb-1">{{ entityChartTitle }}</div>
                <p class="text-muted fs-12 mb-0">{{ entityChartSubtitle }}</p>
              </div>
              <span class="fs-12 text-muted fw-medium bg-light rounded p-1">{{ primaryValueHeader }}</span>
            </div>
            <div class="card-body">
              <AdminApexChart
                type="bar"
                :height="300"
                :series="entityChartSeries"
                :options="entityChartOptions"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="row">
        <div class="col-xxl-7">
          <div class="card custom-card">
            <div class="card-header">
              <div class="card-title mb-0">{{ primaryTableTitle }}</div>
            </div>
            <div class="card-body p-0">
              <div v-if="!primaryRows.length" class="p-3 text-muted">No data yet.</div>
              <div v-else class="table-responsive">
                <table class="table table-hover mb-0">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Detail</th>
                      <th class="text-end">{{ primaryValueHeader }}</th>
                      <th class="text-end">Count</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="row in primaryRows" :key="row.id || row.label || row.name">
                      <td>
                        <div class="fw-semibold">{{ row.name || row.label || row.title }}</div>
                        <div class="text-muted fs-12">{{ row.code || row.id || '-' }}</div>
                      </td>
                      <td>{{ row.partner_name || row.subtitle || row.status || '-' }}</td>
                      <td class="text-end fw-semibold">{{ rowMoney(row) }}</td>
                      <td class="text-end">{{ formatNumber(row.order_count || row.customer_count || row.transaction_count || row.claim_count || row.value || 0) }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <div class="col-xxl-5">
          <div class="card custom-card">
            <div class="card-header">
              <div class="card-title mb-0">{{ recentTableTitle }}</div>
            </div>
            <div class="card-body">
              <div v-if="!recentRows.length" class="np-dashboard-empty">No recent rows yet.</div>
              <div v-else class="list-group list-group-flush np-dashboard-list">
                <div v-for="row in recentRows" :key="row.id || row.title" class="list-group-item px-0">
                  <div class="d-flex align-items-start justify-content-between gap-3">
                    <div>
                      <div class="fw-semibold">{{ row.title || row.name || row.label }}</div>
                      <div class="text-muted fs-12">{{ row.subtitle || row.meta || '-' }}</div>
                      <div class="text-muted fs-12">{{ formatDateTime(row.created_at || row.last_seen_at) }}</div>
                    </div>
                    <div class="text-end">
                      <div v-if="row.amount" class="fw-semibold">{{ formatDashboardMoney(row.amount) }}</div>
                      <AdminStatusBadge v-if="row.status" :status="row.status" />
                      <div v-else-if="row.value !== undefined" class="fw-semibold">{{ formatNumber(row.value) }}</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div v-if="section === 'monitor'" class="card custom-card">
        <div class="card-header">
          <div class="card-title mb-0">Online members</div>
        </div>
        <div class="card-body p-0">
          <div v-if="!memberRows.length" class="p-3 text-muted">No online members right now.</div>
          <div v-else class="table-responsive">
            <table class="table table-hover mb-0">
              <thead>
                <tr>
                  <th>Member</th>
                  <th>Partner store</th>
                  <th>Status</th>
                  <th>Last seen</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in memberRows" :key="row.id">
                  <td>{{ row.title }}</td>
                  <td>{{ row.subtitle }}</td>
                  <td><AdminStatusBadge :status="row.status" /></td>
                  <td>{{ formatDateTime(row.created_at) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div v-if="section === 'monitor'" class="card custom-card">
        <div class="card-header">
          <div class="card-title mb-0">Public visitors</div>
        </div>
        <div class="card-body p-0">
          <div v-if="!visitorRows.length" class="p-3 text-muted">No public visitors right now.</div>
          <div v-else class="table-responsive">
            <table class="table table-hover mb-0">
              <thead>
                <tr>
                  <th>Visitor</th>
                  <th>Partner store / IP</th>
                  <th>Source</th>
                  <th>Last seen</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in visitorRows" :key="row.id">
                  <td>{{ row.title }}</td>
                  <td>{{ row.subtitle }}</td>
                  <td>{{ row.meta || row.status || '-' }}</td>
                  <td>{{ formatDateTime(row.created_at) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      </template>
    </template>
  </div>
</template>

<script setup lang="ts">
import { formatDateTime, formatMoney } from '~/utils/format'

const props = defineProps<{
  section: 'sales' | 'partner' | 'wallet' | 'payout' | 'monitor'
}>()

const api = useAdminApi()
const route = useRoute()
const router = useRouter()
const { t, phrase, locale } = useAdminLocale()

const allowedPeriods = new Set(['today', 'yesterday', 'last_7_days', 'previous_draw', 'current_draw', 'this_month', 'this_year'])
const period = ref(allowedPeriods.has(String(route.query.period || '')) ? String(route.query.period) : defaultPeriodForSection(props.section))
const loading = ref(false)
const error = ref<any>(null)
const summary = ref<any>(null)
const summaryRevision = ref(0)
const salesOrderSort = ref({ key: 'created_at', direction: 'desc' as 'asc' | 'desc' })
const payoutPartnerSort = ref({ key: 'payout_amount', direction: 'desc' as 'asc' | 'desc' })
let loadSequence = 0
const salesColors = ['#5b8ff9', '#a66bff', '#2ecc71', '#f06595', '#ff9f43']
const salesTones = ['primary', 'secondary', 'success', 'pink']
const salesDateFormatter = new Intl.DateTimeFormat('th-TH', { dateStyle: 'medium', timeZone: 'Asia/Bangkok' })
const salesTimeFormatter = new Intl.DateTimeFormat('th-TH', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Bangkok' })
const partnerChartLimit = 20
const salesOrderHeaders = [
  { key: 'customer', label: 'Customer' },
  { key: 'store', label: 'Store' },
  { key: 'created_at', label: 'Ordered Date' },
  { key: 'status', label: 'Status' },
  { key: 'amount', label: 'Total Amount', align: 'end' },
  { key: 'payment', label: 'Payment Method' },
]
const payoutPartnerHeaders = [
  { key: 'name', label: 'Partner' },
  { key: 'payout_amount', label: 'Payout', align: 'end' },
  { key: 'claim_count', label: 'Claims', align: 'end' },
  { key: 'approved_count', label: 'Approve', align: 'end' },
  { key: 'rejected_count', label: 'Reject', align: 'end' },
  { key: 'other_status_count', label: 'Other', align: 'end' },
]

const section = computed(() => props.section)
const dashboardTitle = computed(() => sectionLabel.value)
const sectionLabel = computed(() => dashboardSections.value.find((item: any) => item.key === section.value)?.label || translatedDashboardSectionLabel('sales', 'Sales'))
const dashboardSections = computed(() => (summary.value?.sections || fallbackSections).map((item: any) => ({
  ...item,
  label: translatedDashboardSectionLabel(item.key, item.label),
})))
const periodOptions = computed(() => (summary.value?.filter?.options || (section.value === 'payout' ? fallbackPayoutPeriods : fallbackPeriods)).map((item: any) => ({
  ...item,
  label: dashboardPhrase(item.label),
})))
const filterCaption = computed(() => {
  const filter = summary.value?.filter
  if (!filter) return dashboardPhrase('Loading period')
  return `${dashboardPhrase(filter.label)}: ${dashboardPhrase(filter.current?.label || '-')} ${dashboardPhrase('vs')} ${dashboardPhrase(filter.previous?.label || '-')}`
})
const hero = computed(() => {
  const source = summary.value?.hero || {}
  return {
    ...source,
    label: dashboardPhrase(source.label),
    caption: dashboardPhrase(source.caption),
  }
})
const metrics = computed(() => arrayValue(summary.value?.metrics).map((metric: any) => ({
  ...metric,
  label: dashboardPhrase(metric.label),
})))
const primaryMetric = computed(() => metrics.value[0] || {})
const primaryTone = computed(() => primaryMetric.value?.tone || 'primary')
const primaryIcon = computed(() => primaryMetric.value?.icon || 'ri-dashboard-line')
const heroType = computed(() => typeof hero.value?.value === 'object' && hero.value?.value?.amount !== undefined ? 'money' : 'number')
const primarySeries = computed(() => arrayValue(summary.value?.charts?.primary_trend?.series).slice(0, 3).map((series: any) => ({
  ...series,
  label: dashboardPhrase(series.label),
})))
const breakdownRows = computed(() => buildBreakdownRows(summary.value?.charts?.secondary_breakdown))
const primaryRows = computed(() => arrayValue(summary.value?.tables?.top_partners))
const topTenantRows = computed(() => arrayValue(summary.value?.tables?.top_tenants))
const recentRows = computed(() => arrayValue(summary.value?.tables?.recent_rows))
const memberRows = computed(() => arrayValue(summary.value?.tables?.members))
const visitorRows = computed(() => arrayValue(summary.value?.tables?.visitors))
const periodLabel = computed(() => periodOptions.value.find((option: any) => option.key === period.value)?.label || sectionLabel.value)
const salesKpis = computed(() => {
  const preferred = ['tickets_sold', 'sales_amount', 'paid_customers', 'selling_partners']
  const byKey = new Map(metrics.value.map((metric: any) => [metric.key, metric]))
  const selected = preferred.map((key) => byKey.get(key)).filter(Boolean)
  return (selected.length ? selected : metrics.value.slice(0, 4)).map((metric: any, index: number) => ({
    ...metric,
    tone: salesTones[index] || metric.tone || 'primary',
  }))
})
const salesOrderRows = computed(() => recentRows.value.slice(0, 10))
const salesSortedOrderRows = computed(() => [...salesOrderRows.value].sort((left: any, right: any) => compareSalesOrderRows(left, right)))
const setDistributionRows = computed(() => arrayValue(summary.value?.tables?.set_distribution))
const salesBreakdownTotal = computed(() => breakdownRows.value.reduce((total: number, row: any) => total + Number(row.value || 0), 0))
const salesBreakdownRows = computed(() => breakdownRows.value.slice(0, 4).map((row: any, index: number) => {
  const value = Number(row.value || 0)
  return {
    ...row,
    color: salesColors[index % salesColors.length],
    share: salesBreakdownTotal.value > 0 ? Math.round((value / salesBreakdownTotal.value) * 1000) / 10 : 0,
    tone: salesTones[index % salesTones.length],
  }
}))
const salesTopStores = computed(() => {
  const total = topTenantRows.value.reduce((sum: number, row: any) => sum + Number(row.value || 0), 0)
  return topTenantRows.value.slice(0, 6).map((row: any) => ({
    ...row,
    share: total > 0 ? Math.round((Number(row.value || 0) / total) * 10000) / 100 : 0,
  }))
})
const salesStoreBars = computed(() => {
  const rows = salesTopStores.value.slice(0, 4)
  const max = Math.max(...rows.map((row: any) => Number(row.value || 0)), 1)
  return rows.map((row: any, index: number) => ({
    key: row.id || row.name || String(index),
    label: shortLabel(row.name || row.code || `Store ${index + 1}`),
    labelValue: formatNumber(row.order_count || row.customer_count || 0),
    percent: Math.max(10, Math.round((Number(row.value || 0) / max) * 100)),
  }))
})
const popularNumberGroups = computed(() => {
  const numbers = summary.value?.tables?.popular_numbers || {}
  return [
    { key: 'back2', label: dashboardPhrase('2 ท้าย'), rows: arrayValue(numbers.back2) },
    { key: 'back3', label: dashboardPhrase('3 ท้าย'), rows: arrayValue(numbers.back3) },
    { key: 'front3', label: dashboardPhrase('3 หน้า'), rows: arrayValue(numbers.front3) },
  ]
})
const salesRevenueChart = computed(() => summary.value?.charts?.sales_ticket_comparison || summary.value?.charts?.primary_trend || {})
const salesRevenueChartSeries = computed(() => buildApexSeries(salesRevenueChart.value).slice(0, 2))
const salesRevenueChartOptions = computed(() => lineChartOptions(
  arrayValue(salesRevenueChart.value?.labels),
  dashboardPhrase('Tickets sold'),
  (value: any) => `${formatNumber(value)} ${dashboardPhrase('tickets_unit')}`,
  salesRevenueChart.value,
))
const salesPaymentChartSeries = computed(() => salesBreakdownRows.value.map((row: any) => chartScalar(row.value, row.type)))
const salesPaymentChartOptions = computed(() => donutChartOptions(
  salesBreakdownRows.value.map((row: any) => row.label),
  (value: any) => formatChartValue(value, salesBreakdownRows.value[0]?.type || 'money'),
  salesBreakdownRows.value.map((row: any) => row.color),
))
const salesStoreChartSeries = computed(() => [{
  name: dashboardPhrase('Sales'),
  data: salesTopStores.value.slice(0, 8).map((row: any) => chartScalar(row.value, 'money')),
}])
const salesStoreChartOptions = computed(() => horizontalBarChartOptions(
  salesTopStores.value.slice(0, 8).map((row: any) => row.name || row.code || '-'),
  (value: any) => formatChartValue(value, 'money'),
))
const partnerKpis = computed(() => {
  const preferred = ['partner_sales_amount', 'partner_sales_tickets', 'new_partners', 'affiliate_accounts', 'new_affiliate_accounts']
  const byKey = new Map(metrics.value.map((metric: any) => [metric.key, metric]))
  const selected = preferred.map((key) => byKey.get(key)).filter(Boolean)
  return selected.length ? selected : metrics.value.slice(0, 5)
})
const partnerSalesRows = computed(() => arrayValue(summary.value?.charts?.partner_sales_comparison?.rows))
const partnerMemberRows = computed(() => arrayValue(summary.value?.charts?.partner_new_members_comparison?.rows))
const partnerAffiliateRows = computed(() => arrayValue(summary.value?.charts?.partner_affiliate_accounts_comparison?.rows))
const partnerSalesChartRows = computed(() => groupedPartnerChartRows(partnerSalesRows.value, 'value'))
const partnerMemberChartRows = computed(() => groupedPartnerChartRows(partnerMemberRows.value, 'member_count'))
const partnerAffiliateChartRows = computed(() => groupedPartnerChartRows(partnerAffiliateRows.value, 'new_account_count'))
const partnerSalesChartSeries = computed(() => [{
  name: dashboardPhrase('Sales'),
  data: partnerSalesChartRows.value.map((row: any) => chartScalar(row.value, 'money')),
}])
const partnerSalesChartOptions = computed(() => verticalPartnerBarChartOptions(
  partnerSalesChartRows.value.map((row: any) => row.name || row.code || '-'),
  (value: any) => formatChartValue(value, 'money'),
  ['#5b8ff9'],
))
const partnerMembersChartSeries = computed(() => [{
  name: dashboardPhrase('New members'),
  data: partnerMemberChartRows.value.map((row: any) => Number(row.member_count || row.value || 0)),
}])
const partnerMembersChartOptions = computed(() => verticalPartnerBarChartOptions(
  partnerMemberChartRows.value.map((row: any) => row.name || row.code || '-'),
  (value: any) => `${formatNumber(value)} ${dashboardPhrase('people_unit')}`,
  ['#2ecc71'],
))
const partnerAffiliateChartSeries = computed(() => [
  {
    name: dashboardPhrase('Affiliate Account'),
    data: partnerAffiliateChartRows.value.map((row: any) => Number(row.new_account_count || 0)),
  },
])
const partnerAffiliateChartOptions = computed(() => verticalPartnerBarChartOptions(
  partnerAffiliateChartRows.value.map((row: any) => row.name || row.code || '-'),
  (value: any) => formatNumber(value),
  ['#a66bff'],
))
const partnerSalesChartKey = computed(() => partnerChartKey('partner-sales', partnerSalesChartRows.value))
const partnerMembersChartKey = computed(() => partnerChartKey('partner-members', partnerMemberChartRows.value))
const partnerAffiliateChartKey = computed(() => partnerChartKey('partner-affiliates', partnerAffiliateChartRows.value))
const partnerSalesChartScopeLabel = computed(() => partnerChartScopeLabel(partnerSalesRows.value, 'value', 'baht_unit'))
const partnerMembersChartScopeLabel = computed(() => partnerChartScopeLabel(partnerMemberRows.value, 'member_count', 'people_unit'))
const partnerAffiliateChartScopeLabel = computed(() => partnerChartScopeLabel(partnerAffiliateRows.value, 'new_account_count', 'Accounts'))
const partnerDashboardKey = computed(() => `partner-dashboard:${period.value}:${summaryRevision.value}`)
const payoutRewardKpis = computed(() => selectMetrics(['reward_payouts', 'winning_liability', 'winning_tickets', 'pending_claims'], 4))
const payoutCommissionKpis = computed(() => selectMetrics(['commissions', 'commission_transactions', 'affiliate_payouts'], 3))
const payoutPartnerRows = computed(() => arrayValue(summary.value?.charts?.partner_payout_comparison?.rows || summary.value?.tables?.top_partners))
const payoutPartnerChartRows = computed(() => groupedPartnerChartRows(payoutPartnerRows.value, 'value'))
const payoutPartnerChartSeries = computed(() => [{
  name: dashboardPhrase('Reward payout'),
  data: payoutPartnerChartRows.value.map((row: any) => chartScalar(row.value, 'money')),
}])
const payoutPartnerChartOptions = computed(() => verticalPartnerBarChartOptions(
  payoutPartnerChartRows.value.map((row: any) => row.name || row.code || '-'),
  (value: any) => formatChartValue(value, 'money'),
  ['#5b8ff9'],
))
const payoutPartnerChartKey = computed(() => partnerChartKey('payout-partners', payoutPartnerChartRows.value))
const payoutPartnerChartScopeLabel = computed(() => partnerChartScopeLabel(payoutPartnerRows.value, 'value', 'baht_unit'))
const sortedPayoutPartnerRows = computed(() => [...payoutPartnerRows.value].sort((left: any, right: any) => comparePayoutPartnerRows(left, right)))
const winningTypeRows = computed(() => arrayValue(summary.value?.charts?.winning_type_breakdown))
const winningTypeChartSeries = computed(() => [{
  name: dashboardPhrase('Winning tickets'),
  data: winningTypeRows.value.map((row: any) => Number(row.ticket_count || 0)),
}])
const winningTypeChartOptions = computed(() => barChartOptions(
  winningTypeRows.value.map((row: any) => dashboardPhrase(row.label || '-')),
  (value: any) => `${formatNumber(value)} ${dashboardPhrase('tickets_unit')}`,
))
const payoutCommissionRows = computed(() => arrayValue(summary.value?.charts?.partner_commission_comparison?.rows || summary.value?.tables?.commission_partners))
const payoutCommissionChartRows = computed(() => groupedPartnerChartRows(payoutCommissionRows.value, 'value'))
const payoutCommissionChartSeries = computed(() => [{
  name: dashboardPhrase('Commission'),
  data: payoutCommissionChartRows.value.map((row: any) => chartScalar(row.value, 'money')),
}])
const payoutCommissionChartOptions = computed(() => verticalPartnerBarChartOptions(
  payoutCommissionChartRows.value.map((row: any) => row.name || row.code || '-'),
  (value: any) => formatChartValue(value, 'money'),
  ['#2ecc71'],
))
const payoutCommissionChartKey = computed(() => partnerChartKey('payout-commissions', payoutCommissionChartRows.value))
const payoutCommissionChartScopeLabel = computed(() => partnerChartScopeLabel(payoutCommissionRows.value, 'value', 'baht_unit'))
const genericTrendChartSeries = computed(() => buildApexSeries(summary.value?.charts?.primary_trend).slice(0, 3))
const genericTrendType = computed(() => arrayValue(summary.value?.charts?.primary_trend?.series)[0]?.type || 'number')
const genericTrendChartOptions = computed(() => barChartOptions(
  arrayValue(summary.value?.charts?.primary_trend?.labels),
  (value: any) => formatChartValue(value, genericTrendType.value),
))
const breakdownType = computed(() => breakdownRows.value[0]?.type || 'number')
const breakdownChartSeries = computed(() => breakdownRows.value.map((row: any) => chartScalar(row.value, row.type)))
const breakdownChartOptions = computed(() => donutChartOptions(
  breakdownRows.value.map((row: any) => row.label),
  (value: any) => formatChartValue(value, breakdownType.value),
))
const entityChartRows = computed(() => primaryRows.value.slice(0, 8))
const entityChartType = computed(() => section.value === 'monitor' ? 'number' : 'money')
const entityChartSeries = computed(() => [{
  name: primaryValueHeader.value,
  data: entityChartRows.value.map((row: any) => chartScalar(row.value, entityChartType.value)),
}])
const entityChartOptions = computed(() => horizontalBarChartOptions(
  entityChartRows.value.map((row: any) => row.name || row.label || row.title || row.code || '-'),
  (value: any) => formatChartValue(value, entityChartType.value),
))

const primaryChartTitle = computed(() => dashboardPhrase(({
  sales: 'Sales revenue',
  partner: 'Partner growth',
  wallet: 'Wallet money flow',
  payout: 'Payout trend',
  monitor: 'Usage activity',
})[section.value]))
const primaryChartSubtitle = computed(() => dashboardPhrase(({
  sales: 'Revenue, tickets, and paid order movement.',
  partner: 'New members, partners, and partner stores.',
  wallet: 'Wallet inflow, outflow, and topup movement.',
  payout: 'Reward payouts, winning liability, and commissions.',
  monitor: 'Guest, member, and admin session activity.',
})[section.value]))
const breakdownTitle = computed(() => dashboardPhrase(({
  sales: 'Payment methods',
  partner: 'Affiliate statuses',
  wallet: 'Topup channels',
  payout: 'Claim statuses',
  monitor: 'Traffic sources',
})[section.value]))
const primaryTableTitle = computed(() => dashboardPhrase(({
  sales: 'Top partners by sales',
  partner: 'Partner performance',
  wallet: 'Top stores by wallet flow',
  payout: 'Top partners by payout',
  monitor: 'Active partner stores',
})[section.value]))
const recentTableTitle = computed(() => dashboardPhrase(({
  sales: 'Recent paid orders',
  partner: 'Recent partners',
  wallet: 'Recent wallet ledger',
  payout: 'Recent reward claims',
  monitor: 'Online admins and owner partners',
})[section.value]))
const primaryValueHeader = computed(() => dashboardPhrase(({
  sales: 'Sales',
  partner: 'Sales',
  wallet: 'Inflow',
  payout: 'Payout',
  monitor: 'Online',
})[section.value]))
const entityChartTitle = computed(() => dashboardPhrase(({
  sales: 'Top performance',
  partner: 'Partner sales ranking',
  wallet: 'Wallet flow by store',
  payout: 'Reward payout by partner',
  monitor: 'Active partner stores',
})[section.value]))
const entityChartSubtitle = computed(() => dashboardPhrase(({
  sales: 'Leading partners and stores for the selected period.',
  partner: 'Partners ranked by paid lottery sales in the selected period.',
  wallet: 'Stores with the highest wallet inflow in the selected period.',
  payout: 'Partners with the highest reward payout amount in the selected period.',
  monitor: 'Stores with live member or guest activity in the last 15 minutes.',
})[section.value]))

watch(() => route.query.period, (value) => {
  const next = allowedPeriods.has(String(value || '')) ? String(value) : defaultPeriodForSection(props.section)
  if (next !== period.value) {
    period.value = next
    void load()
  }
})

watch(() => props.section, () => {
  if (!allowedPeriods.has(period.value)) {
    period.value = defaultPeriodForSection(props.section)
  }
  void load()
})

onMounted(load)

async function load() {
  const sequence = ++loadSequence
  const requestedPeriod = period.value
  loading.value = true
  error.value = null
  try {
    const response = await api.apiFetch(`/admin/central/dashboard/${props.section}/summary`, {
      scope: 'central',
      query: { period: requestedPeriod },
    })
    if (sequence !== loadSequence) return
    summary.value = response
    summaryRevision.value += 1
    const responsePeriod = String(response?.filter?.period || '')
    if (allowedPeriods.has(responsePeriod) && responsePeriod !== period.value) {
      period.value = responsePeriod
      void router.replace({ query: { ...route.query, period: responsePeriod } })
    }
  } catch (err) {
    if (sequence !== loadSequence) return
    error.value = err
  } finally {
    if (sequence === loadSequence) {
      loading.value = false
    }
  }
}

async function setPeriod(value: string) {
  if (!allowedPeriods.has(value) || value === period.value) return
  period.value = value
  await router.replace({ query: { ...route.query, period: value } })
  await load()
}

function setSalesOrderSort(key: string) {
  salesOrderSort.value = {
    key,
    direction: salesOrderSort.value.key === key && salesOrderSort.value.direction === 'asc' ? 'desc' : 'asc',
  }
}

function setPayoutPartnerSort(key: string) {
  payoutPartnerSort.value = {
    key,
    direction: payoutPartnerSort.value.key === key && payoutPartnerSort.value.direction === 'asc' ? 'desc' : 'asc',
  }
}

function salesOrderSortIcon(key: string) {
  if (salesOrderSort.value.key !== key) return 'ri-arrow-up-down-line'

  return salesOrderSort.value.direction === 'asc' ? 'ri-arrow-up-s-line' : 'ri-arrow-down-s-line'
}

function payoutPartnerSortIcon(key: string) {
  if (payoutPartnerSort.value.key !== key) return 'ri-arrow-up-down-line'

  return payoutPartnerSort.value.direction === 'asc' ? 'ri-arrow-up-s-line' : 'ri-arrow-down-s-line'
}

function compareSalesOrderRows(left: any, right: any) {
  const key = salesOrderSort.value.key
  const direction = salesOrderSort.value.direction === 'asc' ? 1 : -1
  const leftValue = salesOrderSortValue(left, key)
  const rightValue = salesOrderSortValue(right, key)

  if (typeof leftValue === 'number' && typeof rightValue === 'number') {
    return (leftValue - rightValue) * direction
  }

  return String(leftValue).localeCompare(String(rightValue), 'th') * direction
}

function salesOrderSortValue(row: any, key: string) {
  return {
    customer: salesOrderCustomer(row),
    store: salesOrderStore(row),
    created_at: new Date(row?.created_at || 0).getTime() || 0,
    status: row?.status || '',
    amount: Number(row?.amount?.amount ?? row?.amount ?? 0),
    payment: row?.meta || '',
  }[key] ?? ''
}

function comparePayoutPartnerRows(left: any, right: any) {
  const key = payoutPartnerSort.value.key
  const direction = payoutPartnerSort.value.direction === 'asc' ? 1 : -1
  const leftValue = payoutPartnerSortValue(left, key)
  const rightValue = payoutPartnerSortValue(right, key)

  if (typeof leftValue === 'number' && typeof rightValue === 'number') {
    return (leftValue - rightValue) * direction
  }

  return String(leftValue).localeCompare(String(rightValue), 'th') * direction
}

function payoutPartnerSortValue(row: any, key: string) {
  return {
    name: row?.name || row?.code || '',
    payout_amount: Number(row?.payout_amount?.amount ?? row?.value ?? 0),
    claim_count: Number(row?.claim_count || 0),
    approved_count: Number(row?.approved_count || 0),
    rejected_count: Number(row?.rejected_count || 0),
    other_status_count: Number(row?.other_status_count || 0),
  }[key] ?? ''
}

function buildApexSeries(chart: any) {
  return arrayValue(chart?.series).map((item: any, index: number) => ({
    name: dashboardPhrase(item.label || `Series ${index + 1}`),
    data: arrayValue(item.values).map((value: any) => chartScalar(value, item.type)),
  }))
}

function lineChartOptions(categories: any[], title: string, formatter: (value: any) => string, chart: any = null) {
  return {
    colors: salesColors.slice(0, 2),
    dataLabels: { enabled: false },
    fill: {
      type: 'gradient',
      gradient: { opacityFrom: 0.24, opacityTo: 0.04, stops: [0, 90, 100] },
    },
    grid: { borderColor: '#edf1f7', strokeDashArray: 4 },
    legend: { position: 'top', horizontalAlign: 'center', fontSize: '12px', markers: { radius: 8 } },
    stroke: { curve: 'straight', width: 2.5 },
    tooltip: {
      x: { formatter: (value: any, options: any) => salesRevenueTooltipLabel(value, options?.dataPointIndex, chart) },
      y: { formatter, title: { formatter: (seriesName: string) => `${seriesName}:` } },
    },
    xaxis: {
      categories,
      axisBorder: { show: false },
      axisTicks: { show: false },
      labels: { rotate: 0, trim: true, style: { colors: '#7b8aa0', fontSize: '11px' } },
    },
    yaxis: {
      title: { text: title, style: { color: '#7b8aa0', fontSize: '11px', fontWeight: 500 } },
      labels: { formatter, style: { colors: '#7b8aa0', fontSize: '11px' } },
    },
  }
}

function salesRevenueTooltipLabel(value: any, index: number, chart: any) {
  if (!chart || chart.comparison_mode !== 'sale_day') return String(value || '-')

  const currentLabel = arrayValue(chart.current_date_labels)[index]
  const previousLabel = arrayValue(chart.previous_date_labels)[index]
  if (!currentLabel && !previousLabel) return String(value || '-')

  return `${value || '-'} · ${dashboardPhrase('Current')} ${currentLabel || '-'} · ${dashboardPhrase('Previous')} ${previousLabel || '-'}`
}

function barChartOptions(categories: any[], formatter: (value: any) => string) {
  return {
    colors: salesColors.slice(0, 3),
    dataLabels: { enabled: false },
    grid: { borderColor: '#edf1f7', strokeDashArray: 4 },
    legend: { position: 'top', fontSize: '12px' },
    plotOptions: { bar: { borderRadius: 4, columnWidth: '48%' } },
    tooltip: { y: { formatter } },
    xaxis: {
      categories,
      axisBorder: { show: false },
      axisTicks: { show: false },
      labels: { rotate: 0, trim: true, style: { colors: '#7b8aa0', fontSize: '11px' } },
    },
    yaxis: { labels: { formatter, style: { colors: '#7b8aa0', fontSize: '11px' } } },
  }
}

function horizontalBarChartOptions(categories: any[], formatter: (value: any) => string, colors = ['#5b8ff9']) {
  return {
    colors,
    dataLabels: { enabled: true, formatter, style: { fontSize: '11px', fontWeight: 600 } },
    grid: { borderColor: '#edf1f7', strokeDashArray: 4 },
    legend: { show: colors.length > 1, position: 'top', fontSize: '12px' },
    plotOptions: { bar: { borderRadius: 4, barHeight: '50%', horizontal: true } },
    tooltip: { y: { formatter } },
    xaxis: {
      categories,
      labels: { formatter, style: { colors: '#7b8aa0', fontSize: '11px' } },
    },
    yaxis: {
      labels: {
        maxWidth: 120,
        formatter: (value: any) => ellipsisLabel(value, 18),
        style: { colors: '#202938', fontSize: '12px', fontWeight: 600 },
      },
    },
  }
}

function verticalPartnerBarChartOptions(categories: any[], formatter: (value: any) => string, colors = ['#5b8ff9']) {
  return {
    colors,
    dataLabels: { enabled: false },
    grid: { borderColor: '#edf1f7', strokeDashArray: 4 },
    legend: { show: false },
    plotOptions: { bar: { borderRadius: 4, columnWidth: categories.length > 12 ? '42%' : '54%' } },
    tooltip: { y: { formatter } },
    xaxis: {
      categories,
      axisBorder: { show: false },
      axisTicks: { show: false },
      labels: {
        hideOverlappingLabels: true,
        maxHeight: 96,
        rotate: -45,
        rotateAlways: categories.length > 8,
        trim: true,
        style: { colors: '#7b8aa0', fontSize: '11px' },
      },
    },
    yaxis: {
      labels: { formatter, style: { colors: '#7b8aa0', fontSize: '11px' } },
    },
  }
}

function donutChartOptions(labels: string[], formatter: (value: any) => string, colors = salesColors) {
  return {
    colors,
    dataLabels: {
      enabled: true,
      formatter: (value: any) => `${formatNumber(value)}%`,
      style: { fontSize: '11px', fontWeight: 600 },
    },
    labels,
    legend: { position: 'bottom', fontSize: '12px', markers: { radius: 8 } },
    plotOptions: {
      pie: {
        donut: {
          size: '68%',
          labels: {
            show: true,
            name: { show: true },
            value: { show: true, formatter },
            total: {
              show: true,
              label: dashboardPhrase('Total'),
              formatter: (chart: any) => formatter(chart.globals.seriesTotals.reduce((sum: number, value: number) => sum + value, 0)),
            },
          },
        },
      },
    },
    stroke: { width: 0 },
    tooltip: { y: { formatter } },
  }
}

function buildBreakdownRows(rows: any) {
  const values = arrayValue(rows)
  const max = Math.max(...values.map((row: any) => Number(row.value || 0)), 1)
  return values.map((row: any) => ({
    ...row,
    label: dashboardPhrase(payoutBreakdownLabel(row.label)),
    percent: Math.max(4, Math.round((Number(row.value || 0) / max) * 100)),
  }))
}

function payoutBreakdownLabel(label: any) {
  if (section.value !== 'payout') return label

  return {
    Paid: 'Paid payout',
  }[String(label || '')] || label
}

function selectMetrics(keys: string[], fallbackLimit: number) {
  const byKey = new Map(metrics.value.map((metric: any) => [metric.key, metric]))
  const selected = keys.map((key) => byKey.get(key)).filter(Boolean)

  return selected.length ? selected : metrics.value.slice(0, fallbackLimit)
}

function salesMetricLabel(metric: any) {
  const label = {
    tickets_sold: 'Tickets sold',
    sales_amount: 'Sales amount',
    paid_customers: 'Paid customers',
    selling_partners: 'Selling partners',
    paid_orders: 'Paid orders',
    average_order: 'Average order',
  }[metric?.key] || metric?.label || '-'

  return dashboardPhrase(label)
}

function salesMetricValue(metric: any) {
  const value = formatMetricValue(metric?.current, metric?.type)

  return {
    tickets_sold: `${value} ${dashboardPhrase('tickets_unit')}`,
    paid_customers: `${value} ${dashboardPhrase('people_unit')}`,
  }[metric?.key] || value
}

function partnerMetricValue(metric: any) {
  const value = formatMetricValue(metric?.current, metric?.type)

  return {
    partner_sales_tickets: `${value} ${dashboardPhrase('tickets_unit')}`,
  }[metric?.key] || value
}

function partnerMetricLabel(metric: any) {
  const label = {
    partner_sales_amount: { en: 'Partner sales amount', th: 'ยอดขายของพาร์ทเนอร์ทั้งหมด' },
    partner_sales_tickets: { en: 'Partner tickets sold', th: 'จำนวนสลากที่พาร์ทเนอร์ขายได้' },
    new_partners: { en: 'New partners', th: 'พาร์ทเนอร์ใหม่' },
    affiliate_accounts: { en: 'Affiliate accounts', th: 'บัญชีผู้แนะนำ' },
    new_affiliate_accounts: { en: 'New affiliate accounts', th: 'บัญชีผู้แนะนำใหม่' },
  }[metric?.key] || metric?.label || '-'

  if (typeof label === 'object') {
    return locale.value === 'th-TH' ? label.th : label.en
  }

  return dashboardPhrase(label)
}

function salesMetricTextClass(tone: string) {
  return {
    primary: 'text-primary',
    secondary: 'text-secondary',
    success: 'text-success',
    info: 'text-info',
    warning: 'text-warning',
    danger: 'text-danger',
    pink: 'text-pink',
  }[tone] || 'text-primary'
}

function deltaPercentLabel(delta: any) {
  if (!delta || delta.percent === null || delta.percent === undefined) {
    return Number(delta?.amount || 0) > 0 ? 'New' : 'Live'
  }

  const percent = Number(delta.percent || 0)
  const sign = percent > 0 ? '+' : ''
  return `${sign}${formatNumber(percent)}%`
}

function popularNumberDeltaLabel(row: any) {
  const percent = row?.ticket_count_delta_percent
  if (percent === null || percent === undefined) {
    return Number(row?.previous_ticket_count || 0) === 0 && Number(row?.ticket_count || row?.value || 0) > 0 ? dashboardPhrase('New') : '0%'
  }

  const value = Number(percent || 0)
  const sign = value > 0 ? '+' : ''
  return `${sign}${formatNumber(value)}%`
}

function popularNumberDeltaClass(row: any) {
  const direction = row?.ticket_count_delta_direction
  if (direction === 'up') return 'is-up'
  if (direction === 'down') return 'is-down'
  return 'is-flat'
}

function popularNumberDeltaTitle(row: any) {
  return `${dashboardPhrase('Previous')}: ${formatNumber(row?.previous_ticket_count || 0)} ${dashboardPhrase('tickets_unit')}`
}

function setDistributionDeltaLabel(row: any) {
  const percent = row?.sold_set_delta_percent
  if (percent === null || percent === undefined) {
    return Number(row?.previous_sold_set_count || 0) === 0 && Number(row?.sold_set_count || 0) > 0 ? dashboardPhrase('New') : '0%'
  }

  const value = Number(percent || 0)
  const sign = value > 0 ? '+' : ''
  return `${sign}${formatNumber(value)}%`
}

function setDistributionDeltaClass(row: any) {
  const direction = row?.sold_set_delta_direction
  if (direction === 'up') return 'is-up'
  if (direction === 'down') return 'is-down'
  return 'is-flat'
}

function setDistributionDeltaTitle(row: any) {
  return `${dashboardPhrase('Current')}: ${formatNumber(row?.sold_set_count || 0)} ${dashboardPhrase('sets_unit')} / ${dashboardPhrase('Previous')}: ${formatNumber(row?.previous_sold_set_count || 0)} ${dashboardPhrase('sets_unit')}`
}

function partnerRowDeltaLabel(row: any, prefix: string) {
  const percent = row?.[`${prefix}_delta_percent`]
  if (percent === null || percent === undefined) {
    const previous = Number(row?.[`previous_${prefix}_count`] ?? row?.[`previous_${prefix}_amount`]?.amount ?? 0)
    const current = Number(row?.[`${prefix}_count`] ?? row?.value ?? 0)
    return previous === 0 && current > 0 ? dashboardPhrase('New') : '0%'
  }

  const value = Number(percent || 0)
  const sign = value > 0 ? '+' : ''
  return `${sign}${formatNumber(value)}%`
}

function partnerRowDeltaClass(row: any, prefix: string) {
  const direction = row?.[`${prefix}_delta_direction`]
  if (direction === 'up') return 'is-up'
  if (direction === 'down') return 'is-down'
  return 'is-flat'
}

function salesOrderStore(row: any) {
  const parts = String(row?.subtitle || '').split(' · ').filter(Boolean)
  return parts[0] || '-'
}

function salesOrderCustomer(row: any) {
  const parts = String(row?.subtitle || '').split(' · ').filter(Boolean)
  return parts.slice(1).join(' · ') || parts[0] || 'Customer'
}

function initials(value: any) {
  const text = String(value || '').trim()
  if (!text) return 'OR'
  const parts = text.split(/\s+/).filter(Boolean)
  return (parts.length > 1 ? `${parts[0][0]}${parts[1][0]}` : text.slice(0, 2)).toUpperCase()
}

function formatSalesDate(value: any) {
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '-' : salesDateFormatter.format(date)
}

function formatSalesTime(value: any) {
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '-' : salesTimeFormatter.format(date)
}

function shortLabel(value: any) {
  const text = String(value || '-').trim()
  return text.length > 10 ? `${text.slice(0, 10)}...` : text
}

function ellipsisLabel(value: any, limit = 16) {
  const text = String(value || '-').trim()
  return text.length > limit ? `${text.slice(0, Math.max(1, limit - 3))}...` : text
}

function rowMoney(row: any) {
  const value = row.sales_amount || row.inflow_amount || row.payout_amount || row.amount
  if (value) return formatDashboardMoney(value)
  return formatNumber(row.value || 0)
}

function formatDashboardMoney(value: any) {
  return localizeMoneyText(formatMoney(value))
}

function deltaLabel(delta: any, type: string, compact = false) {
  if (!delta || delta.amount === null || delta.amount === undefined) return compact ? 'Live' : 'No baseline'
  const sign = Number(delta.amount || 0) > 0 ? '+' : ''
  const percent = delta.percent === null || delta.percent === undefined ? '' : ` (${sign}${formatNumber(delta.percent)}%)`
  return `${sign}${formatMetricValue(delta.amount, type)}${percent}`
}

function formatMetricValue(value: any, type = 'number') {
  if (value === null || value === undefined) return '-'
  if (type === 'money') return localizeMoneyText(formatMoney(toMoneyValue(value)))
  if (typeof value === 'object' && value?.amount !== undefined) return localizeMoneyText(formatMoney(value))
  return formatNumber(value)
}

function formatAnyValue(value: any, type = 'number') {
  return type === 'money' ? localizeMoneyText(formatMoney(toMoneyValue(value))) : formatNumber(value)
}

function chartScalar(value: any, type = 'number') {
  const number = Number(typeof value === 'object' && value?.amount !== undefined ? value.amount : value || 0)
  return type === 'money' ? number / 100 : number
}

function formatChartValue(value: any, type = 'number') {
  return type === 'money' ? `${formatNumber(value)} ${dashboardPhrase('baht_unit')}` : formatNumber(value)
}

function localizeMoneyText(value: string) {
  return String(value || '').replace(/\s*บาท/g, ` ${dashboardPhrase('baht_unit')}`)
}

function dashboardPhrase(value: any) {
  return phrase(String(value || '').replace(/\s+/g, ' ').trim())
}

function groupedPartnerChartRows(rows: any[], valueKey: string) {
  const activeRows = rows
    .filter((row: any) => partnerChartNumericValue(row, valueKey) > 0)
    .sort((left: any, right: any) => partnerChartNumericValue(right, valueKey) - partnerChartNumericValue(left, valueKey))
  const visibleRows = activeRows.slice(0, partnerChartLimit)
  const overflowRows = activeRows.slice(partnerChartLimit)

  if (!overflowRows.length) return visibleRows

  const overflowValue = overflowRows.reduce((sum: number, row: any) => sum + partnerChartNumericValue(row, valueKey), 0)
  return [
    ...visibleRows,
    {
      id: `others-${valueKey}`,
      code: `${overflowRows.length} ${dashboardPhrase('partners_unit')}`,
      name: dashboardPhrase('Others'),
      value: overflowValue,
      [valueKey]: overflowValue,
    },
  ]
}

function partnerChartScopeLabel(rows: any[], valueKey: string, unit: string) {
  const activeCount = rows.filter((row: any) => partnerChartNumericValue(row, valueKey) > 0).length
  const scope = activeCount > partnerChartLimit
    ? `${dashboardPhrase('Top')} ${partnerChartLimit} + ${dashboardPhrase('Others')}`
    : `${formatNumber(activeCount)} ${dashboardPhrase('Partners')}`

  return `${scope} · ${dashboardPhrase(unit)}`
}

function setSizeLabel(setSize: any) {
  return `${dashboardPhrase('Set')} ${formatNumber(setSize || 0)} ${dashboardPhrase('tickets_unit')}`
}

function partnerChartNumericValue(row: any, valueKey: string) {
  return Number(row?.[valueKey] ?? row?.value ?? 0)
}

function partnerChartKey(prefix: string, rows: any[]) {
  const rowKey = rows.map((row: any) => [
    row.id || row.code || row.name || '-',
    row.value ?? 0,
    row.previous_sales_amount?.amount ?? row.previous_sales_amount ?? 0,
    row.sales_delta ?? 0,
    row.ticket_count ?? 0,
    row.previous_ticket_count ?? 0,
    row.member_count ?? 0,
    row.previous_member_count ?? 0,
    row.account_count ?? 0,
    row.previous_account_count ?? 0,
    row.new_account_count ?? 0,
    row.previous_new_account_count ?? 0,
  ].join(':')).join('|')

  return `${prefix}:${period.value}:${summaryRevision.value}:${rowKey}`
}

function toMoneyValue(value: any) {
  if (typeof value === 'object' && value?.amount !== undefined) return value
  return { amount: Number(value || 0), currency: 'THB' }
}

function formatNumber(value: any) {
  const number = Number(value || 0)
  return Number.isFinite(number) ? number.toLocaleString('th-TH', { maximumFractionDigits: 2 }) : String(value)
}

function defaultPeriodForSection(value: string) {
  return value === 'payout' ? 'current_draw' : 'today'
}

function arrayValue(value: any) {
  return Array.isArray(value) ? value : []
}

function toneClass(tone: string) {
  return {
    primary: 'bg-primary-transparent text-primary',
    success: 'bg-success-transparent text-success',
    info: 'bg-info-transparent text-info',
    warning: 'bg-warning-transparent text-warning',
    danger: 'bg-danger-transparent text-danger',
    secondary: 'bg-secondary-transparent text-secondary',
    pink: 'bg-pink-transparent text-pink',
  }[tone] || 'bg-primary-transparent text-primary'
}

function directionClass(direction: string) {
  if (direction === 'up') return 'text-success'
  if (direction === 'down') return 'text-danger'
  return 'text-muted'
}

const fallbackSections = [
  { key: 'sales', label: 'Sales', route: '/admin/central/dashboard/sales', icon: 'ri-line-chart-line' },
  { key: 'partner', label: 'Partner', route: '/admin/central/dashboard/partner', icon: 'ri-building-4-line' },
  { key: 'wallet', label: 'Wallet', route: '/admin/central/dashboard/wallet', icon: 'ri-wallet-3-line' },
  { key: 'payout', label: 'Payout', route: '/admin/central/dashboard/payout', icon: 'ri-bank-card-line' },
  { key: 'monitor', label: 'Monitor', route: '/admin/central/dashboard/monitor', icon: 'ri-pulse-line' },
]
const fallbackPeriods = [
  { key: 'today', label: 'Today' },
  { key: 'yesterday', label: 'Yesterday' },
  { key: 'last_7_days', label: 'Last 7 days' },
  { key: 'previous_draw', label: 'Previous draw' },
]
const fallbackPayoutPeriods = [
  { key: 'current_draw', label: 'This draw' },
  { key: 'previous_draw', label: 'Previous draw' },
  { key: 'this_month', label: 'This month' },
  { key: 'this_year', label: 'This year' },
]

function translatedDashboardSectionLabel(key: string, fallback: string) {
  const translationKey = `menus.items.central.dashboard_${key}`
  const translated = t(translationKey)

  return translated !== translationKey ? translated : fallback
}
</script>

<style scoped>
.np-dashboard-toolbar {
  align-items: center;
  display: flex;
  flex-wrap: wrap;
  gap: .75rem;
  justify-content: space-between;
  margin-bottom: 1rem;
}

.np-dashboard-tabs,
.np-dashboard-periods {
  display: flex;
  flex-wrap: wrap;
  gap: .5rem;
}

.np-dashboard-tab,
.np-dashboard-period {
  align-items: center;
  background: var(--custom-white);
  border: 1px solid var(--default-border);
  border-radius: 6px;
  color: var(--default-text-color);
  display: inline-flex;
  font-size: .8125rem;
  font-weight: 600;
  gap: .375rem;
  min-height: 2.25rem;
  padding: .45rem .75rem;
}

.np-dashboard-period {
  cursor: pointer;
}

.np-dashboard-tab.active,
.np-dashboard-period.active {
  background: var(--primary-color);
  border-color: var(--primary-color);
  color: #fff;
}

.np-dashboard-hero h2 {
  color: var(--primary-color);
  font-size: 2.2rem;
  font-weight: 800;
  line-height: 1.1;
  overflow-wrap: anywhere;
}

.np-dashboard-hero-icon,
.np-dashboard-kpi-icon {
  align-items: center;
  border-radius: 6px;
  display: inline-flex;
  flex: 0 0 auto;
  height: 2.75rem;
  justify-content: center;
  width: 2.75rem;
}

.np-dashboard-hero-icon i,
.np-dashboard-kpi-icon i {
  font-size: 1.35rem;
}

.np-dashboard-compare {
  border-top: 1px solid var(--default-border);
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  padding-top: 1rem;
}

.np-dashboard-compare span,
.np-dashboard-kpi p,
.np-dashboard-kpi small {
  font-size: .8125rem;
}

.np-dashboard-compare strong,
.np-dashboard-kpi h5 {
  overflow-wrap: anywhere;
}

.np-dashboard-delta {
  font-size: .75rem;
  font-weight: 700;
  text-align: end;
}

.np-dashboard-breakdown,
.np-dashboard-list {
  display: grid;
  gap: .875rem;
}

.np-dashboard-breakdown-row span {
  overflow-wrap: anywhere;
}

.np-dashboard-progress {
  height: .45rem;
}

.np-dashboard-empty {
  align-items: center;
  color: var(--text-muted);
  display: flex;
  min-height: 8rem;
}

.min-w-0 {
  min-width: 0;
}

.np-sales-dashboard .custom-card,
.np-partner-dashboard .custom-card,
.np-wallet-dashboard .custom-card,
.np-payout-dashboard .custom-card,
.np-monitor-dashboard .custom-card {
  border-radius: 8px;
  margin-bottom: 0;
}

.np-dashboard-section-title {
  color: var(--default-text-color);
  font-size: .95rem;
  font-weight: 700;
  line-height: 1.25;
}

.np-payout-dashboard .table td,
.np-payout-dashboard .table th,
.np-monitor-dashboard .table td,
.np-monitor-dashboard .table th {
  vertical-align: middle;
}

.np-sales-kpi-card .card-body {
  min-height: 6.875rem;
}

.np-sales-kpi-avatar,
.np-sales-mini-icon {
  align-items: center;
  border-radius: 6px;
  display: inline-flex;
  flex: 0 0 auto;
  height: 2.75rem;
  justify-content: center;
  width: 2.75rem;
}

.np-sales-kpi-avatar i {
  font-size: 1.35rem;
}

.np-sales-card-label {
  overflow-wrap: anywhere;
}

.np-sales-chart-card .card-body {
  min-height: 26.25rem;
}

.np-sales-grid-lines line {
  stroke: var(--default-border);
  stroke-dasharray: 6 8;
  stroke-width: 1;
}

.np-sales-donut-card .card-body {
  display: flex;
  justify-content: center;
  min-height: 15.5rem;
}

.np-sales-country-list {
  display: grid;
}

.np-sales-country-row {
  align-items: center;
  border-bottom: 1px solid var(--default-border);
  display: grid;
  gap: .75rem;
  grid-template-columns: auto minmax(0, 1fr) auto auto;
  min-height: 3.6rem;
  padding: .75rem 1rem;
}

.np-sales-country-row:last-child {
  border-bottom: 0;
}

.np-sales-dot,
.np-sales-neutral-avatar {
  background: #c9c9c9;
}

.np-sales-dot {
  border-radius: 50%;
  display: inline-block;
  height: 1.25rem;
  width: 1.25rem;
}

.np-sales-mini-icon {
  height: 2rem;
  width: 2rem;
}

.np-sales-stat-row {
  align-items: center;
  border-bottom: 1px solid var(--default-border);
  display: flex;
  justify-content: space-between;
  min-height: 4.65rem;
  padding: .875rem 1rem;
}

.np-sales-stat-row:last-child {
  border-bottom: 0;
}

.np-sales-spark {
  flex: 0 0 7.5rem;
  height: 2.25rem;
  width: 7.5rem;
}

.np-sales-search-like {
  color: var(--text-muted);
  max-width: 12rem;
  pointer-events: none;
}

.np-sales-sort-button {
  align-items: center;
  background: transparent;
  border: 0;
  color: inherit;
  display: inline-flex;
  font: inherit;
  font-weight: 700;
  gap: .25rem;
  padding: 0;
}

.np-sales-sort-button i {
  color: var(--text-muted);
  font-size: 1rem;
}

.np-sales-sort-button.active i {
  color: var(--primary-color);
}

.np-sales-banner {
  min-height: 10.25rem;
}

.np-sales-banner p {
  font-size: .8125rem;
}

.np-sales-banner-icon {
  align-items: center;
  background: rgba(var(--primary-rgb), .1);
  border-radius: 8px;
  color: var(--primary-color);
  display: inline-flex;
  flex: 0 0 auto;
  height: 4.25rem;
  justify-content: center;
  width: 4.25rem;
}

.np-sales-banner-icon i {
  font-size: 2rem;
}

.np-sales-transaction-list {
  display: grid;
  gap: 1.15rem;
}

.np-sales-popular-group {
  border: 1px solid var(--default-border);
  border-radius: 8px;
  min-height: 100%;
  padding: .875rem;
}

.np-sales-popular-list {
  display: grid;
  gap: .45rem;
}

.np-sales-popular-row {
  align-items: center;
  background: var(--light);
  border-radius: 6px;
  display: grid;
  gap: .6rem;
  grid-template-columns: 1.65rem minmax(0, 1fr) auto auto;
  min-height: 2.35rem;
  padding: .35rem .55rem;
}

.np-sales-popular-row strong {
  font-size: 1rem;
  letter-spacing: .08em;
}

.np-sales-popular-count {
  color: var(--text-muted);
  font-size: .75rem;
  font-weight: 600;
  white-space: nowrap;
}

.np-sales-popular-delta {
  border-radius: 999px;
  font-size: .68rem;
  font-weight: 800;
  line-height: 1;
  min-width: 3.25rem;
  padding: .28rem .45rem;
  text-align: center;
  white-space: nowrap;
}

.np-sales-popular-delta.is-up {
  background: rgba(var(--success-rgb), .12);
  color: var(--success-color);
}

.np-sales-popular-delta.is-down {
  background: rgba(var(--danger-rgb), .12);
  color: var(--danger-color);
}

.np-sales-popular-delta.is-flat {
  background: rgba(var(--secondary-rgb), .12);
  color: var(--text-muted);
}

.np-sales-set-delta {
  border-radius: 999px;
  display: inline-flex;
  font-size: .68rem;
  font-weight: 800;
  justify-content: center;
  line-height: 1;
  min-width: 3.25rem;
  padding: .28rem .45rem;
  white-space: nowrap;
}

.np-sales-set-delta.is-up {
  background: rgba(var(--success-rgb), .12);
  color: var(--success-color);
}

.np-sales-set-delta.is-down {
  background: rgba(var(--danger-rgb), .12);
  color: var(--danger-color);
}

.np-sales-set-delta.is-flat {
  background: rgba(var(--secondary-rgb), .12);
  color: var(--text-muted);
}

.np-sales-popular-rank {
  align-items: center;
  background: rgba(var(--primary-rgb), .1);
  border-radius: 50%;
  color: var(--primary-color);
  display: inline-flex;
  font-size: .7rem;
  font-weight: 800;
  height: 1.45rem;
  justify-content: center;
  width: 1.45rem;
}

:deep(.apexcharts-yaxis-label),
:deep(.apexcharts-xaxis-label) {
  white-space: nowrap;
}

@media (max-width: 767.98px) {
  .np-dashboard-tabs,
  .np-dashboard-periods {
    width: 100%;
  }

  .np-dashboard-tab,
  .np-dashboard-period {
    flex: 1 1 auto;
    justify-content: center;
  }

  .np-dashboard-hero h2 {
    font-size: 1.8rem;
  }

  .np-sales-stat-row {
    align-items: flex-start;
    gap: .75rem;
  }

  .np-sales-search-like {
    max-width: none;
    width: 100%;
  }
}
</style>

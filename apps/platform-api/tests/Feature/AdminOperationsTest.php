<?php

namespace Tests\Feature;

use App\Shared\Audit\AuditLogger;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\AdminAuthFixtures;
use Tests\TestCase;

class AdminOperationsTest extends TestCase
{
    use AdminAuthFixtures;
    use RefreshDatabase;

    public function test_AdminDashboard_central_and_tenant_summaries_work_with_permission(): void
    {
        $this->seedDefaultRbac();
        $centralLogin = $this->createCentralSession(['dashboard.view']);
        $tenantLogin = $this->createTenantSession(['dashboard.view']);

        $this->withToken($centralLogin['access_token'])
            ->getJson('/api/v1/admin/central/dashboard/summary', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('scope', 'central')
            ->assertJsonPath('tenant_id', null)
            ->assertJsonStructure([
                'scope',
                'generated_at',
                'kpis' => [
                    'partners_total',
                    'tenants_active',
                    'games_open',
                    'orders_paid',
                    'sales_amount',
                    'tickets_sold',
                    'stock_available',
                    'pending_reward_claims',
                    'open_alerts',
                    'wallet_balance_amount',
                ],
                'charts' => [
                    'sales_trend' => ['labels', 'keys', 'series'],
                    'sales_by_game' => ['labels', 'keys', 'series'],
                    'usage_trend' => ['labels', 'keys', 'series'],
                    'orders_by_status',
                    'stock_by_status',
                    'reward_claims_by_status',
                    'partner_health_by_status',
                    'alert_severity',
                ],
                'tables' => [
                    'current_game',
                    'recent_games',
                    'top_partners',
                    'top_tenants',
                    'open_alerts',
                    'recent_settlements',
                    'recent_activity',
                ],
                'finance' => [
                    'current_game',
                    'previous_game',
                    'metrics',
                    'comparison_chart',
                ],
                'alerts',
            ])
            ->assertJsonPath('charts.sales_trend.series.0.key', 'orders');

        $this->withToken($centralLogin['access_token'])
            ->getJson('/api/v1/admin/central/dashboard/sales/summary?period=last_7_days', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('scope', 'central')
            ->assertJsonPath('section', 'sales')
            ->assertJsonPath('filter.period', 'last_7_days')
            ->assertJsonStructure([
                'sections',
                'hero' => ['label', 'value', 'previous', 'delta', 'caption'],
                'metrics',
                'charts' => [
                    'primary_trend' => ['labels', 'keys', 'series'],
                    'secondary_breakdown',
                    'top_entities',
                ],
                'tables' => ['top_partners', 'top_tenants', 'recent_rows'],
            ]);

        $centralMenu = $this->withToken($centralLogin['access_token'])
            ->getJson('/api/v1/admin/central/menu', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->json('data');
        $dashboardMenu = $this->menuItemByKey($centralMenu, 'dashboard');

        $this->assertNotNull($dashboardMenu);
        $this->assertSame([
            'dashboard_sales',
            'dashboard_partner',
            'dashboard_wallet',
            'dashboard_payout',
            'dashboard_monitor',
        ], array_column($dashboardMenu['children'] ?? [], 'key'));

        $this->withToken($centralLogin['access_token'])
            ->getJson('/api/v1/admin/central/dashboard/monitor/summary?period=today', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('section', 'monitor')
            ->assertJsonStructure(['metrics', 'charts', 'tables' => ['members']]);

        $this->withToken($centralLogin['access_token'])
            ->getJson('/api/v1/admin/central/dashboard/payout/summary?period=today', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('section', 'payout')
            ->assertJsonPath('filter.period', 'current_draw')
            ->assertJsonPath('filter.options.0.key', 'current_draw')
            ->assertJsonStructure([
                'metrics',
                'charts' => [
                    'partner_payout_comparison' => ['labels', 'type', 'rows'],
                    'winning_type_breakdown',
                    'partner_commission_comparison' => ['labels', 'type', 'rows'],
                ],
                'tables' => ['top_partners', 'commission_partners'],
            ]);

        $this->withToken($tenantLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/dashboard/summary', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonPath('scope', 'tenant')
            ->assertJsonPath('tenant_id', 'ten_auth')
            ->assertJsonStructure(['scope', 'tenant_id', 'generated_at', 'kpis', 'charts', 'tables', 'alerts']);
    }

    public function test_TenantDashboard_returns_real_scoped_operational_metrics(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-06-03 12:00:00', 'Asia/Bangkok'));

        try {
            $this->seedDefaultRbac();
            $tenantLogin = $this->createTenantSession(['dashboard.view']);
            $this->createPartner('par_other_dashboard', 'other-dashboard', 'Other Dashboard Partner');
            $this->createTenant('ten_other_dashboard', 'par_other_dashboard', 'other-dashboard', 'Other Dashboard Store');

            DB::table('games')->insert([
                'id' => 'gam_tenant_dashboard',
                'code' => 'tenant-dashboard',
                'name' => 'Tenant dashboard draw',
                'sale_start_at' => CarbonImmutable::parse('2026-06-01 00:00:00', 'Asia/Bangkok'),
                'draw_at' => CarbonImmutable::parse('2026-06-16 15:30:00', 'Asia/Bangkok'),
                'close_at' => CarbonImmutable::parse('2026-06-16 15:00:00', 'Asia/Bangkok'),
                'closed_at' => null,
                'archived_at' => null,
                'status' => 'open',
                'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $this->insertTenantDashboardPaidTicket(
                'auth',
                'ten_auth',
                'par_auth',
                'gam_tenant_dashboard',
                '123456',
                CarbonImmutable::parse('2026-06-03 09:00:00', 'Asia/Bangkok'),
                8000,
            );
            $this->insertTenantDashboardPaidTicket(
                'other',
                'ten_other_dashboard',
                'par_other_dashboard',
                'gam_tenant_dashboard',
                '654321',
                CarbonImmutable::parse('2026-06-03 09:30:00', 'Asia/Bangkok'),
                9000,
            );

            DB::table('wallet_ledger')->insert([
                'id' => 'wlg_tenant_dashboard_auth',
                'tenant_id' => 'ten_auth',
                'wallet_id' => 'wal_tenant_dashboard_auth',
                'customer_id' => 'cus_tenant_dashboard_auth',
                'entry_type' => 'credit',
                'status' => 'posted',
                'amount' => 12000,
                'currency' => 'THB',
                'balance_after' => 12000,
                'reference_type' => 'topup',
                'reference_id' => 'topup_tenant_dashboard_auth',
                'idempotency_key' => 'ledger-tenant-dashboard-auth',
                'created_by_admin_id' => null,
                'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
                'posted_at' => CarbonImmutable::parse('2026-06-03 10:00:00', 'Asia/Bangkok'),
                'created_at' => CarbonImmutable::parse('2026-06-03 10:00:00', 'Asia/Bangkok'),
                'updated_at' => CarbonImmutable::parse('2026-06-03 10:00:00', 'Asia/Bangkok'),
            ]);

            $summary = $this->withToken($tenantLogin['access_token'])
                ->getJson('/api/v1/admin/tenant/dashboard/summary?period=current_draw', [
                    'X-Admin-Scope' => 'tenant',
                    'X-Tenant-Id' => 'ten_auth',
                ])
                ->assertOk()
                ->assertJsonPath('scope', 'tenant')
                ->assertJsonPath('tenant_id', 'ten_auth')
                ->assertJsonPath('filter.period', 'current_draw')
                ->assertJsonPath('kpis.orders_total', 1)
                ->assertJsonPath('kpis.tickets_total', 1)
                ->assertJsonPath('kpis.sales_amount.amount', 8000)
                ->assertJsonPath('kpis.wallet_inflow_amount.amount', 12000)
                ->assertJsonStructure([
                    'hero' => ['label', 'value', 'previous', 'delta', 'caption'],
                    'metrics',
                    'charts' => [
                        'primary_trend' => ['labels', 'keys', 'series'],
                        'wallet_flow' => ['labels', 'keys', 'series'],
                        'payment_methods',
                        'stock_by_status',
                        'top_numbers',
                    ],
                    'tables' => [
                        'recent_orders',
                        'recent_wallet_ledger',
                        'stock_summary',
                        'popular_numbers',
                    ],
                    'finance',
                    'alerts',
                ])
                ->json();

            $this->assertSame('TENANT-DASH-auth', $summary['tables']['recent_orders'][0]['reference']);
            $this->assertSame('Credit', $summary['tables']['recent_wallet_ledger'][0]['entry_type']);
            $this->assertSame(8000, collect($summary['metrics'])->firstWhere('key', 'sales_amount')['current']);
            $this->assertSame(1, $summary['charts']['top_numbers']['back2'][0]['ticket_count']);
            $this->assertSame('56', $summary['charts']['top_numbers']['back2'][0]['number']);
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_CentralSalesDashboard_compares_sales_revenue_chart_by_sale_day(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-06-03 12:00:00', 'Asia/Bangkok'));

        try {
            $this->seedDefaultRbac();
            $this->createPartner('par_sale_day', 'sale-day-partner', 'Sale Day Partner');
            $this->createTenant('ten_sale_day', 'par_sale_day', 'sale-day-tenant', 'Sale Day Store');
            $login = $this->createCentralSession(['dashboard.view'], 'adm_sale_day', 'sale-day@example.test', 'central_sale_day');

            DB::table('games')->insert([
                [
                    'id' => 'gam_sale_day_previous',
                    'code' => 'sale-day-previous',
                    'name' => 'Previous sale day draw',
                    'sale_start_at' => CarbonImmutable::parse('2026-05-16 00:00:00', 'Asia/Bangkok'),
                    'draw_at' => CarbonImmutable::parse('2026-05-31 15:30:00', 'Asia/Bangkok'),
                    'close_at' => CarbonImmutable::parse('2026-05-31 15:00:00', 'Asia/Bangkok'),
                    'closed_at' => null,
                    'archived_at' => null,
                    'status' => 'reward_published',
                    'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
                [
                    'id' => 'gam_sale_day_current',
                    'code' => 'sale-day-current',
                    'name' => 'Current sale day draw',
                    'sale_start_at' => CarbonImmutable::parse('2026-06-01 00:00:00', 'Asia/Bangkok'),
                    'draw_at' => CarbonImmutable::parse('2026-06-16 15:30:00', 'Asia/Bangkok'),
                    'close_at' => CarbonImmutable::parse('2026-06-16 15:00:00', 'Asia/Bangkok'),
                    'closed_at' => null,
                    'archived_at' => null,
                    'status' => 'open',
                    'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
            ]);

            DB::table('stock_supply_profiles')->insert([
                'id' => 'vsp_sale_day_current',
                'game_id' => 'gam_sale_day_current',
                'status' => 'active',
                'seed' => 'sale-day-current-seed',
                'base_count' => 1000,
                'total_capacity' => 1300,
                'set_distribution_json' => json_encode([
                    ['set_size' => 2, 'percent_basis_points' => 1000],
                    ['set_size' => 5, 'percent_basis_points' => 500],
                ], JSON_THROW_ON_ERROR),
                'created_by_admin_id' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('customers')->insert([
                'id' => 'cus_sale_day',
                'tenant_id' => 'ten_sale_day',
                'customer_no' => 'CUST-SALE-DAY',
                'phone' => '0800000001',
                'email' => null,
                'password_hash' => null,
                'avatar_url' => null,
                'name' => 'Sale Day Customer',
                'status' => 'active',
                'last_login_at' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('affiliate_accounts')->insert([
                'id' => 'aff_sale_day',
                'tenant_id' => 'ten_sale_day',
                'customer_id' => 'cus_sale_day',
                'code' => 'AFF-SALE-DAY',
                'name' => 'Sale Day Affiliate',
                'phone' => '0800000001',
                'email' => null,
                'status' => 'active',
                'wallet_balance_amount' => 0,
                'currency' => 'THB',
                'payout_profile_json' => json_encode([], JSON_THROW_ON_ERROR),
                'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
                'created_by_admin_id' => null,
                'created_at' => CarbonImmutable::parse('2026-06-03 08:00:00', 'Asia/Bangkok'),
                'updated_at' => CarbonImmutable::parse('2026-06-03 08:00:00', 'Asia/Bangkok'),
            ]);

            $this->insertDashboardPaidTicket('cur_1', 'gam_sale_day_current', '000101', CarbonImmutable::parse('2026-06-03 09:00:00', 'Asia/Bangkok'));
            $this->insertDashboardPaidTicket('cur_2', 'gam_sale_day_current', '000102', CarbonImmutable::parse('2026-06-03 10:00:00', 'Asia/Bangkok'));
            $this->insertDashboardPaidTicket('cur_skip', 'gam_sale_day_current', '000103', CarbonImmutable::parse('2026-06-02 10:00:00', 'Asia/Bangkok'));
            $this->insertDashboardPaidTicket('prev_1', 'gam_sale_day_previous', '000201', CarbonImmutable::parse('2026-05-18 09:00:00', 'Asia/Bangkok'));
            $this->insertDashboardPaidTicket('prev_skip', 'gam_sale_day_previous', '000202', CarbonImmutable::parse('2026-05-17 09:00:00', 'Asia/Bangkok'));

            $todaySummary = $this->withToken($login['access_token'])
                ->getJson('/api/v1/admin/central/dashboard/sales/summary?period=today', ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->assertJsonPath('charts.sales_ticket_comparison.comparison_mode', 'sale_day')
                ->assertJsonPath('charts.sales_ticket_comparison.labels.0', 'Sale day 3')
                ->assertJsonPath('charts.sales_ticket_comparison.current_dates.0', '2026-06-03')
                ->assertJsonPath('charts.sales_ticket_comparison.previous_dates.0', '2026-05-18')
                ->json();
            $chart = $todaySummary['charts']['sales_ticket_comparison'];

            $series = collect($chart['series'])->keyBy('key');
            $this->assertSame([2], $series['tickets_sold_current']['values']);
            $this->assertSame([1], $series['tickets_sold_previous']['values']);
            $this->assertSame(1, collect($todaySummary['metrics'])->firstWhere('key', 'selling_partners')['current']);
            $this->assertSame([
                ['set_size' => 1, 'set_count' => 2, 'ticket_capacity' => 2],
                ['set_size' => 2, 'set_count' => 0, 'ticket_capacity' => 0],
                ['set_size' => 5, 'set_count' => 0, 'ticket_capacity' => 0],
            ], array_map(
                fn (array $row): array => [
                    'set_size' => $row['set_size'],
                    'set_count' => $row['set_count'],
                    'ticket_capacity' => $row['ticket_capacity'],
                ],
                $todaySummary['tables']['set_distribution'],
            ));
            $setDistributionBySize = collect($todaySummary['tables']['set_distribution'])->keyBy('set_size');
            $this->assertEquals(100, $setDistributionBySize[1]['percent']);
            $this->assertSame(850, $setDistributionBySize[1]['default_set_count']);
            $this->assertSame(2, $setDistributionBySize[1]['sold_set_count']);
            $this->assertSame(1, $setDistributionBySize[1]['previous_sold_set_count']);
            $this->assertEquals(100, $setDistributionBySize[1]['sold_set_delta_percent']);

            $yesterdaySetDistribution = $this->withToken($login['access_token'])
                ->getJson('/api/v1/admin/central/dashboard/sales/summary?period=yesterday', ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->assertJsonPath('filter.period', 'yesterday')
                ->json('tables.set_distribution');
            $yesterdayBySize = collect($yesterdaySetDistribution)->keyBy('set_size');
            $this->assertSame(1, $yesterdayBySize[1]['set_count']);
            $this->assertSame(1, $yesterdayBySize[1]['ticket_capacity']);

            $partnerSummary = $this->withToken($login['access_token'])
                ->getJson('/api/v1/admin/central/dashboard/partner/summary?period=today', ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->assertJsonPath('section', 'partner')
                ->assertJsonStructure([
                    'metrics',
                    'charts' => [
                        'partner_sales_comparison' => ['labels', 'type', 'rows'],
                        'partner_new_members_comparison' => ['labels', 'type', 'rows'],
                        'partner_affiliate_accounts_comparison' => ['labels', 'type', 'rows'],
                    ],
                    'tables' => ['partner_sales', 'partner_members', 'partner_affiliates'],
                ])
                ->json();
            $partnerMetrics = collect($partnerSummary['metrics'])->keyBy('key');
            $this->assertSame(16000, $partnerMetrics['partner_sales_amount']['current']);
            $this->assertSame(2, $partnerMetrics['partner_sales_tickets']['current']);
            $this->assertSame(1, $partnerMetrics['new_partners']['current']);
            $this->assertSame(1, $partnerMetrics['affiliate_accounts']['current']);
            $this->assertSame(1, $partnerMetrics['new_affiliate_accounts']['current']);
            $this->assertSame(16000, $partnerSummary['charts']['partner_sales_comparison']['rows'][0]['value']);
            $this->assertSame(2, $partnerSummary['charts']['partner_sales_comparison']['rows'][0]['ticket_count']);
            $this->assertSame(1, $partnerSummary['charts']['partner_new_members_comparison']['rows'][0]['member_count']);
            $this->assertSame(1, $partnerSummary['charts']['partner_affiliate_accounts_comparison']['rows'][0]['account_count']);

            $yesterdayPartnerSummary = $this->withToken($login['access_token'])
                ->getJson('/api/v1/admin/central/dashboard/partner/summary?period=yesterday', ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->assertJsonPath('filter.period', 'yesterday')
                ->json();
            $yesterdayPartnerMetrics = collect($yesterdayPartnerSummary['metrics'])->keyBy('key');
            $this->assertSame(8000, $yesterdayPartnerMetrics['partner_sales_amount']['current']);
            $this->assertSame(1, $yesterdayPartnerMetrics['partner_sales_tickets']['current']);
            $this->assertSame(0, $yesterdayPartnerMetrics['new_partners']['current']);
            $this->assertSame(0, $yesterdayPartnerMetrics['affiliate_accounts']['current']);
            $this->assertSame(0, $yesterdayPartnerMetrics['new_affiliate_accounts']['current']);
            $this->assertSame(8000, $yesterdayPartnerSummary['charts']['partner_sales_comparison']['rows'][0]['value']);
            $this->assertSame(1, $yesterdayPartnerSummary['charts']['partner_sales_comparison']['rows'][0]['ticket_count']);
            $this->assertEmpty($yesterdayPartnerSummary['charts']['partner_new_members_comparison']['rows']);
            $this->assertEmpty($yesterdayPartnerSummary['charts']['partner_affiliate_accounts_comparison']['rows']);

            $previousDrawRecentRows = $this->withToken($login['access_token'])
                ->getJson('/api/v1/admin/central/dashboard/sales/summary?period=previous_draw', ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->assertJsonPath('filter.period', 'previous_draw')
                ->json('tables.recent_rows');

            $this->assertSame('ord_cur_2', $previousDrawRecentRows[0]['id']);
            $this->assertNotContains('ord_prev_1', array_column($previousDrawRecentRows, 'id'));

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-06-04 12:00:00', 'Asia/Bangkok'));
            $nextDayLogin = $this->createCentralSession(['dashboard.view'], 'adm_sale_day_next', 'sale-day-next@example.test', 'central_sale_day_next');
            $emptyTodayPartnerSummary = $this->withToken($nextDayLogin['access_token'])
                ->getJson('/api/v1/admin/central/dashboard/partner/summary?period=today', ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->assertJsonPath('filter.period', 'today')
                ->json();
            $emptyTodayPartnerMetrics = collect($emptyTodayPartnerSummary['metrics'])->keyBy('key');
            $this->assertSame(0, $emptyTodayPartnerMetrics['partner_sales_amount']['current']);
            $this->assertSame(0, $emptyTodayPartnerMetrics['partner_sales_tickets']['current']);
            $this->assertSame(0, $emptyTodayPartnerMetrics['affiliate_accounts']['current']);
            $this->assertEmpty($emptyTodayPartnerSummary['charts']['partner_sales_comparison']['rows']);
            $this->assertEmpty($emptyTodayPartnerSummary['charts']['partner_new_members_comparison']['rows']);
            $this->assertEmpty($emptyTodayPartnerSummary['charts']['partner_affiliate_accounts_comparison']['rows']);
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_AdminDashboard_defaults_to_deny_without_dashboard_view(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['menu.manage']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/dashboard/summary', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_CentralMonitorDashboard_tracks_public_guest_sources_and_ips(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner('par_monitor', 'monitor-partner', 'Monitor Partner');
        $this->createTenant('ten_monitor', 'par_monitor', 'monitor-tenant', 'Monitor Tenant');
        $this->createTenantDomain('dom_monitor', 'par_monitor', 'ten_monitor', 'monitor.newpaotang.test');

        $this->postJson('http://monitor.newpaotang.test/api/v1/public/monitor/visit', [
            'visitor_id' => 'visitor-monitor-1',
            'session_id' => 'session-monitor-1',
            'source' => 'facebook',
            'channel' => 'campaign-a',
            'path' => '/buy/search?number=123456',
            'screen' => '390x844',
            'timezone' => 'Asia/Bangkok',
        ])
            ->assertOk()
            ->assertJsonPath('data.tracked', true);

        $this->assertDatabaseHas('public_visit_sessions', [
            'tenant_id' => 'ten_monitor',
            'visitor_key' => 'visitor-monitor-1',
            'session_key' => 'session-monitor-1',
            'source' => 'facebook',
        ]);

        $yesterday = CarbonImmutable::now()->subDay()->setTime(10, 15);
        DB::table('public_visit_sessions')->insert([
            'id' => 'pvs_monitor_yesterday',
            'tenant_id' => 'ten_monitor',
            'partner_id' => 'par_monitor',
            'customer_id' => null,
            'visitor_key' => 'visitor-monitor-2',
            'session_key' => 'session-monitor-2',
            'source' => 'line',
            'channel' => 'line-oa',
            'path' => '/tickets',
            'referrer' => null,
            'ip_address' => '10.10.10.20',
            'user_agent' => 'Monitor test agent',
            'screen' => '430x932',
            'timezone' => 'Asia/Bangkok',
            'first_seen_at' => $yesterday->subMinutes(12),
            'last_seen_at' => $yesterday,
            'expires_at' => $yesterday->addMinutes(30),
            'metadata_json' => json_encode(['source' => 'feature_test'], JSON_THROW_ON_ERROR),
            'created_at' => $yesterday->subMinutes(12),
            'updated_at' => $yesterday,
        ]);

        $login = $this->createCentralSession(['dashboard.view'], 'adm_monitor_guest', 'monitor-guest@example.test', 'central_monitor_guest');
        $summary = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/dashboard/monitor/summary?period=today', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('section', 'monitor')
            ->assertJsonStructure(['metrics', 'charts' => ['secondary_breakdown'], 'tables' => ['visitors']])
            ->json();

        $guestMetric = collect($summary['metrics'])->firstWhere('key', 'active_guests');
        $this->assertSame(1, $guestMetric['current']);
        $this->assertSame('Facebook', $summary['charts']['secondary_breakdown'][0]['label']);
        $this->assertSame('Facebook visitor', $summary['tables']['visitors'][0]['title']);

        $yesterdaySummary = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/dashboard/monitor/summary?period=yesterday', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('section', 'monitor')
            ->assertJsonPath('filter.period', 'yesterday')
            ->json();

        $yesterdayGuestMetric = collect($yesterdaySummary['metrics'])->firstWhere('key', 'active_guests');
        $this->assertSame(1, $yesterdayGuestMetric['current']);
        $this->assertSame('Line', $yesterdaySummary['charts']['secondary_breakdown'][0]['label']);
        $this->assertSame('Line visitor', $yesterdaySummary['tables']['visitors'][0]['title']);
    }

    public function test_AdminRealtime_authorizes_allowed_channels_and_rejects_scope_mismatch(): void
    {
        $this->seedDefaultRbac();
        $centralLogin = $this->createCentralSession([]);
        $tenantLogin = $this->createTenantSession([]);

        $centralAuth = $this->withToken($centralLogin['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '1234.5678',
                'channel_name' => 'private-admin.central.dashboard',
            ], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonStructure(['auth', 'channel_data', 'expires_at'])
            ->json();

        $this->assertStringStartsWith('newpaotang-admin:', $centralAuth['auth']);
        $this->assertNull($centralAuth['channel_data']);

        $this->withToken($centralLogin['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '1234.5678',
                'channel_name' => 'private-admin.tenant.ten_auth.dashboard',
            ], ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $tenantAuth = $this->withToken($tenantLogin['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '9876.5432',
                'channel_name' => 'presence-admin.tenant.ten_auth',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonStructure(['auth', 'channel_data', 'expires_at'])
            ->json();

        $this->assertStringContainsString('"tenant_id":"ten_auth"', $tenantAuth['channel_data']);

        $this->withToken($tenantLogin['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '9876.5432',
                'channel_name' => 'private-admin.tenant.ten_auth.reward-claims',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonStructure(['auth', 'channel_data', 'expires_at']);

        $this->withToken($tenantLogin['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '9876.5432',
                'channel_name' => 'private-admin.tenant.ten_other.dashboard',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_AdminRealtime_stock_generation_channels_require_central_stock_generate_permission(): void
    {
        $this->seedDefaultRbac();
        $stockLogin = $this->createCentralSession(['stock.generate'], 'adm_realtime_stock', 'realtime-stock@example.test', 'central_stock_realtime');
        $deniedLogin = $this->createCentralSession(['stock.view'], 'adm_realtime_stock_denied', 'realtime-stock-denied@example.test', 'central_stock_realtime_denied');
        $tenantLogin = $this->createTenantSession([]);

        foreach ([
            'private-admin.central.stock-generation',
            'private-admin.central.stock-generation.game.gam_realtime',
            'private-admin.central.stock-generation.batch.stb_realtime',
        ] as $channelName) {
            $this->withToken($stockLogin['access_token'])
                ->postJson('/api/v1/admin/central/realtime/auth', [
                    'socket_id' => '2222.3333',
                    'channel_name' => $channelName,
                ], ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->assertJsonStructure(['auth', 'channel_data', 'expires_at']);
        }

        $this->withToken($deniedLogin['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '2222.3333',
                'channel_name' => 'private-admin.central.stock-generation.batch.stb_realtime',
            ], ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($tenantLogin['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '2222.3333',
                'channel_name' => 'private-admin.central.stock-generation',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_AdminRealtime_stock_table_channel_requires_central_stock_view_permission(): void
    {
        $this->seedDefaultRbac();
        $viewLogin = $this->createCentralSession(['stock.view'], 'adm_realtime_table', 'realtime-table@example.test', 'central_stock_table_realtime');
        $deniedLogin = $this->createCentralSession(['stock.generate'], 'adm_realtime_table_denied', 'realtime-table-denied@example.test', 'central_stock_table_denied');
        $tenantLogin = $this->createTenantSession(['stock.view']);

        $this->withToken($viewLogin['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '3333.4444',
                'channel_name' => 'private-admin.central.stock.table.game.gam_realtime',
            ], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonStructure(['auth', 'channel_data', 'expires_at']);

        $this->withToken($deniedLogin['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '3333.4444',
                'channel_name' => 'private-admin.central.stock.table.game.gam_realtime',
            ], ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($tenantLogin['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '3333.4444',
                'channel_name' => 'private-admin.central.stock.table.game.gam_realtime',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_AdminRealtime_tenant_stock_channels_require_tenant_stock_view_permission(): void
    {
        $this->seedDefaultRbac();
        $viewLogin = $this->createTenantSession(['stock.view']);
        $deniedLogin = $this->createTenantSession(['dashboard.view'], 'adm_tenant_stock_deny', 'realtime-tenant-stock-denied@example.test');

        foreach ([
            'private-admin.tenant.ten_auth.stock.game.gam_realtime',
            'private-admin.tenant.ten_auth.stock.coverage.game.gam_realtime',
        ] as $channelName) {
            $this->withToken($viewLogin['access_token'])
                ->postJson('/api/v1/admin/tenant/realtime/auth', [
                    'socket_id' => '4444.5555',
                    'channel_name' => $channelName,
                ], [
                    'X-Admin-Scope' => 'tenant',
                    'X-Tenant-Id' => 'ten_auth',
                ])
                ->assertOk()
                ->assertJsonStructure(['auth', 'channel_data', 'expires_at']);

            $this->withToken($deniedLogin['access_token'])
                ->postJson('/api/v1/admin/tenant/realtime/auth', [
                    'socket_id' => '4444.5555',
                    'channel_name' => $channelName,
                ], [
                    'X-Admin-Scope' => 'tenant',
                    'X-Tenant-Id' => 'ten_auth',
                ])
                ->assertForbidden()
                ->assertJsonPath('error.code', 'permission_denied');
        }

        $this->withToken($viewLogin['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '4444.5555',
                'channel_name' => 'private-admin.tenant.ten_other.stock.game.gam_realtime',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_AdminMenu_management_read_and_update_validates_idempotency_and_writes_audit(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['menu.manage']);
        $roleId = (string) DB::table('roles')->where('code', 'central_ops')->value('id');

        $dashboardMenu = $this->menuItemByKey(
            $this->withToken($login['access_token'])
                ->getJson('/api/v1/admin/central/menu-management', ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->json('data'),
            'dashboard_sales',
        );

        $this->assertNotNull($dashboardMenu);
        $this->assertArrayHasKey('required_permission_code', $dashboardMenu);

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [],
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        DB::table('admin_permission_cache_versions')->insert([
            'id' => 'pcv_admin_menu_existing',
            'admin_user_id' => 'adm_central',
            'scope_id' => 'scp_central',
            'version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $updated = $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [[
                    'id' => $dashboardMenu['id'],
                    'key' => 'dashboard_sales',
                    'label' => 'Sales Managed',
                    'route' => '/central/dashboard/sales',
                    'required_permission_code' => 'dashboard.view',
                    'sort_order' => 5,
                    'status' => 'active',
                    'role_ids' => [$roleId],
                    'children' => [],
                ]],
                'reason' => 'menu update',
                'password' => 'super-secret',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-menu-update',
            ])
            ->assertOk()
            ->json('data');

        $updatedDashboard = $this->menuItemByKey($updated, 'dashboard_sales');
        $this->assertSame('Sales Managed', $updatedDashboard['label']);
        $this->assertSame([$roleId], $updatedDashboard['role_ids']);

        $this->assertDatabaseHas('role_menus', [
            'role_id' => $roleId,
            'menu_id' => $dashboardMenu['id'],
        ]);
        $this->assertDatabaseHas('admin_permission_cache_versions', [
            'admin_user_id' => 'adm_central',
            'scope_id' => 'scp_central',
            'version' => 2,
        ]);

        $auditPayload = json_decode((string) DB::table('audit_logs')->where('action', 'menu.changed')->value('payload_redacted_json'), true);
        $this->assertSame('[REDACTED]', $auditPayload['payload']['password']);
        $this->assertStringNotContainsString('super-secret', json_encode($auditPayload, JSON_THROW_ON_ERROR));
    }

    public function test_AdminMenu_management_rejects_cross_scope_tree_bad_roles_and_duplicate_ordering(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['menu.manage']);
        $this->createPartner();
        $this->createTenant('ten_auth');
        $tenantRoleId = $this->insertRole('tenant', 'ten_auth', 'tenant_menu_role', 'Tenant Menu Role', ['menu.manage']);
        $centralDashboardMenuId = (string) DB::table('admin_menus')->where('scope_type', 'central')->where('code', 'dashboard_sales')->value('id');
        $centralGamesMenuId = (string) DB::table('admin_menus')->where('scope_type', 'central')->where('code', 'games')->value('id');
        $tenantDashboardMenuId = (string) DB::table('admin_menus')->where('scope_type', 'tenant')->where('code', 'dashboard')->value('id');

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [[
                    'id' => $tenantDashboardMenuId,
                    'key' => 'dashboard',
                    'label' => 'Wrong Scope Dashboard',
                    'children' => [],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'cross-scope-menu',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [[
                    'id' => $centralDashboardMenuId,
                    'key' => 'dashboard_sales',
                    'label' => 'Sales',
                    'role_ids' => [$tenantRoleId],
                    'children' => [],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'bad-menu-role',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [
                    [
                        'id' => $centralDashboardMenuId,
                        'key' => 'dashboard_sales',
                        'label' => 'Sales',
                        'sort_order' => 10,
                        'children' => [],
                    ],
                    [
                        'id' => $centralGamesMenuId,
                        'key' => 'games',
                        'label' => 'Games',
                        'sort_order' => 10,
                        'children' => [],
                    ],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'duplicate-menu-order',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');
    }

    public function test_AuditLog_lists_are_permissioned_redacted_and_tenant_isolated(): void
    {
        $this->seedDefaultRbac();
        $centralLogin = $this->createCentralSession(['audit.view']);
        $tenantLogin = $this->createTenantSession(['audit.view']);
        $this->createPartner('par_auth_other');
        $this->createTenant('ten_other', 'par_auth_other');

        app(AuditLogger::class)->logAdminWrite(
            actorId: 'adm_central',
            scopeType: 'central',
            action: 'menu.changed',
            targetType: 'admin_menu_tree',
            targetId: 'scp_central',
            payload: [
                'password' => 'central-secret',
                'token_hash' => 'central-token-hash',
                'invitation_url' => 'https://admin.example.test/invitations/central-raw',
                'invitation_code' => 'CENTRAL-INVITE-CODE',
                'invite_link' => 'https://admin.example.test/invite-link/central-raw',
            ],
        );

        app(AuditLogger::class)->logAdminWrite(
            actorId: 'adm_tenant',
            scopeType: 'tenant',
            action: 'menu.changed',
            targetType: 'admin_menu_tree',
            targetId: 'scp_tenant',
            payload: [
                'password_hash' => 'tenant-password-hash',
                'secret' => 'tenant-secret',
                'invitation_material' => [
                    'invitation_url' => 'https://tenant.example.test/invitations/tenant-raw',
                    'invitation_code' => 'TENANT-INVITE-CODE',
                    'invite_link' => 'https://tenant.example.test/invite-link/tenant-raw',
                ],
            ],
            tenantId: 'ten_auth',
        );

        app(AuditLogger::class)->logAdminWrite(
            actorId: 'adm_other',
            scopeType: 'tenant',
            action: 'menu.changed',
            targetType: 'admin_menu_tree',
            targetId: 'scp_other',
            payload: ['secret' => 'other-secret'],
            tenantId: 'ten_other',
        );

        $centralLogs = $this->withToken($centralLogin['access_token'])
            ->getJson('/api/v1/admin/central/audit-logs?action=menu.changed&limit=10', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json('data');

        $this->assertCount(1, $centralLogs);
        $this->assertSame('central', $centralLogs[0]['scope']);
        $this->assertNull($centralLogs[0]['tenant_id']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['password']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['token_hash']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['invitation_url']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['invitation_code']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['invite_link']);
        $this->assertStringNotContainsString('central-raw', json_encode($centralLogs, JSON_THROW_ON_ERROR));
        $this->assertStringNotContainsString('CENTRAL-INVITE-CODE', json_encode($centralLogs, JSON_THROW_ON_ERROR));

        $tenantLogs = $this->withToken($tenantLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/audit-logs?action=menu.changed&limit=10', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json('data');

        $this->assertCount(1, $tenantLogs);
        $this->assertSame('ten_auth', $tenantLogs[0]['tenant_id']);
        $this->assertSame('[REDACTED]', $tenantLogs[0]['payload']['password_hash']);
        $this->assertSame('[REDACTED]', $tenantLogs[0]['payload']['invitation_material']);
        $this->assertStringNotContainsString('tenant-raw', json_encode($tenantLogs, JSON_THROW_ON_ERROR));
        $this->assertStringNotContainsString('TENANT-INVITE-CODE', json_encode($tenantLogs, JSON_THROW_ON_ERROR));
        $this->assertStringNotContainsString('other-secret', json_encode($tenantLogs, JSON_THROW_ON_ERROR));

        $this->withToken($tenantLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/audit-logs?action=menu.changed', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_other',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_AuditLog_defaults_to_deny_without_audit_view(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['dashboard.view']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/audit-logs', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    private function insertTenantDashboardPaidTicket(
        string $suffix,
        string $tenantId,
        string $partnerId,
        string $gameId,
        string $number,
        CarbonImmutable $paidAt,
        int $amount,
    ): void {
        $stockId = 'stk_tenant_dashboard_'.$suffix;
        $localStockId = 'lsk_tenant_dashboard_'.$suffix;
        $reservationId = 'res_tenant_dashboard_'.$suffix;
        $orderId = 'ord_tenant_dashboard_'.$suffix;
        $customerId = 'cus_tenant_dashboard_'.$suffix;
        $walletId = 'wal_tenant_dashboard_'.$suffix;
        $ticketId = 'tkt_tenant_dashboard_'.$suffix;

        DB::table('customers')->insert([
            'id' => $customerId,
            'tenant_id' => $tenantId,
            'customer_no' => strtoupper('CUST-'.$suffix),
            'phone' => $suffix === 'auth' ? '0800000101' : '0800000102',
            'email' => null,
            'password_hash' => null,
            'avatar_url' => null,
            'reward_payout_bank_account_json' => null,
            'name' => 'Tenant Dashboard Customer '.$suffix,
            'first_name' => null,
            'last_name' => null,
            'status' => 'active',
            'last_login_at' => null,
            'pin_hash' => null,
            'pin_set_at' => null,
            'pin_changed_at' => null,
            'pin_failed_attempts' => 0,
            'pin_locked_until' => null,
            'pin_last_verified_at' => null,
            'auto_reward_claim_enabled' => false,
            'auto_reward_claim_payout_method' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('wallets')->insert([
            'id' => $walletId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'name' => 'Primary wallet',
            'type' => 'primary',
            'status' => 'active',
            'balance_amount' => 12000,
            'currency' => 'THB',
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('stock_items')->insert([
            'id' => $stockId,
            'game_id' => $gameId,
            'batch_id' => null,
            'full_number' => $number,
            'front3' => substr($number, 0, 3),
            'back3' => substr($number, -3),
            'back2' => substr($number, -2),
            'status' => 'sold',
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'allocation_id' => null,
            'recall_reason' => null,
            'recalled_at' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('local_stock_items')->insert([
            'id' => $localStockId,
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'store_id' => null,
            'game_id' => $gameId,
            'stock_item_id' => $stockId,
            'allocation_id' => null,
            'full_number' => $number,
            'front3' => substr($number, 0, 3),
            'back3' => substr($number, -3),
            'back2' => substr($number, -2),
            'image_url' => null,
            'image_thumb_url' => null,
            'status' => 'sold',
            'synced_at' => $paidAt,
            'reserved_at' => $paidAt,
            'sold_at' => $paidAt,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('stock_reservations')->insert([
            'id' => $reservationId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'game_id' => $gameId,
            'status' => 'converted',
            'expires_at' => $paidAt->addMinutes(15),
            'released_at' => null,
            'cancelled_at' => null,
            'converted_at' => $paidAt,
            'idempotency_key' => 'reservation-'.$suffix,
            'payload_hash' => hash('sha256', 'reservation-'.$suffix),
            'released_idempotency_key' => null,
            'released_payload_hash' => null,
            'cancelled_idempotency_key' => null,
            'cancelled_payload_hash' => null,
            'cancelled_by_admin_id' => null,
            'cancel_reason' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('orders')->insert([
            'id' => $orderId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'reservation_id' => $reservationId,
            'game_id' => $gameId,
            'wallet_id' => $walletId,
            'payment_method' => 'wallet',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => $amount,
            'currency' => 'THB',
            'reference' => 'TENANT-DASH-'.$suffix,
            'admin_note' => null,
            'idempotency_key' => 'order-'.$suffix,
            'payload_hash' => hash('sha256', 'order-'.$suffix),
            'paid_at' => $paidAt,
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('tickets')->insert([
            'id' => $ticketId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'order_id' => $orderId,
            'local_stock_item_id' => $localStockId,
            'game_id' => $gameId,
            'full_number' => $number,
            'status' => 'active',
            'image_url' => null,
            'image_thumb_url' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('order_items')->insert([
            'id' => 'oit_tenant_dashboard_'.$suffix,
            'tenant_id' => $tenantId,
            'order_id' => $orderId,
            'local_stock_item_id' => $localStockId,
            'ticket_id' => $ticketId,
            'status' => 'fulfilled',
            'price_amount' => $amount,
            'currency' => 'THB',
            'sale_price_rule_snapshot_json' => json_encode(['set_size' => 1], JSON_THROW_ON_ERROR),
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);
    }

    private function insertDashboardPaidTicket(string $suffix, string $gameId, string $number, CarbonImmutable $paidAt, int $setSize = 1): void
    {
        $stockId = 'stk_'.$suffix;
        $localStockId = 'lsk_'.$suffix;
        $reservationId = 'res_'.$suffix;
        $orderId = 'ord_'.$suffix;

        DB::table('stock_items')->insert([
            'id' => $stockId,
            'game_id' => $gameId,
            'batch_id' => null,
            'full_number' => $number,
            'front3' => substr($number, 0, 3),
            'back3' => substr($number, -3),
            'back2' => substr($number, -2),
            'status' => 'sold',
            'partner_id' => 'par_sale_day',
            'tenant_id' => 'ten_sale_day',
            'allocation_id' => null,
            'recall_reason' => null,
            'recalled_at' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('local_stock_items')->insert([
            'id' => $localStockId,
            'tenant_id' => 'ten_sale_day',
            'partner_id' => 'par_sale_day',
            'store_id' => null,
            'game_id' => $gameId,
            'stock_item_id' => $stockId,
            'allocation_id' => null,
            'full_number' => $number,
            'front3' => substr($number, 0, 3),
            'back3' => substr($number, -3),
            'back2' => substr($number, -2),
            'image_url' => null,
            'image_thumb_url' => null,
            'status' => 'sold',
            'synced_at' => $paidAt,
            'reserved_at' => $paidAt,
            'sold_at' => $paidAt,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('stock_reservations')->insert([
            'id' => $reservationId,
            'tenant_id' => 'ten_sale_day',
            'customer_id' => 'cus_sale_day',
            'game_id' => $gameId,
            'status' => 'converted',
            'expires_at' => $paidAt->addMinutes(15),
            'released_at' => null,
            'cancelled_at' => null,
            'converted_at' => $paidAt,
            'idempotency_key' => 'reservation-'.$suffix,
            'payload_hash' => hash('sha256', 'reservation-'.$suffix),
            'released_idempotency_key' => null,
            'released_payload_hash' => null,
            'cancelled_idempotency_key' => null,
            'cancelled_payload_hash' => null,
            'cancelled_by_admin_id' => null,
            'cancel_reason' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('orders')->insert([
            'id' => $orderId,
            'tenant_id' => 'ten_sale_day',
            'customer_id' => 'cus_sale_day',
            'reservation_id' => $reservationId,
            'game_id' => $gameId,
            'wallet_id' => null,
            'payment_method' => 'wallet',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => 8000,
            'currency' => 'THB',
            'reference' => 'SALE-DAY-'.$suffix,
            'admin_note' => null,
            'idempotency_key' => 'order-'.$suffix,
            'payload_hash' => hash('sha256', 'order-'.$suffix),
            'paid_at' => $paidAt,
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('tickets')->insert([
            'id' => 'tkt_'.$suffix,
            'tenant_id' => 'ten_sale_day',
            'customer_id' => 'cus_sale_day',
            'order_id' => $orderId,
            'local_stock_item_id' => $localStockId,
            'game_id' => $gameId,
            'full_number' => $number,
            'status' => 'active',
            'image_url' => null,
            'image_thumb_url' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        DB::table('order_items')->insert([
            'id' => 'oit_'.$suffix,
            'tenant_id' => 'ten_sale_day',
            'order_id' => $orderId,
            'local_stock_item_id' => $localStockId,
            'ticket_id' => 'tkt_'.$suffix,
            'status' => 'fulfilled',
            'price_amount' => 8000,
            'currency' => 'THB',
            'sale_price_rule_snapshot_json' => json_encode([
                'source' => 'dashboard_test',
                'set_size' => max(1, $setSize),
            ], JSON_THROW_ON_ERROR),
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    private function createCentralSession(
        array $permissions,
        string $adminId = 'adm_central',
        string $email = 'central@example.test',
        string $roleCode = 'central_ops',
    ): array
    {
        $scopeId = $adminId === 'adm_central' ? 'scp_central' : 'scp_'.$adminId;

        $this->createAdmin($adminId, $email);
        $this->createAdminScope($scopeId, 'central');
        $this->assignRoleWithPermissions($adminId, $scopeId, 'central', null, $permissions, $roleCode);

        return $this->loginAdmin([
            'email' => $email,
            'password' => 'secret-password',
            'scope' => 'central',
        ]);
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    private function createTenantSession(
        array $permissions,
        string $adminId = 'adm_tenant',
        string $email = 'tenant@example.test',
    ): array {
        if (! DB::table('partners')->where('id', 'par_auth')->exists()) {
            $this->createPartner();
        }
        if (! DB::table('partner_tenants')->where('id', 'ten_auth')->exists()) {
            $this->createTenant('ten_auth');
        }

        $scopeId = $adminId === 'adm_tenant' ? 'scp_tenant' : 'scp_'.$adminId;
        $roleCode = $adminId === 'adm_tenant' ? 'tenant_ops' : 'tenant_ops_'.$adminId;

        $this->createAdmin($adminId, $email);
        $this->createAdminScope($scopeId, 'tenant', 'ten_auth', 'par_auth');
        $this->assignRoleWithPermissions($adminId, $scopeId, 'tenant', 'ten_auth', $permissions, $roleCode);

        return $this->loginAdmin([
            'email' => $email,
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_auth',
        ]);
    }

    /**
     * @param array<int, array<string, mixed>> $items
     * @return array<string, mixed>|null
     */
    private function menuItemByKey(array $items, string $key): ?array
    {
        foreach ($items as $item) {
            if (($item['key'] ?? null) === $key) {
                return $item;
            }

            $found = $this->menuItemByKey($item['children'] ?? [], $key);

            if ($found !== null) {
                return $found;
            }
        }

        return null;
    }

    /**
     * @param array<int, string> $permissions
     */
    private function insertRole(string $scopeType, ?string $tenantId, string $code, string $name, array $permissions): string
    {
        $roleId = 'rol_'.substr(sha1($scopeType.':'.$tenantId.':'.$code), 0, 20);

        DB::table('roles')->insert([
            'id' => $roleId,
            'scope_type' => $scopeType,
            'tenant_id' => $tenantId,
            'code' => $code,
            'name' => $name,
            'status' => 'active',
            'version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $permissionIds = DB::table('permissions')
            ->where('scope_type', $scopeType)
            ->whereIn('code', $permissions)
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            DB::table('role_permissions')->insert(array_map(fn (string $permissionId): array => [
                'role_id' => $roleId,
                'permission_id' => $permissionId,
                'created_at' => now(),
                'updated_at' => now(),
            ], $permissionIds));
        }

        return $roleId;
    }
}

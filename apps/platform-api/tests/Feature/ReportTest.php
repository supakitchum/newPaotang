<?php

namespace Tests\Feature;

use App\Modules\Growth\Services\GrowthService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class ReportTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_Report_and_export_jobs_are_scoped_for_tenant_and_central_admins(): void
    {
        $world = $this->prepareM8World('report-main');
        $this->insertM8AffiliateGraph($world, 'report-main', 1200);
        app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']);

        $tenantAdmin = $this->m8TenantAdmin($world, ['report.view'], 'report-tenant');
        $centralAdmin = $this->m8CentralAdmin(['report.view'], 'report-central');
        $tenantHeaders = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
        ];
        $centralHeaders = ['X-Admin-Scope' => 'central'];

        $this->withToken($tenantAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/reports/commission', $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('scope', 'tenant')
            ->assertJsonPath('tenant_id', $world['tenant_id'])
            ->assertJsonPath('summary.commission_total.amount', 1200);

        $tenantExport = $this->withToken($tenantAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/reports/commission/exports', [
                'format' => 'csv',
                'filters' => ['status' => 'calculated'],
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-report-export-main'])
            ->assertAccepted()
            ->assertJsonPath('scope', 'tenant')
            ->assertJsonPath('status', 'ready')
            ->json();

        $this->withToken($tenantAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/export-jobs/'.$tenantExport['id'], $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('id', $tenantExport['id']);

        $this->withToken($tenantAdmin['access_token'])
            ->get('/api/v1/admin/tenant/export-jobs/'.$tenantExport['id'].'/download', $tenantHeaders)
            ->assertStatus(302)
            ->assertHeader('Location', $tenantExport['download_url']);

        $centralExport = $this->withToken($centralAdmin['access_token'])
            ->postJson('/api/v1/admin/central/reports/overview/exports', [
                'format' => 'pdf',
                'tenant_id' => $world['tenant_id'],
                'game_id' => $world['game_id'],
            ], $centralHeaders + ['Idempotency-Key' => 'central-report-export-main'])
            ->assertAccepted()
            ->assertJsonPath('scope', 'central')
            ->assertJsonPath('tenant_id', $world['tenant_id'])
            ->json();

        $centralExportFiltersRaw = DB::table('report_export_jobs')->where('id', $centralExport['id'])->value('filters_json');
        $centralExportFilters = is_string($centralExportFiltersRaw)
            ? json_decode($centralExportFiltersRaw, true)
            : (array) $centralExportFiltersRaw;
        $this->assertSame($world['game_id'], $centralExportFilters['game_id'] ?? null);

        $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/overview?tenant_id='.$world['tenant_id'], $centralHeaders)
            ->assertOk()
            ->assertJsonPath('scope', 'central')
            ->assertJsonPath('tenant_id', $world['tenant_id']);

        $this->withToken($centralAdmin['access_token'])
            ->get('/api/v1/admin/central/export-jobs/'.$centralExport['id'].'/download', $centralHeaders)
            ->assertStatus(302)
            ->assertHeader('Location', $centralExport['download_url']);
    }

    public function test_CentralReports_return_detailed_sections_columns_and_real_rows(): void
    {
        $world = $this->prepareM8World('report-central-detail');
        $this->insertM8AffiliateGraph($world, 'report-central-detail', 1750);
        app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']);

        $centralAdmin = $this->m8CentralAdmin(['report.view'], 'report-central-detail');
        $headers = ['X-Admin-Scope' => 'central'];

        $sales = $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/sales?tenant_id='.$world['tenant_id'], $headers)
            ->assertOk()
            ->assertJsonPath('scope', 'central')
            ->assertJsonPath('report_key', 'sales')
            ->assertJsonPath('tenant_id', $world['tenant_id'])
            ->assertJsonPath('summary.sales_total.amount', 10000)
            ->assertJsonPath('summary.tickets_sold_count', 1)
            ->json();

        $this->assertNotEmpty($sales['sections']);
        $this->assertSame('paid_at', $sales['columns'][0]['key']);
        $this->assertSame($world['order_id'], $sales['rows'][0]['id']);
        $this->assertSame(10000, $sales['rows'][0]['total_amount']['amount']);

        $orders = $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/orders?tenant_id='.$world['tenant_id'], $headers)
            ->assertOk()
            ->assertJsonPath('report_key', 'orders')
            ->json();

        $this->assertSame('payment_status', $orders['columns'][6]['key']);
        $this->assertSame('paid', $orders['rows'][0]['payment_status']);

        $customers = $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/customers?tenant_id='.$world['tenant_id'], $headers)
            ->assertOk()
            ->assertJsonPath('report_key', 'customers')
            ->json();

        $this->assertSame($world['customer_id'], $customers['rows'][0]['id']);
        $this->assertArrayHasKey('auto_reward', $customers['rows'][0]);

        $partners = $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/partners?tenant_id='.$world['tenant_id'], $headers)
            ->assertOk()
            ->assertJsonPath('report_key', 'partners')
            ->json();

        $this->assertSame($world['tenant_id'], $partners['rows'][0]['id']);
        $this->assertNotEmpty($partners['sections']);

        foreach (['overview', 'stock', 'wallet', 'commission', 'rewards', 'settlement', 'partner_usage', 'audit'] as $reportKey) {
            $response = $this->withToken($centralAdmin['access_token'])
                ->getJson('/api/v1/admin/central/reports/'.$reportKey.'?tenant_id='.$world['tenant_id'], $headers)
                ->assertOk()
                ->assertJsonPath('report_key', $reportKey)
                ->json();

            $this->assertIsArray($response['columns']);
            $this->assertIsArray($response['sections']);
        }
    }

    public function test_TenantReports_return_detailed_sections_columns_and_money_rows(): void
    {
        $world = $this->prepareM8World('report-tenant-detail');
        $this->insertM8AffiliateGraph($world, 'report-tenant-detail', 1250);
        app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']);

        DB::table('partner_settlements')->insert([
            'id' => 'set_m8_report_tenant',
            'partner_id' => $world['partner_id'],
            'tenant_id' => $world['tenant_id'],
            'status' => 'approved',
            'sales_amount' => 10000,
            'commission_amount' => 1250,
            'payout_amount' => 0,
            'net_amount' => 8750,
            'currency' => 'THB',
            'period_from' => now()->toDateString(),
            'period_to' => now()->toDateString(),
            'approved_by_admin_id' => null,
            'approved_at' => now(),
            'idempotency_key' => null,
            'payload_hash' => null,
            'summary_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $tenantAdmin = $this->m8TenantAdmin($world, ['report.view'], 'report-tenant-detail');
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
        ];

        $sales = $this->withToken($tenantAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/reports/sales?game_id='.$world['game_id'], $headers)
            ->assertOk()
            ->assertJsonPath('scope', 'tenant')
            ->assertJsonPath('report_key', 'sales')
            ->assertJsonPath('tenant_id', $world['tenant_id'])
            ->assertJsonPath('game_id', $world['game_id'])
            ->assertJsonPath('summary.sales_total.amount', 10000)
            ->assertJsonPath('rows.0.total_amount.amount', 10000)
            ->json();

        $this->assertSame('paid_at', $sales['columns'][0]['key']);
        $this->assertNotEmpty($sales['sections']);

        $stock = $this->withToken($tenantAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/reports/stock?game_id='.$world['game_id'], $headers)
            ->assertOk()
            ->assertJsonPath('report_key', 'stock')
            ->assertJsonPath('summary.stock_total_count', 1)
            ->json();

        $this->assertSame('full_number', $stock['columns'][2]['key']);
        $this->assertSame($world['game_id'], $stock['rows'][0]['game_id']);
        $this->assertArrayNotHasKey('image_url', $stock['rows'][0]);

        $commission = $this->withToken($tenantAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/reports/commission?game_id='.$world['game_id'], $headers)
            ->assertOk()
            ->assertJsonPath('summary.commission_total.amount', 1250)
            ->assertJsonPath('rows.0.amount.amount', 1250)
            ->json();

        $this->assertNotEmpty($commission['sections']);

        $settlement = $this->withToken($tenantAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/reports/settlement', $headers)
            ->assertOk()
            ->assertJsonPath('report_key', 'settlement')
            ->assertJsonPath('rows.0.net_amount.amount', 8750)
            ->json();

        $this->assertSame('net_amount', $settlement['columns'][6]['key']);

        foreach (['overview', 'orders', 'customers', 'wallet', 'rewards', 'audit'] as $reportKey) {
            $response = $this->withToken($tenantAdmin['access_token'])
                ->getJson('/api/v1/admin/tenant/reports/'.$reportKey, $headers)
                ->assertOk()
                ->assertJsonPath('report_key', $reportKey)
                ->json();

            $this->assertIsArray($response['columns']);
            $this->assertIsArray($response['sections']);
        }
    }

    public function test_CentralReports_can_filter_draw_bound_reports_by_game(): void
    {
        $world = $this->prepareM8World('report-central-draw-filter');
        $otherGameId = 'gam_m8_report_other';
        $otherReservationId = 'res_m8_report_other';
        $otherOrderId = 'ord_m8_report_other';
        $otherStockId = 'stk_m8_report_other';

        $this->insertGame($otherGameId, 'open');

        DB::table('stock_reservations')->insert([
            'id' => $otherReservationId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['customer_id'],
            'game_id' => $otherGameId,
            'status' => 'converted',
            'expires_at' => now()->addHour(),
            'released_at' => null,
            'cancelled_at' => null,
            'converted_at' => now(),
            'idempotency_key' => 'm8-reserve-report-other',
            'payload_hash' => hash('sha256', 'm8-reserve-report-other'),
            'released_idempotency_key' => null,
            'released_payload_hash' => null,
            'cancelled_idempotency_key' => null,
            'cancelled_payload_hash' => null,
            'cancelled_by_admin_id' => null,
            'cancel_reason' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('orders')->insert([
            'id' => $otherOrderId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['customer_id'],
            'reservation_id' => $otherReservationId,
            'game_id' => $otherGameId,
            'wallet_id' => null,
            'payment_method' => 'bank_transfer',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => 25000,
            'currency' => 'THB',
            'reference' => 'M8-report-other',
            'admin_note' => null,
            'idempotency_key' => 'm8-order-report-other',
            'payload_hash' => hash('sha256', 'm8-order-report-other'),
            'paid_at' => now(),
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('stock_items')->insert([
            'id' => $otherStockId,
            'game_id' => $otherGameId,
            'batch_id' => null,
            'full_number' => '123456',
            'front3' => '123',
            'back3' => '456',
            'back2' => '56',
            'status' => 'sold',
            'partner_id' => $world['partner_id'],
            'tenant_id' => $world['tenant_id'],
            'allocation_id' => null,
            'recall_reason' => null,
            'recalled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $centralAdmin = $this->m8CentralAdmin(['report.view'], 'report-central-draw-filter');
        $headers = ['X-Admin-Scope' => 'central'];

        $unfilteredSales = $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/sales?tenant_id='.$world['tenant_id'], $headers)
            ->assertOk()
            ->json();

        $this->assertSame(35000, $unfilteredSales['summary']['sales_total']['amount']);

        $selectedGameSales = $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/sales?tenant_id='.$world['tenant_id'].'&game_id='.$world['game_id'], $headers)
            ->assertOk()
            ->assertJsonPath('game_id', $world['game_id'])
            ->assertJsonPath('meta.game_filter_supported', true)
            ->assertJsonPath('meta.game_filter_applied', true)
            ->assertJsonPath('summary.sales_total.amount', 10000)
            ->json();

        $this->assertSame($world['order_id'], $selectedGameSales['rows'][0]['id']);

        $otherGameSales = $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/sales?tenant_id='.$world['tenant_id'].'&game_id='.$otherGameId, $headers)
            ->assertOk()
            ->assertJsonPath('summary.sales_total.amount', 25000)
            ->json();

        $this->assertSame($otherOrderId, $otherGameSales['rows'][0]['id']);

        $selectedGameStock = $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/stock?tenant_id='.$world['tenant_id'].'&game_id='.$world['game_id'], $headers)
            ->assertOk()
            ->assertJsonPath('summary.stock_total_count', 1)
            ->json();

        $this->assertSame($world['game_id'], $selectedGameStock['meta']['game_id']);
        $this->assertCount(1, $selectedGameStock['rows']);
        $this->assertSame($world['game_id'], $selectedGameStock['meta']['game']['id']);
    }
}

<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class TenantStockTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_TenantStock_list_view_export_are_permissioned_tenant_scoped_and_audited(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_stock_tenant', 'ten_stock_tenant', 'tenant-stock.newpaotang.test');
        $this->insertActivePartnerTenantWithDomain('par_stock_other', 'ten_stock_other', 'tenant-stock-other.newpaotang.test');
        $this->insertGame('gam_tenant_stock', 'open');
        $this->insertBaseLotteryNumbers(['111110', '111111', '222220']);
        $this->insertVirtualProfile('gam_tenant_stock', 3);
        $this->insertVirtualAllocation('gam_tenant_stock', 'par_stock_tenant', 'ten_stock_tenant', 6670, 2);
        $this->insertVirtualAllocation('gam_tenant_stock', 'par_stock_other', 'ten_stock_other', 3330, 1);

        $limited = $this->createTenantSession('ten_stock_tenant', 'par_stock_tenant', ['reservation.view'], 'adm_stock_limited', 'stock-limited@example.test');
        $this->withToken($limited['access_token'])
            ->getJson('/api/v1/admin/tenant/stock', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $stockAdmin = $this->createTenantSession(
            'ten_stock_tenant',
            'par_stock_tenant',
            ['stock.view', 'stock.export'],
            'adm_stock_view',
            'stock-view@example.test',
        );

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock?game_id=gam_tenant_stock&number=111110', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.tenant_id', 'ten_stock_tenant')
            ->assertJsonPath('data.0.stock_mode', 'virtual')
            ->assertJsonPath('meta.has_more', false);

        $pagedStock = $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock?'.http_build_query([
                'game_id' => 'gam_tenant_stock',
                'limit' => 1,
            ]), [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertOk()
            ->assertJsonPath('meta.has_more', true)
            ->json();

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock?'.http_build_query([
                'game_id' => 'gam_tenant_stock',
                'cursor' => $pagedStock['meta']['next_cursor'],
                'limit' => 1,
            ]), [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertOk();

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock/'.$pagedStock['data'][0]['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertOk()
            ->assertJsonPath('id', $pagedStock['data'][0]['id'])
            ->assertJsonPath('stock_mode', 'virtual');

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock/vstock:ten_stock_other:gam_tenant_stock:222220:0', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');

        $this->withToken($stockAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/stock/exports', [
                'game_id' => 'gam_tenant_stock',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $export = $this->withToken($stockAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/stock/exports', [
                'game_id' => 'gam_tenant_stock',
                'api_secret' => 'redact-me',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
                'Idempotency-Key' => 'tenant-stock-export',
            ])
            ->assertAccepted()
            ->assertJsonPath('tenant_id', 'ten_stock_tenant')
            ->json();

        $replay = $this->withToken($stockAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/stock/exports', [
                'game_id' => 'gam_tenant_stock',
                'api_secret' => 'redact-me',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
                'Idempotency-Key' => 'tenant-stock-export',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($export['id'], $replay['id']);
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_stock_tenant',
            'action' => 'stock.export_requested',
            'target_id' => $export['id'],
        ]);

        $auditPayload = json_decode((string) DB::table('audit_logs')
            ->where('target_id', $export['id'])
            ->value('payload_redacted_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('[REDACTED]', $auditPayload['payload']['api_secret']);
    }

    public function test_TenantStock_lists_virtual_allocation_without_materializing_local_stock(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_virtual_tenant_stock', 'ten_virtual_tenant_stock', 'tenant-virtual-stock.newpaotang.test');
        $this->insertGame('gam_virtual_tenant_stock', 'open');
        $this->insertBaseLotteryNumbers(['123456', '123457']);
        $this->insertVirtualProfile('gam_virtual_tenant_stock', 2);
        $this->insertVirtualAllocation('gam_virtual_tenant_stock', 'par_virtual_tenant_stock', 'ten_virtual_tenant_stock', 10000, 2);

        $stockAdmin = $this->createTenantSession(
            'ten_virtual_tenant_stock',
            'par_virtual_tenant_stock',
            ['stock.view'],
            'adm_virtual_stock_view',
            'virtual-stock-view@example.test',
        );

        $stock = $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock?limit=1', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_virtual_tenant_stock',
            ])
            ->assertOk()
            ->assertJsonPath('meta.stock_mode', 'virtual')
            ->assertJsonPath('meta.game_id', 'gam_virtual_tenant_stock')
            ->assertJsonPath('meta.allocated_count', 2)
            ->assertJsonPath('data.0.stock_mode', 'virtual')
            ->assertJsonPath('data.0.tenant_id', 'ten_virtual_tenant_stock')
            ->assertJsonPath('data.0.partner_id', 'par_virtual_tenant_stock')
            ->assertJsonPath('data.0.status', 'available')
            ->assertJsonPath('meta.has_more', true)
            ->json();

        $this->assertSame(0, DB::table('local_stock_items')->where('tenant_id', 'ten_virtual_tenant_stock')->count());
        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_virtual_tenant_stock')->count());

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock/'.$stock['data'][0]['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_virtual_tenant_stock',
            ])
            ->assertOk()
            ->assertJsonPath('id', $stock['data'][0]['id'])
            ->assertJsonPath('stock_mode', 'virtual')
            ->assertJsonPath('status', 'available');

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock?'.http_build_query([
                'game_id' => 'gam_virtual_tenant_stock',
                'number' => '123457',
                'limit' => 5,
            ]), [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_virtual_tenant_stock',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '123457')
            ->assertJsonPath('data.0.stock_mode', 'virtual');
    }

    public function test_TenantStock_games_coverage_and_owner_fields_are_tenant_scoped(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_tenant_stock_ui', 'ten_tenant_stock_ui', 'tenant-stock-ui.newpaotang.test');
        $this->insertGame('gam_tenant_stock_old', 'open');
        $this->insertGame('gam_tenant_stock_new', 'open');
        DB::table('games')->where('id', 'gam_tenant_stock_old')->update(['draw_at' => now()->addDay()]);
        DB::table('games')->where('id', 'gam_tenant_stock_new')->update(['draw_at' => now()->addDays(2)]);
        $this->insertBaseLotteryNumbers(['555550', '555551']);
        $this->insertVirtualProfile('gam_tenant_stock_old', 2);
        $this->insertVirtualProfile('gam_tenant_stock_new', 2);
        $this->insertVirtualAllocation('gam_tenant_stock_old', 'par_tenant_stock_ui', 'ten_tenant_stock_ui', 10000, 2);
        $this->insertVirtualAllocation('gam_tenant_stock_new', 'par_tenant_stock_ui', 'ten_tenant_stock_ui', 10000, 2);

        $stockAdmin = $this->createTenantSession(
            'ten_tenant_stock_ui',
            'par_tenant_stock_ui',
            ['stock.view'],
            'adm_tenant_stock_ui',
            'tenant-stock-ui@example.test',
        );

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock/games', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_stock_ui',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', 'gam_tenant_stock_new')
            ->assertJsonPath('data.0.is_default', true)
            ->assertJsonPath('meta.default_game_id', 'gam_tenant_stock_new');

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock/coverage?'.http_build_query([
                'game_id' => 'gam_tenant_stock_new',
                'dimension' => 'back2',
                'limit' => 1,
            ]), [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_stock_ui',
            ])
            ->assertOk()
            ->assertJsonPath('scope_type', 'partner')
            ->assertJsonPath('scope_id', 'par_tenant_stock_ui')
            ->assertJsonStructure(['data' => [['number', 'generated_count', 'reserved_count', 'sold_count', 'sellable_remaining_count']]]);

        $availableStock = $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock?'.http_build_query([
                'game_id' => 'gam_tenant_stock_new',
                'number' => '555550',
                'limit' => 1,
            ]), [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_stock_ui',
            ])
            ->assertOk()
            ->json('data.0');

        $customerToken = $this->issueCustomerToken('ten_tenant_stock_ui', 'cus_tenant_stock_owner');
        $reservation = $this->withToken($customerToken)
            ->postJson('http://tenant-stock-ui.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_tenant_stock_new',
                'local_stock_item_ids' => [$availableStock['id']],
            ], [
                'Idempotency-Key' => 'tenant-stock-owner',
            ])
            ->assertCreated()
            ->json();
        $localStockId = $reservation['items'][0]['id'];

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock?'.http_build_query([
                'game_id' => 'gam_tenant_stock_new',
                'status' => 'reserved',
            ]), [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_stock_ui',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $localStockId)
            ->assertJsonPath('data.0.owner_customer_id', 'cus_tenant_stock_owner');

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock/'.$localStockId, [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_stock_ui',
            ])
            ->assertOk()
            ->assertJsonPath('owner_customer_id', 'cus_tenant_stock_owner');
    }

    /**
     * @param array<int, string> $numbers
     */
    private function insertBaseLotteryNumbers(array $numbers): void
    {
        DB::table('base_lottery_numbers')->insert(array_map(fn (string $number): array => [
            'full_number' => $number,
            'front3' => substr($number, 0, 3),
            'back3' => substr($number, -3),
            'back2' => substr($number, -2),
            'created_at' => now(),
            'updated_at' => now(),
        ], $numbers));
    }

    private function insertVirtualProfile(string $gameId, int $totalCapacity): void
    {
        DB::table('stock_supply_profiles')->insert([
            'id' => 'vsp_'.$gameId,
            'game_id' => $gameId,
            'status' => 'active',
            'seed' => 'tenant-virtual-stock-seed',
            'base_count' => $totalCapacity,
            'total_capacity' => $totalCapacity,
            'set_distribution_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertVirtualAllocation(string $gameId, string $partnerId, string $tenantId, int $basisPoints, int $allocatedCount): void
    {
        DB::table('partner_stock_allocations')->insert([
            'id' => 'alc_'.substr(sha1($gameId.':'.$partnerId), 0, 20),
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => $allocatedCount,
            'allocation_percent_basis_points' => $basisPoints,
            'allocated_count' => $allocatedCount,
            'recalled_count' => 0,
            'supply_layer_ids_json' => json_encode(['vsp_'.$gameId], JSON_THROW_ON_ERROR),
            'idempotency_key' => 'tenant-virtual-stock',
            'payload_hash' => hash('sha256', $gameId.':'.$partnerId.':'.$basisPoints),
            'created_by_admin_id' => null,
            'reason' => null,
            'cancelled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}

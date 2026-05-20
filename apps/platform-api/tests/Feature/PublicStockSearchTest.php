<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class PublicStockSearchTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_PublicStockSearch_resolves_tenant_current_game_filters_indexes_and_blocks_maintenance(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_public_a', 'ten_public_a', 'a.newpaotang.test');
        $this->insertActivePartnerTenantWithDomain('par_public_b', 'ten_public_b', 'b.newpaotang.test');
        $this->insertGame('gam_public', 'open');

        $this->syncAllocatedStockToLocal('par_public_a', 'ten_public_a', 'gam_public', 3, 'alloc-public-a', 123450);
        $this->syncAllocatedStockToLocal('par_public_b', 'ten_public_b', 'gam_public', 1, 'alloc-public-b', 999990);

        $this->getJson('http://a.newpaotang.test/api/v1/public/games/current', [
            'X-Request-Id' => 'req-current-game',
        ])
            ->assertOk()
            ->assertJsonPath('id', 'gam_public')
            ->assertJsonPath('status', 'open');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&number=123450')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '123450')
            ->assertJsonPath('meta.has_more', false);

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&front3=123')
            ->assertOk()
            ->assertJsonCount(3, 'data');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&back2=50')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '123450');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&number=999990')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://b.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&number=999990')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '999990');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&store_id=ten_public_a&number=123450')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '123450');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&store_id=ten_public_b&number=999990')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->setTenantMaintenance('ten_public_a');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public')
            ->assertStatus(503)
            ->assertHeader('Retry-After', '300')
            ->assertJsonPath('error.code', 'maintenance_active');
    }

    public function test_PublicStockSearch_filters_by_store_id_within_tenant_and_composes_with_search_options(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_store_filter_a', 'ten_store_filter_a', 'filter-a.newpaotang.test');
        $this->insertActivePartnerTenantWithDomain('par_store_filter_b', 'ten_store_filter_b', 'filter-b.newpaotang.test');
        $this->insertGame('gam_store_filter', 'open');

        $storeOneItems = $this->syncAllocatedStockToLocal('par_store_filter_a', 'ten_store_filter_a', 'gam_store_filter', 2, 'alloc-store-filter-one', 123450, 'sto_filter_one');
        $storeTwoItems = $this->syncAllocatedStockToLocal('par_store_filter_a', 'ten_store_filter_a', 'gam_store_filter', 2, 'alloc-store-filter-two', 123460, 'sto_filter_two');
        $this->syncAllocatedStockToLocal('par_store_filter_b', 'ten_store_filter_b', 'gam_store_filter', 1, 'alloc-store-filter-foreign', 123470, 'sto_filter_foreign');

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&front3=123')
            ->assertOk()
            ->assertJsonCount(4, 'data');

        $storeOne = $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_one&front3=123')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->json('data');

        $this->assertSame(collect($storeOneItems)->sort()->values()->all(), collect($storeOne)->pluck('id')->sort()->values()->all());

        $storeTwo = $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_two&number=123')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->json('data');

        $this->assertSame(collect($storeTwoItems)->sort()->values()->all(), collect($storeTwo)->pluck('id')->sort()->values()->all());

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_two&back2=60')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '123460');

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_one&back2=60')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $pageOne = $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_two&front3=123&limit=1')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.has_more', true)
            ->json();

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_two&front3=123&limit=1&cursor='.$pageOne['meta']['next_cursor'])
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.has_more', false);

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_one&mode=random&limit=1')
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_foreign&front3=123')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://filter-b.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_foreign&front3=123')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_PublicStockSearch_returns_multiple_available_tickets_with_same_number(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_dup_number', 'ten_dup_number', 'dup-number.newpaotang.test');
        $this->insertGame('gam_dup_number', 'open');

        $now = now();
        DB::table('stock_items')->insert([
            [
                'id' => 'stk_dup_number_a',
                'game_id' => 'gam_dup_number',
                'batch_id' => null,
                'full_number' => '444444',
                'front3' => '444',
                'back3' => '444',
                'back2' => '44',
                'status' => 'allocated',
                'partner_id' => 'par_dup_number',
                'tenant_id' => 'ten_dup_number',
                'allocation_id' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => 'stk_dup_number_b',
                'game_id' => 'gam_dup_number',
                'batch_id' => null,
                'full_number' => '444444',
                'front3' => '444',
                'back3' => '444',
                'back2' => '44',
                'status' => 'allocated',
                'partner_id' => 'par_dup_number',
                'tenant_id' => 'ten_dup_number',
                'allocation_id' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ]);

        DB::table('local_stock_items')->insert([
            [
                'id' => 'lsi_dup_number_a',
                'tenant_id' => 'ten_dup_number',
                'partner_id' => 'par_dup_number',
                'store_id' => 'ten_dup_number',
                'game_id' => 'gam_dup_number',
                'stock_item_id' => 'stk_dup_number_a',
                'allocation_id' => null,
                'full_number' => '444444',
                'front3' => '444',
                'back3' => '444',
                'back2' => '44',
                'status' => 'available',
                'synced_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => 'lsi_dup_number_b',
                'tenant_id' => 'ten_dup_number',
                'partner_id' => 'par_dup_number',
                'store_id' => 'ten_dup_number',
                'game_id' => 'gam_dup_number',
                'stock_item_id' => 'stk_dup_number_b',
                'allocation_id' => null,
                'full_number' => '444444',
                'front3' => '444',
                'back3' => '444',
                'back2' => '44',
                'status' => 'available',
                'synced_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ]);

        $this->getJson('http://dup-number.newpaotang.test/api/v1/public/stock/search?game_id=gam_dup_number&number=444444')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.full_number', '444444')
            ->assertJsonPath('data.1.full_number', '444444');
    }

    public function test_PublicStockSearch_virtual_visibility_requires_active_distribution_and_reservation_materializes_stock(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_virtual_public', 'ten_virtual_public', 'virtual-public.newpaotang.test');
        $this->insertGame('gam_virtual_public', 'open');
        $this->insertBaseLotteryNumbers(['123456']);
        $this->insertVirtualProfile('gam_virtual_public');

        $this->getJson('http://virtual-public.newpaotang.test/api/v1/public/stock/search?game_id=gam_virtual_public&number=123456')
            ->assertOk()
            ->assertJsonPath('meta.stock_mode', 'virtual')
            ->assertJsonCount(0, 'data');

        $this->insertPartnerDistribution('gam_virtual_public', 'par_virtual_public', 'ten_virtual_public', 10000);

        $stock = $this->getJson('http://virtual-public.newpaotang.test/api/v1/public/stock/search?game_id=gam_virtual_public&number=123456')
            ->assertOk()
            ->assertJsonPath('meta.stock_mode', 'virtual')
            ->assertJsonPath('data.0.stock_mode', 'virtual')
            ->assertJsonPath('data.0.full_number', '123456')
            ->json('data.0');

        $customerToken = $this->issueCustomerToken('ten_virtual_public', 'cus_virtual_public');
        $this->withToken($customerToken)
            ->postJson('http://virtual-public.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_virtual_public',
                'local_stock_item_ids' => [$stock['id']],
            ], [
                'Idempotency-Key' => 'reserve-virtual-public',
            ])
            ->assertCreated()
            ->assertJsonPath('items.0.stock_mode', 'virtual')
            ->assertJsonPath('items.0.full_number', '123456');

        $this->assertSame(1, DB::table('stock_items')->where('game_id', 'gam_virtual_public')->whereNotNull('virtual_stock_ref')->count());
        $this->assertSame(1, DB::table('local_stock_items')->where('tenant_id', 'ten_virtual_public')->whereNotNull('virtual_stock_ref')->count());
    }

    public function test_PublicStockSearch_ignores_retired_partner_quota_sale_window_overrides(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_window', 'ten_window', 'window.newpaotang.test');
        $this->insertGame('gam_window', 'open');
        $this->insertQuota('pqt_window', 'par_window', 'gam_window', 1);
        $this->syncAllocatedStockToLocal('par_window', 'ten_window', 'gam_window', 1, 'alloc-window', 777770);

        DB::table('partner_quotas')
            ->where('partner_id', 'par_window')
            ->where('game_id', 'gam_window')
            ->update([
                'sale_start_at' => now()->addHour(),
                'sale_close_at' => null,
                'updated_at' => now(),
            ]);

        $this->getJson('http://window.newpaotang.test/api/v1/public/games/current')
            ->assertOk()
            ->assertJsonPath('id', 'gam_window');

        $this->getJson('http://window.newpaotang.test/api/v1/public/stock/search?game_id=gam_window&number=777770')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '777770');

        DB::table('partner_quotas')
            ->where('partner_id', 'par_window')
            ->where('game_id', 'gam_window')
            ->update([
                'sale_start_at' => null,
                'sale_close_at' => now()->addHour(),
                'updated_at' => now(),
            ]);

        $this->getJson('http://window.newpaotang.test/api/v1/public/games/current')
            ->assertOk()
            ->assertJsonPath('id', 'gam_window');

        $this->getJson('http://window.newpaotang.test/api/v1/public/stock/search?game_id=gam_window&number=777770')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '777770');

        DB::table('partner_quotas')
            ->where('partner_id', 'par_window')
            ->where('game_id', 'gam_window')
            ->update([
                'sale_start_at' => null,
                'sale_close_at' => now()->subMinute(),
                'updated_at' => now(),
            ]);

        $this->getJson('http://window.newpaotang.test/api/v1/public/stock/search?game_id=gam_window&number=777770')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '777770');
    }

    /**
     * @param array<int, string> $numbers
     */
    private function insertBaseLotteryNumbers(array $numbers): void
    {
        $rows = [];

        foreach ($numbers as $number) {
            $rows[] = [
                'full_number' => $number,
                'front3' => substr($number, 0, 3),
                'back3' => substr($number, -3),
                'back2' => substr($number, -2),
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        DB::table('base_lottery_numbers')->insert($rows);
    }

    private function insertVirtualProfile(string $gameId): void
    {
        DB::table('stock_supply_profiles')->insert([
            'id' => 'vsp_'.$gameId,
            'game_id' => $gameId,
            'status' => 'active',
            'seed' => 'virtual-public-seed',
            'base_count' => 1,
            'total_capacity' => 1,
            'set_distribution_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertPartnerDistribution(string $gameId, string $partnerId, string $tenantId, int $basisPoints): void
    {
        DB::table('stock_partner_distributions')->insert([
            'id' => 'spd_'.substr(sha1($gameId.':'.$partnerId), 0, 20),
            'game_id' => $gameId,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'percent_basis_points' => $basisPoints,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}

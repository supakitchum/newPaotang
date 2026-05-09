<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
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
}

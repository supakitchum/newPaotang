<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class PublicStockSearchTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_PublicStockSearch_hides_retired_physical_stock_and_blocks_maintenance(): void
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
            ->assertJsonCount(0, 'data')
            ->assertJsonPath('meta.has_more', false);

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&front3=123')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&back2=50')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&number=999990')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://b.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&number=999990')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&store_id=ten_public_a&number=123450')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public&store_id=ten_public_b&number=999990')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->setTenantMaintenance('ten_public_a');

        $this->getJson('http://a.newpaotang.test/api/v1/public/stock/search?game_id=gam_public')
            ->assertStatus(503)
            ->assertHeader('Retry-After', '300')
            ->assertJsonPath('error.code', 'maintenance_active');
    }

    public function test_PublicStockSearch_no_longer_serves_physical_store_scoped_rows(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_store_filter_a', 'ten_store_filter_a', 'filter-a.newpaotang.test');
        $this->insertActivePartnerTenantWithDomain('par_store_filter_b', 'ten_store_filter_b', 'filter-b.newpaotang.test');
        $this->insertGame('gam_store_filter', 'open');

        $this->syncAllocatedStockToLocal('par_store_filter_a', 'ten_store_filter_a', 'gam_store_filter', 2, 'alloc-store-filter-one', 123450, 'sto_filter_one');
        $this->syncAllocatedStockToLocal('par_store_filter_a', 'ten_store_filter_a', 'gam_store_filter', 2, 'alloc-store-filter-two', 123460, 'sto_filter_two');
        $this->syncAllocatedStockToLocal('par_store_filter_b', 'ten_store_filter_b', 'gam_store_filter', 1, 'alloc-store-filter-foreign', 123470, 'sto_filter_foreign');

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&front3=123')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_one&front3=123')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_two&number=123')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_two&back2=60')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_one&back2=60')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $pageOne = $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_two&front3=123&limit=1')
            ->assertOk()
            ->assertJsonCount(0, 'data')
            ->assertJsonPath('meta.has_more', false)
            ->json();

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_two&front3=123&limit=1&cursor='.($pageOne['meta']['next_cursor'] ?? ''))
            ->assertOk()
            ->assertJsonCount(0, 'data')
            ->assertJsonPath('meta.has_more', false);

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_one&mode=random&limit=1')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://filter-a.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_foreign&front3=123')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson('http://filter-b.newpaotang.test/api/v1/public/stock/search?game_id=gam_store_filter&store_id=sto_filter_foreign&front3=123')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_PublicStockSearch_does_not_return_legacy_duplicate_physical_tickets(): void
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
            ->assertJsonCount(0, 'data');
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
            ->assertJsonCount(0, 'data');

        $this->insertPartnerDistribution('gam_virtual_public', 'par_virtual_public', 'ten_virtual_public', 10000);

        $search = $this->getJson('http://virtual-public.newpaotang.test/api/v1/public/stock/search?game_id=gam_virtual_public&number=123456')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '123456')
            ->assertJsonPath('data.0.price.amount', 8000)
            ->json();
        $this->assertArrayNotHasKey('stock_mode', $search['meta']);
        $this->assertArrayNotHasKey('stock_mode', $search['data'][0]);
        $stock = $search['data'][0];

        $customerToken = $this->issueCustomerToken('ten_virtual_public', 'cus_virtual_public');
        $reservation = $this->withToken($customerToken)
            ->postJson('http://virtual-public.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_virtual_public',
                'local_stock_item_ids' => [$stock['id']],
            ], [
                'Idempotency-Key' => 'reserve-virtual-public',
            ])
            ->assertCreated()
            ->assertJsonPath('items.0.full_number', '123456')
            ->assertJsonPath('items.0.price.amount', 8000)
            ->json();
        $this->assertArrayNotHasKey('stock_mode', $reservation['items'][0]);

        $this->assertSame(1, DB::table('stock_items')->where('game_id', 'gam_virtual_public')->whereNotNull('virtual_stock_ref')->count());
        $this->assertSame(1, DB::table('local_stock_items')->where('tenant_id', 'ten_virtual_public')->whereNotNull('virtual_stock_ref')->count());
    }

    public function test_PublicStockSearch_random_virtual_results_interleave_duplicate_copy_numbers(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_random_virtual', 'ten_random_virtual', 'random-virtual.newpaotang.test');
        $this->insertGame('gam_random_virtual', 'open');
        $this->insertBaseLotteryNumbers(['111111', '222222', '333333']);
        $this->insertVirtualProfile('gam_random_virtual', 3, 9, [[
            'set_size' => 3,
            'percent_basis_points' => 10000,
        ]]);
        $this->insertPartnerDistribution('gam_random_virtual', 'par_random_virtual', 'ten_random_virtual', 10000, 9);

        $rows = $this->getJson('http://random-virtual.newpaotang.test/api/v1/public/stock/search?game_id=gam_random_virtual&mode=random&limit=6')
            ->assertOk()
            ->assertJsonCount(6, 'data')
            ->json('data');

        for ($index = 1; $index < count($rows); $index++) {
            $this->assertNotSame($rows[$index - 1]['full_number'], $rows[$index]['full_number']);
        }
    }

    public function test_PublicStockSearch_short_number_uses_suffix_matching(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_suffix_virtual', 'ten_suffix_virtual', 'suffix-virtual.newpaotang.test');
        $this->insertGame('gam_suffix_virtual', 'open');
        $this->insertBaseLotteryNumbers(['000222', '000223', '123422']);
        $this->insertVirtualProfile('gam_suffix_virtual', 3, 3);
        $this->insertPartnerDistribution('gam_suffix_virtual', 'par_suffix_virtual', 'ten_suffix_virtual', 10000, 3);

        $rows = $this->getJson('http://suffix-virtual.newpaotang.test/api/v1/public/stock/search?game_id=gam_suffix_virtual&number=22&limit=10')
            ->assertOk()
            ->json('data');

        $numbers = array_values(array_map(fn (array $row): string => (string) $row['full_number'], $rows));
        $this->assertContains('000222', $numbers);
        $this->assertContains('123422', $numbers);
        $this->assertNotContains('000223', $numbers);
        $this->assertTrue(collect($numbers)->every(fn (string $number): bool => str_ends_with($number, '22')));
    }

    public function test_PublicStockSearch_virtual_preview_image_url_is_deterministic_lazy_and_renders_on_demand(): void
    {
        config([
            'app.url' => 'http://preview-api.newpaotang.test',
            'lottery_images.object_prefix' => 'test-lotteries-preview',
            'lottery_images.asset_root' => storage_path('framework/testing/lottery-images-preview'),
        ]);
        Storage::disk('lottery_images')->deleteDirectory('test-lotteries-preview');

        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_virtual_preview', 'ten_virtual_preview', 'virtual-preview.newpaotang.test');
        $this->insertGame('gam_virtual_preview', 'open');
        $this->insertBaseLotteryNumbers(['654321']);
        $this->insertVirtualProfile('gam_virtual_preview');
        $this->insertPartnerDistribution('gam_virtual_preview', 'par_virtual_preview', 'ten_virtual_preview', 10000);
        $this->insertReadyVirtualImageAssets('par_virtual_preview', 'gam_virtual_preview');

        $first = $this->getJson('http://virtual-preview.newpaotang.test/api/v1/public/stock/search?game_id=gam_virtual_preview&number=654321')
            ->assertOk()
            ->assertJsonPath('data.0.image_url', null)
            ->assertJsonPath('data.0.image_status', 'ready')
            ->json('data.0');

        $second = $this->getJson('http://virtual-preview.newpaotang.test/api/v1/public/stock/search?game_id=gam_virtual_preview&number=654321')
            ->assertOk()
            ->json('data.0');

        $this->assertIsString($first['preview_image_url'] ?? null);
        $this->assertStringContainsString('/api/v1/public/stock/images/', $first['preview_image_url']);
        $this->assertSame($first['preview_image_url'], $first['image_thumb_url']);
        $this->assertSame($first['preview_image_url'], $second['preview_image_url']);
        $this->assertSame([], Storage::disk('lottery_images')->allFiles('test-lotteries-preview/cache/virtual'));

        $path = parse_url((string) $first['preview_image_url'], PHP_URL_PATH);
        $this->assertIsString($path);

        $image = $this->get($path)
            ->assertOk()
            ->assertHeader('Content-Type', 'image/webp')
            ->getContent();

        $this->assertStringStartsWith('RIFF', $image);
        $this->assertSame('WEBP', substr($image, 8, 4));
        $this->assertCount(1, Storage::disk('lottery_images')->allFiles('test-lotteries-preview/cache/virtual'));

        $this->get($path)->assertOk();
        $this->assertCount(1, Storage::disk('lottery_images')->allFiles('test-lotteries-preview/cache/virtual'));
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
            ->assertJsonCount(0, 'data');

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
            ->assertJsonCount(0, 'data');

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
            ->assertJsonCount(0, 'data');
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

    /**
     * @param array<int, array{set_size: int, percent_basis_points: int}> $distribution
     */
    private function insertVirtualProfile(string $gameId, int $baseCount = 1, int $totalCapacity = 1, array $distribution = []): void
    {
        DB::table('stock_supply_profiles')->insert([
            'id' => 'vsp_'.$gameId,
            'game_id' => $gameId,
            'status' => 'active',
            'seed' => 'virtual-public-seed',
            'base_count' => $baseCount,
            'total_capacity' => $totalCapacity,
            'set_distribution_json' => json_encode($distribution, JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertPartnerDistribution(string $gameId, string $partnerId, string $tenantId, int $basisPoints, ?int $allocatedCount = null): void
    {
        $allocatedCount ??= (int) floor(((int) DB::table('stock_supply_profiles')->where('id', 'vsp_'.$gameId)->value('total_capacity') * $basisPoints) / 10000);

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

        DB::table('partner_stock_allocations')->insert([
            'id' => 'alc_'.substr(sha1($gameId.':'.$partnerId), 0, 20),
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => $allocatedCount,
            'allocation_percent_basis_points' => $basisPoints,
            'supply_layer_ids_json' => json_encode(['vsp_'.$gameId], JSON_THROW_ON_ERROR),
            'allocated_count' => $allocatedCount,
            'recalled_count' => 0,
            'idempotency_key' => 'fixture-'.$gameId.'-'.$partnerId,
            'payload_hash' => hash('sha256', $gameId.':'.$partnerId),
            'created_by_admin_id' => null,
            'reason' => null,
            'cancelled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertReadyVirtualImageAssets(string $partnerId, string $gameId): void
    {
        foreach (['odd', 'even', 'charity'] as $setType) {
            $directory = storage_path('framework/testing/lottery-images-preview/games/'.$gameId.'/backgrounds/v1/'.$setType);

            if (! is_dir($directory)) {
                mkdir($directory, 0777, true);
            }

            file_put_contents($directory.'/001.webp', $this->fixtureWebp(500, 280));
        }

        $assetIds = [];

        foreach ([
            'logo_qr' => ['file' => 'logo_qr.webp', 'width' => 80, 'height' => 80],
            'right_sidebar' => ['file' => 'rightsidebar.webp', 'width' => 80, 'height' => 240],
            'logo_bottom' => ['file' => 'logo_bottom.webp', 'width' => 160, 'height' => 60],
        ] as $slot => $asset) {
            $assetId = 'ast_'.substr(sha1($partnerId.':'.$slot), 0, 20);
            $storageKey = 'partners/'.$partnerId.'/lottery-branding/v1/'.$asset['file'];
            $bytes = $this->fixtureWebp($asset['width'], $asset['height']);
            $assetIds[$slot] = $assetId;

            Storage::disk('lottery_images')->put($storageKey, $bytes);
            DB::table('platform_assets')->insert([
                'id' => $assetId,
                'scope_type' => 'central',
                'tenant_id' => null,
                'created_by_admin_id' => null,
                'purpose' => 'partner_lottery_branding',
                'file_name' => $asset['file'],
                'content_type' => 'image/webp',
                'size_bytes' => strlen($bytes),
                'checksum_sha256' => hash('sha256', $bytes),
                'status' => 'committed',
                'storage_key' => $storageKey,
                'upload_url' => null,
                'public_url' => 'https://cdn.lottery.test/'.$storageKey,
                'metadata_json' => json_encode(['partner_id' => $partnerId, 'branding_slot' => $slot, 'version' => 'v1'], JSON_THROW_ON_ERROR),
                'expires_at' => null,
                'committed_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        DB::table('partner_lottery_branding_asset_sets')->insert([
            'id' => 'pba_'.substr(sha1($partnerId.':ready'), 0, 20),
            'partner_id' => $partnerId,
            'version' => 'v1',
            'status' => 'ready',
            'logo_qr_asset_id' => $assetIds['logo_qr'],
            'right_sidebar_asset_id' => $assetIds['right_sidebar'],
            'logo_bottom_asset_id' => $assetIds['logo_bottom'],
            'logo_qr_storage_path' => 'partners/'.$partnerId.'/lottery-branding/v1/logo_qr.webp',
            'right_sidebar_storage_path' => 'partners/'.$partnerId.'/lottery-branding/v1/rightsidebar.webp',
            'logo_bottom_storage_path' => 'partners/'.$partnerId.'/lottery-branding/v1/logo_bottom.webp',
            'uploaded_by_admin_id' => null,
            'activated_at' => now(),
            'locked_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function fixtureWebp(int $width, int $height): string
    {
        $image = imagecreatetruecolor($width, $height);
        $this->assertNotFalse($image);

        if ($image === false) {
            return '';
        }

        imagefill($image, 0, 0, imagecolorallocate($image, 244, 236, 220));
        ob_start();
        imagewebp($image, null, 80);
        $bytes = ob_get_clean();
        imagedestroy($image);

        $this->assertIsString($bytes);

        return $bytes;
    }
}

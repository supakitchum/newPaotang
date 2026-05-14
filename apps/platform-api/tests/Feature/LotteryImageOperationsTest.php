<?php

namespace Tests\Feature;

use App\Jobs\GenerateLotteryImageJob;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;
use ZipArchive;

class LotteryImageOperationsTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    private string $assetRoot;
    private string $storageRoot;

    protected function setUp(): void
    {
        parent::setUp();

        $suffix = Str::lower(Str::random(8));
        $this->assetRoot = storage_path('framework/testing/lottery-ops-assets/'.$suffix);
        $this->storageRoot = storage_path('framework/testing/lottery-ops-output/'.$suffix);

        config([
            'lottery_images.asset_root' => $this->assetRoot,
            'lottery_images.cdn_base_url' => 'https://cdn.lottery.test',
            'filesystems.disks.lottery_images.root' => $this->storageRoot,
        ]);
        Storage::forgetDisk('lottery_images');
    }

    public function test_LotteryImageBackground_central_admin_manages_background_sets_and_tenant_is_rejected(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_lottery_ops', 'ten_lottery_ops');
        $this->insertGame('gam_lottery_bg', 'open');

        $central = $this->createCentralSession(['asset.manage', 'stock.view'], 'adm_lottery_bg', 'lottery-bg@example.test');
        $tenant = $this->createTenantSession('ten_lottery_ops', 'par_lottery_ops', ['asset.manage'], 'adm_lottery_bg_tenant', 'lottery-bg-tenant@example.test');
        $assets = $this->insertBackgroundAssets('gam_lottery_bg', 'odd');

        $this->withToken($tenant['access_token'])
            ->putJson('/api/v1/admin/central/lottery-images/background-asset-sets', [
                'game_id' => 'gam_lottery_bg',
                'version' => 'v1',
                'set_type' => 'odd',
                'assets' => $assets,
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_lottery_ops',
                'Idempotency-Key' => 'tenant-bg-set',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $saved = $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/lottery-images/background-asset-sets', [
                'game_id' => 'gam_lottery_bg',
                'version' => 'v1',
                'set_type' => 'odd',
                'assets' => $assets,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-bg-set',
            ])
            ->assertOk()
            ->assertJsonPath('game_id', 'gam_lottery_bg')
            ->assertJsonPath('set_type', 'odd')
            ->assertJsonPath('ready', true)
            ->assertJsonPath('generation_ready', true)
            ->assertJsonPath('missing_assets', [])
            ->json();

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/lottery-images/background-asset-sets?game_id=gam_lottery_bg&version=v1', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $saved['id']);

        $this->withToken($central['access_token'])
            ->patchJson('/api/v1/admin/central/lottery-images/background-asset-sets/'.$saved['id'], [
                'status' => 'inactive',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-bg-set-inactive',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'inactive')
            ->assertJsonPath('ready', false);
    }

    public function test_LotteryImageMix_persists_percentages_and_generation_uses_them(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_mix_ops', 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.generate', 'stock.view'], 'adm_lottery_mix_ops', 'lottery-mix-ops@example.test');

        $this->registerBackgroundSet($central['access_token'], 'gam_lottery_mix_ops', 'odd', 'mix-odd-assets');

        $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/lottery-images/mix', [
                'game_id' => 'gam_lottery_mix_ops',
                'mix' => ['odd' => 80, 'even' => 10, 'charity' => 5],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'mix-invalid',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/lottery-images/mix', [
                'game_id' => 'gam_lottery_mix_ops',
                'mix' => ['odd' => 100, 'even' => 0, 'charity' => 0],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'mix-odd-only',
            ])
            ->assertOk()
            ->assertJsonPath('mix.odd', 100)
            ->assertJsonPath('source', 'persisted');

        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_lottery_mix_ops',
                'start_number' => 410000,
                'count' => 4,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'mix-generate-odd-only',
            ])
            ->assertAccepted();

        $counts = DB::table('stock_items')
            ->where('game_id', 'gam_lottery_mix_ops')
            ->select('background_set_type', DB::raw('COUNT(*) as total'))
            ->groupBy('background_set_type')
            ->pluck('total', 'background_set_type')
            ->map(fn (mixed $value): int => (int) $value)
            ->all();

        $this->assertSame(['odd' => 4], $counts);
        $this->assertSame(4, DB::table('stock_items')->where('game_id', 'gam_lottery_mix_ops')->where('image_generation_status', 'pending')->count());
    }

    public function test_LotteryImageReadiness_redacts_storage_queue_runtime_and_reports_missing_sets(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_ready_ops', 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.view'], 'adm_lottery_ready_ops', 'lottery-ready-ops@example.test');

        config([
            'filesystems.disks.lottery_images.key' => 'SHOULD_NOT_LEAK',
            'filesystems.disks.lottery_images.secret' => 'SECRET_SHOULD_NOT_LEAK',
        ]);

        $this->registerBackgroundSet($central['access_token'], 'gam_lottery_ready_ops', 'odd', 'ready-odd-assets');
        $this->insertImageStatusStock('stk_ready_pending', 'gam_lottery_ready_ops', '520001', 'even', 'pending_assets', 'background_set_not_ready:even');
        $this->insertImageStatusStock('stk_ready_failed', 'gam_lottery_ready_ops', '520002', 'charity', 'failed', 'lottery_image_webp_encode_failed');

        $readiness = $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/lottery-images/readiness?game_id=gam_lottery_ready_ops&version=v1', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('missing_set_types.0', 'even')
            ->assertJsonPath('pending_assets.central', 1)
            ->assertJsonPath('failed_generation.central', 1)
            ->json();

        $this->assertTrue($readiness['storage_readiness']['secrets_redacted']);
        $this->assertContains('stock-image-generation', $readiness['queue_readiness']['required_queue_names']);
        $this->assertStringContainsString('background_set_not_ready:even', json_encode($readiness['last_error_samples']));

        $body = $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/lottery-images/production-readiness', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('secrets_redacted', true)
            ->assertJsonPath('production_ready', false)
            ->baseResponse
            ->getContent();

        $this->assertStringNotContainsString('SHOULD_NOT_LEAK', $body);
        $this->assertStringNotContainsString('SECRET_SHOULD_NOT_LEAK', $body);
    }

    public function test_LotteryImageOps_retries_pending_assets_after_background_registration(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_retry_ops', 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.generate', 'stock.view'], 'adm_lottery_retry_ops', 'lottery-retry-ops@example.test');

        $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/lottery-images/mix', [
                'game_id' => 'gam_lottery_retry_ops',
                'mix' => ['odd' => 0, 'even' => 100, 'charity' => 0],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'retry-even-mix',
            ])
            ->assertOk();

        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_lottery_retry_ops',
                'start_number' => 630000,
                'count' => 2,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'retry-even-generate',
            ])
            ->assertAccepted();

        $this->assertSame(2, DB::table('stock_items')->where('game_id', 'gam_lottery_retry_ops')->where('image_generation_status', 'pending_assets')->count());

        Queue::fake();

        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/lottery-images/retry-pending', [
                'game_id' => 'gam_lottery_retry_ops',
                'dry_run' => true,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'retry-before-bg',
            ])
            ->assertAccepted()
            ->assertJsonPath('central.ready_count', 0);

        $this->registerBackgroundSet($central['access_token'], 'gam_lottery_retry_ops', 'even', 'retry-even-assets');

        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/lottery-images/retry-pending', [
                'game_id' => 'gam_lottery_retry_ops',
                'dry_run' => false,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'retry-after-bg',
            ])
            ->assertAccepted()
            ->assertJsonPath('central.ready_count', 2)
            ->assertJsonPath('central.dispatched_count', 2);

        Queue::assertPushed(GenerateLotteryImageJob::class, 2);
    }

    public function test_LotteryImageReadiness_reports_production_ready_when_s3_queue_runtime_are_configured_and_redacts_values(): void
    {
        $this->seedDefaultRbac();
        $central = $this->createCentralSession(['stock.view'], 'adm_lottery_prod_ops', 'lottery-prod-ops@example.test');

        config([
            'lottery_images.enabled' => true,
            'lottery_images.disk' => 'lottery_images',
            'lottery_images.cdn_base_url' => 'https://cdn.launch-lottery.example',
            'lottery_images.queues.central' => 'stock-image-generation',
            'lottery_images.queues.partner' => 'stock-partner-image-generation',
            'filesystems.disks.lottery_images.driver' => 's3',
            'filesystems.disks.lottery_images.bucket' => 'np-launch-lottery-private',
            'filesystems.disks.lottery_images.region' => 'ap-southeast-1',
            'filesystems.disks.lottery_images.endpoint' => 'https://r2.launch-lottery.example',
            'filesystems.disks.lottery_images.key' => 'ACCESS_KEY_SHOULD_NOT_LEAK',
            'filesystems.disks.lottery_images.secret' => 'SECRET_KEY_SHOULD_NOT_LEAK',
            'filesystems.disks.lottery_images.token' => 'SESSION_TOKEN_SHOULD_NOT_LEAK',
            'queue.default' => 'database',
            'queue.connections.database' => [
                'driver' => 'database',
                'table' => 'jobs',
                'queue' => 'default',
                'retry_after' => 90,
                'after_commit' => false,
            ],
        ]);

        $body = $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/lottery-images/production-readiness', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('configured', true)
            ->assertJsonPath('disk_driver', 's3')
            ->assertJsonPath('bucket_present', true)
            ->assertJsonPath('region_present', true)
            ->assertJsonPath('endpoint_present', true)
            ->assertJsonPath('cdn_base_url_present', true)
            ->assertJsonPath('queue_configured', true)
            ->assertJsonPath('runtime_webp_ready', true)
            ->assertJsonPath('secrets_redacted', true)
            ->assertJsonPath('production_ready', true)
            ->assertJsonPath('blocking_reasons', [])
            ->assertJsonPath('queues.required_queue_names.0', 'stock-image-generation')
            ->assertJsonPath('queues.required_queue_names.1', 'stock-partner-image-generation')
            ->baseResponse
            ->getContent();

        foreach ([
            'np-launch-lottery-private',
            'ap-southeast-1',
            'https://r2.launch-lottery.example',
            'https://cdn.launch-lottery.example',
            'ACCESS_KEY_SHOULD_NOT_LEAK',
            'SECRET_KEY_SHOULD_NOT_LEAK',
            'SESSION_TOKEN_SHOULD_NOT_LEAK',
        ] as $secretOrConfigValue) {
            $this->assertStringNotContainsString($secretOrConfigValue, $body);
        }
    }

    public function test_LotteryImageOps_object_keys_cdn_urls_and_cache_contract_are_stable(): void
    {
        config([
            'lottery_images.object_prefix' => 'lotteries',
            'lottery_images.cdn_base_url' => 'https://cdn.launch-lottery.example/assets',
            'lottery_images.content_type' => 'image/webp',
            'lottery_images.cache_control' => 'public, max-age=31536000, immutable',
        ]);

        /** @var LotteryImageGenerator $images */
        $images = $this->app->make(LotteryImageGenerator::class);

        $centralFull = $images->centralObjectKey('gam_launch', 'stb_launch', 'stk_000001');
        $centralThumb = $images->centralObjectKey('gam_launch', 'stb_launch', 'stk_000001', 'thumb');
        $partnerFull = $images->partnerObjectKey('gam_launch', 'stb_launch', 'par_alpha', 'stk_000001');
        $partnerThumb = $images->partnerObjectKey('gam_launch', 'stb_launch', 'par_alpha', 'stk_000001', 'thumb');

        $this->assertSame('lotteries/gam_launch/stb_launch/central/stk_000001.webp', $centralFull);
        $this->assertSame('lotteries/gam_launch/stb_launch/central/thumbs/stk_000001.webp', $centralThumb);
        $this->assertSame('lotteries/gam_launch/stb_launch/partners/par_alpha/stk_000001.webp', $partnerFull);
        $this->assertSame('lotteries/gam_launch/stb_launch/partners/par_alpha/thumbs/stk_000001.webp', $partnerThumb);
        $this->assertSame('https://cdn.launch-lottery.example/assets/'.$centralFull, $images->publicUrl($centralFull));
        $this->assertSame('image/webp', config('lottery_images.content_type'));
        $this->assertSame('public, max-age=31536000, immutable', config('lottery_images.cache_control'));
    }

    public function test_LotteryImageZipImport_central_admin_imports_image_zip_and_tenant_is_rejected(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_zip_ops', 'ten_zip_ops');
        $this->insertGame('gam_lottery_zip_ops', 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.view'], 'adm_lottery_zip_ops', 'lottery-zip@example.test');
        $tenant = $this->createTenantSession('ten_zip_ops', 'par_zip_ops', ['asset.manage'], 'adm_lottery_zip_tenant', 'lottery-zip-tenant@example.test');

        $this->withToken($tenant['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => 'gam_lottery_zip_ops',
                'version' => 'v2',
                'set_type' => 'charity',
                'zip' => $this->imageZipUpload([1 => 'png', 2 => 'jpg', 3 => 'webp']),
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_zip_ops',
                'Idempotency-Key' => 'tenant-zip-import',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $response = $this->withToken($central['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => 'gam_lottery_zip_ops',
                'version' => 'v2',
                'set_type' => 'charity',
                'zip' => $this->imageZipUpload([1 => 'png', 2 => 'jpg', 3 => 'webp']),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-zip-import',
            ])
            ->assertOk()
            ->assertJsonPath('meta.game_id', 'gam_lottery_zip_ops')
            ->assertJsonPath('meta.set_type', 'charity')
            ->assertJsonPath('meta.imported_count', 3)
            ->assertJsonPath('meta.expected_count', 3)
            ->assertJsonPath('data.0.position', 1)
            ->assertJsonPath('data.1.position', 2)
            ->assertJsonPath('data.2.position', 3)
            ->assertJsonPath('data.0.assets.source.content_type', 'image/png')
            ->assertJsonPath('data.1.assets.source.content_type', 'image/jpeg')
            ->assertJsonPath('data.2.assets.source.content_type', 'image/webp')
            ->assertJsonPath('data.0.assets.full.content_type', 'image/webp')
            ->assertJsonPath('data.0.assets.thumb.content_type', 'image/webp')
            ->json();

        $this->assertSame(3, DB::table('lottery_image_background_asset_sets')
            ->where('game_id', 'gam_lottery_zip_ops')
            ->where('version', 'v2')
            ->where('set_type', 'charity')
            ->where('status', 'ready')
            ->count());
        $this->assertSame(9, DB::table('platform_assets')
            ->where('purpose', 'ticket_image')
            ->where('storage_key', 'like', 'lottery-image-assets/games/gam_lottery_zip_ops/backgrounds/v2/charity/%')
            ->count());
        $this->assertTrue(Storage::disk('lottery_images')->exists($response['data'][0]['assets']['full']['storage_path']));
        $this->assertTrue(Storage::disk('lottery_images')->exists($response['data'][0]['assets']['thumb']['storage_path']));

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/lottery-images/readiness?game_id=gam_lottery_zip_ops&version=v2', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('backgrounds.2.set_type', 'charity')
            ->assertJsonPath('backgrounds.2.available_count', 3)
            ->assertJsonPath('backgrounds.2.ready', true);
    }

    public function test_LotteryImageZipImport_rejects_non_image_or_missing_sequence_zip(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_zip_invalid', 'open');
        $central = $this->createCentralSession(['asset.manage'], 'adm_lottery_zip_invalid', 'lottery-zip-invalid@example.test');

        $this->withToken($central['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => 'gam_lottery_zip_invalid',
                'version' => 'v1',
                'set_type' => 'odd',
                'zip' => $this->pngZipUpload([1, 3]),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'zip-wrong-count',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.zip.0', 'The zip file is missing 002 image file.');

        $this->withToken($central['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => 'gam_lottery_zip_invalid',
                'version' => 'v1',
                'set_type' => 'odd',
                'zip' => $this->mixedZipUpload(),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'zip-non-image',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->withToken($central['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => 'gam_lottery_zip_invalid',
                'version' => 'v1',
                'set_type' => 'odd',
                'zip' => $this->phpIniRejectedZipUpload(),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'zip-php-ini-limit',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.zip.0', fn (string $message): bool => str_contains($message, 'PHP upload limit'));
    }

    public function test_LotteryImagePreview_supports_manual_number_modes_and_creates_no_rows(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_preview_ops', 'ten_preview_ops');
        $this->insertGame('gam_lottery_preview_ops', 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.view'], 'adm_lottery_preview_ops', 'lottery-preview@example.test');
        $this->registerBackgroundSet($central['access_token'], 'gam_lottery_preview_ops', 'odd', 'preview-odd-assets');
        $this->insertPartnerBrandingAssetSet('par_preview_ops');
        $stockBefore = DB::table('stock_items')->count();
        $localBefore = DB::table('local_stock_items')->count();

        $unbranded = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/lottery-images/preview', [
                'game_id' => 'gam_lottery_preview_ops',
                'version' => 'v1',
                'set_type' => 'odd',
                'lottery_number' => '12345',
                'partner_id' => 'par_preview_ops',
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('mode', 'central_unbranded')
            ->assertJsonPath('requested_mode', 'central_unbranded')
            ->assertJsonPath('lottery_number', '012345')
            ->assertJsonPath('partner_id', 'par_preview_ops')
            ->assertJsonPath('side_effects.stock_rows_created', 0)
            ->json();

        $this->assertWebpBase64($unbranded['image_base64']);

        $branded = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/lottery-images/preview', [
                'game_id' => 'gam_lottery_preview_ops',
                'version' => 'v1',
                'set_type' => 'odd',
                'lottery_number' => '123456',
                'partner_id' => 'par_preview_ops',
                'mode' => 'partner_branded',
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('mode', 'partner_branded')
            ->assertJsonPath('warnings', [])
            ->json();

        $this->assertWebpBase64($branded['image_base64']);
        $this->assertSame($stockBefore, DB::table('stock_items')->count());
        $this->assertSame($localBefore, DB::table('local_stock_items')->count());
        $this->assertNull(DB::table('partner_lottery_branding_asset_sets')->where('partner_id', 'par_preview_ops')->value('locked_at'));
    }

    public function test_LotteryBrandingPreview_uses_route_partner_and_rejects_body_override(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_branding_preview', 'ten_branding_preview');
        $this->insertGame('gam_lottery_branding_preview', 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.view'], 'adm_brand_preview', 'lottery-branding-preview@example.test');
        $this->registerBackgroundSet($central['access_token'], 'gam_lottery_branding_preview', 'odd', 'branding-preview-odd-assets');
        $this->insertPartnerBrandingAssetSet('par_branding_preview');

        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/partners/par_branding_preview/lottery-branding/preview', [
                'game_id' => 'gam_lottery_branding_preview',
                'version' => 'v1',
                'set_type' => 'odd',
                'lottery_number' => '998877',
                'partner_id' => 'par_other',
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $preview = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/partners/par_branding_preview/lottery-branding/preview', [
                'game_id' => 'gam_lottery_branding_preview',
                'version' => 'v1',
                'set_type' => 'odd',
                'lottery_number' => '998877',
                'partner_id' => 'par_branding_preview',
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('mode', 'partner_branded')
            ->assertJsonPath('partner_id', 'par_branding_preview')
            ->assertJsonPath('side_effects.branding_locked', false)
            ->json();

        $this->assertWebpBase64($preview['image_base64']);
        $this->assertNull(DB::table('partner_lottery_branding_asset_sets')->where('partner_id', 'par_branding_preview')->value('locked_at'));
    }

    /**
     * @return array<string, array{asset_id: string}>
     */
    private function insertBackgroundAssets(string $gameId, string $setType): array
    {
        return [
            'source' => ['asset_id' => $this->insertImageAsset($gameId, $setType, 'source', 500, 280)],
            'full' => ['asset_id' => $this->insertImageAsset($gameId, $setType, 'full', 500, 280)],
            'thumb' => ['asset_id' => $this->insertImageAsset($gameId, $setType, 'thumb', 280, 157)],
        ];
    }

    private function registerBackgroundSet(string $token, string $gameId, string $setType, string $idempotencyKey): void
    {
        $this->withToken($token)
            ->putJson('/api/v1/admin/central/lottery-images/background-asset-sets', [
                'game_id' => $gameId,
                'version' => 'v1',
                'set_type' => $setType,
                'assets' => $this->insertBackgroundAssets($gameId, $setType),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => $idempotencyKey,
            ])
            ->assertOk();
    }

    private function insertImageAsset(string $gameId, string $setType, string $slot, int $width, int $height): string
    {
        $assetId = 'ast_'.substr(sha1($gameId.':'.$setType.':'.$slot.':'.$width.'x'.$height), 0, 20);
        $fileName = $setType.'-'.$slot.'.webp';
        $storageKey = 'central/assets/'.$assetId.'/'.$fileName;
        $bytes = $this->fixtureWebp($setType, $width, $height);

        Storage::disk('lottery_images')->put($storageKey, $bytes);

        DB::table('platform_assets')->insert([
            'id' => $assetId,
            'scope_type' => 'central',
            'tenant_id' => null,
            'created_by_admin_id' => null,
            'purpose' => 'ticket_image',
            'file_name' => $fileName,
            'content_type' => 'image/webp',
            'size_bytes' => strlen($bytes),
            'checksum_sha256' => hash('sha256', $bytes),
            'status' => 'committed',
            'storage_key' => $storageKey,
            'upload_url' => null,
            'public_url' => 'https://cdn.lottery.test/'.$storageKey,
            'metadata_json' => json_encode(['width' => $width, 'height' => $height], JSON_THROW_ON_ERROR),
            'expires_at' => null,
            'committed_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $assetId;
    }

    private function fixtureWebp(string $setType, int $width, int $height): string
    {
        $image = imagecreatetruecolor($width, $height);
        $colors = [
            'odd' => [190, 59, 98],
            'even' => [52, 133, 91],
            'charity' => [219, 148, 33],
        ];
        [$red, $green, $blue] = $colors[$setType] ?? [120, 120, 120];
        $background = imagecolorallocate($image, $red, $green, $blue);
        $accent = imagecolorallocate($image, min(255, $red + 30), min(255, $green + 30), min(255, $blue + 30));

        imagefilledrectangle($image, 0, 0, $width, $height, $background);
        imagefilledrectangle($image, 8, 8, $width - 8, $height - 8, $accent);

        ob_start();
        imagewebp($image, null, 80);
        $bytes = ob_get_clean();
        imagedestroy($image);

        $this->assertIsString($bytes);

        return $bytes;
    }

    private function insertImageStatusStock(string $stockId, string $gameId, string $number, string $setType, string $status, string $error): void
    {
        DB::table('stock_items')->insert([
            'id' => $stockId,
            'game_id' => $gameId,
            'batch_id' => null,
            'full_number' => $number,
            'front3' => substr($number, 0, 3),
            'back3' => substr($number, -3),
            'back2' => substr($number, -2),
            'status' => 'available',
            'partner_id' => null,
            'tenant_id' => null,
            'allocation_id' => null,
            'image_generation_status' => $status,
            'image_generation_error' => $error,
            'background_set_type' => $setType,
            'background_asset_version' => 'v1',
            'background_asset_index' => 1,
            'recall_reason' => null,
            'recalled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<int, int> $ordinals
     */
    private function pngZipUpload(array $ordinals): UploadedFile
    {
        return $this->imageZipUpload(array_fill_keys($ordinals, 'png'));
    }

    /**
     * @param array<int, string> $entries
     */
    private function imageZipUpload(array $entries): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'lottery-png-zip-');
        $this->assertIsString($path);

        $zip = new ZipArchive();
        $this->assertTrue($zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE));

        foreach ($entries as $ordinal => $extension) {
            $extension = strtolower($extension);
            $bytes = match ($extension) {
                'jpg', 'jpeg' => $this->fixtureJpeg((int) $ordinal),
                'webp' => $this->fixtureSourceWebp((int) $ordinal),
                default => $this->fixturePng((int) $ordinal),
            };

            $zip->addFromString(str_pad((string) $ordinal, 3, '0', STR_PAD_LEFT).'.'.$extension, $bytes);
        }

        $zip->close();

        return new UploadedFile($path, 'backgrounds.zip', 'application/zip', null, true);
    }

    private function mixedZipUpload(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'lottery-mixed-zip-');
        $this->assertIsString($path);

        $zip = new ZipArchive();
        $this->assertTrue($zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE));
        $zip->addFromString('001.txt', 'not an image');
        $zip->close();

        return new UploadedFile($path, 'mixed.zip', 'application/zip', null, true);
    }

    private function phpIniRejectedZipUpload(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'lottery-ini-limit-zip-');
        $this->assertIsString($path);
        file_put_contents($path, 'zip upload rejected by php.ini');

        return new UploadedFile($path, 'too-large.zip', 'application/zip', UPLOAD_ERR_INI_SIZE, true);
    }

    private function fixturePng(int $seed, int $width = 500, int $height = 280): string
    {
        $image = imagecreatetruecolor($width, $height);
        $background = imagecolorallocate($image, (70 + ($seed * 30)) % 255, (120 + ($seed * 20)) % 255, (170 + ($seed * 10)) % 255);
        $accent = imagecolorallocate($image, 255, 255, 255);

        imagefilledrectangle($image, 0, 0, $width, $height, $background);
        imagefilledellipse($image, (int) floor($width / 2), (int) floor($height / 2), 90, 90, $accent);

        ob_start();
        imagepng($image);
        $bytes = ob_get_clean();
        imagedestroy($image);

        $this->assertIsString($bytes);

        return $bytes;
    }

    private function fixtureJpeg(int $seed, int $width = 500, int $height = 280): string
    {
        $image = imagecreatetruecolor($width, $height);
        $background = imagecolorallocate($image, (90 + ($seed * 20)) % 255, (80 + ($seed * 25)) % 255, (130 + ($seed * 15)) % 255);
        $accent = imagecolorallocate($image, 255, 255, 255);

        imagefilledrectangle($image, 0, 0, $width, $height, $background);
        imagefilledellipse($image, (int) floor($width / 2), (int) floor($height / 2), 90, 90, $accent);

        ob_start();
        imagejpeg($image, null, 90);
        $bytes = ob_get_clean();
        imagedestroy($image);

        $this->assertIsString($bytes);

        return $bytes;
    }

    private function fixtureSourceWebp(int $seed, int $width = 500, int $height = 280): string
    {
        $image = imagecreatetruecolor($width, $height);
        $background = imagecolorallocate($image, (110 + ($seed * 15)) % 255, (95 + ($seed * 25)) % 255, (150 + ($seed * 20)) % 255);
        $accent = imagecolorallocate($image, 255, 255, 255);

        imagefilledrectangle($image, 0, 0, $width, $height, $background);
        imagefilledellipse($image, (int) floor($width / 2), (int) floor($height / 2), 90, 90, $accent);

        ob_start();
        imagewebp($image, null, 90);
        $bytes = ob_get_clean();
        imagedestroy($image);

        $this->assertIsString($bytes);

        return $bytes;
    }

    private function insertPartnerBrandingAssetSet(string $partnerId): void
    {
        $assetIds = [
            'logo_qr' => $this->insertBrandingImageAsset($partnerId, 'logo_qr', 80, 80),
            'right_sidebar' => $this->insertBrandingImageAsset($partnerId, 'right_sidebar', 80, 240),
            'logo_bottom' => $this->insertBrandingImageAsset($partnerId, 'logo_bottom', 160, 60),
        ];

        DB::table('partner_lottery_branding_asset_sets')->insert([
            'id' => 'pba_'.substr(sha1($partnerId.':preview'), 0, 20),
            'partner_id' => $partnerId,
            'version' => 'v1',
            'status' => 'ready',
            'logo_qr_asset_id' => $assetIds['logo_qr'],
            'right_sidebar_asset_id' => $assetIds['right_sidebar'],
            'logo_bottom_asset_id' => $assetIds['logo_bottom'],
            'logo_qr_storage_path' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/logo_qr.webp',
            'right_sidebar_storage_path' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/right_sidebar.webp',
            'logo_bottom_storage_path' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/logo_bottom.webp',
            'uploaded_by_admin_id' => null,
            'activated_at' => now(),
            'locked_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertBrandingImageAsset(string $partnerId, string $slot, int $width, int $height): string
    {
        $assetId = 'ast_'.substr(sha1($partnerId.':'.$slot), 0, 20);
        $storageKey = 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/'.$slot.'.webp';
        $bytes = $this->fixtureWebp('odd', $width, $height);

        Storage::disk('lottery_images')->put($storageKey, $bytes);
        DB::table('platform_assets')->insert([
            'id' => $assetId,
            'scope_type' => 'central',
            'tenant_id' => null,
            'created_by_admin_id' => null,
            'purpose' => 'ticket_image',
            'file_name' => $slot.'.webp',
            'content_type' => 'image/webp',
            'size_bytes' => strlen($bytes),
            'checksum_sha256' => hash('sha256', $bytes),
            'status' => 'committed',
            'storage_key' => $storageKey,
            'upload_url' => null,
            'public_url' => 'https://cdn.lottery.test/'.$storageKey,
            'metadata_json' => json_encode(['width' => $width, 'height' => $height], JSON_THROW_ON_ERROR),
            'expires_at' => null,
            'committed_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $assetId;
    }

    private function assertWebpBase64(string $base64): void
    {
        $bytes = base64_decode($base64, true);

        $this->assertIsString($bytes);
        $this->assertStringStartsWith('RIFF', $bytes);
        $this->assertSame('WEBP', substr($bytes, 8, 4));
    }
}

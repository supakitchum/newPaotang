<?php

namespace Tests\Feature;

use App\Jobs\GenerateLotteryImageJob;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Crypt;
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

    public function test_LotteryImageMix_persists_percentages_and_materialized_assignments_use_them(): void
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

        $this->insertImageReadyMaterializedStock('gam_lottery_mix_ops', 'sbg_lottery_mix_ops', 1000);

        $counts = DB::table('stock_items')
            ->where('game_id', 'gam_lottery_mix_ops')
            ->select('background_set_type', DB::raw('COUNT(*) as total'))
            ->groupBy('background_set_type')
            ->pluck('total', 'background_set_type')
            ->map(fn (mixed $value): int => (int) $value)
            ->all();

        $this->assertSame(['odd' => 1000], $counts);
        $this->assertSame(1000, DB::table('stock_items')->where('game_id', 'gam_lottery_mix_ops')->where('image_generation_status', 'pending')->count());
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

        $this->insertImageReadyMaterializedStock('gam_lottery_retry_ops', 'sbg_lottery_retry_ops', 1000);

        $this->assertSame(1000, DB::table('stock_items')->where('game_id', 'gam_lottery_retry_ops')->where('image_generation_status', 'pending_assets')->count());

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
            ->assertJsonPath('central.ready_count', 500)
            ->assertJsonPath('central.dispatched_count', 500);

        Queue::assertPushed(GenerateLotteryImageJob::class, 500);
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

        DB::table('platform_storage_connections')->updateOrInsert(
            ['id' => 'storage_aws_s3'],
            [
                'provider' => 'aws_s3',
                'status' => 'active',
                'bucket' => 'np-launch-lottery-private',
                'region' => 'ap-southeast-1',
                'endpoint' => 'https://r2.launch-lottery.example',
                'url' => 'https://cdn.launch-lottery.example',
                'root_prefix' => 'lottery-runtime',
                'visibility' => 'private',
                'use_path_style_endpoint' => true,
                'access_key_id_encrypted' => Crypt::encryptString('ACCESS_KEY_SHOULD_NOT_LEAK'),
                'secret_access_key_encrypted' => Crypt::encryptString('SECRET_KEY_SHOULD_NOT_LEAK'),
                'session_token_encrypted' => Crypt::encryptString('SESSION_TOKEN_SHOULD_NOT_LEAK'),
                'created_at' => now(),
                'updated_at' => now(),
            ],
        );
        DB::table('platform_storage_routes')->updateOrInsert(
            ['route_key' => 'lottery_images'],
            [
                'label' => 'Lottery images',
                'description' => 'Generated lottery ticket images and stock preview assets.',
                'driver' => 'aws_s3',
                'root_prefix' => '',
                'tenant_scoped' => true,
                'sort_order' => 10,
                'metadata_json' => json_encode(['path_hint' => 'lotteries/{game}/{batch}/partners/{partner}']),
                'created_at' => now(),
                'updated_at' => now(),
            ],
        );

        $body = $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/lottery-images/production-readiness', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('configured', true)
            ->assertJsonPath('disk', 'storage_connections:lottery_images')
            ->assertJsonPath('disk_driver', 's3')
            ->assertJsonPath('route_key', 'lottery_images')
            ->assertJsonPath('route_driver', 'aws_s3')
            ->assertJsonPath('connection_active', true)
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
            'app.env' => 'production',
            'lottery_images.object_prefix' => 'lotteries',
            'lottery_images.cdn_base_url' => 'https://cdn.launch-lottery.example/assets',
            'lottery_images.local_public_base_url' => '',
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
        $gameId = 'gam_01KRKJV10S2JSFVZE8Q998MN0J';
        $this->insertGame($gameId, 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.view'], 'adm_lottery_zip_ops', 'lottery-zip@example.test');
        $tenant = $this->createTenantSession('ten_zip_ops', 'par_zip_ops', ['asset.manage'], 'adm_lottery_zip_tenant', 'lottery-zip-tenant@example.test');
        $longAlphaName = 'alpha-'.str_repeat('very-long-background-name-', 10).'001.png';
        $longMiddleName = 'middle-'.str_repeat('very-long-background-name-', 10).'002.jpg';
        $longZetaName = 'zeta-'.str_repeat('very-long-background-name-', 10).'003.webp';
        $zipEntries = [
            $longZetaName => 'webp',
            $longAlphaName => 'png',
            $longMiddleName => 'jpg',
        ];

        $this->withToken($tenant['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => $gameId,
                'version' => 'v2',
                'set_type' => 'charity',
                'zip' => $this->namedImageZipUpload($zipEntries, includeMacArtifacts: true),
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_zip_ops',
                'Idempotency-Key' => 'tenant-zip-import',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $response = $this->withToken($central['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => $gameId,
                'version' => 'v2',
                'set_type' => 'charity',
                'zip' => $this->namedImageZipUpload($zipEntries),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-zip-import',
            ])
            ->assertOk()
            ->assertJsonPath('meta.game_id', $gameId)
            ->assertJsonPath('meta.set_type', 'charity')
            ->assertJsonPath('meta.storage_driver', 'local')
            ->assertJsonPath('meta.imported_count', 3)
            ->assertJsonPath('meta.expected_count', 3)
            ->assertJsonPath('data.0.position', 1)
            ->assertJsonPath('data.0.storage_driver', 'local')
            ->assertJsonPath('data.1.position', 2)
            ->assertJsonPath('data.2.position', 3)
            ->assertJsonPath('data.0.assets.source.content_type', 'image/png')
            ->assertJsonPath('data.0.assets.source.storage_driver', 'local')
            ->assertJsonPath('data.1.assets.source.content_type', 'image/jpeg')
            ->assertJsonPath('data.2.assets.source.content_type', 'image/webp')
            ->assertJsonPath('data.0.assets.source.storage_path', 'lottery-image-assets/games/'.$gameId.'/backgrounds/v2/charity/001/001.png')
            ->assertJsonPath('data.1.assets.source.storage_path', 'lottery-image-assets/games/'.$gameId.'/backgrounds/v2/charity/002/002.jpg')
            ->assertJsonPath('data.2.assets.source.storage_path', 'lottery-image-assets/games/'.$gameId.'/backgrounds/v2/charity/003/003.webp')
            ->assertJsonPath('data.0.assets.full.content_type', 'image/webp')
            ->assertJsonPath('data.0.assets.thumb.content_type', 'image/webp')
            ->json();

        $this->assertSame(3, DB::table('lottery_image_background_asset_sets')
            ->where('game_id', $gameId)
            ->where('version', 'v2')
            ->where('set_type', 'charity')
            ->where('status', 'ready')
            ->count());
        $this->assertSame(9, DB::table('platform_assets')
            ->where('purpose', 'ticket_image')
            ->where('storage_key', 'like', 'lottery-image-assets/games/'.$gameId.'/backgrounds/v2/charity/%')
            ->count());
        $this->assertSame(['001.png', '002.jpg', '003.webp'], DB::table('platform_assets')
            ->where('purpose', 'ticket_image')
            ->where('storage_key', 'like', 'lottery-image-assets/games/'.$gameId.'/backgrounds/v2/charity/%/%.%')
            ->whereNotIn('file_name', ['full.webp', 'thumb.webp'])
            ->orderBy('storage_key')
            ->pluck('file_name')
            ->all());
        $persistedZipMetadata = json_encode([
            DB::table('lottery_image_background_asset_sets')
                ->where('game_id', $gameId)
                ->where('version', 'v2')
                ->where('set_type', 'charity')
                ->pluck('metadata_json')
                ->all(),
            DB::table('platform_assets')
                ->where('purpose', 'ticket_image')
                ->where('storage_key', 'like', 'lottery-image-assets/games/'.$gameId.'/backgrounds/v2/charity/%')
                ->pluck('metadata_json')
                ->all(),
        ], JSON_THROW_ON_ERROR);
        $this->assertStringNotContainsString('very-long-background-name', $persistedZipMetadata);
        $this->assertStringContainsString('001.png', $persistedZipMetadata);
        $this->assertStringContainsString('storage_driver', $persistedZipMetadata);
        $this->assertStringContainsString('local', $persistedZipMetadata);
        $this->assertTrue(Storage::disk('lottery_images')->exists($response['data'][0]['assets']['full']['storage_path']));
        $this->assertTrue(Storage::disk('lottery_images')->exists($response['data'][0]['assets']['thumb']['storage_path']));

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/lottery-images/readiness?game_id='.$gameId.'&version=v2', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('backgrounds.2.set_type', 'charity')
            ->assertJsonPath('backgrounds.2.available_count', 3)
            ->assertJsonPath('backgrounds.2.ready', true);

        $this->insertGame('gam_lottery_zip_many', 'open');

        $this->withToken($central['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => 'gam_lottery_zip_many',
                'version' => 'v1',
                'set_type' => 'odd',
                'zip' => $this->namedImageZipUpload($this->namedImageEntries(101)),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-zip-import-many',
            ])
            ->assertOk()
            ->assertJsonPath('meta.imported_count', 101)
            ->assertJsonPath('meta.expected_count', 101)
            ->assertJsonPath('data.100.position', 101)
            ->assertJsonPath('data.100.assets.source.storage_path', 'lottery-image-assets/games/gam_lottery_zip_many/backgrounds/v1/odd/101/101.png');
    }

    public function test_LotteryImageZipImport_rejects_background_route_aws_when_connection_is_not_active(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_zip_no_s3', 'open');
        $central = $this->createCentralSession(['asset.manage'], 'adm_lottery_zip_no_s3', 'lottery-zip-no-s3@example.test');

        DB::table('platform_storage_routes')->updateOrInsert(
            ['route_key' => 'background_assets'],
            [
                'label' => 'Background asset sets',
                'description' => 'Source, full, and thumbnail background images imported for lottery image composition.',
                'driver' => 'aws_s3',
                'root_prefix' => '',
                'tenant_scoped' => false,
                'sort_order' => 20,
                'metadata_json' => json_encode(['path_hint' => 'lottery-image-assets/games/{game}/backgrounds/{version}/{set_type}'], JSON_THROW_ON_ERROR),
                'created_at' => now(),
                'updated_at' => now(),
            ],
        );
        DB::table('platform_storage_connections')->where('id', 'storage_aws_s3')->delete();

        $this->withToken($central['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => 'gam_lottery_zip_no_s3',
                'version' => 'v1',
                'set_type' => 'odd',
                'zip' => $this->namedImageZipUpload(['alpha.png' => 'png']),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-zip-import-no-s3',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.storage_route.0', 'Background asset storage is configured for AWS S3 but the storage connection is not active.');
    }

    public function test_LotteryImageZipImport_rejects_non_image_zip(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_zip_invalid', 'open');
        $central = $this->createCentralSession(['asset.manage'], 'adm_lottery_zip_invalid', 'lottery-zip-invalid@example.test');

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

    public function test_LotteryImageZipImport_preserves_full_background_frame_without_cover_crop(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_full_bg', 'open');
        $central = $this->createCentralSession(['asset.manage'], 'adm_lottery_full_bg', 'lottery-full-bg@example.test');

        $response = $this->withToken($central['access_token'])
            ->post('/api/v1/admin/central/lottery-images/background-asset-sets/import-zip', [
                'game_id' => 'gam_lottery_full_bg',
                'version' => 'v1',
                'set_type' => 'odd',
                'zip' => $this->edgeMarkerZipUpload(),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-full-bg-import',
            ])
            ->assertOk()
            ->json();

        $bytes = Storage::disk('lottery_images')->get($response['data'][0]['assets']['full']['storage_path']);
        $left = $this->pixelRgbFromBytes($bytes, 1, 140);
        $right = $this->pixelRgbFromBytes($bytes, 498, 140);

        $this->assertGreaterThan(180, $left[0]);
        $this->assertLessThan(100, $left[2]);
        $this->assertGreaterThan(180, $right[2]);
        $this->assertLessThan(100, $right[0]);
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

    public function test_LotteryImageLayout_persists_global_composition_and_preview_accepts_override(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_layout_ops', 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.view'], 'adm_lottery_layout_ops', 'lottery-layout@example.test');
        $this->registerBackgroundSet($central['access_token'], 'gam_lottery_layout_ops', 'odd', 'layout-odd-assets');

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/lottery-images/layout', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('scope', 'global')
            ->assertJsonPath('layout.logo_qr.x', 195)
            ->assertJsonPath('layout.logo_num_set.x', 80)
            ->assertJsonPath('layout.logo_num_set.width', 70)
            ->assertJsonPath('layout.emoji_1.y', 111)
            ->assertJsonPath('layout.thai_text.align', 'right')
            ->assertJsonPath('layout.thai_text.valign', 'top')
            ->assertJsonPath('layout.beside.width', 43);

        $saved = $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/lottery-images/layout', [
                'layout' => [
                    'logo_qr' => ['x' => 210, 'y' => 60, 'width' => 58, 'height' => null],
                    'logo_num_set' => ['x' => 82, 'y' => 156, 'width' => 72, 'height' => null],
                    'number_digits' => ['x' => 260, 'y' => 25, 'width' => 26, 'height' => 21, 'gap' => 31],
                    'thai_text' => ['align' => 'right', 'valign' => 'top'],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'layout-update',
            ])
            ->assertOk()
            ->assertJsonPath('layout.logo_qr.x', 210)
            ->assertJsonPath('layout.logo_num_set.width', 72)
            ->assertJsonPath('layout.logo_qr.height', null)
            ->assertJsonPath('layout.number_digits.gap', 31)
            ->assertJsonPath('layout.thai_text.align', 'right')
            ->assertJsonPath('layout.thai_text.valign', 'top')
            ->json();

        $this->assertSame(1, DB::table('platform_system_settings')->where('key', LotteryImageGenerator::LAYOUT_SETTING_KEY)->count());
        $this->assertSame(210, $saved['layout']['logo_qr']['x']);

        $preview = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/lottery-images/preview', [
                'game_id' => 'gam_lottery_layout_ops',
                'version' => 'v1',
                'set_type' => 'odd',
                'lottery_number' => '456789',
                'layout' => [
                    'logo_qr' => ['x' => 230, 'y' => 64, 'width' => 61, 'height' => null],
                    'logo_num_set' => ['x' => 84, 'y' => 158, 'width' => 74, 'height' => null],
                ],
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('layout.logo_qr.x', 230)
            ->assertJsonPath('layout.logo_num_set.x', 84)
            ->assertJsonPath('layout.number_digits.gap', 31)
            ->json();

        $this->assertWebpBase64($preview['image_base64']);
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

    public function test_LotteryBrandingPreview_renders_assets_uploaded_through_local_dev_asset_flow(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_branding_local_upload', 'ten_branding_local_upload');
        $this->insertGame('gam_brand_local_upload', 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.view'], 'adm_brand_local_upload', 'lottery-branding-local-upload@example.test');
        $this->registerBackgroundSet($central['access_token'], 'gam_brand_local_upload', 'odd', 'branding-local-upload-odd-assets');

        $assetIds = [
            'logo_qr' => $this->uploadBrandingImageAsset($central['access_token'], 'par_branding_local_upload', 'logo_qr', 80, 80),
            'right_sidebar' => $this->uploadBrandingImageAsset($central['access_token'], 'par_branding_local_upload', 'right_sidebar', 80, 240),
            'logo_bottom' => $this->uploadBrandingImageAsset($central['access_token'], 'par_branding_local_upload', 'logo_bottom', 160, 60),
        ];

        $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/partners/par_branding_local_upload/lottery-branding-assets', [
                'version' => 'v1',
                'assets' => [
                    'logo_qr' => ['asset_id' => $assetIds['logo_qr']],
                    'right_sidebar' => ['asset_id' => $assetIds['right_sidebar']],
                    'logo_bottom' => ['asset_id' => $assetIds['logo_bottom']],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'branding-local-upload-save',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'ready');

        $partnerPreview = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/partners/par_branding_local_upload/lottery-branding/preview', [
                'game_id' => 'gam_brand_local_upload',
                'version' => 'v1',
                'set_type' => 'odd',
                'lottery_number' => '112233',
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('mode', 'partner_branded')
            ->assertJsonPath('warnings', [])
            ->json();

        $centralPreview = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/lottery-images/preview', [
                'game_id' => 'gam_brand_local_upload',
                'version' => 'v1',
                'set_type' => 'odd',
                'lottery_number' => '112233',
                'mode' => 'central_unbranded',
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->json();

        $this->assertWebpBase64($partnerPreview['image_base64']);
        $this->assertNotSame($centralPreview['image_base64'], $partnerPreview['image_base64']);
    }

    public function test_LotteryImagePreview_loads_partner_branding_from_partner_asset_route(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_preview_brand_route', 'ten_preview_brand_route');
        $this->insertGame('gam_preview_brand_route', 'open');
        $central = $this->createCentralSession(['asset.manage', 'stock.view'], 'adm_preview_brand_route', 'preview-brand-route@example.test');
        $this->registerBackgroundSet($central['access_token'], 'gam_preview_brand_route', 'odd', 'preview-brand-route-bg');
        $this->insertPartnerBrandingAssetSet('par_preview_brand_route');

        $storage = new class($this->fixtureWebp('odd', 500, 280), $this->fixtureWebp('charity', 180, 180)) extends RuntimeStorageService {
            /** @var array<int, array{method: string, route: string, key: string}> */
            public array $calls = [];

            public function __construct(private readonly string $backgroundBytes, private readonly string $brandingBytes)
            {
            }

            public function existsUsingDriver(string $routeKey, string $key, ?string $driver = null): bool
            {
                $this->calls[] = ['method' => 'exists', 'route' => $routeKey, 'key' => $key];

                return $this->bytesFor($routeKey, $key) !== null;
            }

            public function getUsingDriver(string $routeKey, string $key, ?string $driver = null): ?string
            {
                $this->calls[] = ['method' => 'get', 'route' => $routeKey, 'key' => $key];

                return $this->bytesFor($routeKey, $key);
            }

            public function driverForRoute(string $routeKey): string
            {
                return self::DRIVER_LOCAL;
            }

            private function bytesFor(string $routeKey, string $key): ?string
            {
                if (
                    in_array($routeKey, [self::ROUTE_BACKGROUND_ASSETS, self::ROUTE_CENTRAL_ASSETS], true)
                    && (str_contains($key, 'lottery-image-assets/') || str_starts_with($key, 'central/assets/'))
                ) {
                    return $this->backgroundBytes;
                }

                if ($routeKey === self::ROUTE_PARTNER_ASSETS && str_contains($key, 'partners/par_preview_brand_route/lottery-branding/')) {
                    return $this->brandingBytes;
                }

                return null;
            }
        };
        $this->app->instance(RuntimeStorageService::class, $storage);
        $this->app->instance(LotteryImageGenerator::class, new LotteryImageGenerator($storage));
        $this->app->forgetInstance(\App\Modules\CentralStock\Services\LotteryImageOperationsService::class);

        $partnerPreview = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/lottery-images/preview', [
                'game_id' => 'gam_preview_brand_route',
                'version' => 'v1',
                'set_type' => 'odd',
                'lottery_number' => '445566',
                'partner_id' => 'par_preview_brand_route',
                'mode' => 'partner_branded',
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('mode', 'partner_branded')
            ->assertJsonPath('warnings', [])
            ->json();

        $centralPreview = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/lottery-images/preview', [
                'game_id' => 'gam_preview_brand_route',
                'version' => 'v1',
                'set_type' => 'odd',
                'lottery_number' => '445566',
                'mode' => 'central_unbranded',
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->json();

        $routes = array_column($storage->calls, 'route');

        $this->assertContains(RuntimeStorageService::ROUTE_BACKGROUND_ASSETS, $routes);
        $this->assertContains(RuntimeStorageService::ROUTE_PARTNER_ASSETS, $routes);
        $this->assertWebpBase64($partnerPreview['image_base64']);
        $this->assertNotSame($centralPreview['image_base64'], $partnerPreview['image_base64']);
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

    private function uploadBrandingImageAsset(string $token, string $partnerId, string $slot, int $width, int $height): string
    {
        $bytes = $this->fixtureWebp('odd', $width, $height);
        $fileName = 'user-upload-'.$slot.'.webp';
        $canonicalFileName = $slot === 'right_sidebar' ? 'rightsidebar.webp' : $slot.'.webp';
        $canonicalStorageKey = 'partners/'.$partnerId.'/lottery-branding/v1/'.$canonicalFileName;

        $intent = $this->withToken($token)
            ->postJson('/api/v1/admin/central/assets/uploads', [
                'purpose' => 'partner_lottery_branding',
                'file_name' => $fileName,
                'content_type' => 'image/webp',
                'size_bytes' => strlen($bytes),
                'checksum_sha256' => hash('sha256', $bytes),
                'metadata' => [
                    'partner_id' => $partnerId,
                    'branding_slot' => $slot,
                    'version' => 'v1',
                    'width' => $width,
                    'height' => $height,
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'branding-local-upload-intent-'.$slot,
            ])
            ->assertCreated()
            ->assertJsonPath('storage_mode', 'local_dev_metadata_only')
            ->json();

        $uploaded = $this->withToken($token)
            ->post('/api/v1/admin/central/assets/'.$intent['asset_id'].'/local-upload', [
                'file' => $this->uploadedFileFromBytes($bytes, $fileName, 'image/webp'),
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('metadata.storage_boundary', 'local_dev_uploaded')
            ->assertJsonPath('storage_key', $canonicalStorageKey)
            ->assertJsonPath('file_name', $canonicalFileName)
            ->assertJsonPath('content_type', 'image/webp')
            ->json();

        $this->assertTrue(Storage::disk('lottery_images')->exists($uploaded['storage_key']));

        $this->withToken($token)
            ->postJson('/api/v1/admin/central/assets/'.$intent['asset_id'].'/commit', [
                'checksum_sha256' => hash('sha256', $bytes),
                'metadata' => [
                    'partner_id' => $partnerId,
                    'branding_slot' => $slot,
                    'version' => 'v1',
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'branding-local-upload-commit-'.$slot,
            ])
            ->assertOk()
            ->assertJsonPath('status', 'committed')
            ->assertJsonPath('purpose', 'partner_lottery_branding')
            ->assertJsonPath('storage_key', $canonicalStorageKey)
            ->assertJsonPath('file_name', $canonicalFileName);

        return (string) $intent['asset_id'];
    }

    private function uploadedFileFromBytes(string $bytes, string $fileName, string $mimeType): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'local-upload-');
        $this->assertIsString($path);
        file_put_contents($path, $bytes);

        return new UploadedFile($path, $fileName, $mimeType, null, true);
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

    private function insertImageReadyMaterializedStock(string $gameId, string $batchId, int $count): void
    {
        $now = now();
        $stockIds = [];

        DB::table('stock_generation_batches')->insert([
            'id' => $batchId,
            'game_id' => $gameId,
            'type' => 'import',
            'status' => 'completed',
            'requested_count' => $count,
            'generated_count' => $count,
            'total_rounds' => 0,
            'processed_rounds' => 0,
            'chunk_rounds' => 0,
            'range_start' => '000000',
            'range_end' => '999999',
            'number_digits' => 6,
            'idempotency_key' => $batchId,
            'payload_hash' => hash('sha256', $batchId),
            'created_by_admin_id' => null,
            'payload_json' => json_encode(['fixture' => 'legacy-materialized-image-stock'], JSON_THROW_ON_ERROR),
            'started_at' => $now,
            'completed_at' => $now,
            'failed_at' => null,
            'failure_reason' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        for ($number = 0; $number < $count; $number++) {
            $fullNumber = str_pad((string) $number, 6, '0', STR_PAD_LEFT);
            $stockIds[] = 'stk_'.substr(sha1($gameId.':'.$batchId.':'.$fullNumber), 0, 20);
        }

        $assignments = app(LotteryImageGenerator::class)->assignmentsForStockIds($gameId, $batchId, $stockIds);
        $rows = [];

        foreach ($stockIds as $index => $stockId) {
            $fullNumber = str_pad((string) $index, 6, '0', STR_PAD_LEFT);
            $assignment = $assignments[$stockId];

            $rows[] = [
                'id' => $stockId,
                'game_id' => $gameId,
                'batch_id' => $batchId,
                'full_number' => $fullNumber,
                'front3' => substr($fullNumber, 0, 3),
                'back3' => substr($fullNumber, -3),
                'back2' => substr($fullNumber, -2),
                'status' => 'available',
                'partner_id' => null,
                'tenant_id' => null,
                'allocation_id' => null,
                'image_generation_status' => $assignment['image_generation_status'],
                'image_generation_error' => $assignment['image_generation_error'],
                'background_set_type' => $assignment['background_set_type'],
                'background_asset_version' => $assignment['background_asset_version'],
                'background_asset_index' => $assignment['background_asset_index'],
                'recall_reason' => null,
                'recalled_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        foreach (array_chunk($rows, 500) as $chunk) {
            DB::table('stock_items')->insert($chunk);
        }
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
    private function imageZipUpload(array $entries, bool $includeMacArtifacts = false): UploadedFile
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

        if ($includeMacArtifacts) {
            $zip->addFromString('__MACOSX/._001.png', 'macos resource fork');
            $zip->addFromString('._002.jpg', 'macos root resource fork');
            $zip->addFromString('.DS_Store', 'macos finder metadata');
        }

        $zip->close();

        return new UploadedFile($path, 'backgrounds.zip', 'application/zip', null, true);
    }

    /**
     * @param array<string, string> $entries
     */
    private function namedImageZipUpload(array $entries, bool $includeMacArtifacts = false): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'lottery-named-image-zip-');
        $this->assertIsString($path);

        $zip = new ZipArchive();
        $this->assertTrue($zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE));

        $seed = 1;

        foreach ($entries as $name => $extension) {
            $extension = strtolower($extension);
            $bytes = match ($extension) {
                'jpg', 'jpeg' => $this->fixtureJpeg($seed),
                'webp' => $this->fixtureSourceWebp($seed),
                default => $this->fixturePng($seed),
            };

            $zip->addFromString($name, $bytes);
            $seed++;
        }

        if ($includeMacArtifacts) {
            $zip->addFromString('__MACOSX/._alpha background.png', 'macos resource fork');
            $zip->addFromString('._middle background.jpg', 'macos root resource fork');
            $zip->addFromString('.DS_Store', 'macos finder metadata');
        }

        $zip->close();

        return new UploadedFile($path, 'named-backgrounds.zip', 'application/zip', null, true);
    }

    /**
     * @return array<string, string>
     */
    private function namedImageEntries(int $count): array
    {
        $entries = [];

        for ($index = 1; $index <= $count; $index++) {
            $entries[sprintf('background-%03d.png', $index)] = 'png';
        }

        return $entries;
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

    private function edgeMarkerZipUpload(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'lottery-edge-marker-zip-');
        $this->assertIsString($path);

        $zip = new ZipArchive();
        $this->assertTrue($zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE));
        $zip->addFromString('edge.png', $this->edgeMarkerPng());
        $zip->close();

        return new UploadedFile($path, 'edge-marker.zip', 'application/zip', null, true);
    }

    private function edgeMarkerPng(): string
    {
        $image = imagecreatetruecolor(700, 280);
        $middle = imagecolorallocate($image, 240, 240, 240);
        $left = imagecolorallocate($image, 240, 20, 20);
        $right = imagecolorallocate($image, 20, 30, 240);

        imagefilledrectangle($image, 0, 0, 699, 279, $middle);
        imagefilledrectangle($image, 0, 0, 79, 279, $left);
        imagefilledrectangle($image, 620, 0, 699, 279, $right);

        ob_start();
        imagepng($image);
        $bytes = ob_get_clean();
        imagedestroy($image);

        $this->assertIsString($bytes);

        return $bytes;
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

    private function insertBrandingImageAsset(string $partnerId, string $slot, int $width, int $height): string
    {
        $assetId = 'ast_'.substr(sha1($partnerId.':'.$slot), 0, 20);
        $fileName = $slot === 'right_sidebar' ? 'rightsidebar.webp' : $slot.'.webp';
        $storageKey = 'partners/'.$partnerId.'/lottery-branding/v1/'.$fileName;
        $bytes = $this->fixtureWebp('odd', $width, $height);

        Storage::disk('lottery_images')->put($storageKey, $bytes);
        DB::table('platform_assets')->insert([
            'id' => $assetId,
            'scope_type' => 'central',
            'tenant_id' => null,
            'created_by_admin_id' => null,
            'purpose' => 'partner_lottery_branding',
            'file_name' => $fileName,
            'content_type' => 'image/webp',
            'size_bytes' => strlen($bytes),
            'checksum_sha256' => hash('sha256', $bytes),
            'status' => 'committed',
            'storage_key' => $storageKey,
            'upload_url' => null,
            'public_url' => 'https://cdn.lottery.test/'.$storageKey,
            'metadata_json' => json_encode(['width' => $width, 'height' => $height, 'partner_id' => $partnerId, 'branding_slot' => $slot, 'version' => 'v1'], JSON_THROW_ON_ERROR),
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

    /**
     * @return array{0: int, 1: int, 2: int}
     */
    private function pixelRgbFromBytes(string $bytes, int $x, int $y): array
    {
        $image = imagecreatefromstring($bytes);
        $this->assertNotFalse($image);

        if ($image === false) {
            return [0, 0, 0];
        }

        $rgb = imagecolorat($image, $x, $y);
        imagedestroy($image);

        return [
            ($rgb >> 16) & 0xFF,
            ($rgb >> 8) & 0xFF,
            $rgb & 0xFF,
        ];
    }
}

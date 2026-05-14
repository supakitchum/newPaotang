<?php

namespace Tests\Feature;

use App\Jobs\GenerateLotteryImageJob;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

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
}

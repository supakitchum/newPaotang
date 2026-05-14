<?php

namespace Tests\Feature;

use App\Jobs\GenerateLotteryImageJob;
use App\Jobs\GeneratePartnerLotteryImageJob;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class LotteryImageTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    private string $assetRoot;
    private string $storageRoot;

    protected function setUp(): void
    {
        parent::setUp();

        $suffix = Str::lower(Str::random(8));
        $this->assetRoot = storage_path('framework/testing/lottery-assets/'.$suffix);
        $this->storageRoot = storage_path('framework/testing/lottery-output/'.$suffix);

        config([
            'lottery_images.asset_root' => $this->assetRoot,
            'lottery_images.cdn_base_url' => 'https://cdn.lottery.test',
            'filesystems.disks.lottery_images.root' => $this->storageRoot,
        ]);
        Storage::forgetDisk('lottery_images');
    }

    public function test_LotteryImageGeneration_assigns_background_mix_and_generates_central_webp_objects(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_mix', 'open');
        $this->putAllBackgroundSets('gam_lottery_mix');
        $central = $this->createCentralSession(['stock.generate'], 'adm_lottery_mix', 'lottery-mix@example.test');

        $batch = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_lottery_mix',
                'start_number' => 100000,
                'count' => 20,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'lottery-image-mix',
            ])
            ->assertAccepted()
            ->assertJsonPath('generated_count', 20)
            ->json();

        $rows = DB::table('stock_items')
            ->where('game_id', 'gam_lottery_mix')
            ->orderBy('full_number')
            ->get();

        foreach ($rows as $row) {
            (new GenerateLotteryImageJob((string) $row->id))->handle(app(LotteryImageGenerator::class));
        }

        $rows = DB::table('stock_items')
            ->where('game_id', 'gam_lottery_mix')
            ->orderBy('full_number')
            ->get();

        $counts = $rows->groupBy('background_set_type')->map->count()->all();
        ksort($counts);

        $this->assertSame(['charity' => 2, 'even' => 9, 'odd' => 9], $counts);
        $this->assertSame(20, $rows->where('image_generation_status', 'generated')->count());

        $previous = null;
        foreach ($rows as $row) {
            $this->assertNotSame($previous, $row->background_set_type);
            $this->assertStringStartsWith('lotteries/gam_lottery_mix/'.$batch['id'].'/central/', $row->image_storage_path);
            $this->assertStringStartsWith('https://cdn.lottery.test/lotteries/gam_lottery_mix/'.$batch['id'].'/central/', $row->image_url);
            $previous = $row->background_set_type;
        }

        $first = $rows->first();
        $bytes = Storage::disk('lottery_images')->get((string) $first->image_storage_path);
        $thumbBytes = Storage::disk('lottery_images')->get((string) $first->image_thumb_storage_path);

        $this->assertWebpDimensions($bytes, 500, 280);
        $this->assertWebpDimensions($thumbBytes, 280, 157);
        $this->assertStringNotContainsString('metadata_webp_container_placeholder', $bytes);
        $this->assertStringNotContainsString('"scope":"central"', $bytes);
        $this->assertStringNotContainsString('logo_qr_storage_path', $bytes);
    }

    public function test_LotteryImagePendingBackgroundCommand_generates_rows_once_their_set_is_ready(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_lottery_pending', 'open');
        $this->putBackground('gam_lottery_pending', 'odd');
        $central = $this->createCentralSession(['stock.generate'], 'adm_lottery_pending', 'lottery-pending@example.test');

        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_lottery_pending',
                'start_number' => 200000,
                'count' => 4,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'lottery-image-pending',
            ])
            ->assertAccepted();

        $pending = DB::table('stock_items')
            ->where('game_id', 'gam_lottery_pending')
            ->where('background_set_type', 'even')
            ->where('image_generation_status', 'pending_assets')
            ->orderBy('id')
            ->first();

        $this->assertNotNull($pending);

        $this->putBackground('gam_lottery_pending', 'even');
        Queue::fake();

        $this->artisan('lottery-images:check-pending-backgrounds', ['--limit' => 10])
            ->expectsOutput('Pending central ready: 2')
            ->assertExitCode(0);

        Queue::assertPushed(GenerateLotteryImageJob::class, 2);

        (new GenerateLotteryImageJob((string) $pending->id))->handle(app(LotteryImageGenerator::class));

        $updated = DB::table('stock_items')->where('id', $pending->id)->first();

        $this->assertSame('generated', $updated->image_generation_status);
        $this->assertNull($updated->image_generation_error);
        $this->assertTrue(Storage::disk('lottery_images')->exists((string) $updated->image_storage_path));
    }

    public function test_LotteryImageVisual_generation_creates_partner_variant_after_stock_sync_and_exposes_it_publicly(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_lottery_partner', 'ten_lottery_partner', 'lottery-image.newpaotang.test');
        $this->insertGame('gam_lottery_partner', 'open');
        $this->insertQuota('pqt_lottery_partner', 'par_lottery_partner', 'gam_lottery_partner', 5);
        $this->putAllBackgroundSets('gam_lottery_partner');
        $this->insertBrandingAssetSet('par_lottery_partner');

        $central = $this->createCentralSession(
            ['stock.generate', 'stock.allocate'],
            'adm_lottery_partner',
            'lottery-partner@example.test',
        );

        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_lottery_partner',
                'start_number' => 300000,
                'count' => 1,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'lottery-image-partner-generate',
            ])
            ->assertAccepted();

        $stock = DB::table('stock_items')
            ->where('game_id', 'gam_lottery_partner')
            ->first();

        (new GenerateLotteryImageJob((string) $stock->id))->handle(app(LotteryImageGenerator::class));

        $stock = DB::table('stock_items')
            ->where('game_id', 'gam_lottery_partner')
            ->first();

        $centralBytes = Storage::disk('lottery_images')->get((string) $stock->image_storage_path);
        $centralThumbBytes = Storage::disk('lottery_images')->get((string) $stock->image_thumb_storage_path);

        $this->assertWebpDimensions($centralBytes, 500, 280);
        $this->assertWebpDimensions($centralThumbBytes, 280, 157);
        $this->assertStringNotContainsString('logo_qr_storage_path', $centralBytes);

        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_lottery_partner',
                'tenant_id' => 'ten_lottery_partner',
                'game_id' => 'gam_lottery_partner',
                'requested_count' => 1,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'lottery-image-partner-allocation',
            ])
            ->assertAccepted();

        $tenant = $this->createTenantSession(
            'ten_lottery_partner',
            'par_lottery_partner',
            ['stock.sync'],
            'adm_lottery_sync',
            'lottery-sync@example.test',
        );

        $this->withToken($tenant['access_token'])
            ->postJson('/api/v1/admin/tenant/stock-sync/batches', [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_lottery_partner',
                'Idempotency-Key' => 'lottery-image-partner-sync',
            ])
            ->assertAccepted()
            ->assertJsonPath('processed_count', 1);

        $localStock = DB::table('local_stock_items')
            ->where('tenant_id', 'ten_lottery_partner')
            ->where('game_id', 'gam_lottery_partner')
            ->first();

        (new GeneratePartnerLotteryImageJob((string) $localStock->id))->handle(app(LotteryImageGenerator::class));

        $localStock = DB::table('local_stock_items')
            ->where('tenant_id', 'ten_lottery_partner')
            ->where('game_id', 'gam_lottery_partner')
            ->first();

        $this->assertSame('generated', $localStock->image_generation_status);
        $this->assertStringContainsString('/partners/par_lottery_partner/', $localStock->image_url);
        $this->assertStringContainsString('/partners/par_lottery_partner/thumbs/', $localStock->image_thumb_url);

        $bytes = Storage::disk('lottery_images')->get((string) $localStock->image_storage_path);
        $thumbBytes = Storage::disk('lottery_images')->get((string) $localStock->image_thumb_storage_path);

        $this->assertWebpDimensions($bytes, 500, 280);
        $this->assertWebpDimensions($thumbBytes, 280, 157);
        $this->assertStringNotContainsString('metadata_webp_container_placeholder', $bytes);
        $this->assertStringNotContainsString('"scope":"partner"', $bytes);
        $this->assertGreaterThan(40, $this->colorDistance(
            $this->pixelRgb($centralBytes, 474, 140),
            $this->pixelRgb($bytes, 474, 140),
        ));
        $this->assertGreaterThan(40, $this->colorDistance(
            $this->pixelRgb($centralBytes, 318, 230),
            $this->pixelRgb($bytes, 318, 230),
        ));

        $this->getJson('http://lottery-image.newpaotang.test/api/v1/public/stock/search?game_id=gam_lottery_partner&number=300000')
            ->assertOk()
            ->assertJsonPath('data.0.image_url', $localStock->image_url)
            ->assertJsonPath('data.0.image_thumb_url', $localStock->image_thumb_url);
    }

    private function putAllBackgroundSets(string $gameId): void
    {
        foreach (['odd', 'even', 'charity'] as $setType) {
            $this->putBackground($gameId, $setType);
        }
    }

    private function putBackground(string $gameId, string $setType, int $index = 1): void
    {
        $directory = $this->assetRoot.'/games/'.$gameId.'/backgrounds/v1/'.$setType;

        if (! is_dir($directory)) {
            mkdir($directory, 0777, true);
        }

        file_put_contents($directory.'/'.str_pad((string) $index, 3, '0', STR_PAD_LEFT).'.webp', $this->fixtureWebp($setType));
    }

    private function insertBrandingAssetSet(string $partnerId): void
    {
        $now = now();
        $assets = [
            'logo_qr' => 'logo-qr.webp',
            'right_sidebar' => 'right-sidebar.webp',
            'logo_bottom' => 'logo-bottom.webp',
        ];
        $assetIds = [];

        foreach ($assets as $slot => $fileName) {
            $assetId = 'ast_'.substr(sha1($partnerId.':'.$slot), 0, 20);
            $assetIds[$slot] = $assetId;

            DB::table('platform_assets')->insert([
                'id' => $assetId,
                'scope_type' => 'central',
                'tenant_id' => null,
                'created_by_admin_id' => null,
                'purpose' => 'ticket_image',
                'file_name' => $fileName,
                'content_type' => 'image/webp',
                'size_bytes' => 128,
                'checksum_sha256' => hash('sha256', $assetId),
                'status' => 'committed',
                'storage_key' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/'.$fileName,
                'upload_url' => null,
                'public_url' => 'https://cdn.lottery.test/'.$fileName,
                'metadata_json' => json_encode(['fixture' => true], JSON_THROW_ON_ERROR),
                'expires_at' => null,
                'committed_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        DB::table('partner_lottery_branding_asset_sets')->insert([
            'id' => 'plas_'.substr(sha1($partnerId), 0, 20),
            'partner_id' => $partnerId,
            'version' => 'v1',
            'status' => 'ready',
            'logo_qr_asset_id' => $assetIds['logo_qr'],
            'right_sidebar_asset_id' => $assetIds['right_sidebar'],
            'logo_bottom_asset_id' => $assetIds['logo_bottom'],
            'logo_qr_storage_path' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/logo-qr.webp',
            'right_sidebar_storage_path' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/right-sidebar.webp',
            'logo_bottom_storage_path' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/logo-bottom.webp',
            'uploaded_by_admin_id' => null,
            'activated_at' => $now,
            'locked_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private function assertWebpDimensions(string $bytes, int $width, int $height): void
    {
        $this->assertStringStartsWith('RIFF', $bytes);
        $this->assertSame('WEBP', substr($bytes, 8, 4));

        $info = getimagesizefromstring($bytes);

        $this->assertIsArray($info);
        $this->assertSame($width, $info[0]);
        $this->assertSame($height, $info[1]);
        $this->assertSame('image/webp', $info['mime'] ?? null);

        $image = imagecreatefromstring($bytes);

        $this->assertNotFalse($image);

        if ($image !== false) {
            imagedestroy($image);
        }
    }

    /**
     * @return array{0: int, 1: int, 2: int}
     */
    private function pixelRgb(string $bytes, int $x, int $y): array
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

    /**
     * @param array{0: int, 1: int, 2: int} $left
     * @param array{0: int, 1: int, 2: int} $right
     */
    private function colorDistance(array $left, array $right): int
    {
        return abs($left[0] - $right[0]) + abs($left[1] - $right[1]) + abs($left[2] - $right[2]);
    }

    private function fixtureWebp(string $setType): string
    {
        $image = imagecreatetruecolor(640, 360);
        $base = match ($setType) {
            'even' => [72, 142, 112],
            'charity' => [218, 158, 67],
            default => [185, 96, 132],
        };
        $background = imagecolorallocate($image, $base[0], $base[1], $base[2]);
        $line = imagecolorallocatealpha($image, 255, 255, 255, 58);
        $dark = imagecolorallocatealpha($image, 35, 35, 45, 76);

        imagefilledrectangle($image, 0, 0, 639, 359, $background);

        for ($x = -360; $x < 700; $x += 42) {
            imageline($image, $x, 0, $x + 360, 360, $line);
        }

        imagefilledrectangle($image, 0, 270, 639, 359, $dark);

        ob_start();
        imagewebp($image, null, 82);
        $bytes = ob_get_clean();
        imagedestroy($image);

        return is_string($bytes) ? $bytes : '';
    }
}

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

        $batchId = 'sbg_lottery_image_mix';
        $this->insertImageReadyMaterializedStock('gam_lottery_mix', $batchId, 1000);

        $rows = DB::table('stock_items')
            ->where('game_id', 'gam_lottery_mix')
            ->orderBy('full_number')
            ->get();

        $first = $rows->first();

        (new GenerateLotteryImageJob((string) $first->id))->handle(app(LotteryImageGenerator::class));

        $generated = DB::table('stock_items')->where('id', $first->id)->first();

        $counts = $rows->groupBy('background_set_type')->map->count()->all();
        ksort($counts);

        $this->assertSame(['charity' => 100, 'even' => 450, 'odd' => 450], $counts);
        $this->assertSame('generated', $generated->image_generation_status);
        $this->assertStringStartsWith('lotteries/gam_lottery_mix/'.$batchId.'/central/', $generated->image_storage_path);
        $this->assertStringStartsWith('https://cdn.lottery.test/lotteries/gam_lottery_mix/'.$batchId.'/central/', $generated->image_url);

        $bytes = Storage::disk('lottery_images')->get((string) $generated->image_storage_path);
        $thumbBytes = Storage::disk('lottery_images')->get((string) $generated->image_thumb_storage_path);

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

        $this->insertImageReadyMaterializedStock('gam_lottery_pending', 'sbg_lottery_image_pending', 1000);

        $pending = DB::table('stock_items')
            ->where('game_id', 'gam_lottery_pending')
            ->where('background_set_type', 'even')
            ->where('image_generation_status', 'pending_assets')
            ->orderBy('id')
            ->first();

        $this->assertNotNull($pending);

        $this->putBackground('gam_lottery_pending', 'even');
        Queue::fake();

        $this->artisan('lottery-images:check-pending-backgrounds', ['--limit' => 10, '--set_type' => 'even'])
            ->expectsOutput('Pending central ready: 10')
            ->assertExitCode(0);

        Queue::assertPushed(GenerateLotteryImageJob::class, 10);

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
        $this->putAllBackgroundSets('gam_lottery_partner');
        $this->insertBrandingAssetSet('par_lottery_partner');

        $stockIds = $this->insertImageReadyMaterializedStock('gam_lottery_partner', 'sbg_lottery_image_partner', 1);

        $stock = DB::table('stock_items')
            ->where('id', $stockIds[0])
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

        $localStockId = $this->insertLegacyMaterializedLocalStock(
            'par_lottery_partner',
            'ten_lottery_partner',
            'gam_lottery_partner',
            (string) $stock->id,
        );

        $localStock = DB::table('local_stock_items')
            ->where('id', $localStockId)
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
            $this->pixelRgb($centralBytes, 318, 110),
            $this->pixelRgb($bytes, 318, 110),
        ));
        $this->assertGreaterThan(40, $this->colorDistance(
            $this->pixelRgb($centralBytes, 100, 175),
            $this->pixelRgb($bytes, 100, 175),
        ));

        $this->getJson('http://lottery-image.newpaotang.test/api/v1/public/stock/search?game_id=gam_lottery_partner&number='.$localStock->full_number)
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

    /**
     * @return array<int, string>
     */
    private function insertImageReadyMaterializedStock(string $gameId, string $batchId, int $count): array
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
                'recall_reason' => null,
                'recalled_at' => null,
                'background_set_type' => $assignment['background_set_type'],
                'background_asset_version' => $assignment['background_asset_version'],
                'background_asset_index' => $assignment['background_asset_index'],
                'image_generation_status' => $assignment['image_generation_status'],
                'image_generation_error' => $assignment['image_generation_error'],
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        foreach (array_chunk($rows, 500) as $chunk) {
            DB::table('stock_items')->insert($chunk);
        }

        return $stockIds;
    }

    private function insertLegacyMaterializedLocalStock(
        string $partnerId,
        string $tenantId,
        string $gameId,
        string $stockId,
    ): string {
        $now = now();
        $allocationId = 'alc_'.substr(sha1($tenantId.':lottery-image-legacy'), 0, 20);
        $localStockId = 'lsi_'.substr(sha1($tenantId.':'.$stockId.':lottery-image-legacy'), 0, 20);
        $stock = DB::table('stock_items')->where('id', $stockId)->first();

        DB::table('partner_stock_allocations')->insert([
            'id' => $allocationId,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => 1,
            'allocation_percent_basis_points' => null,
            'allocated_count' => 1,
            'recalled_count' => 0,
            'idempotency_key' => 'lottery-image-legacy-materialized',
            'payload_hash' => hash('sha256', 'lottery-image-legacy-materialized'),
            'created_by_admin_id' => null,
            'reason' => 'legacy materialized fixture',
            'cancelled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('stock_items')->where('id', $stockId)->update([
            'status' => 'allocated',
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'allocation_id' => $allocationId,
            'updated_at' => $now,
        ]);

        DB::table('partner_stock_allocation_items')->insert([
            'allocation_id' => $allocationId,
            'stock_item_id' => $stockId,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'status' => 'allocated',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('local_stock_items')->insert([
            'id' => $localStockId,
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'store_id' => $tenantId,
            'game_id' => $gameId,
            'stock_item_id' => $stockId,
            'allocation_id' => $allocationId,
            'full_number' => (string) $stock->full_number,
            'front3' => $stock->front3,
            'back3' => $stock->back3,
            'back2' => $stock->back2,
            'image_url' => null,
            'image_thumb_url' => null,
            'status' => 'available',
            'synced_at' => $now,
            'reserved_at' => null,
            'sold_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return $localStockId;
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
            'logo_qr' => 'logo_qr.webp',
            'right_sidebar' => 'rightsidebar.webp',
            'logo_bottom' => 'logo_bottom.webp',
        ];
        $assetIds = [];

        foreach ($assets as $slot => $fileName) {
            $assetId = 'ast_'.substr(sha1($partnerId.':'.$slot), 0, 20);
            $assetIds[$slot] = $assetId;
            $storageKey = 'partners/'.$partnerId.'/lottery-branding/v1/'.$fileName;
            $bytes = $this->fixtureBrandingWebp($slot);

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
                'checksum_sha256' => hash('sha256', $assetId),
                'status' => 'committed',
                'storage_key' => $storageKey,
                'upload_url' => null,
                'public_url' => 'https://cdn.lottery.test/'.$fileName,
                'metadata_json' => json_encode(['fixture' => true, 'partner_id' => $partnerId, 'branding_slot' => $slot, 'version' => 'v1'], JSON_THROW_ON_ERROR),
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
            'logo_qr_storage_path' => 'partners/'.$partnerId.'/lottery-branding/v1/logo_qr.webp',
            'right_sidebar_storage_path' => 'partners/'.$partnerId.'/lottery-branding/v1/rightsidebar.webp',
            'logo_bottom_storage_path' => 'partners/'.$partnerId.'/lottery-branding/v1/logo_bottom.webp',
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

    private function fixtureBrandingWebp(string $slot): string
    {
        [$width, $height, $rgb] = match ($slot) {
            'right_sidebar' => [220, 60, [20, 40, 220]],
            'logo_bottom' => [220, 80, [240, 190, 20]],
            default => [80, 80, [230, 30, 45]],
        };
        $image = imagecreatetruecolor($width, $height);
        $background = imagecolorallocate($image, $rgb[0], $rgb[1], $rgb[2]);
        $line = imagecolorallocate($image, 255, 255, 255);

        imagefilledrectangle($image, 0, 0, $width - 1, $height - 1, $background);
        imageline($image, 0, 0, $width - 1, $height - 1, $line);
        imageline($image, 0, $height - 1, $width - 1, 0, $line);

        ob_start();
        imagewebp($image, null, 82);
        $bytes = ob_get_clean();
        imagedestroy($image);

        return is_string($bytes) ? $bytes : '';
    }
}

<?php

use App\Models\LocalStockItem;
use App\Models\PartnerLotteryBrandingAssetSet;
use App\Models\StockItem;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$artifactRoot = getenv('QA_CONTAINER_ARTIFACT_ROOT') ?: sys_get_temp_dir().'/qa-lottery-runtime-evidence';
$storageRoot = $artifactRoot.'/storage';
$assetRoot = $artifactRoot.'/assets';

config([
    'lottery_images.asset_root' => $assetRoot,
    'lottery_images.cdn_base_url' => 'https://cdn.qa-lottery.test',
    'filesystems.disks.lottery_images.root' => $storageRoot,
]);
Storage::forgetDisk('lottery_images');

File::ensureDirectoryExists($artifactRoot);
File::ensureDirectoryExists($assetRoot.'/games/gam_qa_runtime/backgrounds/v1/odd');
File::ensureDirectoryExists($assetRoot.'/games/gam_qa_runtime/backgrounds/v1/even');
File::ensureDirectoryExists($assetRoot.'/games/gam_qa_runtime/backgrounds/v1/charity');

$fixtureWebp = base64_decode('UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA', true);
file_put_contents($assetRoot.'/games/gam_qa_runtime/backgrounds/v1/odd/001.webp', $fixtureWebp);
file_put_contents($assetRoot.'/games/gam_qa_runtime/backgrounds/v1/even/001.webp', $fixtureWebp);
file_put_contents($assetRoot.'/games/gam_qa_runtime/backgrounds/v1/charity/001.webp', $fixtureWebp);

$generator = app(LotteryImageGenerator::class);
$stock = new StockItem();
$stock->forceFill([
    'id' => 'stk_qa_runtime',
    'game_id' => 'gam_qa_runtime',
    'batch_id' => 'stb_qa_runtime',
    'full_number' => '123456',
    'background_set_type' => 'odd',
    'background_asset_version' => 'v1',
    'background_asset_index' => 1,
]);

$localStock = new LocalStockItem();
$localStock->forceFill([
    'id' => 'lsi_qa_runtime',
    'tenant_id' => 'ten_qa_runtime',
    'partner_id' => 'par_qa_runtime',
    'game_id' => 'gam_qa_runtime',
    'full_number' => '123456',
]);

$assetSet = new PartnerLotteryBrandingAssetSet();
$assetSet->forceFill([
    'version' => 'v1',
    'logo_qr_storage_path' => 'lottery-image-assets/partners/par_qa_runtime/branding/v1/logo_qr.webp',
    'right_sidebar_storage_path' => 'lottery-image-assets/partners/par_qa_runtime/branding/v1/right_sidebar.webp',
    'logo_bottom_storage_path' => 'lottery-image-assets/partners/par_qa_runtime/branding/v1/logo_bottom.webp',
]);

$centralFullKey = $generator->centralObjectKey('gam_qa_runtime', 'stb_qa_runtime', 'stk_qa_runtime', 'full');
$centralThumbKey = $generator->centralObjectKey('gam_qa_runtime', 'stb_qa_runtime', 'stk_qa_runtime', 'thumb');
$partnerFullKey = $generator->partnerObjectKey('gam_qa_runtime', 'stb_qa_runtime', 'par_qa_runtime', 'stk_qa_runtime', 'full');
$partnerThumbKey = $generator->partnerObjectKey('gam_qa_runtime', 'stb_qa_runtime', 'par_qa_runtime', 'stk_qa_runtime', 'thumb');

$centralFullBytes = $generator->renderCentralImage($stock, 'full');
$centralThumbBytes = $generator->renderCentralImage($stock, 'thumb');
$partnerFullBytes = $generator->renderPartnerImage($localStock, $stock, $assetSet, 'full');
$partnerThumbBytes = $generator->renderPartnerImage($localStock, $stock, $assetSet, 'thumb');

foreach ([
    $centralFullKey => $centralFullBytes,
    $centralThumbKey => $centralThumbBytes,
    $partnerFullKey => $partnerFullBytes,
    $partnerThumbKey => $partnerThumbBytes,
] as $key => $bytes) {
    $generator->storeObject($key, $bytes);
}

file_put_contents($artifactRoot.'/central-full.webp', $centralFullBytes);
file_put_contents($artifactRoot.'/partner-full.webp', $partnerFullBytes);

$dbImageColumns = [];
foreach (['stock_items', 'local_stock_items', 'tickets'] as $table) {
    if (Schema::hasTable($table)) {
        $dbImageColumns[$table] = array_values(array_filter(Schema::getColumnListing($table), fn (string $column): bool => str_contains($column, 'image')));
    }
}

$result = [
    'result' => 'PASS',
    'config' => [
        'enabled' => config('lottery_images.enabled'),
        'disk' => config('lottery_images.disk'),
        'cdn_base_url' => config('lottery_images.cdn_base_url'),
        'object_prefix' => config('lottery_images.object_prefix'),
        'background_mix' => config('lottery_images.background_mix'),
        'dimensions' => config('lottery_images.dimensions'),
        'content_type' => config('lottery_images.content_type'),
        'cache_control' => config('lottery_images.cache_control'),
    ],
    'keys' => [
        'central_full' => $centralFullKey,
        'central_thumb' => $centralThumbKey,
        'partner_full' => $partnerFullKey,
        'partner_thumb' => $partnerThumbKey,
    ],
    'urls' => [
        'central_full' => $generator->publicUrl($centralFullKey),
        'partner_full' => $generator->publicUrl($partnerFullKey),
    ],
    'bytes' => [
        'central_full_sample_path' => $artifactRoot.'/central-full.webp',
        'partner_full_sample_path' => $artifactRoot.'/partner-full.webp',
        'central_first_16_hex' => bin2hex(substr($centralFullBytes, 0, 16)),
        'partner_first_16_hex' => bin2hex(substr($partnerFullBytes, 0, 16)),
        'central_full_size' => strlen($centralFullBytes),
        'central_thumb_size' => strlen($centralThumbBytes),
        'partner_full_size' => strlen($partnerFullBytes),
        'partner_thumb_size' => strlen($partnerThumbBytes),
        'central_starts_riff' => str_starts_with($centralFullBytes, 'RIFF'),
        'central_contains_webp' => str_contains($centralFullBytes, 'WEBP'),
        'central_contains_scope_central' => str_contains($centralFullBytes, '"scope":"central"'),
        'central_contains_branding_paths' => str_contains($centralFullBytes, 'logo_qr_storage_path') || str_contains($centralFullBytes, 'right_sidebar_storage_path') || str_contains($centralFullBytes, 'logo_bottom_storage_path'),
        'partner_contains_scope_partner' => str_contains($partnerFullBytes, '"scope":"partner"'),
        'partner_contains_branding_paths' => str_contains($partnerFullBytes, 'logo_qr_storage_path') && str_contains($partnerFullBytes, 'right_sidebar_storage_path') && str_contains($partnerFullBytes, 'logo_bottom_storage_path'),
    ],
    'storage' => [
        'central_full_exists' => Storage::disk('lottery_images')->exists($centralFullKey),
        'central_thumb_exists' => Storage::disk('lottery_images')->exists($centralThumbKey),
        'partner_full_exists' => Storage::disk('lottery_images')->exists($partnerFullKey),
        'partner_thumb_exists' => Storage::disk('lottery_images')->exists($partnerThumbKey),
    ],
    'database_image_columns' => $dbImageColumns,
    'runtime_limitation' => [
        'gd_loaded' => extension_loaded('gd'),
        'imagick_loaded' => extension_loaded('imagick'),
        'cwebp_available' => trim((string) shell_exec('command -v cwebp 2>/dev/null')) !== '',
        'renderer_mode' => 'metadata_webp_container_placeholder',
        'full_visual_legacy_composition_available' => false,
    ],
];

echo json_encode($result, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR).PHP_EOL;

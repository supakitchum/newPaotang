<?php

declare(strict_types=1);

use App\Models\LocalStockItem;
use App\Models\PartnerLotteryBrandingAssetSet;
use App\Models\StockItem;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\Storage;

$appRoot = '/var/www/html';

require $appRoot.'/vendor/autoload.php';
$app = require $appRoot.'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$samplesDir = getenv('QA_SAMPLE_DIR') ?: '/tmp/qa-lottery-visual-samples';
$runtimeDir = getenv('QA_RUNTIME_DIR') ?: '/tmp/qa-lottery-visual-runtime';
$assetRoot = sys_get_temp_dir().'/qa-lottery-visual-assets-'.bin2hex(random_bytes(4));
$storageRoot = sys_get_temp_dir().'/qa-lottery-visual-storage-'.bin2hex(random_bytes(4));

ensureDirectory($samplesDir);
ensureDirectory($runtimeDir);
ensureDirectory($assetRoot);
ensureDirectory($storageRoot);

config([
    'lottery_images.asset_root' => $assetRoot,
    'lottery_images.cdn_base_url' => 'https://qa-cdn.lottery.test',
    'filesystems.disks.lottery_images.root' => $storageRoot,
]);
Storage::forgetDisk('lottery_images');

$gameId = 'gam_qa_visual_runtime';
$batchId = 'bat_qa_visual_runtime';
$partnerId = 'par_qa_visual_runtime';
$stockId = 'stk_qa_visual_runtime';

writeBackground($assetRoot, $gameId, 'odd', 1);
writeBackground($assetRoot, $gameId, 'even', 1);
writeBackground($assetRoot, $gameId, 'charity', 1);

$assetPaths = [
    'logo_qr' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/logo-qr.webp',
    'right_sidebar' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/right-sidebar.webp',
    'logo_bottom' => 'lottery-image-assets/partners/'.$partnerId.'/branding/v1/logo-bottom.webp',
];

Storage::disk('lottery_images')->put($assetPaths['logo_qr'], fixtureWebp(96, 96, [8, 124, 220], [255, 255, 255], 'QR'));
Storage::disk('lottery_images')->put($assetPaths['right_sidebar'], fixtureWebp(60, 240, [14, 96, 174], [246, 182, 42], 'SIDE'));
Storage::disk('lottery_images')->put($assetPaths['logo_bottom'], fixtureWebp(220, 58, [247, 183, 42], [20, 31, 49], 'LOGO'));

$stock = new StockItem([
    'id' => $stockId,
    'game_id' => $gameId,
    'batch_id' => $batchId,
    'full_number' => '456789',
    'front3' => '456',
    'back3' => '789',
    'back2' => '89',
    'status' => 'available',
    'background_set_type' => 'odd',
    'background_asset_version' => 'v1',
    'background_asset_index' => 1,
]);

$localStock = new LocalStockItem([
    'id' => 'lst_qa_visual_runtime',
    'tenant_id' => 'ten_qa_visual_runtime',
    'partner_id' => $partnerId,
    'game_id' => $gameId,
    'stock_item_id' => $stockId,
    'full_number' => '456789',
    'front3' => '456',
    'back3' => '789',
    'back2' => '89',
    'status' => 'available',
]);

$assetSet = new PartnerLotteryBrandingAssetSet([
    'id' => 'plas_qa_visual_runtime',
    'partner_id' => $partnerId,
    'version' => 'v1',
    'status' => 'ready',
    'logo_qr_storage_path' => $assetPaths['logo_qr'],
    'right_sidebar_storage_path' => $assetPaths['right_sidebar'],
    'logo_bottom_storage_path' => $assetPaths['logo_bottom'],
]);

$generator = app(LotteryImageGenerator::class);

$images = [
    'central_full' => $generator->renderCentralImage($stock, 'full'),
    'central_thumb' => $generator->renderCentralImage($stock, 'thumb'),
    'partner_full' => $generator->renderPartnerImage($localStock, $stock, $assetSet, 'full'),
    'partner_thumb' => $generator->renderPartnerImage($localStock, $stock, $assetSet, 'thumb'),
];

file_put_contents($samplesDir.'/central-full.webp', $images['central_full']);
file_put_contents($samplesDir.'/central-thumb.webp', $images['central_thumb']);
file_put_contents($samplesDir.'/partner-full.webp', $images['partner_full']);
file_put_contents($samplesDir.'/partner-thumb.webp', $images['partner_thumb']);

$evidence = [
    'runtime' => [
        'gd_loaded' => extension_loaded('gd'),
        'imagick_loaded' => extension_loaded('imagick'),
        'imagewebp' => function_exists('imagewebp'),
        'imagecreatefromwebp' => function_exists('imagecreatefromwebp'),
        'lottery_images_runtime' => config('lottery_images.runtime'),
    ],
    'asset_set' => [
        'status' => $assetSet->status,
        'logo_qr_exists' => Storage::disk('lottery_images')->exists($assetPaths['logo_qr']),
        'right_sidebar_exists' => Storage::disk('lottery_images')->exists($assetPaths['right_sidebar']),
        'logo_bottom_exists' => Storage::disk('lottery_images')->exists($assetPaths['logo_bottom']),
    ],
    'images' => [],
    'visual_diffs' => [
        'right_sidebar_pixel_distance' => colorDistance(pixelRgb($images['central_full'], 474, 140), pixelRgb($images['partner_full'], 474, 140)),
        'bottom_logo_pixel_distance' => colorDistance(pixelRgb($images['central_full'], 318, 230), pixelRgb($images['partner_full'], 318, 230)),
    ],
    'content_guards' => [
        'central_contains_placeholder_marker' => str_contains($images['central_full'], 'metadata_webp_container_placeholder'),
        'partner_contains_placeholder_marker' => str_contains($images['partner_full'], 'metadata_webp_container_placeholder'),
        'central_contains_partner_storage_path_key' => str_contains($images['central_full'], 'logo_qr_storage_path'),
        'partner_contains_scope_metadata' => str_contains($images['partner_full'], '"scope":"partner"'),
    ],
];

foreach ($images as $name => $bytes) {
    $info = getimagesizefromstring($bytes);
    $decoded = imagecreatefromstring($bytes);

    $evidence['images'][$name] = [
        'bytes' => strlen($bytes),
        'riff_signature' => substr($bytes, 0, 4),
        'webp_signature' => substr($bytes, 8, 4),
        'width' => is_array($info) ? $info[0] : null,
        'height' => is_array($info) ? $info[1] : null,
        'mime' => is_array($info) ? ($info['mime'] ?? null) : null,
        'decoded_by_gd' => $decoded !== false,
        'sha256' => hash('sha256', $bytes),
    ];

    if ($decoded !== false) {
        imagedestroy($decoded);
    }
}

file_put_contents($runtimeDir.'/visual-evidence.json', json_encode($evidence, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL);
echo json_encode($evidence, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;

function ensureDirectory(string $path): void
{
    if (! is_dir($path) && ! mkdir($path, 0777, true) && ! is_dir($path)) {
        throw new RuntimeException('mkdir_failed:'.$path);
    }
}

function writeBackground(string $assetRoot, string $gameId, string $setType, int $index): void
{
    $directory = $assetRoot.'/games/'.$gameId.'/backgrounds/v1/'.$setType;
    ensureDirectory($directory);
    file_put_contents($directory.'/'.str_pad((string) $index, 3, '0', STR_PAD_LEFT).'.webp', fixtureBackgroundWebp($setType));
}

function fixtureBackgroundWebp(string $setType): string
{
    $palette = match ($setType) {
        'even' => [[72, 142, 112], [255, 255, 255], [35, 35, 45]],
        'charity' => [[218, 158, 67], [255, 244, 210], [92, 58, 22]],
        default => [[185, 96, 132], [255, 229, 238], [72, 35, 58]],
    };

    return fixtureWebp(640, 360, $palette[0], $palette[1], strtoupper($setType));
}

function fixtureWebp(int $width, int $height, array $base, array $accent, string $label): string
{
    $image = imagecreatetruecolor($width, $height);
    $background = imagecolorallocate($image, $base[0], $base[1], $base[2]);
    $line = imagecolorallocatealpha($image, $accent[0], $accent[1], $accent[2], 58);
    $ink = imagecolorallocate($image, $accent[0], $accent[1], $accent[2]);
    $dark = imagecolorallocatealpha($image, 20, 20, 28, 76);

    imagefilledrectangle($image, 0, 0, $width - 1, $height - 1, $background);

    for ($x = -$height; $x < $width + $height; $x += max(16, (int) floor($width / 12))) {
        imageline($image, $x, 0, $x + $height, $height, $line);
    }

    imagefilledrectangle($image, 0, max(0, $height - (int) floor($height / 4)), $width - 1, $height - 1, $dark);
    imagestring($image, 5, max(2, (int) floor($width / 10)), max(2, (int) floor($height / 2) - 8), $label, $ink);

    ob_start();
    $encoded = imagewebp($image, null, 82);
    $bytes = ob_get_clean();
    imagedestroy($image);

    if ($encoded !== true || ! is_string($bytes) || $bytes === '') {
        throw new RuntimeException('fixture_webp_encode_failed');
    }

    return $bytes;
}

function pixelRgb(string $bytes, int $x, int $y): array
{
    $image = imagecreatefromstring($bytes);

    if ($image === false) {
        throw new RuntimeException('pixel_decode_failed');
    }

    $rgb = imagecolorat($image, $x, $y);
    imagedestroy($image);

    return [
        ($rgb >> 16) & 0xFF,
        ($rgb >> 8) & 0xFF,
        $rgb & 0xFF,
    ];
}

function colorDistance(array $left, array $right): int
{
    return abs($left[0] - $right[0]) + abs($left[1] - $right[1]) + abs($left[2] - $right[2]);
}

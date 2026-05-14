<?php

namespace App\Modules\CentralStock\Services;

use App\Models\LocalStockItem;
use App\Models\LotteryImageBackgroundAssetSet;
use App\Models\LotteryImageMixSetting;
use App\Models\PartnerLotteryBrandingAssetSet;
use App\Models\PlatformSystemSetting;
use App\Models\StockItem;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

class LotteryImageGenerator
{
    public const SET_TYPES = ['odd', 'even', 'charity'];
    public const LAYOUT_SETTING_KEY = 'lottery_image_layout';
    private const DESIGN_WIDTH = 500;
    private const DESIGN_HEIGHT = 280;
    private const DEFAULT_LAYOUT = [
        'beside' => ['x' => 1, 'y' => 1, 'width' => 43, 'height' => 274],
        'emoji_1' => ['x' => 192, 'y' => 96, 'width' => 24, 'height' => null],
        'emoji_2' => ['x' => 220, 'y' => 96, 'width' => 24, 'height' => null],
        'emoji_3' => ['x' => 192, 'y' => 119, 'width' => 24, 'height' => null],
        'emoji_4' => ['x' => 220, 'y' => 119, 'width' => 24, 'height' => null],
        'number_digits' => ['x' => 257, 'y' => 23, 'width' => 25, 'height' => 20, 'gap' => 30],
        'text_eng' => ['x' => 258, 'y' => 50, 'width' => 12, 'height' => 7, 'gap' => 30],
        'thai_text' => ['x' => 446, 'y' => 20, 'size' => 23, 'angle' => 90],
        'num_set_center_left' => ['x' => 296, 'y' => 67, 'width' => 50, 'height' => 46],
        'num_set_center_right' => ['x' => 326, 'y' => 67, 'width' => 50, 'height' => 46],
        'num_set_right_left' => ['x' => 393, 'y' => 117, 'width' => 22, 'height' => 22],
        'num_set_right_right' => ['x' => 411, 'y' => 117, 'width' => 22, 'height' => 22],
        'num_set_bottom_left' => ['x' => 93, 'y' => 163, 'width' => 25, 'height' => 25],
        'num_set_bottom_right' => ['x' => 110, 'y' => 163, 'width' => 25, 'height' => 25],
        'logo_bottom' => ['x' => 248, 'y' => 85, 'width' => 190, 'height' => null],
        'logo_qr' => ['x' => 200, 'y' => 55, 'width' => 53, 'height' => null],
        'right_sidebar' => ['x' => 440, 'y' => 0, 'width' => 61, 'height' => null, 'rotate' => 90],
    ];

    /** @var array<string, array<string, int|null>>|null */
    private ?array $layoutCache = null;

    /**
     * @param array<int, string> $stockIds
     * @return array<string, array{background_set_type: string, background_asset_version: string, background_asset_index: int, image_generation_status: string, image_generation_error: string|null}>
     */
    public function assignmentsForStockIds(string $gameId, string $batchId, array $stockIds, ?string $seedExtra = null): array
    {
        $sequence = $this->backgroundSequence(count($stockIds), $gameId.':'.$batchId.':'.($seedExtra ?? ''), $gameId);
        $assignments = [];
        $version = (string) config('lottery_images.background_version', 'v1');

        foreach (array_values($stockIds) as $position => $stockId) {
            $setType = $sequence[$position] ?? 'odd';
            $index = $this->backgroundIndex($gameId, $version, $setType, (string) $stockId, $batchId);
            $ready = $this->backgroundReady($gameId, $version, $setType, $index);

            $assignments[(string) $stockId] = [
                'background_set_type' => $setType,
                'background_asset_version' => $version,
                'background_asset_index' => $index,
                'image_generation_status' => $ready ? 'pending' : 'pending_assets',
                'image_generation_error' => $ready ? null : 'background_set_not_ready:'.$setType,
            ];
        }

        return $assignments;
    }

    public function enabled(): bool
    {
        return (bool) config('lottery_images.enabled', true);
    }

    /**
     * @return array<int, string>
     */
    public function setTypes(): array
    {
        return self::SET_TYPES;
    }

    public function backgroundCount(string $gameId, string $version, string $setType): int
    {
        return count($this->backgroundFiles($gameId, $version, $setType));
    }

    public function minimumBackgroundCountFor(string $setType): int
    {
        return $this->minimumBackgroundCount($setType);
    }

    public function backgroundReadyForStock(StockItem $stock): bool
    {
        return $this->backgroundReady(
            (string) $stock->game_id,
            $stock->background_asset_version === null ? null : (string) $stock->background_asset_version,
            $stock->background_set_type === null ? null : (string) $stock->background_set_type,
            $stock->background_asset_index === null ? null : (int) $stock->background_asset_index,
        );
    }

    public function backgroundReady(string $gameId, ?string $version, ?string $setType, ?int $index = null): bool
    {
        if ($version === null || $setType === null || ! in_array($setType, self::SET_TYPES, true)) {
            return false;
        }

        if ($index !== null) {
            return $this->backgroundPath($gameId, $version, $setType, $index) !== null;
        }

        return count($this->backgroundFiles($gameId, $version, $setType)) >= $this->minimumBackgroundCount($setType);
    }

    public function centralObjectKey(string $gameId, string $batchId, string $stockItemId, string $variant = 'full'): string
    {
        $prefix = trim((string) config('lottery_images.object_prefix', 'lotteries'), '/');
        $base = $prefix.'/'.$gameId.'/'.$batchId.'/central';

        return $variant === 'thumb'
            ? $base.'/thumbs/'.$stockItemId.'.webp'
            : $base.'/'.$stockItemId.'.webp';
    }

    public function partnerObjectKey(string $gameId, string $batchId, string $partnerId, string $stockItemId, string $variant = 'full'): string
    {
        $prefix = trim((string) config('lottery_images.object_prefix', 'lotteries'), '/');
        $base = $prefix.'/'.$gameId.'/'.$batchId.'/partners/'.$partnerId;

        return $variant === 'thumb'
            ? $base.'/thumbs/'.$stockItemId.'.webp'
            : $base.'/'.$stockItemId.'.webp';
    }

    public function storeObject(string $key, string $bytes): void
    {
        Storage::disk((string) config('lottery_images.disk', 'lottery_images'))->put($key, $bytes, [
            'ContentType' => (string) config('lottery_images.content_type', 'image/webp'),
            'CacheControl' => (string) config('lottery_images.cache_control', 'public, max-age=31536000, immutable'),
        ]);
    }

    public function publicUrl(string $key): string
    {
        $baseUrl = rtrim((string) config('lottery_images.cdn_base_url', ''), '/');

        if ($baseUrl !== '') {
            return $baseUrl.'/'.ltrim($key, '/');
        }

        return Storage::disk((string) config('lottery_images.disk', 'lottery_images'))->url($key);
    }

    /**
     * @return array<string, array<string, int|null>>
     */
    public static function defaultLayout(): array
    {
        return self::DEFAULT_LAYOUT;
    }

    /**
     * @param array<string, mixed>|null $override
     * @return array<string, array<string, int|null>>
     */
    public function layout(?array $override = null): array
    {
        $stored = $this->storedLayout();

        return $this->mergeLayout($override === null ? $stored : array_replace_recursive($stored, $override));
    }

    public function renderCentralImage(StockItem $stock, string $variant, ?array $layoutOverride = null): string
    {
        return $this->renderTicketImage($stock, null, null, $variant, $layoutOverride);
    }

    public function renderPartnerImage(LocalStockItem $localStock, StockItem $stock, PartnerLotteryBrandingAssetSet $assetSet, string $variant, ?array $layoutOverride = null): string
    {
        return $this->renderTicketImage($stock, $localStock, $assetSet, $variant, $layoutOverride);
    }

    private function renderTicketImage(StockItem $stock, ?LocalStockItem $localStock, ?PartnerLotteryBrandingAssetSet $assetSet, string $variant, ?array $layoutOverride = null): string
    {
        $this->assertGdWebpRuntime();
        [$width, $height, $quality] = $this->variantSpec($variant);
        $layout = $this->layout($layoutOverride);

        $canvas = imagecreatetruecolor($width, $height);

        if ($canvas === false) {
            throw new RuntimeException('lottery_image_canvas_create_failed');
        }

        imagealphablending($canvas, true);

        try {
            $this->drawBackground($canvas, $stock, $width, $height);
            $this->drawBaseTicket($canvas, $stock, $width, $height, $layout);

            if ($localStock !== null && $assetSet !== null) {
                $this->drawPartnerBranding($canvas, $localStock, $assetSet, $width, $height, $layout);
            }

            return $this->encodeWebp($canvas, $quality);
        } finally {
            imagedestroy($canvas);
        }
    }

    private function assertGdWebpRuntime(): void
    {
        $runtime = (string) config('lottery_images.runtime', 'gd');

        if ($runtime !== 'gd') {
            throw new RuntimeException('lottery_image_runtime_unsupported:'.$runtime);
        }

        if (! extension_loaded('gd') || ! function_exists('imagewebp') || ! function_exists('imagecreatetruecolor')) {
            throw new RuntimeException('lottery_image_runtime_gd_webp_unavailable');
        }
    }

    /**
     * @return array{0: int, 1: int, 2: int}
     */
    private function variantSpec(string $variant): array
    {
        $spec = config('lottery_images.dimensions.'.$variant);

        if (! is_array($spec)) {
            throw new RuntimeException('lottery_image_variant_unknown:'.$variant);
        }

        $width = max(1, (int) ($spec['width'] ?? 0));
        $height = max(1, (int) ($spec['height'] ?? round($width * 0.56)));
        $quality = min(100, max(0, (int) ($spec['quality'] ?? 70)));

        return [$width, $height, $quality];
    }

    private function drawBackground(mixed $canvas, StockItem $stock, int $width, int $height): void
    {
        $path = $this->backgroundPath(
            (string) $stock->game_id,
            (string) $stock->background_asset_version,
            (string) $stock->background_set_type,
            (int) $stock->background_asset_index,
        );

        if ($path === null) {
            throw new RuntimeException('background_set_not_ready:'.(string) $stock->background_set_type);
        }

        $source = $this->loadImageFile($path);

        if ($source === null) {
            throw new RuntimeException('background_decode_failed:'.basename($path));
        }

        try {
            $this->copyCover($source, $canvas, 0, 0, $width, $height);
        } finally {
            imagedestroy($source);
        }
    }

    /**
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawBaseTicket(mixed $canvas, StockItem $stock, int $width, int $height, array $layout): void
    {
        $seed = $this->renderSeed($stock);
        $this->drawBeside($canvas, $seed, $width, $height, $layout);
        $this->drawEmojiSlots($canvas, $seed, $width, $height, $layout);
        $digits = $this->normalizedTicketNumber((string) $stock->full_number);
        $this->drawLotteryDigits($canvas, $digits, $width, $height, $layout);
        $this->drawThaiDigitText($canvas, $digits, $width, $height, $layout);
        $this->drawNumSet($canvas, $this->numSetDigits($seed, (string) $stock->background_set_type), $width, $height, $layout);
    }

    /**
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawPartnerBranding(mixed $canvas, LocalStockItem $localStock, PartnerLotteryBrandingAssetSet $assetSet, int $width, int $height, array $layout): void
    {
        $this->drawBrandingSlot($canvas, $assetSet->logo_bottom_storage_path, 'logo_bottom', $width, $height, $layout);
        $this->drawBrandingSlot($canvas, $assetSet->logo_qr_storage_path, 'logo_qr', $width, $height, $layout);
        $this->drawBrandingSlot($canvas, $assetSet->right_sidebar_storage_path, 'right_sidebar', $width, $height, $layout);
    }

    /**
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawBeside(mixed $canvas, string $seed, int $width, int $height, array $layout): void
    {
        $path = $this->deterministicSystemAsset('beside', $seed, ['png']);

        if ($path === null) {
            return;
        }

        $this->drawLocalSlot($canvas, $path, 'beside', $width, $height, $layout, stretch: true);
    }

    /**
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawEmojiSlots(mixed $canvas, string $seed, int $width, int $height, array $layout): void
    {
        $slots = [
            ['emoji/e1', 'emoji_1'],
            ['emoji/e2', 'emoji_2'],
            ['emoji/e3', 'emoji_3'],
            ['emoji/e4', 'emoji_4'],
        ];

        foreach ($slots as $index => [$directory, $slotKey]) {
            $path = $this->deterministicSystemAsset($directory, $seed.':emoji:'.$index, ['png']);

            if ($path !== null) {
                $this->drawLocalSlot($canvas, $path, $slotKey, $width, $height, $layout);
            }
        }
    }

    /**
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawLotteryDigits(mixed $canvas, string $digits, int $width, int $height, array $layout): void
    {
        $number = $layout['number_digits'];
        $text = $layout['text_eng'];

        foreach (str_split($digits) as $index => $digit) {
            $numberPath = $this->systemAssetPath('number/'.$digit.'.png');

            if ($numberPath !== null) {
                $this->drawLocalAsset(
                    $canvas,
                    $numberPath,
                    $this->sx((int) $number['x'] + ((int) $number['gap'] * $index), $width),
                    $this->sy((int) $number['y'], $height),
                    $this->sx((int) $number['width'], $width),
                    $this->sy((int) $number['height'], $height),
                );
            }

            $textPath = $this->systemAssetPath('text_eng/'.$digit.'.png');

            if ($textPath !== null) {
                $this->drawLocalAsset(
                    $canvas,
                    $textPath,
                    $this->sx((int) $text['x'] + ((int) $text['gap'] * $index), $width),
                    $this->sy((int) $text['y'], $height),
                    $this->sx((int) $text['width'], $width),
                    $this->sy((int) $text['height'], $height),
                    stretch: true,
                );
            }
        }
    }

    /**
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawThaiDigitText(mixed $canvas, string $digits, int $width, int $height, array $layout): void
    {
        $slot = $layout['thai_text'];
        $font = $this->fontAssetPath('lotto-font5.ttf') ?? $this->fontPath();
        $text = implode('', array_map(fn (string $digit): string => $this->thaiGlyphForDigit($digit), str_split($digits)));
        $x = $this->sx((int) $slot['x'], $width);
        $y = $this->sy((int) $slot['y'], $height);
        $color = imagecolorallocate($canvas, 73, 43, 47);

        if ($font !== null && function_exists('imagettftext')) {
            imagettftext($canvas, max(8, $this->sy((int) $slot['size'], $height)), (int) $slot['angle'], $x, $y, $color, $font, $text);

            return;
        }

        imagestringup($canvas, 3, $x, $y, $text, $color);
    }

    /**
     * @param array{0: string, 1: string} $digits
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawNumSet(mixed $canvas, array $digits, int $width, int $height, array $layout): void
    {
        [$left, $right] = $digits;
        $this->drawSystemSlot($canvas, 'num_set_center/'.$left.'.png', 'num_set_center_left', $width, $height, $layout, true);
        $this->drawSystemSlot($canvas, 'num_set_center/'.$right.'.png', 'num_set_center_right', $width, $height, $layout, true);
        $this->drawSystemSlot($canvas, 'num_set_right/'.$left.'.png', 'num_set_right_left', $width, $height, $layout, true);
        $this->drawSystemSlot($canvas, 'num_set_right/'.$right.'.png', 'num_set_right_right', $width, $height, $layout, true);
        $this->drawSystemSlot($canvas, 'num_set_center/'.$left.'.png', 'num_set_bottom_left', $width, $height, $layout, true);
        $this->drawSystemSlot($canvas, 'num_set_center/'.$right.'.png', 'num_set_bottom_right', $width, $height, $layout, true);
    }

    /**
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawSystemSlot(mixed $canvas, string $relativePath, string $slotKey, int $width, int $height, array $layout, bool $stretch = false): void
    {
        $path = $this->systemAssetPath($relativePath);

        if ($path !== null) {
            $this->drawLocalSlot($canvas, $path, $slotKey, $width, $height, $layout, $stretch);
        }
    }

    /**
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawLocalSlot(mixed $canvas, string $path, string $slotKey, int $width, int $height, array $layout, bool $stretch = false): void
    {
        $slot = $layout[$slotKey];

        $this->drawLocalAsset(
            $canvas,
            $path,
            $this->sx((int) $slot['x'], $width),
            $this->sy((int) $slot['y'], $height),
            $this->sx((int) $slot['width'], $width),
            $slot['height'] === null ? null : $this->sy((int) $slot['height'], $height),
            $stretch,
        );
    }

    /**
     * @param array<string, array<string, int|null>> $layout
     */
    private function drawBrandingSlot(mixed $canvas, ?string $storagePath, string $slotKey, int $width, int $height, array $layout): void
    {
        $slot = $layout[$slotKey];

        $this->drawBrandingAsset(
            $canvas,
            $storagePath,
            $this->sx((int) $slot['x'], $width),
            $this->sy((int) $slot['y'], $height),
            $this->sx((int) $slot['width'], $width),
            $slot['height'] === null ? null : $this->sy((int) $slot['height'], $height),
            (int) ($slot['rotate'] ?? 0),
        );
    }

    private function drawBrandingAsset(mixed $canvas, ?string $storagePath, int $x, int $y, int $targetWidth, ?int $targetHeight = null, int $rotateDegrees = 0): void
    {
        $asset = $this->loadStorageImage($storagePath);

        if ($asset === null) {
            return;
        }

        try {
            if ($rotateDegrees !== 0) {
                $rotated = imagerotate($asset, $rotateDegrees, imagecolorallocatealpha($asset, 0, 0, 0, 127));

                if ($rotated !== false) {
                    imagedestroy($asset);
                    $asset = $rotated;
                    imagealphablending($asset, true);
                    imagesavealpha($asset, true);
                }
            }

            $this->copyResizeWidth($asset, $canvas, $x, $y, $targetWidth, $targetHeight);
        } finally {
            imagedestroy($asset);
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function storedLayout(): array
    {
        if ($this->layoutCache !== null) {
            return $this->layoutCache;
        }

        $value = PlatformSystemSetting::query()
            ->where('key', self::LAYOUT_SETTING_KEY)
            ->where('status', 'active')
            ->value('value_json');

        if (is_string($value) && $value !== '') {
            $decoded = json_decode($value, true);
            $value = is_array($decoded) ? $decoded : [];
        }

        $this->layoutCache = is_array($value) ? $value : [];

        return $this->layoutCache;
    }

    /**
     * @param array<string, mixed> $layout
     * @return array<string, array<string, int|null>>
     */
    private function mergeLayout(array $layout): array
    {
        $merged = self::DEFAULT_LAYOUT;

        foreach (self::DEFAULT_LAYOUT as $slotKey => $defaults) {
            $input = is_array($layout[$slotKey] ?? null) ? $layout[$slotKey] : [];

            foreach ($defaults as $field => $default) {
                if (! array_key_exists($field, $input)) {
                    continue;
                }

                $value = $input[$field];
                $merged[$slotKey][$field] = $value === null && $default === null ? null : (int) $value;
            }
        }

        return $merged;
    }

    private function drawLocalAsset(mixed $canvas, string $path, int $x, int $y, int $targetWidth, ?int $targetHeight = null, bool $stretch = false): void
    {
        $asset = $this->loadImageFile($path);

        if ($asset === null) {
            return;
        }

        try {
            if ($targetHeight !== null && $stretch) {
                $this->copyStretch($asset, $canvas, $x, $y, $targetWidth, $targetHeight);
            } else {
                $this->copyResizeWidth($asset, $canvas, $x, $y, $targetWidth, $targetHeight);
            }
        } finally {
            imagedestroy($asset);
        }
    }

    private function loadStorageImage(?string $storagePath): mixed
    {
        if ($storagePath === null || trim($storagePath) === '') {
            return null;
        }

        try {
            $disk = Storage::disk((string) config('lottery_images.disk', 'lottery_images'));

            if (! $disk->exists($storagePath)) {
                return null;
            }

            $bytes = $disk->get($storagePath);
        } catch (\Throwable) {
            return null;
        }

        $image = @imagecreatefromstring($bytes);

        return $image === false ? null : $image;
    }

    public function activePartnerAssetSet(string $partnerId): ?PartnerLotteryBrandingAssetSet
    {
        return PartnerLotteryBrandingAssetSet::query()
            ->where('partner_id', $partnerId)
            ->where('status', 'ready')
            ->orderByDesc('activated_at')
            ->orderByDesc('updated_at')
            ->first();
    }

    private function loadImageFile(string $path): mixed
    {
        if (str_starts_with($path, 'storage://')) {
            return $this->loadStorageImage(substr($path, strlen('storage://')));
        }

        $extension = strtolower(pathinfo($path, PATHINFO_EXTENSION));
        $image = match ($extension) {
            'webp' => function_exists('imagecreatefromwebp') ? @imagecreatefromwebp($path) : false,
            'png' => function_exists('imagecreatefrompng') ? @imagecreatefrompng($path) : false,
            'jpg', 'jpeg' => function_exists('imagecreatefromjpeg') ? @imagecreatefromjpeg($path) : false,
            default => false,
        };

        if ($image === false) {
            $bytes = @file_get_contents($path);
            $image = is_string($bytes) && $bytes !== '' ? @imagecreatefromstring($bytes) : false;
        }

        return $image === false ? null : $image;
    }

    private function copyCover(mixed $source, mixed $target, int $x, int $y, int $width, int $height): void
    {
        $sourceWidth = imagesx($source);
        $sourceHeight = imagesy($source);

        if ($sourceWidth <= 0 || $sourceHeight <= 0) {
            return;
        }

        $scale = max($width / $sourceWidth, $height / $sourceHeight);
        $cropWidth = max(1, (int) floor($width / $scale));
        $cropHeight = max(1, (int) floor($height / $scale));
        $sourceX = max(0, (int) floor(($sourceWidth - $cropWidth) / 2));
        $sourceY = max(0, (int) floor(($sourceHeight - $cropHeight) / 2));

        imagecopyresampled($target, $source, $x, $y, $sourceX, $sourceY, $width, $height, $cropWidth, $cropHeight);
    }

    private function copyStretch(mixed $source, mixed $target, int $x, int $y, int $width, int $height): void
    {
        $sourceWidth = imagesx($source);
        $sourceHeight = imagesy($source);

        if ($sourceWidth <= 0 || $sourceHeight <= 0 || $width <= 0 || $height <= 0) {
            return;
        }

        imagecopyresampled($target, $source, $x, $y, 0, 0, $width, $height, $sourceWidth, $sourceHeight);
    }

    private function copyResizeWidth(mixed $source, mixed $target, int $x, int $y, int $targetWidth, ?int $maxHeight = null): void
    {
        $sourceWidth = imagesx($source);
        $sourceHeight = imagesy($source);

        if ($sourceWidth <= 0 || $sourceHeight <= 0 || $targetWidth <= 0) {
            return;
        }

        $scale = $targetWidth / $sourceWidth;
        $targetHeight = max(1, (int) round($sourceHeight * $scale));

        if ($maxHeight !== null && $targetHeight > $maxHeight) {
            $scale = $maxHeight / $sourceHeight;
            $targetHeight = max(1, $maxHeight);
            $targetWidth = max(1, (int) round($sourceWidth * $scale));
        }

        imagecopyresampled($target, $source, $x, $y, 0, 0, $targetWidth, $targetHeight, $sourceWidth, $sourceHeight);
    }

    private function renderSeed(StockItem $stock): string
    {
        return implode(':', [
            (string) $stock->game_id,
            (string) $stock->batch_id,
            (string) $stock->id,
            (string) $stock->full_number,
            (string) $stock->background_set_type,
        ]);
    }

    /**
     * @return array{0: string, 1: string}
     */
    private function numSetDigits(string $seed, string $setType): array
    {
        $min = $setType === 'charity' ? 0 : 21;
        $max = $setType === 'charity' ? 20 : 89;
        $number = $this->deterministicInt($seed.':num_set', $min, $max);
        $digits = str_pad((string) $number, 2, '0', STR_PAD_LEFT);

        return [$digits[0], $digits[1]];
    }

    private function deterministicInt(string $seed, int $min, int $max): int
    {
        $range = max(1, $max - $min + 1);

        return $min + ((int) hexdec(substr(hash('sha256', $seed), 0, 8)) % $range);
    }

    private function deterministicSystemAsset(string $relativeDirectory, string $seed, array $extensions): ?string
    {
        $files = $this->systemAssetFiles($relativeDirectory, $extensions);

        if ($files === []) {
            return null;
        }

        return $files[$this->deterministicInt($seed.':'.$relativeDirectory, 0, count($files) - 1)];
    }

    /**
     * @param array<int, string> $extensions
     * @return array<int, string>
     */
    private function systemAssetFiles(string $relativeDirectory, array $extensions): array
    {
        $files = [];

        foreach ($this->systemAssetRoots() as $root) {
            $directory = $root.'/'.$relativeDirectory;

            if (! is_dir($directory)) {
                continue;
            }

            foreach ($extensions as $extension) {
                $files = array_merge($files, glob($directory.'/*.'.$extension) ?: []);
            }

            if ($files !== []) {
                break;
            }
        }

        sort($files, SORT_NATURAL);

        return array_values(array_filter($files, 'is_file'));
    }

    private function systemAssetPath(string $relativePath): ?string
    {
        foreach ($this->systemAssetRoots() as $root) {
            $path = $root.'/'.$relativePath;

            if (is_file($path)) {
                return $path;
            }
        }

        return null;
    }

    private function fontAssetPath(string $fileName): ?string
    {
        return $this->systemAssetPath('fonts/'.$fileName);
    }

    /**
     * @return array<int, string>
     */
    private function systemAssetRoots(): array
    {
        $configured = rtrim((string) config('lottery_images.asset_root'), '/').'/system/v1';
        $fallback = resource_path('lottery-images/system/v1');

        return array_values(array_unique([$configured, $fallback]));
    }

    private function thaiGlyphForDigit(string $digit): string
    {
        return match ($digit) {
            '0' => 'K',
            '1' => 'L',
            '2' => 'M',
            '3' => 'N',
            '4' => 'O',
            '5' => 'P',
            '6' => 'Q',
            '7' => 'R',
            '8' => 'S',
            '9' => 'T',
            default => '',
        };
    }

    private function sx(int $value, int $width): int
    {
        return (int) round($value * $width / self::DESIGN_WIDTH);
    }

    private function sy(int $value, int $height): int
    {
        return (int) round($value * $height / self::DESIGN_HEIGHT);
    }

    private function normalizedTicketNumber(string $number): string
    {
        $digits = preg_replace('/\D+/', '', $number) ?: '0';

        return str_pad(substr($digits, -6), 6, '0', STR_PAD_LEFT);
    }

    private function fontPath(): ?string
    {
        $assetRoot = rtrim((string) config('lottery_images.asset_root'), '/');
        $paths = [
            $assetRoot.'/system/v1/fonts/Kanit-Regular.ttf',
            resource_path('lottery-images/system/v1/fonts/Kanit-Regular.ttf'),
            resource_path('lottery-images/system/v1/fonts/THSarabunNew.ttf'),
            resource_path('lottery-images/system/v1/fonts/lotto-font5.ttf'),
        ];

        foreach ($paths as $path) {
            if (is_file($path)) {
                return $path;
            }
        }

        return null;
    }

    /**
     * @return array<int, string>
     */
    private function backgroundSequence(int $count, string $seed, string $gameId): array
    {
        if ($count <= 0) {
            return [];
        }

        $remaining = $this->mixCounts($count, $gameId);
        $sequence = [];
        $previous = null;

        for ($position = 0; $position < $count; $position++) {
            $candidates = array_values(array_filter(
                self::SET_TYPES,
                fn (string $type): bool => ($remaining[$type] ?? 0) > 0 && $type !== $previous,
            ));

            if ($candidates === []) {
                $candidates = array_values(array_filter(
                    self::SET_TYPES,
                    fn (string $type): bool => ($remaining[$type] ?? 0) > 0,
                ));
            }

            usort($candidates, function (string $left, string $right) use ($remaining, $seed, $position): int {
                $countCompare = ($remaining[$right] ?? 0) <=> ($remaining[$left] ?? 0);

                if ($countCompare !== 0) {
                    return $countCompare;
                }

                return $this->deterministicRank($seed, $position, $left) <=> $this->deterministicRank($seed, $position, $right);
            });

            $selected = $candidates[0];
            $sequence[] = $selected;
            $remaining[$selected]--;
            $previous = $selected;
        }

        return $sequence;
    }

    /**
     * @return array<string, int>
     */
    private function mixCounts(int $count, string $gameId): array
    {
        $weights = $this->backgroundMixForGame($gameId);
        $totalWeight = max(1, array_sum(array_map('intval', $weights)));
        $counts = [];
        $remainders = [];
        $allocated = 0;

        foreach (self::SET_TYPES as $type) {
            $exact = $count * (int) ($weights[$type] ?? 0) / $totalWeight;
            $counts[$type] = (int) floor($exact);
            $remainders[$type] = $exact - $counts[$type];
            $allocated += $counts[$type];
        }

        while ($allocated < $count) {
            $selected = self::SET_TYPES[0];

            foreach (self::SET_TYPES as $type) {
                if ($remainders[$type] > $remainders[$selected]) {
                    $selected = $type;
                }
            }

            $counts[$selected]++;
            $remainders[$selected] = -1;
            $allocated++;
        }

        return $counts;
    }

    /**
     * @return array<string, int>
     */
    private function backgroundMixForGame(string $gameId): array
    {
        try {
            $setting = LotteryImageMixSetting::query()
                ->where('game_id', $gameId)
                ->first();

            if ($setting !== null) {
                return [
                    'odd' => (int) $setting->odd_percentage,
                    'even' => (int) $setting->even_percentage,
                    'charity' => (int) $setting->charity_percentage,
                ];
            }
        } catch (\Throwable) {
            //
        }

        return array_map(
            fn (mixed $value): int => (int) $value,
            config('lottery_images.background_mix', ['odd' => 45, 'even' => 45, 'charity' => 10]),
        );
    }

    private function backgroundIndex(string $gameId, string $version, string $setType, string $stockItemId, string $batchId): int
    {
        $availableCount = max(1, count($this->backgroundFiles($gameId, $version, $setType)));
        $hash = crc32($gameId.':'.$version.':'.$setType.':'.$batchId.':'.$stockItemId);

        return (int) (($hash % $availableCount) + 1);
    }

    private function backgroundPath(string $gameId, string $version, string $setType, int $index): ?string
    {
        $files = $this->backgroundFiles($gameId, $version, $setType);

        return $files[$index - 1] ?? null;
    }

    /**
     * @return array<int, string>
     */
    private function backgroundFiles(string $gameId, string $version, string $setType): array
    {
        $files = $this->registeredBackgroundFiles($gameId, $version, $setType);
        $directory = rtrim((string) config('lottery_images.asset_root'), '/').'/games/'.$gameId.'/backgrounds/'.$version.'/'.$setType;

        if (! is_dir($directory)) {
            return $files;
        }

        foreach (['webp', 'png', 'jpg', 'jpeg'] as $extension) {
            $files = array_merge($files, glob($directory.'/*.'.$extension) ?: []);
        }

        sort($files, SORT_NATURAL);

        return array_values($files);
    }

    /**
     * @return array<int, string>
     */
    private function registeredBackgroundFiles(string $gameId, string $version, string $setType): array
    {
        try {
            $rows = LotteryImageBackgroundAssetSet::query()
                ->where('game_id', $gameId)
                ->where('version', $version)
                ->where('set_type', $setType)
                ->where('status', 'ready')
                ->orderBy('position')
                ->orderByDesc('activated_at')
                ->orderByDesc('updated_at')
                ->get();
        } catch (\Throwable) {
            return [];
        }

        $paths = [];

        foreach ($rows as $row) {
            $path = trim((string) $row->full_storage_path);
            $sourcePath = trim((string) $row->source_storage_path);
            $thumbPath = trim((string) $row->thumb_storage_path);

            if (
                $path !== ''
                && $sourcePath !== ''
                && $thumbPath !== ''
                && $this->storagePathExists($path)
                && $this->storagePathExists($sourcePath)
                && $this->storagePathExists($thumbPath)
            ) {
                $paths[] = 'storage://'.$path;
            }
        }

        return $paths;
    }

    private function storagePathExists(string $storagePath): bool
    {
        try {
            return Storage::disk((string) config('lottery_images.disk', 'lottery_images'))->exists($storagePath);
        } catch (\Throwable) {
            return false;
        }
    }

    private function minimumBackgroundCount(string $setType): int
    {
        return max(1, (int) config('lottery_images.background_min_counts.'.$setType, 1));
    }

    private function deterministicRank(string $seed, int $position, string $type): int
    {
        return (int) hexdec(substr(hash('sha256', $seed.':'.$position.':'.$type), 0, 8));
    }

    private function encodeWebp(mixed $canvas, int $quality): string
    {
        ob_start();
        $encoded = imagewebp($canvas, null, $quality);
        $bytes = ob_get_clean();

        if ($encoded !== true || ! is_string($bytes) || $bytes === '') {
            throw new RuntimeException('lottery_image_webp_encode_failed');
        }

        if (substr($bytes, 0, 4) !== 'RIFF' || substr($bytes, 8, 4) !== 'WEBP') {
            throw new RuntimeException('lottery_image_webp_signature_invalid');
        }

        return $bytes;
    }
}

<?php

namespace App\Modules\CentralStock\Services;

use App\Models\LocalStockItem;
use App\Models\LotteryImageBackgroundAssetSet;
use App\Models\LotteryImageMixSetting;
use App\Models\PartnerLotteryBrandingAssetSet;
use App\Models\StockItem;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

class LotteryImageGenerator
{
    public const SET_TYPES = ['odd', 'even', 'charity'];

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

    public function renderCentralImage(StockItem $stock, string $variant): string
    {
        return $this->renderTicketImage($stock, null, null, $variant);
    }

    public function renderPartnerImage(LocalStockItem $localStock, StockItem $stock, PartnerLotteryBrandingAssetSet $assetSet, string $variant): string
    {
        return $this->renderTicketImage($stock, $localStock, $assetSet, $variant);
    }

    private function renderTicketImage(StockItem $stock, ?LocalStockItem $localStock, ?PartnerLotteryBrandingAssetSet $assetSet, string $variant): string
    {
        $this->assertGdWebpRuntime();
        [$width, $height, $quality] = $this->variantSpec($variant);

        $canvas = imagecreatetruecolor($width, $height);

        if ($canvas === false) {
            throw new RuntimeException('lottery_image_canvas_create_failed');
        }

        imagealphablending($canvas, true);

        try {
            $this->drawBackground($canvas, $stock, $width, $height);
            $this->drawBaseTicket($canvas, $stock, $width, $height);

            if ($localStock !== null && $assetSet !== null) {
                $this->drawPartnerBranding($canvas, $localStock, $assetSet, $width, $height);
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

    private function drawBaseTicket(mixed $canvas, StockItem $stock, int $width, int $height): void
    {
        $palette = $this->setPalette($canvas, (string) $stock->background_set_type);
        $white = imagecolorallocatealpha($canvas, 255, 255, 255, 24);
        $softWhite = imagecolorallocatealpha($canvas, 255, 255, 255, 52);
        $shadow = imagecolorallocatealpha($canvas, 31, 36, 48, 72);
        $ink = imagecolorallocate($canvas, 40, 37, 48);
        $muted = imagecolorallocatealpha($canvas, 72, 70, 82, 42);

        $stripWidth = max(9, $this->sx(20, $width));
        imagefilledrectangle($canvas, 0, 0, $stripWidth, $height, $palette['dark']);

        for ($y = -$height; $y < $height * 2; $y += max(11, $this->sy(18, $height))) {
            imageline($canvas, 0, $y, $stripWidth, $y + $this->sy(26, $height), $palette['accent']);
        }

        $left = $this->sx(34, $width);
        $top = $this->sy(22, $height);
        $right = $width - $this->sx(32, $width);
        $bottom = $height - $this->sy(24, $height);

        imagefilledrectangle($canvas, $left + $this->sx(4, $width), $top + $this->sy(5, $height), $right + $this->sx(4, $width), $bottom + $this->sy(5, $height), $shadow);
        imagefilledrectangle($canvas, $left, $top, $right, $bottom, $white);
        imagerectangle($canvas, $left, $top, $right, $bottom, $palette['accent']);
        imagefilledrectangle($canvas, $left, $top, $right, $top + $this->sy(30, $height), $softWhite);

        $this->drawCenteredText($canvas, 'NEWPAOTANG LOTTERY', (int) round($width / 2), $this->sy(45, $height), max(8, $this->sy(13, $height)), $ink);
        $this->drawCenteredText($canvas, strtoupper((string) $stock->background_set_type).' SET', (int) round($width / 2), $this->sy(222, $height), max(7, $this->sy(11, $height)), $palette['dark']);

        $digits = $this->normalizedTicketNumber((string) $stock->full_number);
        $this->drawSevenSegmentNumber($canvas, $digits, $width, $height, $palette['digit'], $muted);

        $badgeTop = $this->sy(197, $height);
        $this->drawBadge($canvas, 'BATCH '.substr((string) $stock->batch_id, -6), $this->sx(62, $width), $badgeTop, $this->sx(130, $width), $this->sy(22, $height), $palette['accent'], $ink);
        $this->drawBadge($canvas, 'NO. '.substr($digits, -3), $width - $this->sx(180, $width), $badgeTop, $this->sx(118, $width), $this->sy(22, $height), $softWhite, $ink);
        $this->drawFixtureMarks($canvas, $width, $height, $palette['accent'], $palette['dark']);
    }

    private function drawPartnerBranding(mixed $canvas, LocalStockItem $localStock, PartnerLotteryBrandingAssetSet $assetSet, int $width, int $height): void
    {
        $primary = imagecolorallocate($canvas, 30, 86, 166);
        $secondary = imagecolorallocate($canvas, 246, 182, 42);
        $ink = imagecolorallocate($canvas, 20, 31, 49);
        $white = imagecolorallocate($canvas, 255, 255, 255);
        $soft = imagecolorallocatealpha($canvas, 255, 255, 255, 18);

        $sidebarWidth = max(24, $this->sx(56, $width));
        $sidebarX = $width - $sidebarWidth;
        imagefilledrectangle($canvas, $sidebarX, 0, $width, $height, $primary);

        for ($y = 0; $y < $height; $y += max(13, $this->sy(26, $height))) {
            imagefilledrectangle($canvas, $sidebarX, $y, $width, min($height, $y + $this->sy(9, $height)), $secondary);
        }

        $qrSize = max(24, $this->sx(58, $width));
        $qrX = max($this->sx(360, $width), $sidebarX - $this->sx(76, $width));
        $qrY = $this->sy(39, $height);
        $this->drawBrandingSlot(
            $canvas,
            $assetSet->logo_qr_storage_path,
            $qrX,
            $qrY,
            $qrSize,
            $qrSize,
            'logo_qr:'.$localStock->partner_id,
            $primary,
            $secondary,
        );

        $bottomX = $this->sx(210, $width);
        $bottomY = $height - $this->sy(68, $height);
        $bottomW = max(48, $sidebarX - $bottomX - $this->sx(14, $width));
        $bottomH = max(18, $this->sy(34, $height));
        $this->drawBrandingSlot(
            $canvas,
            $assetSet->logo_bottom_storage_path,
            $bottomX,
            $bottomY,
            $bottomW,
            $bottomH,
            'logo_bottom:'.$localStock->partner_id,
            $secondary,
            $ink,
        );

        $this->drawBrandingSlot(
            $canvas,
            $assetSet->right_sidebar_storage_path,
            $sidebarX + $this->sx(7, $width),
            $this->sy(12, $height),
            max(12, $sidebarWidth - $this->sx(14, $width)),
            $height - $this->sy(24, $height),
            'right_sidebar:'.$localStock->partner_id,
            $primary,
            $white,
        );

        imagefilledrectangle($canvas, $this->sx(55, $width), $height - $this->sy(48, $height), $this->sx(188, $width), $height - $this->sy(26, $height), $soft);
        $this->drawCenteredText($canvas, 'PARTNER '.substr((string) $localStock->partner_id, -8), $this->sx(121, $width), $height - $this->sy(31, $height), max(6, $this->sy(9, $height)), $white);
    }

    private function drawBrandingSlot(mixed $canvas, ?string $storagePath, int $x, int $y, int $width, int $height, string $fallbackSeed, int $primary, int $secondary): void
    {
        $asset = $this->loadStorageImage($storagePath);

        if ($asset !== null) {
            try {
                $this->copyContain($asset, $canvas, $x, $y, $width, $height);

                return;
            } finally {
                imagedestroy($asset);
            }
        }

        imagefilledrectangle($canvas, $x, $y, $x + $width, $y + $height, imagecolorallocatealpha($canvas, 255, 255, 255, 22));
        imagerectangle($canvas, $x, $y, $x + $width, $y + $height, $primary);

        $hash = hash('sha256', $fallbackSeed.':'.(string) $storagePath);
        $cell = max(3, (int) floor(min($width, $height) / 7));

        for ($row = 0; $row < 7; $row++) {
            for ($column = 0; $column < 7; $column++) {
                $offset = ($row * 7 + $column) % strlen($hash);

                if (hexdec($hash[$offset]) % 2 === 0) {
                    $left = $x + 3 + ($column * $cell);
                    $top = $y + 3 + ($row * $cell);
                    imagefilledrectangle($canvas, $left, $top, min($x + $width - 3, $left + $cell - 1), min($y + $height - 3, $top + $cell - 1), $secondary);
                }
            }
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

    private function copyContain(mixed $source, mixed $target, int $x, int $y, int $width, int $height): void
    {
        $sourceWidth = imagesx($source);
        $sourceHeight = imagesy($source);

        if ($sourceWidth <= 0 || $sourceHeight <= 0) {
            return;
        }

        $scale = min($width / $sourceWidth, $height / $sourceHeight);
        $targetWidth = max(1, (int) round($sourceWidth * $scale));
        $targetHeight = max(1, (int) round($sourceHeight * $scale));
        $targetX = $x + (int) floor(($width - $targetWidth) / 2);
        $targetY = $y + (int) floor(($height - $targetHeight) / 2);

        imagecopyresampled($target, $source, $targetX, $targetY, 0, 0, $targetWidth, $targetHeight, $sourceWidth, $sourceHeight);
    }

    /**
     * @return array{accent: int, dark: int, digit: int}
     */
    private function setPalette(mixed $canvas, string $setType): array
    {
        return match ($setType) {
            'even' => [
                'accent' => imagecolorallocate($canvas, 52, 133, 91),
                'dark' => imagecolorallocate($canvas, 22, 78, 59),
                'digit' => imagecolorallocate($canvas, 24, 85, 64),
            ],
            'charity' => [
                'accent' => imagecolorallocate($canvas, 219, 148, 33),
                'dark' => imagecolorallocate($canvas, 119, 67, 21),
                'digit' => imagecolorallocate($canvas, 130, 66, 17),
            ],
            default => [
                'accent' => imagecolorallocate($canvas, 190, 59, 98),
                'dark' => imagecolorallocate($canvas, 90, 42, 73),
                'digit' => imagecolorallocate($canvas, 116, 47, 78),
            ],
        };
    }

    private function sx(int $value, int $width): int
    {
        return (int) round($value * $width / 500);
    }

    private function sy(int $value, int $height): int
    {
        return (int) round($value * $height / 280);
    }

    private function normalizedTicketNumber(string $number): string
    {
        $digits = preg_replace('/\D+/', '', $number) ?: '0';

        return str_pad(substr($digits, -6), 6, '0', STR_PAD_LEFT);
    }

    private function drawSevenSegmentNumber(mixed $canvas, string $digits, int $width, int $height, int $color, int $muted): void
    {
        $digitWidth = max(20, $this->sx(44, $width));
        $digitHeight = max(38, $this->sy(76, $height));
        $gap = max(4, $this->sx(8, $width));
        $totalWidth = (strlen($digits) * $digitWidth) + ((strlen($digits) - 1) * $gap);
        $x = max($this->sx(42, $width), (int) floor(($width - $totalWidth) / 2));
        $y = $this->sy(77, $height);

        foreach (str_split($digits) as $digit) {
            $this->drawSevenSegmentDigit($canvas, $digit, $x, $y, $digitWidth, $digitHeight, $color, $muted);
            $x += $digitWidth + $gap;
        }
    }

    private function drawSevenSegmentDigit(mixed $canvas, string $digit, int $x, int $y, int $width, int $height, int $color, int $muted): void
    {
        $thickness = max(3, (int) round(min($width, $height) * 0.16));
        $middleTop = $y + (int) floor(($height - $thickness) / 2);
        $middleBottom = $middleTop + $thickness;
        $segments = [
            'a' => [$x + $thickness, $y, $x + $width - $thickness, $y + $thickness],
            'b' => [$x + $width - $thickness, $y + $thickness, $x + $width, $middleTop],
            'c' => [$x + $width - $thickness, $middleBottom, $x + $width, $y + $height - $thickness],
            'd' => [$x + $thickness, $y + $height - $thickness, $x + $width - $thickness, $y + $height],
            'e' => [$x, $middleBottom, $x + $thickness, $y + $height - $thickness],
            'f' => [$x, $y + $thickness, $x + $thickness, $middleTop],
            'g' => [$x + $thickness, $middleTop, $x + $width - $thickness, $middleBottom],
        ];
        $active = match ($digit) {
            '0' => ['a', 'b', 'c', 'd', 'e', 'f'],
            '1' => ['b', 'c'],
            '2' => ['a', 'b', 'g', 'e', 'd'],
            '3' => ['a', 'b', 'g', 'c', 'd'],
            '4' => ['f', 'g', 'b', 'c'],
            '5' => ['a', 'f', 'g', 'c', 'd'],
            '6' => ['a', 'f', 'g', 'e', 'c', 'd'],
            '7' => ['a', 'b', 'c'],
            '8' => ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
            '9' => ['a', 'b', 'c', 'd', 'f', 'g'],
            default => [],
        };

        foreach ($segments as $name => $coordinates) {
            imagefilledrectangle($canvas, $coordinates[0], $coordinates[1], $coordinates[2], $coordinates[3], in_array($name, $active, true) ? $color : $muted);
        }
    }

    private function drawBadge(mixed $canvas, string $text, int $x, int $y, int $width, int $height, int $background, int $ink): void
    {
        imagefilledrectangle($canvas, $x, $y, $x + $width, $y + $height, $background);
        imagerectangle($canvas, $x, $y, $x + $width, $y + $height, $ink);
        $this->drawCenteredText($canvas, $text, $x + (int) floor($width / 2), $y + (int) floor($height * 0.72), max(6, (int) floor($height * 0.45)), $ink);
    }

    private function drawFixtureMarks(mixed $canvas, int $width, int $height, int $accent, int $dark): void
    {
        $radius = max(4, $this->sx(9, $width));
        $x = $this->sx(184, $width);
        $y = $this->sy(61, $height);

        for ($index = 0; $index < 4; $index++) {
            $color = $index % 2 === 0 ? $accent : $dark;
            imagefilledellipse($canvas, $x + ($index * $this->sx(33, $width)), $y, $radius, $radius, $color);
        }
    }

    private function drawCenteredText(mixed $canvas, string $text, int $centerX, int $baselineY, int $size, int $color): void
    {
        $font = $this->fontPath();

        if ($font !== null && function_exists('imagettftext')) {
            $box = imagettfbbox($size, 0, $font, $text);

            if (is_array($box)) {
                $textWidth = abs($box[2] - $box[0]);
                imagettftext($canvas, $size, 0, $centerX - (int) floor($textWidth / 2), $baselineY, $color, $font, $text);

                return;
            }
        }

        $builtInFont = $size >= 12 ? 5 : ($size >= 9 ? 4 : 3);
        $textWidth = imagefontwidth($builtInFont) * strlen($text);
        $textHeight = imagefontheight($builtInFont);

        imagestring($canvas, $builtInFont, $centerX - (int) floor($textWidth / 2), $baselineY - $textHeight, $text, $color);
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

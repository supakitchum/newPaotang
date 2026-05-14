<?php

namespace App\Modules\CentralStock\Services;

use App\Models\LocalStockItem;
use App\Models\PartnerLotteryBrandingAssetSet;
use App\Models\StockItem;
use Illuminate\Support\Facades\Storage;

class LotteryImageGenerator
{
    private const SET_TYPES = ['odd', 'even', 'charity'];

    /**
     * @param array<int, string> $stockIds
     * @return array<string, array{background_set_type: string, background_asset_version: string, background_asset_index: int, image_generation_status: string, image_generation_error: string|null}>
     */
    public function assignmentsForStockIds(string $gameId, string $batchId, array $stockIds, ?string $seedExtra = null): array
    {
        $sequence = $this->backgroundSequence(count($stockIds), $gameId.':'.$batchId.':'.($seedExtra ?? ''));
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
        return $this->webpBytes([
            'scope' => 'central',
            'variant' => $variant,
            'game_id' => (string) $stock->game_id,
            'batch_id' => (string) $stock->batch_id,
            'stock_item_id' => (string) $stock->id,
            'full_number' => (string) $stock->full_number,
            'background_set_type' => (string) $stock->background_set_type,
            'background_asset_version' => (string) $stock->background_asset_version,
            'background_asset_index' => (int) $stock->background_asset_index,
            'dimensions' => config('lottery_images.dimensions.'.$variant, []),
            'branding' => null,
        ]);
    }

    public function renderPartnerImage(LocalStockItem $localStock, StockItem $stock, PartnerLotteryBrandingAssetSet $assetSet, string $variant): string
    {
        return $this->webpBytes([
            'scope' => 'partner',
            'variant' => $variant,
            'partner_id' => (string) $localStock->partner_id,
            'tenant_id' => (string) $localStock->tenant_id,
            'game_id' => (string) $localStock->game_id,
            'batch_id' => (string) $stock->batch_id,
            'stock_item_id' => (string) $stock->id,
            'local_stock_item_id' => (string) $localStock->id,
            'full_number' => (string) $localStock->full_number,
            'background_set_type' => (string) $stock->background_set_type,
            'background_asset_version' => (string) $stock->background_asset_version,
            'background_asset_index' => (int) $stock->background_asset_index,
            'dimensions' => config('lottery_images.dimensions.'.$variant, []),
            'branding' => [
                'version' => (string) $assetSet->version,
                'logo_qr_storage_path' => $assetSet->logo_qr_storage_path,
                'right_sidebar_storage_path' => $assetSet->right_sidebar_storage_path,
                'logo_bottom_storage_path' => $assetSet->logo_bottom_storage_path,
            ],
        ]);
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

    /**
     * @return array<int, string>
     */
    private function backgroundSequence(int $count, string $seed): array
    {
        if ($count <= 0) {
            return [];
        }

        $remaining = $this->mixCounts($count);
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
    private function mixCounts(int $count): array
    {
        $weights = config('lottery_images.background_mix', ['odd' => 45, 'even' => 45, 'charity' => 10]);
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
        $directory = rtrim((string) config('lottery_images.asset_root'), '/').'/games/'.$gameId.'/backgrounds/'.$version.'/'.$setType;

        if (! is_dir($directory)) {
            return [];
        }

        $files = [];

        foreach (['webp', 'png', 'jpg', 'jpeg'] as $extension) {
            $files = array_merge($files, glob($directory.'/*.'.$extension) ?: []);
        }

        sort($files, SORT_NATURAL);

        return array_values($files);
    }

    private function minimumBackgroundCount(string $setType): int
    {
        return max(1, (int) config('lottery_images.background_min_counts.'.$setType, 1));
    }

    private function deterministicRank(string $seed, int $position, string $type): int
    {
        return (int) hexdec(substr(hash('sha256', $seed.':'.$position.':'.$type), 0, 8));
    }

    /**
     * @param array<string, mixed> $metadata
     */
    private function webpBytes(array $metadata): string
    {
        $base = base64_decode('UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA', true);
        $payload = json_encode($metadata, JSON_THROW_ON_ERROR);
        $chunkPayload = $payload.(strlen($payload) % 2 === 1 ? "\0" : '');
        $chunk = 'XMP '.pack('V', strlen($payload)).$chunkPayload;

        return substr($base, 0, 4).pack('V', strlen($base) - 8 + strlen($chunk)).substr($base, 8).$chunk;
    }
}

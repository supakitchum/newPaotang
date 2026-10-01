<?php

namespace App\Modules\PartnerStore\Services;

use App\Models\LocalStockItem;
use App\Models\PartnerLotteryBrandingAssetSet;
use App\Models\StockItem;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use App\Support\PublicUrl;

class VirtualLotteryImageService
{
    private const TOKEN_VERSION = 1;
    private const VARIANTS = ['thumb', 'full'];

    /**
     * @var array<string, array{url: ?string, status: string, error: ?string}>
     */
    private array $previewDescriptorCache = [];

    /**
     * @var array<string, PartnerLotteryBrandingAssetSet|null>
     */
    private array $activePartnerAssetSetCache = [];

    public function __construct(
        private readonly LotteryImageGenerator $images,
        private readonly RuntimeStorageService $storage,
    )
    {
    }

    /**
     * @return array{url: ?string, status: string, error: ?string}
     */
    public function previewDescriptor(string $tenantId, string $partnerId, string $gameId, string $fullNumber, int $copyIndex, string $variant = 'thumb'): array
    {
        $cacheKey = implode('|', [$tenantId, $partnerId, $gameId, $fullNumber, $copyIndex, $variant]);

        if (array_key_exists($cacheKey, $this->previewDescriptorCache)) {
            return $this->previewDescriptorCache[$cacheKey];
        }

        if (! $this->images->enabled()) {
            return $this->previewDescriptorCache[$cacheKey] = ['url' => null, 'status' => 'skipped', 'error' => 'lottery_image_generation_disabled'];
        }

        if (! in_array($variant, self::VARIANTS, true)) {
            return $this->previewDescriptorCache[$cacheKey] = ['url' => null, 'status' => 'failed', 'error' => 'lottery_image_variant_unknown:'.$variant];
        }

        $context = $this->renderContext($tenantId, $partnerId, $gameId, $fullNumber, $copyIndex);

        if (($context['error'] ?? null) !== null) {
            return $this->previewDescriptorCache[$cacheKey] = ['url' => null, 'status' => 'pending_assets', 'error' => (string) $context['error']];
        }

        return $this->previewDescriptorCache[$cacheKey] = [
            'url' => $this->publicRouteUrl($this->signedToken($this->imagePayload($context, 'preview', $variant))),
            'status' => 'ready',
            'error' => null,
        ];
    }

    /**
     * @return array{bytes?: string, status: int, error?: string, headers?: array<string, string>}
     */
    public function renderPublicImage(string $token): array
    {
        $payload = $this->decodeToken($token);

        if ($payload === null || ($payload['mode'] ?? null) !== 'preview') {
            return ['status' => 404, 'error' => 'image_not_found'];
        }

        $variant = (string) ($payload['variant'] ?? '');

        if (! in_array($variant, self::VARIANTS, true)) {
            return ['status' => 404, 'error' => 'image_not_found'];
        }

        $context = $this->renderContext(
            (string) ($payload['tenant_id'] ?? ''),
            (string) ($payload['partner_id'] ?? ''),
            (string) ($payload['game_id'] ?? ''),
            (string) ($payload['full_number'] ?? ''),
            (int) ($payload['copy_index'] ?? 0),
            (string) ($payload['brand_asset_set_id'] ?? ''),
        );

        if (($context['error'] ?? null) !== null) {
            return ['status' => 404, 'error' => (string) $context['error']];
        }

        $key = $this->cacheObjectKey($payload);

        if (! $this->storage->exists(RuntimeStorageService::ROUTE_LOTTERY_IMAGES, $key)) {
            try {
                $bytes = $this->renderBytes($context, $variant);
                $this->images->storeObject($key, $bytes);
            } catch (\Throwable $exception) {
                return ['status' => 404, 'error' => substr($exception->getMessage(), 0, 200)];
            }
        }

        return [
            'bytes' => $this->storage->get(RuntimeStorageService::ROUTE_LOTTERY_IMAGES, $key),
            'status' => 200,
            'headers' => [
                'Content-Type' => (string) config('lottery_images.content_type', 'image/webp'),
                'Cache-Control' => (string) config('lottery_images.cache_control', 'public, max-age=31536000, immutable'),
            ],
        ];
    }

    /**
     * @return array{image_url: ?string, image_thumb_url: ?string, image_storage_path: ?string, image_thumb_storage_path: ?string, snapshot: array<string, mixed>}
     */
    public function renderSoldTicketImages(string $ticketId, object $localStock): array
    {
        $fallback = [
            'image_url' => $localStock->image_url ?? null,
            'image_thumb_url' => $localStock->image_thumb_url ?? null,
            'image_storage_path' => $localStock->image_storage_path ?? null,
            'image_thumb_storage_path' => $localStock->image_thumb_storage_path ?? null,
            'snapshot' => [],
        ];

        if (($localStock->virtual_stock_ref ?? null) === null || ! $this->images->enabled()) {
            return $fallback;
        }

        $context = $this->renderContext(
            (string) $localStock->tenant_id,
            (string) $localStock->partner_id,
            (string) $localStock->game_id,
            (string) $localStock->full_number,
            (int) ($localStock->virtual_copy_index ?? 0),
        );
        $snapshot = $this->snapshot($context, (string) ($localStock->virtual_stock_ref ?? ''), $ticketId);

        if (($context['error'] ?? null) !== null) {
            $snapshot['render_status'] = 'failed';
            $snapshot['render_error'] = (string) $context['error'];

            return array_replace($fallback, ['snapshot' => $snapshot]);
        }

        try {
            $fullKey = $this->soldObjectKey((string) $localStock->game_id, $ticketId, 'full');
            $thumbKey = $this->soldObjectKey((string) $localStock->game_id, $ticketId, 'thumb');

            $this->images->storeObject($fullKey, $this->renderBytes($context, 'full', soldWatermark: true));
            $this->images->storeObject($thumbKey, $this->renderBytes($context, 'thumb', soldWatermark: true));

            $result = [
                'image_url' => $this->images->publicUrl($fullKey),
                'image_thumb_url' => $this->images->publicUrl($thumbKey),
                'image_storage_path' => $fullKey,
                'image_thumb_storage_path' => $thumbKey,
                'snapshot' => $snapshot + [
                    'render_status' => 'generated',
                    'image_storage_path' => $fullKey,
                    'image_thumb_storage_path' => $thumbKey,
                ],
            ];

            LocalStockItem::query()->whereKey((string) $localStock->id)->update([
                'image_url' => $result['image_url'],
                'image_thumb_url' => $result['image_thumb_url'],
                'image_storage_path' => $result['image_storage_path'],
                'image_thumb_storage_path' => $result['image_thumb_storage_path'],
                'image_generation_status' => 'generated',
                'image_generation_error' => null,
                'image_generated_at' => now(),
                'updated_at' => now(),
            ]);

            return $result;
        } catch (\Throwable $exception) {
            $snapshot['render_status'] = 'failed';
            $snapshot['render_error'] = substr($exception->getMessage(), 0, 200);

            return array_replace($fallback, ['snapshot' => $snapshot]);
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function renderContext(string $tenantId, string $partnerId, string $gameId, string $fullNumber, int $copyIndex, string $assetSetId = ''): array
    {
        if ($tenantId === '' || $partnerId === '' || $gameId === '' || preg_match('/^[0-9]{6}$/', $fullNumber) !== 1) {
            return ['error' => 'virtual_stock_ref_invalid'];
        }

        $stockRef = $this->virtualRef($tenantId, $gameId, $fullNumber, $copyIndex);
        $stockId = $this->stableId('stk', $stockRef);
        $assignment = $this->images->assignmentsForStockIds($gameId, 'virtual', [$stockId], $stockRef)[$stockId] ?? null;

        if (! is_array($assignment) || ! $this->images->backgroundReady(
            $gameId,
            (string) ($assignment['background_asset_version'] ?? ''),
            (string) ($assignment['background_set_type'] ?? ''),
            (int) ($assignment['background_asset_index'] ?? 0),
        )) {
            return ['error' => (string) ($assignment['image_generation_error'] ?? 'background_set_not_ready')];
        }

        $assetSet = $assetSetId === ''
            ? $this->activePartnerAssetSet($partnerId)
            : PartnerLotteryBrandingAssetSet::query()->whereKey($assetSetId)->where('partner_id', $partnerId)->first();

        if ($assetSet === null) {
            return ['error' => 'partner_branding_assets_not_ready'];
        }

        return [
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'game_id' => $gameId,
            'full_number' => $fullNumber,
            'copy_index' => $copyIndex,
            'stock_ref' => $stockRef,
            'stock_id' => $stockId,
            'assignment' => $assignment,
            'asset_set' => $assetSet,
            'brand_hash' => $this->assetSetHash($assetSet),
            'background_hash' => substr(hash('sha256', json_encode($assignment, JSON_THROW_ON_ERROR)), 0, 16),
        ];
    }

    private function activePartnerAssetSet(string $partnerId): ?PartnerLotteryBrandingAssetSet
    {
        if (! array_key_exists($partnerId, $this->activePartnerAssetSetCache)) {
            $this->activePartnerAssetSetCache[$partnerId] = $this->images->activePartnerAssetSet($partnerId);
        }

        return $this->activePartnerAssetSetCache[$partnerId];
    }

    /**
     * @param array<string, mixed> $context
     */
    private function renderBytes(array $context, string $variant, bool $soldWatermark = false): string
    {
        return $this->images->renderPartnerImage(
            $this->localModel($context),
            $this->stockModel($context),
            $context['asset_set'],
            $variant,
            soldWatermark: $soldWatermark,
        );
    }

    /**
     * @param array<string, mixed> $context
     */
    private function stockModel(array $context): StockItem
    {
        $assignment = $context['assignment'];

        return new StockItem([
            'id' => (string) $context['stock_id'],
            'game_id' => (string) $context['game_id'],
            'batch_id' => 'virtual',
            'full_number' => (string) $context['full_number'],
            'front3' => substr((string) $context['full_number'], 0, 3),
            'back3' => substr((string) $context['full_number'], -3),
            'back2' => substr((string) $context['full_number'], -2),
            'status' => 'allocated',
            'partner_id' => (string) $context['partner_id'],
            'tenant_id' => (string) $context['tenant_id'],
            'virtual_stock_ref' => (string) $context['stock_ref'],
            'virtual_copy_index' => (int) $context['copy_index'],
            'background_set_type' => (string) $assignment['background_set_type'],
            'background_asset_version' => (string) $assignment['background_asset_version'],
            'background_asset_index' => (int) $assignment['background_asset_index'],
        ]);
    }

    /**
     * @param array<string, mixed> $context
     */
    private function localModel(array $context): LocalStockItem
    {
        return new LocalStockItem([
            'id' => $this->stableId('lsi', (string) $context['tenant_id'].':'.(string) $context['stock_ref']),
            'tenant_id' => (string) $context['tenant_id'],
            'partner_id' => (string) $context['partner_id'],
            'store_id' => (string) $context['tenant_id'],
            'game_id' => (string) $context['game_id'],
            'stock_item_id' => (string) $context['stock_id'],
            'virtual_stock_ref' => (string) $context['stock_ref'],
            'virtual_copy_index' => (int) $context['copy_index'],
            'full_number' => (string) $context['full_number'],
            'front3' => substr((string) $context['full_number'], 0, 3),
            'back3' => substr((string) $context['full_number'], -3),
            'back2' => substr((string) $context['full_number'], -2),
            'status' => 'available',
        ]);
    }

    /**
     * @param array<string, mixed> $context
     * @return array<string, mixed>
     */
    private function imagePayload(array $context, string $mode, string $variant): array
    {
        /** @var PartnerLotteryBrandingAssetSet $assetSet */
        $assetSet = $context['asset_set'];

        return [
            'v' => self::TOKEN_VERSION,
            'mode' => $mode,
            'variant' => $variant,
            'tenant_id' => (string) $context['tenant_id'],
            'partner_id' => (string) $context['partner_id'],
            'game_id' => (string) $context['game_id'],
            'full_number' => (string) $context['full_number'],
            'copy_index' => (int) $context['copy_index'],
            'brand_asset_set_id' => (string) $assetSet->id,
            'brand_hash' => (string) $context['brand_hash'],
            'background_hash' => (string) $context['background_hash'],
        ];
    }

    /**
     * @param array<string, mixed> $context
     * @return array<string, mixed>
     */
    private function snapshot(array $context, string $stockRef, string $ticketId): array
    {
        $assetSet = $context['asset_set'] ?? null;

        return [
            'ticket_id' => $ticketId,
            'virtual_stock_ref' => $stockRef,
            'tenant_id' => $context['tenant_id'] ?? null,
            'partner_id' => $context['partner_id'] ?? null,
            'game_id' => $context['game_id'] ?? null,
            'full_number' => $context['full_number'] ?? null,
            'copy_index' => $context['copy_index'] ?? null,
            'background_assignment' => $context['assignment'] ?? null,
            'branding' => $assetSet instanceof PartnerLotteryBrandingAssetSet ? [
                'asset_set_id' => (string) $assetSet->id,
                'version' => (string) $assetSet->version,
                'logo_qr_storage_path' => $assetSet->logo_qr_storage_path,
                'right_sidebar_storage_path' => $assetSet->right_sidebar_storage_path,
                'logo_bottom_storage_path' => $assetSet->logo_bottom_storage_path,
                'brand_hash' => $this->assetSetHash($assetSet),
            ] : null,
            'layout_hash' => substr(hash('sha256', json_encode($this->images->layout(), JSON_THROW_ON_ERROR)), 0, 16),
            'rendered_at' => now()->toISOString(),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function cacheObjectKey(array $payload): string
    {
        $prefix = trim((string) config('lottery_images.object_prefix', 'lotteries'), '/');
        $hash = substr(hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR)), 0, 24);

        return implode('/', [
            $prefix,
            'cache',
            'virtual',
            'tenants',
            (string) $payload['tenant_id'],
            'games',
            (string) $payload['game_id'],
            'partners',
            (string) $payload['partner_id'],
            (string) $payload['full_number'],
            (string) $payload['copy_index'],
            (string) $payload['brand_hash'].'-'.(string) $payload['background_hash'].'-'.$hash,
            (string) $payload['variant'].'.webp',
        ]);
    }

    private function soldObjectKey(string $gameId, string $ticketId, string $variant): string
    {
        $prefix = trim((string) config('lottery_images.object_prefix', 'lotteries'), '/');

        return $prefix.'/'.$gameId.'/sold-tickets/'.$ticketId.'/'.$variant.'.webp';
    }

    private function publicRouteUrl(string $token): string
    {
        return PublicUrl::absolute(rtrim((string) config('app.url', 'http://localhost'), '/').'/api/v1/public/stock/images/'.$token.'.webp');
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function signedToken(array $payload): string
    {
        ksort($payload);

        $body = $this->base64UrlEncode(json_encode($payload, JSON_THROW_ON_ERROR));
        $signature = $this->base64UrlEncode(hash_hmac('sha256', $body, $this->tokenSecret(), true));

        return $signature.'~'.$body;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function decodeToken(string $token): ?array
    {
        [$signature, $body] = array_pad(explode('~', $token, 2), 2, '');

        if ($signature === '' || $body === '') {
            return null;
        }

        $expected = $this->base64UrlEncode(hash_hmac('sha256', $body, $this->tokenSecret(), true));

        if (! hash_equals($expected, $signature)) {
            return null;
        }

        $decoded = json_decode($this->base64UrlDecode($body), true);

        return is_array($decoded) && (int) ($decoded['v'] ?? 0) === self::TOKEN_VERSION ? $decoded : null;
    }

    private function tokenSecret(): string
    {
        $key = (string) config('app.key', '');

        return $key !== '' ? $key : 'newpaotang-local-virtual-image-secret';
    }

    private function base64UrlEncode(string $bytes): string
    {
        return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
    }

    private function base64UrlDecode(string $value): string
    {
        $padding = strlen($value) % 4;

        if ($padding > 0) {
            $value .= str_repeat('=', 4 - $padding);
        }

        $decoded = base64_decode(strtr($value, '-_', '+/'), true);

        return is_string($decoded) ? $decoded : '';
    }

    private function assetSetHash(PartnerLotteryBrandingAssetSet $assetSet): string
    {
        return substr(hash('sha256', json_encode([
            'id' => (string) $assetSet->id,
            'version' => (string) $assetSet->version,
            'logo_qr' => $assetSet->logo_qr_storage_path,
            'right_sidebar' => $assetSet->right_sidebar_storage_path,
            'logo_bottom' => $assetSet->logo_bottom_storage_path,
            'updated_at' => $assetSet->updated_at?->toISOString(),
        ], JSON_THROW_ON_ERROR)), 0, 16);
    }

    private function virtualRef(string $tenantId, string $gameId, string $fullNumber, int $copyIndex): string
    {
        return 'vstock:'.$tenantId.':'.$gameId.':'.$fullNumber.':'.$copyIndex;
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
}

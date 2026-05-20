<?php

namespace App\Modules\CentralStock\Services;

use App\Models\LocalStockItem;
use App\Models\Partner;
use App\Models\PartnerLotteryBrandingAssetSet;
use App\Models\PlatformAsset;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PartnerLotteryBrandingAssetService
{
    private const ASSET_FIELDS = [
        'logo_qr' => 'logo_qr_asset_id',
        'right_sidebar' => 'right_sidebar_asset_id',
        'logo_bottom' => 'logo_bottom_asset_id',
    ];

    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @return array<string, mixed>|null
     */
    public function find(string $partnerId): ?array
    {
        if (! Partner::query()->whereKey($partnerId)->exists()) {
            return null;
        }

        $assetSet = $this->currentAssetSet($partnerId);

        return $this->resource($partnerId, $assetSet);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function upsert(string $partnerId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        if (! Partner::query()->whereKey($partnerId)->exists()) {
            return ['error' => 'not_found'];
        }

        $generatedImageCount = $this->generatedImageCount($partnerId);

        if ($generatedImageCount > 0) {
            return ['error' => 'resource_conflict'];
        }

        $normalized = $this->normalizedPayload($payload);
        $errors = $this->validationErrors($normalized);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($partnerId, $normalized, $payload, $actor, $request): array {
            $generatedImageCount = $this->generatedImageCount($partnerId);

            if ($generatedImageCount > 0) {
                return ['error' => 'resource_conflict'];
            }

            $assets = $this->assetsById([
                $normalized['logo_qr_asset_id'],
                $normalized['right_sidebar_asset_id'],
                $normalized['logo_bottom_asset_id'],
            ]);

            $now = now();
            $version = $normalized['version'];
            $existing = PartnerLotteryBrandingAssetSet::query()
                ->where('partner_id', $partnerId)
                ->where('version', $version)
                ->lockForUpdate()
                ->first();

            $assetSetId = $existing?->id ?? 'pba_'.Str::ulid()->toBase32();

            PartnerLotteryBrandingAssetSet::query()->updateOrCreate(
                ['id' => $assetSetId],
                [
                    'partner_id' => $partnerId,
                    'version' => $version,
                    'status' => 'ready',
                    'logo_qr_asset_id' => $normalized['logo_qr_asset_id'],
                    'right_sidebar_asset_id' => $normalized['right_sidebar_asset_id'],
                    'logo_bottom_asset_id' => $normalized['logo_bottom_asset_id'],
                    'logo_qr_storage_path' => $assets[$normalized['logo_qr_asset_id']]->storage_key,
                    'right_sidebar_storage_path' => $assets[$normalized['right_sidebar_asset_id']]->storage_key,
                    'logo_bottom_storage_path' => $assets[$normalized['logo_bottom_asset_id']]->storage_key,
                    'uploaded_by_admin_id' => $actor->adminUser['id'],
                    'activated_at' => $now,
                    'locked_at' => null,
                    'created_at' => $existing?->created_at ?? $now,
                    'updated_at' => $now,
                ],
            );

            $this->auditLogger->logAdminWrite(
                actorId: (string) $actor->adminUser['id'],
                scopeType: 'central',
                action: 'partner_lottery_branding_assets.updated',
                targetType: 'partner_lottery_branding_asset_set',
                targetId: $assetSetId,
                payload: [
                    'partner_id' => $partnerId,
                    'payload' => $payload,
                    'idempotency_key' => $request->header('Idempotency-Key'),
                ],
                tenantId: null,
                partnerId: $partnerId,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return ['resource' => $this->resource($partnerId, PartnerLotteryBrandingAssetSet::query()->whereKey($assetSetId)->first())];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function normalizedPayload(array $payload): array
    {
        $assets = is_array($payload['assets'] ?? null) ? $payload['assets'] : [];

        return [
            'version' => trim((string) ($payload['version'] ?? 'v1')),
            'logo_qr_asset_id' => $this->assetId($payload, $assets, 'logo_qr'),
            'right_sidebar_asset_id' => $this->assetId($payload, $assets, 'right_sidebar'),
            'logo_bottom_asset_id' => $this->assetId($payload, $assets, 'logo_bottom'),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $assets
     */
    private function assetId(array $payload, array $assets, string $key): ?string
    {
        $directKey = self::ASSET_FIELDS[$key];

        if (isset($payload[$directKey])) {
            return trim((string) $payload[$directKey]);
        }

        if (is_array($assets[$key] ?? null) && isset($assets[$key]['asset_id'])) {
            return trim((string) $assets[$key]['asset_id']);
        }

        return null;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function validationErrors(array $payload): array
    {
        $errors = [];

        if ($payload['version'] === '' || strlen((string) $payload['version']) > 64 || preg_match('/^[A-Za-z0-9._-]+$/', (string) $payload['version']) !== 1) {
            $errors['version'][] = 'The version field must be 1-64 characters and may contain letters, numbers, dot, underscore, or dash.';
        }

        foreach (self::ASSET_FIELDS as $logicalName => $field) {
            $assetId = $payload[$field] ?? null;

            if (! is_string($assetId) || $assetId === '') {
                $errors[$field][] = 'The '.$field.' field is required.';
                continue;
            }

            $asset = PlatformAsset::query()
                ->where('id', $assetId)
                ->where('scope_type', 'central')
                ->whereNull('tenant_id')
                ->first();

            if ($asset === null) {
                $errors[$field][] = 'The '.$field.' field must reference an existing central asset.';
                continue;
            }

            if ((string) $asset->status !== 'committed') {
                $errors[$field][] = 'The '.$field.' field must reference a committed asset.';
            }

            if ((string) $asset->purpose !== 'partner_lottery_branding') {
                $errors[$field][] = 'The '.$field.' field must reference a partner lottery branding asset.';
            }

            if (! str_starts_with((string) $asset->content_type, 'image/')) {
                $errors[$field][] = 'The '.$field.' field must reference an image asset.';
            }

            if ((int) $asset->size_bytes > 5242880) {
                $errors[$field][] = 'The '.$field.' asset must not be larger than 5242880 bytes.';
            }

            if ($logicalName === 'right_sidebar' && (int) $asset->size_bytes < 1) {
                $errors[$field][] = 'The right sidebar asset is invalid.';
            }
        }

        return $errors;
    }

    /**
     * @param array<int, string> $assetIds
     * @return array<string, PlatformAsset>
     */
    private function assetsById(array $assetIds): array
    {
        return PlatformAsset::query()
            ->whereIn('id', array_values(array_unique($assetIds)))
            ->get()
            ->keyBy('id')
            ->all();
    }

    private function generatedImageCount(string $partnerId): int
    {
        return LocalStockItem::query()
            ->where('partner_id', $partnerId)
            ->where(function ($query): void {
                $query->where('image_generation_status', 'generated')
                    ->orWhereNotNull('image_generated_at')
                    ->orWhereNotNull('image_url');
            })
            ->count();
    }

    private function currentAssetSet(string $partnerId): ?PartnerLotteryBrandingAssetSet
    {
        return PartnerLotteryBrandingAssetSet::query()
            ->where('partner_id', $partnerId)
            ->orderByDesc('activated_at')
            ->orderByDesc('created_at')
            ->first();
    }

    /**
     * @return array<string, mixed>
     */
    private function resource(string $partnerId, ?PartnerLotteryBrandingAssetSet $assetSet): array
    {
        $generatedImageCount = $this->generatedImageCount($partnerId);
        $locked = $generatedImageCount > 0;
        $assets = $assetSet === null ? [] : $this->assetsById([
            (string) $assetSet->logo_qr_asset_id,
            (string) $assetSet->right_sidebar_asset_id,
            (string) $assetSet->logo_bottom_asset_id,
        ]);

        return [
            'partner_id' => $partnerId,
            'asset_set_id' => $assetSet?->id,
            'version' => $assetSet?->version,
            'status' => $locked ? 'locked' : ($assetSet?->status ?? 'missing'),
            'locked' => $locked,
            'lock_reason' => $locked ? 'partner_images_already_generated' : null,
            'generated_image_count' => $generatedImageCount,
            'assets' => [
                'logo_qr' => $this->assetResource($assetSet?->logo_qr_asset_id, $assets),
                'right_sidebar' => $this->assetResource($assetSet?->right_sidebar_asset_id, $assets),
                'logo_bottom' => $this->assetResource($assetSet?->logo_bottom_asset_id, $assets),
            ],
            'activated_at' => $assetSet?->activated_at?->toISOString(),
            'locked_at' => $locked ? ($assetSet?->locked_at?->toISOString()) : null,
            'updated_at' => $assetSet?->updated_at?->toISOString(),
            'updated_by' => $assetSet?->uploaded_by_admin_id,
        ];
    }

    /**
     * @param array<string, PlatformAsset> $assets
     * @return array<string, mixed>|null
     */
    private function assetResource(?string $assetId, array $assets): ?array
    {
        if ($assetId === null || ! isset($assets[$assetId])) {
            return null;
        }

        $asset = $assets[$assetId];

        return [
            'asset_id' => (string) $asset->id,
            'file_name' => $asset->file_name,
            'content_type' => $asset->content_type,
            'size_bytes' => (int) $asset->size_bytes,
            'storage_path' => $asset->storage_key,
            'url' => $asset->public_url,
            'status' => (string) $asset->status,
        ];
    }
}

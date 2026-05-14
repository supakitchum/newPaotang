<?php

namespace App\Modules\CentralStock\Services;

use App\Jobs\GenerateLotteryImageJob;
use App\Jobs\GeneratePartnerLotteryImageJob;
use App\Models\Game;
use App\Models\LocalStockItem;
use App\Models\LotteryImageBackgroundAssetSet;
use App\Models\LotteryImageMixSetting;
use App\Models\PlatformAsset;
use App\Models\StockItem;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class LotteryImageOperationsService
{
    private const SET_TYPES = ['odd', 'even', 'charity'];
    private const BACKGROUND_STATUSES = ['ready', 'inactive', 'retired'];
    private const ASSET_FIELDS = [
        'source' => 'source_asset_id',
        'full' => 'full_asset_id',
        'thumb' => 'thumb_asset_id',
    ];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly LotteryImageGenerator $images,
    ) {
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listBackgroundSets(array $queryParams): array
    {
        $errors = $this->gameVersionErrors($queryParams);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $gameId = trim((string) $queryParams['game_id']);
        $version = $this->versionFrom($queryParams['version'] ?? null);
        $rows = LotteryImageBackgroundAssetSet::query()
            ->where('game_id', $gameId)
            ->where('version', $version)
            ->orderByRaw("CASE set_type WHEN 'odd' THEN 1 WHEN 'even' THEN 2 WHEN 'charity' THEN 3 ELSE 4 END")
            ->get();

        return [
            'data' => $rows->map(fn (LotteryImageBackgroundAssetSet $row): array => $this->backgroundResource($row))->all(),
            'meta' => [
                'game_id' => $gameId,
                'version' => $version,
                'required_set_types' => self::SET_TYPES,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function upsertBackgroundSet(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $normalized = $this->normalizedBackgroundPayload($payload);
        $errors = $this->backgroundPayloadErrors($normalized);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($normalized, $payload, $actor, $request): array {
            $assets = $this->assetsById(array_values(array_filter([
                $normalized['source_asset_id'],
                $normalized['full_asset_id'],
                $normalized['thumb_asset_id'],
            ])));
            $specs = $this->assetSpecs($assets);
            $now = now();
            $existing = LotteryImageBackgroundAssetSet::query()
                ->where('game_id', $normalized['game_id'])
                ->where('version', $normalized['version'])
                ->where('set_type', $normalized['set_type'])
                ->lockForUpdate()
                ->first();
            $assetSetId = $existing?->id ?? 'lib_'.Str::ulid()->toBase32();
            $status = $normalized['status'] ?? 'ready';

            if (($payload['supersede_existing'] ?? false) === true && $status === 'ready') {
                $this->retireOtherBackgroundVersions($normalized['game_id'], $normalized['set_type'], $normalized['version'], $now);
            }

            LotteryImageBackgroundAssetSet::query()->updateOrCreate(
                ['id' => $assetSetId],
                [
                    'game_id' => $normalized['game_id'],
                    'version' => $normalized['version'],
                    'set_type' => $normalized['set_type'],
                    'status' => $status,
                    'source_asset_id' => $normalized['source_asset_id'],
                    'full_asset_id' => $normalized['full_asset_id'],
                    'thumb_asset_id' => $normalized['thumb_asset_id'],
                    'source_storage_path' => $assets[$normalized['source_asset_id']]->storage_key,
                    'full_storage_path' => $assets[$normalized['full_asset_id']]->storage_key,
                    'thumb_storage_path' => $assets[$normalized['thumb_asset_id']]->storage_key,
                    'source_content_type' => $assets[$normalized['source_asset_id']]->content_type,
                    'full_content_type' => $assets[$normalized['full_asset_id']]->content_type,
                    'thumb_content_type' => $assets[$normalized['thumb_asset_id']]->content_type,
                    'source_width' => $specs[$normalized['source_asset_id']]['width'],
                    'source_height' => $specs[$normalized['source_asset_id']]['height'],
                    'full_width' => $specs[$normalized['full_asset_id']]['width'],
                    'full_height' => $specs[$normalized['full_asset_id']]['height'],
                    'thumb_width' => $specs[$normalized['thumb_asset_id']]['width'],
                    'thumb_height' => $specs[$normalized['thumb_asset_id']]['height'],
                    'source_size_bytes' => (int) $assets[$normalized['source_asset_id']]->size_bytes,
                    'full_size_bytes' => (int) $assets[$normalized['full_asset_id']]->size_bytes,
                    'thumb_size_bytes' => (int) $assets[$normalized['thumb_asset_id']]->size_bytes,
                    'uploaded_by_admin_id' => $actor->adminUser['id'],
                    'activated_at' => $status === 'ready' ? $now : $existing?->activated_at,
                    'retired_at' => $status === 'retired' ? $now : null,
                    'metadata_json' => [
                        'expected_dimensions' => $this->expectedDimensions(),
                        'supersede_existing' => (bool) ($payload['supersede_existing'] ?? false),
                    ],
                    'created_at' => $existing?->created_at ?? $now,
                    'updated_at' => $now,
                ],
            );

            $this->audit($actor, $request, 'lottery_image_background_asset_set.updated', 'lottery_image_background_asset_set', $assetSetId, $payload);

            return [
                'resource' => $this->backgroundResource(LotteryImageBackgroundAssetSet::query()->whereKey($assetSetId)->first()),
            ];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateBackgroundSetStatus(string $assetSetId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $assetSet = LotteryImageBackgroundAssetSet::query()->whereKey($assetSetId)->first();

        if ($assetSet === null) {
            return ['error' => 'not_found'];
        }

        $status = trim((string) ($payload['status'] ?? ''));
        $errors = [];

        if (! in_array($status, self::BACKGROUND_STATUSES, true)) {
            $errors['status'][] = 'The status field must be ready, inactive, or retired.';
        }

        if ($status === 'ready') {
            $missing = $this->missingAssetsForSet($assetSet);

            if ($missing !== []) {
                $errors['assets'][] = 'The background set cannot be activated until all source/full/thumb assets are available.';
            }
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($assetSetId, $status, $payload, $actor, $request): array {
            $assetSet = LotteryImageBackgroundAssetSet::query()->whereKey($assetSetId)->lockForUpdate()->first();

            if ($assetSet === null) {
                return ['error' => 'not_found'];
            }

            $now = now();

            if (($payload['supersede_existing'] ?? false) === true && $status === 'ready') {
                $this->retireOtherBackgroundVersions((string) $assetSet->game_id, (string) $assetSet->set_type, (string) $assetSet->version, $now);
            }

            LotteryImageBackgroundAssetSet::query()->whereKey($assetSetId)->update([
                'status' => $status,
                'activated_at' => $status === 'ready' ? $now : $assetSet->activated_at,
                'retired_at' => $status === 'retired' ? $now : null,
                'uploaded_by_admin_id' => $actor->adminUser['id'],
                'updated_at' => $now,
            ]);

            $this->audit($actor, $request, 'lottery_image_background_asset_set.status_updated', 'lottery_image_background_asset_set', $assetSetId, $payload);

            return [
                'resource' => $this->backgroundResource(LotteryImageBackgroundAssetSet::query()->whereKey($assetSetId)->first()),
            ];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function mix(array $queryParams): array
    {
        $gameId = trim((string) ($queryParams['game_id'] ?? ''));

        if ($gameId === '') {
            return ['error' => 'validation_failed', 'errors' => ['game_id' => ['The game_id field is required.']]];
        }

        if (! Game::query()->whereKey($gameId)->exists()) {
            return ['error' => 'not_found'];
        }

        return $this->mixResource($gameId);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateMix(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $gameId = trim((string) ($payload['game_id'] ?? ''));
        $errors = [];

        if ($gameId === '') {
            $errors['game_id'][] = 'The game_id field is required.';
        } elseif (! Game::query()->whereKey($gameId)->exists()) {
            return ['error' => 'not_found'];
        }

        $mix = is_array($payload['mix'] ?? null) ? $payload['mix'] : $payload;
        $values = [];

        foreach (self::SET_TYPES as $setType) {
            $key = $setType.'_percentage';
            $raw = $mix[$setType] ?? $mix[$key] ?? null;

            if (filter_var($raw, FILTER_VALIDATE_INT) === false) {
                $errors[$key][] = 'The '.$key.' field must be an integer percentage.';
                continue;
            }

            $value = (int) $raw;

            if ($value < 0 || $value > 100) {
                $errors[$key][] = 'The '.$key.' field must be between 0 and 100.';
            }

            $values[$setType] = $value;
        }

        if ($values !== [] && array_sum($values) !== 100) {
            $errors['mix'][] = 'The odd, even, and charity percentages must sum to 100.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($gameId, $values, $payload, $actor, $request): array {
            LotteryImageMixSetting::query()->updateOrCreate(
                ['game_id' => $gameId],
                [
                    'id' => LotteryImageMixSetting::query()->where('game_id', $gameId)->value('id') ?? 'lim_'.Str::ulid()->toBase32(),
                    'odd_percentage' => $values['odd'],
                    'even_percentage' => $values['even'],
                    'charity_percentage' => $values['charity'],
                    'updated_by_admin_id' => $actor->adminUser['id'],
                    'updated_at' => now(),
                    'created_at' => now(),
                ],
            );

            $this->audit($actor, $request, 'lottery_image_mix.updated', 'lottery_image_mix_setting', $gameId, $payload);

            return ['resource' => $this->mixResource($gameId)];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function readiness(array $queryParams): array
    {
        $errors = $this->gameVersionErrors($queryParams, requireVersion: false);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $gameId = trim((string) $queryParams['game_id']);
        $version = $this->versionFrom($queryParams['version'] ?? null);
        $batchId = $this->nullableString($queryParams['batch_id'] ?? null);
        $backgrounds = [];
        $missingSetTypes = [];

        foreach (self::SET_TYPES as $setType) {
            $current = LotteryImageBackgroundAssetSet::query()
                ->where('game_id', $gameId)
                ->where('version', $version)
                ->where('set_type', $setType)
                ->orderByDesc('activated_at')
                ->orderByDesc('updated_at')
                ->first();
            $availableCount = $this->images->backgroundCount($gameId, $version, $setType);
            $minimumCount = $this->images->minimumBackgroundCountFor($setType);
            $ready = $availableCount >= $minimumCount;

            if (! $ready) {
                $missingSetTypes[] = $setType;
            }

            $backgrounds[] = [
                'set_type' => $setType,
                'version' => $version,
                'required_count' => $minimumCount,
                'available_count' => $availableCount,
                'ready' => $ready,
                'asset_set' => $current === null ? null : $this->backgroundResource($current),
            ];
        }

        return [
            'game_id' => $gameId,
            'batch_id' => $batchId,
            'version' => $version,
            'backgrounds' => $backgrounds,
            'missing_set_types' => $missingSetTypes,
            'pending_assets' => $this->statusCounts($gameId, $batchId, $version, 'pending_assets'),
            'failed_generation' => $this->statusCounts($gameId, $batchId, $version, 'failed'),
            'last_error_samples' => $this->lastErrorSamples($gameId, $batchId, $version),
            'mix' => $this->mixResource($gameId),
            'storage_readiness' => $this->productionReadiness(),
            'queue_readiness' => $this->queueReadiness(),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function retryPending(array $payload): array
    {
        $limit = min(1000, max(1, (int) ($payload['limit'] ?? 500)));
        $dryRun = filter_var($payload['dry_run'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $gameId = $this->nullableString($payload['game_id'] ?? null);
        $batchId = $this->nullableString($payload['batch_id'] ?? null);
        $version = $this->nullableString($payload['version'] ?? null);
        $setTypes = $this->setTypesFrom($payload['set_types'] ?? $payload['set_type'] ?? null);

        if ($setTypes === null) {
            return ['error' => 'validation_failed', 'errors' => ['set_types' => ['The set_types field must contain odd, even, or charity values.']]];
        }

        $centralReady = 0;
        $centralDispatched = 0;
        $partnerReady = 0;
        $partnerDispatched = 0;
        $centralQuery = StockItem::query()
            ->where('image_generation_status', 'pending_assets')
            ->orderBy('id')
            ->limit($limit);

        $this->applyPendingFilters($centralQuery, $gameId, $batchId, $version, $setTypes);

        foreach ($centralQuery->get() as $stock) {
            if (! $this->images->backgroundReadyForStock($stock)) {
                continue;
            }

            $centralReady++;

            if (! $dryRun) {
                GenerateLotteryImageJob::dispatch((string) $stock->id);
                $centralDispatched++;
            }
        }

        $localQuery = LocalStockItem::query()
            ->where('image_generation_status', 'pending_assets')
            ->orderBy('id')
            ->limit($limit);

        if ($gameId !== null) {
            $localQuery->where('game_id', $gameId);
        }

        foreach ($localQuery->get() as $localStock) {
            $stock = StockItem::query()->whereKey($localStock->stock_item_id)->first();

            if ($stock === null || ! $this->stockMatchesFilters($stock, $gameId, $batchId, $version, $setTypes)) {
                continue;
            }

            if (! $this->images->backgroundReadyForStock($stock) || $this->images->activePartnerAssetSet((string) $localStock->partner_id) === null) {
                continue;
            }

            $partnerReady++;

            if (! $dryRun) {
                GeneratePartnerLotteryImageJob::dispatch((string) $localStock->id);
                $partnerDispatched++;
            }
        }

        return [
            'dry_run' => $dryRun,
            'limit' => $limit,
            'filters' => [
                'game_id' => $gameId,
                'batch_id' => $batchId,
                'version' => $version,
                'set_types' => $setTypes,
            ],
            'central' => [
                'ready_count' => $centralReady,
                'dispatched_count' => $centralDispatched,
                'queue' => config('lottery_images.queues.central', 'stock-image-generation'),
            ],
            'partner' => [
                'ready_count' => $partnerReady,
                'dispatched_count' => $partnerDispatched,
                'queue' => config('lottery_images.queues.partner', 'stock-partner-image-generation'),
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function productionReadiness(): array
    {
        $disk = (string) config('lottery_images.disk', 'lottery_images');
        $diskConfig = config('filesystems.disks.'.$disk, []);
        $driver = is_array($diskConfig) ? (string) ($diskConfig['driver'] ?? '') : '';
        $queues = $this->queueReadiness();
        $runtimeReady = extension_loaded('gd') && function_exists('imagewebp');
        $configured = (bool) config('lottery_images.enabled', true) && is_array($diskConfig) && $diskConfig !== [];
        $bucketPresent = is_array($diskConfig) && trim((string) ($diskConfig['bucket'] ?? '')) !== '';
        $regionPresent = is_array($diskConfig) && trim((string) ($diskConfig['region'] ?? '')) !== '';
        $endpointPresent = is_array($diskConfig) && trim((string) ($diskConfig['endpoint'] ?? '')) !== '';
        $cdnPresent = trim((string) config('lottery_images.cdn_base_url', '')) !== '';
        $blocking = [];

        if (! $configured) {
            $blocking[] = 'lottery_image_generation_not_configured';
        }
        if ($driver !== 's3') {
            $blocking[] = 'object_storage_disk_not_s3_compatible';
        }
        if (! $bucketPresent) {
            $blocking[] = 'object_storage_bucket_missing';
        }
        if (! $regionPresent) {
            $blocking[] = 'object_storage_region_missing';
        }
        if (! $cdnPresent) {
            $blocking[] = 'cdn_base_url_missing';
        }
        if (! $queues['queue_configured']) {
            $blocking[] = 'lottery_image_queue_not_configured';
        }
        if (! $runtimeReady) {
            $blocking[] = 'gd_webp_runtime_unavailable';
        }

        return [
            'configured' => $configured,
            'disk' => $disk,
            'disk_driver' => $driver === '' ? null : $driver,
            'bucket_present' => $bucketPresent,
            'region_present' => $regionPresent,
            'endpoint_present' => $endpointPresent,
            'cdn_base_url_present' => $cdnPresent,
            'queue_configured' => $queues['queue_configured'],
            'runtime_webp_ready' => $runtimeReady,
            'secrets_redacted' => true,
            'production_ready' => $blocking === [],
            'blocking_reasons' => $blocking,
            'queues' => $queues,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function queueReadiness(): array
    {
        $central = trim((string) config('lottery_images.queues.central', 'stock-image-generation'));
        $partner = trim((string) config('lottery_images.queues.partner', 'stock-partner-image-generation'));
        $connection = trim((string) config('queue.default', ''));
        $connectionConfig = $connection === '' ? null : config('queue.connections.'.$connection);
        $configured = $central !== '' && $partner !== '' && is_array($connectionConfig);

        return [
            'queue_configured' => $configured,
            'jobs_can_run' => $configured && (bool) config('lottery_images.enabled', true),
            'connection' => $connection,
            'required_queue_names' => array_values(array_unique([$central, $partner])),
            'central_queue' => $central,
            'partner_queue' => $partner,
            'worker_commands' => [
                'php artisan queue:work --queue='.$central,
                'php artisan queue:work --queue='.$partner,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function normalizedBackgroundPayload(array $payload): array
    {
        $assets = is_array($payload['assets'] ?? null) ? $payload['assets'] : [];

        return [
            'game_id' => trim((string) ($payload['game_id'] ?? '')),
            'version' => $this->versionFrom($payload['version'] ?? null),
            'set_type' => trim((string) ($payload['set_type'] ?? '')),
            'status' => trim((string) ($payload['status'] ?? 'ready')),
            'source_asset_id' => $this->assetId($payload, $assets, 'source'),
            'full_asset_id' => $this->assetId($payload, $assets, 'full'),
            'thumb_asset_id' => $this->assetId($payload, $assets, 'thumb'),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $assets
     */
    private function assetId(array $payload, array $assets, string $slot): ?string
    {
        $field = self::ASSET_FIELDS[$slot];

        if (isset($payload[$field])) {
            return trim((string) $payload[$field]);
        }

        if (is_array($assets[$slot] ?? null) && isset($assets[$slot]['asset_id'])) {
            return trim((string) $assets[$slot]['asset_id']);
        }

        return null;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function backgroundPayloadErrors(array $payload): array
    {
        $errors = $this->gameVersionErrors($payload);

        if (! in_array($payload['set_type'], self::SET_TYPES, true)) {
            $errors['set_type'][] = 'The set_type field must be odd, even, or charity.';
        }

        if (! in_array($payload['status'], self::BACKGROUND_STATUSES, true)) {
            $errors['status'][] = 'The status field must be ready, inactive, or retired.';
        }

        foreach (self::ASSET_FIELDS as $slot => $field) {
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

            $errors = $this->mergeErrors($errors, $this->assetValidationErrors($slot, $field, $asset));
        }

        return $errors;
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function assetValidationErrors(string $slot, string $field, PlatformAsset $asset): array
    {
        $errors = [];

        if ((string) $asset->status !== 'committed') {
            $errors[$field][] = 'The '.$field.' field must reference a committed asset.';
        }

        $mime = (string) $asset->content_type;
        $allowedSource = config('lottery_images.background_asset_limits.allowed_source_mimes', ['image/webp', 'image/png', 'image/jpeg']);
        $requiredVariant = (string) config('lottery_images.background_asset_limits.required_variant_mime', 'image/webp');

        if ($slot === 'source') {
            if (! in_array($mime, $allowedSource, true)) {
                $errors[$field][] = 'The source asset must be a WebP, PNG, or JPEG image.';
            }
        } elseif ($mime !== $requiredVariant) {
            $errors[$field][] = 'The '.$slot.' asset must be an image/webp asset.';
        }

        $limit = $this->sizeLimitForSlot($slot);

        if ((int) $asset->size_bytes < 1 || (int) $asset->size_bytes > $limit) {
            $errors[$field][] = 'The '.$field.' asset size is outside the allowed limit.';
        }

        $spec = $this->imageSpec($asset);

        if ($spec['width'] === null || $spec['height'] === null) {
            $errors[$field][] = 'The '.$field.' asset must include readable image dimensions.';

            return $errors;
        }

        $expected = $this->expectedDimensions();

        if ($slot === 'source' && ($spec['width'] < $expected['full']['width'] || $spec['height'] < $expected['full']['height'])) {
            $errors[$field][] = 'The source asset dimensions must be at least the full image dimensions.';
        }

        if ($slot === 'full' && ($spec['width'] !== $expected['full']['width'] || $spec['height'] !== $expected['full']['height'])) {
            $errors[$field][] = 'The full asset dimensions must match the configured full dimensions.';
        }

        if ($slot === 'thumb' && ($spec['width'] !== $expected['thumb']['width'] || $spec['height'] !== $expected['thumb']['height'])) {
            $errors[$field][] = 'The thumb asset dimensions must match the configured thumbnail dimensions.';
        }

        return $errors;
    }

    private function sizeLimitForSlot(string $slot): int
    {
        return match ($slot) {
            'source' => (int) config('lottery_images.background_asset_limits.max_source_size_bytes', 10485760),
            'thumb' => (int) config('lottery_images.background_asset_limits.max_thumb_size_bytes', 1048576),
            default => (int) config('lottery_images.background_asset_limits.max_full_size_bytes', 5242880),
        };
    }

    /**
     * @return array<string, array{width: int|null, height: int|null, storage_available: bool}>
     */
    private function assetSpecs(array $assets): array
    {
        $specs = [];

        foreach ($assets as $assetId => $asset) {
            $specs[$assetId] = $this->imageSpec($asset);
        }

        return $specs;
    }

    /**
     * @return array{width: int|null, height: int|null, storage_available: bool}
     */
    private function imageSpec(PlatformAsset $asset): array
    {
        $metadata = is_array($asset->metadata_json) ? $asset->metadata_json : [];
        $width = $this->integerMetadata($metadata, ['width', 'dimensions.width', 'image.width']);
        $height = $this->integerMetadata($metadata, ['height', 'dimensions.height', 'image.height']);
        $storageAvailable = $this->storageExists((string) $asset->storage_key);

        if (($width === null || $height === null) && $storageAvailable) {
            try {
                $bytes = Storage::disk((string) config('lottery_images.disk', 'lottery_images'))->get((string) $asset->storage_key);
                $info = is_string($bytes) ? @getimagesizefromstring($bytes) : false;

                if (is_array($info)) {
                    $width = (int) ($info[0] ?? 0);
                    $height = (int) ($info[1] ?? 0);
                }
            } catch (\Throwable) {
                //
            }
        }

        return [
            'width' => $width !== null && $width > 0 ? $width : null,
            'height' => $height !== null && $height > 0 ? $height : null,
            'storage_available' => $storageAvailable,
        ];
    }

    /**
     * @param array<int, string> $paths
     */
    private function integerMetadata(array $metadata, array $paths): ?int
    {
        foreach ($paths as $path) {
            $value = data_get($metadata, $path);

            if (filter_var($value, FILTER_VALIDATE_INT) !== false && (int) $value > 0) {
                return (int) $value;
            }
        }

        return null;
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

    /**
     * @return array<string, mixed>
     */
    private function backgroundResource(?LotteryImageBackgroundAssetSet $assetSet): array
    {
        if ($assetSet === null) {
            return [];
        }

        $missing = $this->missingAssetsForSet($assetSet);

        return [
            'id' => (string) $assetSet->id,
            'game_id' => (string) $assetSet->game_id,
            'version' => (string) $assetSet->version,
            'set_type' => (string) $assetSet->set_type,
            'status' => (string) $assetSet->status,
            'ready' => (string) $assetSet->status === 'ready' && $missing === [],
            'generation_ready' => $this->images->backgroundReady((string) $assetSet->game_id, (string) $assetSet->version, (string) $assetSet->set_type),
            'missing_assets' => $missing,
            'assets' => [
                'source' => $this->backgroundAssetResource($assetSet, 'source'),
                'full' => $this->backgroundAssetResource($assetSet, 'full'),
                'thumb' => $this->backgroundAssetResource($assetSet, 'thumb'),
            ],
            'activated_at' => $assetSet->activated_at?->toISOString(),
            'retired_at' => $assetSet->retired_at?->toISOString(),
            'updated_at' => $assetSet->updated_at?->toISOString(),
            'updated_by' => $assetSet->uploaded_by_admin_id,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function backgroundAssetResource(LotteryImageBackgroundAssetSet $assetSet, string $slot): array
    {
        $assetIdField = $slot.'_asset_id';
        $pathField = $slot.'_storage_path';
        $contentTypeField = $slot.'_content_type';
        $widthField = $slot.'_width';
        $heightField = $slot.'_height';
        $sizeField = $slot.'_size_bytes';

        return [
            'asset_id' => $assetSet->{$assetIdField},
            'storage_path' => $assetSet->{$pathField},
            'content_type' => $assetSet->{$contentTypeField},
            'width' => $assetSet->{$widthField},
            'height' => $assetSet->{$heightField},
            'size_bytes' => $assetSet->{$sizeField},
            'storage_available' => $this->storageExists((string) $assetSet->{$pathField}),
        ];
    }

    /**
     * @return array<int, string>
     */
    private function missingAssetsForSet(LotteryImageBackgroundAssetSet $assetSet): array
    {
        $missing = [];

        foreach (['source', 'full', 'thumb'] as $slot) {
            $assetId = $assetSet->{$slot.'_asset_id'};
            $path = $assetSet->{$slot.'_storage_path'};
            $width = $assetSet->{$slot.'_width'};
            $height = $assetSet->{$slot.'_height'};

            if ($assetId === null || $path === null || $width === null || $height === null || ! $this->storageExists((string) $path)) {
                $missing[] = $slot;
            }
        }

        return $missing;
    }

    private function storageExists(string $storagePath): bool
    {
        if (trim($storagePath) === '') {
            return false;
        }

        try {
            return Storage::disk((string) config('lottery_images.disk', 'lottery_images'))->exists($storagePath);
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function mixResource(string $gameId): array
    {
        $setting = LotteryImageMixSetting::query()->where('game_id', $gameId)->first();
        $configMix = config('lottery_images.background_mix', ['odd' => 45, 'even' => 45, 'charity' => 10]);

        return [
            'game_id' => $gameId,
            'source' => $setting === null ? 'default_config' : 'persisted',
            'mix' => [
                'odd' => $setting === null ? (int) ($configMix['odd'] ?? 45) : (int) $setting->odd_percentage,
                'even' => $setting === null ? (int) ($configMix['even'] ?? 45) : (int) $setting->even_percentage,
                'charity' => $setting === null ? (int) ($configMix['charity'] ?? 10) : (int) $setting->charity_percentage,
            ],
            'updated_at' => $setting?->updated_at?->toISOString(),
            'updated_by' => $setting?->updated_by_admin_id,
        ];
    }

    /**
     * @return array{central: int, partner: int, total: int}
     */
    private function statusCounts(string $gameId, ?string $batchId, ?string $version, string $status): array
    {
        $centralQuery = StockItem::query()->where('game_id', $gameId)->where('image_generation_status', $status);
        $this->applyPendingFilters($centralQuery, $gameId, $batchId, $version, self::SET_TYPES);
        $central = $centralQuery->count();

        $stockIds = StockItem::query()->where('game_id', $gameId);
        $this->applyPendingFilters($stockIds, $gameId, $batchId, $version, self::SET_TYPES);
        $partner = LocalStockItem::query()
            ->where('game_id', $gameId)
            ->where('image_generation_status', $status)
            ->whereIn('stock_item_id', $stockIds->pluck('id'))
            ->count();

        return ['central' => $central, 'partner' => $partner, 'total' => $central + $partner];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function lastErrorSamples(string $gameId, ?string $batchId, ?string $version): array
    {
        $central = StockItem::query()
            ->where('game_id', $gameId)
            ->whereNotNull('image_generation_error');
        $this->applyPendingFilters($central, $gameId, $batchId, $version, self::SET_TYPES);

        $samples = $central->orderByDesc('updated_at')->limit(5)->get()->map(fn (StockItem $stock): array => [
            'scope' => 'central',
            'stock_item_id' => (string) $stock->id,
            'local_stock_item_id' => null,
            'batch_id' => $stock->batch_id,
            'set_type' => $stock->background_set_type,
            'status' => $stock->image_generation_status,
            'error' => $stock->image_generation_error,
            'updated_at' => $stock->updated_at?->toISOString(),
        ])->all();

        $locals = LocalStockItem::query()
            ->where('game_id', $gameId)
            ->whereNotNull('image_generation_error')
            ->orderByDesc('updated_at')
            ->limit(5)
            ->get();

        foreach ($locals as $local) {
            $stock = StockItem::query()->whereKey($local->stock_item_id)->first();

            if ($stock === null || ! $this->stockMatchesFilters($stock, $gameId, $batchId, $version, self::SET_TYPES)) {
                continue;
            }

            $samples[] = [
                'scope' => 'partner',
                'stock_item_id' => (string) $local->stock_item_id,
                'local_stock_item_id' => (string) $local->id,
                'batch_id' => $stock->batch_id,
                'set_type' => $stock->background_set_type,
                'status' => $local->image_generation_status,
                'error' => $local->image_generation_error,
                'updated_at' => $local->updated_at?->toISOString(),
            ];
        }

        return array_slice($samples, 0, 10);
    }

    private function applyPendingFilters(mixed $query, ?string $gameId, ?string $batchId, ?string $version, array $setTypes): void
    {
        if ($gameId !== null) {
            $query->where('game_id', $gameId);
        }

        if ($batchId !== null) {
            $query->where('batch_id', $batchId);
        }

        if ($version !== null) {
            $query->where('background_asset_version', $version);
        }

        if ($setTypes !== []) {
            $query->whereIn('background_set_type', $setTypes);
        }
    }

    private function stockMatchesFilters(StockItem $stock, ?string $gameId, ?string $batchId, ?string $version, array $setTypes): bool
    {
        if ($gameId !== null && (string) $stock->game_id !== $gameId) {
            return false;
        }

        if ($batchId !== null && (string) $stock->batch_id !== $batchId) {
            return false;
        }

        if ($version !== null && (string) $stock->background_asset_version !== $version) {
            return false;
        }

        return $setTypes === [] || in_array((string) $stock->background_set_type, $setTypes, true);
    }

    /**
     * @return array<int, string>|null
     */
    private function setTypesFrom(mixed $raw): ?array
    {
        if ($raw === null || $raw === '') {
            return self::SET_TYPES;
        }

        $values = is_array($raw) ? $raw : explode(',', (string) $raw);
        $setTypes = [];

        foreach ($values as $value) {
            $setType = trim((string) $value);

            if (! in_array($setType, self::SET_TYPES, true)) {
                return null;
            }

            $setTypes[] = $setType;
        }

        return array_values(array_unique($setTypes));
    }

    private function retireOtherBackgroundVersions(string $gameId, string $setType, string $currentVersion, mixed $now): void
    {
        LotteryImageBackgroundAssetSet::query()
            ->where('game_id', $gameId)
            ->where('set_type', $setType)
            ->where('version', '!=', $currentVersion)
            ->where('status', 'ready')
            ->update([
                'status' => 'retired',
                'retired_at' => $now,
                'updated_at' => $now,
            ]);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function gameVersionErrors(array $payload, bool $requireVersion = true): array
    {
        $errors = [];
        $gameId = trim((string) ($payload['game_id'] ?? ''));

        if ($gameId === '') {
            $errors['game_id'][] = 'The game_id field is required.';
        } elseif (! Game::query()->whereKey($gameId)->exists()) {
            $errors['game_id'][] = 'The selected game_id does not exist.';
        }

        if (($requireVersion || ($payload['version'] ?? null) !== null) && ! $this->validVersion($this->versionFrom($payload['version'] ?? null))) {
            $errors['version'][] = 'The version field must be 1-64 characters and may contain letters, numbers, dot, underscore, or dash.';
        }

        return $errors;
    }

    private function versionFrom(mixed $version): string
    {
        $resolved = trim((string) ($version ?? config('lottery_images.background_version', 'v1')));

        return $resolved === '' ? 'v1' : $resolved;
    }

    private function validVersion(string $version): bool
    {
        return strlen($version) <= 64 && preg_match('/^[A-Za-z0-9._-]+$/', $version) === 1;
    }

    private function nullableString(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim((string) $value);

        return $trimmed === '' ? null : $trimmed;
    }

    /**
     * @return array{full: array{width: int, height: int}, thumb: array{width: int, height: int}}
     */
    private function expectedDimensions(): array
    {
        return [
            'full' => [
                'width' => (int) config('lottery_images.dimensions.full.width', 500),
                'height' => (int) config('lottery_images.dimensions.full.height', 280),
            ],
            'thumb' => [
                'width' => (int) config('lottery_images.dimensions.thumb.width', 280),
                'height' => (int) config('lottery_images.dimensions.thumb.height', 157),
            ],
        ];
    }

    /**
     * @param array<string, array<int, string>> $left
     * @param array<string, array<int, string>> $right
     * @return array<string, array<int, string>>
     */
    private function mergeErrors(array $left, array $right): array
    {
        foreach ($right as $field => $messages) {
            foreach ($messages as $message) {
                $left[$field][] = $message;
            }
        }

        return $left;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(AdminSessionContext $actor, Request $request, string $action, string $targetType, string $targetId, array $payload): void
    {
        $this->auditLogger->logAdminWrite(
            actorId: (string) $actor->adminUser['id'],
            scopeType: 'central',
            action: $action,
            targetType: $targetType,
            targetId: $targetId,
            payload: [
                'payload' => $payload,
                'idempotency_key' => $request->header('Idempotency-Key'),
            ],
            tenantId: null,
            partnerId: null,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }
}

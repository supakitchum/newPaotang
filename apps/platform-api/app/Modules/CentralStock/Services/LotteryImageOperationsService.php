<?php

namespace App\Modules\CentralStock\Services;

use App\Jobs\GenerateLotteryImageJob;
use App\Jobs\GeneratePartnerLotteryImageJob;
use App\Models\Game;
use App\Models\LocalStockItem;
use App\Models\LotteryImageBackgroundAssetSet;
use App\Models\LotteryImageMixSetting;
use App\Models\Partner;
use App\Models\PlatformSystemSetting;
use App\Models\PlatformAsset;
use App\Models\StockItem;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use ZipArchive;

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
        private readonly RuntimeStorageService $storage,
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
            ->orderBy('position')
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
                ->where('position', 1)
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
                    'position' => 1,
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
    public function importBackgroundZip(array $payload, ?UploadedFile $zipFile, AdminSessionContext $actor, Request $request): array
    {
        $normalized = [
            'game_id' => trim((string) ($payload['game_id'] ?? '')),
            'version' => $this->versionFrom($payload['version'] ?? null),
            'set_type' => trim((string) ($payload['set_type'] ?? '')),
            'status' => trim((string) ($payload['status'] ?? 'ready')),
            'supersede_existing' => filter_var($payload['supersede_existing'] ?? false, FILTER_VALIDATE_BOOLEAN),
        ];
        $errors = $this->backgroundZipPayloadErrors($normalized, $zipFile, $request);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $entries = $this->extractZipImageEntries($zipFile);

        if (($entries['errors'] ?? []) !== []) {
            return ['error' => 'validation_failed', 'errors' => $entries['errors']];
        }

        $normalized['expected_count'] = (int) ($entries['detected_count'] ?? 0);

        /** @var array<int, array{name: string, sort_name: string, ordinal: int, normalized_name: string, extension: string, content_type: string, bytes: string, width: int, height: int, size_bytes: int, checksum: string}> $files */
        $files = $entries['files'];
        $expected = $this->expectedDimensions();
        $now = now();

        return DB::transaction(function () use ($normalized, $files, $expected, $actor, $request, $payload, $now): array {
            if ($normalized['supersede_existing'] === true && $normalized['status'] === 'ready') {
                $this->retireOtherBackgroundVersions($normalized['game_id'], $normalized['set_type'], $normalized['version'], $now);
            }

            $resources = [];

            foreach ($files as $file) {
                $position = (int) $file['ordinal'];
                $baseKey = 'lottery-image-assets/games/'.$normalized['game_id'].'/backgrounds/'.$normalized['version'].'/'.$normalized['set_type'].'/'.str_pad((string) $position, 3, '0', STR_PAD_LEFT);
                $sourceKey = $baseKey.'/'.$file['normalized_name'];
                $fullKey = $baseKey.'/full.webp';
                $thumbKey = $baseKey.'/thumb.webp';
                $fullBytes = $this->renderBackgroundVariant($file['bytes'], 'full');
                $thumbBytes = $this->renderBackgroundVariant($file['bytes'], 'thumb');

                $this->storeGeneratedAssetBytes($sourceKey, $file['bytes'], $file['content_type']);
                $this->storeGeneratedAssetBytes($fullKey, $fullBytes, 'image/webp');
                $this->storeGeneratedAssetBytes($thumbKey, $thumbBytes, 'image/webp');

                $sourceAsset = $this->upsertGeneratedPlatformAsset(
                    $sourceKey,
                    basename($sourceKey),
                    $file['content_type'],
                    $file['bytes'],
                    ['width' => $file['width'], 'height' => $file['height'], 'zip_entry' => $file['normalized_name']],
                    $actor,
                );
                $fullAsset = $this->upsertGeneratedPlatformAsset(
                    $fullKey,
                    basename($fullKey),
                    'image/webp',
                    $fullBytes,
                    ['width' => $expected['full']['width'], 'height' => $expected['full']['height'], 'source_zip_entry' => $file['normalized_name']],
                    $actor,
                );
                $thumbAsset = $this->upsertGeneratedPlatformAsset(
                    $thumbKey,
                    basename($thumbKey),
                    'image/webp',
                    $thumbBytes,
                    ['width' => $expected['thumb']['width'], 'height' => $expected['thumb']['height'], 'source_zip_entry' => $file['normalized_name']],
                    $actor,
                );
                $existing = LotteryImageBackgroundAssetSet::query()
                    ->where('game_id', $normalized['game_id'])
                    ->where('version', $normalized['version'])
                    ->where('set_type', $normalized['set_type'])
                    ->where('position', $position)
                    ->lockForUpdate()
                    ->first();
                $assetSetId = $existing?->id ?? 'lib_'.Str::ulid()->toBase32();

                LotteryImageBackgroundAssetSet::query()->updateOrCreate(
                    ['id' => $assetSetId],
                    [
                        'game_id' => $normalized['game_id'],
                        'version' => $normalized['version'],
                        'set_type' => $normalized['set_type'],
                        'position' => $position,
                        'status' => $normalized['status'],
                        'source_asset_id' => $sourceAsset->id,
                        'full_asset_id' => $fullAsset->id,
                        'thumb_asset_id' => $thumbAsset->id,
                        'source_storage_path' => $sourceKey,
                        'full_storage_path' => $fullKey,
                        'thumb_storage_path' => $thumbKey,
                        'source_content_type' => $file['content_type'],
                        'full_content_type' => 'image/webp',
                        'thumb_content_type' => 'image/webp',
                        'source_width' => $file['width'],
                        'source_height' => $file['height'],
                        'full_width' => $expected['full']['width'],
                        'full_height' => $expected['full']['height'],
                        'thumb_width' => $expected['thumb']['width'],
                        'thumb_height' => $expected['thumb']['height'],
                        'source_size_bytes' => strlen($file['bytes']),
                        'full_size_bytes' => strlen($fullBytes),
                        'thumb_size_bytes' => strlen($thumbBytes),
                        'uploaded_by_admin_id' => $actor->adminUser['id'],
                        'activated_at' => $normalized['status'] === 'ready' ? $now : $existing?->activated_at,
                        'retired_at' => $normalized['status'] === 'retired' ? $now : null,
                        'metadata_json' => [
                            'imported_from_zip' => true,
                            'zip_entry' => $file['normalized_name'],
                            'expected_count' => $normalized['expected_count'],
                            'expected_dimensions' => $expected,
                            'supersede_existing' => $normalized['supersede_existing'],
                        ],
                        'created_at' => $existing?->created_at ?? $now,
                        'updated_at' => $now,
                    ],
                );

                $resources[] = $this->backgroundResource(LotteryImageBackgroundAssetSet::query()->whereKey($assetSetId)->first());
            }

            LotteryImageBackgroundAssetSet::query()
                ->where('game_id', $normalized['game_id'])
                ->where('version', $normalized['version'])
                ->where('set_type', $normalized['set_type'])
                ->where('position', '>', count($files))
                ->where('status', 'ready')
                ->update([
                    'status' => 'retired',
                    'retired_at' => $now,
                    'updated_at' => $now,
                ]);

            $this->audit($actor, $request, 'lottery_image_background_asset_set.imported_zip', 'lottery_image_background_asset_set', $normalized['game_id'].':'.$normalized['version'].':'.$normalized['set_type'], $payload);

            return [
                'resource' => [
                    'data' => $resources,
                    'meta' => [
                        'game_id' => $normalized['game_id'],
                        'version' => $normalized['version'],
                        'set_type' => $normalized['set_type'],
                        'imported_count' => count($resources),
                        'expected_count' => $normalized['expected_count'],
                    ],
                ],
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
     * @return array<string, mixed>
     */
    public function layout(): array
    {
        $row = PlatformSystemSetting::query()
            ->where('key', LotteryImageGenerator::LAYOUT_SETTING_KEY)
            ->where('status', 'active')
            ->first();

        $saved = is_array($row?->value_json) ? $row->value_json : [];
        $layout = $this->images->layout($saved);

        return [
            'key' => LotteryImageGenerator::LAYOUT_SETTING_KEY,
            'scope' => 'global',
            'layout' => $layout,
            'default_layout' => LotteryImageGenerator::defaultLayout(),
            'updated_at' => $row?->updated_at?->toISOString(),
            'updated_by' => null,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateLayout(array $payload, AdminSessionContext $actor, Request $request): array
    {
        [$layout, $errors] = $this->normalizedLayoutPayload($payload['layout'] ?? $payload);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($layout, $payload, $actor, $request): array {
            PlatformSystemSetting::query()->updateOrCreate(
                ['key' => LotteryImageGenerator::LAYOUT_SETTING_KEY],
                [
                    'id' => 'pss_'.substr(sha1(LotteryImageGenerator::LAYOUT_SETTING_KEY), 0, 20),
                    'value_json' => $layout,
                    'status' => 'active',
                    'updated_at' => now(),
                    'created_at' => now(),
                ],
            );

            $this->audit($actor, $request, 'lottery_image_layout.updated', 'platform_system_settings', LotteryImageGenerator::LAYOUT_SETTING_KEY, $payload);

            return ['resource' => $this->layout()];
        });
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
    public function preview(array $payload, ?string $routePartnerId = null): array
    {
        $gameId = trim((string) ($payload['game_id'] ?? ''));
        $version = $this->versionFrom($payload['version'] ?? null);
        $setType = trim((string) ($payload['set_type'] ?? ''));
        $lotteryNumber = preg_replace('/\D+/', '', (string) ($payload['lottery_number'] ?? '')) ?: '';
        $requestedMode = trim((string) ($payload['mode'] ?? 'central_unbranded'));
        $variant = trim((string) ($payload['variant'] ?? 'full'));
        $bodyPartnerId = $this->nullableString($payload['partner_id'] ?? null);
        $partnerId = $routePartnerId ?? $bodyPartnerId;
        $layoutOverride = null;
        $errors = $this->gameVersionErrors(['game_id' => $gameId, 'version' => $version]);

        if (array_key_exists('layout', $payload)) {
            [$layoutOverride, $layoutErrors] = $this->normalizedLayoutPayload($payload['layout'], partial: true);
            $errors = array_merge($errors, $layoutErrors);
        }

        if (! in_array($setType, self::SET_TYPES, true)) {
            $errors['set_type'][] = 'The set_type field must be odd, even, or charity.';
        }
        if ($lotteryNumber === '' || strlen($lotteryNumber) > 6) {
            $errors['lottery_number'][] = 'The lottery_number field must contain 1 to 6 digits.';
        }
        if (! in_array($requestedMode, ['central_unbranded', 'partner_branded'], true)) {
            $errors['mode'][] = 'The mode field must be central_unbranded or partner_branded.';
        }
        if (! in_array($variant, ['full', 'thumb'], true)) {
            $errors['variant'][] = 'The variant field must be full or thumb.';
        }
        if ($routePartnerId !== null && $bodyPartnerId !== null && $bodyPartnerId !== $routePartnerId) {
            $errors['partner_id'][] = 'The partner_id field must match the route partner_id.';
        }
        if ($requestedMode === 'partner_branded' && $partnerId === null) {
            $errors['partner_id'][] = 'The partner_id field is required when mode is partner_branded.';
        }
        if ($partnerId !== null && ! Partner::query()->whereKey($partnerId)->exists()) {
            $errors['partner_id'][] = 'The selected partner_id does not exist.';
        }
        if (! $this->images->backgroundReady($gameId, $version, $setType, 1)) {
            $errors['background'][] = 'The selected background set is not ready for preview.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $mode = $requestedMode;
        $warnings = [];
        $assetSet = null;

        if ($requestedMode === 'partner_branded') {
            $assetSet = $this->images->activePartnerAssetSet((string) $partnerId);

            if ($assetSet === null) {
                $mode = 'central_unbranded';
                $warnings[] = 'partner_branding_assets_not_ready';
            }
        }

        $digits = str_pad(substr($lotteryNumber, -6), 6, '0', STR_PAD_LEFT);
        $stock = new StockItem([
            'id' => 'preview_'.substr(sha1($gameId.':'.$version.':'.$setType.':'.$digits), 0, 16),
            'game_id' => $gameId,
            'batch_id' => 'preview',
            'full_number' => $digits,
            'front3' => substr($digits, 0, 3),
            'back3' => substr($digits, -3),
            'back2' => substr($digits, -2),
            'status' => 'available',
            'background_set_type' => $setType,
            'background_asset_version' => $version,
            'background_asset_index' => 1,
        ]);

        if ($mode === 'partner_branded' && $assetSet !== null) {
            $local = new LocalStockItem([
                'id' => 'preview_local_'.substr(sha1((string) $partnerId.':'.$digits), 0, 12),
                'tenant_id' => null,
                'partner_id' => $partnerId,
                'game_id' => $gameId,
                'stock_item_id' => $stock->id,
                'full_number' => $digits,
                'front3' => substr($digits, 0, 3),
                'back3' => substr($digits, -3),
                'back2' => substr($digits, -2),
                'status' => 'available',
            ]);
            $bytes = $this->images->renderPartnerImage($local, $stock, $assetSet, $variant, $layoutOverride);
        } else {
            $bytes = $this->images->renderCentralImage($stock, $variant, $layoutOverride);
        }

        $dimensions = $this->expectedDimensions()[$variant];

        return [
            'mode' => $mode,
            'requested_mode' => $requestedMode,
            'fallback_mode' => $mode === $requestedMode ? null : $mode,
            'warnings' => $warnings,
            'game_id' => $gameId,
            'version' => $version,
            'set_type' => $setType,
            'partner_id' => $partnerId,
            'lottery_number' => $digits,
            'variant' => $variant,
            'content_type' => 'image/webp',
            'width' => $dimensions['width'],
            'height' => $dimensions['height'],
            'layout' => $this->images->layout($layoutOverride),
            'image_base64' => base64_encode($bytes),
            'data_url' => 'data:image/webp;base64,'.base64_encode($bytes),
            'side_effects' => [
                'stock_rows_created' => 0,
                'permanent_image_rows_created' => 0,
                'branding_locked' => false,
            ],
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
     * @param mixed $payload
     * @return array{0: array<string, mixed>, 1: array<string, array<int, string>>}
     */
    private function normalizedLayoutPayload(mixed $payload, bool $partial = false): array
    {
        if (! is_array($payload)) {
            return [[], ['layout' => ['The layout field must be an object.']]];
        }

        $defaults = LotteryImageGenerator::defaultLayout();
        $normalized = [];
        $errors = [];

        foreach ($defaults as $slotKey => $fields) {
            $slot = $payload[$slotKey] ?? [];

            if ($partial && ! array_key_exists($slotKey, $payload)) {
                continue;
            }

            if ($slot !== [] && ! is_array($slot)) {
                $errors['layout.'.$slotKey][] = 'The '.$slotKey.' layout slot must be an object.';
                continue;
            }

            $normalized[$slotKey] = [];

            foreach ($fields as $field => $default) {
                if ($partial && ! array_key_exists($field, $slot)) {
                    continue;
                }

                $raw = $slot[$field] ?? $default;
                $fieldKey = 'layout.'.$slotKey.'.'.$field;

                if (is_string($default)) {
                    $allowed = $field === 'align'
                        ? ['left', 'center', 'right']
                        : ['top', 'middle', 'center', 'bottom', 'baseline'];
                    $value = is_scalar($raw) ? (string) $raw : '';

                    if (! in_array($value, $allowed, true)) {
                        $errors[$fieldKey][] = 'The '.$fieldKey.' field must be one of: '.implode(', ', $allowed).'.';
                        continue;
                    }

                    $normalized[$slotKey][$field] = $value;
                    continue;
                }

                if ($raw === null && $default === null) {
                    $normalized[$slotKey][$field] = null;
                    continue;
                }

                if (filter_var($raw, FILTER_VALIDATE_INT) === false) {
                    $errors[$fieldKey][] = 'The '.$fieldKey.' field must be an integer.';
                    continue;
                }

                $value = (int) $raw;

                if (in_array($field, ['width', 'height', 'gap', 'size'], true) && ($value < 1 || $value > 1000)) {
                    $errors[$fieldKey][] = 'The '.$fieldKey.' field must be between 1 and 1000.';
                    continue;
                }

                if (in_array($field, ['x', 'y'], true) && ($value < -1000 || $value > 2000)) {
                    $errors[$fieldKey][] = 'The '.$fieldKey.' field must be between -1000 and 2000.';
                    continue;
                }

                if (in_array($field, ['angle', 'rotate'], true) && ($value < -360 || $value > 360)) {
                    $errors[$fieldKey][] = 'The '.$fieldKey.' field must be between -360 and 360.';
                    continue;
                }

                $normalized[$slotKey][$field] = $value;
            }
        }

        return [$normalized, $errors];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function backgroundZipPayloadErrors(array $payload, ?UploadedFile $zipFile, Request $request): array
    {
        $errors = $this->gameVersionErrors($payload);
        $uploadLimit = $this->zipUploadLimitBytes();

        if (! in_array($payload['set_type'], self::SET_TYPES, true)) {
            $errors['set_type'][] = 'The set_type field must be odd, even, or charity.';
        }
        if (! in_array($payload['status'], self::BACKGROUND_STATUSES, true)) {
            $errors['status'][] = 'The status field must be ready, inactive, or retired.';
        }
        if (! $zipFile instanceof UploadedFile) {
            $contentLength = (int) $request->server('CONTENT_LENGTH', 0);
            $errors['zip'][] = $uploadLimit !== null && $contentLength > $uploadLimit
                ? $this->zipUploadLimitExceededMessage($uploadLimit)
                : 'The zip field is required and must be a valid upload.';
        } elseif (! $zipFile->isValid()) {
            $errors['zip'][] = in_array($zipFile->getError(), [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)
                ? $this->zipUploadLimitExceededMessage($uploadLimit)
                : 'The zip field is required and must be a valid upload.';
        } elseif ((int) $zipFile->getSize() < 1) {
            $errors['zip'][] = 'The zip file must be at least 1 byte.';
        } elseif ($uploadLimit !== null && (int) $zipFile->getSize() > $uploadLimit) {
            $errors['zip'][] = $this->zipUploadLimitExceededMessage($uploadLimit);
        }

        return $errors;
    }

    private function zipUploadLimitExceededMessage(?int $uploadLimit): string
    {
        $suffix = $uploadLimit === null
            ? 'the PHP upload limit.'
            : 'the PHP upload limit of '.$this->humanBytes($uploadLimit).' ('.$uploadLimit.' bytes).';

        return 'The zip file exceeds '.$suffix.' Increase upload_max_filesize and post_max_size in php.ini or upload a smaller zip.';
    }

    private function zipUploadLimitBytes(): ?int
    {
        $limits = array_values(array_filter([
            $this->iniBytes((string) ini_get('upload_max_filesize')),
            $this->iniBytes((string) ini_get('post_max_size')),
        ], static fn (?int $value): bool => $value !== null && $value > 0));

        return $limits === [] ? null : min($limits);
    }

    private function iniBytes(string $value): ?int
    {
        $value = trim($value);

        if ($value === '' || $value === '-1') {
            return null;
        }

        $unit = strtolower(substr($value, -1));
        $number = is_numeric($unit) ? (float) $value : (float) substr($value, 0, -1);

        if ($number <= 0) {
            return null;
        }

        $multiplier = match ($unit) {
            'g' => 1024 * 1024 * 1024,
            'm' => 1024 * 1024,
            'k' => 1024,
            default => 1,
        };

        return (int) ceil($number * $multiplier);
    }

    private function humanBytes(int $bytes): string
    {
        if ($bytes >= 1024 * 1024 * 1024) {
            return round($bytes / (1024 * 1024 * 1024), 2).' GiB';
        }

        if ($bytes >= 1024 * 1024) {
            return round($bytes / (1024 * 1024), 2).' MiB';
        }

        if ($bytes >= 1024) {
            return round($bytes / 1024, 2).' KiB';
        }

        return $bytes.' B';
    }

    /**
     * @return array{files?: array<int, array{name: string, sort_name: string, ordinal: int, normalized_name: string, extension: string, content_type: string, bytes: string, width: int, height: int, size_bytes: int, checksum: string}>, detected_count?: int, errors?: array<string, array<int, string>>}
     */
    private function extractZipImageEntries(?UploadedFile $zipFile): array
    {
        if (! $zipFile instanceof UploadedFile) {
            return ['errors' => ['zip' => ['The zip field is required and must be a valid upload.']]];
        }

        $archive = new ZipArchive();
        $opened = $archive->open((string) $zipFile->getRealPath());

        if ($opened !== true) {
            return ['errors' => ['zip' => ['The uploaded file must be a readable zip archive.']]];
        }

        $errors = [];
        $files = [];
        $validEntries = [];
        $expected = $this->expectedDimensions();
        $sourceLimit = $this->sizeLimitForSlot('source');
        $allowedMimes = config('lottery_images.background_asset_limits.allowed_source_mimes', ['image/webp', 'image/png', 'image/jpeg']);
        $allowedExtensions = [
            'jpeg' => 'image/jpeg',
            'jpg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
        ];

        try {
            for ($index = 0; $index < $archive->numFiles; $index++) {
                $stat = $archive->statIndex($index);
                $name = is_array($stat) ? (string) ($stat['name'] ?? '') : '';

                if ($name === '' || str_ends_with($name, '/')) {
                    continue;
                }

                if ($this->isIgnoredMacZipEntry($name)) {
                    continue;
                }

                $basename = basename($name);

                if ($basename !== $name || str_contains($name, '\\') || str_contains($name, '..') || str_starts_with($name, '.') || str_starts_with($name, '__MACOSX')) {
                    $errors['zip'][] = 'The zip file contains an unsafe path: '.$name.'.';
                    continue;
                }

                $extension = strtolower(pathinfo($basename, PATHINFO_EXTENSION));
                $expectedMime = $allowedExtensions[$extension] ?? null;

                if ($extension === '' || $expectedMime === null || ! in_array($expectedMime, $allowedMimes, true)) {
                    $errors['zip'][] = 'The zip entry '.$name.' must use a supported image extension: png, jpg, jpeg, or webp.';
                    continue;
                }

                if (isset($validEntries[strtolower($basename)])) {
                    $errors['zip'][] = 'The zip file contains duplicate image name '.$name.'.';
                    continue;
                }

                $bytes = $archive->getFromIndex($index);

                if (! is_string($bytes) || $bytes === '') {
                    $errors['zip'][] = 'The zip entry '.$name.' could not be read.';
                    continue;
                }

                if (strlen($bytes) > $sourceLimit) {
                    $errors['zip'][] = 'The zip entry '.$name.' is larger than the allowed source image size.';
                    continue;
                }

                $info = @getimagesizefromstring($bytes);
                $mime = is_array($info) ? (string) ($info['mime'] ?? '') : '';

                if (! is_array($info) || ! in_array($mime, $allowedMimes, true) || $mime !== $expectedMime) {
                    $errors['zip'][] = 'The zip entry '.$name.' must be a readable image file matching its extension.';
                    continue;
                }

                $width = (int) ($info[0] ?? 0);
                $height = (int) ($info[1] ?? 0);

                if ($width < $expected['full']['width'] || $height < $expected['full']['height']) {
                    $errors['zip'][] = 'The zip entry '.$name.' dimensions must be at least '.$expected['full']['width'].'x'.$expected['full']['height'].'.';
                    continue;
                }

                $validEntries[strtolower($basename)] = [
                    'name' => $name,
                    'sort_name' => $basename,
                    'extension' => $extension === 'jpeg' ? 'jpg' : $extension,
                    'content_type' => $mime,
                    'bytes' => $bytes,
                    'width' => $width,
                    'height' => $height,
                    'size_bytes' => strlen($bytes),
                    'checksum' => hash('sha256', $bytes),
                ];
            }
        } finally {
            $archive->close();
        }

        usort($validEntries, static fn (array $left, array $right): int => strnatcasecmp((string) $left['sort_name'], (string) $right['sort_name']));

        foreach (array_values($validEntries) as $index => $entry) {
            $files[] = [
                ...$entry,
                'ordinal' => $index + 1,
                'normalized_name' => str_pad((string) ($index + 1), 3, '0', STR_PAD_LEFT).'.'.$entry['extension'],
            ];
        }

        $detectedCount = count($files);

        if ($detectedCount < 1) {
            $errors['zip'][] = 'The zip file must contain at least 1 supported image file.';
        }

        if ($errors !== []) {
            return ['errors' => $errors];
        }

        return ['files' => $files, 'detected_count' => $detectedCount];
    }

    private function isIgnoredMacZipEntry(string $name): bool
    {
        $basename = basename($name);

        return $basename === '.DS_Store'
            || str_starts_with($basename, '._')
            || str_starts_with($name, '__MACOSX/');
    }

    private function renderBackgroundVariant(string $sourceBytes, string $variant): string
    {
        $source = @imagecreatefromstring($sourceBytes);

        if ($source === false) {
            throw new \RuntimeException('background_image_decode_failed');
        }

        $spec = $this->expectedDimensions()[$variant];
        $canvas = imagecreatetruecolor($spec['width'], $spec['height']);

        if ($canvas === false) {
            imagedestroy($source);
            throw new \RuntimeException('background_canvas_create_failed');
        }

        try {
            $sourceWidth = imagesx($source);
            $sourceHeight = imagesy($source);

            imagecopyresampled($canvas, $source, 0, 0, 0, 0, $spec['width'], $spec['height'], $sourceWidth, $sourceHeight);
            ob_start();
            $encoded = imagewebp($canvas, null, (int) config('lottery_images.dimensions.'.$variant.'.quality', 70));
            $bytes = ob_get_clean();

            if ($encoded !== true || ! is_string($bytes) || $bytes === '') {
                throw new \RuntimeException('background_webp_encode_failed');
            }

            return $bytes;
        } finally {
            imagedestroy($canvas);
            imagedestroy($source);
        }
    }

    private function storeGeneratedAssetBytes(string $key, string $bytes, string $contentType): void
    {
        $this->storage->put(RuntimeStorageService::ROUTE_LOTTERY_IMAGES, $key, $bytes, [
            'ContentType' => $contentType,
            'CacheControl' => (string) config('lottery_images.cache_control', 'public, max-age=31536000, immutable'),
        ]);
    }

    /**
     * @param array<string, mixed> $metadata
     */
    private function upsertGeneratedPlatformAsset(string $key, string $fileName, string $contentType, string $bytes, array $metadata, AdminSessionContext $actor): PlatformAsset
    {
        $assetId = 'ast_'.substr(sha1($key.':'.hash('sha256', $bytes)), 0, 20);

        PlatformAsset::query()->updateOrCreate(
            ['id' => $assetId],
            [
                'scope_type' => 'central',
                'tenant_id' => null,
                'created_by_admin_id' => $actor->adminUser['id'],
                'purpose' => 'ticket_image',
                'file_name' => $fileName,
                'content_type' => $contentType,
                'size_bytes' => strlen($bytes),
                'checksum_sha256' => hash('sha256', $bytes),
                'status' => 'committed',
                'storage_key' => $key,
                'upload_url' => null,
                'public_url' => $this->images->publicUrl($key),
                'metadata_json' => $metadata + ['generated_by' => 'lottery_background_zip_import'],
                'expires_at' => null,
                'committed_at' => now(),
                'updated_at' => now(),
                'created_at' => now(),
            ],
        );

        return PlatformAsset::query()->whereKey($assetId)->firstOrFail();
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
                $bytes = $this->storage->get(RuntimeStorageService::ROUTE_LOTTERY_IMAGES, (string) $asset->storage_key);
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
            'position' => (int) ($assetSet->position ?? 1),
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
            return $this->storage->exists(RuntimeStorageService::ROUTE_LOTTERY_IMAGES, $storagePath);
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

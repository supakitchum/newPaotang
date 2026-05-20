<?php

namespace App\Modules\AdminOperations\Services;

use App\Models\PartnerTenant;
use App\Models\PlatformAsset;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class AssetService
{
    private const PARTNER_LOTTERY_BRANDING_PURPOSE = 'partner_lottery_branding';
    private const PARTNER_LOTTERY_BRANDING_FILES = [
        'logo_qr' => 'logo_qr.webp',
        'right_sidebar' => 'rightsidebar.webp',
        'logo_bottom' => 'logo_bottom.webp',
    ];

    private const PURPOSES = [
        'tenant_logo',
        'tenant_favicon',
        'tenant_og_image',
        'ticket_image',
        self::PARTNER_LOTTERY_BRANDING_PURPOSE,
        'admin_attachment',
        'import_file',
        'other',
    ];

    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>, status?: int}
     */
    public function createUploadIntent(
        string $scopeType,
        ?string $tenantId,
        array $payload,
        AdminSessionContext $actor,
        Request $request,
    ): array {
        if ($this->productionStorageBlocked()) {
            return ['error' => 'blocked_external'];
        }

        $normalized = $this->uploadPayload($tenantId, $payload);
        $errors = $this->uploadErrors($tenantId, $normalized);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($scopeType, $tenantId, $payload, $normalized, $actor, $request): array {
            $assetId = 'ast_'.Str::ulid()->toBase32();
            $storageKey = $this->storageKey($scopeType, $tenantId, $assetId, $normalized);
            $uploadUrl = 'https://local-assets.newpaotang.test/'.$storageKey.'?intent='.$assetId;
            $expiresAt = now()->addMinutes(15);

            PlatformAsset::query()->create([
                'id' => $assetId,
                'scope_type' => $scopeType,
                'tenant_id' => $tenantId,
                'created_by_admin_id' => $actor->adminUser['id'],
                'purpose' => $normalized['purpose'],
                'file_name' => $normalized['file_name'],
                'content_type' => $normalized['content_type'],
                'size_bytes' => $normalized['size_bytes'],
                'checksum_sha256' => $normalized['checksum_sha256'],
                'status' => 'pending_upload',
                'storage_key' => $storageKey,
                'upload_url' => $uploadUrl,
                'public_url' => null,
                'metadata_json' => $normalized['metadata'],
                'expires_at' => $expiresAt,
                'committed_at' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, $scopeType, 'asset.upload_intent_created', $assetId, $payload, $tenantId);

            return [
                'resource' => $this->uploadIntentResource(PlatformAsset::whereKey($assetId)->first()),
                'status' => 201,
            ];
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findAsset(string $scopeType, ?string $tenantId, string $assetId): ?array
    {
        $asset = $this->assetQuery($scopeType, $tenantId)
            ->where('id', $assetId)
            ->first();

        return $asset === null ? null : $this->assetResource($asset);
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function storeLocalUpload(
        string $scopeType,
        ?string $tenantId,
        string $assetId,
        ?UploadedFile $file,
        AdminSessionContext $actor,
        Request $request,
    ): array {
        if ($this->productionStorageBlocked()) {
            return ['error' => 'blocked_external'];
        }

        $asset = $this->assetQuery($scopeType, $tenantId)
            ->where('id', $assetId)
            ->first();

        if ($asset === null) {
            return ['error' => 'not_found'];
        }

        $errors = $this->localUploadErrors($asset, $file);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($scopeType, $tenantId, $assetId, $file, $actor, $request): array {
            $asset = $this->assetQuery($scopeType, $tenantId)
                ->where('id', $assetId)
                ->lockForUpdate()
                ->first();

            if ($asset === null) {
                return ['error' => 'not_found'];
            }

            $errors = $this->localUploadErrors($asset, $file);

            if ($errors !== []) {
                return ['error' => 'validation_failed', 'errors' => $errors];
            }

            /** @var UploadedFile $file */
            $stored = $this->localUploadPayload($asset, $file);
            Storage::disk((string) config('lottery_images.disk', 'lottery_images'))->put(
                (string) $asset->storage_key,
                $stored['bytes'],
                ['ContentType' => $stored['content_type']],
            );

            $metadata = is_array($asset->metadata_json) ? $asset->metadata_json : [];
            PlatformAsset::query()
                ->where('id', $assetId)
                ->update([
                    'content_type' => $stored['content_type'],
                    'size_bytes' => $stored['size_bytes'],
                    'file_name' => $stored['file_name'],
                    'metadata_json' => array_replace_recursive($metadata, [
                        'storage_boundary' => 'local_dev_uploaded',
                        'storage_disk' => (string) config('lottery_images.disk', 'lottery_images'),
                        'production_storage_ready' => false,
                        'local_uploaded_at' => now()->toISOString(),
                    ], $stored['metadata']),
                    'updated_at' => now(),
                ]);

            $this->audit($actor, $request, $scopeType, 'asset.local_upload_stored', $assetId, ['source_file_name' => $file->getClientOriginalName()], $tenantId);

            return ['resource' => $this->findAsset($scopeType, $tenantId, $assetId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function commitAsset(
        string $scopeType,
        ?string $tenantId,
        string $assetId,
        array $payload,
        AdminSessionContext $actor,
        Request $request,
    ): array {
        if ($this->productionStorageBlocked()) {
            return ['error' => 'blocked_external'];
        }

        $asset = $this->assetQuery($scopeType, $tenantId)
            ->where('id', $assetId)
            ->first();

        if ($asset === null) {
            return ['error' => 'not_found'];
        }

        $errors = $this->commitErrors($asset, $payload);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (in_array((string) $asset->status, ['failed', 'archived'], true)) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($scopeType, $tenantId, $assetId, $payload, $actor, $request): array {
            $asset = $this->assetQuery($scopeType, $tenantId)
                ->where('id', $assetId)
                ->lockForUpdate()
                ->first();

            if ($asset === null) {
                return ['error' => 'not_found'];
            }

            $metadata = is_array($asset->metadata_json) ? $asset->metadata_json : [];

            if (is_array($payload['metadata'] ?? null)) {
                $metadata = array_replace_recursive($metadata, $payload['metadata']);
            }

            $updates = [
                'checksum_sha256' => $payload['checksum_sha256'] ?? $asset->checksum_sha256,
                'status' => 'committed',
                'metadata_json' => $metadata + [
                    'storage_boundary' => 'local_dev_metadata_only',
                    'production_storage_ready' => false,
                ],
                'committed_at' => now(),
                'updated_at' => now(),
            ];

            if ((string) $asset->purpose === self::PARTNER_LOTTERY_BRANDING_PURPOSE) {
                $updates['public_url'] = $this->publicAssetUrl((string) $asset->storage_key);
                $updates['content_type'] = (string) config('lottery_images.content_type', 'image/webp');
                $updates['file_name'] = $this->canonicalBrandingFileName((string) ($metadata['branding_slot'] ?? ''));
            }

            PlatformAsset::query()
                ->where('id', $assetId)
                ->update($updates);

            $this->audit($actor, $request, $scopeType, 'asset.committed_local_dev', $assetId, $payload, $tenantId);

            return ['resource' => $this->findAsset($scopeType, $tenantId, $assetId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function uploadPayload(?string $tenantId, array $payload): array
    {
        $metadata = is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [];
        $normalized = [
            'tenant_id' => $payload['tenant_id'] ?? null,
            'purpose' => trim((string) ($payload['purpose'] ?? '')),
            'file_name' => trim((string) ($payload['file_name'] ?? '')),
            'content_type' => trim((string) ($payload['content_type'] ?? '')),
            'size_bytes' => filter_var($payload['size_bytes'] ?? null, FILTER_VALIDATE_INT),
            'checksum_sha256' => $this->nullableString($payload['checksum_sha256'] ?? null),
            'metadata' => $metadata,
            'expected_tenant_id' => $tenantId,
        ];

        if ($normalized['purpose'] === self::PARTNER_LOTTERY_BRANDING_PURPOSE) {
            $slot = trim((string) ($metadata['branding_slot'] ?? ''));
            $version = $this->canonicalBrandingVersion($metadata['version'] ?? 'v1');

            $normalized['metadata'] = array_replace_recursive($metadata, [
                'branding_slot' => $slot,
                'version' => $version,
                'source_file_name' => $normalized['file_name'],
                'source_content_type' => $normalized['content_type'],
            ]);
            $normalized['file_name'] = $this->canonicalBrandingFileName($slot);
            $normalized['content_type'] = (string) config('lottery_images.content_type', 'image/webp');
        }

        return $normalized;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function uploadErrors(?string $tenantId, array $payload): array
    {
        $errors = [];

        if ($tenantId !== null && array_key_exists('tenant_id', $payload) && $payload['tenant_id'] !== null && $payload['tenant_id'] !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the selected tenant.';
        }

        if (! in_array($payload['purpose'], self::PURPOSES, true)) {
            $errors['purpose'][] = 'The purpose field is invalid.';
        }

        if ($payload['purpose'] === self::PARTNER_LOTTERY_BRANDING_PURPOSE) {
            $metadata = is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [];
            $partnerId = trim((string) ($metadata['partner_id'] ?? ''));
            $slot = trim((string) ($metadata['branding_slot'] ?? ''));
            $version = trim((string) ($metadata['version'] ?? ''));

            if ($payload['expected_tenant_id'] !== null) {
                $errors['purpose'][] = 'Partner lottery branding assets must be uploaded in central scope.';
            }

            if ($partnerId === '' || ! DB::table('partners')->where('id', $partnerId)->exists()) {
                $errors['metadata.partner_id'][] = 'The metadata.partner_id field must reference an existing partner.';
            }

            if (! array_key_exists($slot, self::PARTNER_LOTTERY_BRANDING_FILES)) {
                $errors['metadata.branding_slot'][] = 'The metadata.branding_slot field is invalid.';
            }

            if ($version === '' || strlen($version) > 64 || preg_match('/^[A-Za-z0-9._-]+$/', $version) !== 1) {
                $errors['metadata.version'][] = 'The metadata.version field must be 1-64 characters and may contain letters, numbers, dot, underscore, or dash.';
            }
        }

        foreach (['file_name', 'content_type'] as $field) {
            if (! is_string($payload[$field]) || $payload[$field] === '') {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if ($payload['size_bytes'] === false || (int) $payload['size_bytes'] < 1 || (int) $payload['size_bytes'] > 52428800) {
            $errors['size_bytes'][] = 'The size_bytes field must be between 1 and 52428800.';
        }

        if ($payload['checksum_sha256'] !== null && preg_match('/^[a-f0-9]{64}$/i', $payload['checksum_sha256']) !== 1) {
            $errors['checksum_sha256'][] = 'The checksum_sha256 field must be a SHA-256 hex digest.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function commitErrors(object $asset, array $payload): array
    {
        $errors = [];
        $checksum = $this->nullableString($payload['checksum_sha256'] ?? null);

        if ($checksum !== null && preg_match('/^[a-f0-9]{64}$/i', $checksum) !== 1) {
            $errors['checksum_sha256'][] = 'The checksum_sha256 field must be a SHA-256 hex digest.';
        }

        if ($checksum !== null && $asset->checksum_sha256 !== null && strcasecmp((string) $asset->checksum_sha256, $checksum) !== 0) {
            $errors['checksum_sha256'][] = 'The checksum_sha256 field does not match the upload intent.';
        }

        if (array_key_exists('metadata', $payload) && ! is_array($payload['metadata'])) {
            $errors['metadata'][] = 'The metadata field must be an object.';
        }

        return $errors;
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function localUploadErrors(object $asset, ?UploadedFile $file): array
    {
        $errors = [];

        if (! $file instanceof UploadedFile || ! $file->isValid()) {
            $errors['file'][] = 'The file field is required and must be a valid upload.';
            return $errors;
        }

        if ((string) $asset->status !== 'pending_upload') {
            $errors['asset'][] = 'The asset must be pending upload before a local file can be stored.';
        }

        if (trim((string) $asset->storage_key) === '') {
            $errors['asset'][] = 'The asset storage key is missing.';
        }

        if ((int) $file->getSize() !== (int) $asset->size_bytes) {
            $errors['file'][] = 'The uploaded file size does not match the upload intent.';
        }

        if ((string) $asset->purpose === self::PARTNER_LOTTERY_BRANDING_PURPOSE && ! str_starts_with((string) $file->getMimeType(), 'image/')) {
            $errors['file'][] = 'The uploaded file must be an image.';
        }

        $checksum = hash_file('sha256', $file->getRealPath());

        if ($asset->checksum_sha256 !== null && is_string($checksum) && strcasecmp((string) $asset->checksum_sha256, $checksum) !== 0) {
            $errors['file'][] = 'The uploaded file checksum does not match the upload intent.';
        }

        return $errors;
    }

    private function productionStorageBlocked(): bool
    {
        return app()->isProduction();
    }

    private function assetQuery(string $scopeType, ?string $tenantId): mixed
    {
        $query = PlatformAsset::query()->where('scope_type', $scopeType);

        return $scopeType === 'tenant'
            ? $query->where('tenant_id', $tenantId)
            : $query->whereNull('tenant_id');
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function storageKey(string $scopeType, ?string $tenantId, string $assetId, array $payload): string
    {
        if ($payload['purpose'] === self::PARTNER_LOTTERY_BRANDING_PURPOSE) {
            $metadata = is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [];

            return 'partners/'.trim((string) $metadata['partner_id']).'/lottery-branding/'.$this->canonicalBrandingVersion($metadata['version'] ?? 'v1').'/'.$this->canonicalBrandingFileName((string) ($metadata['branding_slot'] ?? ''));
        }

        $fileName = (string) $payload['file_name'];
        $slug = Str::slug(pathinfo($fileName, PATHINFO_FILENAME));
        $extension = strtolower((string) pathinfo($fileName, PATHINFO_EXTENSION));
        $safeName = ($slug !== '' ? $slug : 'asset').($extension !== '' ? '.'.$extension : '');

        return $scopeType === 'tenant'
            ? 'tenants/'.$tenantId.'/assets/'.$assetId.'/'.$safeName
            : 'central/assets/'.$assetId.'/'.$safeName;
    }

    /**
     * @return array{bytes: string, content_type: string, size_bytes: int, file_name: string, metadata: array<string, mixed>}
     */
    private function localUploadPayload(object $asset, UploadedFile $file): array
    {
        $sourceBytes = file_get_contents($file->getRealPath()) ?: '';

        if ((string) $asset->purpose !== self::PARTNER_LOTTERY_BRANDING_PURPOSE) {
            return [
                'bytes' => $sourceBytes,
                'content_type' => (string) $asset->content_type,
                'size_bytes' => strlen($sourceBytes),
                'file_name' => (string) $asset->file_name,
                'metadata' => [],
            ];
        }

        $webpBytes = $this->webpBytes($sourceBytes);
        $bytes = $webpBytes ?? $sourceBytes;
        $metadata = is_array($asset->metadata_json) ? $asset->metadata_json : [];

        return [
            'bytes' => $bytes,
            'content_type' => (string) config('lottery_images.content_type', 'image/webp'),
            'size_bytes' => strlen($bytes),
            'file_name' => $this->canonicalBrandingFileName((string) ($metadata['branding_slot'] ?? '')),
            'metadata' => [
                'source_file_name' => $file->getClientOriginalName(),
                'source_content_type' => $file->getClientMimeType(),
                'source_size_bytes' => (int) $file->getSize(),
                'webp_conversion_status' => $webpBytes === null ? 'source_passthrough' : 'converted',
                'stored_checksum_sha256' => hash('sha256', $bytes),
                'stored_size_bytes' => strlen($bytes),
            ],
        ];
    }

    private function webpBytes(string $sourceBytes): ?string
    {
        if (! extension_loaded('gd') || ! function_exists('imagecreatefromstring') || ! function_exists('imagewebp')) {
            return null;
        }

        $image = @imagecreatefromstring($sourceBytes);

        if ($image === false) {
            return null;
        }

        try {
            imagepalettetotruecolor($image);
            imagealphablending($image, true);
            imagesavealpha($image, true);
            ob_start();
            $ok = imagewebp($image, null, 82);
            $bytes = ob_get_clean();

            return $ok && is_string($bytes) && $bytes !== '' ? $bytes : null;
        } finally {
            imagedestroy($image);
        }
    }

    private function canonicalBrandingFileName(string $slot): string
    {
        return self::PARTNER_LOTTERY_BRANDING_FILES[$slot] ?? 'asset.webp';
    }

    private function canonicalBrandingVersion(mixed $version): string
    {
        $value = trim((string) $version);

        return $value === '' ? 'v1' : $value;
    }

    private function publicAssetUrl(string $key): string
    {
        $baseUrl = rtrim((string) config('lottery_images.cdn_base_url', ''), '/');

        if ($baseUrl !== '') {
            return $baseUrl.'/'.ltrim($key, '/');
        }

        return Storage::disk((string) config('lottery_images.disk', 'lottery_images'))->url($key);
    }

    /**
     * @return array<string, mixed>
     */
    private function uploadIntentResource(object $asset): array
    {
        return [
            'asset_id' => (string) $asset->id,
            'upload_url' => (string) $asset->upload_url,
            'method' => 'PUT',
            'headers' => [
                'content-type' => (string) $asset->content_type,
                'x-newpaotang-storage-boundary' => 'local_dev_metadata_only',
            ],
            'form_fields' => null,
            'expires_at' => $asset->expires_at?->toISOString(),
            'public_url' => null,
            'storage_mode' => 'local_dev_metadata_only',
            'production_storage_ready' => false,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function assetResource(object $asset): array
    {
        return [
            'id' => (string) $asset->id,
            'tenant_id' => $asset->tenant_id,
            'purpose' => (string) $asset->purpose,
            'status' => (string) $asset->status,
            'content_type' => $asset->content_type,
            'size_bytes' => (int) $asset->size_bytes,
            'url' => $asset->public_url,
            'storage_key' => $asset->storage_key,
            'created_at' => $asset->created_at?->toISOString(),
            'updated_at' => $asset->updated_at?->toISOString(),
            'file_name' => $asset->file_name,
            'checksum_sha256' => $asset->checksum_sha256,
            'metadata' => $asset->metadata_json ?? [],
            'storage_mode' => 'local_dev_metadata_only',
            'production_storage_ready' => false,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(
        AdminSessionContext $actor,
        Request $request,
        string $scopeType,
        string $action,
        string $targetId,
        array $payload,
        ?string $tenantId,
    ): void {
        $partnerId = $tenantId === null ? null : PartnerTenant::whereKey($tenantId)->value('partner_id');

        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: $scopeType,
            action: $action,
            targetType: 'platform_asset',
            targetId: $targetId,
            payload: [
                'payload' => $payload,
                'storage_boundary' => 'local_dev_metadata_only',
                'production_storage_ready' => false,
                'idempotency_key' => $request->header('Idempotency-Key'),
            ],
            tenantId: $tenantId,
            partnerId: $partnerId === null ? null : (string) $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    private function nullableString(mixed $value): ?string
    {
        $string = trim((string) $value);

        return $string === '' ? null : $string;
    }
}

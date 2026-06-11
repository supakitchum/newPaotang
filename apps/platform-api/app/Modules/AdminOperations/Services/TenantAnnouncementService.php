<?php

namespace App\Modules\AdminOperations\Services;

use App\Models\PartnerTenant;
use App\Models\PlatformAsset;
use App\Models\TenantAnnouncement;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use App\Support\PublicUrl;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TenantAnnouncementService
{
    private const STATUSES = ['draft', 'active', 'inactive', 'archived'];
    private const MAX_IMAGE_BYTES = 8_388_608;
    private const PURPOSE = 'tenant_announcement_image';

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly RuntimeStorageService $storage,
    )
    {
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function list(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = TenantAnnouncement::query()
            ->forTenant($tenantId)
            ->with(['fullAsset', 'thumbAsset'])
            ->limit($limit + 1);

        $this->whereString($query, 'status', $queryParams['status'] ?? null);

        if (array_key_exists('modal_enabled', $queryParams) && $queryParams['modal_enabled'] !== null && $queryParams['modal_enabled'] !== '') {
            $query->where('modal_enabled', filter_var($queryParams['modal_enabled'], FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) === true);
        }

        if (array_key_exists('important', $queryParams) && $queryParams['important'] !== null && $queryParams['important'] !== '') {
            $query->where('important', filter_var($queryParams['important'], FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) === true);
        }

        if (($queryParams['q'] ?? null) !== null && trim((string) $queryParams['q']) !== '') {
            $q = '%'.trim((string) $queryParams['q']).'%';
            $query->where(fn ($builder) => $builder
                ->where('title', 'like', $q)
                ->orWhere('slug', 'like', $q)
                ->orWhere('summary', 'like', $q));
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '<', trim((string) $queryParams['cursor']));
        }

        $sortKey = in_array((string) ($queryParams['sort'] ?? ''), ['title', 'status', 'modal_enabled', 'important', 'sort_order', 'display_start_at', 'display_end_at', 'created_at', 'updated_at'], true)
            ? (string) $queryParams['sort']
            : 'created_at';
        $direction = strtolower((string) ($queryParams['direction'] ?? 'desc')) === 'asc' ? 'asc' : 'desc';
        $query->orderBy($sortKey, $direction)->orderBy('id', $direction);

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->resource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function find(string $tenantId, string $announcementId): ?array
    {
        $row = TenantAnnouncement::query()
            ->forTenant($tenantId)
            ->with(['fullAsset', 'thumbAsset'])
            ->where('id', $announcementId)
            ->first();

        return $row === null ? null : $this->resource($row);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function create(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $normalized = $this->payload($tenantId, $payload, true);
        $errors = $this->errors($tenantId, $normalized, true);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (TenantAnnouncement::query()->forTenant($tenantId)->where('slug', $normalized['slug'])->exists()) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $payload, $normalized, $actor, $request, $tenant): array {
            $announcementId = 'ann_'.Str::ulid()->toBase32();

            TenantAnnouncement::query()->create($normalized + [
                'id' => $announcementId,
                'tenant_id' => $tenantId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, 'announcement.created', $announcementId, $payload, $tenantId, (string) $tenant->partner_id);

            return ['resource' => $this->find($tenantId, $announcementId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function update(string $tenantId, string $announcementId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $announcement = TenantAnnouncement::query()->forTenant($tenantId)->where('id', $announcementId)->first();

        if ($announcement === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();
        $normalized = $this->payload($tenantId, $payload, false, $announcement);
        $errors = $this->errors($tenantId, $normalized, false);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            array_key_exists('slug', $normalized)
            && TenantAnnouncement::query()->forTenant($tenantId)->where('slug', $normalized['slug'])->where('id', '!=', $announcementId)->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $announcementId, $payload, $normalized, $actor, $request, $tenant): array {
            if ($normalized !== []) {
                TenantAnnouncement::query()->forTenant($tenantId)->where('id', $announcementId)->update($normalized + ['updated_at' => now()]);
            }

            $this->audit($actor, $request, 'announcement.updated', $announcementId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => $this->find($tenantId, $announcementId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, status?: int}
     */
    public function delete(string $tenantId, string $announcementId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $announcement = TenantAnnouncement::query()->forTenant($tenantId)->where('id', $announcementId)->first();

        if ($announcement === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();

        return DB::transaction(function () use ($tenantId, $announcementId, $payload, $actor, $request, $tenant): array {
            TenantAnnouncement::query()->forTenant($tenantId)->where('id', $announcementId)->update([
                'status' => 'archived',
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, 'announcement.archived', $announcementId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => [], 'status' => 204];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function uploadImage(string $tenantId, string $announcementId, ?UploadedFile $file, AdminSessionContext $actor, Request $request): array
    {
        $announcement = TenantAnnouncement::query()->forTenant($tenantId)->where('id', $announcementId)->first();

        if ($announcement === null) {
            return ['error' => 'not_found'];
        }

        $errors = $this->imageErrors($file);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();

        return DB::transaction(function () use ($tenantId, $announcementId, $file, $actor, $request, $tenant): array {
            /** @var UploadedFile $file */
            $sourceBytes = file_get_contents($file->getRealPath()) ?: '';
            $variants = [
                'full' => $this->variantPayload($sourceBytes, 1080, 82, $file),
                'thumb' => $this->variantPayload($sourceBytes, 480, 76, $file),
            ];
            $assetIds = [];

            foreach ($variants as $variant => $variantPayload) {
                $assetIds[$variant] = $this->storeVariantAsset($tenantId, $announcementId, $variant, $variantPayload, $actor);
            }

            TenantAnnouncement::query()->forTenant($tenantId)->where('id', $announcementId)->update([
                'image_full_asset_id' => $assetIds['full'],
                'image_thumb_asset_id' => $assetIds['thumb'],
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, 'announcement.image_uploaded', $announcementId, [
                'source_file_name' => $file->getClientOriginalName(),
                'source_size_bytes' => (int) $file->getSize(),
            ], $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => $this->find($tenantId, $announcementId)];
        });
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, content_source_status: string}
     */
    public function publicList(string $tenantId, int $limit = 10): array
    {
        $rows = $this->activeQuery($tenantId)
            ->where('status', 'active')
            ->orderByDesc('important')
            ->orderByDesc('sort_order')
            ->orderByDesc('updated_at')
            ->limit(max(1, min(50, $limit)))
            ->get()
            ->all();

        return [
            'data' => array_map(fn (object $row): array => $this->publicResource($row), $rows),
            'content_source_status' => $rows === [] ? 'empty' : 'configured',
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function publicModal(string $tenantId): ?array
    {
        $important = $this->activeQuery($tenantId)
            ->where('modal_enabled', true)
            ->where('important', true)
            ->orderByDesc('sort_order')
            ->orderByDesc('updated_at')
            ->first();

        if ($important !== null) {
            return $this->publicResource($important);
        }

        $rows = $this->activeQuery($tenantId)
            ->where('modal_enabled', true)
            ->get()
            ->all();

        if ($rows === []) {
            return null;
        }

        return $this->publicResource($rows[array_rand($rows)]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function publicFindBySlug(string $tenantId, string $slug): ?array
    {
        $row = $this->activeQuery($tenantId)
            ->where('slug', $this->normalizeSlug($slug))
            ->first();

        return $row === null ? null : $this->publicResource($row, true);
    }

    private function activeQuery(string $tenantId): mixed
    {
        $now = now();

        return TenantAnnouncement::query()
            ->forTenant($tenantId)
            ->with(['fullAsset', 'thumbAsset'])
            ->where('status', 'active')
            ->where(fn ($query) => $query->whereNull('display_start_at')->orWhere('display_start_at', '<=', $now))
            ->where(fn ($query) => $query->whereNull('display_end_at')->orWhere('display_end_at', '>', $now));
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function payload(string $tenantId, array $payload, bool $creating, ?object $existing = null): array
    {
        $title = array_key_exists('title', $payload) ? trim((string) $payload['title']) : null;
        $slugSource = array_key_exists('slug', $payload)
            ? (string) $payload['slug']
            : ($creating && $title !== null ? $title : null);

        return array_filter([
            'tenant_id' => $payload['tenant_id'] ?? null,
            'title' => $title,
            'title_i18n' => array_key_exists('title_i18n', $payload) ? $this->normalizedLocalizedText($payload['title_i18n']) : null,
            'slug' => $slugSource === null ? null : $this->normalizeSlug($slugSource),
            'summary' => array_key_exists('summary', $payload) ? $this->nullableString($payload['summary']) : null,
            'summary_i18n' => array_key_exists('summary_i18n', $payload) ? $this->normalizedLocalizedText($payload['summary_i18n']) : null,
            'body' => array_key_exists('body', $payload) ? $this->nullableString($payload['body']) : null,
            'body_i18n' => array_key_exists('body_i18n', $payload) ? $this->normalizedLocalizedText($payload['body_i18n']) : null,
            'status' => array_key_exists('status', $payload) ? trim((string) $payload['status']) : ($creating ? 'draft' : null),
            'modal_enabled' => array_key_exists('modal_enabled', $payload) ? (bool) filter_var($payload['modal_enabled'], FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) : ($creating ? true : null),
            'important' => array_key_exists('important', $payload) ? (bool) filter_var($payload['important'], FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) : ($creating ? false : null),
            'display_start_at' => array_key_exists('display_start_at', $payload) ? $this->nullableDateTime($payload['display_start_at']) : null,
            'display_end_at' => array_key_exists('display_end_at', $payload) ? $this->nullableDateTime($payload['display_end_at']) : null,
            'sort_order' => array_key_exists('sort_order', $payload) ? filter_var($payload['sort_order'], FILTER_VALIDATE_INT) : ($creating ? 0 : null),
            'metadata_json' => array_key_exists('metadata', $payload) && is_array($payload['metadata'])
                ? array_replace_recursive(is_array($existing?->metadata_json) ? $existing->metadata_json : [], $payload['metadata'])
                : null,
        ], fn (mixed $value): bool => $value !== null);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function errors(string $tenantId, array $payload, bool $creating): array
    {
        $errors = [];

        if (array_key_exists('tenant_id', $payload) && $payload['tenant_id'] !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the selected tenant.';
        }

        foreach (['title', 'slug'] as $field) {
            if ($creating && (! array_key_exists($field, $payload) || trim((string) $payload[$field]) === '')) {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (array_key_exists('title', $payload) && (trim((string) $payload['title']) === '' || mb_strlen((string) $payload['title']) > 255)) {
            $errors['title'][] = 'The title field must be 1-255 characters.';
        }

        if (array_key_exists('slug', $payload) && (trim((string) $payload['slug']) === '' || strlen((string) $payload['slug']) > 180)) {
            $errors['slug'][] = 'The slug field must be 1-180 characters.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('sort_order', $payload) && $payload['sort_order'] === false) {
            $errors['sort_order'][] = 'The sort_order field must be an integer.';
        }

        foreach (['title_i18n', 'summary_i18n', 'body_i18n'] as $field) {
            if (array_key_exists($field, $payload) && ! is_array($payload[$field])) {
                $errors[$field][] = 'The '.$field.' field must be an object keyed by locale.';
            }
        }

        foreach (['display_start_at', 'display_end_at'] as $field) {
            if (array_key_exists($field, $payload) && $payload[$field] === false) {
                $errors[$field][] = 'The '.$field.' field must be a valid date time.';
            }
        }

        if (
            array_key_exists('display_start_at', $payload)
            && array_key_exists('display_end_at', $payload)
            && $payload['display_start_at'] instanceof Carbon
            && $payload['display_end_at'] instanceof Carbon
            && $payload['display_end_at']->lte($payload['display_start_at'])
        ) {
            $errors['display_end_at'][] = 'The display_end_at field must be after display_start_at.';
        }

        return $errors;
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function imageErrors(?UploadedFile $file): array
    {
        $errors = [];

        if (! $file instanceof UploadedFile || ! $file->isValid()) {
            return ['file' => ['The file field is required and must be a valid upload.']];
        }

        if ((int) $file->getSize() < 1 || (int) $file->getSize() > self::MAX_IMAGE_BYTES) {
            $errors['file'][] = 'The image file must be between 1 byte and 8 MB.';
        }

        if (! str_starts_with((string) $file->getMimeType(), 'image/')) {
            $errors['file'][] = 'The uploaded file must be an image.';
        }

        return $errors;
    }

    /**
     * @return array{bytes: string, content_type: string, file_name: string, size_bytes: int, metadata: array<string, mixed>}
     */
    private function variantPayload(string $sourceBytes, int $maxWidth, int $quality, UploadedFile $file): array
    {
        $webpBytes = $this->resizedWebpBytes($sourceBytes, $maxWidth, $quality);
        $bytes = $webpBytes ?? $sourceBytes;
        $contentType = $webpBytes === null ? (string) ($file->getMimeType() ?: 'application/octet-stream') : 'image/webp';

        return [
            'bytes' => $bytes,
            'content_type' => $contentType,
            'file_name' => $webpBytes === null ? $file->getClientOriginalName() : 'announcement.webp',
            'size_bytes' => strlen($bytes),
            'metadata' => [
                'source_file_name' => $file->getClientOriginalName(),
                'source_content_type' => $file->getClientMimeType(),
                'source_size_bytes' => (int) $file->getSize(),
                'max_width' => $maxWidth,
                'webp_conversion_status' => $webpBytes === null ? 'source_passthrough' : 'converted',
                'stored_checksum_sha256' => hash('sha256', $bytes),
            ],
        ];
    }

    private function resizedWebpBytes(string $sourceBytes, int $maxWidth, int $quality): ?string
    {
        if (! extension_loaded('gd') || ! function_exists('imagecreatefromstring') || ! function_exists('imagewebp')) {
            return null;
        }

        $image = @imagecreatefromstring($sourceBytes);

        if ($image === false) {
            return null;
        }

        try {
            $width = imagesx($image);
            $height = imagesy($image);
            $ratio = $width > $maxWidth ? $maxWidth / max(1, $width) : 1;
            $targetWidth = max(1, (int) round($width * $ratio));
            $targetHeight = max(1, (int) round($height * $ratio));
            $canvas = imagecreatetruecolor($targetWidth, $targetHeight);

            imagealphablending($canvas, false);
            imagesavealpha($canvas, true);
            imagecopyresampled($canvas, $image, 0, 0, 0, 0, $targetWidth, $targetHeight, $width, $height);

            ob_start();
            $ok = imagewebp($canvas, null, $quality);
            $bytes = ob_get_clean();
            imagedestroy($canvas);

            return $ok && is_string($bytes) && $bytes !== '' ? $bytes : null;
        } finally {
            imagedestroy($image);
        }
    }

    /**
     * @param array{bytes: string, content_type: string, file_name: string, size_bytes: int, metadata: array<string, mixed>} $payload
     */
    private function storeVariantAsset(string $tenantId, string $announcementId, string $variant, array $payload, AdminSessionContext $actor): string
    {
        $assetId = 'ast_'.Str::ulid()->toBase32();
        $extension = $payload['content_type'] === 'image/webp'
            ? 'webp'
            : strtolower((string) pathinfo($payload['file_name'], PATHINFO_EXTENSION));
        $extension = $extension !== '' ? $extension : 'img';
        $storageKey = 'tenants/'.$tenantId.'/announcements/'.$announcementId.'/'.$variant.'.'.$extension;

        $storageKey = $this->storage->put(
            RuntimeStorageService::ROUTE_ANNOUNCEMENT_IMAGES,
            $storageKey,
            $payload['bytes'],
            ['ContentType' => $payload['content_type']],
        );

        PlatformAsset::query()->create([
            'id' => $assetId,
            'scope_type' => 'tenant',
            'tenant_id' => $tenantId,
            'created_by_admin_id' => $actor->adminUser['id'],
            'purpose' => self::PURPOSE,
            'file_name' => 'announcement-'.$variant.'.'.$extension,
            'content_type' => $payload['content_type'],
            'size_bytes' => $payload['size_bytes'],
            'checksum_sha256' => $payload['metadata']['stored_checksum_sha256'] ?? null,
            'status' => 'committed',
            'storage_key' => $storageKey,
            'upload_url' => null,
            'public_url' => $this->storage->publicUrl(RuntimeStorageService::ROUTE_ANNOUNCEMENT_IMAGES, $storageKey),
            'metadata_json' => $payload['metadata'] + [
                'announcement_id' => $announcementId,
                'variant' => $variant,
                'storage_route' => RuntimeStorageService::ROUTE_ANNOUNCEMENT_IMAGES,
            ],
            'expires_at' => null,
            'committed_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $assetId;
    }

    /**
     * @return array<string, mixed>
     */
    private function resource(object $row): array
    {
        $fullAsset = $row->relationLoaded('fullAsset') ? $row->fullAsset : null;
        $thumbAsset = $row->relationLoaded('thumbAsset') ? $row->thumbAsset : null;
        $fullUrl = PublicUrl::normalizeAssetUrl($fullAsset?->public_url);
        $thumbUrl = PublicUrl::normalizeAssetUrl($thumbAsset?->public_url) ?: $fullUrl;

        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'title' => (string) $row->title,
            'title_i18n' => $this->decodedLocalizedText($row->title_i18n ?? null),
            'slug' => (string) $row->slug,
            'summary' => $row->summary,
            'summary_i18n' => $this->decodedLocalizedText($row->summary_i18n ?? null),
            'body' => $row->body,
            'body_i18n' => $this->decodedLocalizedText($row->body_i18n ?? null),
            'status' => (string) $row->status,
            'modal_enabled' => (bool) $row->modal_enabled,
            'important' => (bool) $row->important,
            'display_start_at' => $row->display_start_at?->toISOString(),
            'display_end_at' => $row->display_end_at?->toISOString(),
            'sort_order' => (int) $row->sort_order,
            'image_full_asset_id' => $row->image_full_asset_id,
            'image_thumb_asset_id' => $row->image_thumb_asset_id,
            'image_full_url' => $fullUrl,
            'image_thumb_url' => $thumbUrl,
            'cover' => $thumbUrl,
            'cover_url' => $thumbUrl,
            'url' => '/news/'.(string) $row->slug,
            'metadata' => $row->metadata_json ?? [],
            'created_at' => $row->created_at?->toISOString(),
            'updated_at' => $row->updated_at?->toISOString(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function publicResource(object $row, bool $includeBody = false): array
    {
        $resource = $this->resource($row);
        $resource['title'] = $this->localizedText($row->title_i18n ?? null, $row->title) ?? '';
        $resource['summary'] = $this->localizedText($row->summary_i18n ?? null, $row->summary);

        if ($includeBody) {
            $resource['body'] = $this->localizedText($row->body_i18n ?? null, $row->body);
        }

        if (! $includeBody) {
            unset($resource['body']);
        }

        return $resource;
    }

    private function normalizeSlug(string $value): string
    {
        $slug = Str::slug(trim($value), '-', 'th');

        if ($slug === '') {
            $slug = strtolower(preg_replace('/[^A-Za-z0-9]+/', '-', trim($value)) ?: '');
            $slug = trim($slug, '-');
        }

        return substr($slug !== '' ? $slug : 'news-'.Str::lower(Str::random(8)), 0, 180);
    }

    private function nullableString(mixed $value): ?string
    {
        $string = trim((string) $value);

        return $string === '' ? null : $string;
    }

    private function nullableDateTime(mixed $value): mixed
    {
        $string = trim((string) $value);

        if ($string === '') {
            return null;
        }

        try {
            return Carbon::parse($string);
        } catch (\Throwable) {
            return false;
        }
    }

    private function whereString(mixed $query, string $field, mixed $value): void
    {
        if ($value !== null && trim((string) $value) !== '') {
            $query->where($field, trim((string) $value));
        }
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        return $limit === false ? 20 : max(1, min(100, $limit));
    }

    /**
     * @param mixed $value
     * @return array<string, string>
     */
    private function normalizedLocalizedText(mixed $value): array
    {
        if (is_string($value) && trim($value) !== '') {
            $decoded = json_decode($value, true);
            $value = is_array($decoded) ? $decoded : [];
        }

        if (! is_array($value)) {
            return [];
        }

        $normalized = [];

        foreach ($value as $locale => $text) {
            $canonicalLocale = $this->canonicalLocale($locale);
            $string = trim((string) $text);

            if ($canonicalLocale !== null && $string !== '') {
                $normalized[$canonicalLocale] = $string;
            }
        }

        return $normalized;
    }

    /**
     * @param mixed $value
     * @return array<string, string>
     */
    private function decodedLocalizedText(mixed $value): array
    {
        return $this->normalizedLocalizedText($value);
    }

    private function localizedText(mixed $localized, mixed $fallback): ?string
    {
        $translations = $this->normalizedLocalizedText($localized);
        $locale = $this->canonicalLocale(app()->getLocale()) ?? 'th-TH';
        $fallbackText = trim((string) $fallback);

        return $translations[$locale]
            ?? $translations['th-TH']
            ?? ($fallbackText !== '' ? $fallbackText : null);
    }

    private function canonicalLocale(mixed $value): ?string
    {
        $locale = str_replace('_', '-', strtolower(trim((string) $value)));

        return match ($locale) {
            'th', 'th-th' => 'th-TH',
            'en', 'en-us', 'en-gb' => 'en-US',
            default => null,
        };
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(
        AdminSessionContext $actor,
        Request $request,
        string $action,
        string $targetId,
        array $payload,
        string $tenantId,
        ?string $partnerId,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'tenant',
            action: $action,
            targetType: 'tenant_announcement',
            targetId: $targetId,
            payload: [
                'payload' => $payload,
                'idempotency_key' => $request->header('Idempotency-Key'),
            ],
            tenantId: $tenantId,
            partnerId: $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }
}

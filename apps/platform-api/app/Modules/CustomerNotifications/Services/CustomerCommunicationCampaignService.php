<?php

namespace App\Modules\CustomerNotifications\Services;

use App\Models\Customer;
use App\Models\CustomerCommunicationCampaign;
use App\Models\PlatformAsset;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Support\PublicUrl;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CustomerCommunicationCampaignService
{
    private const AUDIENCES = [
        'all_customers',
        'all_installations',
        'anonymous_installations',
        'customer',
    ];

    private const INSTALLATION_AUDIENCES = ['all_installations', 'anonymous_installations'];
    private const STATUSES = ['scheduled', 'published', 'cancelled', 'failed'];
    private const MAX_IMAGE_BYTES = 8_388_608;
    private const ALLOWED_IMAGE_MIMES = ['image/jpeg', 'image/png', 'image/webp'];
    private const PURPOSE = 'customer_communication_image';

    public function __construct(
        private readonly CustomerNotificationService $notifications,
        private readonly RuntimeStorageService $storage,
        private readonly AuditLogger $auditLogger,
    ) {
    }

    /**
     * @param array<string, mixed> $query
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function list(string $tenantId, array $query): array
    {
        $limit = max(1, min(50, (int) ($query['limit'] ?? 20)));
        $builder = CustomerCommunicationCampaign::query()
            ->forTenant($tenantId)
            ->with(['customer', 'creator', 'fullAsset', 'thumbAsset']);

        $status = trim((string) ($query['status'] ?? ''));
        if ($status !== '' && in_array($status, self::STATUSES, true)) {
            $builder->where('status', $status);
        }

        $audience = trim((string) ($query['audience_type'] ?? ''));
        if ($audience !== '' && in_array($audience, self::AUDIENCES, true)) {
            $builder->where('audience_type', $audience);
        }

        $search = Str::lower(trim((string) ($query['q'] ?? '')));
        if ($search !== '') {
            $like = '%'.$search.'%';
            $builder->where(function (Builder $query) use ($like): void {
                $query
                    ->whereRaw('LOWER(name) LIKE ?', [$like])
                    ->orWhereRaw('LOWER(id) LIKE ?', [$like])
                    ->orWhereRaw("LOWER(COALESCE(notification_id, '')) LIKE ?", [$like])
                    ->orWhereHas('customer', function (Builder $customerQuery) use ($like): void {
                        $customerQuery
                            ->whereRaw("LOWER(COALESCE(name, '')) LIKE ?", [$like])
                            ->orWhereRaw("LOWER(COALESCE(phone, '')) LIKE ?", [$like])
                            ->orWhereRaw("LOWER(COALESCE(customer_no, '')) LIKE ?", [$like]);
                    });
            });
        }

        $cursor = trim((string) ($query['cursor'] ?? ''));
        if ($cursor !== '') {
            $builder->where('id', '<', $cursor);
        }

        $rows = $builder->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $rows = $rows->take($limit)->values();
        $notificationIds = $rows->pluck('notification_id')->filter()->values()->all();
        $stats = $this->deliveryStats($notificationIds);

        return [
            'data' => $rows->map(fn (CustomerCommunicationCampaign $campaign): array => $this->resource(
                $campaign,
                $stats[(string) $campaign->notification_id] ?? null,
            ))->all(),
            'meta' => [
                'next_cursor' => $hasMore && $rows->isNotEmpty() ? (string) $rows->last()->id : null,
                'has_more' => $hasMore,
                'action_options' => $this->notifications->adminActionOptions(),
                'campaign_counts' => $this->campaignCounts($tenantId),
                ...$this->notifications->adminAudienceCounts($tenantId),
            ],
        ];
    }

    /** @return array<string, mixed>|null */
    public function detail(string $tenantId, string $campaignId): ?array
    {
        $campaign = CustomerCommunicationCampaign::query()
            ->forTenant($tenantId)
            ->with(['customer', 'creator', 'fullAsset', 'thumbAsset'])
            ->whereKey($campaignId)
            ->first();

        if ($campaign === null) return null;

        $notificationId = trim((string) $campaign->notification_id);
        $stats = $notificationId === ''
            ? null
            : ($this->deliveryStats([$notificationId])[$notificationId] ?? null);

        return [
            ...$this->resource($campaign, $stats),
            'delivery_breakdown' => $this->deliveryBreakdown($notificationId),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function create(
        string $tenantId,
        AdminSessionContext $actor,
        array $payload,
        ?UploadedFile $image,
        Request $request,
        string $idempotencyKey,
    ): array {
        $normalized = $this->normalizePayload($payload);
        [$scheduledAt, $scheduledAtInvalid] = $this->normalizeScheduledAt($normalized);
        $errors = $this->errors($tenantId, $normalized, $image, $scheduledAt, $scheduledAtInvalid);
        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $dedupeKey = hash('sha256', 'admin:'.$actor->adminUser['id'].':'.$idempotencyKey);
        $existing = CustomerCommunicationCampaign::query()
            ->forTenant($tenantId)
            ->with(['customer', 'creator', 'fullAsset', 'thumbAsset'])
            ->where('dedupe_key', $dedupeKey)
            ->first();
        if ($existing !== null) {
            return ['resource' => $this->resource($existing)];
        }

        $campaignId = 'ccp_'.Str::ulid()->toBase32();
        $assetIds = $image instanceof UploadedFile
            ? $this->storeImageVariants($tenantId, $campaignId, $image, $actor)
            : ['full' => null, 'thumb' => null];
        $status = 'scheduled';

        $campaign = CustomerCommunicationCampaign::query()->create([
            'id' => $campaignId,
            'tenant_id' => $tenantId,
            'name' => $normalized['name'],
            'audience_type' => $normalized['audience_type'],
            'customer_id' => $normalized['audience_type'] === 'customer' ? $normalized['customer_id'] : null,
            'status' => $status,
            'title_json' => $normalized['title'],
            'body_json' => $normalized['body'],
            'action_key' => $normalized['action_key'],
            'action_entity_id' => $normalized['action_entity_id'],
            'image_full_asset_id' => $assetIds['full'],
            'image_thumb_asset_id' => $assetIds['thumb'],
            'created_by_admin_id' => (string) $actor->adminUser['id'],
            'dedupe_key' => $dedupeKey,
            'scheduled_at' => $scheduledAt,
            'metadata_json' => ['request_id' => $request->header('X-Request-Id')],
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->audit($campaign, $actor, $request, 'customer_communication.created');

        if ($scheduledAt === null) {
            try {
                $published = $this->publishCampaign($tenantId, $campaignId);
            } catch (\Throwable $exception) {
                CustomerCommunicationCampaign::query()->whereKey($campaignId)->update([
                    'status' => 'failed',
                    'last_error_code' => 'publish_failed',
                    'updated_at' => now(),
                ]);
                throw $exception;
            }
            if (($published['error'] ?? null) !== null) {
                return $published;
            }
            $campaign = CustomerCommunicationCampaign::query()->with(['customer', 'creator', 'fullAsset', 'thumbAsset'])
                ->whereKey($campaignId)
                ->firstOrFail();
        } else {
            $campaign->load(['customer', 'creator', 'fullAsset', 'thumbAsset']);
        }

        return ['resource' => $this->resource($campaign)];
    }

    /** @return array{resource?: array<string, mixed>, error?: string} */
    public function publishNow(string $tenantId, string $campaignId, AdminSessionContext $actor, Request $request): array
    {
        $result = $this->publishCampaign($tenantId, $campaignId, true);
        if (($result['resource'] ?? null) !== null) {
            $campaign = CustomerCommunicationCampaign::query()->forTenant($tenantId)->whereKey($campaignId)->first();
            if ($campaign !== null) {
                $this->audit($campaign, $actor, $request, 'customer_communication.published');
            }
        }

        return $result;
    }

    /** @return array{resource?: array<string, mixed>, error?: string} */
    public function cancel(string $tenantId, string $campaignId, AdminSessionContext $actor, Request $request): array
    {
        $campaign = CustomerCommunicationCampaign::query()
            ->forTenant($tenantId)
            ->whereKey($campaignId)
            ->first();
        if ($campaign === null) {
            return ['error' => 'not_found'];
        }
        if ($campaign->status === 'published') {
            return ['error' => 'resource_conflict'];
        }
        if ($campaign->status !== 'cancelled') {
            $campaign->forceFill([
                'status' => 'cancelled',
                'cancelled_at' => now(),
                'updated_at' => now(),
            ])->save();
            $this->audit($campaign, $actor, $request, 'customer_communication.cancelled');
        }

        return ['resource' => $this->resource($campaign->fresh(['customer', 'creator', 'fullAsset', 'thumbAsset']))];
    }

    /** @return array{selected: int, published: int, failed: int} */
    public function publishDue(int $limit = 25): array
    {
        $ids = CustomerCommunicationCampaign::query()
            ->where('status', 'scheduled')
            ->whereNotNull('scheduled_at')
            ->where('scheduled_at', '<=', now())
            ->orderBy('scheduled_at')
            ->orderBy('id')
            ->limit(max(1, min(100, $limit)))
            ->pluck('id')
            ->map(static fn (mixed $id): string => (string) $id)
            ->all();
        $published = 0;
        $failed = 0;

        foreach ($ids as $id) {
            $campaign = CustomerCommunicationCampaign::query()->whereKey($id)->first();
            if ($campaign === null) {
                continue;
            }
            try {
                $result = $this->publishCampaign((string) $campaign->tenant_id, $id);
                ($result['error'] ?? null) === null ? $published++ : $failed++;
            } catch (\Throwable) {
                $failed++;
                CustomerCommunicationCampaign::query()->whereKey($id)->update([
                    'status' => 'failed',
                    'last_error_code' => 'publish_failed',
                    'updated_at' => now(),
                ]);
            }
        }

        return ['selected' => count($ids), 'published' => $published, 'failed' => $failed];
    }

    /** @return array{resource?: array<string, mixed>, error?: string} */
    private function publishCampaign(string $tenantId, string $campaignId, bool $force = false): array
    {
        return DB::transaction(function () use ($tenantId, $campaignId, $force): array {
            $campaign = CustomerCommunicationCampaign::query()
                ->forTenant($tenantId)
                ->with(['customer', 'creator', 'fullAsset', 'thumbAsset'])
                ->whereKey($campaignId)
                ->lockForUpdate()
                ->first();
            if ($campaign === null) {
                return ['error' => 'not_found'];
            }
            if ($campaign->status === 'published') {
                return ['resource' => $this->resource($campaign)];
            }
            if ($campaign->status === 'cancelled') {
                return ['error' => 'resource_conflict'];
            }
            if (! $force && $campaign->scheduled_at !== null && $campaign->scheduled_at->isFuture()) {
                return ['error' => 'resource_conflict'];
            }

            $campaign->forceFill(['status' => 'publishing', 'last_error_code' => null, 'updated_at' => now()])->save();
            $imageUrl = PublicUrl::normalizeAssetUrl($campaign->fullAsset?->public_url);
            $thumbUrl = PublicUrl::normalizeAssetUrl($campaign->thumbAsset?->public_url) ?: $imageUrl;
            $content = [
                'category' => 'admin',
                'title' => $campaign->title_json,
                'body' => $campaign->body_json,
                'icon_key' => 'campaign',
                'action_key' => $campaign->action_key,
                'action_entity_id' => $campaign->action_entity_id,
                'subject_type' => 'customer_communication_campaign',
                'subject_id' => $campaign->id,
            ];
            $context = [
                'creator_type' => 'tenant_admin',
                'creator_id' => (string) $campaign->created_by_admin_id,
                'dedupe_key' => 'campaign:'.$campaign->id,
                'metadata' => [
                    'campaign_id' => (string) $campaign->id,
                    'campaign_name' => (string) $campaign->name,
                    'audience' => (string) $campaign->audience_type,
                    'image_url' => $imageUrl,
                    'image_thumb_url' => $thumbUrl,
                ],
                'broadcast_after_commit' => true,
            ];

            if ($campaign->audience_type === 'all_customers') {
                $notificationId = $this->notifications->createForTenantAudience(
                    $tenantId,
                    'admin.communication_campaign',
                    $content,
                    $context,
                );
            } elseif (in_array((string) $campaign->audience_type, self::INSTALLATION_AUDIENCES, true)) {
                $notificationId = $this->notifications->createForInstallationAudience(
                    $tenantId,
                    (string) $campaign->audience_type,
                    'admin.communication_campaign',
                    $content,
                    $context,
                );
            } else {
                $resource = $this->notifications->createForCustomer(
                    $tenantId,
                    (string) $campaign->customer_id,
                    'admin.communication_campaign',
                    $content,
                    $context,
                );
                $notificationId = is_array($resource) ? (string) ($resource['id'] ?? '') : '';
            }

            if ($notificationId === null || $notificationId === '') {
                $campaign->forceFill([
                    'status' => 'failed',
                    'last_error_code' => 'audience_unavailable',
                    'updated_at' => now(),
                ])->save();
                return ['error' => 'not_found'];
            }

            $campaign->forceFill([
                'status' => 'published',
                'notification_id' => $notificationId,
                'published_at' => now(),
                'last_error_code' => null,
                'updated_at' => now(),
            ])->save();

            return ['resource' => $this->resource($campaign->fresh(['customer', 'creator', 'fullAsset', 'thumbAsset']))];
        });
    }

    /** @param array<string, mixed> $payload @return array<string, mixed> */
    private function normalizePayload(array $payload): array
    {
        $title = $this->localizedMap($payload['title'] ?? []);
        $body = $this->localizedMap($payload['body'] ?? []);
        $audience = trim((string) ($payload['audience_type'] ?? 'all_customers'));
        $deliveryMode = trim((string) ($payload['delivery_mode'] ?? 'now'));
        $actionEntityId = trim((string) ($payload['action_entity_id'] ?? ''));

        return [
            'name' => Str::limit(trim((string) ($payload['name'] ?? '')) ?: ($title['th-TH'] ?? $title['en-US'] ?? 'Campaign'), 160, ''),
            'audience_type' => $audience,
            'customer_id' => trim((string) ($payload['customer_id'] ?? '')),
            'title' => $title,
            'body' => $body,
            'action_key' => trim((string) ($payload['action_key'] ?? 'none')) ?: 'none',
            'action_entity_id' => $actionEntityId === '' ? null : $actionEntityId,
            'delivery_mode' => $deliveryMode,
            'scheduled_at' => trim((string) ($payload['scheduled_at'] ?? '')),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{0: Carbon|null, 1: bool}
     */
    private function normalizeScheduledAt(array $payload): array
    {
        if ($payload['delivery_mode'] !== 'scheduled') {
            return [null, false];
        }

        $value = (string) $payload['scheduled_at'];
        if (preg_match('/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,6})?)?(?:Z|[+-]\d{2}:\d{2})\z/D', $value) !== 1) {
            return [null, true];
        }

        try {
            // Eloquent omits offsets in SQL, so its clock value must match the DB session timezone.
            $scheduledAt = Carbon::parse($value)->setTimezone($this->persistenceTimezone());
        } catch (\Throwable) {
            return [null, true];
        }

        return [$scheduledAt, false];
    }

    private function persistenceTimezone(): string
    {
        $timezone = DB::connection()->getConfig('timezone');

        return is_string($timezone) && trim($timezone) !== ''
            ? $timezone
            : (string) config('app.timezone', 'UTC');
    }

    /** @param array<string, mixed> $payload @return array<string, array<int, string>> */
    private function errors(
        string $tenantId,
        array $payload,
        ?UploadedFile $image,
        ?Carbon $scheduledAt,
        bool $scheduledAtInvalid,
    ): array
    {
        $errors = [];
        if (! in_array($payload['audience_type'], self::AUDIENCES, true)) {
            $errors['audience_type'][] = 'The campaign audience is invalid.';
        }
        $customerExists = $payload['audience_type'] === 'customer'
            && $payload['customer_id'] !== ''
            && Customer::query()->forTenant($tenantId)->whereKey($payload['customer_id'])->where('status', 'active')->exists();
        if ($payload['audience_type'] === 'customer' && ! $customerExists) {
            $errors['customer_id'][] = 'Select an active customer in this tenant.';
        }
        if ($payload['title'] === []) {
            $errors['title'][] = 'At least one localized title is required.';
        }
        if ($payload['body'] === []) {
            $errors['body'][] = 'At least one localized message is required.';
        }
        foreach ($payload['title'] as $value) {
            if (mb_strlen($value) > 160) $errors['title'][] = 'Campaign titles must not exceed 160 characters.';
        }
        foreach ($payload['body'] as $value) {
            if (mb_strlen($value) > 1000) $errors['body'][] = 'Campaign messages must not exceed 1000 characters.';
        }

        $actionOptions = collect($this->notifications->adminActionOptions())->keyBy('key');
        $action = $actionOptions->get($payload['action_key']);
        if (! is_array($action)) {
            $errors['action_key'][] = 'The campaign destination is invalid.';
        } elseif (($action['entity_required'] ?? false) && $payload['action_entity_id'] === null) {
            $errors['action_entity_id'][] = 'The selected destination requires a record ID.';
        }
        if ($payload['action_entity_id'] !== null && (
            mb_strlen($payload['action_entity_id']) > 100
            || str_contains($payload['action_entity_id'], '://')
            || preg_match('/[\/?#]/u', $payload['action_entity_id']) === 1
        )) {
            $errors['action_entity_id'][] = 'The destination record ID format is invalid.';
        }
        if ($payload['audience_type'] !== 'customer'
            && ($action['entity_required'] ?? false)
            && ! in_array($payload['action_key'], ['activity', 'news'], true)) {
            $errors['action_key'][] = 'This record-specific destination cannot be broadcast to every customer.';
        }

        if (! in_array($payload['delivery_mode'], ['now', 'scheduled'], true)) {
            $errors['delivery_mode'][] = 'The delivery mode must be now or scheduled.';
        } elseif ($payload['delivery_mode'] === 'scheduled') {
            if ($scheduledAtInvalid || $scheduledAt === null) {
                $errors['scheduled_at'][] = 'Enter a valid campaign date and time with a timezone offset.';
            } else {
                if ($scheduledAt->lessThanOrEqualTo(now()->addMinute())) {
                    $errors['scheduled_at'][] = 'Schedule the campaign at least one minute in the future.';
                }
                if ($scheduledAt->greaterThan(now()->addYear())) {
                    $errors['scheduled_at'][] = 'Campaigns can be scheduled up to one year ahead.';
                }
            }
        }

        if ($image !== null) {
            if (! $image->isValid()) {
                $errors['file'][] = 'The image upload is invalid.';
            } elseif ((int) $image->getSize() < 1 || (int) $image->getSize() > self::MAX_IMAGE_BYTES) {
                $errors['file'][] = 'The image must not exceed 8 MB.';
            } else {
                $bytes = file_get_contents($image->getRealPath());
                $mime = is_string($bytes) ? $this->imageMime($bytes) : null;
                if ($mime === null || ! in_array($mime, self::ALLOWED_IMAGE_MIMES, true)) {
                    $errors['file'][] = 'The image must be a valid JPG, PNG, or WebP file.';
                }
            }
        }

        return $errors;
    }

    /** @return array{full: string, thumb: string} */
    private function storeImageVariants(string $tenantId, string $campaignId, UploadedFile $image, AdminSessionContext $actor): array
    {
        $sourceBytes = file_get_contents($image->getRealPath()) ?: '';
        $sourceMime = $this->imageMime($sourceBytes) ?? 'image/jpeg';
        $assets = [];
        foreach (['full' => [1200, 84], 'thumb' => [480, 78]] as $variant => [$width, $quality]) {
            $webp = $this->resizedWebpBytes($sourceBytes, $width, $quality);
            $bytes = $webp ?? $sourceBytes;
            $contentType = $webp === null ? $sourceMime : 'image/webp';
            $extension = $webp === null ? match ($sourceMime) {
                'image/png' => 'png',
                'image/webp' => 'webp',
                default => 'jpg',
            } : 'webp';
            $assetId = 'ast_'.Str::ulid()->toBase32();
            $storageKey = $this->storage->put(
                RuntimeStorageService::ROUTE_CUSTOMER_COMMUNICATION_IMAGES,
                'tenants/'.$tenantId.'/customer-communications/'.$campaignId.'/'.$variant.'.'.$extension,
                $bytes,
                ['ContentType' => $contentType],
            );
            PlatformAsset::query()->create([
                'id' => $assetId,
                'scope_type' => 'tenant',
                'tenant_id' => $tenantId,
                'created_by_admin_id' => (string) $actor->adminUser['id'],
                'purpose' => self::PURPOSE,
                'file_name' => 'communication-'.$variant.'.'.$extension,
                'content_type' => $contentType,
                'size_bytes' => strlen($bytes),
                'checksum_sha256' => hash('sha256', $bytes),
                'status' => 'committed',
                'storage_key' => $storageKey,
                'public_url' => $this->storage->publicUrl(RuntimeStorageService::ROUTE_CUSTOMER_COMMUNICATION_IMAGES, $storageKey),
                'metadata_json' => ['campaign_id' => $campaignId, 'variant' => $variant],
                'committed_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $assets[$variant] = $assetId;
        }

        return $assets;
    }

    private function imageMime(string $bytes): ?string
    {
        if ($bytes === '') return null;
        $info = @getimagesizefromstring($bytes);
        $mime = is_array($info) ? strtolower(trim((string) ($info['mime'] ?? ''))) : '';

        return in_array($mime, self::ALLOWED_IMAGE_MIMES, true) ? $mime : null;
    }

    private function resizedWebpBytes(string $sourceBytes, int $maxWidth, int $quality): ?string
    {
        if (! extension_loaded('gd') || ! function_exists('imagecreatefromstring') || ! function_exists('imagewebp')) return null;
        $image = @imagecreatefromstring($sourceBytes);
        if ($image === false) return null;
        try {
            $width = imagesx($image);
            $height = imagesy($image);
            if ($width < 1 || $height < 1) return null;
            $targetWidth = min($width, $maxWidth);
            $targetHeight = max(1, (int) round($height * ($targetWidth / $width)));
            $target = imagecreatetruecolor($targetWidth, $targetHeight);
            if ($target === false) return null;
            try {
                imagealphablending($target, false);
                imagesavealpha($target, true);
                imagecopyresampled($target, $image, 0, 0, 0, 0, $targetWidth, $targetHeight, $width, $height);
                ob_start();
                $ok = imagewebp($target, null, $quality);
                $bytes = ob_get_clean();
                return $ok && is_string($bytes) && $bytes !== '' ? $bytes : null;
            } finally {
                imagedestroy($target);
            }
        } finally {
            imagedestroy($image);
        }
    }

    /** @param array<int, string> $notificationIds @return array<string, array<string, int>> */
    private function deliveryStats(array $notificationIds): array
    {
        if ($notificationIds === []) return [];
        $recipientRows = DB::table('customer_notification_recipients')
            ->whereIn('notification_id', $notificationIds)
            ->groupBy('notification_id')
            ->get([
                'notification_id',
                DB::raw('COUNT(*) AS recipient_count'),
                DB::raw('SUM(CASE WHEN read_at IS NOT NULL THEN 1 ELSE 0 END) AS read_count'),
            ]);
        $deliveryRows = DB::table('customer_notification_deliveries as d')
            ->whereIn('d.notification_id', $notificationIds)
            ->groupBy('d.notification_id')
            ->get([
                'd.notification_id',
                DB::raw('COUNT(*) AS installation_count'),
                DB::raw("SUM(CASE WHEN d.status = 'sent' THEN 1 ELSE 0 END) AS sent_count"),
                DB::raw("SUM(CASE WHEN d.status IN ('queued', 'sending') THEN 1 ELSE 0 END) AS pending_count"),
                DB::raw("SUM(CASE WHEN d.status IN ('failed', 'skipped') THEN 1 ELSE 0 END) AS failed_count"),
            ])->keyBy('notification_id');

        $stats = [];
        foreach ($recipientRows as $row) {
            $delivery = $deliveryRows->get($row->notification_id);
            $stats[(string) $row->notification_id] = [
                'recipient_count' => (int) $row->recipient_count,
                'installation_count' => (int) ($delivery->installation_count ?? 0),
                'read_count' => (int) $row->read_count,
                'sent_count' => (int) ($delivery->sent_count ?? 0),
                'pending_count' => (int) ($delivery->pending_count ?? 0),
                'failed_count' => (int) ($delivery->failed_count ?? 0),
            ];
        }

        foreach ($deliveryRows as $delivery) {
            $notificationId = (string) $delivery->notification_id;
            if (isset($stats[$notificationId])) continue;
            $stats[$notificationId] = [
                'recipient_count' => 0,
                'installation_count' => (int) ($delivery->installation_count ?? 0),
                'read_count' => 0,
                'sent_count' => (int) ($delivery->sent_count ?? 0),
                'pending_count' => (int) ($delivery->pending_count ?? 0),
                'failed_count' => (int) ($delivery->failed_count ?? 0),
            ];
        }

        return $stats;
    }

    /** @return array<string, int> */
    private function campaignCounts(string $tenantId): array
    {
        $counts = array_fill_keys(self::STATUSES, 0);
        $rows = CustomerCommunicationCampaign::query()
            ->forTenant($tenantId)
            ->selectRaw('status, COUNT(*) AS aggregate')
            ->groupBy('status')
            ->get();

        foreach ($rows as $row) {
            $counts[(string) $row->status] = (int) $row->aggregate;
        }

        return [
            'total' => array_sum($counts),
            ...$counts,
        ];
    }

    /** @return array<string, mixed> */
    private function deliveryBreakdown(string $notificationId): array
    {
        if ($notificationId === '') {
            return [
                'statuses' => [],
                'platforms' => [],
                'errors' => [],
                'last_activity_at' => null,
            ];
        }

        $statusRows = DB::table('customer_notification_deliveries')
            ->where('notification_id', $notificationId)
            ->groupBy('status')
            ->orderBy('status')
            ->get(['status', DB::raw('COUNT(*) AS count')]);
        $platformRows = DB::table('customer_notification_deliveries as d')
            ->join('customer_push_devices as device', 'device.id', '=', 'd.device_id')
            ->where('d.notification_id', $notificationId)
            ->groupBy('device.platform')
            ->orderBy('device.platform')
            ->get([
                'device.platform',
                DB::raw('COUNT(*) AS total_count'),
                DB::raw("SUM(CASE WHEN d.status = 'sent' THEN 1 ELSE 0 END) AS sent_count"),
                DB::raw("SUM(CASE WHEN d.status IN ('queued', 'sending') THEN 1 ELSE 0 END) AS pending_count"),
                DB::raw("SUM(CASE WHEN d.status IN ('failed', 'skipped') THEN 1 ELSE 0 END) AS failed_count"),
            ]);
        $errorRows = DB::table('customer_notification_deliveries')
            ->where('notification_id', $notificationId)
            ->whereIn('status', ['failed', 'skipped'])
            ->whereNotNull('last_error_code')
            ->where('last_error_code', '<>', '')
            ->groupBy('last_error_code')
            ->orderByDesc(DB::raw('COUNT(*)'))
            ->limit(10)
            ->get(['last_error_code', DB::raw('COUNT(*) AS count')]);

        return [
            'statuses' => $statusRows->map(fn (object $row): array => [
                'status' => (string) $row->status,
                'count' => (int) $row->count,
            ])->values()->all(),
            'platforms' => $platformRows->map(fn (object $row): array => [
                'platform' => (string) $row->platform,
                'total_count' => (int) $row->total_count,
                'sent_count' => (int) $row->sent_count,
                'pending_count' => (int) $row->pending_count,
                'failed_count' => (int) $row->failed_count,
            ])->values()->all(),
            'errors' => $errorRows->map(fn (object $row): array => [
                'code' => (string) $row->last_error_code,
                'count' => (int) $row->count,
            ])->values()->all(),
            'last_activity_at' => DB::table('customer_notification_deliveries')
                ->where('notification_id', $notificationId)
                ->max('updated_at'),
        ];
    }

    /** @param array<string, int>|null $stats @return array<string, mixed> */
    private function resource(CustomerCommunicationCampaign $campaign, ?array $stats = null): array
    {
        $stats ??= [
            'recipient_count' => 0,
            'installation_count' => 0,
            'read_count' => 0,
            'sent_count' => 0,
            'pending_count' => 0,
            'failed_count' => 0,
        ];
        $stats['target_count'] = in_array((string) $campaign->audience_type, self::INSTALLATION_AUDIENCES, true)
            ? (int) ($stats['installation_count'] ?? 0)
            : (int) ($stats['recipient_count'] ?? 0);
        $stats['unread_count'] = max(0, (int) ($stats['recipient_count'] ?? 0) - (int) ($stats['read_count'] ?? 0));

        return [
            'id' => (string) $campaign->id,
            'name' => (string) $campaign->name,
            'audience_type' => (string) $campaign->audience_type,
            'customer' => $campaign->customer === null ? null : [
                'id' => (string) $campaign->customer->id,
                'customer_no' => $campaign->customer->customer_no,
                'name' => $campaign->customer->name,
                'phone' => $campaign->customer->phone,
            ],
            'status' => (string) $campaign->status,
            'title' => $campaign->title_json,
            'body' => $campaign->body_json,
            'action' => ['key' => $campaign->action_key, 'entity_id' => $campaign->action_entity_id],
            'image' => [
                'url' => PublicUrl::normalizeAssetUrl($campaign->fullAsset?->public_url),
                'thumb_url' => PublicUrl::normalizeAssetUrl($campaign->thumbAsset?->public_url),
            ],
            'notification_id' => $campaign->notification_id,
            'delivery_mode' => $campaign->scheduled_at === null ? 'now' : 'scheduled',
            'scheduled_at' => $campaign->scheduled_at?->toISOString(),
            'published_at' => $campaign->published_at?->toISOString(),
            'cancelled_at' => $campaign->cancelled_at?->toISOString(),
            'last_error_code' => $campaign->last_error_code,
            'creator' => [
                'id' => $campaign->creator?->id,
                'name' => $campaign->creator?->name,
                'username' => $campaign->creator?->username,
            ],
            'stats' => $stats,
            'created_at' => $campaign->created_at?->toISOString(),
            'updated_at' => $campaign->updated_at?->toISOString(),
        ];
    }

    /** @return array<string, string> */
    private function localizedMap(mixed $value): array
    {
        if (is_string($value)) {
            $text = trim($value);
            return $text === '' ? [] : ['th-TH' => $text, 'en-US' => $text];
        }
        if (! is_array($value)) return [];
        $result = [];
        foreach ($value as $locale => $text) {
            if (! is_scalar($text)) continue;
            $normalized = trim((string) $text);
            if ($normalized !== '') $result[(string) $locale] = $normalized;
        }
        return $result;
    }

    private function audit(CustomerCommunicationCampaign $campaign, AdminSessionContext $actor, Request $request, string $action): void
    {
        $this->auditLogger->logAdminWrite(
            actorId: (string) $actor->adminUser['id'],
            scopeType: 'tenant',
            action: $action,
            targetType: 'customer_communication_campaign',
            targetId: (string) $campaign->id,
            payload: [
                'audience_type' => (string) $campaign->audience_type,
                'status' => (string) $campaign->status,
                'scheduled_at' => $campaign->scheduled_at?->toISOString(),
                'content_fingerprint' => hash('sha256', json_encode([$campaign->title_json, $campaign->body_json], JSON_THROW_ON_ERROR)),
            ],
            tenantId: (string) $campaign->tenant_id,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }
}

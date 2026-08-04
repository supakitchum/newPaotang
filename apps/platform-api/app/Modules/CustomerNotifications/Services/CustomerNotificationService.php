<?php

namespace App\Modules\CustomerNotifications\Services;

use App\Jobs\FanoutCustomerNotificationRecipientsJob;
use App\Jobs\SendCustomerPushNotificationJob;
use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\CustomerNotification;
use App\Models\CustomerNotificationDelivery;
use App\Models\CustomerNotificationRecipient;
use App\Models\CustomerPushDevice;
use App\Models\PartnerTenant;
use App\Modules\CustomerNotifications\Events\CustomerNotificationChanged;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CustomerNotificationService
{
    private const FANOUT_CHUNK_SIZE = 250;

    private const DELIVERY_MAX_ATTEMPTS = 4;

    private const DELIVERY_LEASE_MINUTES = 10;

    private const DEVICE_REVOKED_LOGOUT = 'customer_logout';

    private const DEVICE_REVOKED_REASSIGNED = 'registration_reassigned';

    private const DEVICE_REVOKED_STALE = 'stale_registration';

    public const CATEGORIES = [
        'order',
        'lottery',
        'topup',
        'wallet',
        'reward',
        'activity',
        'affiliate',
        'news',
        'account',
        'admin',
        'support',
    ];

    public const ACTION_KEYS = [
        'none',
        'home',
        'order',
        'checkout_pending',
        'wallet',
        'tickets',
        'ticket',
        'topups',
        'topup',
        'reward_claims',
        'reward_claim',
        'activities',
        'activity',
        'activity_claims',
        'activity_claim',
        'affiliate',
        'affiliate_rankings',
        'affiliate_commissions',
        'affiliate_withdraw',
        'news',
        'support',
        'support_ticket',
    ];

    private const ACTION_ENTITY_KEYS = [
        'order',
        'checkout_pending',
        'ticket',
        'topup',
        'reward_claim',
        'activity',
        'activity_claim',
        'news',
        'support_ticket',
    ];

    private const ADMIN_ACTION_KEYS = [
        'none',
        'home',
        'wallet',
        'tickets',
        'ticket',
        'topups',
        'topup',
        'reward_claims',
        'reward_claim',
        'activities',
        'activity',
        'activity_claims',
        'activity_claim',
        'affiliate',
        'affiliate_rankings',
        'affiliate_commissions',
        'affiliate_withdraw',
        'news',
        'support',
        'support_ticket',
    ];

    private const ADMIN_ACTION_ENTITY_KEYS = [
        'ticket',
        'topup',
        'reward_claim',
        'activity',
        'activity_claim',
        'news',
        'support_ticket',
    ];

    private const DEVICE_METADATA_KEYS = [
        'app_build_number',
        'os_name',
        'os_version',
        'os_sdk',
        'manufacturer',
        'device_model',
        'device_machine',
        'is_physical_device',
    ];

    private const DEVICE_METADATA_TEXT_LIMITS = [
        'app_build_number' => 40,
        'os_name' => 40,
        'os_version' => 80,
        'manufacturer' => 120,
        'device_model' => 160,
        'device_machine' => 160,
    ];

    public function __construct(
        private readonly FirebaseCloudMessagingClient $fcm,
        private readonly AuditLogger $auditLogger,
    ) {
    }

    /**
     * @param array<string, mixed> $query
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function customerList(string $tenantId, string $customerId, array $query, string $locale): array
    {
        $limit = $this->limit($query['limit'] ?? null);
        $builder = CustomerNotificationRecipient::query()
            ->with('notification')
            ->forTenant($tenantId)
            ->where('customer_id', $customerId);

        if (($query['status'] ?? 'all') === 'unread') {
            $builder->whereNull('read_at');
        }

        $category = trim((string) ($query['category'] ?? ''));
        if ($category !== '' && in_array($category, self::CATEGORIES, true)) {
            $builder->whereHas('notification', fn (Builder $notification) => $notification->where('category', $category));
        }

        $cursor = trim((string) ($query['cursor'] ?? ''));
        if ($cursor !== '') {
            $builder->where('id', '<', $cursor);
        }

        $rows = $builder->orderByDesc('id')->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_values(array_filter(array_map(
                fn (CustomerNotificationRecipient $recipient): ?array => $recipient->notification === null
                    ? null
                    : $this->recipientResource($recipient, $recipient->notification, $locale),
                $rows,
            ))),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
                'unread_count' => $this->unreadCount($tenantId, $customerId),
            ],
        ];
    }

    public function unreadCount(string $tenantId, string $customerId): int
    {
        return CustomerNotificationRecipient::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customerId)
            ->whereNull('read_at')
            ->count();
    }

    /**
     * @return array<string, mixed>|null
     */
    public function markRead(string $tenantId, string $customerId, string $notificationId, string $locale): ?array
    {
        $recipient = CustomerNotificationRecipient::query()
            ->with('notification')
            ->forTenant($tenantId)
            ->where('customer_id', $customerId)
            ->where('notification_id', $notificationId)
            ->first();

        if ($recipient === null || $recipient->notification === null) {
            return null;
        }

        if ($recipient->read_at === null) {
            $recipient->forceFill(['read_at' => now(), 'updated_at' => now()])->save();
            $this->broadcastRead($tenantId, $customerId, $notificationId);
        }

        return $this->recipientResource($recipient->refresh(), $recipient->notification, $locale);
    }

    /**
     * @return array{updated_count: int, unread_count: int}
     */
    public function markAllRead(string $tenantId, string $customerId): array
    {
        $updated = CustomerNotificationRecipient::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customerId)
            ->whereNull('read_at')
            ->update(['read_at' => now(), 'updated_at' => now()]);

        if ($updated > 0) {
            $this->broadcastRead($tenantId, $customerId, null);
        }

        return [
            'updated_count' => $updated,
            'unread_count' => $this->unreadCount($tenantId, $customerId),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function registerDevice(string $tenantId, string $customerId, array $payload): array
    {
        $errors = $this->deviceErrors($payload);
        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $installationId = trim((string) $payload['installation_id']);
        $token = trim((string) $payload['fcm_token']);
        $tokenHash = hash_hmac('sha256', $token, (string) config('app.key'));
        $metadata = $this->normalizedDeviceMetadata($payload['metadata'] ?? null);
        $device = DB::transaction(function () use ($tenantId, $customerId, $installationId, $token, $tokenHash, $payload, $metadata): ?CustomerPushDevice {
            $this->lockPushRegistrationIdentity($installationId, $tokenHash);
            $now = now();
            $device = CustomerPushDevice::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->where('installation_id', $installationId)
                ->lockForUpdate()
                ->first();

            $terminallyRevokedTokenExists = CustomerPushDevice::query()
                ->where('token_hash', $tokenHash)
                ->whereNotNull('revoked_at')
                ->where(function (Builder $query): void {
                    $query->whereNull('revoked_reason')
                        ->orWhere('revoked_reason', 'like', 'fcm_%');
                })
                ->exists();
            $sameRevokedInstallation = $device !== null
                && $device->revoked_at !== null
                && hash_equals((string) $device->token_hash, $tokenHash);
            if ($terminallyRevokedTokenExists || $sameRevokedInstallation) {
                return null;
            }

            if ($device === null) {
                $device = new CustomerPushDevice([
                    'id' => 'cpd_'.Str::ulid()->toBase32(),
                    'tenant_id' => $tenantId,
                    'customer_id' => $customerId,
                    'installation_id' => $installationId,
                    'created_at' => $now,
                ]);
            }

            // One app installation and its current token can have only one
            // active customer owner, including after an offline logout.
            CustomerPushDevice::query()
                ->where(function (Builder $query) use ($installationId, $tokenHash): void {
                    $query->where('installation_id', $installationId)
                        ->orWhere('token_hash', $tokenHash);
                })
                ->whereNull('revoked_at')
                ->when($device->exists, fn (Builder $query) => $query->where('id', '!=', $device->id))
                ->update([
                    'revoked_at' => $now,
                    'revoked_reason' => self::DEVICE_REVOKED_REASSIGNED,
                    'updated_at' => $now,
                ]);

            $device->fill([
                'platform' => strtolower(trim((string) $payload['platform'])),
                'fcm_token_encrypted' => $token,
                'token_hash' => $tokenHash,
                'locale' => $this->localeKey($payload['locale'] ?? null),
                'app_version' => $this->nullableText($payload['app_version'] ?? null, 40),
                'device_name' => $this->nullableText($payload['device_name'] ?? null, 255),
                'metadata_json' => $metadata,
                'last_seen_at' => $now,
                'revoked_at' => null,
                'revoked_reason' => null,
                'updated_at' => $now,
            ])->save();

            return $device;
        });

        if ($device === null) {
            return ['error' => 'token_rotation_required'];
        }

        return ['resource' => $this->deviceResource($device->refresh())];
    }

    private function lockPushRegistrationIdentity(string $installationId, string $tokenHash): void
    {
        if (DB::connection()->getDriverName() !== 'pgsql') {
            return;
        }

        $locks = [
            'customer-push-installation:'.$installationId,
            'customer-push-token:'.$tokenHash,
        ];
        sort($locks, SORT_STRING);
        foreach ($locks as $lock) {
            DB::select('select pg_advisory_xact_lock(hashtextextended(?, 0))', [$lock]);
        }
    }

    public function revokeDevice(string $tenantId, string $customerId, string $installationId): bool
    {
        $device = CustomerPushDevice::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customerId)
            ->where('installation_id', $installationId)
            ->first();

        if ($device === null) {
            return false;
        }

        if ($device->revoked_at === null) {
            $device->forceFill([
                'revoked_at' => now(),
                'revoked_reason' => self::DEVICE_REVOKED_LOGOUT,
                'updated_at' => now(),
            ])->save();
        }

        return true;
    }

    /** @return array<string, mixed> */
    public function deviceStatus(string $tenantId, string $customerId, string $installationId): array
    {
        $installationId = trim($installationId);
        $device = $installationId === ''
            ? null
            : CustomerPushDevice::query()
                ->forTenant($tenantId)
                ->where('customer_id', $customerId)
                ->where('installation_id', $installationId)
                ->first();

        if ($device === null) {
            return [
                'installation_id' => $installationId,
                'state' => 'missing',
                'registered' => false,
                'needs_token_rotation' => false,
                'revoked_reason' => null,
                'revoked_at' => null,
                'last_seen_at' => null,
            ];
        }

        $registered = $device->revoked_at === null;

        return [
            'installation_id' => (string) $device->installation_id,
            'state' => $registered ? 'active' : 'revoked',
            'registered' => $registered,
            // A revoked row may predate revoked_reason. Rotating is the safe
            // recovery because the server never exposes or accepts token hashes.
            'needs_token_rotation' => ! $registered,
            'revoked_reason' => $registered ? null : $device->revoked_reason,
            'revoked_at' => $device->revoked_at?->toISOString(),
            'last_seen_at' => $device->last_seen_at?->toISOString(),
        ];
    }

    public function revokeStaleDevices(int $limit = 100, ?int $staleDays = null): int
    {
        $staleDays ??= (int) config('services.firebase_cloud_messaging.device_stale_days', 270);
        if ($staleDays <= 0) {
            return 0;
        }

        $limit = max(1, min(500, $limit));
        $cutoff = now()->subDays($staleDays);
        $candidateIds = CustomerPushDevice::query()
            ->whereNull('revoked_at')
            ->where('last_seen_at', '<=', $cutoff)
            ->orderBy('last_seen_at')
            ->orderBy('id')
            ->limit($limit)
            ->pluck('id');

        if ($candidateIds->isEmpty()) {
            return 0;
        }

        $now = now();

        // Recheck freshness in the update so a concurrent app registration wins.
        return CustomerPushDevice::query()
            ->whereKey($candidateIds->all())
            ->whereNull('revoked_at')
            ->where('last_seen_at', '<=', $cutoff)
            ->update([
                'revoked_at' => $now,
                'revoked_reason' => self::DEVICE_REVOKED_STALE,
                'updated_at' => $now,
            ]);
    }

    /**
     * @param array<string, mixed> $content
     * @param array<string, mixed> $context
     * @return array<string, mixed>|null
     */
    public function createForCustomer(
        string $tenantId,
        string $customerId,
        string $eventKey,
        array $content,
        array $context = [],
    ): ?array {
        $customerQuery = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId);

        if (($context['allow_inactive_customer'] ?? false) !== true) {
            $customerQuery->where('status', 'active');
        }

        if (! $customerQuery->exists()) {
            return null;
        }

        $normalized = $this->normalizedContent($content);
        $dedupeSource = trim((string) ($context['dedupe_key'] ?? ''));
        $dedupeKey = hash('sha256', implode('|', [
            $tenantId,
            $customerId,
            $eventKey,
            $dedupeSource !== '' ? $dedupeSource : ($normalized['subject_type'] ?? '').':'.($normalized['subject_id'] ?? ''),
        ]));

        $recipient = DB::transaction(function () use ($tenantId, $customerId, $eventKey, $normalized, $context, $dedupeKey): CustomerNotificationRecipient {
            $notification = CustomerNotification::query()->firstOrCreate(
                ['tenant_id' => $tenantId, 'dedupe_key' => $dedupeKey],
                [
                    'id' => 'cnt_'.Str::ulid()->toBase32(),
                    'event_key' => $eventKey,
                    'category' => $normalized['category'],
                    'title_json' => $normalized['title'],
                    'body_json' => $normalized['body'],
                    'icon_key' => $normalized['icon_key'],
                    'action_key' => $normalized['action_key'],
                    'action_entity_id' => $normalized['action_entity_id'],
                    'subject_type' => $normalized['subject_type'],
                    'subject_id' => $normalized['subject_id'],
                    'creator_type' => trim((string) ($context['creator_type'] ?? 'system')) ?: 'system',
                    'creator_id' => $this->nullableText($context['creator_id'] ?? null, 30),
                    'metadata_json' => is_array($context['metadata'] ?? null) ? $context['metadata'] : null,
                    'published_at' => now(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
            );

            return CustomerNotificationRecipient::query()->firstOrCreate(
                ['notification_id' => $notification->id, 'customer_id' => $customerId],
                [
                    'id' => 'cnr_'.Str::ulid()->toBase32(),
                    'tenant_id' => $tenantId,
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
            );
        });

        $this->dispatchCreated(
            $recipient,
            ($context['broadcast_after_commit'] ?? false) === true,
        );
        $notification = CustomerNotification::query()->find($recipient->notification_id);

        return $notification === null
            ? null
            : $this->recipientResource($recipient, $notification, 'th-TH');
    }

    /**
     * Queue a tenant-wide notification without creating recipients in the
     * publish request. Duplicate publish requests reuse the immutable source
     * and do not enqueue another fan-out chain.
     *
     * @param array<string, mixed> $content
     * @param array<string, mixed> $context
     */
    public function createForTenantAudience(
        string $tenantId,
        string $eventKey,
        array $content,
        array $context = [],
    ): ?string {
        $tenantExists = PartnerTenant::query()
            ->whereKey($tenantId)
            ->where('status', 'active')
            ->exists();

        if (! $tenantExists) {
            return null;
        }

        $normalized = $this->normalizedContent($content);
        $dedupeSource = trim((string) ($context['dedupe_key'] ?? ''));
        $dedupeKey = hash('sha256', implode('|', [
            $tenantId,
            'tenant_audience',
            $eventKey,
            $dedupeSource !== '' ? $dedupeSource : ($normalized['subject_type'] ?? '').':'.($normalized['subject_id'] ?? ''),
        ]));

        $notification = CustomerNotification::query()->firstOrCreate(
            ['tenant_id' => $tenantId, 'dedupe_key' => $dedupeKey],
            [
                'id' => 'cnt_'.Str::ulid()->toBase32(),
                'event_key' => $eventKey,
                'category' => $normalized['category'],
                'title_json' => $normalized['title'],
                'body_json' => $normalized['body'],
                'icon_key' => $normalized['icon_key'],
                'action_key' => $normalized['action_key'],
                'action_entity_id' => $normalized['action_entity_id'],
                'subject_type' => $normalized['subject_type'],
                'subject_id' => $normalized['subject_id'],
                'creator_type' => trim((string) ($context['creator_type'] ?? 'system')) ?: 'system',
                'creator_id' => $this->nullableText($context['creator_id'] ?? null, 30),
                'metadata_json' => [
                    ...(is_array($context['metadata'] ?? null) ? $context['metadata'] : []),
                    'audience' => 'tenant',
                ],
                'published_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ],
        );

        if ($notification->wasRecentlyCreated) {
            FanoutCustomerNotificationRecipientsJob::dispatch((string) $notification->id)->afterCommit();
        }

        return (string) $notification->id;
    }

    public function fanOutTenantChunk(string $notificationId, ?string $afterCustomerId = null): void
    {
        $notification = CustomerNotification::query()->whereKey($notificationId)->first();
        if ($notification === null) {
            return;
        }

        $customerQuery = Customer::query()
            ->where('tenant_id', $notification->tenant_id)
            ->where('status', 'active')
            ->orderBy('id')
            ->limit(self::FANOUT_CHUNK_SIZE);

        $cursor = trim((string) $afterCustomerId);
        if ($cursor !== '') {
            $customerQuery->where('id', '>', $cursor);
        }

        $customerIds = $customerQuery->pluck('id')->map(static fn (mixed $id): string => (string) $id)->all();
        if ($customerIds === []) {
            return;
        }

        $recipients = DB::transaction(function () use ($notification, $customerIds): array {
            $rows = [];
            foreach ($customerIds as $customerId) {
                $rows[] = CustomerNotificationRecipient::query()->firstOrCreate(
                    ['notification_id' => $notification->id, 'customer_id' => $customerId],
                    [
                        'id' => 'cnr_'.Str::ulid()->toBase32(),
                        'tenant_id' => $notification->tenant_id,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ],
                );
            }

            return $rows;
        });

        foreach ($recipients as $recipient) {
            $this->dispatchCreated($recipient);
        }

        if (count($customerIds) === self::FANOUT_CHUNK_SIZE) {
            FanoutCustomerNotificationRecipientsJob::dispatch(
                $notificationId,
                end($customerIds) ?: null,
            )->afterCommit();
        }
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function sendFromAdmin(
        string $tenantId,
        AdminSessionContext $actor,
        array $payload,
        Request $request,
        string $idempotencyKey,
    ): array {
        $errors = $this->adminSendErrors($tenantId, $payload);
        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $customerId = trim((string) $payload['customer_id']);
        $content = [
            'category' => 'admin',
            'title' => $payload['title'],
            'body' => $payload['body'],
            'icon_key' => 'admin',
            'action_key' => trim((string) ($payload['action_key'] ?? 'none')) ?: 'none',
            'action_entity_id' => $this->nullableText($payload['action_entity_id'] ?? null, 100),
            'subject_type' => 'admin_message',
            'subject_id' => $idempotencyKey,
        ];

        return DB::transaction(function () use (
            $tenantId,
            $customerId,
            $actor,
            $content,
            $payload,
            $request,
            $idempotencyKey,
        ): array {
            $resource = $this->createForCustomer(
                $tenantId,
                $customerId,
                'admin.direct_message',
                $content,
                [
                    'creator_type' => 'tenant_admin',
                    'creator_id' => (string) $actor->adminUser['id'],
                    'dedupe_key' => 'admin:'.$actor->adminUser['id'].':'.$idempotencyKey,
                    'metadata' => ['request_id' => $request->header('X-Request-Id')],
                    'broadcast_after_commit' => true,
                ],
            );

            if ($resource === null) {
                return ['error' => 'not_found'];
            }

            $this->auditLogger->logAdminWrite(
                actorId: (string) $actor->adminUser['id'],
                scopeType: 'tenant',
                action: 'customer_notification.sent',
                targetType: 'customer',
                targetId: $customerId,
                payload: [
                    'content_fingerprint' => hash('sha256', json_encode([$payload['title'], $payload['body']], JSON_THROW_ON_ERROR)),
                    'destination' => [
                        'action_key' => $content['action_key'],
                        'action_entity_id' => $content['action_entity_id'],
                    ],
                    'outcome' => 'accepted',
                ],
                tenantId: $tenantId,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return ['resource' => $resource];
        });
    }

    /**
     * @param array<string, mixed> $query
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function adminList(string $tenantId, array $query): array
    {
        $limit = $this->limit($query['limit'] ?? null);
        $builder = CustomerNotification::query()
            ->with(['recipients.customer', 'recipients.deliveries'])
            ->forTenant($tenantId);

        foreach (['category', 'event_key', 'creator_type'] as $field) {
            $value = trim((string) ($query[$field] ?? ''));
            if ($value !== '') {
                $builder->where($field, $value);
            }
        }

        $customerId = trim((string) ($query['customer_id'] ?? ''));
        if ($customerId !== '') {
            $builder->whereHas('recipients', fn (Builder $recipients) => $recipients->where('customer_id', $customerId));
        }

        $cursor = trim((string) ($query['cursor'] ?? ''));
        if ($cursor !== '') {
            $builder->where('id', '<', $cursor);
        }

        $rows = $builder->orderByDesc('id')->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);
        $creatorIds = collect($rows)
            ->filter(fn (CustomerNotification $notification): bool => $notification->creator_type === 'tenant_admin')
            ->pluck('creator_id')
            ->filter()
            ->unique()
            ->values();
        $creators = AdminUser::query()
            ->whereIn('id', $creatorIds)
            ->get(['id', 'name', 'username', 'email'])
            ->keyBy('id');

        return [
            'data' => array_map(
                fn (CustomerNotification $notification): array => $this->adminResource(
                    $notification,
                    $creators->get($notification->creator_id),
                ),
                $rows,
            ),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
                'action_options' => $this->adminActionOptions(),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $query
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function adminCustomerOptions(string $tenantId, array $query): array
    {
        $limit = max(1, min(50, (int) ($query['limit'] ?? 20)));
        $activeCustomerCount = Customer::query()
            ->forTenant($tenantId)
            ->where('status', 'active')
            ->count();
        $builder = Customer::query()
            ->forTenant($tenantId)
            ->where('status', 'active');

        $customerId = trim((string) ($query['customer_id'] ?? ''));
        if ($customerId !== '') {
            $builder->whereKey($customerId);
        }

        $search = trim((string) ($query['q'] ?? ''));
        if ($search !== '') {
            $builder->where(function (Builder $nested) use ($search): void {
                $nested->where('name', 'like', '%'.$search.'%')
                    ->orWhere('phone', 'like', '%'.$search.'%')
                    ->orWhere('email', 'like', '%'.$search.'%')
                    ->orWhere('customer_no', 'like', '%'.strtoupper($search).'%');
            });
        }

        return [
            'data' => $builder
                ->orderBy('name')
                ->orderBy('id')
                ->limit($limit)
                ->get(['id', 'customer_no', 'name', 'phone', 'email', 'status'])
                ->map(static fn (Customer $customer): array => [
                    'id' => (string) $customer->id,
                    'customer_no' => $customer->customer_no,
                    'name' => $customer->name,
                    'phone' => $customer->phone,
                    'email' => $customer->email,
                    'status' => (string) $customer->status,
                ])
                ->values()
                ->all(),
            'meta' => [
                'action_options' => $this->adminActionOptions(),
                'active_customer_count' => $activeCustomerCount,
            ],
        ];
    }

    /** @return array<int, array{key: string, label: string, entity_required: bool}> */
    public function adminActionOptions(): array
    {
        $labels = [
            'none' => 'No destination',
            'home' => 'Home',
            'wallet' => 'Wallet',
            'tickets' => 'Tickets',
            'ticket' => 'Ticket detail',
            'topups' => 'Topup history',
            'topup' => 'Topup detail',
            'reward_claims' => 'Reward claims',
            'reward_claim' => 'Reward claim detail',
            'activities' => 'Activities',
            'activity' => 'Activity detail',
            'activity_claims' => 'Activity claims',
            'activity_claim' => 'Activity claim detail',
            'affiliate' => 'Affiliate',
            'affiliate_rankings' => 'Affiliate rankings',
            'affiliate_commissions' => 'Affiliate commissions',
            'affiliate_withdraw' => 'Affiliate withdrawal',
            'news' => 'News detail',
        ];

        return array_map(static fn (string $key): array => [
            'key' => $key,
            'label' => $labels[$key] ?? Str::of($key)->replace('_', ' ')->title()->toString(),
            'entity_required' => in_array($key, self::ADMIN_ACTION_ENTITY_KEYS, true),
        ], self::ADMIN_ACTION_KEYS);
    }

    public function processDelivery(string $deliveryId): void
    {
        $claimed = DB::transaction(function () use ($deliveryId): bool {
            $delivery = CustomerNotificationDelivery::query()
                ->whereKey($deliveryId)
                ->lockForUpdate()
                ->first();

            if ($delivery === null || in_array((string) $delivery->status, ['sent', 'failed', 'skipped'], true)) {
                return false;
            }

            if (
                (string) $delivery->status === 'sending'
                && $delivery->updated_at?->isAfter(now()->subMinutes(self::DELIVERY_LEASE_MINUTES))
            ) {
                return false;
            }

            if ((int) $delivery->attempts >= self::DELIVERY_MAX_ATTEMPTS) {
                $delivery->forceFill([
                    'status' => 'failed',
                    'last_error_code' => 'delivery_attempts_exhausted',
                    'next_retry_at' => null,
                    'failed_at' => now(),
                    'updated_at' => now(),
                ])->save();

                return false;
            }

            $delivery->forceFill([
                'status' => 'sending',
                'attempts' => (int) $delivery->attempts + 1,
                'next_retry_at' => null,
                'updated_at' => now(),
            ])->save();

            return true;
        });

        if (! $claimed) {
            return;
        }

        $delivery = CustomerNotificationDelivery::query()
            ->with(['recipient.notification', 'device'])
            ->whereKey($deliveryId)
            ->first();

        if ($delivery === null) {
            return;
        }

        $recipient = $delivery->recipient;
        $device = $delivery->device;
        $notification = $recipient?->notification;
        $isFinalSessionReplacementDelivery = $device !== null
            && $notification !== null
            && $device->revoked_at !== null
            && (string) $notification->event_key === 'account.session.replaced'
            && $delivery->created_at !== null
            && $delivery->created_at->lessThanOrEqualTo($device->revoked_at);
        if ($recipient === null
            || $device === null
            || $notification === null
            || ($device->revoked_at !== null && ! $isFinalSessionReplacementDelivery)) {
            $delivery->forceFill([
                'status' => 'skipped',
                'last_error_code' => 'device_unavailable',
                'failed_at' => now(),
                'updated_at' => now(),
            ])->save();
            return;
        }

        $attempts = (int) $delivery->attempts;
        $locale = $device->locale ?: 'th-TH';
        $pushPreview = $this->pushPreview($notification, $locale);
        $notificationMetadata = is_array($notification->metadata_json)
            ? $notification->metadata_json
            : [];
        $imageUrl = trim((string) ($notificationMetadata['image_url'] ?? ''));
        if ($imageUrl !== '') {
            $pushPreview['image'] = $imageUrl;
        }
        $androidNotification = ['channel_id' => 'customer_updates'];
        $apnsPayload = ['aps' => ['sound' => 'default']];
        $apnsOptions = [];
        if ($imageUrl !== '') {
            $androidNotification['image'] = $imageUrl;
            $apnsPayload['aps']['mutable-content'] = 1;
            $apnsOptions['image'] = $imageUrl;
        }
        $result = $this->fcm->send([
            'token' => (string) $device->fcm_token_encrypted,
            'notification' => $pushPreview,
            'data' => [
                'notification_id' => (string) $notification->id,
                'event_key' => (string) $notification->event_key,
                'replacement_session_id' => (string) ($notificationMetadata['replacement_session_id'] ?? ''),
                'action_key' => (string) $notification->action_key,
                'action_entity_id' => (string) ($notification->action_entity_id ?? ''),
                'image_url' => $imageUrl,
                'image_thumb_url' => trim((string) ($notificationMetadata['image_thumb_url'] ?? $imageUrl)),
            ],
            'android' => [
                'priority' => 'high',
                'notification' => $androidNotification,
            ],
            'apns' => [
                'payload' => $apnsPayload,
                ...($apnsOptions === [] ? [] : ['fcm_options' => $apnsOptions]),
            ],
        ]);

        if (($result['ok'] ?? false) === true) {
            $delivery->forceFill([
                'status' => 'sent',
                'provider_message_id' => $result['message_id'] ?? null,
                'last_error_code' => null,
                'next_retry_at' => null,
                'sent_at' => now(),
                'failed_at' => null,
                'updated_at' => now(),
            ])->save();
            return;
        }

        $errorCode = trim((string) ($result['error_code'] ?? 'provider_error')) ?: 'provider_error';
        $terminalToken = ($result['revoke_device'] ?? false) === true;
        if ($terminalToken) {
            $device->forceFill([
                'revoked_at' => now(),
                'revoked_reason' => 'fcm_'.Str::limit($errorCode, 60, ''),
                'updated_at' => now(),
            ])->save();
        }

        $retryable = ($result['retryable'] ?? false) === true && $attempts < self::DELIVERY_MAX_ATTEMPTS;
        $delivery->forceFill([
            'status' => $retryable ? 'queued' : ($errorCode === 'provider_unavailable' ? 'skipped' : 'failed'),
            'last_error_code' => $errorCode,
            'next_retry_at' => $retryable ? now()->addSeconds([30, 120, 600, 1800][min($attempts - 1, 3)]) : null,
            'failed_at' => $retryable ? null : now(),
            'updated_at' => now(),
        ])->save();

        if ($retryable) {
            throw new \RuntimeException('Customer push delivery is retryable: '.$errorCode);
        }
    }

    public function recoverStaleDeliveries(
        int $limit = 100,
        int $queuedMinutes = 2,
        int $staleMinutes = self::DELIVERY_LEASE_MINUTES,
    ): int {
        $limit = max(1, min(500, $limit));
        $queuedCutoff = now()->subMinutes(max(1, $queuedMinutes));
        $staleCutoff = now()->subMinutes(max(self::DELIVERY_LEASE_MINUTES, $staleMinutes));
        $now = now();

        $candidateIds = CustomerNotificationDelivery::query()
            ->where(function (Builder $query) use ($now, $queuedCutoff, $staleCutoff): void {
                $query->where(function (Builder $queued) use ($now, $queuedCutoff): void {
                    $queued->where('status', 'queued')
                        ->where(function (Builder $due) use ($now, $queuedCutoff): void {
                            $due->where('next_retry_at', '<=', $now)
                                ->orWhere(function (Builder $neverDispatched) use ($queuedCutoff): void {
                                    $neverDispatched->whereNull('next_retry_at')
                                        ->where('created_at', '<=', $queuedCutoff);
                                });
                        });
                })->orWhere(function (Builder $sending) use ($staleCutoff): void {
                    $sending->where('status', 'sending')
                        ->where('updated_at', '<=', $staleCutoff);
                });
            })
            ->orderBy('updated_at')
            ->limit($limit)
            ->pluck('id')
            ->map(static fn (mixed $id): string => (string) $id)
            ->all();

        $dispatched = 0;
        foreach ($candidateIds as $deliveryId) {
            $reserved = DB::transaction(function () use ($deliveryId, $now, $queuedCutoff, $staleCutoff): bool {
                $delivery = CustomerNotificationDelivery::query()
                    ->whereKey($deliveryId)
                    ->lockForUpdate()
                    ->first();

                if ($delivery === null) {
                    return false;
                }

                $queuedIsDue = (string) $delivery->status === 'queued'
                    && (
                        $delivery->next_retry_at?->lessThanOrEqualTo($now)
                        || ($delivery->next_retry_at === null && $delivery->created_at?->lessThanOrEqualTo($queuedCutoff))
                    );
                $sendingIsStale = (string) $delivery->status === 'sending'
                    && $delivery->updated_at?->lessThanOrEqualTo($staleCutoff);

                if (! $queuedIsDue && ! $sendingIsStale) {
                    return false;
                }

                if ((int) $delivery->attempts >= self::DELIVERY_MAX_ATTEMPTS) {
                    $delivery->forceFill([
                        'status' => 'failed',
                        'last_error_code' => 'delivery_attempts_exhausted',
                        'next_retry_at' => null,
                        'failed_at' => now(),
                        'updated_at' => now(),
                    ])->save();

                    return false;
                }

                $delivery->forceFill([
                    'status' => 'queued',
                    'last_error_code' => $sendingIsStale
                        ? 'worker_stale_requeued'
                        : $delivery->last_error_code,
                    'next_retry_at' => now()->addMinute(),
                    'failed_at' => null,
                    'updated_at' => now(),
                ])->save();

                return true;
            });

            if (! $reserved) {
                continue;
            }

            try {
                SendCustomerPushNotificationJob::dispatch($deliveryId);
                $dispatched++;
            } catch (\Throwable) {
                CustomerNotificationDelivery::query()
                    ->whereKey($deliveryId)
                    ->where('status', 'queued')
                    ->update([
                        'last_error_code' => 'queue_dispatch_failed',
                        'next_retry_at' => now(),
                        'updated_at' => now(),
                    ]);
            }
        }

        return $dispatched;
    }

    public function recoverTenantFanouts(int $limit = 25, int $queuedMinutes = 2): int
    {
        $notifications = CustomerNotification::query()
            ->where('created_at', '<=', now()->subMinutes(max(1, $queuedMinutes)))
            ->where(function (Builder $query): void {
                $query->where('metadata_json->audience', 'tenant')
                    ->orWhereIn('event_key', [
                        'content.activity.published',
                        'content.news.published',
                    ]);
            })
            ->orderBy('created_at')
            ->limit(max(1, min(100, $limit)))
            ->get();

        $dispatched = 0;
        foreach ($notifications as $notification) {
            $missingCustomerId = Customer::query()
                ->where('tenant_id', $notification->tenant_id)
                ->where('status', 'active')
                ->whereNotExists(function ($query) use ($notification): void {
                    $query->selectRaw('1')
                        ->from('customer_notification_recipients')
                        ->whereColumn('customer_notification_recipients.customer_id', 'customers.id')
                        ->where('customer_notification_recipients.notification_id', $notification->id);
                })
                ->orderBy('id')
                ->value('id');

            if ($missingCustomerId === null) {
                continue;
            }

            $afterCustomerId = Customer::query()
                ->where('tenant_id', $notification->tenant_id)
                ->where('status', 'active')
                ->where('id', '<', $missingCustomerId)
                ->orderByDesc('id')
                ->value('id');

            try {
                FanoutCustomerNotificationRecipientsJob::dispatch(
                    (string) $notification->id,
                    $afterCustomerId === null ? null : (string) $afterCustomerId,
                );
                $dispatched++;
            } catch (\Throwable) {
                // The next scheduled recovery run will retry this immutable source.
            }
        }

        return $dispatched;
    }

    private function dispatchCreated(
        CustomerNotificationRecipient $recipient,
        bool $broadcastAfterCommit = false,
    ): void
    {
        $this->queueRecipientDeliveries((string) $recipient->tenant_id, (string) $recipient->id);

        if ($broadcastAfterCommit) {
            DB::afterCommit(fn () => $this->broadcastCreated($recipient));

            return;
        }

        $this->broadcastCreated($recipient);
    }

    private function broadcastCreated(CustomerNotificationRecipient $recipient): void
    {
        try {
            CustomerNotificationChanged::dispatch('customer.notification.created', [
                'tenant_id' => (string) $recipient->tenant_id,
                'customer_id' => (string) $recipient->customer_id,
                'notification_id' => (string) $recipient->notification_id,
                'unread_count' => $this->unreadCount((string) $recipient->tenant_id, (string) $recipient->customer_id),
            ]);
        } catch (\Throwable) {
            // Realtime is an optimization; the durable inbox remains authoritative.
        }
    }

    private function queueRecipientDeliveries(string $tenantId, string $recipientId): void
    {
        $recipient = CustomerNotificationRecipient::query()->forTenant($tenantId)->whereKey($recipientId)->first();
        if ($recipient === null) {
            return;
        }

        $devices = CustomerPushDevice::query()
            ->forTenant($tenantId)
            ->where('customer_id', $recipient->customer_id)
            ->whereNull('revoked_at')
            ->get();

        foreach ($devices as $device) {
            $delivery = CustomerNotificationDelivery::query()->firstOrCreate(
                ['recipient_id' => $recipientId, 'device_id' => $device->id],
                [
                    'id' => 'cnd_'.Str::ulid()->toBase32(),
                    'tenant_id' => $tenantId,
                    'status' => 'queued',
                    'attempts' => 0,
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
            );

            if ($delivery->wasRecentlyCreated) {
                try {
                    SendCustomerPushNotificationJob::dispatch((string) $delivery->id)->afterCommit();
                } catch (\Throwable) {
                    $delivery->forceFill([
                        'last_error_code' => 'queue_dispatch_failed',
                        'next_retry_at' => now(),
                        'updated_at' => now(),
                    ])->save();
                }
            }
        }
    }

    private function broadcastRead(string $tenantId, string $customerId, ?string $notificationId): void
    {
        try {
            CustomerNotificationChanged::dispatch('customer.notification.read', [
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'notification_id' => $notificationId,
                'unread_count' => $this->unreadCount($tenantId, $customerId),
            ]);
        } catch (\Throwable) {
        }
    }

    /** @return array<string, mixed> */
    private function recipientResource(CustomerNotificationRecipient $recipient, CustomerNotification $notification, string $locale): array
    {
        $metadata = is_array($notification->metadata_json) ? $notification->metadata_json : [];
        return [
            'id' => (string) $notification->id,
            'recipient_id' => (string) $recipient->id,
            'category' => (string) $notification->category,
            'event_key' => (string) $notification->event_key,
            'title' => $this->localizedText($notification->title_json, $locale),
            'body' => $this->localizedText($notification->body_json, $locale),
            'image_url' => trim((string) ($metadata['image_url'] ?? '')),
            'image_thumb_url' => trim((string) ($metadata['image_thumb_url'] ?? $metadata['image_url'] ?? '')),
            'icon_key' => (string) $notification->icon_key,
            'action' => [
                'key' => (string) $notification->action_key,
                'entity_id' => $notification->action_entity_id,
            ],
            'subject' => [
                'type' => $notification->subject_type,
                'id' => $notification->subject_id,
            ],
            'is_read' => $recipient->read_at !== null,
            'read_at' => $recipient->read_at?->toISOString(),
            'created_at' => $notification->published_at?->toISOString(),
        ];
    }

    /** @return array<string, mixed> */
    private function adminResource(CustomerNotification $notification, ?AdminUser $creator = null): array
    {
        $metadata = is_array($notification->metadata_json) ? $notification->metadata_json : [];
        return [
            'id' => (string) $notification->id,
            'event_key' => (string) $notification->event_key,
            'category' => (string) $notification->category,
            'title' => $notification->title_json,
            'body' => $notification->body_json,
            'image_url' => trim((string) ($metadata['image_url'] ?? '')),
            'image_thumb_url' => trim((string) ($metadata['image_thumb_url'] ?? $metadata['image_url'] ?? '')),
            'icon_key' => (string) $notification->icon_key,
            'action' => ['key' => $notification->action_key, 'entity_id' => $notification->action_entity_id],
            'subject' => ['type' => $notification->subject_type, 'id' => $notification->subject_id],
            'creator' => [
                'type' => $notification->creator_type,
                'id' => $notification->creator_id,
                'name' => $creator?->name,
                'username' => $creator?->username,
                'email' => $creator?->email,
            ],
            'published_at' => $notification->published_at?->toISOString(),
            'recipients' => $notification->recipients->map(function (CustomerNotificationRecipient $recipient): array {
                $deliveries = $recipient->deliveries;
                return [
                    'customer' => [
                        'id' => $recipient->customer?->id,
                        'customer_no' => $recipient->customer?->customer_no,
                        'name' => $recipient->customer?->name,
                        'phone' => $recipient->customer?->phone,
                    ],
                    'is_read' => $recipient->read_at !== null,
                    'read_at' => $recipient->read_at?->toISOString(),
                    'push' => $this->deliverySummary($deliveries),
                ];
            })->values()->all(),
        ];
    }

    /** @return array{status: string, total_count: int, sent_count: int, pending_count: int, failed_count: int, last_error_code: ?string} */
    private function deliverySummary(mixed $deliveries): array
    {
        $totalCount = $deliveries->count();
        $sentCount = $deliveries->where('status', 'sent')->count();
        $pendingCount = $deliveries->whereIn('status', ['queued', 'sending'])->count();
        $failedCount = $deliveries->whereIn('status', ['failed', 'skipped'])->count();
        $status = match (true) {
            $totalCount === 0 => 'not_registered',
            $sentCount === $totalCount => 'sent',
            $sentCount > 0, $pendingCount > 0 && $failedCount > 0 => 'partial',
            $deliveries->contains('status', 'sending') => 'sending',
            $deliveries->contains('status', 'queued') => 'queued',
            $deliveries->contains('status', 'failed') => 'failed',
            $deliveries->contains('status', 'skipped') => 'skipped',
            default => (string) ($deliveries->sortByDesc('updated_at')->first()?->status ?? 'failed'),
        };
        $lastFailure = $deliveries
            ->filter(fn (CustomerNotificationDelivery $delivery): bool => trim((string) $delivery->last_error_code) !== '')
            ->sortByDesc('updated_at')
            ->first();

        return [
            'status' => $status,
            'total_count' => $totalCount,
            'sent_count' => $sentCount,
            'pending_count' => $pendingCount,
            'failed_count' => $failedCount,
            'last_error_code' => $lastFailure?->last_error_code,
        ];
    }

    /** @return array<string, mixed> */
    private function deviceResource(CustomerPushDevice $device): array
    {
        return [
            'installation_id' => (string) $device->installation_id,
            'platform' => (string) $device->platform,
            'locale' => $device->locale,
            'app_version' => $device->app_version,
            'device_name' => $device->device_name,
            'last_seen_at' => $device->last_seen_at?->toISOString(),
            'registered' => $device->revoked_at === null,
            'revoked_reason' => $device->revoked_at === null ? null : $device->revoked_reason,
        ];
    }

    /**
     * @param array<string, mixed> $content
     * @return array<string, mixed>
     */
    private function normalizedContent(array $content): array
    {
        $category = trim((string) ($content['category'] ?? 'account'));
        $actionKey = trim((string) ($content['action_key'] ?? 'none'));
        $actionEntityId = $this->nullableText($content['action_entity_id'] ?? null, 100);
        if (in_array($actionKey, self::ACTION_ENTITY_KEYS, true) && $actionEntityId === null) {
            $actionKey = 'none';
        }

        return [
            'category' => in_array($category, self::CATEGORIES, true) ? $category : 'account',
            'title' => $this->localizedMap($content['title'] ?? ''),
            'body' => $this->localizedMap($content['body'] ?? ''),
            'icon_key' => $this->nullableText($content['icon_key'] ?? null, 40) ?: 'notification',
            'action_key' => in_array($actionKey, self::ACTION_KEYS, true) ? $actionKey : 'none',
            'action_entity_id' => $actionEntityId,
            'subject_type' => $this->nullableText($content['subject_type'] ?? null, 60),
            'subject_id' => $this->nullableText($content['subject_id'] ?? null, 100),
        ];
    }

    /** @return array<string, array<int, string>> */
    private function deviceErrors(array $payload): array
    {
        $errors = [];
        $installationId = is_scalar($payload['installation_id'] ?? null)
            ? trim((string) $payload['installation_id'])
            : '';
        $token = is_scalar($payload['fcm_token'] ?? null)
            ? trim((string) $payload['fcm_token'])
            : '';
        $platform = is_scalar($payload['platform'] ?? null)
            ? strtolower(trim((string) $payload['platform']))
            : '';

        if (strlen($installationId) < 8 || strlen($installationId) > 128 || preg_match('/^[A-Za-z0-9._:-]+$/', $installationId) !== 1) {
            $errors['installation_id'][] = 'The installation ID format is invalid.';
        }
        if (strlen($token) < 20 || strlen($token) > 4096) {
            $errors['fcm_token'][] = 'The FCM token format is invalid.';
        }
        if (! in_array($platform, ['ios', 'android'], true)) {
            $errors['platform'][] = 'The platform must be ios or android.';
        }

        foreach (['app_version' => 40, 'device_name' => 255] as $field => $maxLength) {
            $value = $payload[$field] ?? null;
            if ($value !== null && (! is_string($value) || mb_strlen(trim($value)) > $maxLength)) {
                $errors[$field][] = 'The '.$field.' field is invalid.';
            }
        }

        $metadata = $payload['metadata'] ?? null;
        if ($metadata !== null && ! is_array($metadata)) {
            $errors['metadata'][] = 'The device metadata must be an object.';
        } elseif (is_array($metadata)) {
            $unsupportedKeys = array_diff(array_map('strval', array_keys($metadata)), self::DEVICE_METADATA_KEYS);
            if ($unsupportedKeys !== []) {
                $errors['metadata'][] = 'The device metadata contains unsupported fields.';
            }

            foreach (self::DEVICE_METADATA_TEXT_LIMITS as $key => $maxLength) {
                $value = $metadata[$key] ?? null;
                if ($value !== null && (! is_string($value) || mb_strlen(trim($value)) > $maxLength)) {
                    $errors['metadata'][] = 'The device metadata contains an invalid value.';
                    break;
                }
            }

            if (array_key_exists('os_sdk', $metadata)) {
                $osSdk = filter_var($metadata['os_sdk'], FILTER_VALIDATE_INT);
                if ($osSdk === false || $osSdk < 0 || $osSdk > 1000) {
                    $errors['metadata'][] = 'The device metadata contains an invalid OS SDK.';
                }
            }
            if (array_key_exists('is_physical_device', $metadata) && ! is_bool($metadata['is_physical_device'])) {
                $errors['metadata'][] = 'The physical-device metadata must be boolean.';
            }
        }

        return $errors;
    }

    /** @return array<string, int|string|bool>|null */
    private function normalizedDeviceMetadata(mixed $value): ?array
    {
        if (! is_array($value)) {
            return null;
        }

        $metadata = [];
        foreach (self::DEVICE_METADATA_TEXT_LIMITS as $key => $_) {
            if (! array_key_exists($key, $value) || $value[$key] === null) {
                continue;
            }
            $text = trim((string) $value[$key]);
            if ($text !== '') {
                $metadata[$key] = $text;
            }
        }
        if (array_key_exists('os_sdk', $value)) {
            $metadata['os_sdk'] = (int) $value['os_sdk'];
        }
        if (array_key_exists('is_physical_device', $value)) {
            $metadata['is_physical_device'] = (bool) $value['is_physical_device'];
        }

        return $metadata === [] ? null : $metadata;
    }

    /** @return array<string, array<int, string>> */
    private function adminSendErrors(string $tenantId, array $payload): array
    {
        $errors = [];
        $customerId = trim((string) ($payload['customer_id'] ?? ''));
        $title = $this->localizedMap($payload['title'] ?? []);
        $body = $this->localizedMap($payload['body'] ?? []);
        $actionKey = trim((string) ($payload['action_key'] ?? 'none')) ?: 'none';
        $customerExists = $customerId !== '' && Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId)
            ->where('status', 'active')
            ->exists();

        if (! $customerExists) {
            $errors['customer_id'][] = 'The selected customer was not found in this tenant.';
        }
        if ($this->mapEmpty($title)) {
            $errors['title'][] = 'At least one localized title is required.';
        }
        if ($this->mapEmpty($body)) {
            $errors['body'][] = 'At least one localized body is required.';
        }
        foreach ($title as $value) {
            if (mb_strlen($value) > 160) $errors['title'][] = 'Notification titles must not exceed 160 characters.';
        }
        foreach ($body as $value) {
            if (mb_strlen($value) > 1000) $errors['body'][] = 'Notification bodies must not exceed 1000 characters.';
        }
        if (! in_array($actionKey, self::ADMIN_ACTION_KEYS, true)) {
            $errors['action_key'][] = 'The notification destination is invalid.';
        }
        $actionEntityId = trim((string) ($payload['action_entity_id'] ?? ''));
        if (in_array($actionKey, self::ADMIN_ACTION_ENTITY_KEYS, true) && $actionEntityId === '') {
            $errors['action_entity_id'][] = 'The selected destination requires a record ID.';
        }
        $entityFormatInvalid =
            $actionEntityId !== ''
            && (
                mb_strlen($actionEntityId) > 100
                || str_contains($actionEntityId, '://')
                || preg_match('/[\/?#]/u', $actionEntityId) === 1
            );
        if ($entityFormatInvalid) {
            $errors['action_entity_id'][] = 'The destination record ID format is invalid.';
        }
        if (
            $customerExists
            && $actionEntityId !== ''
            && ! $entityFormatInvalid
            && in_array($actionKey, self::ADMIN_ACTION_ENTITY_KEYS, true)
            && ! $this->adminActionEntityExists($tenantId, $customerId, $actionKey, $actionEntityId)
        ) {
            $errors['action_entity_id'][] = 'The destination record was not found for this customer in this tenant.';
        }

        return $errors;
    }

    private function adminActionEntityExists(
        string $tenantId,
        string $customerId,
        string $actionKey,
        string $entityId,
    ): bool {
        return match ($actionKey) {
            'ticket' => DB::table('tickets')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->where('id', $entityId)
                ->exists(),
            'topup' => DB::table('topup_requests')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->where('id', $entityId)
                ->exists(),
            'reward_claim' => DB::table('reward_claims')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->where('id', $entityId)
                ->exists(),
            'activity_claim' => DB::table('activity_claims')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->where('id', $entityId)
                ->exists(),
            'activity' => DB::table('tenant_activities')
                ->where('tenant_id', $tenantId)
                ->where('status', 'active')
                ->where('slug', $entityId)
                ->exists(),
            'news' => DB::table('tenant_announcements')
                ->where('tenant_id', $tenantId)
                ->where('status', 'active')
                ->where('slug', $entityId)
                ->exists(),
            default => true,
        };
    }

    /** @return array<string, string> */
    private function localizedMap(mixed $value): array
    {
        if (is_string($value)) {
            $text = trim($value);
            return $text === '' ? [] : ['th-TH' => $text, 'en-US' => $text];
        }
        if (! is_array($value)) return [];

        $map = [];
        foreach ($value as $locale => $text) {
            if (! is_scalar($text)) continue;
            $normalizedLocale = $this->localeKey($locale);
            $normalizedText = trim((string) $text);
            if ($normalizedLocale !== null && $normalizedText !== '') {
                $map[$normalizedLocale] = $normalizedText;
            }
        }
        return $map;
    }

    private function localizedText(mixed $value, string $locale): string
    {
        $map = is_array($value) ? $value : [];
        $key = $this->localeKey($locale) ?? 'th-TH';
        return trim((string) ($map[$key] ?? $map['th-TH'] ?? $map['en-US'] ?? Arr::first($map) ?? ''));
    }

    /** @return array{title: string, body: string} */
    private function pushPreview(CustomerNotification $notification, string $locale): array
    {
        return [
            'title' => $this->localizedText($notification->title_json, $locale),
            'body' => $this->localizedText($notification->body_json, $locale),
        ];
    }

    private function localeKey(mixed $locale): ?string
    {
        $normalized = strtolower(str_replace('_', '-', trim((string) $locale)));
        if (str_starts_with($normalized, 'th')) return 'th-TH';
        if (str_starts_with($normalized, 'en')) return 'en-US';
        return null;
    }

    /** @param array<string, string> $map */
    private function mapEmpty(array $map): bool
    {
        return ! collect($map)->contains(fn (string $text): bool => trim($text) !== '');
    }

    private function nullableText(mixed $value, int $max): ?string
    {
        $text = trim((string) $value);
        return $text === '' ? null : mb_substr($text, 0, $max);
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);
        return $limit === false ? 30 : max(1, min(100, (int) $limit));
    }
}

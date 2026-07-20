<?php

namespace App\Modules\CustomerNotifications\Services;

use App\Jobs\FanoutCustomerNotificationRecipientsJob;
use App\Jobs\SendCustomerPushNotificationJob;
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
    ];

    public const ACTION_KEYS = [
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
        'news',
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

        return ['updated_count' => $updated, 'unread_count' => 0];
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
        $now = now();
        $device = CustomerPushDevice::query()->firstOrNew([
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'installation_id' => $installationId,
        ]);

        if (! $device->exists) {
            $device->id = 'cpd_'.Str::ulid()->toBase32();
            $device->created_at = $now;
        }

        $device->fill([
            'platform' => strtolower(trim((string) $payload['platform'])),
            'fcm_token_encrypted' => $token,
            'token_hash' => hash_hmac('sha256', $token, (string) config('app.key')),
            'locale' => $this->localeKey($payload['locale'] ?? null),
            'app_version' => $this->nullableText($payload['app_version'] ?? null, 40),
            'device_name' => $this->nullableText($payload['device_name'] ?? null, 255),
            'metadata_json' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : null,
            'last_seen_at' => $now,
            'revoked_at' => null,
            'updated_at' => $now,
        ])->save();

        return ['resource' => $this->deviceResource($device->refresh())];
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
            $device->forceFill(['revoked_at' => now(), 'updated_at' => now()])->save();
        }

        return true;
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
        $customerExists = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId)
            ->where('status', 'active')
            ->exists();

        if (! $customerExists) {
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

        $this->dispatchCreated($recipient);
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
                'metadata_json' => is_array($context['metadata'] ?? null) ? $context['metadata'] : null,
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
                'content_hash' => hash('sha256', json_encode([$payload['title'], $payload['body']], JSON_THROW_ON_ERROR)),
                'action_key' => $content['action_key'],
                'action_entity_id' => $content['action_entity_id'],
            ],
            tenantId: $tenantId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        return ['resource' => $resource];
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

        return [
            'data' => array_map(fn (CustomerNotification $notification): array => $this->adminResource($notification), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    public function processDelivery(string $deliveryId): void
    {
        $delivery = CustomerNotificationDelivery::query()
            ->with(['recipient.notification', 'device'])
            ->whereKey($deliveryId)
            ->first();

        if ($delivery === null || in_array((string) $delivery->status, ['sent', 'failed', 'skipped'], true)) {
            return;
        }

        $recipient = $delivery->recipient;
        $device = $delivery->device;
        $notification = $recipient?->notification;
        if ($recipient === null || $device === null || $notification === null || $device->revoked_at !== null) {
            $delivery->forceFill([
                'status' => 'skipped',
                'last_error_code' => 'device_unavailable',
                'failed_at' => now(),
                'updated_at' => now(),
            ])->save();
            return;
        }

        $attempts = (int) $delivery->attempts + 1;
        $delivery->forceFill(['status' => 'sending', 'attempts' => $attempts, 'updated_at' => now()])->save();
        $locale = $device->locale ?: 'th-TH';
        $result = $this->fcm->send([
            'token' => (string) $device->fcm_token_encrypted,
            'notification' => [
                'title' => $this->localizedText($notification->title_json, $locale),
                'body' => $this->localizedText($notification->body_json, $locale),
            ],
            'data' => [
                'notification_id' => (string) $notification->id,
                'action_key' => (string) $notification->action_key,
                'action_entity_id' => (string) ($notification->action_entity_id ?? ''),
            ],
            'android' => [
                'priority' => 'high',
                'notification' => ['channel_id' => 'customer_updates'],
            ],
            'apns' => [
                'payload' => ['aps' => ['sound' => 'default']],
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
        $terminalToken = in_array($errorCode, ['unregistered', 'invalid_argument'], true);
        if ($terminalToken) {
            $device->forceFill(['revoked_at' => now(), 'updated_at' => now()])->save();
        }

        $retryable = ($result['retryable'] ?? false) === true && $attempts < 4;
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

    private function dispatchCreated(CustomerNotificationRecipient $recipient): void
    {
        $this->queueRecipientDeliveries((string) $recipient->tenant_id, (string) $recipient->id);

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
                SendCustomerPushNotificationJob::dispatch((string) $delivery->id)->afterCommit();
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
        return [
            'id' => (string) $notification->id,
            'recipient_id' => (string) $recipient->id,
            'category' => (string) $notification->category,
            'event_key' => (string) $notification->event_key,
            'title' => $this->localizedText($notification->title_json, $locale),
            'body' => $this->localizedText($notification->body_json, $locale),
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
    private function adminResource(CustomerNotification $notification): array
    {
        return [
            'id' => (string) $notification->id,
            'event_key' => (string) $notification->event_key,
            'category' => (string) $notification->category,
            'title' => $notification->title_json,
            'body' => $notification->body_json,
            'icon_key' => (string) $notification->icon_key,
            'action' => ['key' => $notification->action_key, 'entity_id' => $notification->action_entity_id],
            'subject' => ['type' => $notification->subject_type, 'id' => $notification->subject_id],
            'creator' => ['type' => $notification->creator_type, 'id' => $notification->creator_id],
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
                    'push' => [
                        'status' => $deliveries->isEmpty() ? 'not_registered' : ($deliveries->contains('status', 'sent') ? 'sent' : (string) $deliveries->sortByDesc('updated_at')->first()?->status),
                        'sent_count' => $deliveries->where('status', 'sent')->count(),
                        'failed_count' => $deliveries->whereIn('status', ['failed', 'skipped'])->count(),
                        'last_error_code' => $deliveries->sortByDesc('updated_at')->first()?->last_error_code,
                    ],
                ];
            })->values()->all(),
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

        return [
            'category' => in_array($category, self::CATEGORIES, true) ? $category : 'account',
            'title' => $this->localizedMap($content['title'] ?? ''),
            'body' => $this->localizedMap($content['body'] ?? ''),
            'icon_key' => $this->nullableText($content['icon_key'] ?? null, 40) ?: 'notification',
            'action_key' => in_array($actionKey, self::ACTION_KEYS, true) ? $actionKey : 'none',
            'action_entity_id' => $this->nullableText($content['action_entity_id'] ?? null, 100),
            'subject_type' => $this->nullableText($content['subject_type'] ?? null, 60),
            'subject_id' => $this->nullableText($content['subject_id'] ?? null, 100),
        ];
    }

    /** @return array<string, array<int, string>> */
    private function deviceErrors(array $payload): array
    {
        $errors = [];
        $installationId = trim((string) ($payload['installation_id'] ?? ''));
        $token = trim((string) ($payload['fcm_token'] ?? ''));
        $platform = strtolower(trim((string) ($payload['platform'] ?? '')));

        if (strlen($installationId) < 8 || strlen($installationId) > 128 || preg_match('/^[A-Za-z0-9._:-]+$/', $installationId) !== 1) {
            $errors['installation_id'][] = 'The installation ID format is invalid.';
        }
        if (strlen($token) < 20 || strlen($token) > 4096) {
            $errors['fcm_token'][] = 'The FCM token format is invalid.';
        }
        if (! in_array($platform, ['ios', 'android'], true)) {
            $errors['platform'][] = 'The platform must be ios or android.';
        }

        return $errors;
    }

    /** @return array<string, array<int, string>> */
    private function adminSendErrors(string $tenantId, array $payload): array
    {
        $errors = [];
        $customerId = trim((string) ($payload['customer_id'] ?? ''));
        $title = $this->localizedMap($payload['title'] ?? []);
        $body = $this->localizedMap($payload['body'] ?? []);
        $actionKey = trim((string) ($payload['action_key'] ?? 'none')) ?: 'none';

        if ($customerId === '' || ! Customer::query()->where('tenant_id', $tenantId)->where('id', $customerId)->where('status', 'active')->exists()) {
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
        if (! in_array($actionKey, self::ACTION_KEYS, true)) {
            $errors['action_key'][] = 'The notification destination is invalid.';
        }

        return $errors;
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

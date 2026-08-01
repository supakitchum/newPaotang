<?php

namespace App\Modules\LineNotifications\Services;

use App\Jobs\SendLineNotificationJob;
use App\Models\Customer;
use App\Models\CustomerLineIdentity;
use App\Models\LineNotificationDelivery;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantDomain;
use App\Models\TenantLineChannel;
use App\Models\TenantLineMessageTemplate;
use App\Shared\Tenancy\TenantHostNormalizer;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class TenantLineNotificationService
{
    public const EVENT_KEYS = [
        'topup.created',
        'order.paid',
        'activity.entry.created',
        'reward_claim.submitted',
        'topup.status_updated',
        'reward_claim.status_updated',
        'activity_claim.status_updated',
    ];

    public function __construct(private readonly LineMessagingClient $line)
    {
    }

    public function channelForTenant(string $tenantId): ?TenantLineChannel
    {
        return TenantLineChannel::query()
            ->where('tenant_id', $tenantId)
            ->first();
    }

    public function activeChannelForTenant(string $tenantId): ?TenantLineChannel
    {
        return TenantLineChannel::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->first();
    }

    public function decrypted(TenantLineChannel $channel, string $field): string
    {
        $value = (string) ($channel->{$field} ?? '');

        if ($value === '') {
            return '';
        }

        try {
            return Crypt::decryptString($value);
        } catch (\Throwable) {
            return '';
        }
    }

    public function showSettings(string $tenantId): array
    {
        $channel = $this->channelForTenant($tenantId);
        $this->ensureDefaultTemplates($tenantId);

        return [
            'connection' => $this->serializeChannel($channel, $tenantId),
            'templates' => $this->templates($tenantId),
            'events' => array_map(fn (string $event): array => $this->eventDefinition($event), self::EVENT_KEYS),
        ];
    }

    public function updateConnection(string $tenantId, array $payload): array
    {
        $errors = [];
        $existing = $this->channelForTenant($tenantId);
        $accessToken = $this->connectionSecret($existing, $payload, 'messaging_access_token', 'messaging_access_token_encrypted');
        $messagingSecret = $this->connectionSecret($existing, $payload, 'messaging_channel_secret', 'messaging_channel_secret_encrypted');
        $loginChannelId = $this->connectionSecret($existing, $payload, 'login_channel_id', 'login_channel_id_encrypted');
        $loginChannelSecret = $this->connectionSecret($existing, $payload, 'login_channel_secret', 'login_channel_secret_encrypted');
        $liffId = $this->cleanString($payload['liff_id'] ?? null);
        $status = in_array(($payload['status'] ?? 'active'), ['active', 'inactive'], true) ? (string) $payload['status'] : 'active';

        if ($accessToken === '') {
            $errors['messaging_access_token'][] = 'The Messaging API channel access token is required.';
        }

        if ($messagingSecret === '') {
            $errors['messaging_channel_secret'][] = 'The Messaging API channel secret is required.';
        }

        if ($loginChannelId === '') {
            $errors['login_channel_id'][] = 'The LINE Login channel ID is required.';
        }

        if ($loginChannelSecret === '') {
            $errors['login_channel_secret'][] = 'The LINE Login channel secret is required.';
        }

        if ($liffId !== '' && ! preg_match('/^[0-9A-Za-z_-]{4,80}$/', $liffId)) {
            $errors['liff_id'][] = 'The LINE LIFF ID format is invalid.';
        }

        if ($liffId !== '' && ! $this->supportsLiffId()) {
            return [
                'error' => 'line_schema_not_ready',
                'message' => 'เกิดข้อผิดพลาดในการบันทึก LINE LIFF กรุณารัน database migration แล้วกด Save ใหม่อีกครั้ง',
                'details' => [
                    'fields' => [
                        'liff_id' => ['The tenant_line_channels.liff_id column is missing.'],
                    ],
                ],
            ];
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (! $this->encryptionKeyConfigured()) {
            return [
                'error' => 'line_encryption_not_configured',
                'message' => 'เกิดข้อผิดพลาดในการบันทึกการเชื่อมต่อ LINE กรุณากด Save ใหม่อีกครั้ง',
                'details' => [
                    'fields' => [
                        'connection' => ['Application encryption key is not configured.'],
                    ],
                ],
            ];
        }

        $tokenCheck = $this->line->verifyMessagingToken($accessToken);
        $botInfo = $this->line->botInfo($accessToken);

        if (($tokenCheck['ok'] ?? false) !== true || ($botInfo['ok'] ?? false) !== true) {
            return [
                'error' => 'line_verification_failed',
                'errors' => [
                    'messaging_access_token' => [
                        'LINE token verification failed: '.($botInfo['message'] ?? $tokenCheck['message'] ?? 'unknown error'),
                    ],
                ],
            ];
        }

        $bot = $botInfo['data'] ?? [];
        $now = now();
        $channelId = (string) (TenantLineChannel::query()->where('tenant_id', $tenantId)->value('id') ?: 'tlc_'.Str::ulid()->toBase32());

        try {
            $encryptedCredentials = [
                'messaging_access_token_encrypted' => Crypt::encryptString($accessToken),
                'messaging_channel_secret_encrypted' => Crypt::encryptString($messagingSecret),
                'login_channel_id_encrypted' => Crypt::encryptString($loginChannelId),
                'login_channel_secret_encrypted' => Crypt::encryptString($loginChannelSecret),
            ];
        } catch (\Throwable) {
            return [
                'error' => 'line_encryption_failed',
                'message' => 'เกิดข้อผิดพลาดในการบันทึกการเชื่อมต่อ LINE กรุณากด Save ใหม่อีกครั้ง',
                'details' => [
                    'fields' => [
                        'connection' => ['Unable to encrypt LINE credentials.'],
                    ],
                ],
            ];
        }

        $channelPayload = [
            'id' => $channelId,
            'status' => $status,
            ...$encryptedCredentials,
            'bot_user_id' => $this->cleanString($bot['userId'] ?? null) ?: null,
            'bot_basic_id' => $this->cleanString($bot['basicId'] ?? null) ?: null,
            'bot_premium_id' => $this->cleanString($bot['premiumId'] ?? null) ?: null,
            'bot_display_name' => $this->cleanString($bot['displayName'] ?? null) ?: null,
            'bot_picture_url' => $this->cleanString($bot['pictureUrl'] ?? null) ?: null,
            'chat_mode' => $this->cleanString($bot['chatMode'] ?? null) ?: null,
            'mark_as_read_mode' => $this->cleanString($bot['markAsReadMode'] ?? null) ?: null,
            'verified_at' => $now,
            'last_test_status' => 'verified',
            'last_test_message' => 'LINE Messaging API token verified.',
            'updated_at' => $now,
        ];

        if ($this->supportsLiffId()) {
            $channelPayload['liff_id'] = $liffId ?: null;
        }

        TenantLineChannel::query()->updateOrCreate(
            ['tenant_id' => $tenantId],
            $channelPayload,
        );

        $this->ensureDefaultTemplates($tenantId);
        $this->requeueRecoverableDeliveries($tenantId);

        return ['resource' => $this->showSettings($tenantId)];
    }

    public function disconnectConnection(string $tenantId): array
    {
        TenantLineChannel::query()
            ->where('tenant_id', $tenantId)
            ->delete();

        return ['resource' => $this->showSettings($tenantId)];
    }

    public function templates(string $tenantId): array
    {
        $this->ensureDefaultTemplates($tenantId);

        $order = array_flip(self::EVENT_KEYS);

        return TenantLineMessageTemplate::query()
            ->where('tenant_id', $tenantId)
            ->get()
            ->sortBy(fn (TenantLineMessageTemplate $template): int => $order[(string) $template->event_key] ?? 999)
            ->values()
            ->map(fn (TenantLineMessageTemplate $template): array => $this->serializeTemplate($template))
            ->all();
    }

    public function updateTemplate(string $tenantId, string $eventKey, array $payload): array
    {
        if (! in_array($eventKey, self::EVENT_KEYS, true)) {
            return ['error' => 'not_found'];
        }

        $type = in_array(($payload['message_type'] ?? 'flex'), ['text', 'flex'], true) ? (string) $payload['message_type'] : 'flex';
        $title = $this->cleanString($payload['title'] ?? '');
        $body = trim((string) ($payload['body_text'] ?? ''));
        $flex = $payload['flex_json'] ?? null;
        $errors = [];

        if ($title === '') {
            $errors['title'][] = 'The title field is required.';
        }

        if ($type === 'text' && $body === '') {
            $errors['body_text'][] = 'The body text field is required for text messages.';
        }

        if ($type === 'flex' && (! is_array($flex) || $flex === [])) {
            $errors['flex_json'][] = 'The Flex JSON field is required for Flex messages.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $this->ensureDefaultTemplates($tenantId);
        $template = TenantLineMessageTemplate::query()
            ->where('tenant_id', $tenantId)
            ->where('event_key', $eventKey)
            ->first();

        if (! $template instanceof TenantLineMessageTemplate) {
            return ['error' => 'not_found'];
        }

        $template->fill([
            'enabled' => (bool) ($payload['enabled'] ?? true),
            'message_type' => $type,
            'title' => $title,
            'body_text' => $body,
            'flex_json' => $type === 'flex' ? $flex : null,
            'variables_json' => $this->variablesForEvent($eventKey),
            'updated_at' => now(),
        ]);
        $template->save();

        return ['resource' => $this->serializeTemplate($template)];
    }

    public function previewTemplate(string $tenantId, string $eventKey, array $payload = []): array
    {
        $template = $this->templateForEvent($tenantId, $eventKey);

        if (! $template instanceof TenantLineMessageTemplate) {
            return ['error' => 'not_found'];
        }

        $variables = array_replace_recursive($this->sampleVariables($eventKey), is_array($payload['variables'] ?? null) ? $payload['variables'] : []);

        return [
            'resource' => [
                'event_key' => $eventKey,
                'messages' => $this->renderMessages($template, $variables),
                'variables' => $variables,
            ],
        ];
    }

    public function linkedCustomers(string $tenantId, array $query): array
    {
        $rows = CustomerLineIdentity::query()
            ->where('tenant_id', $tenantId)
            ->orderByDesc('updated_at')
            ->limit(min(100, max(1, (int) ($query['limit'] ?? 50))))
            ->get();

        return [
            'data' => $rows->map(fn (CustomerLineIdentity $identity): array => $this->serializeIdentity($identity))->all(),
        ];
    }

    public function deliveries(string $tenantId, array $query): array
    {
        $rows = LineNotificationDelivery::query()
            ->where('tenant_id', $tenantId)
            ->when($this->cleanString($query['status'] ?? null) !== '', fn ($q) => $q->where('status', $this->cleanString($query['status'] ?? null)))
            ->orderByDesc('created_at')
            ->limit(min(100, max(1, (int) ($query['limit'] ?? 50))))
            ->get();

        return [
            'data' => $rows->map(fn (LineNotificationDelivery $delivery): array => $this->serializeDelivery($delivery))->all(),
        ];
    }

    public function testSend(string $tenantId, array $payload): array
    {
        $customerId = $this->cleanString($payload['customer_id'] ?? null);
        $lineUserId = $this->cleanString($payload['line_user_id'] ?? null);
        $message = trim((string) ($payload['message'] ?? ''));
        $errors = [];

        if ($lineUserId === '' && $customerId !== '') {
            $lineUserId = $this->cleanString(CustomerLineIdentity::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->where('notification_enabled', true)
                ->value('line_user_id'));
        }

        if ($lineUserId === '') {
            $errors['line_user_id'][] = 'Select a linked customer or enter a LINE user ID before sending a test message.';
        }

        if ($message === '') {
            $tenantName = (string) (PartnerTenant::query()->whereKey($tenantId)->value('name') ?: 'Partner');
            $message = 'ทดสอบแจ้งเตือน LINE จาก '.$tenantName."\nเวลา: ".now()->timezone('Asia/Bangkok')->format('d/m/Y H:i');
        }

        if (mb_strlen($message) > 1000) {
            $errors['message'][] = 'The test message is too long.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $channel = $this->channelForTenant($tenantId);

        if (! $channel instanceof TenantLineChannel || $channel->status !== 'active') {
            return [
                'error' => 'line_channel_not_ready',
                'message' => 'LINE channel is not active or has not been configured.',
            ];
        }

        if (! $this->encryptionKeyConfigured()) {
            return [
                'error' => 'line_encryption_not_configured',
                'message' => 'เกิดข้อผิดพลาดในการทดสอบ LINE กรุณาตรวจสอบ APP_KEY แล้วกด Save ใหม่อีกครั้ง',
            ];
        }

        $token = $this->decrypted($channel, 'messaging_access_token_encrypted');

        if ($token === '') {
            return [
                'error' => 'line_channel_not_ready',
                'message' => 'LINE Messaging API access token is unavailable.',
            ];
        }

        $result = $this->line->push($token, $lineUserId, [[
            'type' => 'text',
            'text' => $message,
        ]], (string) Str::uuid());
        $now = now();

        $channel->fill([
            'last_tested_at' => $now,
            'last_test_status' => ($result['ok'] ?? false) === true ? 'sent' : 'failed',
            'last_test_message' => ($result['ok'] ?? false) === true
                ? 'Test message sent to '.$lineUserId
                : (string) ($result['message'] ?? 'LINE test send failed.'),
            'updated_at' => $now,
        ])->save();

        if (($result['ok'] ?? false) !== true) {
            return [
                'error' => 'line_test_send_failed',
                'message' => (string) ($result['message'] ?? 'LINE test send failed.'),
                'details' => ['status' => (int) ($result['status'] ?? 0)],
            ];
        }

        return [
            'resource' => [
                'status' => 'sent',
                'line_user_id' => $lineUserId,
                'sent_at' => $now,
                'connection' => $this->serializeChannel($channel->refresh(), $tenantId),
            ],
        ];
    }

    public function customerSettings(string $tenantId, string $customerId): array
    {
        $channel = $this->channelForTenant($tenantId);
        $identity = CustomerLineIdentity::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->first();

        return [
            'line_available' => $this->channelReadyForLogin($channel),
            'bot_basic_id' => $channel?->bot_basic_id,
            'bot_display_name' => $channel?->bot_display_name,
            'add_friend_url' => $channel?->bot_basic_id ? 'https://line.me/R/ti/p/@'.ltrim((string) $channel->bot_basic_id, '@') : null,
            'liff_id' => $channel?->liff_id,
            'liff' => [
                'id' => $channel?->liff_id,
                'enabled' => $this->cleanString($channel?->liff_id) !== '',
            ],
            'identity' => $identity instanceof CustomerLineIdentity ? $this->serializeIdentity($identity) : null,
        ];
    }

    public function updateCustomerSettings(string $tenantId, string $customerId, array $payload): array
    {
        $identity = CustomerLineIdentity::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->first();

        if (! $identity instanceof CustomerLineIdentity) {
            return ['error' => 'not_found'];
        }

        $identity->notification_enabled = (bool) ($payload['notification_enabled'] ?? true);
        $identity->updated_at = now();
        $identity->save();

        return ['resource' => $this->customerSettings($tenantId, $customerId)];
    }

    public function disconnectCustomer(string $tenantId, string $customerId): array
    {
        CustomerLineIdentity::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->delete();

        return ['resource' => $this->customerSettings($tenantId, $customerId)];
    }

    public function upsertIdentity(string $tenantId, string $customerId, array $profile, bool $friendFlag): CustomerLineIdentity
    {
        $lineUserId = $this->cleanString($profile['userId'] ?? $profile['sub'] ?? '');
        $now = now();
        $existingLineIdentity = CustomerLineIdentity::query()
            ->where('tenant_id', $tenantId)
            ->where('line_user_id', $lineUserId)
            ->whereNull('revoked_at')
            ->first();
        $id = (string) ($existingLineIdentity?->id ?: CustomerLineIdentity::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->whereNull('revoked_at')
            ->value('id') ?: 'cli_'.Str::ulid()->toBase32());

        $identity = $existingLineIdentity ?? new CustomerLineIdentity([
            'id' => $id,
            'tenant_id' => $tenantId,
            'line_user_id' => $lineUserId,
        ]);
        $identity->fill([
            'customer_id' => $customerId,
            'display_name' => $this->cleanString($profile['displayName'] ?? $profile['name'] ?? null) ?: null,
            'picture_url' => $this->cleanString($profile['pictureUrl'] ?? $profile['picture'] ?? null) ?: null,
            'friend_flag' => $friendFlag,
            'notification_enabled' => true,
            'linked_at' => $now,
            'last_login_at' => $now,
            'last_friend_checked_at' => $now,
            'unreachable_at' => null,
            'revoked_at' => null,
            'updated_at' => $now,
        ])->save();

        return $identity;
    }

    public function channelReadyForLogin(?TenantLineChannel $channel): bool
    {
        if (! $channel instanceof TenantLineChannel || $channel->status !== 'active') {
            return false;
        }

        return $this->decrypted($channel, 'login_channel_id_encrypted') !== ''
            && $this->decrypted($channel, 'login_channel_secret_encrypted') !== '';
    }

    public function enqueue(string $tenantId, ?string $customerId, string $eventKey, string $sourceType, string $sourceId, array $variables = []): void
    {
        if ($customerId === null || $customerId === '' || ! in_array($eventKey, self::EVENT_KEYS, true)) {
            return;
        }

        $callback = function () use ($tenantId, $customerId, $eventKey, $sourceType, $sourceId, $variables): void {
            $channel = $this->activeChannelForTenant($tenantId);
            $identity = CustomerLineIdentity::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->whereNull('revoked_at')
                ->where('notification_enabled', true)
                ->first();
            $template = $this->templateForEvent($tenantId, $eventKey);

            if (! $channel instanceof TenantLineChannel || ! $identity instanceof CustomerLineIdentity || ! $template instanceof TenantLineMessageTemplate || ! $template->enabled) {
                return;
            }

            $messages = $this->renderMessages($template, $variables);

            if ($messages === []) {
                return;
            }

            $deliveryId = 'lnd_'.Str::ulid()->toBase32();
            $delivery = LineNotificationDelivery::query()->firstOrCreate(
                [
                    'tenant_id' => $tenantId,
                    'customer_id' => $customerId,
                    'event_key' => $eventKey,
                    'source_type' => $sourceType,
                    'source_id' => $sourceId,
                ],
                [
                    'id' => $deliveryId,
                    'line_user_id' => (string) $identity->line_user_id,
                    'status' => 'queued',
                    'attempts' => 0,
                    'message_json' => $messages,
                    'metadata_json' => ['variables' => $variables],
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
            );

            if ($delivery->wasRecentlyCreated) {
                SendLineNotificationJob::dispatch((string) $delivery->id);
            }
        };

        if (DB::transactionLevel() > 0) {
            DB::afterCommit($callback);
            return;
        }

        $callback();
    }

    public function processDelivery(string $deliveryId): void
    {
        $delivery = LineNotificationDelivery::query()->where('id', $deliveryId)->first();

        if (! $delivery instanceof LineNotificationDelivery || $delivery->status === 'sent') {
            return;
        }

        $channel = $this->channelForTenant((string) $delivery->tenant_id);
        $lineUserId = $this->deliveryLineUserId($delivery);
        $messages = $this->deliveryMessages($delivery);

        if (! $channel instanceof TenantLineChannel) {
            $this->failDelivery($delivery, 'line_channel_missing', 'No LINE channel is configured for this tenant.');
            return;
        }

        if ($channel->status !== 'active') {
            $this->failDelivery($delivery, 'line_channel_inactive', 'LINE channel is not active.');
            return;
        }

        if (! $this->encryptionKeyConfigured()) {
            $this->failDelivery($delivery, 'line_app_key_missing', 'Application encryption key is missing; LINE credentials cannot be decrypted.');
            return;
        }

        $token = $this->decrypted($channel, 'messaging_access_token_encrypted');

        if ($token === '') {
            $this->failDelivery($delivery, 'line_access_token_unavailable', 'LINE Messaging API access token is missing or cannot be decrypted.');
            return;
        }

        if ($lineUserId === '') {
            $this->failDelivery($delivery, 'line_recipient_missing', 'Customer LINE user ID is missing or notifications are disabled.');
            return;
        }

        if ($messages === []) {
            $this->failDelivery($delivery, 'line_message_payload_missing', 'LINE message payload is empty or cannot be rendered.');
            return;
        }

        $retryKey = $this->lineRetryKey($delivery);
        $result = $this->line->push($token, $lineUserId, $messages, $retryKey);

        if (($result['ok'] ?? false) === true) {
            $delivery->fill([
                'status' => 'sent',
                'attempts' => ((int) $delivery->attempts) + 1,
                'sent_at' => now(),
                'last_error' => null,
                'line_response_json' => $result['data'] ?? [],
                'updated_at' => now(),
            ])->save();
            return;
        }

        $status = (int) ($result['status'] ?? 0);
        $delivery->fill([
            'status' => in_array($status, [429, 500, 502, 503, 504], true) ? 'retryable_failed' : 'failed',
            'attempts' => ((int) $delivery->attempts) + 1,
            'last_error' => (string) ($result['message'] ?? 'LINE push failed.'),
            'line_response_json' => ['status' => $status],
            'updated_at' => now(),
        ])->save();

        if ($status >= 400 && $status < 500 && $delivery->customer_id) {
            CustomerLineIdentity::query()
                ->where('tenant_id', $delivery->tenant_id)
                ->where('customer_id', $delivery->customer_id)
                ->update([
                    'unreachable_at' => now(),
                    'updated_at' => now(),
                ]);
        }
    }

    public function requeueRecoverableDeliveries(string $tenantId, int $limit = 50): int
    {
        $ids = LineNotificationDelivery::query()
            ->where('tenant_id', $tenantId)
            ->whereIn('status', ['failed', 'retryable_failed'])
            ->where(function ($query): void {
                $query
                    ->where('last_error', 'like', 'Missing LINE channel%')
                    ->orWhere('last_error', 'like', 'line_channel_%')
                    ->orWhere('last_error', 'like', 'line_app_key_missing:%')
                    ->orWhere('last_error', 'like', 'line_access_token_unavailable:%')
                    ->orWhere('last_error', 'like', 'line_recipient_missing:%')
                    ->orWhere('last_error', 'like', 'line_message_payload_missing:%')
                    ->orWhere('last_error', 'like', '%X-Line-Retry-Key%');
            })
            ->orderBy('created_at')
            ->limit(max(1, min(200, $limit)))
            ->pluck('id');

        foreach ($ids as $id) {
            LineNotificationDelivery::query()
                ->where('id', $id)
                ->update([
                    'status' => 'queued',
                    'last_error' => null,
                    'next_retry_at' => null,
                    'updated_at' => now(),
                ]);

            SendLineNotificationJob::dispatch((string) $id);
        }

        return $ids->count();
    }

    public function ensureDefaultTemplates(string $tenantId): void
    {
        $now = now();
        foreach (self::EVENT_KEYS as $eventKey) {
            TenantLineMessageTemplate::query()->firstOrCreate(
                ['tenant_id' => $tenantId, 'event_key' => $eventKey],
                [
                    'id' => 'tlt_'.Str::ulid()->toBase32(),
                    'enabled' => true,
                    'message_type' => 'flex',
                    'title' => $this->eventDefinition($eventKey)['label'],
                    'body_text' => $this->defaultBody($eventKey),
                    'flex_json' => $this->defaultFlexTemplate($eventKey),
                    'variables_json' => $this->variablesForEvent($eventKey),
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }
    }

    public function renderMessages(TenantLineMessageTemplate $template, array $variables): array
    {
        $eventKey = (string) $template->event_key;

        if ($template->message_type === 'text') {
            return [[
                'type' => 'text',
                'text' => $this->renderString($this->bodyForRendering((string) $template->body_text, $eventKey), $variables),
            ]];
        }

        $flex = is_array($template->flex_json) ? $template->flex_json : $this->defaultFlexTemplate($eventKey);
        if ($this->isDefaultFlexTemplate($flex, $eventKey)) {
            $flex = $this->defaultFlexTemplate($eventKey);
        }
        $rendered = $this->renderValue($flex, $variables);

        return [[
            'type' => 'flex',
            'altText' => $this->renderString((string) $template->title, $variables),
            'contents' => $rendered,
        ]];
    }

    private function bodyForRendering(string $body, string $eventKey): string
    {
        $normalizedBody = $this->normalizeLineTemplateText($body);
        foreach ([$this->legacyDefaultBody($eventKey), $this->defaultBody($eventKey)] as $candidate) {
            if ($candidate !== '' && $normalizedBody === $this->normalizeLineTemplateText($candidate)) {
                return $this->defaultBody($eventKey);
            }
        }

        return $body;
    }

    /**
     * @param array<string, mixed> $flex
     */
    private function isDefaultFlexTemplate(array $flex, string $eventKey): bool
    {
        $title = Arr::get($flex, 'body.contents.0.text');
        $body = Arr::get($flex, 'body.contents.1.text');

        return $title === '{{event.title}}'
            && is_string($body)
            && $this->bodyForRendering($body, $eventKey) === $this->defaultBody($eventKey);
    }

    private function normalizeLineTemplateText(string $value): string
    {
        return trim((string) preg_replace('/\s+/', ' ', $value));
    }

    private function renderValue(mixed $value, array $variables): mixed
    {
        if (is_string($value)) {
            return $this->renderString($value, $variables);
        }

        if (is_array($value)) {
            $result = [];
            foreach ($value as $key => $child) {
                $result[$key] = $this->renderValue($child, $variables);
            }

            return $result;
        }

        return $value;
    }

    private function renderString(string $value, array $variables): string
    {
        $rendered = (string) preg_replace_callback('/{{\s*([a-zA-Z0-9_.-]+)\s*}}/', function (array $matches) use ($variables): string {
            $replacement = Arr::get($variables, $matches[1]);

            if (is_array($replacement) || is_object($replacement)) {
                return '';
            }

            return (string) ($replacement ?? '');
        }, $value);

        $rendered = (string) preg_replace("/[ \t]+\n/", "\n", $rendered);
        $rendered = (string) preg_replace("/\n{2,}/", "\n", $rendered);

        return trim($rendered);
    }

    private function templateForEvent(string $tenantId, string $eventKey): ?TenantLineMessageTemplate
    {
        $this->ensureDefaultTemplates($tenantId);

        return TenantLineMessageTemplate::query()
            ->where('tenant_id', $tenantId)
            ->where('event_key', $eventKey)
            ->first();
    }

    private function deliveryLineUserId(LineNotificationDelivery $delivery): string
    {
        $lineUserId = $this->cleanString($delivery->line_user_id);

        if ($lineUserId !== '' || $this->cleanString($delivery->customer_id) === '') {
            return $lineUserId;
        }

        $identity = CustomerLineIdentity::query()
            ->where('tenant_id', $delivery->tenant_id)
            ->where('customer_id', $delivery->customer_id)
            ->where('notification_enabled', true)
            ->first();

        if (! $identity instanceof CustomerLineIdentity) {
            return '';
        }

        $lineUserId = $this->cleanString($identity->line_user_id);

        if ($lineUserId !== '') {
            $delivery->fill([
                'line_user_id' => $lineUserId,
                'updated_at' => now(),
            ])->save();
        }

        return $lineUserId;
    }

    private function deliveryMessages(LineNotificationDelivery $delivery): array
    {
        $messages = is_array($delivery->message_json) ? $delivery->message_json : [];

        if ($messages !== []) {
            return $messages;
        }

        $metadata = is_array($delivery->metadata_json) ? $delivery->metadata_json : [];
        $variables = is_array($metadata['variables'] ?? null) ? $metadata['variables'] : [];
        $template = $this->templateForEvent((string) $delivery->tenant_id, (string) $delivery->event_key);

        if (! $template instanceof TenantLineMessageTemplate || ! $template->enabled) {
            return [];
        }

        $messages = $this->renderMessages($template, $variables);

        if ($messages !== []) {
            $delivery->fill([
                'message_json' => $messages,
                'updated_at' => now(),
            ])->save();
        }

        return $messages;
    }

    private function failDelivery(LineNotificationDelivery $delivery, string $code, string $message): void
    {
        $delivery->fill([
            'status' => 'failed',
            'attempts' => ((int) $delivery->attempts) + 1,
            'last_error' => $code.': '.$message,
            'line_response_json' => ['error_code' => $code],
            'updated_at' => now(),
        ])->save();
    }

    private function lineRetryKey(LineNotificationDelivery $delivery): string
    {
        $hex = substr(hash('sha256', $delivery->id.':'.$delivery->attempts), 0, 32);
        $hex[12] = '4';
        $hex[16] = dechex((hexdec($hex[16]) & 0x3) | 0x8);

        return sprintf(
            '%s-%s-%s-%s-%s',
            substr($hex, 0, 8),
            substr($hex, 8, 4),
            substr($hex, 12, 4),
            substr($hex, 16, 4),
            substr($hex, 20, 12),
        );
    }

    private function serializeChannel(?TenantLineChannel $channel, string $tenantId): array
    {
        $callbackUrl = $this->customerCallbackUrl($tenantId);

        if (! $channel instanceof TenantLineChannel) {
            return [
                'configured' => false,
                'status' => 'inactive',
                'callback_url' => $callbackUrl,
                'webhook_url' => '/api/v1/public/line/webhook',
            ];
        }

        return [
            'configured' => true,
            'status' => $channel->status,
            'messaging_access_token_masked' => $this->masked($this->decrypted($channel, 'messaging_access_token_encrypted')),
            'messaging_channel_secret_masked' => $this->masked($this->decrypted($channel, 'messaging_channel_secret_encrypted')),
            'login_channel_id_masked' => $this->masked($this->decrypted($channel, 'login_channel_id_encrypted')),
            'login_channel_secret_masked' => $this->masked($this->decrypted($channel, 'login_channel_secret_encrypted')),
            'liff_id' => $this->supportsLiffId() ? $channel->liff_id : null,
            'bot_user_id' => $channel->bot_user_id,
            'bot_basic_id' => $channel->bot_basic_id,
            'bot_display_name' => $channel->bot_display_name,
            'bot_picture_url' => $channel->bot_picture_url,
            'chat_mode' => $channel->chat_mode,
            'verified_at' => $channel->verified_at,
            'last_tested_at' => $channel->last_tested_at,
            'last_test_status' => $channel->last_test_status,
            'last_test_message' => $channel->last_test_message,
            'callback_url' => $callbackUrl,
            'webhook_url' => '/api/v1/public/line/webhook',
        ];
    }

    private function serializeTemplate(TenantLineMessageTemplate $template): array
    {
        return [
            'id' => $template->id,
            'event_key' => $template->event_key,
            'label' => $this->eventDefinition((string) $template->event_key)['label'],
            'description' => $this->eventDefinition((string) $template->event_key)['description'],
            'enabled' => (bool) $template->enabled,
            'message_type' => $template->message_type,
            'title' => $template->title,
            'body_text' => $template->body_text,
            'flex_json' => $template->flex_json,
            'variables' => $template->variables_json ?: $this->variablesForEvent((string) $template->event_key),
            'updated_at' => $template->updated_at,
        ];
    }

    private function serializeIdentity(CustomerLineIdentity $identity): array
    {
        $customer = Customer::query()->where('id', $identity->customer_id)->first();

        return [
            'id' => $identity->id,
            'customer_id' => $identity->customer_id,
            'customer_name' => $customer?->name,
            'customer_phone' => $customer?->phone,
            'line_user_id' => $identity->line_user_id,
            'display_name' => $identity->display_name,
            'picture_url' => $identity->picture_url,
            'friend_flag' => (bool) $identity->friend_flag,
            'notification_enabled' => (bool) $identity->notification_enabled,
            'linked_at' => $identity->linked_at,
            'last_login_at' => $identity->last_login_at,
            'unreachable_at' => $identity->unreachable_at,
        ];
    }

    private function serializeDelivery(LineNotificationDelivery $delivery): array
    {
        return [
            'id' => $delivery->id,
            'customer_id' => $delivery->customer_id,
            'line_user_id' => $delivery->line_user_id,
            'event_key' => $delivery->event_key,
            'source_type' => $delivery->source_type,
            'source_id' => $delivery->source_id,
            'status' => $delivery->status,
            'attempts' => (int) $delivery->attempts,
            'sent_at' => $delivery->sent_at,
            'last_error' => $delivery->last_error,
            'created_at' => $delivery->created_at,
            'updated_at' => $delivery->updated_at,
        ];
    }

    private function eventDefinition(string $eventKey): array
    {
        return match ($eventKey) {
            'topup.created' => ['label' => 'Topup submitted', 'description' => 'Customer submitted a wallet topup request.'],
            'order.paid' => ['label' => 'Lottery order paid', 'description' => 'Customer purchased lottery tickets successfully.'],
            'activity.entry.created' => ['label' => 'Activity joined', 'description' => 'Customer joined a partner activity.'],
            'reward_claim.submitted' => ['label' => 'Reward claim submitted', 'description' => 'Customer submitted a reward cashout claim.'],
            'topup.status_updated' => ['label' => 'Topup status updated', 'description' => 'Partner approved or rejected a topup.'],
            'reward_claim.status_updated' => ['label' => 'Reward claim updated', 'description' => 'Partner updated reward claim status.'],
            'activity_claim.status_updated' => ['label' => 'Activity payout updated', 'description' => 'Partner updated activity payout status.'],
            default => ['label' => Str::of($eventKey)->replace('.', ' ')->title()->toString(), 'description' => 'LINE notification event.'],
        };
    }

    private function defaultBody(string $eventKey): string
    {
        return match ($eventKey) {
            'topup.created' => "รับรายการเติมเงินแล้ว\nยอด: {{topup.amount_baht}} บาท\nเลขอ้างอิง: {{topup.reference}}\nสถานะ: รอตรวจสอบ",
            'order.paid' => "ซื้อสลากสำเร็จ\nจำนวน: {{order.ticket_count}} ใบ\nยอดชำระ: {{order.amount_baht}} บาท\nเลขอ้างอิง: {{order.reference}}",
            'activity.entry.created' => "เข้าร่วมกิจกรรมสำเร็จ\nกิจกรรม: {{activity.name}}\nเลขที่เลือก: {{activity.selected_number}}",
            'reward_claim.submitted' => "รับคำขอขึ้นเงินรางวัลแล้ว\nยอด: {{claim.amount_baht}} บาท\nเลขอ้างอิง: {{claim.reference}}\nสถานะ: รอตรวจสอบ",
            'topup.status_updated' => "อัปเดตรายการเติมเงิน\nสถานะ: {{topup.status_label}}\nยอด: {{topup.amount_baht}} บาท\nเลขอ้างอิง: {{topup.reference}}\n{{topup.reason}}",
            'reward_claim.status_updated' => "อัปเดตการขึ้นเงินรางวัล\nสถานะ: {{claim.status_label}}\nยอด: {{claim.amount_baht}} บาท\nเลขอ้างอิง: {{claim.reference}}\n{{claim.reason}}",
            'activity_claim.status_updated' => "อัปเดตการจ่ายเงินกิจกรรม\nสถานะ: {{claim.status_label}}\nยอด: {{claim.amount_baht}} บาท\nเลขอ้างอิง: {{claim.reference}}\n{{claim.reason}}",
            default => '{{event.title}}',
        };
    }

    private function legacyDefaultBody(string $eventKey): string
    {
        return match ($eventKey) {
            'topup.created' => 'รับรายการเติมเงิน {{topup.amount_baht}} บาท เลขที่ {{topup.reference}} แล้ว',
            'order.paid' => 'ซื้อสลากสำเร็จ {{order.ticket_count}} ใบ ยอด {{order.amount_baht}} บาท เลขที่ {{order.reference}}',
            'activity.entry.created' => 'เข้าร่วมกิจกรรม {{activity.name}} เลขที่เลือก {{activity.selected_number}} สำเร็จ',
            'reward_claim.submitted' => 'รับคำขอขึ้นเงินรางวัล {{claim.amount_baht}} บาท เลขที่ {{claim.reference}} แล้ว',
            'topup.status_updated' => 'รายการเติมเงิน {{topup.reference}} เป็นสถานะ {{topup.status_label}} {{topup.reason}}',
            'reward_claim.status_updated' => 'รายการขึ้นเงินรางวัล {{claim.reference}} เป็นสถานะ {{claim.status_label}} {{claim.reason}}',
            'activity_claim.status_updated' => 'รายการจ่ายเงินกิจกรรม {{claim.reference}} เป็นสถานะ {{claim.status_label}} {{claim.reason}}',
            default => '',
        };
    }

    private function defaultFlexTemplate(string $eventKey): array
    {
        return [
            'type' => 'bubble',
            'body' => [
                'type' => 'box',
                'layout' => 'vertical',
                'spacing' => 'md',
                'contents' => [
                    [
                        'type' => 'text',
                        'text' => '{{event.title}}',
                        'weight' => 'bold',
                        'size' => 'lg',
                        'wrap' => true,
                        'color' => '#0B72D9',
                    ],
                    [
                        'type' => 'text',
                        'text' => $this->defaultBody($eventKey),
                        'size' => 'sm',
                        'wrap' => true,
                        'color' => '#1F2937',
                        'margin' => 'md',
                    ],
                    [
                        'type' => 'separator',
                        'margin' => 'md',
                    ],
                    [
                        'type' => 'text',
                        'text' => 'ลูกค้า: {{customer.name}} {{customer.phone}}',
                        'size' => 'xs',
                        'wrap' => true,
                        'color' => '#6B7280',
                    ],
                    [
                        'type' => 'text',
                        'text' => 'ร้าน: {{tenant.name}}',
                        'size' => 'xs',
                        'wrap' => true,
                        'color' => '#6B7280',
                    ],
                ],
            ],
        ];
    }

    private function variablesForEvent(string $eventKey): array
    {
        return [
            'event.title',
            'tenant.name',
            'customer.name',
            'customer.phone',
            ...match ($eventKey) {
                'topup.created', 'topup.status_updated' => ['topup.reference', 'topup.amount_baht', 'topup.status_label', 'topup.reason'],
                'order.paid' => ['order.reference', 'order.amount_baht', 'order.ticket_count'],
                'activity.entry.created' => ['activity.name', 'activity.selected_number', 'activity.prediction_type'],
                'reward_claim.submitted', 'reward_claim.status_updated', 'activity_claim.status_updated' => ['claim.reference', 'claim.amount_baht', 'claim.status_label', 'claim.reason'],
                default => [],
            },
        ];
    }

    private function sampleVariables(string $eventKey): array
    {
        return [
            'event' => ['title' => $this->eventDefinition($eventKey)['label']],
            'tenant' => ['name' => 'Partner Shop'],
            'customer' => ['name' => 'ลูกค้าตัวอย่าง', 'phone' => '0812345678'],
            'topup' => ['reference' => 'TOP12345', 'amount_baht' => '500.00', 'status_label' => 'อนุมัติแล้ว', 'reason' => ''],
            'order' => ['reference' => 'ORD12345', 'amount_baht' => '800.00', 'ticket_count' => '10'],
            'activity' => ['name' => 'แผงเลขนำโชค', 'selected_number' => '99', 'prediction_type' => 'เลขท้าย 2 ตัว'],
            'claim' => ['reference' => 'CLM12345', 'amount_baht' => '4,000.00', 'status_label' => 'จ่ายแล้ว', 'reason' => ''],
        ];
    }

    private function masked(string $value): string
    {
        if ($value === '') {
            return '';
        }

        if (strlen($value) <= 10) {
            return str_repeat('*', strlen($value));
        }

        return substr($value, 0, 4).'...'.substr($value, -4);
    }

    private function cleanString(mixed $value): string
    {
        return trim((string) $value);
    }

    private function connectionSecret(?TenantLineChannel $channel, array $payload, string $payloadKey, string $encryptedField): string
    {
        $value = $this->cleanString($payload[$payloadKey] ?? null);

        if ($value !== '' || ! $channel instanceof TenantLineChannel) {
            return $value;
        }

        return $this->decrypted($channel, $encryptedField);
    }

    private function encryptionKeyConfigured(): bool
    {
        return $this->cleanString(config('app.key')) !== '';
    }

    private function supportsLiffId(): bool
    {
        return Schema::hasTable('tenant_line_channels')
            && Schema::hasColumn('tenant_line_channels', 'liff_id');
    }

    private function customerCallbackUrl(string $tenantId): string
    {
        $configured = $this->cleanString(config('platform.line.callback_url', ''));

        if ($configured !== '' && ! str_contains($configured, '/api/v1/customer/auth/line/callback')) {
            return $configured;
        }

        $host = $this->primaryStorefrontHost($tenantId);
        $scheme = preg_match('/(^localhost$|\.localhost$|\.test$)/i', $host) ? 'http' : 'https';

        return $scheme.'://'.$host.'/line/callback';
    }

    private function primaryStorefrontHost(string $tenantId): string
    {
        $host = PartnerTenantDomain::query()
            ->forTenant($tenantId)
            ->orderByDesc('is_primary')
            ->orderBy('host')
            ->value('host');

        if ($host !== null) {
            return TenantHostNormalizer::normalize((string) $host);
        }

        $tenantCode = PartnerTenant::whereKey($tenantId)->value('code');

        return TenantHostNormalizer::normalize(($tenantCode ?: $tenantId).'.newpaotang.test');
    }
}

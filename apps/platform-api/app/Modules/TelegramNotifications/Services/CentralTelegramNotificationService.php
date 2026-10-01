<?php

namespace App\Modules\TelegramNotifications\Services;

use App\Jobs\SendTelegramNotificationJob;
use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\PartnerTenant;
use App\Models\TelegramBotConnection;
use App\Models\TelegramChat;
use App\Models\TelegramMessageTemplate;
use App\Models\TelegramNotificationDelivery;
use App\Models\TenantTelegramNotificationRoute;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CentralTelegramNotificationService
{
    private const BOT_ID = 'tgb_central';

    public const EVENT_KEYS = [
        'topup.submitted',
        'topup.status_updated',
        'commission.submitted',
        'commission.status_updated',
        'reward_claim.submitted',
        'reward_claim.status_updated',
        'order.paid',
        'activity.entry.created',
        'activity_claim.status_updated',
        'activity.result.published',
    ];

    private const ADMIN_REVIEW_EVENT_KEYS = [
        'topup.status_updated',
        'commission.status_updated',
        'reward_claim.status_updated',
        'activity_claim.status_updated',
    ];

    public function __construct(private readonly TelegramBotClient $telegram)
    {
    }

    public function show(): array
    {
        $this->ensureDefaultTemplates();

        return [
            'bot' => $this->serializeBot($this->bot()),
            'events' => array_map(fn (string $event): array => $this->eventDefinition($event), self::EVENT_KEYS),
            'templates' => $this->templates(),
        ];
    }

    public function updateBot(array $payload): array
    {
        $token = $this->cleanString($payload['bot_token'] ?? '');
        $status = in_array(($payload['status'] ?? 'active'), ['active', 'inactive'], true) ? (string) $payload['status'] : 'active';

        if ($token === '') {
            return ['error' => 'validation_failed', 'errors' => ['bot_token' => ['The Telegram bot token is required.']]];
        }

        if (! $this->encryptionKeyConfigured()) {
            return [
                'error' => 'telegram_encryption_not_configured',
                'message' => 'เกิดข้อผิดพลาดในการบันทึก Telegram bot กรุณาตรวจสอบ APP_KEY แล้วกด Save ใหม่อีกครั้ง',
            ];
        }

        $check = $this->telegram->getMe($token);

        if (($check['ok'] ?? false) !== true) {
            return [
                'error' => 'telegram_verification_failed',
                'errors' => [
                    'bot_token' => ['Telegram bot verification failed: '.($check['message'] ?? 'unknown error')],
                ],
            ];
        }

        $bot = is_array($check['data'] ?? null) ? $check['data'] : [];
        $now = now();

        try {
            $encryptedToken = Crypt::encryptString($token);
        } catch (\Throwable) {
            return [
                'error' => 'telegram_encryption_failed',
                'message' => 'เกิดข้อผิดพลาดในการเข้ารหัส Telegram bot token กรุณากด Save ใหม่อีกครั้ง',
            ];
        }

        TelegramBotConnection::query()->updateOrCreate(
            ['id' => self::BOT_ID],
            [
                'status' => $status,
                'bot_token_encrypted' => $encryptedToken,
                'bot_id' => (string) ($bot['id'] ?? ''),
                'bot_username' => $this->cleanString($bot['username'] ?? '') ?: null,
                'bot_first_name' => $this->cleanString($bot['first_name'] ?? '') ?: null,
                'verified_at' => $now,
                'last_test_status' => 'verified',
                'last_test_message' => 'Telegram bot verified.',
                'updated_at' => $now,
            ],
        );

        $this->ensureDefaultTemplates();

        return ['resource' => $this->show()];
    }

    public function disconnectBot(): array
    {
        TelegramBotConnection::query()->whereKey(self::BOT_ID)->delete();

        return ['resource' => $this->show()];
    }

    public function syncChats(): array
    {
        $bot = $this->bot();
        $token = $bot instanceof TelegramBotConnection ? $this->decrypted($bot) : '';

        if (! $bot instanceof TelegramBotConnection || $bot->status !== 'active' || $token === '') {
            return ['error' => 'telegram_bot_not_ready'];
        }

        $offset = $bot->last_update_id === null ? null : ((int) $bot->last_update_id) + 1;
        $result = $this->telegram->getUpdates($token, $offset);

        if (($result['ok'] ?? false) !== true) {
            return [
                'error' => 'telegram_sync_failed',
                'message' => (string) ($result['message'] ?? 'Telegram getUpdates failed.'),
            ];
        }

        $updates = is_array($result['data'] ?? null) ? $result['data'] : [];
        $maxUpdateId = $bot->last_update_id;
        $synced = 0;

        foreach ($updates as $update) {
            if (! is_array($update)) {
                continue;
            }

            if (isset($update['update_id'])) {
                $maxUpdateId = max((int) ($maxUpdateId ?? 0), (int) $update['update_id']);
            }

            $chat = $this->chatFromUpdate($update);

            if ($chat === []) {
                continue;
            }

            $this->upsertChat($chat, $update);
            $synced++;
        }

        $bot->fill([
            'last_update_id' => $maxUpdateId,
            'last_synced_at' => now(),
            'updated_at' => now(),
        ])->save();

        return [
            'resource' => [
                'bot' => $this->serializeBot($bot->refresh()),
                'synced_count' => $synced,
                'chats' => $this->chats()['data'],
            ],
        ];
    }

    public function chats(array $query = []): array
    {
        $limit = max(1, min(200, (int) ($query['limit'] ?? 100)));
        $rows = TelegramChat::query()
            ->orderByDesc('last_seen_at')
            ->orderBy('title')
            ->limit($limit)
            ->get();

        return [
            'data' => $rows->map(fn (TelegramChat $chat): array => $this->serializeChat($chat))->all(),
        ];
    }

    public function testSend(array $payload): array
    {
        $chatId = $this->cleanString($payload['chat_id'] ?? '');
        $message = trim((string) ($payload['message'] ?? ''));
        $errors = [];

        if ($chatId === '' || ! TelegramChat::query()->where('chat_id', $chatId)->exists()) {
            $errors['chat_id'][] = 'Select a discovered Telegram chat before sending a test message.';
        }

        if ($message === '') {
            $message = "ทดสอบแจ้งเตือน Telegram จาก Siamblend\nเวลา: ".$this->occurredAt();
        }

        if (mb_strlen($message) > 3500) {
            $errors['message'][] = 'The test message is too long.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $bot = $this->bot();
        $token = $bot instanceof TelegramBotConnection ? $this->decrypted($bot) : '';

        if (! $bot instanceof TelegramBotConnection || $bot->status !== 'active' || $token === '') {
            return [
                'error' => 'telegram_bot_not_ready',
                'message' => 'Telegram bot is not active or token is unavailable.',
            ];
        }

        $result = $this->telegram->sendMessage($token, $chatId, htmlspecialchars($message, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'));
        $now = now();

        $bot->fill([
            'last_test_status' => ($result['ok'] ?? false) === true ? 'sent' : 'failed',
            'last_test_message' => ($result['ok'] ?? false) === true
                ? 'Test message sent to '.$chatId
                : (string) ($result['message'] ?? 'Telegram test send failed.'),
            'updated_at' => $now,
        ])->save();

        if (($result['ok'] ?? false) !== true) {
            return [
                'error' => 'telegram_test_send_failed',
                'message' => (string) ($result['message'] ?? 'Telegram test send failed.'),
                'details' => ['status' => (int) ($result['status'] ?? 0)],
            ];
        }

        return [
            'resource' => [
                'status' => 'sent',
                'chat_id' => $chatId,
                'sent_at' => $now,
                'bot' => $this->serializeBot($bot->refresh()),
            ],
        ];
    }

    public function routes(): array
    {
        $tenants = PartnerTenant::query()
            ->orderBy('name')
            ->get(['id', 'code', 'name', 'status']);
        $routes = TenantTelegramNotificationRoute::query()->get()->keyBy(fn (TenantTelegramNotificationRoute $route): string => $route->tenant_id.':'.$route->event_key);
        $events = array_map(fn (string $event): array => $this->eventDefinition($event), self::EVENT_KEYS);

        $data = [];
        foreach ($tenants as $tenant) {
            foreach (self::EVENT_KEYS as $eventKey) {
                $route = $routes->get((string) $tenant->id.':'.$eventKey);
                $data[] = [
                    'tenant_id' => (string) $tenant->id,
                    'tenant_code' => (string) $tenant->code,
                    'tenant_name' => (string) $tenant->name,
                    'tenant_status' => (string) $tenant->status,
                    'event_key' => $eventKey,
                    'event_label' => $this->eventDefinition($eventKey)['label'],
                    'chat_id' => $route?->chat_id,
                    'enabled' => (bool) ($route?->enabled ?? false),
                    'updated_at' => $route?->updated_at,
                ];
            }
        }

        return [
            'data' => $data,
            'events' => $events,
            'chats' => $this->chats()['data'],
        ];
    }

    public function updateRoutes(array $payload): array
    {
        $rows = is_array($payload['routes'] ?? null) ? $payload['routes'] : [];
        $errors = [];
        $now = now();

        foreach ($rows as $index => $row) {
            if (! is_array($row)) {
                continue;
            }

            $tenantId = $this->cleanString($row['tenant_id'] ?? '');
            $eventKey = $this->cleanString($row['event_key'] ?? '');
            $chatId = $this->cleanString($row['chat_id'] ?? '');
            $enabled = (bool) ($row['enabled'] ?? false);

            if (! PartnerTenant::query()->whereKey($tenantId)->exists()) {
                $errors["routes.$index.tenant_id"][] = 'The tenant is invalid.';
            }

            if (! in_array($eventKey, self::EVENT_KEYS, true)) {
                $errors["routes.$index.event_key"][] = 'The event key is invalid.';
            }

            if ($enabled && ($chatId === '' || ! TelegramChat::query()->where('chat_id', $chatId)->exists())) {
                $errors["routes.$index.chat_id"][] = 'The Telegram chat is required when the route is enabled.';
            }
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        foreach ($rows as $row) {
            if (! is_array($row)) {
                continue;
            }

            $tenantId = $this->cleanString($row['tenant_id'] ?? '');
            $eventKey = $this->cleanString($row['event_key'] ?? '');
            $chatId = $this->cleanString($row['chat_id'] ?? '');
            $enabled = (bool) ($row['enabled'] ?? false);

            TenantTelegramNotificationRoute::query()->updateOrCreate(
                ['tenant_id' => $tenantId, 'event_key' => $eventKey],
                [
                    'id' => (string) (TenantTelegramNotificationRoute::query()->where('tenant_id', $tenantId)->where('event_key', $eventKey)->value('id') ?: 'tgr_'.Str::ulid()->toBase32()),
                    'chat_id' => $chatId === '' ? null : $chatId,
                    'enabled' => $enabled,
                    'updated_at' => $now,
                ],
            );
        }

        return ['resource' => $this->routes()];
    }

    public function templates(): array
    {
        $this->ensureDefaultTemplates();
        $order = array_flip(self::EVENT_KEYS);

        return TelegramMessageTemplate::query()
            ->get()
            ->sortBy(fn (TelegramMessageTemplate $template): int => $order[(string) $template->event_key] ?? 999)
            ->values()
            ->map(fn (TelegramMessageTemplate $template): array => $this->serializeTemplate($template))
            ->all();
    }

    public function updateTemplate(string $eventKey, array $payload): array
    {
        if (! in_array($eventKey, self::EVENT_KEYS, true)) {
            return ['error' => 'not_found'];
        }

        $title = $this->cleanString($payload['title'] ?? '');
        $body = trim((string) ($payload['body_text'] ?? ''));
        $errors = [];

        if ($title === '') {
            $errors['title'][] = 'The title field is required.';
        }

        if ($body === '') {
            $errors['body_text'][] = 'The body text field is required.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $this->ensureDefaultTemplates();
        $template = TelegramMessageTemplate::query()->where('event_key', $eventKey)->first();

        if (! $template instanceof TelegramMessageTemplate) {
            return ['error' => 'not_found'];
        }

        $template->fill([
            'enabled' => (bool) ($payload['enabled'] ?? true),
            'title' => $title,
            'body_text' => $body,
            'variables_json' => $this->variablesForEvent($eventKey),
            'updated_at' => now(),
        ])->save();

        return ['resource' => $this->serializeTemplate($template)];
    }

    public function deliveries(array $query): array
    {
        $rows = TelegramNotificationDelivery::query()
            ->when($this->cleanString($query['status'] ?? '') !== '', fn ($q) => $q->where('status', $this->cleanString($query['status'] ?? '')))
            ->orderByDesc('created_at')
            ->limit(max(1, min(200, (int) ($query['limit'] ?? 100))))
            ->get();

        return [
            'data' => $rows->map(fn (TelegramNotificationDelivery $delivery): array => $this->serializeDelivery($delivery))->all(),
        ];
    }

    public function enqueue(string $tenantId, string $eventKey, string $sourceType, string $sourceId, array $variables = []): void
    {
        if ($tenantId === '' || $sourceId === '' || ! in_array($eventKey, self::EVENT_KEYS, true)) {
            return;
        }

        $callback = function () use ($tenantId, $eventKey, $sourceType, $sourceId, $variables): void {
            $bot = $this->bot();
            $route = TenantTelegramNotificationRoute::query()
                ->where('tenant_id', $tenantId)
                ->where('event_key', $eventKey)
                ->where('enabled', true)
                ->first();
            $template = TelegramMessageTemplate::query()
                ->where('event_key', $eventKey)
                ->where('enabled', true)
                ->first();

            if (! $bot instanceof TelegramBotConnection || $bot->status !== 'active' || ! $route instanceof TenantTelegramNotificationRoute || $this->cleanString($route->chat_id) === '') {
                return;
            }

            $message = $template instanceof TelegramMessageTemplate
                ? $this->renderTemplate($template, $variables)
                : $this->renderTemplateString($this->defaultTemplate($eventKey), $variables);

            $message = $this->appendReviewerLine($eventKey, $message, $variables);

            if ($message === '') {
                return;
            }

            $delivery = TelegramNotificationDelivery::query()->firstOrCreate(
                [
                    'tenant_id' => $tenantId,
                    'event_key' => $eventKey,
                    'source_type' => $sourceType,
                    'source_id' => $sourceId,
                ],
                [
                    'id' => 'tgd_'.Str::ulid()->toBase32(),
                    'chat_id' => (string) $route->chat_id,
                    'status' => 'queued',
                    'attempts' => 0,
                    'message_text' => $message,
                    'metadata_json' => ['variables' => $variables],
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
            );

            if ($delivery->wasRecentlyCreated) {
                SendTelegramNotificationJob::dispatch((string) $delivery->id);
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
        $delivery = TelegramNotificationDelivery::query()->whereKey($deliveryId)->first();

        if (! $delivery instanceof TelegramNotificationDelivery || $delivery->status === 'sent') {
            return;
        }

        $bot = $this->bot();
        $token = $bot instanceof TelegramBotConnection ? $this->decrypted($bot) : '';
        $chatId = $this->cleanString($delivery->chat_id);
        $message = trim((string) $delivery->message_text);

        if (! $bot instanceof TelegramBotConnection || $bot->status !== 'active') {
            $this->failDelivery($delivery, 'telegram_bot_inactive', 'Telegram bot is not active.');
            return;
        }

        if ($token === '') {
            $this->failDelivery($delivery, 'telegram_token_unavailable', 'Telegram bot token is missing or cannot be decrypted.');
            return;
        }

        if ($chatId === '' || $message === '') {
            $this->failDelivery($delivery, 'telegram_payload_missing', 'Telegram chat or message payload is missing.');
            return;
        }

        $result = $this->telegram->sendMessage($token, $chatId, $message);
        $attempts = ((int) $delivery->attempts) + 1;

        if (($result['ok'] ?? false) === true) {
            $delivery->fill([
                'status' => 'sent',
                'attempts' => $attempts,
                'sent_at' => now(),
                'last_error' => null,
                'telegram_response_json' => $result['data'] ?? [],
                'updated_at' => now(),
            ])->save();
            return;
        }

        $status = (int) ($result['status'] ?? 0);
        $retryable = in_array($status, [429, 500, 502, 503, 504], true) && $attempts < 3;
        $nextRetry = $retryable ? now()->addSeconds($status === 429 ? 60 : 120 * $attempts) : null;

        $delivery->fill([
            'status' => $retryable ? 'retryable_failed' : 'failed',
            'attempts' => $attempts,
            'next_retry_at' => $nextRetry,
            'last_error' => (string) ($result['message'] ?? 'Telegram sendMessage failed.'),
            'telegram_response_json' => ['status' => $status, 'data' => $result['data'] ?? []],
            'updated_at' => now(),
        ])->save();

        if ($retryable) {
            SendTelegramNotificationJob::dispatch((string) $delivery->id)->delay($nextRetry);
        }
    }

    public function ensureDefaultTemplates(): void
    {
        $now = now();
        foreach (self::EVENT_KEYS as $eventKey) {
            TelegramMessageTemplate::query()->firstOrCreate(
                ['event_key' => $eventKey],
                [
                    'id' => 'tgt_'.Str::ulid()->toBase32(),
                    'enabled' => true,
                    'title' => $this->eventDefinition($eventKey)['label'],
                    'body_text' => $this->defaultTemplate($eventKey),
                    'variables_json' => $this->variablesForEvent($eventKey),
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }
    }

    private function bot(): ?TelegramBotConnection
    {
        return TelegramBotConnection::query()->whereKey(self::BOT_ID)->first();
    }

    private function decrypted(TelegramBotConnection $bot): string
    {
        $value = (string) ($bot->bot_token_encrypted ?? '');

        if ($value === '') {
            return '';
        }

        try {
            return Crypt::decryptString($value);
        } catch (\Throwable) {
            return '';
        }
    }

    private function chatFromUpdate(array $update): array
    {
        foreach (['message', 'edited_message', 'channel_post', 'edited_channel_post'] as $key) {
            $message = $update[$key] ?? null;
            if (is_array($message) && is_array($message['chat'] ?? null)) {
                return $message['chat'];
            }
        }

        return [];
    }

    private function upsertChat(array $chat, array $update): void
    {
        $chatId = $this->cleanString($chat['id'] ?? '');

        if ($chatId === '') {
            return;
        }

        TelegramChat::query()->updateOrCreate(
            ['chat_id' => $chatId],
            [
                'id' => (string) (TelegramChat::query()->where('chat_id', $chatId)->value('id') ?: 'tgc_'.Str::ulid()->toBase32()),
                'chat_type' => $this->cleanString($chat['type'] ?? '') ?: null,
                'title' => $this->cleanString($chat['title'] ?? '') ?: null,
                'username' => $this->cleanString($chat['username'] ?? '') ?: null,
                'first_name' => $this->cleanString($chat['first_name'] ?? '') ?: null,
                'last_name' => $this->cleanString($chat['last_name'] ?? '') ?: null,
                'last_seen_at' => now(),
                'metadata_json' => ['last_update_id' => $update['update_id'] ?? null],
                'updated_at' => now(),
            ],
        );
    }

    private function renderTemplate(TelegramMessageTemplate $template, array $variables): string
    {
        return $this->renderTemplateString((string) $template->body_text, $variables);
    }

    private function renderTemplateString(string $bodyText, array $variables): string
    {
        $rendered = (string) preg_replace_callback('/{{\s*([a-zA-Z0-9_.-]+)\s*}}/', function (array $matches) use ($variables): string {
            $value = Arr::get($variables, $matches[1]);

            if (is_array($value) || is_object($value)) {
                return '';
            }

            return htmlspecialchars((string) ($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }, $bodyText);

        $rendered = (string) preg_replace("/[ \t]+\n/", "\n", $rendered);
        $rendered = (string) preg_replace("/\n{2,}/", "\n", $rendered);

        return trim($rendered);
    }

    private function appendReviewerLine(string $eventKey, string $message, array $variables): string
    {
        if (! in_array($eventKey, self::ADMIN_REVIEW_EVENT_KEYS, true) || trim($message) === '') {
            return $message;
        }

        $username = $this->cleanString(Arr::get($variables, 'admin.username'));

        if ($username === '') {
            return $message;
        }

        if ($this->containsReviewerMarker($message)) {
            return $message;
        }

        return trim($message)."\nผู้ตรวจ: ".htmlspecialchars($username, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }

    private function containsReviewerMarker(string $message): bool
    {
        foreach (['ผู้ตรวจ:', 'ตรวจโดย:', 'Reviewer:', 'Reviewed by:', 'Admin:'] as $marker) {
            if (str_contains($message, $marker)) {
                return true;
            }
        }

        return false;
    }

    private function failDelivery(TelegramNotificationDelivery $delivery, string $code, string $message): void
    {
        $delivery->fill([
            'status' => 'failed',
            'attempts' => ((int) $delivery->attempts) + 1,
            'last_error' => $code.': '.$message,
            'telegram_response_json' => ['error_code' => $code],
            'updated_at' => now(),
        ])->save();
    }

    private function serializeBot(?TelegramBotConnection $bot): array
    {
        if (! $bot instanceof TelegramBotConnection) {
            return [
                'configured' => false,
                'status' => 'inactive',
            ];
        }

        return [
            'configured' => true,
            'status' => $bot->status,
            'bot_username' => $bot->bot_username,
            'bot_first_name' => $bot->bot_first_name,
            'bot_id' => $bot->bot_id,
            'bot_token_masked' => $this->masked($this->decrypted($bot)),
            'last_update_id' => $bot->last_update_id,
            'verified_at' => $bot->verified_at,
            'last_synced_at' => $bot->last_synced_at,
            'last_test_status' => $bot->last_test_status,
            'last_test_message' => $bot->last_test_message,
        ];
    }

    private function serializeChat(TelegramChat $chat): array
    {
        $label = $chat->title ?: trim((string) ($chat->first_name.' '.$chat->last_name)) ?: ($chat->username ?: $chat->chat_id);

        return [
            'id' => $chat->id,
            'chat_id' => $chat->chat_id,
            'label' => $label,
            'chat_type' => $chat->chat_type,
            'title' => $chat->title,
            'username' => $chat->username,
            'last_seen_at' => $chat->last_seen_at,
        ];
    }

    private function serializeTemplate(TelegramMessageTemplate $template): array
    {
        $eventKey = (string) $template->event_key;
        $bodyText = (string) $template->body_text;

        if (in_array($eventKey, self::ADMIN_REVIEW_EVENT_KEYS, true) && ! $this->containsReviewerMarker($bodyText)) {
            $bodyText = trim($bodyText)."\nผู้ตรวจ: {{ admin.username }}";
        }

        return [
            'id' => $template->id,
            'event_key' => $template->event_key,
            'label' => $this->eventDefinition($eventKey)['label'],
            'description' => $this->eventDefinition($eventKey)['description'],
            'enabled' => (bool) $template->enabled,
            'title' => $template->title,
            'body_text' => $bodyText,
            'variables' => $this->variablesForEvent($eventKey),
            'updated_at' => $template->updated_at,
        ];
    }

    private function serializeDelivery(TelegramNotificationDelivery $delivery): array
    {
        return [
            'id' => $delivery->id,
            'tenant_id' => $delivery->tenant_id,
            'tenant_name' => PartnerTenant::query()->whereKey((string) $delivery->tenant_id)->value('name'),
            'event_key' => $delivery->event_key,
            'event_label' => $this->eventDefinition((string) $delivery->event_key)['label'] ?? $delivery->event_key,
            'chat_id' => $delivery->chat_id,
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
            'topup.submitted' => ['label' => 'Topup waiting review', 'description' => 'Customer submitted a topup request waiting for tenant review.'],
            'topup.status_updated' => ['label' => 'Topup reviewed', 'description' => 'Tenant admin approved, rejected, or cancelled a topup request.'],
            'commission.submitted' => ['label' => 'Commission payout waiting review', 'description' => 'Affiliate commission payout/deposit/withdraw request is waiting for tenant review.'],
            'commission.status_updated' => ['label' => 'Commission payout reviewed', 'description' => 'Tenant admin reviewed an affiliate commission payout/withdrawal.'],
            'reward_claim.submitted' => ['label' => 'Reward claim waiting review', 'description' => 'Customer submitted a reward cashout claim waiting for tenant review.'],
            'reward_claim.status_updated' => ['label' => 'Reward claim reviewed', 'description' => 'Tenant admin updated a reward cashout claim.'],
            'order.paid' => ['label' => 'Order paid', 'description' => 'Customer purchased lottery tickets successfully.'],
            'activity.entry.created' => ['label' => 'Activity entry created', 'description' => 'Customer joined an activity and selected a number.'],
            'activity_claim.status_updated' => ['label' => 'Activity payout reviewed', 'description' => 'Tenant admin updated an activity payout claim.'],
            'activity.result.published' => ['label' => 'Activity result published', 'description' => 'Lucky board/cashback activity results were calculated.'],
            default => ['label' => Str::of($eventKey)->replace('.', ' ')->title()->toString(), 'description' => 'Telegram notification event.'],
        };
    }

    private function defaultTemplate(string $eventKey): string
    {
        return match ($eventKey) {
            'topup.submitted' => "<b>มีรายการเติมเงินรอตรวจสอบ</b>\nร้าน: {{ tenant.name }}\nลูกค้า: {{ customer.name }} {{ customer.phone }}\nยอด: {{ topup.amount_baht }} บาท\nเลขอ้างอิง: {{ topup.reference }}\nเวลา: {{ event.occurred_at }}",
            'topup.status_updated' => "<b>ตรวจสอบรายการเติมเงินแล้ว</b>\nร้าน: {{ tenant.name }}\nลูกค้า: {{ customer.name }} {{ customer.phone }}\nสถานะ: {{ topup.status_label }}\nยอด: {{ topup.amount_baht }} บาท\nเลขอ้างอิง: {{ topup.reference }}\n{{ topup.reason }}\nผู้ตรวจ: {{ admin.username }}\nเวลา: {{ event.occurred_at }}",
            'commission.submitted' => "<b>มีรายการคอมมิชชันรอตรวจสอบ</b>\nร้าน: {{ tenant.name }}\nลูกค้า/บัญชี: {{ commission.customer_name }}\nประเภท: {{ commission.type_label }}\nยอด: {{ commission.amount_baht }} บาท\nเลขอ้างอิง: {{ commission.reference }}\nเวลา: {{ event.occurred_at }}",
            'commission.status_updated' => "<b>ตรวจสอบรายการถอนคอมมิชชันแล้ว</b>\nร้าน: {{ tenant.name }}\nลูกค้า/บัญชี: {{ commission.customer_name }}\nประเภท: {{ commission.type_label }}\nสถานะ: {{ commission.status_label }}\nยอด: {{ commission.amount_baht }} บาท\nเลขอ้างอิง: {{ commission.reference }}\n{{ commission.reason }}\nผู้ตรวจ: {{ admin.username }}\nเวลา: {{ event.occurred_at }}",
            'reward_claim.submitted' => "<b>มีรายการขึ้นเงินรางวัลรอตรวจสอบ</b>\nร้าน: {{ tenant.name }}\nลูกค้า: {{ customer.name }} {{ customer.phone }}\nยอด: {{ claim.amount_baht }} บาท\nเลขอ้างอิง: {{ claim.reference }}\nเวลา: {{ event.occurred_at }}",
            'reward_claim.status_updated' => "<b>ตรวจสอบรายการขึ้นเงินรางวัลแล้ว</b>\nร้าน: {{ tenant.name }}\nลูกค้า: {{ customer.name }} {{ customer.phone }}\nสถานะ: {{ claim.status_label }}\nยอด: {{ claim.amount_baht }} บาท\nเลขอ้างอิง: {{ claim.reference }}\n{{ claim.reason }}\nผู้ตรวจ: {{ admin.username }}\nเวลา: {{ event.occurred_at }}",
            'order.paid' => "<b>ลูกค้าซื้อสลากสำเร็จ</b>\nร้าน: {{ tenant.name }}\nลูกค้า: {{ customer.name }} {{ customer.phone }}\nงวด: {{ order.draw_label }}\nจำนวน: {{ order.ticket_count }} ใบ\nยอด: {{ order.amount_baht }} บาท\nเลขอ้างอิง: {{ order.reference }}\nเวลา: {{ event.occurred_at }}",
            'activity.entry.created' => "<b>ลูกค้าเข้าร่วมกิจกรรม</b>\nร้าน: {{ tenant.name }}\nกิจกรรม: {{ activity.name }}\nประเภท: {{ activity.prediction_type_label }}\nลูกค้า: {{ customer.name }} {{ customer.phone }}\nเลขที่เลือก: {{ activity.selected_number }}\nสิทธิ์ที่ใช้: {{ activity.rights_used }}\nเวลา: {{ event.occurred_at }}",
            'activity_claim.status_updated' => "<b>ตรวจสอบรายการขึ้นเงินรางวัลกิจกรรมแล้ว</b>\nร้าน: {{ tenant.name }}\nลูกค้า: {{ customer.name }} {{ customer.phone }}\nสถานะ: {{ claim.status_label }}\nยอด: {{ claim.amount_baht }} บาท\nเลขอ้างอิง: {{ claim.reference }}\n{{ claim.reason }}\nผู้ตรวจ: {{ admin.username }}\nเวลา: {{ event.occurred_at }}",
            'activity.result.published' => "<b>ผลกิจกรรมออกแล้ว</b>\nร้าน: {{ tenant.name }}\nงวด: {{ activity.draw_label }}\n{{ activity.summary }}\nเวลา: {{ event.occurred_at }}",
            default => '{{ event.title }}',
        };
    }

    private function variablesForEvent(string $eventKey): array
    {
        return [
            'event.title',
            'event.occurred_at',
            'tenant.name',
            ...match ($eventKey) {
                'topup.submitted' => ['customer.name', 'customer.phone', 'topup.reference', 'topup.amount_baht'],
                'topup.status_updated' => ['customer.name', 'customer.phone', 'topup.reference', 'topup.amount_baht', 'topup.status_label', 'topup.reason', 'admin.username'],
                'commission.submitted' => ['commission.customer_name', 'commission.type_label', 'commission.reference', 'commission.amount_baht'],
                'commission.status_updated' => ['commission.customer_name', 'commission.type_label', 'commission.reference', 'commission.amount_baht', 'commission.status_label', 'commission.reason', 'admin.username'],
                'reward_claim.submitted' => ['customer.name', 'customer.phone', 'claim.reference', 'claim.amount_baht'],
                'reward_claim.status_updated', 'activity_claim.status_updated' => ['customer.name', 'customer.phone', 'claim.reference', 'claim.amount_baht', 'claim.status_label', 'claim.reason', 'admin.username'],
                'order.paid' => ['customer.name', 'customer.phone', 'order.reference', 'order.ticket_count', 'order.amount_baht', 'order.draw_label'],
                'activity.entry.created' => ['customer.name', 'customer.phone', 'activity.name', 'activity.prediction_type_label', 'activity.selected_number', 'activity.rights_used'],
                'activity.result.published' => ['activity.draw_label', 'activity.summary'],
                default => [],
            },
        ];
    }

    /**
     * @param array<string, mixed>|null $adminUser
     * @return array<string, string>
     */
    public function adminVariables(?array $adminUser): array
    {
        $adminUser ??= [];

        $id = $this->cleanString($adminUser['id'] ?? '');
        $username = $this->cleanString($adminUser['username'] ?? '');
        $name = $this->cleanString($adminUser['name'] ?? '');
        $email = $this->cleanString($adminUser['email'] ?? '');

        if ($id !== '' && ($username === '' || $name === '' || $email === '')) {
            $admin = AdminUser::query()->whereKey($id)->first(['id', 'username', 'name', 'email']);
            $username = $username !== '' ? $username : $this->cleanString($admin?->username);
            $name = $name !== '' ? $name : $this->cleanString($admin?->name);
            $email = $email !== '' ? $email : $this->cleanString($admin?->email);
        }

        $displayName = $username !== '' ? $username : ($name !== '' ? $name : ($email !== '' ? $email : $id));

        return [
            'id' => $id,
            'username' => $displayName,
            'name' => $name,
            'email' => $email,
            'display_name' => $displayName,
        ];
    }

    public function tenantName(string $tenantId): string
    {
        return (string) (PartnerTenant::query()->whereKey($tenantId)->value('name') ?: 'Partner');
    }

    public function customerVariables(string $tenantId, ?string $customerId): array
    {
        $customer = $customerId === null || $customerId === ''
            ? null
            : Customer::query()->where('tenant_id', $tenantId)->whereKey($customerId)->first();

        return [
            'name' => (string) ($customer?->name ?? ''),
            'phone' => (string) ($customer?->phone ?? ''),
        ];
    }

    public function baht(int $amount): string
    {
        return number_format($amount / 100, 2);
    }

    public function occurredAt(mixed $value = null): string
    {
        return ($value === null ? now() : Carbon::parse((string) $value))
            ->timezone('Asia/Bangkok')
            ->format('d/m/Y H:i');
    }

    private function masked(string $value): string
    {
        if ($value === '') {
            return '';
        }

        if (strlen($value) <= 12) {
            return str_repeat('*', strlen($value));
        }

        return substr($value, 0, 6).'...'.substr($value, -4);
    }

    private function cleanString(mixed $value): string
    {
        return trim((string) $value);
    }

    private function encryptionKeyConfigured(): bool
    {
        return $this->cleanString(config('app.key')) !== '';
    }
}

<?php

namespace App\Modules\AdminOperations\Services;

use App\Models\PartnerTenant;
use App\Models\TenantPaymentChannel;
use App\Models\TenantPaymentProviderConnection;
use App\Models\TenantPaymentSetting;
use App\Modules\Commerce\Services\PaymentProviders\DeepayKbankPaymentProvider;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Support\ExternalCheckoutPayment;
use App\Support\ThaiBankCatalog;
use App\Support\TenantPaymentMethods;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TenantPaymentSettingsService
{
    private const CHANNEL_STATUSES = ['draft', 'active', 'inactive', 'disabled', 'archived', 'blocked_external'];
    private const PUBLIC_PAYMENT_CONFIG_KEYS = [
        'bank_transfer',
        'bank_code',
        'bank_name',
        'bank_icon',
        'account_name',
        'account_number',
    ];
    private const SENSITIVE_KEYS = [
        'secret',
        'token',
        'key',
        'password',
        'credential',
        'account',
        'bank',
        'promptpay',
        'webhook',
        'signature',
        'private',
    ];

    private const PROVIDER_CONNECTION_STATUSES = ['active', 'inactive', 'disabled'];

    private const PAYMENT_PROVIDER_OPTIONS = [
        DeepayKbankPaymentProvider::PROVIDER => [
            'value' => DeepayKbankPaymentProvider::PROVIDER,
            'label' => 'DeePay KBank',
            'description' => 'KBank QR Code and Credit QR Code through DeePay.',
        ],
    ];

    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @return array<string, mixed>|null
     */
    public function settings(string $tenantId): ?array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return null;
        }

        return $this->settingResource($this->ensureSettings($tenantId));
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateSettings(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $normalized = $this->settingsPayload($tenantId, $payload);
        $errors = $this->settingsErrors($tenantId, $normalized);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($tenantId, $payload, $normalized, $actor, $request, $tenant): array {
            $settings = $this->ensureSettings($tenantId);
            $updates = $this->settingUpdates($settings, $normalized);

            TenantPaymentSetting::query()
                ->where('tenant_id', $tenantId)
                ->update($updates + ['updated_at' => now()]);

            $this->audit($actor, $request, 'payment_settings.updated', 'tenant_payment_setting', (string) $settings->id, $payload, $tenantId, (string) $tenant->partner_id);

            return ['resource' => $this->settings($tenantId)];
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function deepayKbankConnection(string $tenantId): ?array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return null;
        }

        return $this->providerConnectionResource($tenantId, DeepayKbankPaymentProvider::PROVIDER);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function saveDeepayKbankConnection(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $provider = DeepayKbankPaymentProvider::PROVIDER;
        $existing = TenantPaymentProviderConnection::query()
            ->forTenant($tenantId)
            ->where('provider', $provider)
            ->first();

        $status = trim((string) ($payload['status'] ?? 'active'));
        $apiKey = trim((string) ($payload['api_key'] ?? ''));
        $errors = [];

        if (! in_array($status, self::PROVIDER_CONNECTION_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if ($status === 'active' && $apiKey === '' && $existing?->api_key_encrypted === null) {
            $errors['api_key'][] = 'The API key field is required.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($tenantId, $provider, $existing, $status, $apiKey, $actor, $request, $payload, $tenant): array {
            $metadata = is_array($existing?->metadata_json) ? $existing->metadata_json : [];
            TenantPaymentProviderConnection::query()->updateOrInsert(
                [
                    'tenant_id' => $tenantId,
                    'provider' => $provider,
                ],
                [
                    'id' => $existing?->id ?? 'tppc_'.substr(sha1($tenantId.':'.$provider), 0, 20),
                    'status' => $status,
                    'api_key_encrypted' => $apiKey !== ''
                        ? Crypt::encryptString($apiKey)
                        : $existing?->api_key_encrypted,
                    'last_test_status' => null,
                    'last_error' => null,
                    'metadata_json' => json_encode([
                        ...$metadata,
                        'callback_path' => $this->providerCallbackPath($provider),
                        'webhook_auth_mode' => DeepayKbankPaymentProvider::WEBHOOK_AUTH_MODE,
                    ], JSON_THROW_ON_ERROR),
                    'updated_at' => now(),
                    'created_at' => $existing?->created_at ?? now(),
                ],
            );

            $this->audit($actor, $request, 'payment_provider_connection.updated', 'tenant_payment_provider_connection', $existing?->id ?? $provider, [
                ...$payload,
                'api_key' => $apiKey === '' ? null : '[CONFIGURED]',
                'webhook_secret' => array_key_exists('webhook_secret', $payload) ? '[IGNORED]' : null,
            ], $tenantId, (string) $tenant->partner_id);

            return ['resource' => $this->providerConnectionResource($tenantId, $provider)];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function deactivateDeepayKbankConnection(string $tenantId, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $provider = DeepayKbankPaymentProvider::PROVIDER;

        return DB::transaction(function () use ($tenantId, $provider, $actor, $request, $tenant): array {
            $connection = TenantPaymentProviderConnection::query()
                ->forTenant($tenantId)
                ->where('provider', $provider)
                ->lockForUpdate()
                ->first();

            if ($connection === null) {
                return ['resource' => $this->providerConnectionResource($tenantId, $provider)];
            }

            TenantPaymentProviderConnection::query()
                ->where('id', $connection->id)
                ->update([
                    'status' => 'inactive',
                    'updated_at' => now(),
                ]);

            $this->audit($actor, $request, 'payment_provider_connection.deactivated', 'tenant_payment_provider_connection', (string) $connection->id, [
                'provider' => $provider,
            ], $tenantId, (string) $tenant->partner_id);

            return ['resource' => $this->providerConnectionResource($tenantId, $provider)];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listChannels(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = TenantPaymentChannel::query()
            ->forTenant($tenantId)
            ->orderBy('id')
            ->limit($limit + 1);

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->where('status', trim((string) $queryParams['status']));
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->channelResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findChannel(string $tenantId, string $channelId): ?array
    {
        $channel = TenantPaymentChannel::query()
            ->forTenant($tenantId)
            ->where('id', $channelId)
            ->first();

        return $channel === null ? null : $this->channelResource($channel);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createChannel(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $normalized = $this->channelPayload($tenantId, $payload, true);
        $errors = $this->channelErrors($tenantId, $normalized, true);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (TenantPaymentChannel::query()->forTenant($tenantId)->where('code', $normalized['code'])->exists()) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $payload, $normalized, $actor, $request, $tenant): array {
            $channelId = 'pay_'.Str::ulid()->toBase32();

            TenantPaymentChannel::query()->create($normalized + [
                'id' => $channelId,
                'tenant_id' => $tenantId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, 'payment_channel.created', 'tenant_payment_channel', $channelId, $payload, $tenantId, (string) $tenant->partner_id);

            return ['resource' => $this->findChannel($tenantId, $channelId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateChannel(string $tenantId, string $channelId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $channel = TenantPaymentChannel::query()->forTenant($tenantId)->where('id', $channelId)->first();

        if ($channel === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();
        $normalized = $this->channelPayload($tenantId, $payload, false, $channel);
        $errors = $this->channelErrors($tenantId, $normalized, false);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            array_key_exists('code', $normalized)
            && TenantPaymentChannel::query()->forTenant($tenantId)->where('code', $normalized['code'])->where('id', '!=', $channelId)->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $channelId, $payload, $normalized, $actor, $request, $tenant): array {
            if ($normalized !== []) {
                TenantPaymentChannel::query()
                    ->forTenant($tenantId)
                    ->where('id', $channelId)
                    ->update($normalized + ['updated_at' => now()]);
            }

            $this->audit($actor, $request, 'payment_channel.updated', 'tenant_payment_channel', $channelId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => $this->findChannel($tenantId, $channelId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, status?: int}
     */
    public function archiveChannel(string $tenantId, string $channelId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $channel = TenantPaymentChannel::query()->forTenant($tenantId)->where('id', $channelId)->first();

        if ($channel === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();

        return DB::transaction(function () use ($tenantId, $channelId, $payload, $actor, $request, $tenant): array {
            TenantPaymentChannel::query()
                ->forTenant($tenantId)
                ->where('id', $channelId)
                ->update([
                    'status' => 'archived',
                    'updated_at' => now(),
                ]);

            $this->audit($actor, $request, 'payment_channel.archived', 'tenant_payment_channel', $channelId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => [], 'status' => 204];
        });
    }

    private function ensureSettings(string $tenantId): object
    {
        $settings = TenantPaymentSetting::query()->forTenant($tenantId)->first();

        if ($settings !== null) {
            return $settings;
        }

        TenantPaymentSetting::query()->create([
            'id' => 'tps_'.substr(sha1($tenantId.':payment-settings'), 0, 20),
            'tenant_id' => $tenantId,
            'status' => 'active',
            'provider_mode' => 'manual_only',
            'default_currency' => 'THB',
            'allow_manual_topup' => true,
            'allow_external_payment' => false,
            'payment_provider_status' => 'blocked_external',
            'config_json' => [
                'storage_boundary' => 'local_config_only',
                'production_provider_ready' => false,
                'bank_transfer' => [
                    'bank_code' => 'kbank',
                    'bank_name' => 'ธนาคารกสิกรไทย',
                    'bank_icon' => 'bi-bank',
                    'account_name' => 'Tenant Wallet',
                    'account_number' => '000-000-0000',
                ],
                'payment_methods' => TenantPaymentMethods::defaults(),
            ],
            'secret_status_json' => [],
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return TenantPaymentSetting::query()->forTenant($tenantId)->first();
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function settingsPayload(string $tenantId, array $payload): array
    {
        $source = is_array($payload['settings'] ?? null) ? $payload['settings'] : $payload;
        $sanitized = $this->sanitizeConfig(is_array($source['config'] ?? null) ? $source['config'] : []);

        return array_filter([
            'tenant_id' => $source['tenant_id'] ?? null,
            'status' => array_key_exists('status', $source) ? trim((string) $source['status']) : null,
            'provider_mode' => array_key_exists('provider_mode', $source) ? trim((string) $source['provider_mode']) : null,
            'default_currency' => array_key_exists('default_currency', $source) ? strtoupper(trim((string) $source['default_currency'])) : null,
            'allow_manual_topup' => array_key_exists('allow_manual_topup', $source) ? filter_var($source['allow_manual_topup'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) : null,
            'allow_external_payment' => array_key_exists('allow_external_payment', $source) ? filter_var($source['allow_external_payment'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) : null,
            'payment_provider_status' => array_key_exists('payment_provider_status', $source) ? trim((string) $source['payment_provider_status']) : null,
            'config_json' => $sanitized['config'],
            'secret_status_json' => $sanitized['secrets'],
        ], fn (mixed $value): bool => $value !== null);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function settingsErrors(string $tenantId, array $payload): array
    {
        $errors = [];

        if (array_key_exists('tenant_id', $payload) && $payload['tenant_id'] !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the selected tenant.';
        }

        if (array_key_exists('default_currency', $payload) && preg_match('/^[A-Z]{3}$/', (string) $payload['default_currency']) !== 1) {
            $errors['default_currency'][] = 'The default_currency field must be a three-letter currency code.';
        }

        foreach (['allow_manual_topup', 'allow_external_payment'] as $field) {
            if (array_key_exists($field, $payload) && ! is_bool($payload[$field])) {
                $errors[$field][] = 'The '.$field.' field must be true or false.';
            }
        }

        if (
            array_key_exists('payment_provider_status', $payload)
            && ! in_array($payload['payment_provider_status'], ['blocked_external', 'local_dev_configured', 'manual_only', 'disabled'], true)
        ) {
            $errors['payment_provider_status'][] = 'The payment_provider_status field is invalid.';
        }

        $errors = array_replace_recursive($errors, $this->paymentMethodProviderErrors($tenantId, $payload));
        $settings = TenantPaymentSetting::query()->forTenant($tenantId)->first();
        $allowExternalPayment = array_key_exists('allow_external_payment', $payload)
            ? (bool) $payload['allow_external_payment']
            : (bool) ($settings?->allow_external_payment ?? false);
        $config = array_replace_recursive(
            is_array($settings?->config_json) ? $settings->config_json : [],
            is_array($payload['config_json'] ?? null) ? $payload['config_json'] : [],
        );
        $errors = array_replace_recursive(
            $errors,
            ExternalCheckoutPayment::validationErrors($allowExternalPayment, $config),
        );

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function paymentMethodProviderErrors(string $tenantId, array $payload): array
    {
        $incomingConfig = is_array($payload['config_json'] ?? null) ? $payload['config_json'] : [];
        $settings = TenantPaymentSetting::query()->forTenant($tenantId)->first();
        $currentConfig = $settings !== null && is_array($settings->config_json) ? $settings->config_json : [];
        $config = array_replace_recursive($currentConfig, $incomingConfig);
        $methods = is_array($config['payment_methods'] ?? null) ? $config['payment_methods'] : [];
        $errors = [];

        foreach ([TenantPaymentMethods::QR, TenantPaymentMethods::CREDIT_CARD] as $method) {
            if (! array_key_exists($method, $methods)) {
                continue;
            }

            $rawMethodConfig = $methods[$method];
            $methodConfig = is_array($rawMethodConfig) ? $rawMethodConfig : [];

            if (! TenantPaymentMethods::isEnabled($config, $method)) {
                continue;
            }

            $provider = trim((string) ($methodConfig['provider'] ?? ''));
            $field = 'config.payment_methods.'.$method.'.provider';

            if ($provider === '') {
                $errors[$field][] = 'Select a payment provider before enabling this payment method.';
                continue;
            }

            if (! array_key_exists($provider, self::PAYMENT_PROVIDER_OPTIONS)) {
                $errors[$field][] = 'The selected payment provider is invalid.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function settingUpdates(object $settings, array $payload): array
    {
        $updates = [];

        foreach (['status', 'provider_mode', 'default_currency', 'allow_manual_topup', 'allow_external_payment'] as $field) {
            if (array_key_exists($field, $payload)) {
                $updates[$field] = $payload[$field];
            }
        }

        if (array_key_exists('payment_provider_status', $payload)) {
            $updates['payment_provider_status'] = $payload['payment_provider_status'];
        }

        if (array_key_exists('config_json', $payload)) {
            $updates['config_json'] = array_replace_recursive(is_array($settings->config_json) ? $settings->config_json : [], $payload['config_json'], [
                'storage_boundary' => 'local_config_only',
                'production_provider_ready' => false,
            ]);
        }

        if (array_key_exists('secret_status_json', $payload)) {
            $updates['secret_status_json'] = array_replace_recursive(is_array($settings->secret_status_json) ? $settings->secret_status_json : [], $payload['secret_status_json']);
        }

        if (($updates['allow_external_payment'] ?? $settings->allow_external_payment) === true) {
            $updates['payment_provider_status'] = $updates['payment_provider_status'] ?? 'blocked_external';
        }

        return $updates;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function channelPayload(string $tenantId, array $payload, bool $creating, ?object $existing = null): array
    {
        $sanitized = $this->sanitizeConfig(is_array($payload['config'] ?? null) ? $payload['config'] : []);
        $code = array_key_exists('code', $payload) ? Str::slug((string) $payload['code'], '_') : null;

        return array_filter([
            'tenant_id' => $payload['tenant_id'] ?? null,
            'code' => $code,
            'name' => array_key_exists('name', $payload) ? trim((string) $payload['name']) : null,
            'provider' => array_key_exists('provider', $payload) ? trim((string) $payload['provider']) : ($creating ? 'manual' : null),
            'channel_type' => array_key_exists('channel_type', $payload) ? trim((string) $payload['channel_type']) : ($creating ? 'manual' : null),
            'status' => array_key_exists('status', $payload) ? trim((string) $payload['status']) : ($creating ? 'draft' : null),
            'sort_order' => array_key_exists('sort_order', $payload) ? filter_var($payload['sort_order'], FILTER_VALIDATE_INT) : null,
            'config_json' => array_key_exists('config', $payload) ? array_replace_recursive(is_array($existing?->config_json) ? $existing->config_json : [], $sanitized['config'], [
                'storage_boundary' => 'local_config_only',
                'production_provider_ready' => false,
            ]) : null,
            'secret_status_json' => array_key_exists('config', $payload) ? array_replace_recursive(is_array($existing?->secret_status_json) ? $existing->secret_status_json : [], $sanitized['secrets']) : null,
        ], fn (mixed $value): bool => $value !== null);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function channelErrors(string $tenantId, array $payload, bool $creating): array
    {
        $errors = [];

        if (array_key_exists('tenant_id', $payload) && $payload['tenant_id'] !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the selected tenant.';
        }

        foreach (['code', 'name'] as $field) {
            if ($creating && (! array_key_exists($field, $payload) || trim((string) $payload[$field]) === '')) {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (array_key_exists('code', $payload) && preg_match('/^[a-z0-9_\\-]{2,64}$/', (string) $payload['code']) !== 1) {
            $errors['code'][] = 'The code field must contain 2 to 64 lowercase letters, numbers, dashes, or underscores.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::CHANNEL_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('sort_order', $payload) && $payload['sort_order'] === false) {
            $errors['sort_order'][] = 'The sort_order field must be an integer.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $config
     * @return array{config: array<string, mixed>, secrets: array<string, mixed>}
     */
    private function sanitizeConfig(array $config): array
    {
        $safe = [];
        $secrets = [];

        foreach ($config as $key => $value) {
            if ($this->isSensitiveKey((string) $key) && ! $this->isPublicPaymentConfigKey((string) $key)) {
                $secrets[$key] = $value === null || $value === '' ? null : '[CONFIGURED]';
                continue;
            }

            if (is_array($value)) {
                $nested = $this->sanitizeConfig($value);
                $safe[$key] = $nested['config'];

                if ($nested['secrets'] !== []) {
                    $secrets[$key] = $nested['secrets'];
                }

                continue;
            }

            $safe[$key] = $value;
        }

        return ['config' => $safe, 'secrets' => $secrets];
    }

    private function isPublicPaymentConfigKey(string $key): bool
    {
        return in_array($key, self::PUBLIC_PAYMENT_CONFIG_KEYS, true);
    }

    private function isSensitiveKey(string $key): bool
    {
        $normalized = strtolower($key);

        foreach (self::SENSITIVE_KEYS as $sensitiveKey) {
            if (str_contains($normalized, $sensitiveKey)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @return array<string, mixed>
     */
    private function settingResource(object $settings): array
    {
        return [
            'id' => (string) $settings->id,
            'tenant_id' => (string) $settings->tenant_id,
            'status' => (string) $settings->status,
            'created_at' => $settings->created_at?->toISOString(),
            'updated_at' => $settings->updated_at?->toISOString(),
            'provider_mode' => (string) $settings->provider_mode,
            'default_currency' => (string) $settings->default_currency,
            'allow_manual_topup' => (bool) $settings->allow_manual_topup,
            'allow_external_payment' => (bool) $settings->allow_external_payment,
            'payment_provider_status' => (string) $settings->payment_provider_status,
            'config' => $settings->config_json ?? [],
            'payment_methods' => TenantPaymentMethods::normalize(is_array($settings->config_json) ? $settings->config_json : []),
            'enabled_payment_methods' => TenantPaymentMethods::enabledKeys(is_array($settings->config_json) ? $settings->config_json : []),
            'bank_transfer' => $this->bankTransferResource(is_array($settings->config_json) ? $settings->config_json : []),
            'bank_catalog' => ThaiBankCatalog::all(),
            'payment_provider_options' => $this->paymentProviderOptions((string) $settings->tenant_id),
            'payment_provider_connections' => $this->providerConnectionsResource((string) $settings->tenant_id),
            'secret_status' => $settings->secret_status_json ?? [],
            'production_provider_ready' => false,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function paymentProviderOptions(string $tenantId): array
    {
        $connections = $this->providerConnectionsResource($tenantId);

        return array_values(array_map(function (array $provider) use ($connections): array {
            $key = (string) $provider['value'];
            $connection = $connections[$key] ?? null;

            return $provider + [
                'configured' => (bool) ($connection['configured'] ?? false),
                'ready' => (bool) ($connection['ready'] ?? false),
                'status' => (string) ($connection['status'] ?? 'inactive'),
            ];
        }, self::PAYMENT_PROVIDER_OPTIONS));
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function providerConnectionsResource(string $tenantId): array
    {
        return [
            DeepayKbankPaymentProvider::PROVIDER => $this->providerConnectionResource($tenantId, DeepayKbankPaymentProvider::PROVIDER),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function providerConnectionResource(string $tenantId, string $provider): array
    {
        $connection = TenantPaymentProviderConnection::query()
            ->forTenant($tenantId)
            ->where('provider', $provider)
            ->first();

        $apiKeyConfigured = $connection !== null && $connection->api_key_encrypted !== null;
        $webhookSecretConfigured = $connection !== null && $connection->webhook_secret_encrypted !== null;
        $metadata = is_array($connection?->metadata_json) ? $connection->metadata_json : [];
        $status = (string) ($connection?->status ?? 'inactive');

        return [
            'provider' => $provider,
            'label' => self::PAYMENT_PROVIDER_OPTIONS[$provider]['label'] ?? $provider,
            'status' => $status,
            'configured' => $apiKeyConfigured,
            'ready' => $status === 'active' && $apiKeyConfigured,
            'api_key_configured' => $apiKeyConfigured,
            'api_key_masked' => $this->maskedSecret($connection?->api_key_encrypted),
            'webhook_secret_configured' => $webhookSecretConfigured,
            'webhook_secret_masked' => $this->maskedSecret($connection?->webhook_secret_encrypted),
            'webhook_auth_mode' => (string) ($metadata['webhook_auth_mode'] ?? DeepayKbankPaymentProvider::WEBHOOK_AUTH_MODE),
            'verified_at' => $connection?->verified_at?->toISOString(),
            'last_tested_at' => $connection?->last_tested_at?->toISOString(),
            'last_test_status' => $connection?->last_test_status,
            'last_error' => $connection?->last_error,
            'callback_path' => $this->providerCallbackPath($provider),
            'callback_url' => $this->providerCallbackUrl($provider),
        ];
    }

    private function providerCallbackPath(string $provider): string
    {
        return '/api/v1/webhooks/topups/'.$provider;
    }

    private function providerCallbackUrl(string $provider): string
    {
        return rtrim((string) config('app.url'), '/').$this->providerCallbackPath($provider);
    }

    private function maskedSecret(mixed $encrypted): ?string
    {
        $value = trim((string) $encrypted);
        if ($value === '') {
            return null;
        }

        try {
            $plain = Crypt::decryptString($value);
        } catch (\Throwable) {
            return '[CONFIGURED]';
        }

        $length = strlen($plain);
        if ($length <= 8) {
            return str_repeat('•', max(4, $length));
        }

        return substr($plain, 0, 4).str_repeat('•', max(4, $length - 8)).substr($plain, -4);
    }

    /**
     * @param array<string, mixed> $config
     * @return array<string, mixed>
     */
    private function bankTransferResource(array $config): array
    {
        $bankConfig = is_array($config['bank_transfer'] ?? null) ? $config['bank_transfer'] : $config;
        $bankCode = trim((string) ($bankConfig['bank_code'] ?? ''));
        $bankName = trim((string) ($bankConfig['bank_name'] ?? ''));
        $catalogBank = ThaiBankCatalog::findByCodeOrName($bankCode !== '' ? $bankCode : $bankName);

        return [
            'bank_code' => $catalogBank['code'] ?? ($bankCode !== '' ? $bankCode : 'kbank'),
            'bank_name' => $catalogBank['name'] ?? ($bankName !== '' ? $bankName : 'ธนาคารกสิกรไทย'),
            'bank_icon' => (string) ($bankConfig['bank_icon'] ?? ($catalogBank['icon'] ?? 'bi-bank')),
            'account_name' => (string) ($bankConfig['account_name'] ?? 'Tenant Wallet'),
            'account_number' => (string) ($bankConfig['account_number'] ?? '000-000-0000'),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function channelResource(object $channel): array
    {
        return [
            'id' => (string) $channel->id,
            'tenant_id' => (string) $channel->tenant_id,
            'status' => (string) $channel->status,
            'created_at' => $channel->created_at?->toISOString(),
            'updated_at' => $channel->updated_at?->toISOString(),
            'code' => (string) $channel->code,
            'name' => (string) $channel->name,
            'provider' => (string) $channel->provider,
            'channel_type' => (string) $channel->channel_type,
            'sort_order' => (int) $channel->sort_order,
            'config' => $channel->config_json ?? [],
            'secret_status' => $channel->secret_status_json ?? [],
            'provider_status' => $channel->provider === 'manual' ? 'manual_only' : 'blocked_external',
            'production_provider_ready' => false,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(
        AdminSessionContext $actor,
        Request $request,
        string $action,
        string $targetType,
        string $targetId,
        array $payload,
        string $tenantId,
        ?string $partnerId,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'tenant',
            action: $action,
            targetType: $targetType,
            targetId: $targetId,
            payload: [
                'payload' => $payload,
                'production_provider_ready' => false,
                'idempotency_key' => $request->header('Idempotency-Key'),
            ],
            tenantId: $tenantId,
            partnerId: $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        return $limit === false ? 50 : max(1, min(100, $limit));
    }
}

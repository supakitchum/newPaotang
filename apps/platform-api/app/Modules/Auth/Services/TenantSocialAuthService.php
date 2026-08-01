<?php

namespace App\Modules\Auth\Services;

use App\Models\TenantLineChannel;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantDomain;
use App\Models\TenantSocialAuthProvider;
use App\Modules\LineNotifications\Services\TenantLineNotificationService;
use App\Shared\Tenancy\TenantHostNormalizer;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Str;

class TenantSocialAuthService
{
    public const PROVIDERS = ['line', 'google', 'apple', 'facebook'];

    public function __construct(private readonly TenantLineNotificationService $lineNotifications)
    {
    }

    /**
     * @return array<string, mixed>
     */
    public function settings(string $tenantId): array
    {
        return [
            'data' => [
                'providers' => array_map(fn (string $provider): array => $this->providerResource($tenantId, $provider), self::PROVIDERS),
                'callback_urls' => $this->callbackUrls($tenantId),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function update(string $tenantId, string $provider, array $payload): array
    {
        $provider = $this->normalizeProvider($provider);

        if (! in_array($provider, self::PROVIDERS, true)) {
            return ['error' => 'provider_managed_elsewhere'];
        }

        if ($provider === 'line') {
            $errors = $this->providerAppearanceErrors($payload);

            if ($errors !== []) {
                return ['error' => 'validation_failed', 'errors' => $errors];
            }

            $existing = TenantSocialAuthProvider::query()
                ->where('tenant_id', $tenantId)
                ->where('provider', $provider)
                ->first();
            $metadata = $this->providerMetadata($existing, $provider, $payload);

            if ($existing instanceof TenantSocialAuthProvider || $metadata !== []) {
                TenantSocialAuthProvider::query()->updateOrCreate(
                    ['tenant_id' => $tenantId, 'provider' => $provider],
                    [
                        'id' => (string) ($existing?->id ?: 'tsa_'.Str::ulid()->toBase32()),
                        'status' => 'inactive',
                        'redirect_uri' => $this->customerCallbackUrl($tenantId, $provider),
                        'metadata_json' => $metadata,
                        'updated_at' => now(),
                    ],
                );
            }

            return ['resource' => $this->settings($tenantId)];
        }

        $errors = $this->providerErrors($tenantId, $provider, $payload);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $existing = TenantSocialAuthProvider::query()
            ->where('tenant_id', $tenantId)
            ->where('provider', $provider)
            ->first();
        $status = in_array(($payload['status'] ?? 'inactive'), ['active', 'inactive'], true) ? (string) $payload['status'] : 'inactive';
        $recordId = (string) ($existing?->id ?: 'tsa_'.Str::ulid()->toBase32());
        $updates = [
            'id' => $recordId,
            'tenant_id' => $tenantId,
            'provider' => $provider,
            'status' => $status,
            'redirect_uri' => $this->callbackUrlFor($provider, $tenantId),
            'last_test_status' => 'saved',
            'last_test_message' => 'Provider settings saved.',
            'metadata_json' => $this->providerMetadata($existing, $provider, $payload),
            'updated_at' => now(),
        ];

        foreach ($this->secretFieldsForProvider($provider) as $input => $column) {
            $value = trim((string) ($payload[$input] ?? ''));

            if ($value !== '') {
                $updates[$column] = Crypt::encryptString($value);
            } elseif (! $existing instanceof TenantSocialAuthProvider || trim((string) $existing->{$column}) === '') {
                $updates[$column] = null;
            }
        }

        TenantSocialAuthProvider::query()->updateOrCreate(
            ['tenant_id' => $tenantId, 'provider' => $provider],
            $updates,
        );

        return ['resource' => $this->settings($tenantId)];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function disconnect(string $tenantId, string $provider): array
    {
        $provider = $this->normalizeProvider($provider);

        if (! in_array($provider, ['google', 'apple', 'facebook'], true)) {
            return ['error' => 'provider_managed_elsewhere'];
        }

        TenantSocialAuthProvider::query()
            ->where('tenant_id', $tenantId)
            ->where('provider', $provider)
            ->delete();

        return ['resource' => $this->settings($tenantId)];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function enabledProviders(string $tenantId): array
    {
        return array_values(array_filter(
            array_map(fn (string $provider): array => $this->publicProviderResource($tenantId, $provider), self::PROVIDERS),
            fn (array $provider): bool => (bool) ($provider['enabled'] ?? false),
        ));
    }

    public function activeProvider(string $tenantId, string $provider): ?TenantSocialAuthProvider
    {
        return TenantSocialAuthProvider::query()
            ->where('tenant_id', $tenantId)
            ->where('provider', $this->normalizeProvider($provider))
            ->where('status', 'active')
            ->first();
    }

    public function customerCallbackUrl(string $tenantId, string $provider): string
    {
        $provider = $this->normalizeProvider($provider);

        if ($provider === 'line') {
            return $this->storefrontBaseUrl($tenantId).'/line/callback';
        }

        return $this->callbackUrlFor($provider, $tenantId);
    }

    public function decrypted(TenantSocialAuthProvider $provider, string $field): string
    {
        $value = (string) ($provider->{$field} ?? '');

        if ($value === '') {
            return '';
        }

        try {
            return Crypt::decryptString($value);
        } catch (\Throwable) {
            return '';
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function providerResource(string $tenantId, string $provider): array
    {
        $record = TenantSocialAuthProvider::query()
            ->where('tenant_id', $tenantId)
            ->where('provider', $provider)
            ->first();
        $appearance = $this->providerAppearance($record);

        if ($provider === 'line') {
            $line = $this->lineNotifications->channelForTenant($tenantId);

            return [
                'provider' => 'line',
                'label' => $appearance['display_label'] ?: 'LINE',
                'display_label' => $appearance['display_label'],
                'brand_color' => $appearance['brand_color'],
                'button_background_color' => $appearance['button_background_color'],
                'button_foreground_color' => $appearance['button_foreground_color'],
                'status' => $line instanceof TenantLineChannel ? (string) $line->status : 'inactive',
                'configured' => $line instanceof TenantLineChannel,
                'ready' => $this->lineNotifications->channelReadyForLogin($line),
                'managed_elsewhere' => true,
                'settings_route' => '/admin/tenant/line-notifications',
            ];
        }

        return [
            'provider' => $provider,
            'label' => $appearance['display_label'] ?: $this->defaultProviderLabel($provider),
            'display_label' => $appearance['display_label'],
            'brand_color' => $appearance['brand_color'],
            'button_background_color' => $appearance['button_background_color'],
            'button_foreground_color' => $appearance['button_foreground_color'],
            'status' => $record?->status ?? 'inactive',
            'configured' => $record instanceof TenantSocialAuthProvider,
            'ready' => $record instanceof TenantSocialAuthProvider && $record->status === 'active' && $this->hasRequiredSecrets($record),
            'managed_elsewhere' => false,
            'client_id_masked' => $record instanceof TenantSocialAuthProvider ? $this->mask($this->decrypted($record, 'client_id_encrypted')) : null,
            'client_secret_configured' => $record instanceof TenantSocialAuthProvider && trim((string) $record->client_secret_encrypted) !== '',
            'team_id_masked' => $record instanceof TenantSocialAuthProvider ? $this->mask($this->decrypted($record, 'team_id_encrypted')) : null,
            'key_id_masked' => $record instanceof TenantSocialAuthProvider ? $this->mask($this->decrypted($record, 'key_id_encrypted')) : null,
            'private_key_configured' => $record instanceof TenantSocialAuthProvider && trim((string) $record->private_key_encrypted) !== '',
            'redirect_uri' => $this->callbackUrlFor($provider, $tenantId),
            'last_test_status' => $record?->last_test_status,
            'last_test_message' => $record?->last_test_message,
        ];
    }

    private function publicProviderResource(string $tenantId, string $provider): array
    {
        $resource = $this->providerResource($tenantId, $provider);

        return [
            'provider' => $resource['provider'],
            'label' => $resource['label'],
            'enabled' => (bool) ($resource['ready'] ?? false),
            'login_url' => '/api/v1/customer/auth/social/'.$resource['provider'].'/login',
            'brand_color' => $resource['brand_color'] ?? null,
            'button_background_color' => $resource['button_background_color'] ?? null,
            'button_foreground_color' => $resource['button_foreground_color'] ?? null,
        ];
    }

    /**
     * @return array<string, string>
     */
    private function secretFieldsForProvider(string $provider): array
    {
        return $provider === 'apple'
            ? [
                'client_id' => 'client_id_encrypted',
                'team_id' => 'team_id_encrypted',
                'key_id' => 'key_id_encrypted',
                'private_key' => 'private_key_encrypted',
            ]
            : [
                'client_id' => 'client_id_encrypted',
                'client_secret' => 'client_secret_encrypted',
            ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function providerErrors(string $tenantId, string $provider, array $payload): array
    {
        $errors = $this->providerAppearanceErrors($payload);

        foreach ($this->secretFieldsForProvider($provider) as $input => $column) {
            $hasExisting = TenantSocialAuthProvider::query()
                ->where('tenant_id', $tenantId)
                ->where('provider', $provider)
                ->whereNotNull($column)
                ->where($column, '!=', '')
                ->exists();

            if (trim((string) ($payload[$input] ?? '')) === '' && ! $hasExisting) {
                $errors[$input][] = 'The '.$input.' field is required.';
            }
        }

        if (! in_array(($payload['status'] ?? 'inactive'), ['active', 'inactive'], true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function providerAppearanceErrors(array $payload): array
    {
        $errors = [];

        if (array_key_exists('display_label', $payload)) {
            $label = trim((string) $payload['display_label']);
            if (mb_strlen($label) > 80) {
                $errors['display_label'][] = 'The display_label field must not exceed 80 characters.';
            }
        }

        foreach (['brand_color', 'button_background_color', 'button_foreground_color'] as $field) {
            if (! array_key_exists($field, $payload)) {
                continue;
            }

            $value = trim((string) $payload[$field]);
            if ($value !== '' && preg_match('/^#[0-9a-fA-F]{6}$/', $value) !== 1) {
                $errors[$field][] = 'The '.$field.' field must be a 6-digit hex color.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function providerMetadata(?TenantSocialAuthProvider $record, string $provider, array $payload): array
    {
        $metadata = is_array($record?->metadata_json) ? $record->metadata_json : [];

        if ($provider !== 'line') {
            $metadata['scopes'] = match ($provider) {
                'google' => ['openid', 'profile', 'email'],
                'facebook' => ['public_profile', 'email'],
                default => [],
            };
        }

        $appearance = is_array($metadata['appearance'] ?? null) ? $metadata['appearance'] : [];
        foreach (['display_label', 'brand_color', 'button_background_color', 'button_foreground_color'] as $field) {
            if (! array_key_exists($field, $payload)) {
                continue;
            }

            $value = trim((string) $payload[$field]);
            if ($value === '') {
                unset($appearance[$field]);
            } else {
                $appearance[$field] = str_ends_with($field, '_color') ? strtoupper($value) : $value;
            }
        }

        if ($appearance === []) {
            unset($metadata['appearance']);
        } else {
            $metadata['appearance'] = $appearance;
        }

        return $metadata;
    }

    /**
     * @return array{display_label: string, brand_color: string, button_background_color: string, button_foreground_color: string}
     */
    private function providerAppearance(?TenantSocialAuthProvider $record): array
    {
        $metadata = is_array($record?->metadata_json) ? $record->metadata_json : [];
        $appearance = is_array($metadata['appearance'] ?? null) ? $metadata['appearance'] : [];

        return [
            'display_label' => trim((string) ($appearance['display_label'] ?? '')),
            'brand_color' => trim((string) ($appearance['brand_color'] ?? '')),
            'button_background_color' => trim((string) ($appearance['button_background_color'] ?? '')),
            'button_foreground_color' => trim((string) ($appearance['button_foreground_color'] ?? '')),
        ];
    }

    private function hasRequiredSecrets(TenantSocialAuthProvider $record): bool
    {
        foreach ($this->secretFieldsForProvider((string) $record->provider) as $column) {
            if ($this->decrypted($record, $column) === '') {
                return false;
            }
        }

        return true;
    }

    private function normalizeProvider(string $provider): string
    {
        return match (strtolower(trim($provider))) {
            'gmail', 'google_login', 'google_oauth', 'google_oauth2' => 'google',
            'apple_id', 'apple_login', 'sign_in_with_apple' => 'apple',
            'fb', 'facebook_login', 'facebook_oauth', 'meta', 'meta_login' => 'facebook',
            'line_login', 'line_oa', 'line_oauth' => 'line',
            default => strtolower(trim($provider)),
        };
    }

    private function callbackUrlFor(string $provider, string $tenantId): string
    {
        return $this->storefrontBaseUrl($tenantId).'/social/'.$provider.'/callback';
    }

    /**
     * @return array<string, string>
     */
    private function callbackUrls(string $tenantId): array
    {
        return [
            'line' => $this->customerCallbackUrl($tenantId, 'line'),
            'google' => $this->customerCallbackUrl($tenantId, 'google'),
            'apple' => $this->customerCallbackUrl($tenantId, 'apple'),
            'facebook' => $this->customerCallbackUrl($tenantId, 'facebook'),
        ];
    }

    private function defaultProviderLabel(string $provider): string
    {
        return match ($provider) {
            'google' => 'Google / Gmail',
            'apple' => 'Apple ID',
            'facebook' => 'Facebook',
            default => strtoupper($provider),
        };
    }

    private function storefrontBaseUrl(string $tenantId): string
    {
        $host = PartnerTenantDomain::query()
            ->forTenant($tenantId)
            ->orderByDesc('is_primary')
            ->orderBy('host')
            ->value('host');

        if ($host === null) {
            $tenantCode = PartnerTenant::whereKey($tenantId)->value('code');
            $host = ($tenantCode ?: $tenantId).'.newpaotang.test';
        }

        $host = TenantHostNormalizer::normalize((string) $host);
        $scheme = preg_match('/(^localhost$|\.localhost$|\.test$)/i', $host) === 1 ? 'http' : 'https';

        return $scheme.'://'.$host;
    }

    private function mask(string $value): ?string
    {
        if ($value === '') {
            return null;
        }

        return strlen($value) <= 8 ? str_repeat('•', strlen($value)) : substr($value, 0, 4).'••••'.substr($value, -4);
    }
}

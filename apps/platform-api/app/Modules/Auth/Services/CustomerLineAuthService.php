<?php

namespace App\Modules\Auth\Services;

use App\Models\CustomerExternalAuthState;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CustomerLineAuthService
{
    private const PROVIDER = 'line';

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function redirect(array $tenant, array $payload, Request $request): array
    {
        if (! $this->credentialsConfigured()) {
            return $this->providerBlocked('provider_not_configured');
        }

        $state = 'line_'.bin2hex(random_bytes(24));
        $redirectUri = $this->callbackUrl($request);
        $stateId = 'les_'.Str::ulid()->toBase32();

        CustomerExternalAuthState::query()->insert([
            'id' => $stateId,
            'tenant_id' => (string) $tenant['tenant_id'],
            'provider' => self::PROVIDER,
            'state_hash' => hash('sha256', $state),
            'store_id' => $this->nullableString($payload['store_id'] ?? null),
            'status' => 'pending',
            'redirect_uri' => $redirectUri,
            'expires_at' => now()->addSeconds((int) config('platform.line.state_ttl_seconds', 600)),
            'consumed_at' => null,
            'metadata_json' => json_encode([
                'host' => $request->getHost(),
                'provider_readiness' => 'configured_redirect_only',
                'production_line_ready' => false,
            ], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'resource' => [
                'url' => $this->authorizationUrl($state, $redirectUri),
                'provider' => self::PROVIDER,
                'provider_status' => 'configured_redirect_only',
                'production_line_ready' => false,
            ],
            'status' => 200,
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $query
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function callback(array $tenant, array $query, Request $request): array
    {
        if (! $this->credentialsConfigured()) {
            return $this->providerBlocked('provider_not_configured');
        }

        $code = trim((string) ($query['code'] ?? ''));
        $state = trim((string) ($query['state'] ?? ''));

        if ($code === '' || $state === '') {
            $fields = [];

            if ($code === '') {
                $fields['code'][] = 'The code field is required.';
            }

            if ($state === '') {
                $fields['state'][] = 'The state field is required.';
            }

            return [
                'error' => 'validation_failed',
                'details' => ['fields' => $fields],
            ];
        }

        $stateRecord = DB::transaction(function () use ($tenant, $state, $request): ?CustomerExternalAuthState {
            $record = CustomerExternalAuthState::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('provider', self::PROVIDER)
                ->where('state_hash', hash('sha256', $state))
                ->where('status', 'pending')
                ->whereNull('consumed_at')
                ->where('expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if ($record === null) {
                return null;
            }

            $metadata = is_array($record->metadata_json) ? $record->metadata_json : [];
            $host = (string) ($metadata['host'] ?? '');

            if ($host === '' || ! hash_equals($host, $request->getHost())) {
                return null;
            }

            CustomerExternalAuthState::query()
                ->where('id', $record->id)
                ->update([
                    'status' => 'consumed',
                    'consumed_at' => now(),
                    'updated_at' => now(),
                ]);

            return $record;
        });

        if ($stateRecord === null) {
            return ['error' => 'authentication_required'];
        }

        return [
            'error' => 'provider_exchange_blocked',
            'details' => [
                'provider' => self::PROVIDER,
                'provider_status' => 'blocked_external',
                'production_line_ready' => false,
                'reason' => 'LINE token exchange and account-linking policy require Coordinator/Ops approval before successful login.',
                'state_id' => $stateRecord->id,
                'line_code' => '[REDACTED]',
                'host' => $request->getHost(),
            ],
        ];
    }

    /**
     * @return array{error: string, details: array<string, mixed>}
     */
    private function providerBlocked(string $code): array
    {
        return [
            'error' => $code,
            'details' => [
                'provider' => self::PROVIDER,
                'provider_status' => 'blocked_external',
                'production_line_ready' => false,
                'reason' => 'LINE channel credentials/provider exchange are not configured for this environment.',
            ],
        ];
    }

    private function credentialsConfigured(): bool
    {
        return trim((string) config('platform.line.client_id', '')) !== ''
            && trim((string) config('platform.line.client_secret', '')) !== '';
    }

    private function authorizationUrl(string $state, string $redirectUri): string
    {
        return (string) config('platform.line.authorize_url', 'https://access.line.me/oauth2/v2.1/authorize').'?'.http_build_query([
            'response_type' => 'code',
            'client_id' => (string) config('platform.line.client_id'),
            'redirect_uri' => $redirectUri,
            'state' => $state,
            'scope' => 'profile openid',
        ]);
    }

    private function callbackUrl(Request $request): string
    {
        $configured = trim((string) config('platform.line.callback_url', ''));

        if ($configured !== '') {
            return $configured;
        }

        return $request->getSchemeAndHttpHost().'/api/v1/customer/auth/line/callback';
    }

    private function nullableString(mixed $value): ?string
    {
        $value = trim((string) $value);

        return $value === '' ? null : $value;
    }
}

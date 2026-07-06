<?php

namespace App\Modules\Auth\Services;

use App\Models\Customer;
use App\Models\CustomerExternalAuthState;
use App\Models\CustomerLineLinkToken;
use App\Models\CustomerSocialIdentity;
use App\Models\TenantSocialAuthProvider;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Auth\CustomerSuspensionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class CustomerSocialAuthService
{
    public function __construct(
        private readonly CustomerAuthService $customerAuth,
        private readonly TenantSocialAuthService $providers,
        private readonly CustomerSuspensionService $customerSuspensions,
    ) {
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function redirect(array $tenant, string $provider, array $payload, Request $request): array
    {
        $provider = $this->normalizeProvider($provider);

        if (! in_array($provider, ['google', 'apple'], true)) {
            return ['error' => 'provider_not_supported'];
        }

        $connection = $this->providers->activeProvider((string) $tenant['tenant_id'], $provider);

        if (! $connection instanceof TenantSocialAuthProvider) {
            return ['error' => 'provider_not_configured'];
        }

        $state = $provider.'_'.bin2hex(random_bytes(24));
        $redirectUri = $this->providers->customerCallbackUrl((string) $tenant['tenant_id'], $provider);
        CustomerExternalAuthState::query()->insert([
            'id' => 'eas_'.Str::ulid()->toBase32(),
            'tenant_id' => (string) $tenant['tenant_id'],
            'provider' => $provider,
            'state_hash' => hash('sha256', $state),
            'store_id' => null,
            'status' => 'pending',
            'redirect_uri' => $redirectUri,
            'expires_at' => now()->addSeconds(600),
            'consumed_at' => null,
            'metadata_json' => json_encode([
                'host' => $request->getHost(),
                'redirect_uri' => $redirectUri,
                'purpose' => $this->purpose($payload['purpose'] ?? null),
                'redirect' => $this->redirectPath($payload['redirect'] ?? $payload['redirect_path'] ?? null),
            ], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'resource' => [
                'url' => $provider === 'google'
                    ? $this->googleAuthorizationUrl($connection, $state, $redirectUri)
                    : $this->appleAuthorizationUrl($connection, $state, $redirectUri),
                'provider' => $provider,
                'provider_status' => 'ready',
            ],
            'status' => 200,
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $query
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function callback(array $tenant, string $provider, array $query, Request $request, ?CustomerSessionContext $currentCustomer = null): array
    {
        $provider = $this->normalizeProvider($provider);

        if (! in_array($provider, ['google', 'apple'], true)) {
            return ['error' => 'provider_not_supported'];
        }

        $connection = $this->providers->activeProvider((string) $tenant['tenant_id'], $provider);

        if (! $connection instanceof TenantSocialAuthProvider) {
            return ['error' => 'provider_not_configured'];
        }

        $stateRecord = $this->consumeState($tenant, $provider, trim((string) ($query['state'] ?? '')), $request);

        if (! $stateRecord instanceof CustomerExternalAuthState) {
            return ['error' => 'authentication_required'];
        }

        $metadata = is_array($stateRecord->metadata_json) ? $stateRecord->metadata_json : [];
        $redirectPath = $this->redirectPath($metadata['redirect'] ?? null);
        $code = trim((string) ($query['code'] ?? ''));

        if ($code === '') {
            return ['error' => 'validation_failed', 'details' => ['fields' => ['code' => ['The code field is required.']]]];
        }

        $profile = $provider === 'google'
            ? $this->googleProfile($connection, $code, (string) $stateRecord->redirect_uri)
            : $this->appleProfile($connection, $code, (string) $stateRecord->redirect_uri, $query);

        if (($profile['ok'] ?? false) !== true) {
            return [
                'error' => 'provider_exchange_failed',
                'details' => ['reason' => $profile['message'] ?? 'Provider profile exchange failed.'],
            ];
        }

        $providerProfile = $profile['data'] ?? [];
        $providerUserId = trim((string) ($providerProfile['id'] ?? ''));

        if ($providerUserId === '') {
            return [
                'error' => 'provider_exchange_failed',
                'details' => ['reason' => 'Provider profile did not include an id.'],
            ];
        }

        if ($currentCustomer instanceof CustomerSessionContext) {
            return $this->linkCurrentCustomer($tenant, $currentCustomer, $provider, $providerProfile, $redirectPath);
        }

        $identity = CustomerSocialIdentity::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->where('provider', $provider)
            ->where('provider_user_id', $providerUserId)
            ->first();

        if ($identity instanceof CustomerSocialIdentity) {
            $customer = Customer::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('id', $identity->customer_id)
                ->first();

            if (! $customer instanceof Customer || (string) $customer->status !== 'active') {
                return ['error' => 'authentication_required'];
            }

            if ($this->customerSuspensions->isSuspended($customer)) {
                return [
                    'error' => 'customer_suspended',
                    'details' => $this->customerSuspensions->payload($customer),
                ];
            }

            $this->upsertIdentity((string) $tenant['tenant_id'], (string) $customer->id, $provider, $providerProfile);
            Customer::query()->where('id', $customer->id)->update(['last_login_at' => now(), 'updated_at' => now()]);
            $this->customerAuth->ensurePrimaryWallet((string) $tenant['tenant_id'], (string) $customer->id);

            return [
                'resource' => array_merge(
                    $this->customerAuth->issueSession((string) $tenant['tenant_id'], (string) $customer->id),
                    ['redirect' => $redirectPath],
                ),
                'status' => 200,
            ];
        }

        $linkToken = $this->createLinkToken((string) $tenant['tenant_id'], $provider, $providerProfile);

        return [
            'resource' => [
                'social_link_required' => true,
                'provider' => $provider,
                'link_token' => $linkToken,
                'redirect' => $redirectPath,
                'profile' => [
                    'display_name' => $providerProfile['display_name'] ?? null,
                    'picture_url' => $providerProfile['avatar_url'] ?? null,
                    'email' => $providerProfile['email'] ?? null,
                ],
            ],
            'status' => 200,
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function linkPhone(array $tenant, string $provider, array $payload): array
    {
        $provider = $this->normalizeProvider($provider);

        if (! in_array($provider, ['google', 'apple'], true)) {
            return ['error' => 'provider_not_supported'];
        }

        $token = trim((string) ($payload['link_token'] ?? ''));
        $phone = preg_replace('/\D+/', '', (string) ($payload['phone'] ?? ''));
        $password = (string) ($payload['password'] ?? '');
        $passwordConfirmation = (string) ($payload['password_confirmation'] ?? $password);
        $errors = [];

        if ($token === '') {
            $errors['link_token'][] = 'The link_token field is required.';
        }

        if (! is_string($phone) || strlen($phone) < 9 || strlen($phone) > 10) {
            $errors['phone'][] = 'The phone field must contain a valid phone number.';
        }

        if ($password === '') {
            $errors['password'][] = 'The password field is required.';
        }

        if ($password !== $passwordConfirmation) {
            $errors['password_confirmation'][] = 'The password confirmation does not match.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'details' => ['fields' => $errors]];
        }

        return DB::transaction(function () use ($tenant, $provider, $token, $phone, $password): array {
            $link = CustomerLineLinkToken::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('token_hash', hash('sha256', $token))
                ->where('status', 'pending')
                ->whereNull('consumed_at')
                ->where('expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if (! $link instanceof CustomerLineLinkToken) {
                return ['error' => 'authentication_required'];
            }

            $metadata = is_array($link->metadata_json) ? $link->metadata_json : [];
            $profile = is_array($metadata['profile'] ?? null) ? $metadata['profile'] : [];
            $customer = Customer::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('phone', $phone)
                ->first();

            if ($customer instanceof Customer) {
                if ($customer->password_hash === null || ! Hash::check($password, (string) $customer->password_hash)) {
                    return ['error' => 'validation_failed', 'details' => ['fields' => ['password' => ['The password does not match this phone number.']]]];
                }

                if ($this->customerSuspensions->isSuspended($customer)) {
                    return ['error' => 'customer_suspended', 'details' => $this->customerSuspensions->payload($customer)];
                }
            } else {
                if (strlen($password) < 6) {
                    return ['error' => 'validation_failed', 'details' => ['fields' => ['password' => ['The password field must be at least 6 characters.']]]];
                }

                $customer = $this->customerAuth->createLineCustomer($tenant, [
                    'phone' => $phone,
                    'password' => $password,
                    'name' => $profile['display_name'] ?? strtoupper($provider).' Customer',
                    'email' => $profile['email'] ?? null,
                    'avatar_url' => $profile['avatar_url'] ?? null,
                ]);
            }

            $this->upsertIdentity((string) $tenant['tenant_id'], (string) $customer->id, $provider, $profile);
            CustomerLineLinkToken::query()->where('id', $link->id)->update([
                'status' => 'consumed',
                'consumed_at' => now(),
                'updated_at' => now(),
            ]);
            $this->customerAuth->ensurePrimaryWallet((string) $tenant['tenant_id'], (string) $customer->id);

            return ['resource' => $this->customerAuth->issueSession((string) $tenant['tenant_id'], (string) $customer->id), 'status' => 200];
        });
    }

    private function consumeState(array $tenant, string $provider, string $state, Request $request): ?CustomerExternalAuthState
    {
        if ($state === '') {
            return null;
        }

        return DB::transaction(function () use ($tenant, $provider, $state, $request): ?CustomerExternalAuthState {
            $record = CustomerExternalAuthState::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('provider', $provider)
                ->where('state_hash', hash('sha256', $state))
                ->where('status', 'pending')
                ->whereNull('consumed_at')
                ->where('expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if (! $record instanceof CustomerExternalAuthState) {
                return null;
            }

            $metadata = is_array($record->metadata_json) ? $record->metadata_json : [];
            if (! hash_equals((string) ($metadata['host'] ?? ''), $request->getHost())) {
                return null;
            }

            CustomerExternalAuthState::query()->where('id', $record->id)->update([
                'status' => 'consumed',
                'consumed_at' => now(),
                'updated_at' => now(),
            ]);

            return $record;
        });
    }

    private function googleAuthorizationUrl(TenantSocialAuthProvider $connection, string $state, string $redirectUri): string
    {
        return 'https://accounts.google.com/o/oauth2/v2/auth?'.http_build_query([
            'client_id' => $this->providers->decrypted($connection, 'client_id_encrypted'),
            'redirect_uri' => $redirectUri,
            'response_type' => 'code',
            'scope' => 'openid profile email',
            'state' => $state,
            'prompt' => 'select_account',
        ]);
    }

    private function appleAuthorizationUrl(TenantSocialAuthProvider $connection, string $state, string $redirectUri): string
    {
        return 'https://appleid.apple.com/auth/authorize?'.http_build_query([
            'client_id' => $this->providers->decrypted($connection, 'client_id_encrypted'),
            'redirect_uri' => $redirectUri,
            'response_type' => 'code',
            'response_mode' => 'query',
            'scope' => 'name email',
            'state' => $state,
        ]);
    }

    /**
     * @return array{ok: bool, data?: array<string, mixed>, message?: string}
     */
    private function googleProfile(TenantSocialAuthProvider $connection, string $code, string $redirectUri): array
    {
        $token = Http::asForm()->timeout(10)->post('https://oauth2.googleapis.com/token', [
            'client_id' => $this->providers->decrypted($connection, 'client_id_encrypted'),
            'client_secret' => $this->providers->decrypted($connection, 'client_secret_encrypted'),
            'code' => $code,
            'grant_type' => 'authorization_code',
            'redirect_uri' => $redirectUri,
        ]);

        if (! $token->successful()) {
            return ['ok' => false, 'message' => $token->body()];
        }

        $accessToken = (string) ($token->json('access_token') ?? '');
        $profile = Http::withToken($accessToken)->timeout(10)->get('https://openidconnect.googleapis.com/v1/userinfo');

        if (! $profile->successful()) {
            return ['ok' => false, 'message' => $profile->body()];
        }

        return [
            'ok' => true,
            'data' => [
                'id' => (string) $profile->json('sub'),
                'email' => $profile->json('email'),
                'display_name' => $profile->json('name'),
                'avatar_url' => $profile->json('picture'),
            ],
        ];
    }

    /**
     * @return array{ok: bool, data?: array<string, mixed>, message?: string}
     */
    private function appleProfile(TenantSocialAuthProvider $connection, string $code, string $redirectUri, array $query): array
    {
        $clientSecret = $this->appleClientSecret($connection);

        if ($clientSecret === '') {
            return ['ok' => false, 'message' => 'Apple client secret could not be generated.'];
        }

        $token = Http::asForm()->timeout(10)->post('https://appleid.apple.com/auth/token', [
            'client_id' => $this->providers->decrypted($connection, 'client_id_encrypted'),
            'client_secret' => $clientSecret,
            'code' => $code,
            'grant_type' => 'authorization_code',
            'redirect_uri' => $redirectUri,
        ]);

        if (! $token->successful()) {
            return ['ok' => false, 'message' => $token->body()];
        }

        $claims = $this->decodeJwtPayload((string) ($token->json('id_token') ?? ''));
        $user = is_string($query['user'] ?? null) ? json_decode((string) $query['user'], true) : [];
        $name = is_array($user) ? trim(implode(' ', array_filter([
            $user['name']['firstName'] ?? null,
            $user['name']['lastName'] ?? null,
        ]))) : '';

        return [
            'ok' => true,
            'data' => [
                'id' => (string) ($claims['sub'] ?? ''),
                'email' => $claims['email'] ?? null,
                'display_name' => $name ?: null,
                'avatar_url' => null,
            ],
        ];
    }

    private function appleClientSecret(TenantSocialAuthProvider $connection): string
    {
        $teamId = $this->providers->decrypted($connection, 'team_id_encrypted');
        $keyId = $this->providers->decrypted($connection, 'key_id_encrypted');
        $clientId = $this->providers->decrypted($connection, 'client_id_encrypted');
        $privateKey = $this->providers->decrypted($connection, 'private_key_encrypted');

        if ($teamId === '' || $keyId === '' || $clientId === '' || $privateKey === '') {
            return '';
        }

        $header = $this->base64Url(json_encode(['alg' => 'ES256', 'kid' => $keyId], JSON_THROW_ON_ERROR));
        $payload = $this->base64Url(json_encode([
            'iss' => $teamId,
            'iat' => time(),
            'exp' => time() + 86400 * 30,
            'aud' => 'https://appleid.apple.com',
            'sub' => $clientId,
        ], JSON_THROW_ON_ERROR));
        $body = $header.'.'.$payload;

        $signature = '';
        if (openssl_sign($body, $signature, $privateKey, OPENSSL_ALGO_SHA256) !== true) {
            return '';
        }

        return $body.'.'.$this->base64Url($this->ecdsaDerToJose($signature, 64));
    }

    private function upsertIdentity(string $tenantId, string $customerId, string $provider, array $profile): void
    {
        CustomerSocialIdentity::query()->updateOrCreate(
            ['tenant_id' => $tenantId, 'provider' => $provider, 'provider_user_id' => (string) ($profile['id'] ?? '')],
            [
                'id' => (string) (CustomerSocialIdentity::query()
                    ->where('tenant_id', $tenantId)
                    ->where('provider', $provider)
                    ->where('provider_user_id', (string) ($profile['id'] ?? ''))
                    ->value('id') ?: 'csi_'.Str::ulid()->toBase32()),
                'customer_id' => $customerId,
                'email' => $profile['email'] ?? null,
                'display_name' => $profile['display_name'] ?? null,
                'avatar_url' => $profile['avatar_url'] ?? null,
                'linked_at' => now(),
                'last_login_at' => now(),
                'metadata_json' => $profile,
            ],
        );
    }

    private function linkCurrentCustomer(array $tenant, CustomerSessionContext $context, string $provider, array $profile, string $redirectPath): array
    {
        $existing = CustomerSocialIdentity::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->where('provider', $provider)
            ->where('provider_user_id', (string) ($profile['id'] ?? ''))
            ->first();

        if ($existing instanceof CustomerSocialIdentity && (string) $existing->customer_id !== $context->customerId()) {
            return ['error' => 'resource_conflict'];
        }

        $this->upsertIdentity((string) $tenant['tenant_id'], $context->customerId(), $provider, $profile);

        return [
            'resource' => array_merge(
                $this->customerAuth->issueSession((string) $tenant['tenant_id'], $context->customerId(), null, $context->pinVerified() ? (string) now() : null),
                ['social_linked' => true, 'provider' => $provider, 'redirect' => $redirectPath],
            ),
            'status' => 200,
        ];
    }

    private function createLinkToken(string $tenantId, string $provider, array $profile): string
    {
        $token = 'social_link_'.Str::random(64);

        CustomerLineLinkToken::query()->insert([
            'id' => 'slt_'.Str::ulid()->toBase32(),
            'tenant_id' => $tenantId,
            'token_hash' => hash('sha256', $token),
            'line_user_id' => $provider.':'.(string) ($profile['id'] ?? ''),
            'display_name' => $profile['display_name'] ?? null,
            'picture_url' => $profile['avatar_url'] ?? null,
            'friend_flag' => false,
            'status' => 'pending',
            'expires_at' => now()->addMinutes(15),
            'consumed_at' => null,
            'metadata_json' => ['provider' => $provider, 'profile' => $profile],
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $token;
    }

    private function purpose(mixed $value): string
    {
        return trim((string) $value) === 'password_reset' ? 'password_reset' : 'login';
    }

    private function redirectPath(mixed $value): string
    {
        $redirect = trim((string) $value);

        if ($redirect === '' || ! str_starts_with($redirect, '/') || str_starts_with($redirect, '//')) {
            return '/';
        }

        $path = parse_url($redirect, PHP_URL_PATH);

        if (! is_string($path) || in_array($path, ['/login', '/register', '/forgot-password', '/reset-password', '/pin'], true)) {
            return '/';
        }

        return $redirect;
    }

    private function normalizeProvider(string $provider): string
    {
        return strtolower(trim($provider));
    }

    private function decodeJwtPayload(string $jwt): array
    {
        $parts = explode('.', $jwt);

        if (count($parts) < 2) {
            return [];
        }

        $decoded = base64_decode(strtr($parts[1], '-_', '+/'), true);
        $payload = $decoded === false ? null : json_decode($decoded, true);

        return is_array($payload) ? $payload : [];
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function ecdsaDerToJose(string $derSignature, int $partLength): string
    {
        $offset = 0;
        if (ord($derSignature[$offset++] ?? "\0") !== 0x30) {
            return $derSignature;
        }

        $length = ord($derSignature[$offset++] ?? "\0");
        if (($length & 0x80) !== 0) {
            $lengthBytes = $length & 0x7f;
            $offset += $lengthBytes;
        }

        $r = $this->readDerInteger($derSignature, $offset);
        $s = $this->readDerInteger($derSignature, $offset);
        $half = intdiv($partLength, 2);

        return str_pad($this->trimDerInteger($r), $half, "\0", STR_PAD_LEFT)
            .str_pad($this->trimDerInteger($s), $half, "\0", STR_PAD_LEFT);
    }

    private function readDerInteger(string $signature, int &$offset): string
    {
        if (ord($signature[$offset++] ?? "\0") !== 0x02) {
            return '';
        }

        $length = ord($signature[$offset++] ?? "\0");
        $value = substr($signature, $offset, $length);
        $offset += $length;

        return $value;
    }

    private function trimDerInteger(string $value): string
    {
        while (strlen($value) > 1 && $value[0] === "\0") {
            $value = substr($value, 1);
        }

        return $value;
    }
}

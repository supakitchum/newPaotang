<?php

namespace App\Modules\Auth\Services;

use App\Models\Customer;
use App\Models\CustomerExternalAuthState;
use App\Models\CustomerLineLinkToken;
use App\Models\CustomerSocialIdentity;
use App\Models\TenantSocialAuthProvider;
use App\Modules\SmsOtp\Services\SmsOtpService;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Auth\CustomerSuspensionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class CustomerSocialAuthService
{
    private const PROVIDERS = ['google', 'apple', 'facebook'];

    public function __construct(
        private readonly CustomerAuthService $customerAuth,
        private readonly TenantSocialAuthService $providers,
        private readonly CustomerSuspensionService $customerSuspensions,
        private readonly SmsOtpService $smsOtp,
    ) {
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function redirect(
        array $tenant,
        string $provider,
        array $payload,
        Request $request,
        ?CustomerSessionContext $currentCustomer = null,
    ): array
    {
        $provider = $this->normalizeProvider($provider);

        if (! in_array($provider, self::PROVIDERS, true)) {
            return ['error' => 'provider_not_supported'];
        }

        $connection = $this->providers->activeProvider((string) $tenant['tenant_id'], $provider);

        if (! $connection instanceof TenantSocialAuthProvider) {
            return ['error' => 'provider_not_configured'];
        }

        $purpose = $this->purpose($payload['purpose'] ?? null);
        if ($purpose === 'link' && ! $currentCustomer instanceof CustomerSessionContext) {
            return ['error' => 'authentication_required'];
        }
        if ($purpose === 'link' && ! $currentCustomer->hasPin()) {
            return ['error' => 'pin_setup_required'];
        }
        if ($purpose === 'link' && ! $currentCustomer->pinVerified()) {
            return ['error' => 'pin_required'];
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
                'purpose' => $purpose,
                'link_customer_id' => $purpose === 'link'
                    ? $currentCustomer?->customerId()
                    : null,
                'redirect' => $this->redirectPath($payload['redirect'] ?? $payload['redirect_path'] ?? null),
            ], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'resource' => [
                'url' => match ($provider) {
                    'google' => $this->googleAuthorizationUrl($connection, $state, $redirectUri),
                    'apple' => $this->appleAuthorizationUrl($connection, $state, $redirectUri),
                    'facebook' => $this->facebookAuthorizationUrl($connection, $state, $redirectUri),
                },
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

        if (! in_array($provider, self::PROVIDERS, true)) {
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
        $purpose = $this->purpose($metadata['purpose'] ?? null);
        $redirectPath = $this->redirectPath($metadata['redirect'] ?? null);
        $code = trim((string) ($query['code'] ?? ''));

        if ($code === '') {
            return ['error' => 'validation_failed', 'details' => ['fields' => ['code' => ['The code field is required.']]]];
        }

        $profile = match ($provider) {
            'google' => $this->googleProfile($connection, $code, (string) $stateRecord->redirect_uri),
            'apple' => $this->appleProfile($connection, $code, (string) $stateRecord->redirect_uri, $query),
            'facebook' => $this->facebookProfile($connection, $code, (string) $stateRecord->redirect_uri),
        };

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

        if ($purpose === 'link') {
            $expectedCustomerId = trim((string) ($metadata['link_customer_id'] ?? ''));
            if (! $currentCustomer instanceof CustomerSessionContext
                || $expectedCustomerId === ''
                || ! hash_equals($expectedCustomerId, $currentCustomer->customerId())) {
                return ['error' => 'authentication_required'];
            }
            if (! $currentCustomer->hasPin()) {
                return ['error' => 'pin_setup_required'];
            }
            if (! $currentCustomer->pinVerified()) {
                return ['error' => 'pin_required'];
            }

            return $this->linkCurrentCustomer($tenant, $currentCustomer, $provider, $providerProfile, $redirectPath);
        }

        if ($currentCustomer instanceof CustomerSessionContext) {
            return $this->linkCurrentCustomer($tenant, $currentCustomer, $provider, $providerProfile, $redirectPath);
        }

        $identity = CustomerSocialIdentity::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->where('provider', $provider)
            ->where('provider_user_id', $providerUserId)
            ->whereNull('revoked_at')
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
                    $this->customerAuth->issueSession(
                        (string) $tenant['tenant_id'],
                        (string) $customer->id,
                        activationRequired: true,
                    ),
                    ['redirect' => $redirectPath],
                ),
                'status' => 200,
            ];
        }

        $linkToken = $this->createLinkToken((string) $tenant['tenant_id'], $provider, $providerProfile);

        return [
            'resource' => [
                'social_link_required' => true,
                'social_onboarding_required' => true,
                'phone_verification_required' => true,
                'member_profile_required' => true,
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

        if (! in_array($provider, self::PROVIDERS, true)) {
            return ['error' => 'provider_not_supported'];
        }

        $token = trim((string) ($payload['link_token'] ?? ''));
        $phone = $this->smsOtp->normalizePhone($payload['phone'] ?? null);
        $firstName = trim((string) ($payload['first_name'] ?? ''));
        $lastName = trim((string) ($payload['last_name'] ?? ''));
        $password = (string) ($payload['password'] ?? '');
        $passwordConfirmation = (string) ($payload['password_confirmation'] ?? $password);
        $otpVerificationToken = trim((string) ($payload['otp_verification_token'] ?? ''));
        $acceptedTerms = filter_var(
            $payload['accepted_terms'] ?? false,
            FILTER_VALIDATE_BOOL,
        );
        $errors = [];

        if ($token === '') {
            $errors['link_token'][] = 'The link_token field is required.';
        }

        if (! is_string($phone) || strlen($phone) < 9 || strlen($phone) > 10) {
            $errors['phone'][] = 'The phone field must contain a valid phone number.';
        }

        if ($firstName === '') {
            $errors['first_name'][] = 'The first_name field is required.';
        }

        if ($lastName === '') {
            $errors['last_name'][] = 'The last_name field is required.';
        }

        if (strlen($password) < 6) {
            $errors['password'][] = 'The password field must be at least 6 characters.';
        }

        if ($password !== $passwordConfirmation) {
            $errors['password_confirmation'][] = 'The password confirmation does not match.';
        }

        if ($otpVerificationToken === '') {
            $errors['otp_verification_token'][] = 'Phone OTP verification is required.';
        }

        if (! $acceptedTerms) {
            $errors['accepted_terms'][] = 'The terms must be accepted.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'details' => ['fields' => $errors]];
        }

        return DB::transaction(function () use (
            $tenant,
            $provider,
            $token,
            $phone,
            $firstName,
            $lastName,
            $password,
            $otpVerificationToken,
        ): array {
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
            if (($metadata['provider'] ?? null) !== $provider) {
                return ['error' => 'authentication_required'];
            }
            $profile = is_array($metadata['profile'] ?? null) ? $metadata['profile'] : [];
            $identityOwner = CustomerSocialIdentity::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('provider', $provider)
                ->where('provider_user_id', (string) ($profile['id'] ?? ''))
                ->first();
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

                if ((string) $customer->status !== 'active') {
                    return ['error' => 'authentication_required'];
                }

                if ($identityOwner instanceof CustomerSocialIdentity
                    && (string) $identityOwner->customer_id !== (string) $customer->id) {
                    return ['error' => 'resource_conflict'];
                }
            } else {
                if ($identityOwner instanceof CustomerSocialIdentity) {
                    return ['error' => 'resource_conflict'];
                }
            }

            $otp = $this->smsOtp->consumeVerifiedToken(
                (string) $tenant['tenant_id'],
                (string) $phone,
                SmsOtpService::PURPOSE_REGISTER,
                $otpVerificationToken,
            );
            if (($otp['ok'] ?? false) !== true) {
                return ['error' => (string) ($otp['error'] ?? 'otp_invalid')];
            }

            if (! $customer instanceof Customer) {
                $customer = $this->customerAuth->createLineCustomer($tenant, [
                    'phone' => $phone,
                    'password' => $password,
                    'name' => trim($firstName.' '.$lastName),
                    'first_name' => $firstName,
                    'last_name' => $lastName,
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
            Customer::query()->where('id', $customer->id)->update([
                'last_login_at' => now(),
                'updated_at' => now(),
            ]);
            $this->customerAuth->ensurePrimaryWallet((string) $tenant['tenant_id'], (string) $customer->id);

            return [
                'resource' => $this->customerAuth->issueSession(
                    (string) $tenant['tenant_id'],
                    (string) $customer->id,
                    activationRequired: true,
                ),
                'status' => 200,
            ];
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
        return $this->urlWithQuery($this->socialEndpoint(
            'google.authorize_url',
            'https://accounts.google.com/o/oauth2/v2/auth',
        ), [
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
        return $this->urlWithQuery($this->socialEndpoint(
            'apple.authorize_url',
            'https://appleid.apple.com/auth/authorize',
        ), [
            'client_id' => $this->providers->decrypted($connection, 'client_id_encrypted'),
            'redirect_uri' => $redirectUri,
            'response_type' => 'code',
            'response_mode' => 'query',
            'state' => $state,
        ]);
    }

    private function facebookAuthorizationUrl(TenantSocialAuthProvider $connection, string $state, string $redirectUri): string
    {
        return $this->urlWithQuery($this->socialEndpoint(
            'facebook.authorize_url',
            'https://www.facebook.com/v25.0/dialog/oauth',
        ), [
            'client_id' => $this->providers->decrypted($connection, 'client_id_encrypted'),
            'redirect_uri' => $redirectUri,
            'response_type' => 'code',
            'scope' => 'public_profile,email',
            'state' => $state,
        ]);
    }

    /**
     * @return array{ok: bool, data?: array<string, mixed>, message?: string}
     */
    private function googleProfile(TenantSocialAuthProvider $connection, string $code, string $redirectUri): array
    {
        $token = Http::asForm()->timeout($this->requestTimeoutSeconds())->post($this->socialEndpoint(
            'google.token_url',
            'https://oauth2.googleapis.com/token',
        ), [
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
        if ($accessToken === '') {
            return ['ok' => false, 'message' => 'Google did not return an access token.'];
        }

        $profile = Http::withToken($accessToken)
            ->timeout($this->requestTimeoutSeconds())
            ->get($this->socialEndpoint(
                'google.userinfo_url',
                'https://openidconnect.googleapis.com/v1/userinfo',
            ));

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

        $token = Http::asForm()->timeout($this->requestTimeoutSeconds())->post($this->socialEndpoint(
            'apple.token_url',
            'https://appleid.apple.com/auth/token',
        ), [
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
        $clientId = $this->providers->decrypted($connection, 'client_id_encrypted');
        $issuer = $this->socialEndpoint('apple.issuer', 'https://appleid.apple.com');
        $audience = $claims['aud'] ?? null;
        $validAudience = is_array($audience)
            ? in_array($clientId, $audience, true)
            : hash_equals($clientId, (string) $audience);

        if (
            trim((string) ($claims['sub'] ?? '')) === ''
            || ! hash_equals($issuer, (string) ($claims['iss'] ?? ''))
            || ! $validAudience
            || (int) ($claims['exp'] ?? 0) <= time()
        ) {
            return ['ok' => false, 'message' => 'Apple returned an invalid identity token.'];
        }

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

    /**
     * @return array{ok: bool, data?: array<string, mixed>, message?: string}
     */
    private function facebookProfile(TenantSocialAuthProvider $connection, string $code, string $redirectUri): array
    {
        $clientId = $this->providers->decrypted($connection, 'client_id_encrypted');
        $clientSecret = $this->providers->decrypted($connection, 'client_secret_encrypted');
        $token = Http::asForm()->timeout($this->requestTimeoutSeconds())->post($this->socialEndpoint(
            'facebook.token_url',
            'https://graph.facebook.com/v25.0/oauth/access_token',
        ), [
            'client_id' => $clientId,
            'client_secret' => $clientSecret,
            'code' => $code,
            'redirect_uri' => $redirectUri,
        ]);

        if (! $token->successful()) {
            return ['ok' => false, 'message' => $token->body()];
        }

        $accessToken = trim((string) ($token->json('access_token') ?? ''));
        if ($accessToken === '') {
            return ['ok' => false, 'message' => 'Facebook did not return an access token.'];
        }

        $profile = Http::withToken($accessToken)
            ->timeout($this->requestTimeoutSeconds())
            ->get($this->socialEndpoint(
                'facebook.profile_url',
                'https://graph.facebook.com/v25.0/me',
            ), [
                'fields' => 'id,name,email,picture.width(256).height(256)',
                'appsecret_proof' => hash_hmac('sha256', $accessToken, $clientSecret),
            ]);

        if (! $profile->successful()) {
            return ['ok' => false, 'message' => $profile->body()];
        }

        return [
            'ok' => true,
            'data' => [
                'id' => (string) $profile->json('id'),
                'email' => $profile->json('email'),
                'display_name' => $profile->json('name'),
                'avatar_url' => $profile->json('picture.data.url'),
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
            'aud' => $this->socialEndpoint('apple.issuer', 'https://appleid.apple.com'),
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
        $identity = CustomerSocialIdentity::query()
            ->where('tenant_id', $tenantId)
            ->where('provider', $provider)
            ->where('provider_user_id', (string) ($profile['id'] ?? ''))
            ->whereNull('revoked_at')
            ->first() ?? new CustomerSocialIdentity([
                'id' => 'csi_'.Str::ulid()->toBase32(),
                'tenant_id' => $tenantId,
                'provider' => $provider,
                'provider_user_id' => (string) ($profile['id'] ?? ''),
            ]);
        $identity->fill([
            'customer_id' => $customerId,
            'email' => $profile['email'] ?? null,
            'display_name' => $profile['display_name'] ?? null,
            'avatar_url' => $profile['avatar_url'] ?? null,
            'linked_at' => now(),
            'last_login_at' => now(),
            'revoked_at' => null,
            'metadata_json' => $profile,
        ])->save();
    }

    private function linkCurrentCustomer(array $tenant, CustomerSessionContext $context, string $provider, array $profile, string $redirectPath): array
    {
        $existing = CustomerSocialIdentity::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->where('provider', $provider)
            ->where('provider_user_id', (string) ($profile['id'] ?? ''))
            ->whereNull('revoked_at')
            ->first();

        if ($existing instanceof CustomerSocialIdentity && (string) $existing->customer_id !== $context->customerId()) {
            return ['error' => 'resource_conflict'];
        }

        $this->upsertIdentity((string) $tenant['tenant_id'], $context->customerId(), $provider, $profile);
        $session = $this->customerAuth->rotateVerifiedSession($context);

        if (isset($session['error'])) {
            return ['error' => (string) $session['error']];
        }

        return [
            'resource' => array_merge(
                $session,
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
            'metadata_json' => json_encode(
                ['provider' => $provider, 'profile' => $profile],
                JSON_THROW_ON_ERROR,
            ),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $token;
    }

    private function purpose(mixed $value): string
    {
        return match (trim((string) $value)) {
            'password_reset' => 'password_reset',
            'link' => 'link',
            default => 'login',
        };
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
        return match (strtolower(trim($provider))) {
            'gmail', 'google_login', 'google_oauth', 'google_oauth2' => 'google',
            'apple_id', 'apple_login', 'sign_in_with_apple' => 'apple',
            'fb', 'facebook_login', 'facebook_oauth', 'meta', 'meta_login' => 'facebook',
            default => strtolower(trim($provider)),
        };
    }

    /**
     * @param array<string, scalar> $query
     */
    private function urlWithQuery(string $url, array $query): string
    {
        return $url.(str_contains($url, '?') ? '&' : '?').http_build_query($query);
    }

    private function socialEndpoint(string $key, string $fallback): string
    {
        $value = trim((string) config('platform.social_auth.'.$key, $fallback));

        return $value !== '' ? $value : $fallback;
    }

    private function requestTimeoutSeconds(): int
    {
        return max(1, (int) config('platform.social_auth.http_timeout_seconds', 10));
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

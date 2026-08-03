<?php

namespace App\Modules\Auth\Services;

use App\Models\Customer;
use App\Models\CustomerExternalAuthState;
use App\Models\CustomerLineIdentity;
use App\Models\CustomerLineLinkToken;
use App\Modules\LineNotifications\Services\LineMessagingClient;
use App\Modules\LineNotifications\Services\TenantLineNotificationService;
use App\Modules\SmsOtp\Services\SmsOtpService;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Auth\CustomerSuspensionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class CustomerLineAuthService
{
    private const PROVIDER = 'line';

    public function __construct(
        private readonly CustomerAuthService $customerAuth,
        private readonly CustomerPasswordResetService $passwordResets,
        private readonly LineMessagingClient $line,
        private readonly TenantLineNotificationService $lineNotifications,
        private readonly TenantSocialAuthService $socialAuth,
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
        array $payload,
        Request $request,
        ?CustomerSessionContext $currentCustomer = null,
    ): array
    {
        $channel = $this->lineNotifications->activeChannelForTenant((string) $tenant['tenant_id']);

        if (! $this->lineNotifications->channelReadyForLogin($channel)) {
            if ($this->legacyLineConfigReady()) {
                return $this->legacyBlockedRedirect($tenant, $payload, $request);
            }

            return $this->providerBlocked('provider_not_configured');
        }

        $state = 'line_'.bin2hex(random_bytes(24));
        $redirectUri = $this->callbackUrl($tenant);
        $stateId = 'les_'.Str::ulid()->toBase32();
        $loginChannelId = $this->lineNotifications->decrypted($channel, 'login_channel_id_encrypted');
        $purpose = $this->linePurpose($payload['purpose'] ?? null);
        if ($purpose === 'link' && ! $currentCustomer instanceof CustomerSessionContext) {
            return ['error' => 'authentication_required'];
        }
        if ($purpose === 'link' && ! $currentCustomer->hasPin()) {
            return ['error' => 'pin_setup_required'];
        }
        if ($purpose === 'link' && ! $currentCustomer->pinVerified()) {
            return ['error' => 'pin_required'];
        }

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
                'redirect_uri' => $redirectUri,
                'line_channel_id' => $loginChannelId,
                'purpose' => $purpose,
                'link_customer_id' => $purpose === 'link'
                    ? $currentCustomer?->customerId()
                    : null,
                'redirect' => $this->redirectPath($payload['redirect'] ?? $payload['redirect_path'] ?? null),
                'provider_readiness' => 'production_ready',
                'production_line_ready' => true,
            ], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'resource' => [
                'url' => $this->authorizationUrl($loginChannelId, $state, $redirectUri),
                'provider' => self::PROVIDER,
                'provider_status' => 'ready',
                'production_line_ready' => true,
            ],
            'status' => 200,
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $query
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function callback(array $tenant, array $query, Request $request, ?CustomerSessionContext $currentCustomer = null): array
    {
        $channel = $this->lineNotifications->activeChannelForTenant((string) $tenant['tenant_id']);

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

        if (! $this->lineNotifications->channelReadyForLogin($channel)) {
            if (! $this->legacyLineConfigReady()) {
                return $this->providerBlocked('provider_not_configured');
            }

            $stateRecord = $this->consumePendingState($tenant, $state, $request);

            if ($stateRecord === null) {
                return ['error' => 'authentication_required'];
            }

            return [
                'error' => 'provider_exchange_blocked',
                'details' => [
                    'provider' => self::PROVIDER,
                    'provider_status' => 'blocked_external',
                    'production_line_ready' => false,
                    'line_code' => '[REDACTED]',
                    'reason' => 'LINE login is running in legacy blocked mode.',
                ],
            ];
        }

        $stateRecord = $this->consumePendingState($tenant, $state, $request);

        if ($stateRecord === null) {
            return ['error' => 'authentication_required'];
        }

        $metadata = is_array($stateRecord->metadata_json) ? $stateRecord->metadata_json : [];
        $redirectUri = (string) ($metadata['redirect_uri'] ?? $this->callbackUrl($tenant));
        $purpose = $this->linePurpose($metadata['purpose'] ?? null);
        $redirectPath = $this->redirectPath($metadata['redirect'] ?? null);
        $exchange = $this->line->exchangeLoginCode(
            $this->lineNotifications->decrypted($channel, 'login_channel_id_encrypted'),
            $this->lineNotifications->decrypted($channel, 'login_channel_secret_encrypted'),
            $code,
            $redirectUri,
        );

        if (($exchange['ok'] ?? false) !== true) {
            return [
                'error' => 'provider_exchange_failed',
                'details' => ['reason' => $exchange['message'] ?? 'LINE token exchange failed.'],
            ];
        }

        $accessToken = (string) (($exchange['data'] ?? [])['access_token'] ?? '');
        $profile = $accessToken === '' ? ['ok' => false, 'message' => 'Missing LINE access token.'] : $this->line->profile($accessToken);

        if (($profile['ok'] ?? false) !== true) {
            return [
                'error' => 'provider_exchange_failed',
                'details' => ['reason' => $profile['message'] ?? 'LINE profile fetch failed.'],
            ];
        }

        $lineProfile = $profile['data'] ?? [];
        $lineUserId = $this->nullableString($lineProfile['userId'] ?? null);

        if ($lineUserId === null) {
            return [
                'error' => 'provider_exchange_failed',
                'details' => ['reason' => 'LINE profile did not include a userId.'],
            ];
        }

        $friend = $accessToken === '' ? ['ok' => false] : $this->line->friendshipStatus($accessToken);
        $friendFlag = (bool) (($friend['data'] ?? [])['friendFlag'] ?? false);
        $expectedLinkCustomerId = trim((string) ($metadata['link_customer_id'] ?? ''));
        if ($purpose === 'link' && $expectedLinkCustomerId === '') {
            return ['error' => 'authentication_required'];
        }

        return $this->completeAuthentication(
            $tenant,
            $request,
            $currentCustomer,
            $lineProfile,
            $lineUserId,
            $friendFlag,
            $purpose,
            $redirectPath,
            $expectedLinkCustomerId ?: null,
        );
    }

    /**
     * Complete LINE Login initiated by the native iOS or Android SDK.
     *
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function native(
        array $tenant,
        array $payload,
        Request $request,
        ?CustomerSessionContext $currentCustomer = null,
    ): array {
        $accessToken = trim((string) ($payload['access_token'] ?? ''));
        if ($accessToken === '' || strlen($accessToken) > 4096) {
            return [
                'error' => 'validation_failed',
                'details' => [
                    'fields' => ['access_token' => ['A valid LINE access token is required.']],
                ],
            ];
        }

        $purpose = $this->linePurpose($payload['purpose'] ?? null);
        $redirectPath = $this->redirectPath($payload['redirect'] ?? $payload['redirect_path'] ?? null);
        if ($purpose === 'link') {
            if (! $currentCustomer instanceof CustomerSessionContext) {
                return ['error' => 'authentication_required'];
            }
            if (! $currentCustomer->hasPin()) {
                return ['error' => 'pin_setup_required'];
            }
            if (! $currentCustomer->pinVerified()) {
                return ['error' => 'pin_required'];
            }
        }

        $channel = $this->lineNotifications->activeChannelForTenant((string) $tenant['tenant_id']);
        if (! $this->lineNotifications->channelReadyForLogin($channel)) {
            return $this->providerBlocked('provider_not_configured');
        }

        $configuredChannelId = $this->lineNotifications->decrypted($channel, 'login_channel_id_encrypted');
        $verification = $this->line->verifyLoginAccessToken($accessToken);
        $verified = is_array($verification['data'] ?? null) ? $verification['data'] : [];
        $verifiedChannelId = trim((string) ($verified['client_id'] ?? ''));
        if (($verification['ok'] ?? false) !== true
            || $verifiedChannelId === ''
            || ! hash_equals($configuredChannelId, $verifiedChannelId)) {
            return [
                'error' => 'provider_exchange_failed',
                'details' => ['reason' => 'LINE access token verification failed.'],
            ];
        }

        $profile = $this->line->profile($accessToken);
        if (($profile['ok'] ?? false) !== true) {
            return [
                'error' => 'provider_exchange_failed',
                'details' => ['reason' => 'LINE profile fetch failed.'],
            ];
        }

        $lineProfile = is_array($profile['data'] ?? null) ? $profile['data'] : [];
        $lineUserId = $this->nullableString($lineProfile['userId'] ?? null);
        if ($lineUserId === null) {
            return [
                'error' => 'provider_exchange_failed',
                'details' => ['reason' => 'LINE profile did not include a userId.'],
            ];
        }

        $friend = $this->line->friendshipStatus($accessToken);
        $friendFlag = (bool) (($friend['data'] ?? [])['friendFlag'] ?? false);

        return $this->completeAuthentication(
            $tenant,
            $request,
            $currentCustomer,
            $lineProfile,
            $lineUserId,
            $friendFlag,
            $purpose,
            $redirectPath,
        );
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $lineProfile
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    private function completeAuthentication(
        array $tenant,
        Request $request,
        ?CustomerSessionContext $currentCustomer,
        array $lineProfile,
        string $lineUserId,
        bool $friendFlag,
        string $purpose,
        string $redirectPath,
        ?string $expectedCustomerId = null,
    ): array {
        if ($purpose === 'link') {
            if (! $currentCustomer instanceof CustomerSessionContext
                || ($expectedCustomerId !== null && ! hash_equals($expectedCustomerId, $currentCustomer->customerId()))) {
                return ['error' => 'authentication_required'];
            }
            if (! $currentCustomer->hasPin()) {
                return ['error' => 'pin_setup_required'];
            }
            if (! $currentCustomer->pinVerified()) {
                return ['error' => 'pin_required'];
            }

            return $this->linkCurrentCustomer($tenant, $currentCustomer, $lineProfile, $lineUserId, $friendFlag, $redirectPath);
        }

        if ($currentCustomer instanceof CustomerSessionContext) {
            if ($purpose === 'password_reset') {
                return [
                    'error' => 'line_reset_requires_linked_identity',
                    'details' => ['reason' => 'Sign out before using LINE to reset a password.'],
                ];
            }

            return $this->linkCurrentCustomer($tenant, $currentCustomer, $lineProfile, $lineUserId, $friendFlag, $redirectPath);
        }

        $identity = CustomerLineIdentity::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->where('line_user_id', $lineUserId)
            ->whereNull('revoked_at')
            ->first();

        if ($identity instanceof CustomerLineIdentity) {
            $customer = Customer::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('id', $identity->customer_id)
                ->first();

            if ($customer === null) {
                return ['error' => 'authentication_required'];
            }

            if ($purpose !== 'password_reset' && $this->customerSuspensions->isSuspended($customer)) {
                return [
                    'error' => 'customer_suspended',
                    'details' => $this->customerSuspensions->payload($customer),
                ];
            }

            if ($purpose !== 'password_reset' && (string) $customer->status !== 'active') {
                return ['error' => 'authentication_required'];
            }

            $this->lineNotifications->upsertIdentity((string) $tenant['tenant_id'], (string) $customer->id, $lineProfile, $friendFlag);

            if ($purpose === 'password_reset') {
                return $this->passwordResets->issueLineResetToken((string) $tenant['tenant_id'], $lineUserId, $request);
            }

            Customer::query()->where('id', $customer->id)->update([
                'last_login_at' => now(),
                'updated_at' => now(),
            ]);
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

        if ($purpose === 'password_reset') {
            return [
                'error' => 'line_identity_not_linked',
                'details' => ['reason' => 'LINE account is not linked to a customer account.'],
            ];
        }

        $linkToken = $this->createLinkToken((string) $tenant['tenant_id'], $lineProfile, $friendFlag);

        return [
            'resource' => [
                'line_link_required' => true,
                'social_onboarding_required' => true,
                'phone_verification_required' => true,
                'member_profile_required' => true,
                'link_token' => $linkToken,
                'redirect' => $redirectPath,
                'line_profile' => [
                    'display_name' => $lineProfile['displayName'] ?? null,
                    'picture_url' => $lineProfile['pictureUrl'] ?? null,
                    'friend_flag' => $friendFlag,
                ],
            ],
            'status' => 200,
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $lineProfile
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    private function linkCurrentCustomer(
        array $tenant,
        CustomerSessionContext $currentCustomer,
        array $lineProfile,
        string $lineUserId,
        bool $friendFlag,
        string $redirectPath,
    ): array {
        $tenantId = (string) $tenant['tenant_id'];
        $customerId = $currentCustomer->customerId();
        $existingLineIdentity = CustomerLineIdentity::query()
            ->where('tenant_id', $tenantId)
            ->where('line_user_id', $lineUserId)
            ->first();

        if ($existingLineIdentity instanceof CustomerLineIdentity && (string) $existingLineIdentity->customer_id !== $customerId) {
            return [
                'error' => 'resource_conflict',
                'details' => ['reason' => 'line_identity_already_linked'],
            ];
        }

        $customer = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId)
            ->where('status', 'active')
            ->first();

        if (! $customer instanceof Customer) {
            return ['error' => 'authentication_required'];
        }

        CustomerLineIdentity::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->where('line_user_id', '!=', $lineUserId)
            ->delete();

        $this->lineNotifications->upsertIdentity($tenantId, $customerId, $lineProfile, $friendFlag);
        Customer::query()->where('id', $customerId)->update([
            'last_login_at' => now(),
            'updated_at' => now(),
        ]);
        $this->customerAuth->ensurePrimaryWallet($tenantId, $customerId);

        $session = $this->customerAuth->rotateVerifiedSession($currentCustomer);

        if (isset($session['error'])) {
            return ['error' => (string) $session['error']];
        }

        return [
            'resource' => array_merge(
                $session,
                ['line_linked' => true, 'redirect' => $redirectPath],
            ),
            'status' => 200,
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function linkPhone(array $tenant, array $payload): array
    {
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

            $lineOwner = CustomerLineIdentity::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('line_user_id', $link->line_user_id)
                ->first();

            $customer = Customer::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('phone', $phone)
                ->first();

            if ($customer instanceof Customer) {
                if ($customer->password_hash === null || ! Hash::check($password, (string) $customer->password_hash)) {
                    return [
                        'error' => 'validation_failed',
                        'details' => ['fields' => ['password' => ['The password does not match this phone number.']]],
                    ];
                }

                if ($this->customerSuspensions->isSuspended($customer)) {
                    return [
                        'error' => 'customer_suspended',
                        'details' => $this->customerSuspensions->payload($customer),
                    ];
                }

                if ($customer->status !== 'active') {
                    return ['error' => 'authentication_required'];
                }

                if ($lineOwner instanceof CustomerLineIdentity && (string) $lineOwner->customer_id !== (string) $customer->id) {
                    return ['error' => 'resource_conflict'];
                }
            } else {
                if ($lineOwner instanceof CustomerLineIdentity) {
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
                    'avatar_url' => $link->picture_url,
                ]);
            }

            CustomerLineIdentity::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('customer_id', $customer->id)
                ->where('line_user_id', '!=', $link->line_user_id)
                ->delete();

            $this->lineNotifications->upsertIdentity((string) $tenant['tenant_id'], (string) $customer->id, [
                'userId' => $link->line_user_id,
                'displayName' => $link->display_name,
                'pictureUrl' => $link->picture_url,
            ], (bool) $link->friend_flag);

            CustomerLineLinkToken::query()->where('id', $link->id)->update([
                'status' => 'consumed',
                'consumed_at' => now(),
                'updated_at' => now(),
            ]);
            Customer::query()->where('id', $customer->id)->update([
                'last_login_at' => now(),
                'updated_at' => now(),
            ]);

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
                'reason' => 'LINE channel credentials are not configured for this tenant.',
            ],
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource: array<string, mixed>, status: int}
     */
    private function legacyBlockedRedirect(array $tenant, array $payload, Request $request): array
    {
        $state = 'line_'.bin2hex(random_bytes(24));
        $redirectUri = $this->legacyCallbackUrl($tenant);
        $stateId = 'les_'.Str::ulid()->toBase32();
        $clientId = trim((string) config('platform.line.client_id', ''));
        $purpose = $this->linePurpose($payload['purpose'] ?? null);

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
                'redirect_uri' => $redirectUri,
                'line_channel_id' => $clientId,
                'purpose' => $purpose,
                'redirect' => $this->redirectPath($payload['redirect'] ?? $payload['redirect_path'] ?? null),
                'provider_readiness' => 'blocked_external',
                'production_line_ready' => false,
            ], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'resource' => [
                'url' => $this->authorizationUrl($clientId, $state, $redirectUri),
                'provider' => self::PROVIDER,
                'provider_status' => 'blocked_external',
                'production_line_ready' => false,
            ],
            'status' => 200,
        ];
    }

    private function authorizationUrl(string $clientId, string $state, string $redirectUri): string
    {
        return (string) config('platform.line.authorize_url', 'https://access.line.me/oauth2/v2.1/authorize').'?'.http_build_query([
            'response_type' => 'code',
            'client_id' => $clientId,
            'redirect_uri' => $redirectUri,
            'state' => $state,
            'scope' => 'profile openid',
            'bot_prompt' => 'normal',
        ]);
    }

    private function callbackUrl(array $tenant): string
    {
        $configured = trim((string) config('platform.line.callback_url', ''));

        if ($configured !== '' && ! str_contains($configured, '/api/v1/customer/auth/line/callback')) {
            return $configured;
        }

        return $this->socialAuth->customerCallbackUrl((string) $tenant['tenant_id'], self::PROVIDER);
    }

    private function legacyCallbackUrl(array $tenant): string
    {
        $configured = trim((string) config('platform.line.callback_url', ''));

        return $configured !== '' ? $configured : $this->callbackUrl($tenant);
    }

    private function legacyLineConfigReady(): bool
    {
        return trim((string) config('platform.line.client_id', '')) !== ''
            && trim((string) config('platform.line.client_secret', '')) !== ''
            && trim((string) config('platform.line.callback_url', '')) !== '';
    }

    private function consumePendingState(array $tenant, string $state, Request $request): ?CustomerExternalAuthState
    {
        return DB::transaction(function () use ($tenant, $state, $request): ?CustomerExternalAuthState {
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
    }

    private function createLinkToken(string $tenantId, array $profile, bool $friendFlag): string
    {
        $token = 'lnk_'.bin2hex(random_bytes(24));

        CustomerLineLinkToken::query()->insert([
            'id' => 'clt_'.Str::ulid()->toBase32(),
            'tenant_id' => $tenantId,
            'token_hash' => hash('sha256', $token),
            'line_user_id' => (string) ($profile['userId'] ?? ''),
            'display_name' => $this->nullableString($profile['displayName'] ?? null),
            'picture_url' => $this->nullableString($profile['pictureUrl'] ?? null),
            'friend_flag' => $friendFlag,
            'status' => 'pending',
            'expires_at' => now()->addMinutes(15),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $token;
    }

    private function nullableString(mixed $value): ?string
    {
        $value = trim((string) $value);

        return $value === '' ? null : $value;
    }

    private function linePurpose(mixed $value): string
    {
        $purpose = trim((string) $value);

        return in_array($purpose, ['login', 'password_reset', 'link'], true) ? $purpose : 'login';
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
}

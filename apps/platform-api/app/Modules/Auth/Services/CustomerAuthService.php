<?php

namespace App\Modules\Auth\Services;

use App\Models\Customer;
use App\Models\CustomerAuthSession;
use App\Models\CustomerPinAssertion;
use App\Models\CustomerPushDevice;
use App\Models\PartnerTenant;
use App\Models\Wallet;
use App\Modules\Auth\Events\CustomerSessionReplaced;
use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use App\Modules\SmsOtp\Services\SmsOtpService;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Auth\CustomerSuspensionService;
use App\Shared\Idempotency\IdempotencyService;
use App\Support\CustomerNo;
use App\Support\EncryptedJsonPayload;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class CustomerAuthService
{
    public const REVOKED_REASON_REPLACED_BY_NEW_LOGIN = 'replaced_by_new_login';

    private const REVOKED_REASON_LOGOUT = 'logout';
    private const REVOKED_REASON_REFRESHED = 'refreshed';
    private const REVOKED_REASON_SESSION_ROTATED = 'session_rotated';
    private const ACCESS_TOKEN_TTL_SECONDS = 3600;
    private const REFRESH_TOKEN_TTL_SECONDS = 2592000;
    private const LOGIN_OTP_CHALLENGE_TTL_SECONDS = 600;
    private const PIN_MAX_FAILED_ATTEMPTS = 5;
    private const PIN_LOCK_SECONDS = 900;

    public function __construct(
        private readonly IdempotencyService $idempotency,
        private readonly CustomerSuspensionService $customerSuspensions,
        private readonly SmsOtpService $smsOtp,
        private readonly CustomerNotificationDomainEventService $customerNotificationEvents,
    ) {
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function register(array $tenant, array $payload, Request $request): array
    {
        $normalized = [
            'first_name' => trim((string) ($payload['first_name'] ?? '')),
            'last_name' => trim((string) ($payload['last_name'] ?? '')),
            'phone' => trim((string) ($payload['phone'] ?? '')),
            'email' => $this->nullableLower($payload['email'] ?? null),
            'accepted_terms' => (bool) ($payload['accepted_terms'] ?? true),
        ];
        $normalized['name'] = trim((string) ($payload['name'] ?? trim($normalized['first_name'].' '.$normalized['last_name'])));
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $actorId = $tenant['tenant_id'].':'.$normalized['phone'];
        $replay = $this->idempotency->replayOrConflict($tenant['tenant_id'], 'customer_register', $actorId, 'customer.auth.register', $idempotencyKey, $normalized);

        if (is_array($replay)) {
            return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
        }

        if ($replay !== null) {
            return ['error' => $replay];
        }

        if (Customer::where('tenant_id', $tenant['tenant_id'])
            ->where('phone', $normalized['phone'])
            ->where('status', '<>', 'deleted')
            ->exists()) {
            return ['error' => 'resource_conflict'];
        }
        $latestDeleted = Customer::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->where('phone', $normalized['phone'])
            ->where('status', 'deleted')
            ->latest('deleted_at')
            ->first();
        if ($latestDeleted instanceof Customer
            && $latestDeleted->phone_reuse_after !== null
            && $latestDeleted->phone_reuse_after->isFuture()) {
            return [
                'error' => 'account_reuse_cooldown',
                'details' => ['phone_reuse_after' => $latestDeleted->phone_reuse_after->toISOString()],
            ];
        }

        if ($this->smsOtp->providerRequiredForRegister((string) $tenant['tenant_id'])) {
            $consume = $this->smsOtp->consumeVerifiedToken(
                (string) $tenant['tenant_id'],
                $normalized['phone'],
                SmsOtpService::PURPOSE_REGISTER,
                (string) ($payload['otp_verification_token'] ?? ''),
            );

            if (($consume['ok'] ?? false) !== true) {
                return [
                    'error' => 'otp_required',
                    'errors' => [
                        'otp_verification_token' => ['OTP verification is required before registration.'],
                    ],
                ];
            }
        }

        return DB::transaction(function () use ($tenant, $payload, $request, $normalized, $idempotencyKey, $actorId): array {
            $customerId = 'cus_'.Str::ulid()->toBase32();
            $customerNo = $this->newCustomerNo((string) $tenant['tenant_id']);
            $now = now();

            Customer::query()->insert([
                'id' => $customerId,
                'tenant_id' => $tenant['tenant_id'],
                'customer_no' => $customerNo,
                'phone' => $normalized['phone'],
                'email' => $normalized['email'],
                'password_hash' => Hash::make((string) $payload['password']),
                'avatar_url' => null,
                'name' => $normalized['name'],
                'first_name' => $normalized['first_name'] !== '' ? $normalized['first_name'] : null,
                'last_name' => $normalized['last_name'] !== '' ? $normalized['last_name'] : null,
                'status' => 'active',
                'last_login_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->ensurePrimaryWallet((string) $tenant['tenant_id'], $customerId);
            $response = $this->issueSession(
                (string) $tenant['tenant_id'],
                $customerId,
                activationRequired: true,
            );

            $this->idempotency->storeResponse(
                $tenant['tenant_id'],
                'customer_register',
                $actorId,
                'customer.auth.register',
                $idempotencyKey,
                $normalized,
                201,
                $response,
            );

            return ['resource' => $response, 'status' => 201];
        });
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function login(array $tenant, array $payload, Request $request): array
    {
        $loginMethod = strtolower(trim((string) ($payload['login_method'] ?? 'legacy')));
        if (! in_array($loginMethod, ['legacy', 'otp', 'password'], true)) {
            return [
                'error' => 'validation_failed',
                'errors' => ['login_method' => ['The login method is invalid.']],
            ];
        }

        $username = trim((string) ($payload['phone'] ?? $payload['username'] ?? ''));
        $password = (string) ($payload['password'] ?? '');

        if ($username === '' || ($loginMethod !== 'otp' && $password === '')) {
            return [
                'error' => 'validation_failed',
                'errors' => [
                    $username === '' ? 'phone' : 'password' => [
                        $username === ''
                            ? 'The phone field is required.'
                            : 'The password field is required.',
                    ],
                ],
            ];
        }

        if ($loginMethod === 'otp') {
            $username = $this->smsOtp->normalizePhone($username) ?? '';
            if ($username === '') {
                return [
                    'error' => 'validation_failed',
                    'errors' => ['phone' => ['The phone field is invalid.']],
                ];
            }
        }

        $customer = Customer::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->where('status', '<>', 'deleted')
            ->when(
                $loginMethod === 'otp',
                fn ($query) => $query->where('phone', $username),
                fn ($query) => $query->where(function ($query) use ($username): void {
                    $query->where('phone', $username)
                        ->orWhere('email', strtolower($username));
                }),
            )
            ->first();

        if ($customer === null) {
            return ['error' => 'customer_account_not_found'];
        }

        if ($loginMethod !== 'otp'
            && ($customer->password_hash === null || ! Hash::check($password, (string) $customer->password_hash))) {
            return ['error' => 'invalid_login_credentials'];
        }

        if ($this->customerSuspensions->isSuspended($customer)) {
            return [
                'error' => 'customer_suspended',
                'suspension' => $this->customerSuspensions->payload($customer),
            ];
        }

        if ((string) $customer->status !== 'active') {
            return ['error' => 'customer_account_inactive'];
        }

        if ($loginMethod === 'otp') {
            return $this->beginLoginOtpChallenge(
                (string) $tenant['tenant_id'],
                (string) $customer->id,
                (string) $customer->phone,
                $request,
            );
        }

        if ($loginMethod === 'legacy' && $this->smsOtp->providerRequiredForLogin((string) $tenant['tenant_id'])) {
            return $this->beginLoginOtpChallenge(
                (string) $tenant['tenant_id'],
                (string) $customer->id,
                (string) $customer->phone,
                $request,
            );
        }

        return $this->completeLogin((string) $tenant['tenant_id'], (string) $customer->id);
    }

    /**
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, message?: string, details?: array<string, mixed>}
     */
    public function resendLoginOtp(array $tenant, string $challengeToken, Request $request): array
    {
        $challenge = $this->loginOtpChallenge((string) $tenant['tenant_id'], $challengeToken);
        if ($challenge === null) {
            return [
                'error' => 'login_otp_challenge_invalid',
                'status' => 422,
                'message' => 'The login OTP challenge is invalid or expired.',
            ];
        }

        $result = $this->smsOtp->requestOtp(
            (string) $tenant['tenant_id'],
            ['purpose' => SmsOtpService::PURPOSE_LOGIN],
            $request,
            SmsOtpService::PURPOSE_LOGIN,
            (string) $challenge['phone'],
        );

        if (isset($result['error'])) {
            return $result;
        }

        Cache::put(
            $this->loginOtpChallengeCacheKey((string) $tenant['tenant_id'], $challengeToken),
            $challenge,
            now()->addSeconds(self::LOGIN_OTP_CHALLENGE_TTL_SECONDS),
        );

        return [
            'resource' => $this->loginOtpChallengeResource(
                $challengeToken,
                (string) $challenge['phone'],
                $result['resource'] ?? [],
            ),
            'status' => 202,
        ];
    }

    /**
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, message?: string, details?: array<string, mixed>}
     */
    public function verifyLoginOtp(array $tenant, string $challengeToken, string $otp): array
    {
        $tenantId = (string) $tenant['tenant_id'];
        $challenge = $this->loginOtpChallenge($tenantId, $challengeToken);
        if ($challenge === null) {
            return [
                'error' => 'login_otp_challenge_invalid',
                'status' => 422,
                'message' => 'The login OTP challenge is invalid or expired.',
            ];
        }

        $verification = $this->smsOtp->verifyOtp(
            $tenantId,
            ['otp' => $otp],
            SmsOtpService::PURPOSE_LOGIN,
            (string) $challenge['phone'],
        );
        if (isset($verification['error'])) {
            return $verification;
        }

        $verificationToken = trim((string) (($verification['resource'] ?? [])['otp_verification_token'] ?? ''));
        $consume = $this->smsOtp->consumeVerifiedToken(
            $tenantId,
            (string) $challenge['phone'],
            SmsOtpService::PURPOSE_LOGIN,
            $verificationToken,
        );
        if (($consume['ok'] ?? false) !== true) {
            return [
                'error' => 'otp_invalid',
                'status' => 422,
                'message' => 'OTP is invalid or expired.',
            ];
        }

        $cacheKey = $this->loginOtpChallengeCacheKey($tenantId, $challengeToken);
        $consumedChallenge = Cache::pull($cacheKey);
        if (! is_array($consumedChallenge)) {
            return [
                'error' => 'login_otp_challenge_invalid',
                'status' => 422,
                'message' => 'The login OTP challenge is invalid or expired.',
            ];
        }

        $customer = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', (string) $consumedChallenge['customer_id'])
            ->first();
        if (! $customer instanceof Customer) {
            return ['error' => 'customer_account_not_found'];
        }
        if ((string) $customer->status !== 'active') {
            return ['error' => 'customer_account_inactive'];
        }
        if ($this->customerSuspensions->isSuspended($customer)) {
            return [
                'error' => 'customer_suspended',
                'suspension' => $this->customerSuspensions->payload($customer),
            ];
        }

        return [
            'resource' => $this->completeLogin($tenantId, (string) $customer->id),
            'status' => 200,
        ];
    }

    public function createLineCustomer(array $tenant, array $payload): object
    {
        $tenantId = (string) $tenant['tenant_id'];
        $now = now();
        $name = trim((string) ($payload['name'] ?? ''));
        $firstName = trim((string) ($payload['first_name'] ?? ''));
        $lastName = trim((string) ($payload['last_name'] ?? ''));

        if ($name === '') {
            $name = trim($firstName.' '.$lastName);
        }

        if ($name === '') {
            $name = 'LINE Customer';
        }

        $customerId = 'cus_'.Str::ulid()->toBase32();

        Customer::query()->insert([
            'id' => $customerId,
            'tenant_id' => $tenantId,
            'customer_no' => $this->newCustomerNo($tenantId),
            'phone' => trim((string) ($payload['phone'] ?? '')),
            'email' => $this->nullableLower($payload['email'] ?? null),
            'password_hash' => Hash::make((string) ($payload['password'] ?? '')),
            'avatar_url' => trim((string) ($payload['avatar_url'] ?? '')) ?: null,
            'name' => $name,
            'first_name' => $firstName !== '' ? $firstName : null,
            'last_name' => $lastName !== '' ? $lastName : null,
            'status' => 'active',
            'last_login_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $this->ensurePrimaryWallet($tenantId, $customerId);

        return Customer::query()->where('id', $customerId)->firstOrFail();
    }

    /**
     * @param array<string, mixed> $tenant
     * @return array<string, mixed>|null
     */
    public function refresh(array $tenant, string $refreshToken): ?array
    {
        if ($refreshToken === '') {
            return null;
        }

        return DB::transaction(function () use ($tenant, $refreshToken): ?array {
            $oldSession = CustomerAuthSession::query()
                ->where('refresh_token_hash', hash('sha256', $refreshToken))
                ->where('tenant_id', $tenant['tenant_id'])
                ->whereNull('revoked_at')
                ->where('refresh_expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if ($oldSession === null) {
                $replacedSession = CustomerAuthSession::query()
                    ->where('refresh_token_hash', hash('sha256', $refreshToken))
                    ->where('tenant_id', $tenant['tenant_id'])
                    ->where('revoked_reason', self::REVOKED_REASON_REPLACED_BY_NEW_LOGIN)
                    ->first();

                if ($replacedSession instanceof CustomerAuthSession) {
                    return [
                        'error' => 'customer_session_replaced',
                        'replacement_session_id' => $replacedSession->replaced_by_session_id,
                        'replaced_at' => $replacedSession->revoked_at?->toISOString(),
                    ];
                }

                return null;
            }

            $customer = Customer::whereKey($oldSession->customer_id)
                ->where('tenant_id', $tenant['tenant_id'])
                ->first();

            if ($customer === null) {
                CustomerAuthSession::query()->where('id', $oldSession->id)->update([
                    'revoked_at' => now(),
                    'revoked_reason' => self::REVOKED_REASON_REFRESHED,
                    'updated_at' => now(),
                ]);

                return null;
            }

            if ($this->customerSuspensions->isSuspended($customer)) {
                CustomerAuthSession::query()->where('id', $oldSession->id)->update([
                    'revoked_at' => now(),
                    'revoked_reason' => self::REVOKED_REASON_REFRESHED,
                    'updated_at' => now(),
                ]);

                return [
                    'error' => 'customer_suspended',
                    'suspension' => $this->customerSuspensions->payload($customer),
                ];
            }

            if ((string) $customer->status !== 'active') {
                CustomerAuthSession::query()->where('id', $oldSession->id)->update([
                    'revoked_at' => now(),
                    'revoked_reason' => self::REVOKED_REASON_REFRESHED,
                    'updated_at' => now(),
                ]);

                return null;
            }

            CustomerAuthSession::query()->where('id', $oldSession->id)->update([
                'revoked_at' => now(),
                'revoked_reason' => self::REVOKED_REASON_REFRESHED,
                'updated_at' => now(),
            ]);

            return $this->issueSession(
                (string) $tenant['tenant_id'],
                (string) $customer->id,
                (string) $oldSession->id,
                $oldSession->pin_verified_at === null ? null : (string) $oldSession->pin_verified_at,
                (bool) ($oldSession->activation_required ?? false),
            );
        });
    }

    public function revoke(CustomerSessionContext $context): void
    {
        CustomerAuthSession::query()
            ->where('id', $context->session['id'])
            ->whereNull('revoked_at')
            ->update([
                'revoked_at' => now(),
                'revoked_reason' => self::REVOKED_REASON_LOGOUT,
                'updated_at' => now(),
            ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function profile(CustomerSessionContext $context): ?array
    {
        $customer = Customer::where('tenant_id', $context->tenantId())
            ->where('id', $context->customerId())
            ->first();

        return $customer === null ? null : $this->customerProfile($customer, $context->pinVerified());
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function updateProfile(CustomerSessionContext $context, array $payload, Request $request): array
    {
        if (array_key_exists('reward_payout_bank_account', $payload) || array_key_exists('bank_account', $payload)) {
            $pinResult = $this->verifyPinOrAssertionForContext($context, $payload, false);

            if (($pinResult['error'] ?? null) !== null) {
                return $pinResult;
            }
        }

        $normalized = array_filter([
            'name' => array_key_exists('name', $payload) ? trim((string) $payload['name']) : null,
            'first_name' => array_key_exists('first_name', $payload) ? trim((string) $payload['first_name']) : null,
            'last_name' => array_key_exists('last_name', $payload) ? trim((string) $payload['last_name']) : null,
            'phone' => array_key_exists('phone', $payload) ? trim((string) $payload['phone']) : null,
            'email' => array_key_exists('email', $payload) ? $this->nullableLower($payload['email']) : null,
            'avatar_url' => array_key_exists('avatar_url', $payload) ? ($payload['avatar_url'] ?: null) : null,
            'preferred_locale' => array_key_exists('preferred_locale', $payload) ? $this->normalizeLocale($payload['preferred_locale']) : null,
        ], fn (mixed $value): bool => $value !== null);

        if (array_key_exists('reward_payout_bank_account', $payload) || array_key_exists('bank_account', $payload)) {
            $bankAccount = $this->normalizeBankAccount($payload['reward_payout_bank_account'] ?? $payload['bank_account'] ?? null);
            $normalized['reward_payout_bank_account_json'] = null;
            $normalized['reward_payout_bank_account_encrypted'] = EncryptedJsonPayload::encrypt($bankAccount);
        }

        if (array_key_exists('auto_reward_claim', $payload) || array_key_exists('auto_reward_claim_enabled', $payload) || array_key_exists('auto_reward_claim_payout_method', $payload)) {
            if (! Schema::hasColumn('customers', 'auto_reward_claim_enabled') || ! Schema::hasColumn('customers', 'auto_reward_claim_payout_method')) {
                return ['error' => 'resource_conflict'];
            }

            $autoReward = is_array($payload['auto_reward_claim'] ?? null) ? $payload['auto_reward_claim'] : [];
            $enabled = array_key_exists('enabled', $autoReward)
                ? filter_var($autoReward['enabled'], FILTER_VALIDATE_BOOLEAN)
                : filter_var($payload['auto_reward_claim_enabled'] ?? false, FILTER_VALIDATE_BOOLEAN);
            $method = $this->normalizeAutoRewardClaimPayoutMethod(
                $autoReward['payout_method'] ?? $autoReward['type'] ?? $payload['auto_reward_claim_payout_method'] ?? null,
            );

            $normalized['auto_reward_claim_enabled'] = $enabled;
            $normalized['auto_reward_claim_payout_method'] = $enabled ? $method : null;
        }

        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict($context->tenantId(), 'customer', $context->customerId(), 'customer.profile.patch', $idempotencyKey, $normalized);

        if (is_array($replay)) {
            return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
        }

        if ($replay !== null) {
            return ['error' => $replay];
        }

        return DB::transaction(function () use ($context, $normalized, $idempotencyKey): array {
            $updates = $normalized + ['updated_at' => now()];

            Customer::query()
                ->where('tenant_id', $context->tenantId())
                ->where('id', $context->customerId())
                ->update($updates);

            $profile = $this->profile($context) ?? [];
            $this->idempotency->storeResponse(
                $context->tenantId(),
                'customer',
                $context->customerId(),
                'customer.profile.patch',
                $idempotencyKey,
                $normalized,
                200,
                $profile,
            );

            return ['resource' => $profile, 'status' => 200];
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function pinStatus(CustomerSessionContext $context): array
    {
        $customer = Customer::where('tenant_id', $context->tenantId())
            ->where('id', $context->customerId())
            ->first();

        return [
            'has_pin' => $customer !== null && $this->customerHasPin($customer),
            'pin_verified' => $context->pinVerified(),
            'pin_setup_required' => $customer !== null && ! $this->customerHasPin($customer),
            'pin_required' => $customer !== null && $this->customerHasPin($customer) && ! $context->pinVerified(),
            'locked_until' => $customer?->pin_locked_until?->toIso8601String(),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, retry_after_seconds?: int|null}
     */
    public function setupPin(CustomerSessionContext $context, array $payload): array
    {
        $pin = trim((string) ($payload['pin'] ?? ''));

        return DB::transaction(function () use ($context, $pin): array {
            $customer = Customer::query()
                ->where('tenant_id', $context->tenantId())
                ->where('id', $context->customerId())
                ->lockForUpdate()
                ->first();

            if ($customer === null) {
                return ['error' => 'authentication_required'];
            }

            if ($this->customerHasPin($customer)) {
                return ['error' => 'resource_conflict'];
            }

            $now = now();
            if (! $this->markSessionPinVerified((string) $context->session['id'], $now)) {
                return ['error' => 'customer_session_replaced'];
            }

            Customer::query()->where('id', $customer->id)->update([
                'pin_hash' => Hash::make($pin),
                'pin_set_at' => $now,
                'pin_changed_at' => $now,
                'pin_failed_attempts' => 0,
                'pin_locked_until' => null,
                'pin_last_verified_at' => $now,
                'updated_at' => $now,
            ]);

            DB::afterCommit(fn () => $this->customerNotificationEvents->pinChanged(
                $context->tenantId(),
                $context->customerId(),
                $now->toISOString(),
            ));
            $fresh = Customer::whereKey($customer->id)->first();

            return ['resource' => $this->pinResponse($fresh, true)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, retry_after_seconds?: int|null}
     */
    public function verifyPin(CustomerSessionContext $context, array $payload): array
    {
        $pin = trim((string) ($payload['pin'] ?? ''));

        return $this->verifyPinForContext($context, $pin, true);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, retry_after_seconds?: int|null}
     */
    public function verifyPinOrAssertionForContext(CustomerSessionContext $context, array $payload, bool $markSessionVerified = false): array
    {
        $assertionToken = trim((string) ($payload['pin_assertion_token'] ?? ''));

        if ($assertionToken !== '') {
            return $this->consumePinAssertionForContext($context, $assertionToken, $markSessionVerified);
        }

        return $this->verifyPinForContext($context, trim((string) ($payload['pin'] ?? '')), $markSessionVerified);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, retry_after_seconds?: int|null}
     */
    public function changePin(CustomerSessionContext $context, array $payload): array
    {
        $currentPin = trim((string) ($payload['current_pin'] ?? ''));
        $newPin = trim((string) ($payload['new_pin'] ?? ''));

        return DB::transaction(function () use ($context, $currentPin, $newPin): array {
            $customer = Customer::query()
                ->where('tenant_id', $context->tenantId())
                ->where('id', $context->customerId())
                ->lockForUpdate()
                ->first();

            if ($customer === null) {
                return ['error' => 'authentication_required'];
            }

            if (! $this->customerHasPin($customer)) {
                return ['error' => 'pin_setup_required'];
            }

            if ($this->pinLockRetryAfter($customer) !== null) {
                return ['error' => 'pin_locked', 'retry_after_seconds' => $this->pinLockRetryAfter($customer)];
            }

            if (! Hash::check($currentPin, (string) $customer->pin_hash)) {
                $this->recordFailedPinAttempt($customer);

                return ['error' => 'pin_invalid'];
            }

            $now = now();
            if (! $this->markSessionPinVerified((string) $context->session['id'], $now)) {
                return ['error' => 'customer_session_replaced'];
            }

            Customer::query()->where('id', $customer->id)->update([
                'pin_hash' => Hash::make($newPin),
                'pin_changed_at' => $now,
                'pin_failed_attempts' => 0,
                'pin_locked_until' => null,
                'pin_last_verified_at' => $now,
                'updated_at' => $now,
            ]);

            DB::afterCommit(fn () => $this->customerNotificationEvents->pinChanged(
                $context->tenantId(),
                $context->customerId(),
                $now->toISOString(),
            ));
            $fresh = Customer::whereKey($customer->id)->first();

            return ['resource' => $this->pinResponse($fresh, true)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function verifyPinResetPassword(CustomerSessionContext $context, array $payload): array
    {
        $customer = Customer::query()
            ->where('tenant_id', $context->tenantId())
            ->where('id', $context->customerId())
            ->first();

        $password = (string) ($payload['password'] ?? '');

        if ($customer === null) {
            return ['error' => 'authentication_required'];
        }

        if ($customer->password_hash === null || ! Hash::check($password, (string) $customer->password_hash)) {
            return ['error' => 'password_invalid'];
        }

        Cache::put($this->pinResetCacheKey($context), [
            'tenant_id' => $context->tenantId(),
            'customer_id' => $context->customerId(),
            'session_id' => (string) $context->session['id'],
        ], now()->addMinutes(10));

        return [
            'resource' => [
                'reset_verified' => true,
                'expires_in_seconds' => 600,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function resetPin(CustomerSessionContext $context, array $payload): array
    {
        $verified = Cache::get($this->pinResetCacheKey($context));

        if (! is_array($verified)
            || ($verified['tenant_id'] ?? null) !== $context->tenantId()
            || ($verified['customer_id'] ?? null) !== $context->customerId()
            || ($verified['session_id'] ?? null) !== (string) $context->session['id']) {
            return ['error' => 'pin_reset_not_verified'];
        }

        $pin = trim((string) ($payload['pin'] ?? ''));

        return DB::transaction(function () use ($context, $pin): array {
            $customer = Customer::query()
                ->where('tenant_id', $context->tenantId())
                ->where('id', $context->customerId())
                ->lockForUpdate()
                ->first();

            if ($customer === null) {
                return ['error' => 'authentication_required'];
            }

            if (! $this->customerHasPin($customer)) {
                return ['error' => 'pin_setup_required'];
            }

            $now = now();
            if (! $this->markSessionPinVerified((string) $context->session['id'], $now)) {
                return ['error' => 'customer_session_replaced'];
            }

            Customer::query()->where('id', $customer->id)->update([
                'pin_hash' => Hash::make($pin),
                'pin_set_at' => $customer->pin_set_at ?? $now,
                'pin_changed_at' => $now,
                'pin_failed_attempts' => 0,
                'pin_locked_until' => null,
                'pin_last_verified_at' => $now,
                'updated_at' => $now,
            ]);

            Cache::forget($this->pinResetCacheKey($context));
            DB::afterCommit(fn () => $this->customerNotificationEvents->pinChanged(
                $context->tenantId(),
                $context->customerId(),
                $now->toISOString(),
            ));
            $fresh = Customer::whereKey($customer->id)->first();

            return ['resource' => $this->pinResponse($fresh, true)];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function resetPinAfterOtp(CustomerSessionContext $context, string $pin): array
    {
        return DB::transaction(function () use ($context, $pin): array {
            $customer = Customer::query()
                ->where('tenant_id', $context->tenantId())
                ->where('id', $context->customerId())
                ->lockForUpdate()
                ->first();

            if ($customer === null) {
                return ['error' => 'authentication_required'];
            }

            if (! $this->customerHasPin($customer)) {
                return ['error' => 'pin_setup_required'];
            }

            $now = now();
            if (! $this->markSessionPinVerified((string) $context->session['id'], $now)) {
                return ['error' => 'customer_session_replaced'];
            }

            Customer::query()->where('id', $customer->id)->update([
                'pin_hash' => Hash::make($pin),
                'pin_set_at' => $customer->pin_set_at ?? $now,
                'pin_changed_at' => $now,
                'pin_failed_attempts' => 0,
                'pin_locked_until' => null,
                'pin_last_verified_at' => $now,
                'updated_at' => $now,
            ]);

            Cache::forget($this->pinResetCacheKey($context));
            DB::afterCommit(fn () => $this->customerNotificationEvents->pinChanged(
                $context->tenantId(),
                $context->customerId(),
                $now->toISOString(),
            ));
            $fresh = Customer::whereKey($customer->id)->first();

            return ['resource' => $this->pinResponse($fresh, true)];
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function issueSession(
        string $tenantId,
        string $customerId,
        ?string $refreshedFromId = null,
        ?string $pinVerifiedAt = null,
        bool $activationRequired = false,
    ): array {
        $accessToken = $this->newToken('npa_ct');
        $refreshToken = $this->newToken('npa_crt');
        $sessionId = 'cas_'.Str::ulid()->toBase32();
        $now = now();

        CustomerAuthSession::query()->insert([
            'id' => $sessionId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'access_token_hash' => hash('sha256', $accessToken),
            'refresh_token_hash' => hash('sha256', $refreshToken),
            'access_expires_at' => $now->copy()->addSeconds(self::ACCESS_TOKEN_TTL_SECONDS),
            'refresh_expires_at' => $now->copy()->addSeconds(self::REFRESH_TOKEN_TTL_SECONDS),
            'revoked_at' => null,
            'refreshed_from_id' => $refreshedFromId,
            'last_used_at' => null,
            'pin_verified_at' => $pinVerifiedAt,
            'activation_required' => $activationRequired,
            'activated_at' => $activationRequired ? null : $now,
            'revoked_reason' => null,
            'replaced_by_session_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $customer = Customer::where('id', $customerId)->first();
        $pinVerified = $pinVerifiedAt !== null;

        return [
            'session_id' => $sessionId,
            'token' => $accessToken,
            'refresh_token' => $refreshToken,
            'expires_in' => self::ACCESS_TOKEN_TTL_SECONDS,
            'pin_verified' => $pinVerified,
            'session_activation_required' => $activationRequired,
            'pin_setup_required' => $customer === null ? false : ! $this->customerHasPin($customer),
            'pin_required' => $customer !== null && $this->customerHasPin($customer) && ! $pinVerified,
            'user' => $this->customerProfile($customer, $pinVerified),
        ];
    }

    /**
     * Rotate an already verified session without treating it as a login from a
     * second device. Social-account linking uses this path.
     *
     * @return array<string, mixed>
     */
    public function rotateVerifiedSession(CustomerSessionContext $context): array
    {
        return DB::transaction(function () use ($context): array {
            $oldSession = CustomerAuthSession::query()
                ->where('id', (string) $context->session['id'])
                ->where('tenant_id', $context->tenantId())
                ->where('customer_id', $context->customerId())
                ->whereNull('revoked_at')
                ->lockForUpdate()
                ->first();

            if (! $oldSession instanceof CustomerAuthSession) {
                return ['error' => 'authentication_required'];
            }

            $now = now();
            CustomerAuthSession::query()->where('id', $oldSession->id)->update([
                'revoked_at' => $now,
                'revoked_reason' => self::REVOKED_REASON_SESSION_ROTATED,
                'updated_at' => $now,
            ]);

            return $this->issueSession(
                $context->tenantId(),
                $context->customerId(),
                (string) $oldSession->id,
                $context->pinVerified() ? $now->toISOString() : null,
                (bool) ($oldSession->activation_required ?? false),
            );
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, message?: string, details?: array<string, mixed>}
     */
    private function beginLoginOtpChallenge(string $tenantId, string $customerId, string $phone, Request $request): array
    {
        $phone = $this->smsOtp->normalizePhone($phone) ?? '';
        if ($phone === '') {
            return [
                'error' => 'login_otp_phone_missing',
                'status' => 409,
                'message' => 'This customer account does not have a phone number for OTP verification.',
            ];
        }

        $result = $this->smsOtp->requestOtp(
            $tenantId,
            ['purpose' => SmsOtpService::PURPOSE_LOGIN],
            $request,
            SmsOtpService::PURPOSE_LOGIN,
            $phone,
        );
        if (isset($result['error']) && ($result['error'] ?? null) !== 'otp_cooldown') {
            return $result;
        }

        $challengeToken = 'lotp_'.Str::random(64);
        Cache::put(
            $this->loginOtpChallengeCacheKey($tenantId, $challengeToken),
            [
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'phone' => $phone,
            ],
            now()->addSeconds(self::LOGIN_OTP_CHALLENGE_TTL_SECONDS),
        );

        $delivery = $result['resource'] ?? [];
        if (($result['error'] ?? null) === 'otp_cooldown') {
            $delivery['resend_after_seconds'] = (int) (($result['details'] ?? [])['retry_after_seconds'] ?? 60);
        }

        return [
            'resource' => $this->loginOtpChallengeResource($challengeToken, $phone, $delivery),
            'status' => 202,
        ];
    }

    /**
     * @param array<string, mixed> $delivery
     * @return array<string, mixed>
     */
    private function loginOtpChallengeResource(string $challengeToken, string $phone, array $delivery): array
    {
        return [
            'otp_required' => true,
            'next_step' => 'otp',
            'login_challenge_token' => $challengeToken,
            'phone_masked' => trim((string) ($delivery['phone_masked'] ?? '')) ?: $this->smsOtp->maskedPhone($phone),
            'expires_in_seconds' => self::LOGIN_OTP_CHALLENGE_TTL_SECONDS,
            'resend_after_seconds' => max(0, (int) ($delivery['resend_after_seconds'] ?? 60)),
        ];
    }

    /**
     * @return array{tenant_id: string, customer_id: string, phone: string}|null
     */
    private function loginOtpChallenge(string $tenantId, string $challengeToken): ?array
    {
        $challengeToken = trim($challengeToken);
        if ($challengeToken === '') {
            return null;
        }

        $challenge = Cache::get($this->loginOtpChallengeCacheKey($tenantId, $challengeToken));
        if (! is_array($challenge)
            || ! hash_equals($tenantId, (string) ($challenge['tenant_id'] ?? ''))
            || trim((string) ($challenge['customer_id'] ?? '')) === ''
            || trim((string) ($challenge['phone'] ?? '')) === '') {
            return null;
        }

        return [
            'tenant_id' => $tenantId,
            'customer_id' => (string) $challenge['customer_id'],
            'phone' => (string) $challenge['phone'],
        ];
    }

    private function loginOtpChallengeCacheKey(string $tenantId, string $challengeToken): string
    {
        return 'customer_login_otp:'.$tenantId.':'.hash('sha256', trim($challengeToken));
    }

    /**
     * @return array<string, mixed>
     */
    private function completeLogin(string $tenantId, string $customerId): array
    {
        Customer::query()->where('tenant_id', $tenantId)->where('id', $customerId)->update([
            'last_login_at' => now(),
            'updated_at' => now(),
        ]);
        $this->ensurePrimaryWallet($tenantId, $customerId);

        return $this->issueSession(
            $tenantId,
            $customerId,
            activationRequired: true,
        );
    }

    public function ensurePrimaryWallet(string $tenantId, string $customerId): string
    {
        $existing = Wallet::where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->where('type', 'primary')
            ->value('id');

        if ($existing !== null) {
            return (string) $existing;
        }

        $walletId = 'wal_'.substr(sha1($tenantId.':'.$customerId.':primary'), 0, 20);

        Wallet::query()->insertOrIgnore([
            'id' => $walletId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'name' => 'Primary wallet',
            'type' => 'primary',
            'status' => 'active',
            'balance_amount' => 0,
            'currency' => 'THB',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return (string) Wallet::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->where('type', 'primary')
            ->value('id');
    }

    private function newToken(string $prefix): string
    {
        return $prefix.'_'.Str::random(64);
    }

    private function nullableLower(mixed $value): ?string
    {
        $email = strtolower(trim((string) $value));

        return $email === '' ? null : $email;
    }

    /**
     * @return array<string, string>
     */
    private function normalizeBankAccount(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $bankName = trim((string) ($value['bank_name'] ?? $value['bank'] ?? ''));
        $accountName = trim((string) ($value['account_name'] ?? $value['bank_deposit_name'] ?? ''));
        $accountNumber = trim((string) ($value['account_number'] ?? $value['account_no'] ?? $value['bank_account_no'] ?? $value['bank_deposit_number'] ?? ''));
        $branch = trim((string) ($value['branch'] ?? ''));
        $normalized = [
            'bank_name' => $bankName,
            'account_name' => $accountName,
            'account_number' => $accountNumber,
            'branch' => $branch,
        ];

        return array_filter($normalized, fn (string $field): bool => $field !== '');
    }

    /**
     * @return array<string, mixed>
     */
    private function decodedBankAccount(mixed $value): array
    {
        if (is_array($value)) {
            return $value;
        }

        if (! is_string($value) || trim($value) === '') {
            return [];
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, retry_after_seconds?: int|null}
     */
    private function verifyPinForContext(CustomerSessionContext $context, string $pin, bool $markSessionVerified): array
    {
        return DB::transaction(function () use ($context, $pin, $markSessionVerified): array {
            $customer = Customer::query()
                ->where('tenant_id', $context->tenantId())
                ->where('id', $context->customerId())
                ->lockForUpdate()
                ->first();

            if ($customer === null) {
                return ['error' => 'authentication_required'];
            }

            if (! $this->customerHasPin($customer)) {
                return ['error' => 'pin_setup_required'];
            }

            $retryAfter = $this->pinLockRetryAfter($customer);

            if ($retryAfter !== null) {
                return ['error' => 'pin_locked', 'retry_after_seconds' => $retryAfter];
            }

            if (! Hash::check($pin, (string) $customer->pin_hash)) {
                $this->recordFailedPinAttempt($customer);

                $fresh = Customer::whereKey($customer->id)->first();
                $retryAfter = $fresh === null ? null : $this->pinLockRetryAfter($fresh);

                return $retryAfter === null
                    ? ['error' => 'pin_invalid']
                    : ['error' => 'pin_locked', 'retry_after_seconds' => $retryAfter];
            }

            $now = now();
            if ($markSessionVerified
                && ! $this->markSessionPinVerified((string) $context->session['id'], $now)) {
                return ['error' => 'customer_session_replaced'];
            }

            Customer::query()->where('id', $customer->id)->update([
                'pin_failed_attempts' => 0,
                'pin_locked_until' => null,
                'pin_last_verified_at' => $now,
                'updated_at' => $now,
            ]);

            $fresh = Customer::whereKey($customer->id)->first();

            return ['resource' => $this->pinResponse($fresh, true)];
        });
    }

    private function markSessionPinVerified(string $sessionId, mixed $verifiedAt): bool
    {
        $snapshot = CustomerAuthSession::query()->where('id', $sessionId)->first();

        if (! $snapshot instanceof CustomerAuthSession || $snapshot->revoked_at !== null) {
            return false;
        }

        // Locking the customer first serializes PIN and biometric completions
        // across concurrent login attempts without relying on request timing.
        $customer = Customer::query()
            ->where('tenant_id', $snapshot->tenant_id)
            ->where('id', $snapshot->customer_id)
            ->lockForUpdate()
            ->first();

        if (! $customer instanceof Customer) {
            return false;
        }

        $sessions = CustomerAuthSession::query()
            ->where('tenant_id', $snapshot->tenant_id)
            ->where('customer_id', $snapshot->customer_id)
            ->whereNull('revoked_at')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
        $session = $sessions->firstWhere('id', $sessionId);

        if (! $session instanceof CustomerAuthSession) {
            return false;
        }

        $now = now();

        if (! (bool) $session->activation_required) {
            CustomerAuthSession::query()->where('id', $sessionId)->update([
                'pin_verified_at' => $verifiedAt,
                'updated_at' => $now,
            ]);

            return true;
        }

        $otherSessions = $sessions->where('id', '!=', $sessionId);
        $otherSessionIds = $otherSessions
            ->pluck('id')
            ->map(static fn (mixed $id): string => (string) $id)
            ->all();
        $replacedActiveSessionCount = $otherSessions
            ->filter(static fn (CustomerAuthSession $item): bool => ! (bool) $item->activation_required)
            ->count();

        if ($otherSessionIds !== []) {
            CustomerAuthSession::query()
                ->whereIn('id', $otherSessionIds)
                ->whereNull('revoked_at')
                ->update([
                    'revoked_at' => $now,
                    'revoked_reason' => self::REVOKED_REASON_REPLACED_BY_NEW_LOGIN,
                    'replaced_by_session_id' => $sessionId,
                    'updated_at' => $now,
                ]);
        }

        CustomerAuthSession::query()->where('id', $sessionId)->update([
            'pin_verified_at' => $verifiedAt,
            'activation_required' => false,
            'activated_at' => $now,
            'updated_at' => $now,
        ]);

        if ($replacedActiveSessionCount > 0) {
            // Create the final security delivery while the previous push
            // registrations are still addressable. The delivery worker has a
            // narrow exception for this event after the registrations revoke.
            $this->customerNotificationEvents->sessionReplaced(
                (string) $session->tenant_id,
                (string) $session->customer_id,
                $sessionId,
            );

            if (Schema::hasTable('customer_push_devices')) {
                CustomerPushDevice::query()
                    ->where('tenant_id', (string) $session->tenant_id)
                    ->where('customer_id', (string) $session->customer_id)
                    ->whereNull('revoked_at')
                    ->update([
                        'revoked_at' => $now,
                        'revoked_reason' => 'session_replaced',
                        'updated_at' => $now,
                    ]);
            }

            $tenantId = (string) $session->tenant_id;
            $customerId = (string) $session->customer_id;
            $replacedAt = $now->toISOString();
            DB::afterCommit(function () use ($tenantId, $customerId, $sessionId, $replacedAt): void {
                try {
                    CustomerSessionReplaced::dispatch(
                        $tenantId,
                        $customerId,
                        $sessionId,
                        $replacedAt,
                    );
                } catch (\Throwable $exception) {
                    Log::warning('Customer session replacement realtime broadcast failed.', [
                        'tenant_id' => $tenantId,
                        'customer_id' => $customerId,
                        'replacement_session_id' => $sessionId,
                        'exception' => $exception::class,
                    ]);
                }
            });
        }

        return true;
    }

    public function markSessionPinVerifiedForAssertion(string $sessionId): bool
    {
        return $this->markSessionPinVerified($sessionId, now());
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    private function consumePinAssertionForContext(CustomerSessionContext $context, string $token, bool $markSessionVerified): array
    {
        return DB::transaction(function () use ($context, $token, $markSessionVerified): array {
            $assertion = CustomerPinAssertion::query()
                ->where('tenant_id', $context->tenantId())
                ->where('customer_id', $context->customerId())
                ->where('token_hash', hash('sha256', $token))
                ->where('status', 'active')
                ->whereNull('consumed_at')
                ->where('expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if (! $assertion instanceof CustomerPinAssertion) {
                return ['error' => 'pin_assertion_invalid'];
            }

            if ($markSessionVerified
                && ! $this->markSessionPinVerified((string) $context->session['id'], now())) {
                return ['error' => 'customer_session_replaced'];
            }

            CustomerPinAssertion::query()->where('id', $assertion->id)->update([
                'status' => 'consumed',
                'consumed_at' => now(),
                'updated_at' => now(),
            ]);

            return [
                'resource' => [
                    'pin_verified' => true,
                    'pin_assertion_consumed' => true,
                ],
            ];
        });
    }

    /**
     * @return array<string, mixed>
     */
    private function pinResponse(?object $customer, bool $pinVerified): array
    {
        return [
            'has_pin' => $customer !== null && $this->customerHasPin($customer),
            'pin_verified' => $pinVerified,
            'pin_setup_required' => $customer !== null && ! $this->customerHasPin($customer),
            'pin_required' => $customer !== null && $this->customerHasPin($customer) && ! $pinVerified,
            'user' => $this->customerProfile($customer, $pinVerified),
        ];
    }

    private function customerHasPin(object $customer): bool
    {
        return is_string($customer->pin_hash) && $customer->pin_hash !== '';
    }

    private function pinResetCacheKey(CustomerSessionContext $context): string
    {
        return 'customer_pin_reset:'.sha1($context->tenantId().':'.$context->customerId().':'.(string) $context->session['id']);
    }

    private function pinLockRetryAfter(object $customer): ?int
    {
        if ($customer->pin_locked_until === null) {
            return null;
        }

        $lockedUntil = $customer->pin_locked_until;
        $retryAfter = method_exists($lockedUntil, 'getTimestamp')
            ? $lockedUntil->getTimestamp() - now()->getTimestamp()
            : strtotime((string) $lockedUntil) - time();

        return $retryAfter > 0 ? $retryAfter : null;
    }

    private function recordFailedPinAttempt(object $customer): void
    {
        $attempts = min(255, ((int) ($customer->pin_failed_attempts ?? 0)) + 1);
        $updates = [
            'pin_failed_attempts' => $attempts,
            'updated_at' => now(),
        ];

        if ($attempts >= self::PIN_MAX_FAILED_ATTEMPTS) {
            $updates['pin_locked_until'] = now()->addSeconds(self::PIN_LOCK_SECONDS);
        }

        Customer::query()->where('id', $customer->id)->update($updates);
    }

    /**
     * @return array<string, mixed>
     */
    private function customerProfile(?object $customer, bool $pinVerified = false): array
    {
        if ($customer === null) {
            return [];
        }

        $hasPin = $this->customerHasPin($customer);
        $wallet = Wallet::query()
            ->where('tenant_id', (string) $customer->tenant_id)
            ->where('customer_id', (string) $customer->id)
            ->orderByRaw("CASE WHEN type = 'primary' THEN 0 ELSE 1 END")
            ->orderBy('created_at')
            ->first();
        $walletResource = $this->customerProfileWalletResource($wallet);

        return [
            'id' => (string) $customer->id,
            'tenant_id' => (string) $customer->tenant_id,
            'customer_no' => CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
            'member_no' => CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
            'name' => $customer->name,
            'first_name' => $customer->first_name ?? null,
            'last_name' => $customer->last_name ?? null,
            'phone' => $customer->phone,
            'email' => $customer->email ?? null,
            'status' => $customer->status ?? null,
            'preferred_locale' => $customer->preferred_locale ?? null,
            'avatar_url' => $customer->avatar_url ?? null,
            'reward_payout_bank_account' => EncryptedJsonPayload::decrypt(
                $customer->reward_payout_bank_account_encrypted ?? null,
                $customer->reward_payout_bank_account_json ?? null,
            ),
            'auto_reward_claim' => [
                'enabled' => (bool) ($customer->auto_reward_claim_enabled ?? false),
                'payout_method' => $this->normalizeAutoRewardClaimPayoutMethod($customer->auto_reward_claim_payout_method ?? null),
                'type' => $this->autoRewardClaimType($customer->auto_reward_claim_payout_method ?? null),
            ],
            'wallet' => $walletResource,
            'primary_wallet' => $walletResource,
            'has_pin' => $hasPin,
            'pin_verified' => $pinVerified,
            'pin_required' => $hasPin && ! $pinVerified,
            'pin_setup_required' => ! $hasPin,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function customerProfileWalletResource(?object $wallet): ?array
    {
        if ($wallet === null) {
            return null;
        }

        return [
            'id' => (string) $wallet->id,
            'name' => (string) $wallet->name,
            'type' => (string) $wallet->type,
        ];
    }

    private function normalizeAutoRewardClaimPayoutMethod(mixed $value): string
    {
        $method = trim((string) $value);

        return match ($method) {
            'bank', 'bank_transfer' => 'bank_transfer',
            default => 'wallet_credit',
        };
    }

    private function autoRewardClaimType(mixed $value): string
    {
        return $this->normalizeAutoRewardClaimPayoutMethod($value) === 'bank_transfer' ? 'bank_transfer' : 'wallet';
    }

    private function normalizeLocale(mixed $value): ?string
    {
        $locale = str_replace('_', '-', strtolower(trim((string) $value)));

        return match ($locale) {
            'th', 'th-th' => 'th-TH',
            'en', 'en-us', 'en-gb' => 'en-US',
            default => null,
        };
    }

    private function newCustomerNo(string $tenantId): string
    {
        $tenantCode = PartnerTenant::query()->where('id', $tenantId)->value('code');

        do {
            $customerNo = CustomerNo::generate(is_string($tenantCode) ? $tenantCode : null, $tenantId);
        } while (Customer::query()->where('customer_no', $customerNo)->exists());

        return $customerNo;
    }
}

<?php

namespace App\Modules\Auth\Services;

use App\Models\Customer;
use App\Models\CustomerAuthSession;
use App\Models\PartnerTenant;
use App\Models\Wallet;
use App\Modules\SmsOtp\Services\SmsOtpService;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Auth\CustomerSuspensionService;
use App\Shared\Idempotency\IdempotencyService;
use App\Support\CustomerNo;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class CustomerAuthService
{
    private const ACCESS_TOKEN_TTL_SECONDS = 3600;
    private const REFRESH_TOKEN_TTL_SECONDS = 2592000;
    private const PIN_MAX_FAILED_ATTEMPTS = 5;
    private const PIN_LOCK_SECONDS = 900;

    public function __construct(
        private readonly IdempotencyService $idempotency,
        private readonly CustomerSuspensionService $customerSuspensions,
        private readonly SmsOtpService $smsOtp,
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

        if (Customer::where('tenant_id', $tenant['tenant_id'])->where('phone', $normalized['phone'])->exists()) {
            return ['error' => 'resource_conflict'];
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
            $response = $this->issueSession((string) $tenant['tenant_id'], $customerId);

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
     * @return array<string, mixed>|null
     */
    public function login(array $tenant, array $payload): ?array
    {
        $username = trim((string) ($payload['username'] ?? ''));
        $password = (string) ($payload['password'] ?? '');

        if ($username === '' || $password === '') {
            return null;
        }

        $customer = Customer::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->where(function ($query) use ($username): void {
                $query->where('phone', $username)
                    ->orWhere('email', strtolower($username));
            })
            ->first();

        if ($customer === null || $customer->password_hash === null || ! Hash::check($password, (string) $customer->password_hash)) {
            return null;
        }

        if ($this->customerSuspensions->isSuspended($customer)) {
            return [
                'error' => 'customer_suspended',
                'suspension' => $this->customerSuspensions->payload($customer),
            ];
        }

        if ((string) $customer->status !== 'active') {
            return null;
        }

        Customer::query()->where('id', $customer->id)->update([
            'last_login_at' => now(),
            'updated_at' => now(),
        ]);

        $this->ensurePrimaryWallet((string) $tenant['tenant_id'], (string) $customer->id);

        return $this->issueSession((string) $tenant['tenant_id'], (string) $customer->id);
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
                return null;
            }

            $customer = Customer::whereKey($oldSession->customer_id)
                ->where('tenant_id', $tenant['tenant_id'])
                ->first();

            if ($customer === null) {
                CustomerAuthSession::query()->where('id', $oldSession->id)->update([
                    'revoked_at' => now(),
                    'updated_at' => now(),
                ]);

                return null;
            }

            if ($this->customerSuspensions->isSuspended($customer)) {
                CustomerAuthSession::query()->where('id', $oldSession->id)->update([
                    'revoked_at' => now(),
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
                    'updated_at' => now(),
                ]);

                return null;
            }

            CustomerAuthSession::query()->where('id', $oldSession->id)->update([
                'revoked_at' => now(),
                'updated_at' => now(),
            ]);

            return $this->issueSession(
                (string) $tenant['tenant_id'],
                (string) $customer->id,
                (string) $oldSession->id,
                $oldSession->pin_verified_at === null ? null : (string) $oldSession->pin_verified_at,
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
            $pinResult = $this->verifyPinForContext($context, trim((string) ($payload['pin'] ?? '')), false);

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
            $normalized['reward_payout_bank_account_json'] = $bankAccount === []
                ? null
                : json_encode($bankAccount, JSON_THROW_ON_ERROR);
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
            Customer::query()->where('id', $customer->id)->update([
                'pin_hash' => Hash::make($pin),
                'pin_set_at' => $now,
                'pin_changed_at' => $now,
                'pin_failed_attempts' => 0,
                'pin_locked_until' => null,
                'pin_last_verified_at' => $now,
                'updated_at' => $now,
            ]);

            $this->markSessionPinVerified((string) $context->session['id'], $now);
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
            Customer::query()->where('id', $customer->id)->update([
                'pin_hash' => Hash::make($newPin),
                'pin_changed_at' => $now,
                'pin_failed_attempts' => 0,
                'pin_locked_until' => null,
                'pin_last_verified_at' => $now,
                'updated_at' => $now,
            ]);

            $this->markSessionPinVerified((string) $context->session['id'], $now);
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
            $this->markSessionPinVerified((string) $context->session['id'], $now);
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
            $this->markSessionPinVerified((string) $context->session['id'], $now);
            $fresh = Customer::whereKey($customer->id)->first();

            return ['resource' => $this->pinResponse($fresh, true)];
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function issueSession(string $tenantId, string $customerId, ?string $refreshedFromId = null, ?string $pinVerifiedAt = null): array
    {
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
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $customer = Customer::where('id', $customerId)->first();
        $pinVerified = $pinVerifiedAt !== null;

        return [
            'token' => $accessToken,
            'refresh_token' => $refreshToken,
            'expires_in' => self::ACCESS_TOKEN_TTL_SECONDS,
            'pin_verified' => $pinVerified,
            'pin_setup_required' => $customer === null ? false : ! $this->customerHasPin($customer),
            'pin_required' => $customer !== null && $this->customerHasPin($customer) && ! $pinVerified,
            'user' => $this->customerProfile($customer, $pinVerified),
        ];
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

        Wallet::query()->insert([
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

        return $walletId;
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
            Customer::query()->where('id', $customer->id)->update([
                'pin_failed_attempts' => 0,
                'pin_locked_until' => null,
                'pin_last_verified_at' => $now,
                'updated_at' => $now,
            ]);

            if ($markSessionVerified) {
                $this->markSessionPinVerified((string) $context->session['id'], $now);
            }

            $fresh = Customer::whereKey($customer->id)->first();

            return ['resource' => $this->pinResponse($fresh, true)];
        });
    }

    private function markSessionPinVerified(string $sessionId, mixed $verifiedAt): void
    {
        CustomerAuthSession::query()->where('id', $sessionId)->update([
            'pin_verified_at' => $verifiedAt,
            'updated_at' => now(),
        ]);
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
            'reward_payout_bank_account' => $this->decodedBankAccount($customer->reward_payout_bank_account_json ?? null),
            'auto_reward_claim' => [
                'enabled' => (bool) ($customer->auto_reward_claim_enabled ?? false),
                'payout_method' => $this->normalizeAutoRewardClaimPayoutMethod($customer->auto_reward_claim_payout_method ?? null),
                'type' => $this->autoRewardClaimType($customer->auto_reward_claim_payout_method ?? null),
            ],
            'has_pin' => $hasPin,
            'pin_verified' => $pinVerified,
            'pin_required' => $hasPin && ! $pinVerified,
            'pin_setup_required' => ! $hasPin,
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

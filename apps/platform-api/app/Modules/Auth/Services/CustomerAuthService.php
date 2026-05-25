<?php

namespace App\Modules\Auth\Services;

use App\Models\Customer;
use App\Models\CustomerAuthSession;
use App\Models\PartnerTenant;
use App\Models\Wallet;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Idempotency\IdempotencyService;
use App\Support\CustomerNo;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class CustomerAuthService
{
    private const ACCESS_TOKEN_TTL_SECONDS = 3600;
    private const REFRESH_TOKEN_TTL_SECONDS = 604800;

    public function __construct(private readonly IdempotencyService $idempotency)
    {
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
            ->where('status', 'active')
            ->where(function ($query) use ($username): void {
                $query->where('phone', $username)
                    ->orWhere('email', strtolower($username));
            })
            ->first();

        if ($customer === null || $customer->password_hash === null || ! Hash::check($password, (string) $customer->password_hash)) {
            return null;
        }

        Customer::query()->where('id', $customer->id)->update([
            'last_login_at' => now(),
            'updated_at' => now(),
        ]);

        $this->ensurePrimaryWallet((string) $tenant['tenant_id'], (string) $customer->id);

        return $this->issueSession((string) $tenant['tenant_id'], (string) $customer->id);
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
                ->where('status', 'active')
                ->first();

            if ($customer === null) {
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

            return $this->issueSession((string) $tenant['tenant_id'], (string) $customer->id, (string) $oldSession->id);
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

        return $customer === null ? null : $this->customerProfile($customer);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function updateProfile(CustomerSessionContext $context, array $payload, Request $request): array
    {
        $normalized = array_filter([
            'name' => array_key_exists('name', $payload) ? trim((string) $payload['name']) : null,
            'first_name' => array_key_exists('first_name', $payload) ? trim((string) $payload['first_name']) : null,
            'last_name' => array_key_exists('last_name', $payload) ? trim((string) $payload['last_name']) : null,
            'phone' => array_key_exists('phone', $payload) ? trim((string) $payload['phone']) : null,
            'email' => array_key_exists('email', $payload) ? $this->nullableLower($payload['email']) : null,
            'avatar_url' => array_key_exists('avatar_url', $payload) ? ($payload['avatar_url'] ?: null) : null,
        ], fn (mixed $value): bool => $value !== null);

        if (array_key_exists('reward_payout_bank_account', $payload) || array_key_exists('bank_account', $payload)) {
            $bankAccount = $this->normalizeBankAccount($payload['reward_payout_bank_account'] ?? $payload['bank_account'] ?? null);
            $normalized['reward_payout_bank_account_json'] = $bankAccount === []
                ? null
                : json_encode($bankAccount, JSON_THROW_ON_ERROR);
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
    public function issueSession(string $tenantId, string $customerId, ?string $refreshedFromId = null): array
    {
        $accessToken = $this->newToken('npa_ct');
        $refreshToken = $this->newToken('npa_crt');
        $sessionId = 'cas_'.Str::ulid()->toBase32();

        CustomerAuthSession::query()->insert([
            'id' => $sessionId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'access_token_hash' => hash('sha256', $accessToken),
            'refresh_token_hash' => hash('sha256', $refreshToken),
            'access_expires_at' => now()->addSeconds(self::ACCESS_TOKEN_TTL_SECONDS),
            'refresh_expires_at' => now()->addSeconds(self::REFRESH_TOKEN_TTL_SECONDS),
            'revoked_at' => null,
            'refreshed_from_id' => $refreshedFromId,
            'last_used_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'token' => $accessToken,
            'refresh_token' => $refreshToken,
            'expires_in' => self::ACCESS_TOKEN_TTL_SECONDS,
            'user' => $this->customerProfile(Customer::where('id', $customerId)->first()),
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
     * @return array<string, mixed>
     */
    private function customerProfile(object $customer): array
    {
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
            'avatar_url' => $customer->avatar_url ?? null,
            'reward_payout_bank_account' => $this->decodedBankAccount($customer->reward_payout_bank_account_json ?? null),
        ];
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

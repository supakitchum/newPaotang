<?php

namespace App\Modules\Auth\Services;

use App\Models\Customer;
use App\Models\CustomerAuthSession;
use App\Models\CustomerLineIdentity;
use App\Models\CustomerPasswordResetRequest;
use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class CustomerPasswordResetService
{
    private const RESET_TTL_MINUTES = 30;
    private const TABLE = 'customer_password_reset_requests';

    public function __construct(private readonly CustomerNotificationDomainEventService $customerNotificationEvents)
    {
    }

    public function storageReady(): bool
    {
        try {
            return Schema::hasTable(self::TABLE);
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function forgotPasswordErrors(array $payload): array
    {
        $phone = $this->normalizePhone($payload['phone'] ?? null);
        $email = $this->normalizeEmail($payload['email'] ?? null);

        if ($phone === null && $email === null) {
            return ['identifier' => ['Enter the phone number or email attached to this account.']];
        }

        if ($phone !== null && (strlen($phone) < 9 || strlen($phone) > 10)) {
            return ['phone' => ['The phone field must contain a valid phone number.']];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function resetPasswordErrors(array $payload): array
    {
        $errors = [];
        $token = trim((string) ($payload['token'] ?? ''));
        $password = (string) ($payload['password'] ?? '');
        $confirmation = (string) ($payload['password_confirmation'] ?? '');

        if ($token === '') {
            $errors['token'][] = 'The token field is required.';
        }

        if ($password === '') {
            $errors['password'][] = 'The password field is required.';
        }

        if ($password !== $confirmation) {
            $errors['password_confirmation'][] = 'The password confirmation does not match.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function resetPasswordWithOtpErrors(array $payload): array
    {
        $errors = [];
        $phone = $this->normalizePhone($payload['phone'] ?? null);
        $token = trim((string) ($payload['otp_verification_token'] ?? ''));
        $password = (string) ($payload['password'] ?? '');
        $confirmation = (string) ($payload['password_confirmation'] ?? '');

        if ($phone === null) {
            $errors['phone'][] = 'The phone field must contain a valid phone number.';
        }

        if ($token === '') {
            $errors['otp_verification_token'][] = 'The OTP verification token field is required.';
        }

        if ($password === '') {
            $errors['password'][] = 'The password field is required.';
        }

        if ($password !== $confirmation) {
            $errors['password_confirmation'][] = 'The password confirmation does not match.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, mixed>}
     */
    public function requestReset(array $tenant, array $payload, Request $request): array
    {
        $tenantId = (string) $tenant['tenant_id'];

        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        $phone = $this->normalizePhone($payload['phone'] ?? null);
        $email = $this->normalizeEmail($payload['email'] ?? null);
        $identifier = $phone ?? $email ?? trim((string) ($payload['identifier'] ?? ''));

        $customer = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->where(function ($query) use ($phone, $email): void {
                if ($phone !== null) {
                    $query->orWhere('phone', $phone);
                }

                if ($email !== null) {
                    $query->orWhere('email', $email);
                }
            })
            ->first();

        $requestId = 'cpr_'.Str::ulid()->toBase32();
        CustomerPasswordResetRequest::query()->insert([
            'id' => $requestId,
            'tenant_id' => $tenantId,
            'customer_id' => $customer?->id,
            'channel' => 'admin_request',
            'status' => 'submitted',
            'requested_identifier' => $identifier,
            'phone' => $phone,
            'email' => $email,
            'reset_token_hash' => null,
            'link_issued_at' => null,
            'expires_at' => null,
            'consumed_at' => null,
            'issued_by_admin_id' => null,
            'requested_ip' => $request->ip(),
            'requested_user_agent' => $request->userAgent(),
            'metadata_json' => json_encode([
                'matched_customer' => $customer instanceof Customer,
            ], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'resource' => [
                'status' => 'submitted',
                'message' => 'Password reset request submitted.',
            ],
            'status' => 202,
        ];
    }

    /**
     * @param array<string, mixed> $query
     * @return array<string, mixed>
     */
    public function tenantRequests(string $tenantId, array $query): array
    {
        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        $limit = max(1, min(100, (int) ($query['limit'] ?? 25)));
        $status = trim((string) ($query['status'] ?? ''));
        $search = trim((string) ($query['q'] ?? $query['search'] ?? ''));

        $builder = CustomerPasswordResetRequest::query()
            ->from('customer_password_reset_requests')
            ->leftJoin('customers', 'customers.id', '=', 'customer_password_reset_requests.customer_id')
            ->leftJoin('admin_users', 'admin_users.id', '=', 'customer_password_reset_requests.issued_by_admin_id')
            ->where('customer_password_reset_requests.tenant_id', $tenantId)
            ->select([
                'customer_password_reset_requests.*',
                'customers.customer_no as customer_no',
                'customers.name as customer_name',
                'customers.phone as customer_phone',
                'customers.email as customer_email',
                'admin_users.name as issued_by_name',
                'admin_users.email as issued_by_email',
            ])
            ->orderByDesc('customer_password_reset_requests.created_at')
            ->limit($limit + 1);

        if ($status !== '') {
            $builder->where('customer_password_reset_requests.status', $status);
        }

        if ($search !== '') {
            $builder->where(function ($inner) use ($search): void {
                $inner->where('customer_password_reset_requests.requested_identifier', 'like', '%'.$search.'%')
                    ->orWhere('customers.customer_no', 'like', '%'.$search.'%')
                    ->orWhere('customers.name', 'like', '%'.$search.'%')
                    ->orWhere('customers.phone', 'like', '%'.$search.'%');
            });
        }

        $rows = $builder->get()->map(fn (object $row): array => $this->tenantRequestResource($row))->all();
        $hasMore = count($rows) > $limit;

        if ($hasMore) {
            array_pop($rows);
        }

        return [
            'data' => $rows,
            'meta' => [
                'limit' => $limit,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, mixed>}
     */
    public function issueAdminResetLink(string $tenantId, string $requestId, AdminSessionContext $context, Request $request): array
    {
        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        return DB::transaction(function () use ($tenantId, $requestId, $context, $request): array {
            $reset = CustomerPasswordResetRequest::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $requestId)
                ->whereIn('status', ['submitted', 'link_issued'])
                ->lockForUpdate()
                ->first();

            if (! $reset instanceof CustomerPasswordResetRequest) {
                return ['error' => 'not_found'];
            }

            $customer = $reset->customer_id === null ? null : Customer::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $reset->customer_id)
                ->where('status', 'active')
                ->first();

            if (! $customer instanceof Customer) {
                return [
                    'error' => 'validation_failed',
                    'errors' => ['customer' => ['No active customer matched this request.']],
                ];
            }

            return [
                'resource' => $this->issueTokenForRequest(
                    reset: $reset,
                    customer: $customer,
                    issuedByAdminId: (string) $context->adminUser['id'],
                    request: $request,
                ),
                'status' => 200,
            ];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function resetPassword(array $payload, Request $request, ?string $tenantId = null): array
    {
        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        $token = trim((string) ($payload['token'] ?? ''));
        $tokenHash = $this->hashToken($token);
        $password = (string) ($payload['password'] ?? '');

        return DB::transaction(function () use ($tokenHash, $password, $request, $payload, $tenantId): array {
            $reset = CustomerPasswordResetRequest::query()
                ->where('reset_token_hash', $tokenHash)
                ->where('status', 'link_issued')
                ->whereNull('consumed_at')
                ->where('expires_at', '>', now())
                ->when($tenantId !== null && $tenantId !== '', fn ($query) => $query->where('tenant_id', $tenantId))
                ->lockForUpdate()
                ->first();

            if (! $reset instanceof CustomerPasswordResetRequest) {
                return ['error' => 'authentication_required'];
            }

            $customer = Customer::query()
                ->where('tenant_id', $reset->tenant_id)
                ->where('id', $reset->customer_id)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();

            if (! $customer instanceof Customer) {
                return ['error' => 'authentication_required'];
            }

            Customer::query()
                ->where('id', $customer->id)
                ->update([
                    'password_hash' => Hash::make($password),
                    'updated_at' => now(),
                ]);

            CustomerPasswordResetRequest::query()
                ->where('id', $reset->id)
                ->update([
                    'status' => 'consumed',
                    'consumed_at' => now(),
                    'metadata_json' => json_encode(array_merge($reset->metadata_json ?? [], [
                        'consumed_ip' => $request->ip(),
                        'consumed_user_agent' => $request->userAgent(),
                        'source' => $payload['source'] ?? 'reset_link',
                    ]), JSON_THROW_ON_ERROR),
                    'updated_at' => now(),
                ]);

            $this->revokeCustomerSessions((string) $customer->id);
            DB::afterCommit(fn () => $this->customerNotificationEvents->passwordChanged(
                (string) $customer->tenant_id,
                (string) $customer->id,
                (string) $reset->id,
            ));

            return [
                'resource' => [
                    'status' => 'password_reset',
                    'message' => 'Password has been reset.',
                ],
                'status' => 200,
            ];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function resetPasswordForVerifiedPhone(string $tenantId, string $phone, array $payload, Request $request): array
    {
        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        $phone = $this->normalizePhone($phone);
        $password = (string) ($payload['password'] ?? '');

        if ($phone === null || $password === '') {
            return ['error' => 'authentication_required'];
        }

        return DB::transaction(function () use ($tenantId, $phone, $password, $request): array {
            $customer = Customer::query()
                ->where('tenant_id', $tenantId)
                ->where('phone', $phone)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();

            if (! $customer instanceof Customer) {
                return ['error' => 'authentication_required'];
            }

            Customer::query()
                ->where('id', $customer->id)
                ->update([
                    'password_hash' => Hash::make($password),
                    'updated_at' => now(),
                ]);

            $resetRequestId = 'cpr_'.Str::ulid()->toBase32();
            CustomerPasswordResetRequest::query()->create([
                'id' => $resetRequestId,
                'tenant_id' => $tenantId,
                'customer_id' => (string) $customer->id,
                'channel' => 'sms_otp',
                'status' => 'consumed',
                'requested_identifier' => $phone,
                'phone' => $phone,
                'email' => $customer->email,
                'reset_token_hash' => null,
                'link_issued_at' => null,
                'expires_at' => null,
                'consumed_at' => now(),
                'issued_by_admin_id' => null,
                'requested_ip' => $request->ip(),
                'requested_user_agent' => $request->userAgent(),
                'metadata_json' => [
                    'source' => 'sms_otp',
                    'consumed_ip' => $request->ip(),
                    'consumed_user_agent' => $request->userAgent(),
                ],
            ]);

            $this->revokeCustomerSessions((string) $customer->id);
            DB::afterCommit(fn () => $this->customerNotificationEvents->passwordChanged(
                $tenantId,
                (string) $customer->id,
                $resetRequestId,
            ));

            return [
                'resource' => [
                    'status' => 'password_reset',
                    'message' => 'Password has been reset.',
                ],
                'status' => 200,
            ];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>}
     */
    public function issueLineResetToken(string $tenantId, string $lineUserId, Request $request): array
    {
        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        $identity = CustomerLineIdentity::query()
            ->where('tenant_id', $tenantId)
            ->where('line_user_id', $lineUserId)
            ->first();

        if (! $identity instanceof CustomerLineIdentity) {
            return [
                'error' => 'line_identity_not_linked',
                'details' => ['reason' => 'LINE account is not linked to any customer account.'],
            ];
        }

        $customer = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $identity->customer_id)
            ->where('status', 'active')
            ->first();

        if (! $customer instanceof Customer) {
            return ['error' => 'authentication_required'];
        }

        $reset = CustomerPasswordResetRequest::query()->create([
            'id' => 'cpr_'.Str::ulid()->toBase32(),
            'tenant_id' => $tenantId,
            'customer_id' => (string) $customer->id,
            'channel' => 'line_login',
            'status' => 'submitted',
            'requested_identifier' => 'LINE:'.$lineUserId,
            'phone' => $customer->phone,
            'email' => $customer->email,
            'requested_ip' => $request->ip(),
            'requested_user_agent' => $request->userAgent(),
            'metadata_json' => [
                'line_user_id' => $lineUserId,
                'line_display_name' => $identity->display_name,
            ],
        ]);

        $issued = $this->issueTokenForRequest(
            reset: $reset,
            customer: $customer,
            issuedByAdminId: null,
            request: $request,
        );

        return [
            'resource' => [
                'password_reset_ready' => true,
                'password_reset_token' => $issued['reset_token'],
                'expires_at' => $issued['expires_at'],
                'customer' => [
                    'name' => $customer->name,
                    'phone' => $customer->phone,
                ],
            ],
            'status' => 200,
        ];
    }

    private function issueTokenForRequest(
        CustomerPasswordResetRequest $reset,
        Customer $customer,
        ?string $issuedByAdminId,
        Request $request,
    ): array {
        $token = $this->newToken();
        $expiresAt = now()->addMinutes(self::RESET_TTL_MINUTES);
        $resetPath = '/reset-password?token='.urlencode($token);
        $resetUrl = $this->customerBaseUrl((string) $reset->tenant_id).$resetPath;

        CustomerPasswordResetRequest::query()
            ->where('id', $reset->id)
            ->update([
                'customer_id' => (string) $customer->id,
                'status' => 'link_issued',
                'reset_token_hash' => $this->hashToken($token),
                'link_issued_at' => now(),
                'expires_at' => $expiresAt,
                'issued_by_admin_id' => $issuedByAdminId,
                'metadata_json' => json_encode(array_merge($reset->metadata_json ?? [], [
                    'issued_ip' => $request->ip(),
                    'issued_user_agent' => $request->userAgent(),
                    'reset_path' => $resetPath,
                ]), JSON_THROW_ON_ERROR),
                'updated_at' => now(),
            ]);

        return [
            'id' => (string) $reset->id,
            'status' => 'link_issued',
            'customer' => [
                'id' => (string) $customer->id,
                'customer_no' => $customer->customer_no,
                'name' => $customer->name,
                'phone' => $customer->phone,
                'email' => $customer->email,
            ],
            'reset_token' => $token,
            'reset_url' => $resetUrl,
            'reset_path' => $resetPath,
            'expires_at' => $expiresAt->toIso8601String(),
        ];
    }

    private function customerBaseUrl(string $tenantId): string
    {
        $host = DB::table('partner_tenant_domains')
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->orderByDesc('is_primary')
            ->value('host');

        if (! is_string($host) || trim($host) === '') {
            return '';
        }

        $host = trim($host);
        $scheme = str_contains($host, 'localhost') || str_ends_with($host, '.test') ? 'http' : 'https';

        return $scheme.'://'.$host;
    }

    private function revokeCustomerSessions(string $customerId): void
    {
        CustomerAuthSession::query()
            ->where('customer_id', $customerId)
            ->whereNull('revoked_at')
            ->update([
                'revoked_at' => now(),
                'updated_at' => now(),
            ]);
    }

    private function tenantRequestResource(object $row): array
    {
        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'customer_id' => $row->customer_id,
            'customer' => [
                'id' => $row->customer_id,
                'customer_no' => $row->customer_no,
                'name' => $row->customer_name,
                'phone' => $row->customer_phone,
                'email' => $row->customer_email,
            ],
            'channel' => $row->channel,
            'status' => $row->status,
            'requested_identifier' => $row->requested_identifier,
            'phone' => $row->phone,
            'email' => $row->email,
            'link_issued_at' => $this->dateTimeString($row->link_issued_at),
            'expires_at' => $this->dateTimeString($row->expires_at),
            'consumed_at' => $this->dateTimeString($row->consumed_at),
            'issued_by' => [
                'id' => $row->issued_by_admin_id,
                'name' => $row->issued_by_name,
                'email' => $row->issued_by_email,
            ],
            'created_at' => $this->dateTimeString($row->created_at),
            'updated_at' => $this->dateTimeString($row->updated_at),
        ];
    }

    private function dateTimeString(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        return method_exists($value, 'toIso8601String') ? $value->toIso8601String() : (string) $value;
    }

    private function normalizePhone(mixed $value): ?string
    {
        $phone = preg_replace('/\D+/', '', (string) $value);

        if (! is_string($phone) || $phone === '') {
            return null;
        }

        if (str_starts_with($phone, '66') && strlen($phone) === 11) {
            $phone = '0'.substr($phone, 2);
        }

        return strlen($phone) >= 9 && strlen($phone) <= 10 ? $phone : null;
    }

    private function normalizeEmail(mixed $value): ?string
    {
        $email = strtolower(trim((string) $value));

        return $email === '' ? null : $email;
    }

    private function newToken(): string
    {
        return 'cpr_'.bin2hex(random_bytes(32));
    }

    private function hashToken(string $token): string
    {
        return hash('sha256', $token);
    }

    /**
     * @return array{error: string, details: array<string, string>}
     */
    private function storageUnavailable(): array
    {
        return [
            'error' => 'storage_unavailable',
            'details' => [
                'resource' => self::TABLE,
                'reason' => 'password_reset_storage_not_migrated',
            ],
        ];
    }
}

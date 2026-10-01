<?php

namespace App\Shared\Auth;

use App\Models\Customer;
use App\Models\CustomerAuthSession;
use App\Modules\Auth\Services\CustomerAuthService;

class CustomerSessionResolver
{
    /**
     * @var array{code: string, message: string, details: array<string, mixed>}|null
     */
    private ?array $failure = null;

    public function __construct(private readonly CustomerSuspensionService $customerSuspensions)
    {
    }

    public function accessTokenTenantId(?string $accessToken): ?string
    {
        if ($accessToken === null || $accessToken === '') {
            return null;
        }

        $tenantId = CustomerAuthSession::where('access_token_hash', hash('sha256', $accessToken))
            ->value('tenant_id');

        return $tenantId === null ? null : (string) $tenantId;
    }

    public function resolveAccessToken(?string $accessToken, ?string $expectedTenantId = null): ?CustomerSessionContext
    {
        $this->failure = null;

        if ($accessToken === null || $accessToken === '') {
            return null;
        }

        $accessTokenHash = hash('sha256', $accessToken);
        $session = CustomerAuthSession::where('access_token_hash', $accessTokenHash)
            ->whereNull('revoked_at')
            ->where('access_expires_at', '>', now())
            ->first();

        if ($session === null) {
            $revokedSession = CustomerAuthSession::query()
                ->where('access_token_hash', $accessTokenHash)
                ->whereNotNull('revoked_at')
                ->when(
                    $expectedTenantId !== null,
                    fn ($query) => $query->where('tenant_id', $expectedTenantId),
                )
                ->first();

            if ($revokedSession instanceof CustomerAuthSession
                && $revokedSession->revoked_reason === CustomerAuthService::REVOKED_REASON_REPLACED_BY_NEW_LOGIN) {
                $this->failure = [
                    'code' => 'customer_session_replaced',
                    'message' => 'This account signed in on a new device. The previous device was signed out.',
                    'details' => [
                        'replacement_session_id' => $revokedSession->replaced_by_session_id,
                        'replaced_at' => $revokedSession->revoked_at?->toISOString(),
                    ],
                ];
            }

            return null;
        }

        if ($expectedTenantId !== null && (string) $session->tenant_id !== $expectedTenantId) {
            return null;
        }

        $customer = Customer::whereKey($session->customer_id)
            ->where('tenant_id', $session->tenant_id)
            ->first();

        if ($customer === null || $this->customerSuspensions->isSuspended($customer) || (string) $customer->status !== 'active') {
            return null;
        }

        CustomerAuthSession::query()->where('id', $session->id)->update([
            'last_used_at' => now(),
            'updated_at' => now(),
        ]);

        return new CustomerSessionContext(
            session: [
                'id' => (string) $session->id,
                'tenant_id' => (string) $session->tenant_id,
                'customer_id' => (string) $session->customer_id,
                'pin_verified_at' => $session->pin_verified_at,
                'pin_verified' => $session->pin_verified_at !== null,
                'activation_required' => (bool) ($session->activation_required ?? false),
            ],
            customer: [
                'id' => (string) $customer->id,
                'tenant_id' => (string) $customer->tenant_id,
                'phone' => $customer->phone,
                'name' => $customer->name,
                'email' => $customer->email ?? null,
                'avatar_url' => $customer->avatar_url ?? null,
                'status' => (string) $customer->status,
                'preferred_locale' => $customer->preferred_locale ?? null,
                'has_pin' => is_string($customer->pin_hash) && $customer->pin_hash !== '',
            ],
        );
    }

    /**
     * @return array{code: string, message: string, details: array<string, mixed>}|null
     */
    public function failure(): ?array
    {
        return $this->failure;
    }

    /**
     * @return array<string, mixed>|null
     */
    public function suspendedCustomerForAccessToken(?string $accessToken, ?string $expectedTenantId = null): ?array
    {
        if ($accessToken === null || $accessToken === '') {
            return null;
        }

        $session = CustomerAuthSession::where('access_token_hash', hash('sha256', $accessToken))
            ->whereNull('revoked_at')
            ->where('access_expires_at', '>', now())
            ->first();

        if ($session === null) {
            return null;
        }

        if ($expectedTenantId !== null && (string) $session->tenant_id !== $expectedTenantId) {
            return null;
        }

        $customer = Customer::whereKey($session->customer_id)
            ->where('tenant_id', $session->tenant_id)
            ->first();

        if ($customer === null || ! $this->customerSuspensions->isSuspended($customer)) {
            return null;
        }

        return $this->customerSuspensions->payload($customer);
    }
}

<?php

namespace App\Shared\Auth;

use App\Models\Customer;
use App\Models\CustomerAuthSession;
use Illuminate\Support\Facades\DB;

class CustomerSessionResolver
{
    public function accessTokenTenantId(?string $accessToken): ?string
    {
        if ($accessToken === null || $accessToken === '') {
            return null;
        }

        $tenantId = CustomerAuthSession::where('access_token_hash', hash('sha256', $accessToken))
            ->whereNull('revoked_at')
            ->where('access_expires_at', '>', now())
            ->value('tenant_id');

        return $tenantId === null ? null : (string) $tenantId;
    }

    public function resolveAccessToken(?string $accessToken, ?string $expectedTenantId = null): ?CustomerSessionContext
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
            ->where('status', 'active')
            ->first();

        if ($customer === null) {
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
            ],
            customer: [
                'id' => (string) $customer->id,
                'tenant_id' => (string) $customer->tenant_id,
                'phone' => $customer->phone,
                'name' => $customer->name,
                'email' => $customer->email ?? null,
                'avatar_url' => $customer->avatar_url ?? null,
                'status' => (string) $customer->status,
                'has_pin' => is_string($customer->pin_hash) && $customer->pin_hash !== '',
            ],
        );
    }
}

<?php

namespace App\Shared\Auth;

class CustomerSessionContext
{
    /**
     * @param array<string, mixed> $session
     * @param array<string, mixed> $customer
     */
    public function __construct(
        public readonly array $session,
        public readonly array $customer,
    ) {
    }

    public function tenantId(): string
    {
        return (string) $this->session['tenant_id'];
    }

    public function customerId(): string
    {
        return (string) $this->session['customer_id'];
    }

    public function hasPin(): bool
    {
        return (bool) ($this->customer['has_pin'] ?? false);
    }

    public function pinVerified(): bool
    {
        return (bool) ($this->session['pin_verified'] ?? false);
    }
}

<?php

namespace App\Shared\Auth;

class AdminSessionContext
{
    /**
     * @param array<string, mixed> $session
     * @param array<string, mixed> $adminUser
     * @param array<int, array<string, mixed>> $scopes
     */
    public function __construct(
        public readonly array $session,
        public readonly array $adminUser,
        public readonly array $scopes,
    ) {
    }

    public function activeScope(): string
    {
        return (string) $this->session['scope_type'];
    }

    public function activeScopeId(): ?string
    {
        return $this->session['scope_id'] ?? null;
    }

    public function activeTenantId(): ?string
    {
        return $this->session['tenant_id'] ?? null;
    }
}

<?php

namespace App\Shared\Tenancy;

use RuntimeException;

class TenantContext
{
    private ?string $partnerId = null;

    private ?string $tenantId = null;

    private ?string $domainId = null;

    private ?string $host = null;

    public function set(string $partnerId, string $tenantId, string $domainId, string $host): void
    {
        $this->partnerId = $partnerId;
        $this->tenantId = $tenantId;
        $this->domainId = $domainId;
        $this->host = $host;
    }

    public function clear(): void
    {
        $this->partnerId = null;
        $this->tenantId = null;
        $this->domainId = null;
        $this->host = null;
    }

    public function hasTenant(): bool
    {
        return $this->tenantId !== null;
    }

    public function partnerId(): ?string
    {
        return $this->partnerId;
    }

    public function tenantId(): ?string
    {
        return $this->tenantId;
    }

    public function domainId(): ?string
    {
        return $this->domainId;
    }

    public function host(): ?string
    {
        return $this->host;
    }

    public function requireTenantId(): string
    {
        if ($this->tenantId === null) {
            throw new RuntimeException('Tenant context has not been resolved.');
        }

        return $this->tenantId;
    }
}

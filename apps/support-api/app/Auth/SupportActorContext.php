<?php

namespace App\Auth;

use App\Models\SupportActor;

class SupportActorContext
{
    /**
     * @param array<string, mixed> $claims
     */
    public function __construct(
        public readonly SupportActor $actor,
        public readonly array $claims,
    ) {
    }

    public function tenantId(): string
    {
        return (string) $this->actor->tenant_id;
    }

    public function actorType(): string
    {
        return (string) $this->actor->actor_type;
    }

    public function externalId(): string
    {
        return (string) $this->actor->external_id;
    }

    public function isCustomer(): bool
    {
        return $this->actorType() === 'customer';
    }

    public function isAdmin(): bool
    {
        return $this->actorType() === 'admin';
    }

    public function hasPermission(string $permission): bool
    {
        return in_array($permission, $this->permissions(), true);
    }

    /**
     * @return array<int, string>
     */
    public function permissions(): array
    {
        return array_values(array_filter(
            is_array($this->actor->permissions_json) ? $this->actor->permissions_json : [],
            fn (mixed $value): bool => is_string($value) && $value !== '',
        ));
    }
}

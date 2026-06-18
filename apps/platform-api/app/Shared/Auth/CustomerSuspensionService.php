<?php

namespace App\Shared\Auth;

use App\Models\Customer;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Schema;

class CustomerSuspensionService
{
    public function storageReady(): bool
    {
        return Schema::hasColumn('customers', 'suspended_at')
            && Schema::hasColumn('customers', 'suspended_until')
            && Schema::hasColumn('customers', 'suspension_reason')
            && Schema::hasColumn('customers', 'suspended_by_admin_id');
    }

    public function refreshExpired(Customer $customer): Customer
    {
        if ((string) $customer->status !== 'suspended' || ! $this->storageReady()) {
            return $customer;
        }

        $suspendedUntil = $this->dateOrNull($customer->getAttribute('suspended_until'));

        if ($suspendedUntil === null || $suspendedUntil->isFuture()) {
            return $customer;
        }

        $customer->forceFill([
            'status' => 'active',
            'suspended_at' => null,
            'suspended_until' => null,
            'suspension_reason' => null,
            'suspended_by_admin_id' => null,
            'updated_at' => now(),
        ])->save();

        return $customer->refresh();
    }

    public function isSuspended(Customer $customer): bool
    {
        $this->refreshExpired($customer);

        return (string) $customer->status === 'suspended';
    }

    /**
     * @return array<string, mixed>
     */
    public function payload(Customer $customer): array
    {
        $suspendedUntil = $this->dateOrNull($customer->getAttribute('suspended_until'));
        $suspendedAt = $this->dateOrNull($customer->getAttribute('suspended_at'));

        return [
            'reason' => trim((string) ($customer->getAttribute('suspension_reason') ?? '')),
            'suspended_at' => $suspendedAt?->toIso8601String(),
            'suspended_until' => $suspendedUntil?->toIso8601String(),
            'is_permanent' => $suspendedUntil === null,
        ];
    }

    private function dateOrNull(mixed $value): ?Carbon
    {
        if ($value instanceof Carbon) {
            return $value;
        }

        if ($value instanceof \DateTimeInterface) {
            return Carbon::instance($value);
        }

        if (is_string($value) && trim($value) !== '') {
            return Carbon::parse($value);
        }

        return null;
    }
}

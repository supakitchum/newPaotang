<?php

namespace App\Models\Concerns;

use App\Models\PartnerTenant;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

trait BelongsToTenant
{
    public function scopeForTenant(Builder $query, string $tenantId): Builder
    {
        return $query->where($this->getTable().'.tenant_id', $tenantId);
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(PartnerTenant::class, 'tenant_id');
    }
}

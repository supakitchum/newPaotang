<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class PartnerTenant extends BaseModel
{
    protected $table = 'partner_tenants';

    protected $fillable = [
        'id',
        'partner_id',
        'code',
        'name',
        'status',
        'created_at',
        'updated_at',
    ];

    public function scopeForTenant(Builder $query, string $tenantId): Builder
    {
        return $query->where($this->getTable().'.id', $tenantId);
    }

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function domains(): HasMany
    {
        return $this->hasMany(PartnerTenantDomain::class, 'tenant_id');
    }

    public function settings(): HasOne
    {
        return $this->hasOne(PartnerTenantSetting::class, 'tenant_id');
    }

    public function theme(): HasOne
    {
        return $this->hasOne(PartnerTenantTheme::class, 'tenant_id');
    }

    public function customers(): HasMany
    {
        return $this->hasMany(Customer::class, 'tenant_id');
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'tenant_id');
    }

    public function wallets(): HasMany
    {
        return $this->hasMany(Wallet::class, 'tenant_id');
    }

    public function agents(): HasMany
    {
        return $this->hasMany(Agent::class, 'tenant_id');
    }

    public function affiliateAccounts(): HasMany
    {
        return $this->hasMany(AffiliateAccount::class, 'tenant_id');
    }

    public function reportExportJobs(): HasMany
    {
        return $this->hasMany(ReportExportJob::class, 'tenant_id');
    }

    public function settlements(): HasMany
    {
        return $this->hasMany(PartnerSettlement::class, 'tenant_id');
    }
}

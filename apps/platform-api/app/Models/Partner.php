<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Partner extends BaseModel
{
    protected $table = 'partners';

    protected $fillable = [
        'id',
        'code',
        'name',
        'type',
        'status',
        'stock_percent_basis_points',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'stock_percent_basis_points' => 'integer',
    ];

    public function tenants(): HasMany
    {
        return $this->hasMany(PartnerTenant::class, 'partner_id');
    }

    public function domains(): HasMany
    {
        return $this->hasMany(PartnerTenantDomain::class, 'partner_id');
    }

    public function apiClients(): HasMany
    {
        return $this->hasMany(PartnerApiClient::class, 'partner_id');
    }

    public function quotas(): HasMany
    {
        return $this->hasMany(PartnerQuota::class, 'partner_id');
    }

    public function stockAllocations(): HasMany
    {
        return $this->hasMany(PartnerStockAllocation::class, 'partner_id');
    }

    public function lotteryBrandingAssetSets(): HasMany
    {
        return $this->hasMany(PartnerLotteryBrandingAssetSet::class, 'partner_id');
    }

    public function monitoringProfile(): HasOne
    {
        return $this->hasOne(PartnerMonitoringProfile::class, 'partner_id');
    }

    public function centralMaintenanceSetting(): HasOne
    {
        return $this->hasOne(PartnerCentralMaintenanceSetting::class, 'partner_id');
    }

    public function settlements(): HasMany
    {
        return $this->hasMany(PartnerSettlement::class, 'partner_id');
    }
}

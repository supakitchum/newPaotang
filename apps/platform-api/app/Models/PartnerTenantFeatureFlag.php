<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class PartnerTenantFeatureFlag extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_feature_flags';

    protected $fillable = [
        'id',
        'tenant_id',
        'feature_key',
        'enabled',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'enabled' => 'boolean',
    ];
}

<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class PartnerTenantDeploymentProfile extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_deployment_profiles';

    protected $fillable = [
        'id',
        'tenant_id',
        'mode',
        'status',
        'runtime_region',
        'resource_pool',
        'created_at',
        'updated_at',
    ];
}

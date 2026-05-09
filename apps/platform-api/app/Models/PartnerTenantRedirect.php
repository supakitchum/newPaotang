<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class PartnerTenantRedirect extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_redirects';

    protected $fillable = [
        'id',
        'tenant_id',
        'source_path',
        'target_url',
        'status_code',
        'status',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'status_code' => 'integer',
        'metadata_json' => 'array',
    ];
}

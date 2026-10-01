<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class PartnerTenantSeoPage extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_seo_pages';

    protected $fillable = [
        'id',
        'tenant_id',
        'path',
        'title',
        'description',
        'canonical_url',
        'robots',
        'og_image_url',
        'status',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'metadata_json' => 'array',
    ];
}

<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class PartnerTenantSeoSetting extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_seo_settings';

    protected $fillable = [
        'id',
        'tenant_id',
        'status',
        'default_title',
        'title_template',
        'default_description',
        'default_keywords_json',
        'robots_default',
        'canonical_base_url',
        'og_image_url',
        'config_version',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'default_keywords_json' => 'array',
        'config_version' => 'integer',
    ];
}

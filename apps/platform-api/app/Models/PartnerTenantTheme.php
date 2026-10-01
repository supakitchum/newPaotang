<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class PartnerTenantTheme extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_themes';

    protected $fillable = [
        'id',
        'tenant_id',
        'logo_url',
        'favicon_url',
        'og_image_url',
        'primary_color',
        'secondary_color',
        'accent_color',
        'background_color',
        'text_color',
        'font_family',
        'config_version',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'config_version' => 'integer',
    ];
}

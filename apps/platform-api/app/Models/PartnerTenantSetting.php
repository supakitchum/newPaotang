<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class PartnerTenantSetting extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_settings';

    protected $fillable = [
        'id',
        'tenant_id',
        'site_name',
        'site_name_i18n',
        'display_name',
        'display_name_i18n',
        'locale',
        'timezone',
        'support_email',
        'support_phone',
        'default_title',
        'title_template',
        'default_description',
        'default_keywords_json',
        'robots_default',
        'sitemap_enabled',
        'robots_enabled',
        'maintenance_active',
        'maintenance_mode',
        'maintenance_message',
        'maintenance_message_i18n',
        'maintenance_expected_end_at',
        'maintenance_retry_after_seconds',
        'maintenance_allowed_routes_json',
        'maintenance_blocked_route_patterns_json',
        'api_base_url',
        'realtime_url',
        'asset_cdn_base_url',
        'waiting_result_youtube_url',
        'terms_content',
        'terms_content_i18n',
        'config_version',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'default_keywords_json' => 'array',
        'sitemap_enabled' => 'boolean',
        'robots_enabled' => 'boolean',
        'maintenance_active' => 'boolean',
        'maintenance_expected_end_at' => 'datetime',
        'maintenance_retry_after_seconds' => 'integer',
        'maintenance_allowed_routes_json' => 'array',
        'maintenance_blocked_route_patterns_json' => 'array',
        'site_name_i18n' => 'array',
        'display_name_i18n' => 'array',
        'maintenance_message_i18n' => 'array',
        'terms_content_i18n' => 'array',
        'config_version' => 'integer',
    ];
}

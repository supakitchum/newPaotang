<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantLineMessageTemplate extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_line_message_templates';

    protected $fillable = [
        'id',
        'tenant_id',
        'event_key',
        'enabled',
        'message_type',
        'title',
        'body_text',
        'flex_json',
        'variables_json',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'enabled' => 'boolean',
        'flex_json' => 'array',
        'variables_json' => 'array',
        'metadata_json' => 'array',
    ];
}

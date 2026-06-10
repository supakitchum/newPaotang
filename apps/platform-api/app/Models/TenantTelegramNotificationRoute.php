<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantTelegramNotificationRoute extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_telegram_notification_routes';

    protected $fillable = [
        'id',
        'tenant_id',
        'event_key',
        'chat_id',
        'enabled',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'enabled' => 'boolean',
        'metadata_json' => 'array',
    ];
}

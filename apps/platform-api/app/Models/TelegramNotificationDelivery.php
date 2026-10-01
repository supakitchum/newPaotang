<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TelegramNotificationDelivery extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'telegram_notification_deliveries';

    protected $fillable = [
        'id',
        'tenant_id',
        'event_key',
        'chat_id',
        'source_type',
        'source_id',
        'status',
        'attempts',
        'next_retry_at',
        'sent_at',
        'last_error',
        'message_text',
        'telegram_response_json',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'attempts' => 'integer',
        'next_retry_at' => 'datetime',
        'sent_at' => 'datetime',
        'telegram_response_json' => 'array',
        'metadata_json' => 'array',
    ];
}

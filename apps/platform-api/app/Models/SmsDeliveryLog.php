<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class SmsDeliveryLog extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'sms_delivery_logs';

    protected $fillable = [
        'id',
        'tenant_id',
        'provider_id',
        'provider',
        'purpose',
        'phone_masked',
        'status',
        'http_status',
        'latency_ms',
        'provider_message_id',
        'error_message',
        'request_json',
        'response_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'http_status' => 'integer',
        'latency_ms' => 'integer',
        'request_json' => 'array',
        'response_json' => 'array',
    ];
}

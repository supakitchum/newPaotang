<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LineNotificationDelivery extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'line_notification_deliveries';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'line_user_id',
        'event_key',
        'source_type',
        'source_id',
        'status',
        'attempts',
        'next_retry_at',
        'sent_at',
        'last_error',
        'message_json',
        'line_response_json',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'attempts' => 'integer',
        'next_retry_at' => 'datetime',
        'sent_at' => 'datetime',
        'message_json' => 'array',
        'line_response_json' => 'array',
        'metadata_json' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }
}

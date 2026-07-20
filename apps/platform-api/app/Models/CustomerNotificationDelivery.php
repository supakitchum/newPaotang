<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerNotificationDelivery extends BaseModel
{
    use BelongsToTenant;

    protected $fillable = [
        'id',
        'tenant_id',
        'recipient_id',
        'device_id',
        'status',
        'attempts',
        'provider_message_id',
        'last_error_code',
        'next_retry_at',
        'sent_at',
        'failed_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'attempts' => 'integer',
        'next_retry_at' => 'datetime',
        'sent_at' => 'datetime',
        'failed_at' => 'datetime',
    ];

    public function recipient(): BelongsTo
    {
        return $this->belongsTo(CustomerNotificationRecipient::class, 'recipient_id');
    }

    public function device(): BelongsTo
    {
        return $this->belongsTo(CustomerPushDevice::class, 'device_id');
    }
}

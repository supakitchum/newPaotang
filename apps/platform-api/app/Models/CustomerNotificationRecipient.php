<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CustomerNotificationRecipient extends BaseModel
{
    use BelongsToTenant;

    protected $fillable = [
        'id',
        'tenant_id',
        'notification_id',
        'customer_id',
        'read_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'read_at' => 'datetime',
    ];

    public function notification(): BelongsTo
    {
        return $this->belongsTo(CustomerNotification::class, 'notification_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function deliveries(): HasMany
    {
        return $this->hasMany(CustomerNotificationDelivery::class, 'recipient_id');
    }
}

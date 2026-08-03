<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CustomerPushDevice extends BaseModel
{
    use BelongsToTenant;

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'installation_id',
        'platform',
        'fcm_token_encrypted',
        'token_hash',
        'locale',
        'app_version',
        'device_name',
        'metadata_json',
        'last_seen_at',
        'revoked_at',
        'revoked_reason',
        'created_at',
        'updated_at',
    ];

    protected $hidden = ['fcm_token_encrypted', 'token_hash'];

    protected $casts = [
        'fcm_token_encrypted' => 'encrypted',
        'metadata_json' => 'array',
        'last_seen_at' => 'datetime',
        'revoked_at' => 'datetime',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function deliveries(): HasMany
    {
        return $this->hasMany(CustomerNotificationDelivery::class, 'device_id');
    }
}

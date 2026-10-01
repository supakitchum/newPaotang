<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerBiometricDevice extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_biometric_devices';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'device_id',
        'platform',
        'device_name',
        'algorithm',
        'public_key_pem',
        'status',
        'registered_at',
        'last_used_at',
        'revoked_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'public_key_pem',
    ];

    protected $casts = [
        'registered_at' => 'datetime',
        'last_used_at' => 'datetime',
        'revoked_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }
}

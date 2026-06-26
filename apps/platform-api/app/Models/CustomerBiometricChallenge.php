<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerBiometricChallenge extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_biometric_challenges';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'biometric_device_id',
        'purpose',
        'challenge',
        'status',
        'expires_at',
        'verified_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'verified_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function device(): BelongsTo
    {
        return $this->belongsTo(CustomerBiometricDevice::class, 'biometric_device_id');
    }
}

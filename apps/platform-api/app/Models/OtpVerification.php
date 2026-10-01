<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class OtpVerification extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'otp_verifications';

    protected $fillable = [
        'id',
        'tenant_id',
        'provider_id',
        'provider',
        'purpose',
        'phone',
        'phone_normalized',
        'otp_hash',
        'verification_token_hash',
        'status',
        'attempts',
        'max_attempts',
        'expires_at',
        'cooldown_until',
        'verified_at',
        'consumed_at',
        'requested_ip',
        'requested_user_agent',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'otp_hash',
        'verification_token_hash',
    ];

    protected $casts = [
        'attempts' => 'integer',
        'max_attempts' => 'integer',
        'expires_at' => 'datetime',
        'cooldown_until' => 'datetime',
        'verified_at' => 'datetime',
        'consumed_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

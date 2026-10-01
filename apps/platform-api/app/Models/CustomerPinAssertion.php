<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class CustomerPinAssertion extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_pin_assertions';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'source_type',
        'source_id',
        'token_hash',
        'purpose',
        'status',
        'expires_at',
        'consumed_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'token_hash',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

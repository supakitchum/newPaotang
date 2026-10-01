<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerPasskeyChallenge extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_passkey_challenges';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'ceremony',
        'rp_id',
        'allowed_origins_json',
        'options_json',
        'status',
        'expires_at',
        'consumed_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'allowed_origins_json' => 'array',
        'options_json' => 'array',
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }
}

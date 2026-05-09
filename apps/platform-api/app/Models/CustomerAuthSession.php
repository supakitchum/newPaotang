<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerAuthSession extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_auth_sessions';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'access_token_hash',
        'access_expires_at',
        'revoked_at',
        'last_used_at',
        'created_at',
        'updated_at',
        'refresh_token_hash',
        'refresh_expires_at',
        'refreshed_from_id',
    ];

    protected $hidden = [
        'access_token_hash',
        'refresh_token_hash',
    ];

    protected $casts = [
        'access_expires_at' => 'datetime',
        'refresh_expires_at' => 'datetime',
        'revoked_at' => 'datetime',
        'last_used_at' => 'datetime',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }
}

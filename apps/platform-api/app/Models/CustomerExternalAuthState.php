<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerExternalAuthState extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_external_auth_states';

    protected $fillable = [
        'id',
        'tenant_id',
        'provider',
        'state_hash',
        'store_id',
        'status',
        'redirect_uri',
        'expires_at',
        'consumed_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'state_hash',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(PartnerTenant::class, 'tenant_id');
    }
}

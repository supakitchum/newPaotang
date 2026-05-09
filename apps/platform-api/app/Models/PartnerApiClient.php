<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerApiClient extends BaseModel
{
    protected $table = 'partner_api_clients';

    protected $fillable = [
        'id',
        'partner_id',
        'name',
        'client_key',
        'secret_hash',
        'status',
        'scopes_json',
        'last_used_at',
        'revoked_at',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'secret_hash',
    ];

    protected $casts = [
        'scopes_json' => 'array',
        'last_used_at' => 'datetime',
        'revoked_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}

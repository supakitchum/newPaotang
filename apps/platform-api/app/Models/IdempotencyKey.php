<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class IdempotencyKey extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'idempotency_keys';

    protected $fillable = [
        'id',
        'tenant_id',
        'actor_type',
        'actor_id',
        'route_key',
        'permission_code',
        'idempotency_key',
        'payload_hash',
        'response_body_json',
        'completed_at',
        'expires_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'response_status' => 'integer',
        'response_body_json' => 'array',
        'completed_at' => 'datetime',
        'expires_at' => 'datetime',
    ];
}

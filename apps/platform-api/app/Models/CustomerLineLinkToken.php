<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class CustomerLineLinkToken extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_line_link_tokens';

    protected $fillable = [
        'id',
        'tenant_id',
        'token_hash',
        'line_user_id',
        'display_name',
        'picture_url',
        'friend_flag',
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
        'friend_flag' => 'boolean',
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

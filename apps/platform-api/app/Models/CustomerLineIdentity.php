<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerLineIdentity extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_line_identities';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'line_user_id',
        'display_name',
        'picture_url',
        'friend_flag',
        'notification_enabled',
        'linked_at',
        'last_login_at',
        'last_friend_checked_at',
        'unreachable_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'friend_flag' => 'boolean',
        'notification_enabled' => 'boolean',
        'linked_at' => 'datetime',
        'last_login_at' => 'datetime',
        'last_friend_checked_at' => 'datetime',
        'unreachable_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }
}

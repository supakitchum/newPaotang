<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerPasswordResetRequest extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_password_reset_requests';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'channel',
        'status',
        'requested_identifier',
        'phone',
        'email',
        'reset_token_hash',
        'link_issued_at',
        'expires_at',
        'consumed_at',
        'issued_by_admin_id',
        'requested_ip',
        'requested_user_agent',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'reset_token_hash',
    ];

    protected $casts = [
        'link_issued_at' => 'datetime',
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function issuedBy(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'issued_by_admin_id');
    }
}

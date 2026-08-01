<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerAccountDeletionRequest extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_account_deletion_requests';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'status',
        'reason_code',
        'reason_detail',
        'idempotency_key',
        'payload_hash',
        'pin_verified_at',
        'otp_verified_at',
        'requested_at',
        'scheduled_for',
        'last_checked_at',
        'reminder_sent_at',
        'blocked_at',
        'cancelled_at',
        'completed_at',
        'blockers_json',
        'identity_snapshot_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'pin_verified_at' => 'datetime',
        'otp_verified_at' => 'datetime',
        'requested_at' => 'datetime',
        'scheduled_for' => 'datetime',
        'last_checked_at' => 'datetime',
        'reminder_sent_at' => 'datetime',
        'blocked_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'completed_at' => 'datetime',
        'blockers_json' => 'array',
        'identity_snapshot_json' => 'encrypted:array',
    ];

    protected $hidden = ['identity_snapshot_json', 'payload_hash', 'idempotency_key'];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AffiliatePayout extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_payouts';

    protected $fillable = [
        'id',
        'tenant_id',
        'affiliate_account_id',
        'status',
        'payout_method',
        'amount',
        'currency',
        'bank_account_json',
        'admin_note',
        'idempotency_key',
        'payload_hash',
        'requested_by_admin_id',
        'approved_by_admin_id',
        'approved_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'amount' => 'integer',
        'bank_account_json' => 'array',
        'approved_at' => 'datetime',
    ];

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }

    public function requestedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'requested_by_admin_id');
    }

    public function approvedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'approved_by_admin_id');
    }
}

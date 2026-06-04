<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ActivityClaim extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'activity_claims';

    protected $fillable = [
        'id',
        'tenant_id',
        'activity_award_id',
        'activity_id',
        'game_id',
        'customer_id',
        'wallet_id',
        'payout_ledger_id',
        'reference',
        'status',
        'payout_method',
        'claim_amount',
        'currency',
        'bank_account_json',
        'customer_note',
        'admin_note',
        'idempotency_key',
        'payload_hash',
        'reviewed_by_admin_id',
        'paid_by_admin_id',
        'submitted_at',
        'reviewed_at',
        'paid_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'claim_amount' => 'integer',
        'bank_account_json' => 'array',
        'submitted_at' => 'datetime',
        'reviewed_at' => 'datetime',
        'paid_at' => 'datetime',
    ];

    public function award(): BelongsTo
    {
        return $this->belongsTo(TenantActivityAward::class, 'activity_award_id');
    }

    public function activity(): BelongsTo
    {
        return $this->belongsTo(TenantActivity::class, 'activity_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class, 'wallet_id');
    }

    public function payoutLedger(): BelongsTo
    {
        return $this->belongsTo(WalletLedger::class, 'payout_ledger_id');
    }
}

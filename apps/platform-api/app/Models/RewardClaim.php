<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RewardClaim extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'reward_claims';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'ticket_id',
        'winning_ticket_id',
        'game_id',
        'wallet_id',
        'payout_ledger_id',
        'reference',
        'status',
        'payout_method',
        'prize_amount',
        'base_prize_amount',
        'adjustment_amount',
        'tenant_price_rule_id',
        'price_rule_snapshot_json',
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
        'prize_amount' => 'integer',
        'base_prize_amount' => 'integer',
        'adjustment_amount' => 'integer',
        'price_rule_snapshot_json' => 'array',
        'bank_account_json' => 'array',
        'submitted_at' => 'datetime',
        'reviewed_at' => 'datetime',
        'paid_at' => 'datetime',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function ticket(): BelongsTo
    {
        return $this->belongsTo(Ticket::class, 'ticket_id');
    }

    public function winningTicket(): BelongsTo
    {
        return $this->belongsTo(WinningTicket::class, 'winning_ticket_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class, 'wallet_id');
    }

    public function payoutLedger(): BelongsTo
    {
        return $this->belongsTo(WalletLedger::class, 'payout_ledger_id');
    }

    public function reviewedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'reviewed_by_admin_id');
    }

    public function paidByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'paid_by_admin_id');
    }
}

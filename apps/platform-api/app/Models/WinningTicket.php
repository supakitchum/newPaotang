<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class WinningTicket extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'winning_tickets';

    protected $fillable = [
        'id',
        'tenant_id',
        'game_id',
        'ticket_id',
        'reward_result_id',
        'reward_prize_id',
        'prize_type',
        'prize_number',
        'amount',
        'base_amount',
        'adjustment_amount',
        'tenant_price_rule_id',
        'price_rule_snapshot_json',
        'currency',
        'status',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'amount' => 'integer',
        'base_amount' => 'integer',
        'adjustment_amount' => 'integer',
        'price_rule_snapshot_json' => 'array',
    ];

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function ticket(): BelongsTo
    {
        return $this->belongsTo(Ticket::class, 'ticket_id');
    }

    public function rewardResult(): BelongsTo
    {
        return $this->belongsTo(RewardResult::class, 'reward_result_id');
    }

    public function rewardPrize(): BelongsTo
    {
        return $this->belongsTo(RewardPrize::class, 'reward_prize_id');
    }

    public function rewardClaims(): HasMany
    {
        return $this->hasMany(RewardClaim::class, 'winning_ticket_id');
    }
}

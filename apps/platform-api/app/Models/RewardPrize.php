<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class RewardPrize extends BaseModel
{
    protected $table = 'reward_prizes';

    protected $fillable = [
        'id',
        'reward_result_id',
        'game_id',
        'prize_type',
        'prize_number',
        'amount',
        'currency',
        'sort_order',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'amount' => 'integer',
        'sort_order' => 'integer',
    ];

    public function rewardResult(): BelongsTo
    {
        return $this->belongsTo(RewardResult::class, 'reward_result_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function winningTickets(): HasMany
    {
        return $this->hasMany(WinningTicket::class, 'reward_prize_id');
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class RewardCheckBatch extends BaseModel
{
    protected $table = 'reward_check_batches';

    protected $fillable = [
        'id',
        'reward_result_id',
        'game_id',
        'status',
        'chunk_count',
        'processed_ticket_count',
        'winning_count',
        'idempotency_key',
        'payload_hash',
        'started_at',
        'completed_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'chunk_count' => 'integer',
        'processed_ticket_count' => 'integer',
        'winning_count' => 'integer',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    public function rewardResult(): BelongsTo
    {
        return $this->belongsTo(RewardResult::class, 'reward_result_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(RewardCheckItem::class, 'reward_check_batch_id');
    }
}

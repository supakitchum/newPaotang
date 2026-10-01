<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class RewardResult extends BaseModel
{
    protected $table = 'reward_results';

    protected $fillable = [
        'id',
        'game_id',
        'status',
        'version',
        'summary_json',
        'created_by_admin_id',
        'verified_by_admin_id',
        'published_by_admin_id',
        'corrected_by_admin_id',
        'correction_note',
        'checked_at',
        'verified_at',
        'published_at',
        'corrected_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'version' => 'integer',
        'summary_json' => 'array',
        'checked_at' => 'datetime',
        'verified_at' => 'datetime',
        'published_at' => 'datetime',
        'corrected_at' => 'datetime',
    ];

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function prizes(): HasMany
    {
        return $this->hasMany(RewardPrize::class, 'reward_result_id');
    }

    public function checkBatches(): HasMany
    {
        return $this->hasMany(RewardCheckBatch::class, 'reward_result_id');
    }

    public function winningTickets(): HasMany
    {
        return $this->hasMany(WinningTicket::class, 'reward_result_id');
    }

    public function publishLogs(): HasMany
    {
        return $this->hasMany(RewardPublishLog::class, 'reward_result_id');
    }
}

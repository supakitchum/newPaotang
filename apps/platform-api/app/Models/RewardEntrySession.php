<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class RewardEntrySession extends BaseModel
{
    protected $table = 'reward_entry_sessions';

    protected $fillable = [
        'id',
        'game_id',
        'status',
        'expected_operators_json',
        'expected_operator_count',
        'submitted_count',
        'scraper_snapshot_json',
        'reward_result_id',
        'created_by_admin_id',
        'resolved_by_admin_id',
        'ready_at',
        'resolved_at',
        'cancelled_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'expected_operators_json' => 'array',
        'expected_operator_count' => 'integer',
        'submitted_count' => 'integer',
        'scraper_snapshot_json' => 'array',
        'ready_at' => 'datetime',
        'resolved_at' => 'datetime',
        'cancelled_at' => 'datetime',
    ];

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function submissions(): HasMany
    {
        return $this->hasMany(RewardEntrySubmission::class, 'session_id');
    }

    public function resolution(): HasOne
    {
        return $this->hasOne(RewardEntryResolution::class, 'session_id');
    }
}

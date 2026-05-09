<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RewardPublishLog extends BaseModel
{
    protected $table = 'reward_publish_logs';

    protected $fillable = [
        'id',
        'reward_result_id',
        'game_id',
        'reward_version',
        'published_by_admin_id',
        'payload_json',
        'published_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'reward_version' => 'integer',
        'payload_json' => 'array',
        'published_at' => 'datetime',
    ];

    public function rewardResult(): BelongsTo
    {
        return $this->belongsTo(RewardResult::class, 'reward_result_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function publishedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'published_by_admin_id');
    }
}

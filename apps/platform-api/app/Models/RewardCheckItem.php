<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RewardCheckItem extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'reward_check_items';

    protected $fillable = [
        'id',
        'reward_check_batch_id',
        'reward_result_id',
        'tenant_id',
        'cursor_from',
        'cursor_to',
        'status',
        'checked_count',
        'winning_count',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'checked_count' => 'integer',
        'winning_count' => 'integer',
    ];

    public function batch(): BelongsTo
    {
        return $this->belongsTo(RewardCheckBatch::class, 'reward_check_batch_id');
    }

    public function rewardResult(): BelongsTo
    {
        return $this->belongsTo(RewardResult::class, 'reward_result_id');
    }
}

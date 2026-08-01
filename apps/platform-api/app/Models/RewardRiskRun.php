<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class RewardRiskRun extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'reward_risk_runs';

    protected $fillable = [
        'id', 'tenant_id', 'game_id', 'reward_result_id', 'phase', 'reward_version',
        'source_hash', 'settings_snapshot_json', 'status', 'is_current',
        'evaluated_group_count', 'finding_count', 'total_purchase_amount',
        'total_prize_amount', 'currency', 'last_error', 'started_at',
        'completed_at', 'superseded_at',
    ];

    protected $casts = [
        'reward_version' => 'integer',
        'settings_snapshot_json' => 'array',
        'is_current' => 'boolean',
        'evaluated_group_count' => 'integer',
        'finding_count' => 'integer',
        'total_purchase_amount' => 'integer',
        'total_prize_amount' => 'integer',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'superseded_at' => 'datetime',
    ];
}

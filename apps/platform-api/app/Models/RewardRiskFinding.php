<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class RewardRiskFinding extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'reward_risk_findings';

    protected $fillable = [
        'id', 'run_id', 'tenant_id', 'game_id', 'customer_id', 'full_number',
        'prize_types_json', 'ticket_count', 'purchase_amount', 'prize_amount',
        'threshold_multiplier', 'threshold_amount', 'excess_amount', 'currency', 'status',
    ];

    protected $casts = [
        'prize_types_json' => 'array',
        'ticket_count' => 'integer',
        'purchase_amount' => 'integer',
        'prize_amount' => 'integer',
        'threshold_multiplier' => 'decimal:2',
        'threshold_amount' => 'integer',
        'excess_amount' => 'integer',
    ];
}

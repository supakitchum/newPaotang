<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class RewardRiskFindingTicket extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'reward_risk_finding_tickets';

    protected $fillable = [
        'id', 'finding_id', 'run_id', 'tenant_id', 'ticket_id',
        'winning_ticket_id', 'prize_type', 'prize_number', 'amount', 'currency',
    ];

    protected $casts = ['amount' => 'integer'];
}

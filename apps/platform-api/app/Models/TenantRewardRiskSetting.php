<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantRewardRiskSetting extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_reward_risk_settings';

    protected $fillable = [
        'id', 'tenant_id', 'enabled', 'monitored_prize_types_json',
        'threshold_multiplier', 'version', 'updated_by_admin_id',
    ];

    protected $casts = [
        'enabled' => 'boolean',
        'monitored_prize_types_json' => 'array',
        'threshold_multiplier' => 'decimal:2',
        'version' => 'integer',
    ];
}

<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantPriceRule extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_price_rules';

    protected $fillable = [
        'id',
        'tenant_id',
        'game_id',
        'code',
        'name',
        'rule_type',
        'price_amount',
        'currency',
        'status',
        'conditions_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'price_amount' => 'integer',
        'conditions_json' => 'array',
    ];
}

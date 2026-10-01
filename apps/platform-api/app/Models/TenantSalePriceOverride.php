<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantSalePriceOverride extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_sale_price_overrides';

    protected $fillable = [
        'id',
        'tenant_id',
        'partner_id',
        'game_id',
        'set_size',
        'price_amount',
        'currency',
        'status',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'set_size' => 'integer',
        'price_amount' => 'integer',
    ];
}

<?php

namespace App\Models;

class StockSupplyProfile extends BaseModel
{
    protected $table = 'stock_supply_profiles';

    protected $fillable = [
        'id',
        'game_id',
        'status',
        'seed',
        'base_count',
        'total_capacity',
        'set_distribution_json',
        'created_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'base_count' => 'integer',
        'total_capacity' => 'integer',
        'set_distribution_json' => 'array',
    ];
}

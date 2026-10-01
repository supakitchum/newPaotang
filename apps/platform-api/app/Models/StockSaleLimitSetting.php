<?php

namespace App\Models;

class StockSaleLimitSetting extends BaseModel
{
    protected $table = 'stock_sale_limit_settings';

    protected $fillable = [
        'id',
        'game_id',
        'scope_type',
        'scope_id',
        'back2_limit',
        'back3_limit',
        'front3_limit',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'back2_limit' => 'integer',
        'back3_limit' => 'integer',
        'front3_limit' => 'integer',
    ];
}

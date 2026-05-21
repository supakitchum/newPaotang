<?php

namespace App\Models;

class GameSalePriceRule extends BaseModel
{
    protected $table = 'game_sale_price_rules';

    protected $fillable = [
        'id',
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

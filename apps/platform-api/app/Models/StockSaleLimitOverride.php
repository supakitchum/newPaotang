<?php

namespace App\Models;

class StockSaleLimitOverride extends BaseModel
{
    protected $table = 'stock_sale_limit_overrides';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'game_id',
        'scope_type',
        'scope_id',
        'dimension',
        'value',
        'limit',
    ];

    protected $casts = [
        'limit' => 'integer',
    ];
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class VirtualStockSupplyLayer extends BaseModel
{
    protected $table = 'virtual_stock_supply_layers';

    protected $fillable = [
        'id',
        'profile_id',
        'batch_id',
        'game_id',
        'status',
        'layer_seed',
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

    public function profile(): BelongsTo
    {
        return $this->belongsTo(StockSupplyProfile::class, 'profile_id');
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(StockGenerationBatch::class, 'batch_id');
    }
}

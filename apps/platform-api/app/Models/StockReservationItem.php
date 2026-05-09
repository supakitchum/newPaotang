<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StockReservationItem extends BasePivotModel
{
    use BelongsToTenant;

    protected $table = 'stock_reservation_items';

    protected $fillable = [
        'reservation_id',
        'local_stock_item_id',
        'tenant_id',
        'game_id',
        'status',
        'created_at',
        'updated_at',
    ];

    public function reservation(): BelongsTo
    {
        return $this->belongsTo(StockReservation::class, 'reservation_id');
    }

    public function localStockItem(): BelongsTo
    {
        return $this->belongsTo(LocalStockItem::class, 'local_stock_item_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }
}

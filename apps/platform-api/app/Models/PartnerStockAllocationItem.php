<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerStockAllocationItem extends BasePivotModel
{
    use BelongsToTenant;

    protected $table = 'partner_stock_allocation_items';

    protected $fillable = [
        'allocation_id',
        'stock_item_id',
        'partner_id',
        'tenant_id',
        'game_id',
        'status',
        'created_at',
        'updated_at',
    ];

    public function allocation(): BelongsTo
    {
        return $this->belongsTo(PartnerStockAllocation::class, 'allocation_id');
    }

    public function stockItem(): BelongsTo
    {
        return $this->belongsTo(StockItem::class, 'stock_item_id');
    }

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }
}

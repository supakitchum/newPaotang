<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class StockItem extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'stock_items';

    protected $fillable = [
        'id',
        'game_id',
        'batch_id',
        'full_number',
        'front3',
        'back3',
        'back2',
        'status',
        'partner_id',
        'tenant_id',
        'allocation_id',
        'recall_reason',
        'recalled_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'recalled_at' => 'datetime',
    ];

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(StockGenerationBatch::class, 'batch_id');
    }

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function allocation(): BelongsTo
    {
        return $this->belongsTo(PartnerStockAllocation::class, 'allocation_id');
    }

    public function localStockItems(): HasMany
    {
        return $this->hasMany(LocalStockItem::class, 'stock_item_id');
    }
}

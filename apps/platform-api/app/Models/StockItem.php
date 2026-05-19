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
        'virtual_stock_ref',
        'virtual_copy_index',
        'image_url',
        'image_thumb_url',
        'image_storage_path',
        'image_thumb_storage_path',
        'image_generation_status',
        'image_generation_error',
        'image_generated_at',
        'background_set_type',
        'background_asset_version',
        'background_asset_index',
        'recall_reason',
        'recalled_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'recalled_at' => 'datetime',
        'image_generated_at' => 'datetime',
        'background_asset_index' => 'integer',
        'virtual_copy_index' => 'integer',
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

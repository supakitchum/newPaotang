<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class LocalStockItem extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'local_stock_items';

    protected $fillable = [
        'id',
        'tenant_id',
        'partner_id',
        'store_id',
        'game_id',
        'stock_item_id',
        'allocation_id',
        'full_number',
        'front3',
        'back3',
        'back2',
        'image_url',
        'image_thumb_url',
        'image_storage_path',
        'image_thumb_storage_path',
        'image_generation_status',
        'image_generation_error',
        'image_generated_at',
        'status',
        'synced_at',
        'reserved_at',
        'sold_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'synced_at' => 'datetime',
        'reserved_at' => 'datetime',
        'sold_at' => 'datetime',
        'image_generated_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function stockItem(): BelongsTo
    {
        return $this->belongsTo(StockItem::class, 'stock_item_id');
    }

    public function allocation(): BelongsTo
    {
        return $this->belongsTo(PartnerStockAllocation::class, 'allocation_id');
    }

    public function reservationItems(): HasMany
    {
        return $this->hasMany(StockReservationItem::class, 'local_stock_item_id');
    }

    public function orderItems(): HasMany
    {
        return $this->hasMany(OrderItem::class, 'local_stock_item_id');
    }

    public function ticket(): HasOne
    {
        return $this->hasOne(Ticket::class, 'local_stock_item_id');
    }
}

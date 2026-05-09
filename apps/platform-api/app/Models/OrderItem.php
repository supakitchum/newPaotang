<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderItem extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'order_items';

    protected $fillable = [
        'id',
        'tenant_id',
        'order_id',
        'local_stock_item_id',
        'ticket_id',
        'status',
        'price_amount',
        'currency',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'price_amount' => 'integer',
    ];

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    public function localStockItem(): BelongsTo
    {
        return $this->belongsTo(LocalStockItem::class, 'local_stock_item_id');
    }

    public function ticket(): BelongsTo
    {
        return $this->belongsTo(Ticket::class, 'ticket_id');
    }
}

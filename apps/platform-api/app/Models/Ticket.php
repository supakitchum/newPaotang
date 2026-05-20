<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Ticket extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tickets';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'order_id',
        'local_stock_item_id',
        'game_id',
        'full_number',
        'status',
        'image_url',
        'image_thumb_url',
        'image_render_snapshot_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'image_render_snapshot_json' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    public function localStockItem(): BelongsTo
    {
        return $this->belongsTo(LocalStockItem::class, 'local_stock_item_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function orderItem(): HasOne
    {
        return $this->hasOne(OrderItem::class, 'ticket_id');
    }

    public function winningTickets(): HasMany
    {
        return $this->hasMany(WinningTicket::class, 'ticket_id');
    }

    public function rewardClaims(): HasMany
    {
        return $this->hasMany(RewardClaim::class, 'ticket_id');
    }
}

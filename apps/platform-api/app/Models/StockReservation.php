<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class StockReservation extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'stock_reservations';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'game_id',
        'status',
        'expires_at',
        'released_at',
        'cancelled_at',
        'converted_at',
        'idempotency_key',
        'payload_hash',
        'released_idempotency_key',
        'released_payload_hash',
        'cancelled_idempotency_key',
        'cancelled_payload_hash',
        'cancelled_by_admin_id',
        'cancel_reason',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'released_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'converted_at' => 'datetime',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function cancelledByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'cancelled_by_admin_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(StockReservationItem::class, 'reservation_id');
    }

    public function localStockItems(): BelongsToMany
    {
        return $this->belongsToMany(LocalStockItem::class, 'stock_reservation_items', 'reservation_id', 'local_stock_item_id')
            ->withPivot(['tenant_id', 'game_id', 'status', 'price_amount', 'currency', 'sale_price_rule_snapshot_json'])
            ->withTimestamps();
    }
}

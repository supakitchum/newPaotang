<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Order extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'orders';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'reservation_id',
        'game_id',
        'wallet_id',
        'payment_method',
        'status',
        'payment_status',
        'total_amount',
        'currency',
        'reference',
        'admin_note',
        'idempotency_key',
        'payload_hash',
        'paid_at',
        'cancelled_at',
        'refunded_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'total_amount' => 'integer',
        'paid_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'refunded_at' => 'datetime',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function reservation(): BelongsTo
    {
        return $this->belongsTo(StockReservation::class, 'reservation_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class, 'wallet_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class, 'order_id');
    }

    public function tickets(): HasMany
    {
        return $this->hasMany(Ticket::class, 'order_id');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class, 'order_id');
    }

    public function commissionTransactions(): HasMany
    {
        return $this->hasMany(CommissionTransaction::class, 'order_id');
    }
}

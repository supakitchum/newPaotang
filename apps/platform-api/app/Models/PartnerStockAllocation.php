<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PartnerStockAllocation extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_stock_allocations';

    protected $fillable = [
        'id',
        'partner_id',
        'tenant_id',
        'game_id',
        'quota_id',
        'status',
        'requested_count',
        'allocated_count',
        'idempotency_key',
        'created_by_admin_id',
        'reason',
        'cancelled_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'requested_count' => 'integer',
        'allocated_count' => 'integer',
        'cancelled_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function quota(): BelongsTo
    {
        return $this->belongsTo(PartnerQuota::class, 'quota_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(PartnerStockAllocationItem::class, 'allocation_id');
    }

    public function localStockItems(): HasMany
    {
        return $this->hasMany(LocalStockItem::class, 'allocation_id');
    }
}

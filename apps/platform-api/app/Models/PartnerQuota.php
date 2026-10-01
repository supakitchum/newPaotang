<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PartnerQuota extends BaseModel
{
    protected $table = 'partner_quotas';

    protected $fillable = [
        'id',
        'partner_id',
        'game_id',
        'quota_count',
        'allocated_count',
        'sale_start_at',
        'sale_close_at',
        'status',
        'created_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'quota_count' => 'integer',
        'allocated_count' => 'integer',
        'sale_start_at' => 'datetime',
        'sale_close_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function allocations(): HasMany
    {
        return $this->hasMany(PartnerStockAllocation::class, 'quota_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StockSyncBatch extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'stock_sync_batches';

    protected $fillable = [
        'id',
        'tenant_id',
        'partner_id',
        'allocation_id',
        'status',
        'cursor',
        'processed_count',
        'idempotency_key',
        'payload_hash',
        'requested_by_admin_id',
        'payload_json',
        'started_at',
        'completed_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'processed_count' => 'integer',
        'payload_json' => 'array',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function allocation(): BelongsTo
    {
        return $this->belongsTo(PartnerStockAllocation::class, 'allocation_id');
    }

    public function requestedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'requested_by_admin_id');
    }
}

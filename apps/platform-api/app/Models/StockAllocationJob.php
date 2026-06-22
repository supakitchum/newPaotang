<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;

class StockAllocationJob extends BaseModel
{
    protected $fillable = [
        'id',
        'type',
        'status',
        'game_id',
        'allocation_id',
        'created_by_admin_id',
        'idempotency_key',
        'payload_hash',
        'payload_json',
        'actor_snapshot_json',
        'progress_current',
        'progress_total',
        'progress_percent',
        'created_count',
        'skipped_count',
        'failed_count',
        'current_step',
        'error_code',
        'error_message',
        'result_json',
        'queued_at',
        'started_at',
        'heartbeat_at',
        'completed_at',
        'failed_at',
        'cancelled_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'payload_json' => 'array',
        'actor_snapshot_json' => 'array',
        'progress_current' => 'integer',
        'progress_total' => 'integer',
        'progress_percent' => 'integer',
        'created_count' => 'integer',
        'skipped_count' => 'integer',
        'failed_count' => 'integer',
        'result_json' => 'array',
        'queued_at' => 'datetime',
        'started_at' => 'datetime',
        'heartbeat_at' => 'datetime',
        'completed_at' => 'datetime',
        'failed_at' => 'datetime',
        'cancelled_at' => 'datetime',
    ];

    public function items(): HasMany
    {
        return $this->hasMany(StockAllocationJobItem::class, 'job_id');
    }
}

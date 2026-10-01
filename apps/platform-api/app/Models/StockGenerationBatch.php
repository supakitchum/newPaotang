<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class StockGenerationBatch extends BaseModel
{
    protected $table = 'stock_generation_batches';

    protected $fillable = [
        'id',
        'game_id',
        'type',
        'status',
        'requested_count',
        'generated_count',
        'total_rounds',
        'processed_rounds',
        'chunk_rounds',
        'range_start',
        'range_end',
        'number_digits',
        'idempotency_key',
        'payload_hash',
        'created_by_admin_id',
        'payload_json',
        'started_at',
        'completed_at',
        'failed_at',
        'failure_reason',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'requested_count' => 'integer',
        'generated_count' => 'integer',
        'total_rounds' => 'integer',
        'processed_rounds' => 'integer',
        'chunk_rounds' => 'integer',
        'number_digits' => 'integer',
        'payload_json' => 'array',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'failed_at' => 'datetime',
    ];

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function stockItems(): HasMany
    {
        return $this->hasMany(StockItem::class, 'batch_id');
    }

    public function chunks(): HasMany
    {
        return $this->hasMany(StockGenerationBatchChunk::class, 'batch_id');
    }
}

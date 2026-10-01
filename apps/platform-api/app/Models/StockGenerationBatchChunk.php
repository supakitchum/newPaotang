<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StockGenerationBatchChunk extends BaseModel
{
    protected $table = 'stock_generation_batch_chunks';

    protected $fillable = [
        'id',
        'batch_id',
        'chunk_index',
        'start_round',
        'round_count',
        'status',
        'attempt_count',
        'started_at',
        'completed_at',
        'failed_at',
        'failure_reason',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'chunk_index' => 'integer',
        'start_round' => 'integer',
        'round_count' => 'integer',
        'attempt_count' => 'integer',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'failed_at' => 'datetime',
    ];

    public function batch(): BelongsTo
    {
        return $this->belongsTo(StockGenerationBatch::class, 'batch_id');
    }
}

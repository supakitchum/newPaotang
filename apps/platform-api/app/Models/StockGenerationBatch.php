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
        'range_start',
        'range_end',
        'idempotency_key',
        'payload_hash',
        'created_by_admin_id',
        'payload_json',
        'completed_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'requested_count' => 'integer',
        'generated_count' => 'integer',
        'number_digits' => 'integer',
        'payload_json' => 'array',
        'completed_at' => 'datetime',
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
}

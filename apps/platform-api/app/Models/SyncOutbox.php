<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SyncOutbox extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'sync_outbox';

    protected $fillable = [
        'id',
        'event_id',
        'event_type',
        'event_version',
        'producer',
        'tenant_id',
        'partner_id',
        'game_id',
        'aggregate_type',
        'aggregate_id',
        'idempotency_key',
        'correlation_id',
        'payload_json',
        'status',
        'attempt_count',
        'available_at',
        'processed_at',
        'last_error',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'event_version' => 'integer',
        'payload_json' => 'array',
        'attempt_count' => 'integer',
        'available_at' => 'datetime',
        'processed_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }
}

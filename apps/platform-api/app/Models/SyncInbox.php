<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SyncInbox extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'sync_inbox';

    protected $fillable = [
        'id',
        'event_id',
        'event_type',
        'event_version',
        'consumer',
        'tenant_id',
        'partner_id',
        'game_id',
        'idempotency_key',
        'payload_hash',
        'status',
        'processed_at',
        'last_error',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'event_version' => 'integer',
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

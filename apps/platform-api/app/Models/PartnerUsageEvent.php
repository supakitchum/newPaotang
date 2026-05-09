<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerUsageEvent extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_usage_events';

    protected $fillable = [
        'id',
        'partner_id',
        'tenant_id',
        'meter_key',
        'quantity',
        'labels_json',
        'occurred_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'quantity' => 'integer',
        'labels_json' => 'array',
        'occurred_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}

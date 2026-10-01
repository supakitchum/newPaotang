<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerUsageMeter extends BaseModel
{
    protected $table = 'partner_usage_meters';

    protected $fillable = [
        'id',
        'partner_id',
        'meter_key',
        'value',
        'limit_value',
        'status',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'value' => 'integer',
        'limit_value' => 'integer',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}

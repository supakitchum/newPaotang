<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TenantActivityCashbackConfig extends BaseModel
{
    protected $table = 'tenant_activity_cashback_configs';

    protected $primaryKey = 'activity_id';

    protected $fillable = [
        'activity_id',
        'cashback_type',
        'cashback_percent_bps',
        'fixed_amount',
        'min_ticket_count',
        'min_purchase_amount',
        'currency',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'cashback_percent_bps' => 'integer',
        'fixed_amount' => 'integer',
        'min_ticket_count' => 'integer',
        'min_purchase_amount' => 'integer',
        'metadata_json' => 'array',
    ];

    public function activity(): BelongsTo
    {
        return $this->belongsTo(TenantActivity::class, 'activity_id');
    }
}

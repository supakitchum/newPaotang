<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TenantActivityLuckyConfig extends BaseModel
{
    protected $table = 'tenant_activity_lucky_configs';

    protected $primaryKey = 'activity_id';

    protected $fillable = [
        'activity_id',
        'first_prize_last2_enabled',
        'first_prize_last3_enabled',
        'last2_enabled',
        'eligibility_rule',
        'threshold_tickets',
        'first_prize_last2_amount',
        'first_prize_last3_amount',
        'last2_amount',
        'currency',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'first_prize_last2_enabled' => 'boolean',
        'first_prize_last3_enabled' => 'boolean',
        'last2_enabled' => 'boolean',
        'threshold_tickets' => 'integer',
        'first_prize_last2_amount' => 'integer',
        'first_prize_last3_amount' => 'integer',
        'last2_amount' => 'integer',
        'metadata_json' => 'array',
    ];

    public function activity(): BelongsTo
    {
        return $this->belongsTo(TenantActivity::class, 'activity_id');
    }
}

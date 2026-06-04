<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class TenantActivityAward extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_activity_awards';

    protected $fillable = [
        'id',
        'tenant_id',
        'activity_id',
        'game_id',
        'customer_id',
        'entry_id',
        'type',
        'prediction_type',
        'amount',
        'currency',
        'status',
        'calculated_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'amount' => 'integer',
        'calculated_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function activity(): BelongsTo
    {
        return $this->belongsTo(TenantActivity::class, 'activity_id');
    }

    public function entry(): BelongsTo
    {
        return $this->belongsTo(TenantActivityEntry::class, 'entry_id');
    }

    public function claim(): HasOne
    {
        return $this->hasOne(ActivityClaim::class, 'activity_award_id');
    }
}

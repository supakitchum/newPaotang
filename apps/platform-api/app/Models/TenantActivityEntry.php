<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class TenantActivityEntry extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_activity_entries';

    protected $fillable = [
        'id',
        'tenant_id',
        'activity_id',
        'game_id',
        'customer_id',
        'prediction_type',
        'selected_number',
        'status',
        'rights_rule',
        'rights_source_type',
        'rights_source_id',
        'awarded_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'awarded_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function activity(): BelongsTo
    {
        return $this->belongsTo(TenantActivity::class, 'activity_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function award(): HasOne
    {
        return $this->hasOne(TenantActivityAward::class, 'entry_id');
    }
}

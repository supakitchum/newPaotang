<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerBillingPlanBinding extends BaseModel
{
    protected $table = 'partner_billing_plan_bindings';

    protected $fillable = [
        'id',
        'partner_id',
        'billing_plan_code',
        'status',
        'effective_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'effective_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}

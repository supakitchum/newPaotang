<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AffiliateTierRateHistory extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_tier_rate_history';

    protected $dateFormat = 'Y-m-d H:i:s.u';

    protected $fillable = [
        'id',
        'tenant_id',
        'affiliate_program_id',
        'commission_per_ticket_amount',
        'source',
        'metadata_json',
        'effective_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'commission_per_ticket_amount' => 'integer',
        'metadata_json' => 'array',
        'effective_at' => 'datetime',
    ];

    public function program(): BelongsTo
    {
        return $this->belongsTo(AffiliateProgram::class, 'affiliate_program_id');
    }
}

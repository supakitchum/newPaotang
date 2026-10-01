<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AffiliateTierCampaignResult extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_tier_campaign_results';

    protected $fillable = [
        'id',
        'tenant_id',
        'campaign_id',
        'affiliate_account_id',
        'ticket_count',
        'rank',
        'reached_at',
        'previous_program_id',
        'calculated_program_id',
        'applied_program_id',
        'result_status',
        'metadata_json',
        'finalized_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'ticket_count' => 'integer',
        'rank' => 'integer',
        'reached_at' => 'datetime',
        'finalized_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(AffiliateTierCampaign::class, 'campaign_id');
    }

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }

    public function previousProgram(): BelongsTo
    {
        return $this->belongsTo(AffiliateProgram::class, 'previous_program_id');
    }

    public function calculatedProgram(): BelongsTo
    {
        return $this->belongsTo(AffiliateProgram::class, 'calculated_program_id');
    }

    public function appliedProgram(): BelongsTo
    {
        return $this->belongsTo(AffiliateProgram::class, 'applied_program_id');
    }
}

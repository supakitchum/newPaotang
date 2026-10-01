<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AffiliateTierCampaignRule extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_tier_campaign_rules';

    protected $fillable = [
        'id',
        'tenant_id',
        'campaign_id',
        'target_program_id',
        'rule_order',
        'minimum_ticket_count',
        'rank_from',
        'rank_to',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'rule_order' => 'integer',
        'minimum_ticket_count' => 'integer',
        'rank_from' => 'integer',
        'rank_to' => 'integer',
    ];

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(AffiliateTierCampaign::class, 'campaign_id');
    }

    public function targetProgram(): BelongsTo
    {
        return $this->belongsTo(AffiliateProgram::class, 'target_program_id');
    }
}

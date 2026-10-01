<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AffiliateTierCampaignStat extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_tier_campaign_stats';

    protected $fillable = [
        'id',
        'tenant_id',
        'campaign_id',
        'affiliate_account_id',
        'ticket_count',
        'reached_at',
        'reconciled_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'ticket_count' => 'integer',
        'reached_at' => 'datetime',
        'reconciled_at' => 'datetime',
    ];

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(AffiliateTierCampaign::class, 'campaign_id');
    }

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }
}

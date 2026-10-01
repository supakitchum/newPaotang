<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AffiliateTierHistory extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_tier_history';

    protected $fillable = [
        'id',
        'tenant_id',
        'affiliate_account_id',
        'campaign_id',
        'previous_program_id',
        'new_program_id',
        'source',
        'ticket_count',
        'rank',
        'metadata_json',
        'effective_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'ticket_count' => 'integer',
        'rank' => 'integer',
        'metadata_json' => 'array',
        'effective_at' => 'datetime',
    ];

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(AffiliateTierCampaign::class, 'campaign_id');
    }
}

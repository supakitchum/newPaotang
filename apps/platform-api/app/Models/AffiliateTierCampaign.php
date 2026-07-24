<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AffiliateTierCampaign extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_tier_campaigns';

    protected $fillable = [
        'id',
        'tenant_id',
        'name',
        'campaign_type',
        'status',
        'starts_at',
        'ends_at',
        'finalized_at',
        'created_by_admin_id',
        'finalized_by_admin_id',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
        'finalized_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function rules(): HasMany
    {
        return $this->hasMany(AffiliateTierCampaignRule::class, 'campaign_id')->orderBy('rule_order');
    }

    public function results(): HasMany
    {
        return $this->hasMany(AffiliateTierCampaignResult::class, 'campaign_id');
    }

    public function stats(): HasMany
    {
        return $this->hasMany(AffiliateTierCampaignStat::class, 'campaign_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AffiliateProgram extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_programs';

    protected $fillable = [
        'id',
        'tenant_id',
        'code',
        'name',
        'status',
        'minimum_payout_amount',
        'starts_at',
        'ends_at',
        'metadata_json',
        'created_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function links(): HasMany
    {
        return $this->hasMany(AffiliateLink::class, 'affiliate_program_id');
    }

    public function attributions(): HasMany
    {
        return $this->hasMany(AffiliateAttribution::class, 'affiliate_program_id');
    }

    public function commissionRules(): HasMany
    {
        return $this->hasMany(CommissionRule::class, 'affiliate_program_id');
    }
}

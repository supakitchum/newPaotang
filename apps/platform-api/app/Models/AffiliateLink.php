<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AffiliateLink extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_links';

    protected $fillable = [
        'id',
        'tenant_id',
        'affiliate_account_id',
        'affiliate_program_id',
        'code',
        'url',
        'status',
        'metadata_json',
        'created_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'metadata_json' => 'array',
    ];

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }

    public function affiliateProgram(): BelongsTo
    {
        return $this->belongsTo(AffiliateProgram::class, 'affiliate_program_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function attributions(): HasMany
    {
        return $this->hasMany(AffiliateAttribution::class, 'affiliate_link_id');
    }
}

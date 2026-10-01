<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CommissionRule extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'commission_rules';

    protected $fillable = [
        'id',
        'tenant_id',
        'affiliate_program_id',
        'affiliate_account_id',
        'code',
        'name',
        'rule_type',
        'amount',
        'rate_bps',
        'currency',
        'status',
        'metadata_json',
        'created_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'amount' => 'integer',
        'rate_bps' => 'integer',
        'metadata_json' => 'array',
    ];

    public function affiliateProgram(): BelongsTo
    {
        return $this->belongsTo(AffiliateProgram::class, 'affiliate_program_id');
    }

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function commissionTransactions(): HasMany
    {
        return $this->hasMany(CommissionTransaction::class, 'commission_rule_id');
    }
}

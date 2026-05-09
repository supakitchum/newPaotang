<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CommissionTransaction extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'commission_transactions';

    protected $fillable = [
        'id',
        'tenant_id',
        'affiliate_account_id',
        'affiliate_attribution_id',
        'order_id',
        'commission_rule_id',
        'original_commission_id',
        'transaction_type',
        'status',
        'amount',
        'currency',
        'idempotency_key',
        'payload_hash',
        'calculated_at',
        'approved_by_admin_id',
        'approved_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'amount' => 'integer',
        'calculated_at' => 'datetime',
        'approved_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }

    public function affiliateAttribution(): BelongsTo
    {
        return $this->belongsTo(AffiliateAttribution::class, 'affiliate_attribution_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    public function commissionRule(): BelongsTo
    {
        return $this->belongsTo(CommissionRule::class, 'commission_rule_id');
    }

    public function originalCommission(): BelongsTo
    {
        return $this->belongsTo(self::class, 'original_commission_id');
    }

    public function reversals(): HasMany
    {
        return $this->hasMany(self::class, 'original_commission_id');
    }

    public function approvedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'approved_by_admin_id');
    }
}

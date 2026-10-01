<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AffiliateAccount extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_accounts';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'affiliate_program_id',
        'code',
        'name',
        'store_name_status',
        'store_name_normalized',
        'store_name_approved_at',
        'store_name_change_available_at',
        'phone',
        'email',
        'status',
        'wallet_balance_amount',
        'currency',
        'payout_profile_json',
        'payout_profile_encrypted',
        'metadata_json',
        'created_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'wallet_balance_amount' => 'integer',
        'store_name_approved_at' => 'datetime',
        'store_name_change_available_at' => 'datetime',
        'payout_profile_json' => 'array',
        'metadata_json' => 'array',
    ];

    protected $hidden = [
        'payout_profile_json',
        'payout_profile_encrypted',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function program(): BelongsTo
    {
        return $this->belongsTo(AffiliateProgram::class, 'affiliate_program_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function links(): HasMany
    {
        return $this->hasMany(AffiliateLink::class, 'affiliate_account_id');
    }

    public function attributions(): HasMany
    {
        return $this->hasMany(AffiliateAttribution::class, 'affiliate_account_id');
    }

    public function commissionRules(): HasMany
    {
        return $this->hasMany(CommissionRule::class, 'affiliate_account_id');
    }

    public function commissionTransactions(): HasMany
    {
        return $this->hasMany(CommissionTransaction::class, 'affiliate_account_id');
    }

    public function payouts(): HasMany
    {
        return $this->hasMany(AffiliatePayout::class, 'affiliate_account_id');
    }

    public function storeNameRequests(): HasMany
    {
        return $this->hasMany(AffiliateStoreNameRequest::class, 'affiliate_account_id');
    }

    public function tierHistory(): HasMany
    {
        return $this->hasMany(AffiliateTierHistory::class, 'affiliate_account_id');
    }
}

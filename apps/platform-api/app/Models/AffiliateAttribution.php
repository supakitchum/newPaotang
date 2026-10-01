<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AffiliateAttribution extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_attributions';

    protected $fillable = [
        'id',
        'tenant_id',
        'affiliate_account_id',
        'affiliate_link_id',
        'affiliate_program_id',
        'customer_id',
        'order_id',
        'status',
        'attributed_at',
        'converted_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'attributed_at' => 'datetime',
        'converted_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }

    public function affiliateLink(): BelongsTo
    {
        return $this->belongsTo(AffiliateLink::class, 'affiliate_link_id');
    }

    public function affiliateProgram(): BelongsTo
    {
        return $this->belongsTo(AffiliateProgram::class, 'affiliate_program_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    public function commissionTransactions(): HasMany
    {
        return $this->hasMany(CommissionTransaction::class, 'affiliate_attribution_id');
    }
}

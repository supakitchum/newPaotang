<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AffiliateStoreNameClaim extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_store_name_claims';

    protected $fillable = [
        'id',
        'tenant_id',
        'affiliate_account_id',
        'request_id',
        'normalized_name',
        'status',
        'created_at',
        'updated_at',
    ];

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }

    public function request(): BelongsTo
    {
        return $this->belongsTo(AffiliateStoreNameRequest::class, 'request_id');
    }
}

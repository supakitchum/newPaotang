<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AffiliateStoreNameRequest extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'affiliate_store_name_requests';

    protected $fillable = [
        'id',
        'tenant_id',
        'affiliate_account_id',
        'request_type',
        'previous_name',
        'requested_name',
        'normalized_name',
        'status',
        'admin_note',
        'reviewed_by_admin_id',
        'submitted_at',
        'reviewed_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'submitted_at' => 'datetime',
        'reviewed_at' => 'datetime',
    ];

    public function affiliateAccount(): BelongsTo
    {
        return $this->belongsTo(AffiliateAccount::class, 'affiliate_account_id');
    }

    public function reviewedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'reviewed_by_admin_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerSettlement extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_settlements';

    protected $fillable = [
        'id',
        'partner_id',
        'tenant_id',
        'status',
        'sales_amount',
        'commission_amount',
        'payout_amount',
        'net_amount',
        'currency',
        'period_from',
        'period_to',
        'approved_by_admin_id',
        'approved_at',
        'idempotency_key',
        'payload_hash',
        'summary_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'sales_amount' => 'integer',
        'commission_amount' => 'integer',
        'payout_amount' => 'integer',
        'net_amount' => 'integer',
        'period_from' => 'date',
        'period_to' => 'date',
        'approved_at' => 'datetime',
        'summary_json' => 'array',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function approvedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'approved_by_admin_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletLedger extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'wallet_ledger';

    protected $fillable = [
        'id',
        'tenant_id',
        'wallet_id',
        'customer_id',
        'entry_type',
        'status',
        'amount',
        'currency',
        'balance_after',
        'reference_type',
        'reference_id',
        'idempotency_key',
        'created_by_admin_id',
        'metadata_json',
        'posted_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'amount' => 'integer',
        'balance_after' => 'integer',
        'metadata_json' => 'array',
        'posted_at' => 'datetime',
    ];

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class, 'wallet_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }
}

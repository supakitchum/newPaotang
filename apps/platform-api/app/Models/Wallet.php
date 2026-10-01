<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Wallet extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'wallets';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'name',
        'type',
        'status',
        'balance_amount',
        'currency',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'balance_amount' => 'integer',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function ledgerEntries(): HasMany
    {
        return $this->hasMany(WalletLedger::class, 'wallet_id');
    }

    public function topupRequests(): HasMany
    {
        return $this->hasMany(TopupRequest::class, 'wallet_id');
    }

    public function rewardClaims(): HasMany
    {
        return $this->hasMany(RewardClaim::class, 'wallet_id');
    }
}

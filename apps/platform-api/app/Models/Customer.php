<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Customer extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customers';

    protected $fillable = [
        'id',
        'tenant_id',
        'phone',
        'name',
        'status',
        'created_at',
        'updated_at',
        'email',
        'password_hash',
        'avatar_url',
        'last_login_at',
    ];

    protected $hidden = [
        'password_hash',
    ];

    protected $casts = [
        'last_login_at' => 'datetime',
    ];

    public function authSessions(): HasMany
    {
        return $this->hasMany(CustomerAuthSession::class, 'customer_id');
    }

    public function wallet(): HasOne
    {
        return $this->hasOne(Wallet::class, 'customer_id');
    }

    public function wallets(): HasMany
    {
        return $this->hasMany(Wallet::class, 'customer_id');
    }

    public function reservations(): HasMany
    {
        return $this->hasMany(StockReservation::class, 'customer_id');
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'customer_id');
    }

    public function tickets(): HasMany
    {
        return $this->hasMany(Ticket::class, 'customer_id');
    }

    public function topupRequests(): HasMany
    {
        return $this->hasMany(TopupRequest::class, 'customer_id');
    }

    public function rewardClaims(): HasMany
    {
        return $this->hasMany(RewardClaim::class, 'customer_id');
    }
}

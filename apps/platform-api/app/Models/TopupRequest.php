<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TopupRequest extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'topup_requests';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'wallet_id',
        'payment_id',
        'provider',
        'channel',
        'status',
        'amount',
        'bonus_amount',
        'currency',
        'reference',
        'transfer_at',
        'slip_url',
        'idempotency_key',
        'payload_hash',
        'reviewed_by_admin_id',
        'reviewed_at',
        'admin_note',
        'provider_payload_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'amount' => 'integer',
        'bonus_amount' => 'integer',
        'transfer_at' => 'datetime',
        'reviewed_at' => 'datetime',
        'provider_payload_json' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class, 'wallet_id');
    }

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class, 'payment_id');
    }

    public function reviewedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'reviewed_by_admin_id');
    }

    public function webhookCallbacks(): HasMany
    {
        return $this->hasMany(WebhookCallback::class, 'topup_request_id');
    }
}

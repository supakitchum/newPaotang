<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Payment extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'payments';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'order_id',
        'provider',
        'status',
        'amount',
        'currency',
        'reference',
        'redirect_url',
        'idempotency_key',
        'payload_hash',
        'provider_event_id',
        'provider_reference',
        'provider_payload_json',
        'paid_at',
        'created_at',
        'updated_at',
        'topup_request_id',
    ];

    protected $casts = [
        'amount' => 'integer',
        'provider_payload_json' => 'array',
        'paid_at' => 'datetime',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    public function topupRequest(): BelongsTo
    {
        return $this->belongsTo(TopupRequest::class, 'topup_request_id');
    }

    public function webhookCallbacks(): HasMany
    {
        return $this->hasMany(WebhookCallback::class, 'payment_id');
    }
}

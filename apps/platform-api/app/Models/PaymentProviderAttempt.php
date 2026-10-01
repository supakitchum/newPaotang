<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentProviderAttempt extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'payment_provider_attempts';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'payment_id',
        'topup_request_id',
        'provider',
        'operation',
        'channel',
        'status',
        'request_id',
        'idempotency_key_hash',
        'provider_reference1',
        'provider_reference2',
        'provider_reference3',
        'provider_reference4',
        'provider_transaction_reference',
        'application_error_code',
        'provider_http_status',
        'provider_code',
        'provider_message',
        'response_classification',
        'latency_ms',
        'attempted_at',
        'completed_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'provider_http_status' => 'integer',
        'latency_ms' => 'integer',
        'attempted_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class, 'payment_id');
    }

    public function topupRequest(): BelongsTo
    {
        return $this->belongsTo(TopupRequest::class, 'topup_request_id');
    }
}

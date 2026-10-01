<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WebhookCallback extends BaseModel
{
    protected $table = 'webhook_callbacks';

    protected $fillable = [
        'id',
        'domain',
        'provider',
        'callback_key',
        'payload_hash',
        'status',
        'payment_id',
        'topup_request_id',
        'payload_json',
        'response_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'payload_json' => 'array',
        'response_json' => 'array',
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

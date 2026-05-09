<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantPaymentChannel extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_payment_channels';

    protected $fillable = [
        'id',
        'tenant_id',
        'code',
        'name',
        'provider',
        'channel_type',
        'status',
        'sort_order',
        'config_json',
        'secret_status_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'sort_order' => 'integer',
        'config_json' => 'array',
        'secret_status_json' => 'array',
    ];
}

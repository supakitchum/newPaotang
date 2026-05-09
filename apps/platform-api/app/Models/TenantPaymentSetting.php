<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantPaymentSetting extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_payment_settings';

    protected $fillable = [
        'id',
        'tenant_id',
        'status',
        'provider_mode',
        'default_currency',
        'allow_manual_topup',
        'allow_external_payment',
        'payment_provider_status',
        'config_json',
        'secret_status_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'allow_manual_topup' => 'boolean',
        'allow_external_payment' => 'boolean',
        'config_json' => 'array',
        'secret_status_json' => 'array',
    ];
}

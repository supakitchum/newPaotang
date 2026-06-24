<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantPaymentProviderConnection extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_payment_provider_connections';

    protected $fillable = [
        'id',
        'tenant_id',
        'provider',
        'status',
        'api_key_encrypted',
        'verified_at',
        'last_tested_at',
        'last_test_status',
        'last_error',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'api_key_encrypted',
    ];

    protected $casts = [
        'verified_at' => 'datetime',
        'last_tested_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

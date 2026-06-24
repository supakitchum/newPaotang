<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantSmsProvider extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_sms_providers';

    protected $fillable = [
        'id',
        'tenant_id',
        'provider',
        'status',
        'api_key_encrypted',
        'api_secret_encrypted',
        'sender_name',
        'verified_at',
        'last_tested_at',
        'last_test_status',
        'last_test_message',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'api_key_encrypted',
        'api_secret_encrypted',
    ];

    protected $casts = [
        'verified_at' => 'datetime',
        'last_tested_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

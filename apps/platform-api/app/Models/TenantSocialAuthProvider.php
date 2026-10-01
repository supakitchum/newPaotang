<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantSocialAuthProvider extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_social_auth_providers';

    protected $fillable = [
        'id',
        'tenant_id',
        'provider',
        'status',
        'client_id_encrypted',
        'client_secret_encrypted',
        'team_id_encrypted',
        'key_id_encrypted',
        'private_key_encrypted',
        'redirect_uri',
        'verified_at',
        'last_tested_at',
        'last_test_status',
        'last_test_message',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'client_id_encrypted',
        'client_secret_encrypted',
        'team_id_encrypted',
        'key_id_encrypted',
        'private_key_encrypted',
    ];

    protected $casts = [
        'verified_at' => 'datetime',
        'last_tested_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

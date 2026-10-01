<?php

namespace App\Models;

class PlatformStorageConnection extends BaseModel
{
    protected $table = 'platform_storage_connections';

    protected $fillable = [
        'id',
        'provider',
        'status',
        'bucket',
        'region',
        'endpoint',
        'url',
        'root_prefix',
        'visibility',
        'use_path_style_endpoint',
        'access_key_id_encrypted',
        'secret_access_key_encrypted',
        'session_token_encrypted',
        'last_test_status',
        'last_test_message',
        'last_tested_at',
        'verified_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'access_key_id_encrypted',
        'secret_access_key_encrypted',
        'session_token_encrypted',
    ];

    protected $casts = [
        'use_path_style_endpoint' => 'boolean',
        'last_tested_at' => 'datetime',
        'verified_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

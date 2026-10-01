<?php

namespace App\Models;

class PlatformStorageRoute extends BaseModel
{
    protected $table = 'platform_storage_routes';

    protected $primaryKey = 'route_key';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'route_key',
        'label',
        'description',
        'driver',
        'root_prefix',
        'tenant_scoped',
        'sort_order',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'tenant_scoped' => 'boolean',
        'metadata_json' => 'array',
    ];
}

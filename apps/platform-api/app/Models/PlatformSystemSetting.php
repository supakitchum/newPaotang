<?php

namespace App\Models;

class PlatformSystemSetting extends BaseModel
{
    protected $table = 'platform_system_settings';

    protected $fillable = [
        'id',
        'key',
        'value_json',
        'status',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'value_json' => 'array',
    ];
}

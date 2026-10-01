<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;

class TenantLineChannel extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_line_channels';

    protected $fillable = [
        'id',
        'tenant_id',
        'status',
        'messaging_access_token_encrypted',
        'messaging_channel_secret_encrypted',
        'login_channel_id_encrypted',
        'login_channel_secret_encrypted',
        'liff_id',
        'bot_user_id',
        'bot_basic_id',
        'bot_premium_id',
        'bot_display_name',
        'bot_picture_url',
        'chat_mode',
        'mark_as_read_mode',
        'verified_at',
        'last_tested_at',
        'last_test_status',
        'last_test_message',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'messaging_access_token_encrypted',
        'messaging_channel_secret_encrypted',
        'login_channel_id_encrypted',
        'login_channel_secret_encrypted',
    ];

    protected $casts = [
        'verified_at' => 'datetime',
        'last_tested_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

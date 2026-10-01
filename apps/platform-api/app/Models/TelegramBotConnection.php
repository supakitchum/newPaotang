<?php

namespace App\Models;

class TelegramBotConnection extends BaseModel
{
    protected $table = 'telegram_bot_connections';

    protected $fillable = [
        'id',
        'status',
        'bot_token_encrypted',
        'bot_id',
        'bot_username',
        'bot_first_name',
        'last_update_id',
        'verified_at',
        'last_synced_at',
        'last_test_status',
        'last_test_message',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'bot_token_encrypted',
    ];

    protected $casts = [
        'last_update_id' => 'integer',
        'verified_at' => 'datetime',
        'last_synced_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

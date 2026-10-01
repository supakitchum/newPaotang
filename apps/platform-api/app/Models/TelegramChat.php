<?php

namespace App\Models;

class TelegramChat extends BaseModel
{
    protected $table = 'telegram_chats';

    protected $fillable = [
        'id',
        'chat_id',
        'chat_type',
        'title',
        'username',
        'first_name',
        'last_name',
        'last_seen_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'last_seen_at' => 'datetime',
        'metadata_json' => 'array',
    ];
}

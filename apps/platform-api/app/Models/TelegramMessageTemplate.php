<?php

namespace App\Models;

class TelegramMessageTemplate extends BaseModel
{
    protected $table = 'telegram_message_templates';

    protected $fillable = [
        'id',
        'event_key',
        'enabled',
        'title',
        'body_text',
        'variables_json',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'enabled' => 'boolean',
        'variables_json' => 'array',
        'metadata_json' => 'array',
    ];
}

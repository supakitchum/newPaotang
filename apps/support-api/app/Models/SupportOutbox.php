<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SupportOutbox extends Model
{
    protected $table = 'support_outbox';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];
    protected $casts = [
        'payload_json' => 'array',
        'available_at' => 'datetime',
        'delivered_at' => 'datetime',
    ];
}

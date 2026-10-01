<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SupportAgentState extends Model
{
    protected $table = 'support_agent_states';
    public $incrementing = false;
    protected $primaryKey = null;
    protected $guarded = [];
    protected $casts = [
        'available' => 'boolean',
        'last_heartbeat_at' => 'datetime',
        'last_assigned_at' => 'datetime',
    ];
}

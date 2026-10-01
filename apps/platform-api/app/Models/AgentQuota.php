<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AgentQuota extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'agent_quotas';

    protected $fillable = [
        'id',
        'tenant_id',
        'agent_id',
        'game_id',
        'quota_count',
        'used_count',
        'status',
        'payload_json',
        'updated_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'quota_count' => 'integer',
        'used_count' => 'integer',
        'payload_json' => 'array',
    ];

    public function agent(): BelongsTo
    {
        return $this->belongsTo(Agent::class, 'agent_id');
    }

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function updatedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'updated_by_admin_id');
    }
}

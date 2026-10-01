<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Agent extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'agents';

    protected $fillable = [
        'id',
        'tenant_id',
        'partner_id',
        'code',
        'name',
        'phone',
        'email',
        'store_id',
        'status',
        'metadata_json',
        'created_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'metadata_json' => 'array',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function quotas(): HasMany
    {
        return $this->hasMany(AgentQuota::class, 'agent_id');
    }
}

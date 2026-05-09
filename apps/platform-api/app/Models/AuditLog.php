<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AuditLog extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'audit_logs';

    protected $fillable = [
        'id',
        'actor_type',
        'actor_id',
        'scope_type',
        'tenant_id',
        'partner_id',
        'action',
        'target_type',
        'target_id',
        'request_id',
        'ip_address',
        'user_agent',
        'payload_redacted_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'payload_redacted_json' => 'array',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}

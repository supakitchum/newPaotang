<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SupportImpersonationEvent extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'support_impersonation_events';

    protected $fillable = [
        'id',
        'tenant_id',
        'support_access_request_id',
        'support_impersonation_session_id',
        'event_type',
        'action',
        'actor_admin_id',
        'target_user_id',
        'target_user_type',
        'reason',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'metadata_json' => 'array',
    ];

    public function supportAccessRequest(): BelongsTo
    {
        return $this->belongsTo(SupportAccessRequest::class, 'support_access_request_id');
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(SupportImpersonationSession::class, 'support_impersonation_session_id');
    }
}

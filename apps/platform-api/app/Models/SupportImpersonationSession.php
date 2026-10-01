<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SupportImpersonationSession extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'support_impersonation_sessions';

    protected $fillable = [
        'id',
        'tenant_id',
        'support_access_request_id',
        'target_user_id',
        'target_user_type',
        'scope',
        'status',
        'token_hash',
        'token_last_four',
        'issued_to_admin_id',
        'started_at',
        'expires_at',
        'revoked_at',
        'ended_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'started_at' => 'datetime',
        'expires_at' => 'datetime',
        'revoked_at' => 'datetime',
        'ended_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function supportAccessRequest(): BelongsTo
    {
        return $this->belongsTo(SupportAccessRequest::class, 'support_access_request_id');
    }

    public function issuedToAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'issued_to_admin_id');
    }

    public function blockedActions(): HasMany
    {
        return $this->hasMany(SupportImpersonationBlockedAction::class, 'support_impersonation_session_id');
    }
}

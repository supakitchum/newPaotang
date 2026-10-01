<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SupportAccessRequest extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'support_access_requests';

    protected $fillable = [
        'id',
        'tenant_id',
        'target_user_id',
        'target_user_type',
        'scope',
        'status',
        'reason',
        'ticket_id',
        'requested_by_admin_id',
        'approved_by_admin_id',
        'approved_at',
        'revoked_by_admin_id',
        'revoked_at',
        'completed_at',
        'expires_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'approved_at' => 'datetime',
        'revoked_at' => 'datetime',
        'completed_at' => 'datetime',
        'expires_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function requestedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'requested_by_admin_id');
    }

    public function approvedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'approved_by_admin_id');
    }

    public function approvals(): HasMany
    {
        return $this->hasMany(SupportAccessApproval::class, 'support_access_request_id');
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(SupportImpersonationSession::class, 'support_access_request_id');
    }
}

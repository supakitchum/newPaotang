<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerTenantMaintenanceBypass extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_maintenance_bypasses';

    protected $fillable = [
        'id',
        'tenant_id',
        'bypass_type',
        'actor_type',
        'actor_id',
        'support_impersonation_session_id',
        'status',
        'reason',
        'ticket_id',
        'expires_at',
        'revoked_at',
        'created_by_admin_id',
        'revoked_by_admin_id',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'revoked_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function revokedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'revoked_by_admin_id');
    }
}

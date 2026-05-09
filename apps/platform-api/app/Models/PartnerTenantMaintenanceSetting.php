<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PartnerTenantMaintenanceSetting extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_maintenance_settings';

    protected $fillable = [
        'id',
        'tenant_id',
        'status',
        'mode',
        'message',
        'reason',
        'ticket_id',
        'scheduled_start_at',
        'started_at',
        'expected_end_at',
        'ended_at',
        'retry_after_seconds',
        'allowed_routes_json',
        'blocked_route_patterns_json',
        'created_by_admin_id',
        'updated_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'scheduled_start_at' => 'datetime',
        'started_at' => 'datetime',
        'expected_end_at' => 'datetime',
        'ended_at' => 'datetime',
        'retry_after_seconds' => 'integer',
        'allowed_routes_json' => 'array',
        'blocked_route_patterns_json' => 'array',
    ];

    public function events(): HasMany
    {
        return $this->hasMany(PartnerTenantMaintenanceEvent::class, 'maintenance_setting_id');
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function updatedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'updated_by_admin_id');
    }
}

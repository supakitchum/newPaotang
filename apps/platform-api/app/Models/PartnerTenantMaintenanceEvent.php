<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerTenantMaintenanceEvent extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_maintenance_events';

    protected $fillable = [
        'id',
        'tenant_id',
        'maintenance_setting_id',
        'event_type',
        'status',
        'mode',
        'reason',
        'ticket_id',
        'actor_admin_id',
        'payload_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'payload_json' => 'array',
    ];

    public function setting(): BelongsTo
    {
        return $this->belongsTo(PartnerTenantMaintenanceSetting::class, 'maintenance_setting_id');
    }

    public function actorAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'actor_admin_id');
    }
}

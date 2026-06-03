<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerCentralMaintenanceSetting extends BaseModel
{
    protected $table = 'partner_central_maintenance_settings';

    protected $fillable = [
        'id',
        'partner_id',
        'status',
        'message',
        'reason',
        'ticket_id',
        'scheduled_start_at',
        'started_at',
        'expected_end_at',
        'ended_at',
        'retry_after_seconds',
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
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
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

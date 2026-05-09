<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerMonitoringProfile extends BaseModel
{
    protected $table = 'partner_monitoring_profiles';

    protected $fillable = [
        'id',
        'partner_id',
        'status',
        'health_status',
        'created_at',
        'updated_at',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}

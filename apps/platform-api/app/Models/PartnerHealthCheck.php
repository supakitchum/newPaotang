<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerHealthCheck extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_health_checks';

    protected $fillable = [
        'id',
        'partner_id',
        'tenant_id',
        'check_key',
        'health_status',
        'checked_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'checked_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}

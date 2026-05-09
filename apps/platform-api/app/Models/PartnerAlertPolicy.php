<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerAlertPolicy extends BaseModel
{
    protected $table = 'partner_alert_policies';

    protected $fillable = [
        'id',
        'partner_id',
        'policy_key',
        'status',
        'severity',
        'config_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'config_json' => 'array',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}

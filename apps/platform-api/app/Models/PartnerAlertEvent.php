<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerAlertEvent extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_alert_events';

    protected $fillable = [
        'id',
        'partner_id',
        'tenant_id',
        'alert_policy_id',
        'policy_key',
        'severity',
        'status',
        'channel',
        'title',
        'message',
        'labels_json',
        'payload_redacted_json',
        'dry_run',
        'triggered_at',
        'delivered_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'labels_json' => 'array',
        'payload_redacted_json' => 'array',
        'dry_run' => 'boolean',
        'triggered_at' => 'datetime',
        'delivered_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function alertPolicy(): BelongsTo
    {
        return $this->belongsTo(PartnerAlertPolicy::class, 'alert_policy_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerDailyUsageSummary extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_daily_usage_summaries';

    protected $fillable = [
        'id',
        'partner_id',
        'tenant_id',
        'usage_date',
        'api_request_count',
        'booking_request_count',
        'checkout_request_count',
        'order_count',
        'sold_ticket_count',
        'image_bandwidth_gb',
        'storage_gb',
        'queue_job_count',
        'rate_limited_count',
        'error_count',
        'sync_event_count',
        'labels_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'usage_date' => 'date',
        'api_request_count' => 'integer',
        'booking_request_count' => 'integer',
        'checkout_request_count' => 'integer',
        'order_count' => 'integer',
        'sold_ticket_count' => 'integer',
        'image_bandwidth_gb' => 'float',
        'storage_gb' => 'float',
        'queue_job_count' => 'integer',
        'rate_limited_count' => 'integer',
        'error_count' => 'integer',
        'sync_event_count' => 'integer',
        'labels_json' => 'array',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}

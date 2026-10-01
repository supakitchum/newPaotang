<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerCommunicationCampaign extends BaseModel
{
    use BelongsToTenant;

    protected $fillable = [
        'id',
        'tenant_id',
        'name',
        'audience_type',
        'customer_id',
        'status',
        'title_json',
        'body_json',
        'action_key',
        'action_entity_id',
        'image_full_asset_id',
        'image_thumb_asset_id',
        'notification_id',
        'created_by_admin_id',
        'dedupe_key',
        'scheduled_at',
        'published_at',
        'cancelled_at',
        'last_error_code',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'title_json' => 'array',
        'body_json' => 'array',
        'scheduled_at' => 'datetime',
        'published_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function notification(): BelongsTo
    {
        return $this->belongsTo(CustomerNotification::class, 'notification_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }

    public function fullAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'image_full_asset_id');
    }

    public function thumbAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'image_thumb_asset_id');
    }
}
